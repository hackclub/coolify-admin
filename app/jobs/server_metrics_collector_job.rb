class ServerMetricsCollectorJob < ApplicationJob
  queue_as :default

  def perform(server_id)
    start_time = Time.current
    server = Server.find(server_id)
    Rails.logger.info "[ServerMetrics] #{server.name}: Starting collection..."
    
    key = server.private_key&.private_key
    unless key.present?
      Rails.logger.warn "[ServerMetrics] #{server.name}: No SSH key, skipping"
      return
    end

    client = SshClient.new(host: server.ip, user: server.user, port: server.port || 22, private_key: key)

    # Collect and update CPU cores every time (servers can be rescaled)
    Rails.logger.info "[ServerMetrics] #{server.name}: → Detecting CPU cores..."
    cores = collect_cpu_cores(client)
    server.update(cpu_cores: cores) if cores && cores != server.cpu_cores

    now = Time.current
    Rails.logger.info "[ServerMetrics] #{server.name}: → Collecting CPU percentage..."
    cpu_pct = collect_cpu_pct(client, server)
    
    Rails.logger.info "[ServerMetrics] #{server.name}: → Collecting memory stats..."
    mem_pct, mem_used = collect_mem(client)
    
    Rails.logger.info "[ServerMetrics] #{server.name}: → Collecting disk usage..."
    disk_used, disk_total = collect_disk_totals(client)
    
    Rails.logger.info "[ServerMetrics] #{server.name}: → Collecting load average..."
    load1, load5, load15 = collect_loadavg(client)
    
    Rails.logger.info "[ServerMetrics] #{server.name}: → Collecting IOPS..."
    iops_r, iops_w = collect_iops(client)
    
    Rails.logger.info "[ServerMetrics] #{server.name}: → Collecting filesystem info..."
    filesystems = collect_filesystems(client)
    
    Rails.logger.info "[ServerMetrics] #{server.name}: → Counting zombie processes..."
    zombie_count = collect_zombie_processes(client)

    ServerStat.create!(
      server: server,
      captured_at: now,
      cpu_pct: cpu_pct,
      mem_pct: mem_pct,
      mem_used_bytes: mem_used,
      disk_used_bytes: disk_used,
      disk_total_bytes: disk_total,
      iops_r: iops_r,
      iops_w: iops_w,
      load1: load1,
      load5: load5,
      load15: load15,
      filesystems: filesystems,
      zombie_processes: zombie_count
    )
    
    elapsed = (Time.current - start_time).round(1)
    Rails.logger.info "[ServerMetrics] #{server.name}: ✓ Collected in #{elapsed}s"
  rescue => e
    elapsed = (Time.current - start_time).round(1) rescue 0
    Rails.logger.error "[ServerMetrics] #{server.name}: ✗ FAILED after #{elapsed}s - #{e.class}: #{e.message}"
  end

  private

  def collect_cpu_pct(client, server)
    # Primary: /proc/stat delta - using the provided single-call command
    # Use single quotes throughout to avoid escaping issues
    cpu_cmd = <<~'SHELL'.strip
      sh -c 'A=$(grep "^cpu " /proc/stat); sleep 1; B=$(grep "^cpu " /proc/stat); set -- $A; ua=$2; na=$3; sa=$4; ia=$5; iowa=$6; irqa=$7; sirqa=$8; sta=$9; ta=$((ua+na+sa+ia+iowa+irqa+sirqa+sta)); idlea=$((ia+iowa)); set -- $B; ub=$2; nb=$3; sb=$4; ib=$5; iowb=$6; irqb=$7; sirqb=$8; stb=$9; tb=$((ub+nb+sb+ib+iowb+irqb+sirqb+stb)); idleb=$((ib+iowb)); tot=$((tb-ta)); idle=$((idleb-idlea)); awk -v t=$tot -v i=$idle '"'"'BEGIN { if (t>0) printf("%.2f\n", 100*(t-i)/t); else print 0 }'"'"''
    SHELL
    _code, out, err = client.exec!(cpu_cmd, timeout: 15)
    text = (out.to_s + "\n" + err.to_s).strip
    num = text[/[0-9]+(?:\.[0-9]+)?/]
    return num.to_f.round(2) if num

    # Fallback to two-call delta
    _code1, out1, err1 = client.exec!("grep '^cpu ' /proc/stat")
    sleep 1
    _code2, out2, err2 = client.exec!("grep '^cpu ' /proc/stat")
    if out1.to_s.include?("cpu ") && out2.to_s.include?("cpu ")
      a = parse_proc_stat(out1)
      b = parse_proc_stat(out2)
      totald = (b[:total] - a[:total]).to_f
      idled = (b[:idle] - a[:idle]).to_f
      return ((totald - idled) / totald * 100.0).round(2) if totald > 0
    end

    # Fallback: top -bn1
    code, out, _ = client.exec!("top -bn1 | grep 'Cpu(s)' | awk '{print $2+$4}' 2>/dev/null")
    if code == 0
      val = out.to_s.strip
      return val.to_f if val.match?(/^[0-9.]+$/)
    end
    nil
  end

  def parse_proc_stat(line)
    parts = line.to_s.split
    # parts[0] = 'cpu', then a variable number of jiffy counters
    nums = parts[1..].to_a.map { |x| Integer(x) rescue 0 }
    total = nums.sum
    idle = nums[3].to_i # idle
    iowait = nums[4].to_i # iowait may be missing, to_i => 0
    { total: total, idle: idle + iowait }
  end

  def collect_mem(client)
    # Try free -b first
    code, out, _err = client.exec!("free -b")
    if code == 0 && (line = out.lines.find { |l| l.start_with?("Mem:") })
      _label, total, used, _free, _shared, _buff, _avail = line.split
      total = total.to_f
      used = used.to_i
      pct = total > 0 ? (used / total * 100.0).round(2) : nil
      return [pct, used]
    end

    # Fallback: parse /proc/meminfo -> MemTotal - MemAvailable
    code, out, _ = client.exec!("cat /proc/meminfo | egrep '^(MemTotal|MemAvailable):' | awk '{print $2}'")
    vals = out.split.map(&:to_i)
    if vals.length == 2
      total_kb, avail_kb = vals
      used_bytes = (total_kb - avail_kb) * 1024
      pct = total_kb > 0 ? ((used_bytes.to_f / (total_kb * 1024)) * 100.0).round(2) : nil
      return [pct, used_bytes]
    end
    [nil, nil]
  end

  def collect_disk_totals(client)
    # GNU df path - exclude pseudo/remote filesystems, filter out fuse.* types via awk
    code, out, _err = client.exec!("df -B1 --output=fstype,used,size -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null | tail -n+2 | awk '$1!~/^fuse/{u+=$2; t+=$3} END {print u, t}'", timeout: 45)
    if code == 0 && out.to_s.strip.split.length == 2
      used, total = out.split.map(&:to_i)
      return [used, total]
    end
    # Portable fallback: POSIX df -kP, filter pseudo FS by device name heuristics
    code, out, _ = client.exec!("df -kP 2>/dev/null | tail -n+2 | awk '$1!~/(tmpfs|devtmpfs|overlay|proc|sysfs|cgroup|debugfs|securityfs|pstore|tracefs|ramfs|squashfs|nsfs|bpf|efivarfs|fuse)/{u+=$3; t+=$2} END {print u*1024, t*1024}'", timeout: 45)
    if code == 0 && out.to_s.strip.split.length == 2
      used, total = out.split.map(&:to_i)
      return [used, total]
    end
    [nil, nil]
  end

  def collect_loadavg(client)
    _code, out, _err = client.exec!("cat /proc/loadavg")
    a, b, c, *_ = out.split
    [a.to_f, b.to_f, c.to_f]
  rescue
    [nil, nil, nil]
  end

  def collect_iops(client)
    # Cheap fallback: compute r/s and w/s from /proc/diskstats delta for all disks
    _code, out1, _err = client.exec!("cat /proc/diskstats")
    sleep 1
    _code, out2, _err = client.exec!("cat /proc/diskstats")
    a = sum_diskstats(out1)
    b = sum_diskstats(out2)
    rd = b[:reads_completed] - a[:reads_completed]
    wd = b[:writes_completed] - a[:writes_completed]
    [rd.to_f, wd.to_f]
  rescue
    [nil, nil]
  end

  def sum_diskstats(text)
    reads = 0
    writes = 0
    text.each_line do |l|
      parts = l.split
      next unless parts.length >= 8
      reads += parts[3].to_i
      writes += parts[7].to_i
    end
    { reads_completed: reads, writes_completed: writes }
  end

  def collect_filesystems(client)
    # Try GNU df with fstype
    code, out, _ = client.exec!("df -B1 --output=source,target,fstype,used,size,itotal,iused -x tmpfs -x devtmpfs 2>/dev/null", timeout: 60)
    if code == 0 && out.lines.size > 1
      return out.lines.drop(1).filter_map do |l|
        parts = l.split
        next if parts.size < 7
        src, tgt, fstype, used, size, itotal, iused = parts
        next if pseudo_fs?(fstype, src)
        {
          device: src,
          mountpoint: tgt,
          fstype: fstype,
          used_bytes: used.to_i,
          total_bytes: size.to_i,
          inodes_total: itotal.to_i,
          inodes_used: iused.to_i
        }
      end
    end
    # Fallback: df -kP (no fstype). Join with /proc/mounts to get fstype.
    code, mounts_out, _ = client.exec!("cat /proc/mounts | awk '{print $1, $2, $3}'")
    mtypes = {}
    if code == 0
      mounts_out.each_line do |l|
        dev, mnt, fstype = l.split
        mtypes[mnt] = [dev, fstype]
      end
    end
    code, out, _ = client.exec!("df -kP 2>/dev/null | tail -n+2", timeout: 60)
    return [] unless code == 0
    out.each_line.filter_map do |l|
      parts = l.split
      next if parts.size < 6
      fs, blocks, used, avail, _usep, mount = parts[0,6]
      dev, fstype = mtypes[mount] || [fs, '']
      next if pseudo_fs?(fstype, dev)
      {
        device: dev,
        mountpoint: mount,
        fstype: fstype,
        used_bytes: used.to_i * 1024,
        total_bytes: blocks.to_i * 1024,
        inodes_total: nil,
        inodes_used: nil
      }
    end
  end

  def pseudo_fs?(fstype, device)
    return true if device =~ /^(tmpfs|devtmpfs|overlay|proc|sysfs|cgroup|debugfs|securityfs|pstore|tracefs|ramfs|squashfs|nsfs|bpf|efivarfs)/
    return true if %w[tmpfs devtmpfs overlay proc sysfs cgroup debugfs securityfs pstore tracefs ramfs squashfs nsfs bpf efivarfs].include?(fstype.to_s)
    false
  end

  def collect_cpu_cores(client)
    code, out, _ = client.exec!("nproc 2>/dev/null || grep -c processor /proc/cpuinfo")
    out.to_i if code == 0 && out.to_i > 0
  end

  def collect_zombie_processes(client)
    # Count processes in zombie state (Z)
    code, out, _err = client.exec!("ps axo state | grep -c '^Z' 2>/dev/null || echo 0")
    return out.to_i if code == 0 && out.to_s.strip.match?(/^\d+$/)
    
    # Fallback: count from /proc
    code, out, _ = client.exec!("find /proc -maxdepth 1 -type d -name '[0-9]*' -exec cat {}/stat 2>/dev/null \\; | awk '{if ($3 == \"Z\") count++} END {print count+0}'")
    code == 0 ? out.to_i : nil
  rescue
    nil
  end
end



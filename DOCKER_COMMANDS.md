# Docker Compose Commands Reference

## Quick Answer

**To bind ports when using `docker-compose run`:**

```bash
docker-compose run --service-ports web bash
```

Both of these work the same:
- `docker-compose run --service-ports web bash`
- `docker-compose run --service-ports web /bin/bash`

## Complete Command Reference

### 1. Access Running Container (RECOMMENDED)

```bash
docker-compose exec web bash
```

**When to use:**
- Container is already running
- Quick access to shell
- Run Rails console or migrations
- 99% of daily use cases

**Advantages:**
- ✅ Fast (uses existing container)
- ✅ Ports already available (localhost:3000)
- ✅ No cleanup needed

### 2. Run New Container WITH Port Binding

```bash
docker-compose run --service-ports web bash
```

**When to use:**
- Need isolated testing
- Container isn't running
- Need to manually start Rails server

**Advantages:**
- ✅ Ports are bound (127.0.0.1:3000→3000)
- ✅ Fresh container environment

**Disadvantages:**
- ⚠️ Creates new container each time
- ⚠️ Container persists after exit (manual cleanup)

**Better version (auto-cleanup):**
```bash
docker-compose run --rm --service-ports web bash
```

### 3. Run New Container WITHOUT Port Binding

```bash
docker-compose run web bash
```

**When to use:**
- Running background tasks
- Database migrations
- Tasks that don't need web server

**Advantages:**
- ✅ Faster startup
- ✅ No port conflicts

**Disadvantages:**
- ❌ Cannot access via localhost:3000
- ⚠️ Creates new container each time

### 4. Direct Docker Command

```bash
docker exec -it coolify-admin_web_1 bash
```

**When to use:**
- Direct Docker control
- Same as `docker-compose exec`

## Common Use Cases

### Access Shell
```bash
# Most common way
docker-compose exec web bash

# With port binding
docker-compose run --service-ports web bash
```

### Run Rails Console
```bash
docker-compose exec web rails console
```

### Run Database Migrations
```bash
docker-compose exec web rails db:migrate
```

### Run Tests
```bash
docker-compose exec web rails test
```

### Generate Code
```bash
docker-compose exec web rails generate model User name:string
```

### Install Gems
```bash
docker-compose exec web bundle install
```

### Run One-off Commands
```bash
# Without keeping container
docker-compose run --rm web rails db:seed

# With ports (for server)
docker-compose run --rm --service-ports web rails server -b 0.0.0.0
```

### Debug with Byebug
```bash
# Need interactive terminal
docker-compose run --service-ports web bash
# Then inside: rails server -b 0.0.0.0
```

## Important Flags

| Flag | Purpose |
|------|---------|
| `--service-ports` | Enable port mapping from docker-compose.yml |
| `--rm` | Automatically remove container after exit |
| `-T` | Disable pseudo-TTY (for scripts) |
| `-d` | Run in detached mode (background) |
| `-e KEY=value` | Set environment variables |

## Comparison

| Command | Uses Existing Container | Binds Ports | Creates New Container | Auto-cleanup |
|---------|------------------------|-------------|----------------------|--------------|
| `exec` | ✅ | ✅ (already bound) | ❌ | N/A |
| `run --service-ports` | ❌ | ✅ | ✅ | ❌ |
| `run --rm --service-ports` | ❌ | ✅ | ✅ | ✅ |
| `run` | ❌ | ❌ | ✅ | ❌ |
| `run --rm` | ❌ | ❌ | ✅ | ✅ |

## Best Practices

✅ **DO:**
- Use `exec` for daily work
- Use `--rm` flag with `run` to avoid container buildup
- Use `--service-ports` when you need the web server

❌ **DON'T:**
- Leave orphaned containers from `run` commands
- Use `run` when `exec` will work
- Forget the `--service-ports` flag if you need ports

## Cleanup

```bash
# Stop all services
docker-compose down

# Remove orphaned containers
docker-compose rm

# See all containers
docker-compose ps -a

# Remove specific container
docker rm <container_name>
```

## Troubleshooting

### Container not running?
```bash
docker-compose ps
docker-compose up -d
```

### Port already in use?
```bash
docker-compose down
docker-compose up -d
```

### Too many orphaned containers?
```bash
docker-compose down
docker system prune
```

### Check container logs
```bash
docker-compose logs web
docker-compose logs -f web  # follow
```

## TL;DR

**Daily use (container running):**
```bash
docker-compose exec web bash
```

**Need ports with new container:**
```bash
docker-compose run --rm --service-ports web bash
```

**One-off command:**
```bash
docker-compose run --rm web rails db:migrate
```

---

**Remember:** 
- `exec` = use existing container (fast) ✅
- `run --service-ports` = new container with ports ⚠️
- `run --rm` = auto-cleanup 🧹


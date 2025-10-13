# Agent Development Guide - Docker Environment

This document is for AI agents working on the Coolify Admin codebase. It explains how the Docker development environment works and how to execute commands properly.

## Docker Environment Overview

This Rails application runs entirely in Docker containers. The development setup uses `docker-compose` with two services:

1. **`web`** - Rails application container (Ruby 3.4.7, Rails 8.0.3)
2. **`db`** - PostgreSQL 17 database container

### Key Architecture Points

- The codebase is **mounted as a volume** from the host (`/root/dev/coolify-admin`) to the container (`/rails`)
- File changes on the host are immediately reflected in the container
- Bundle gems are cached in a Docker volume (`bundle_cache`) to persist between rebuilds
- The Rails server auto-starts via the `docker-entrypoint` script, which runs `db:prepare` automatically

## Critical: How to Run Commands

### ❌ DO NOT run commands directly on the host

```bash
# ❌ WRONG - bundle is not installed on the host
bundle install

# ❌ WRONG - rails is not installed on the host
bin/rails db:migrate

# ❌ WRONG - ruby is not properly configured on host
rails console
```

### ✅ ALWAYS run Rails/Ruby commands inside the Docker container

```bash
# ✅ CORRECT - runs inside the web container
docker-compose exec web bundle install

# ✅ CORRECT - runs migrations in the container
docker-compose exec web bin/rails db:migrate

# ✅ CORRECT - opens console in the container
docker-compose exec web rails console
```

### Important: TTY Issues with docker-compose exec

When running `docker-compose exec` in non-interactive environments (like CI or when piped), you may encounter the error:

```
the input device is not a TTY
```

**Solution:** Add the `-T` flag to disable pseudo-TTY allocation:

```bash
# For non-interactive execution (scripts, CI, automation)
docker-compose exec -T web bundle install
docker-compose exec -T web bin/rails db:migrate
```

**When to use `-T`:**
- In automated scripts
- When input is piped from another command
- In CI/CD pipelines
- When the command doesn't require user input

**When NOT to use `-T`:**
- Interactive Rails console (`rails console`)
- Text editors (like `rails credentials:edit`)
- Any command requiring user input
- Debugging with `binding.pry` or similar

## Common Development Tasks

### 1. Installing Gems

When you add gems to the `Gemfile`:

```bash
# Install gems (use -T for automation)
docker-compose exec -T web bundle install

# Restart the Rails server to pick up new gems
docker-compose restart web
```

### 2. Database Operations

```bash
# Run migrations
docker-compose exec -T web bin/rails db:migrate

# Rollback migration
docker-compose exec -T web bin/rails db:rollback

# Reset database (drops, creates, migrates, seeds)
docker-compose exec -T web bin/rails db:reset

# Generate a migration
docker-compose exec web bin/rails generate migration CreateSomething

# Initialize encryption keys
docker-compose exec web bin/rails db:encryption:init
```

### 3. Generators

```bash
# Generate a controller
docker-compose exec web bin/rails generate controller Pages index

# Generate a model
docker-compose exec web bin/rails generate model User name:string email:string

# Generate a scaffold
docker-compose exec web bin/rails generate scaffold Post title:string body:text
```

### 4. Rails Console

```bash
# Open interactive console (do NOT use -T here)
docker-compose exec web rails console

# Run a single Ruby command
docker-compose exec -T web rails runner "puts Rails.env"
```

### 5. Testing

```bash
# Run all tests
docker-compose exec -T web rails test

# Run specific test file
docker-compose exec -T web rails test test/models/user_test.rb

# Run with verbose output
docker-compose exec -T web rails test -v
```

### 6. Code Quality

```bash
# Run RuboCop
docker-compose exec -T web bundle exec rubocop

# Auto-correct issues
docker-compose exec -T web bundle exec rubocop -A

# Run Brakeman security scan
docker-compose exec -T web bundle exec brakeman
```

## File System & Volumes

### Project Structure

```
Host:        /root/dev/coolify-admin/
Container:   /rails/
```

Files are synchronized bidirectionally. When you create/edit files on the host, they appear instantly in the container.

### Volume Mounts

1. **Code volume (bind mount)**
   - Host: `/root/dev/coolify-admin`
   - Container: `/rails`
   - Type: Read-write bind mount
   - Changes: Immediate synchronization

2. **Bundle cache volume (named volume)**
   - Name: `bundle_cache`
   - Container: `/usr/local/bundle`
   - Purpose: Persist gems between container rebuilds
   - Note: Survives `docker-compose down` but not `docker-compose down -v`

3. **Database volume (named volume)**
   - Name: `postgres_data`
   - Container: `/var/lib/postgresql/data`
   - Purpose: Persist PostgreSQL data
   - Note: Survives container restarts

## Container Lifecycle

### Starting the Environment

```bash
# Start containers (first time or after rebuild)
docker-compose up

# Start in background
docker-compose up -d

# Rebuild and start (after Dockerfile changes)
docker-compose up --build
```

### Stopping the Environment

```bash
# Stop containers (preserves volumes)
docker-compose down

# Stop and remove volumes (complete clean slate)
docker-compose down -v
```

### Restarting Services

```bash
# Restart Rails server (picks up gem changes, initializer changes)
docker-compose restart web

# Restart database
docker-compose restart db

# Restart all services
docker-compose restart
```

## Auto-Initialization on Startup

The `docker-entrypoint` script automatically runs `bin/rails db:prepare` when starting the Rails server. This means:

- On first start: Database is created and migrations run
- On subsequent starts: Pending migrations are run automatically
- You typically don't need to manually run `db:create` or `db:migrate`

If you need a clean database:

```bash
docker-compose exec -T web bin/rails db:drop db:create db:migrate
```

## Environment Variables

Environment variables are set in `docker-compose.yml`:

```yaml
environment:
  RAILS_ENV: development
  DATABASE_URL: postgresql://postgres:password@db:5432/coolify_admin_development
```

To add more environment variables, edit `docker-compose.yml` and restart:

```yaml
environment:
  RAILS_ENV: development
  DATABASE_URL: postgresql://...
  RAILS_MASTER_KEY: your_master_key_here
  SOME_API_KEY: your_value_here
```

## Network & Ports

- **Rails app:** `http://localhost:3000` (host) → port `3000` (container)
- **PostgreSQL:** `localhost:5432` (host) → port `5432` (container)
- **Security:** Ports bound to `127.0.0.1` (localhost only) for security

### Internal Container Networking

Within Docker Compose, services communicate via service names:
- Rails connects to database at `db:5432` (not `localhost:5432`)
- Service names act as DNS hostnames within the Docker network

## Debugging Inside Containers

### View Logs

```bash
# Follow Rails logs
docker-compose logs -f web

# Follow database logs
docker-compose logs -f db

# View last 100 lines
docker-compose logs --tail=100 web
```

### Access Container Shell

```bash
# Open bash shell in web container
docker-compose exec web bash

# Once inside, you can run commands directly:
# bundle install
# rails db:migrate
# rails console
# etc.
```

### Inspect Container State

```bash
# List running containers
docker-compose ps

# View resource usage
docker stats

# Inspect container details
docker-compose exec web ps aux
docker-compose exec web df -h
```

## Common Issues & Solutions

### 1. "the input device is not a TTY"

**Problem:** Running `docker-compose exec` without a terminal.

**Solution:** Add `-T` flag:
```bash
docker-compose exec -T web bundle install
```

### 2. "Command 'bundle' not found"

**Problem:** Attempting to run commands on the host instead of in the container.

**Solution:** Prefix with `docker-compose exec web`:
```bash
docker-compose exec -T web bundle install
```

### 3. Gems not loading after bundle install

**Problem:** Rails server hasn't restarted to pick up new gems.

**Solution:** Restart the web service:
```bash
docker-compose restart web
```

### 4. Database connection refused

**Problem:** Database container isn't running or isn't healthy yet.

**Solution:** 
```bash
# Check container status
docker-compose ps

# Wait for database health check
docker-compose up db  # runs in foreground, watch for "ready to accept connections"

# Or restart
docker-compose restart db
```

### 5. Permission errors with files

**Problem:** Files created by container have different ownership.

**Solution:** The container runs as root, but volumes are mounted from host. This is usually not an issue for development. If needed:
```bash
# On host, fix permissions
sudo chown -R $USER:$USER /root/dev/coolify-admin
```

### 6. Port 3000 already in use

**Problem:** Another process is using port 3000.

**Solution:**
```bash
# Find and kill the process
lsof -ti:3000 | xargs kill -9

# Or change the port in docker-compose.yml
```

### 7. Changes not reflecting

**Problem:** Code changes not showing up.

**Solution:**
- For most code: Changes are immediate (controllers, models, views)
- For initializers: Restart server with `docker-compose restart web`
- For routes: Usually immediate in development mode
- For gems: Must run `bundle install` and restart server

## Agent Best Practices

### 1. Always Use Container Context

Remember that the Ruby/Rails environment exists ONLY inside the Docker container. Never assume host has Ruby, Rails, or bundler.

### 2. Check Container Status First

Before running commands, verify containers are running:
```bash
docker-compose ps
```

### 3. Use -T Flag for Automation

When running non-interactive commands programmatically, always use `-T`:
```bash
docker-compose exec -T web bundle install
```

### 4. Handle Failures Gracefully

If a container command fails, check:
1. Are containers running? (`docker-compose ps`)
2. Are there logs indicating problems? (`docker-compose logs web`)
3. Is the database healthy? (`docker-compose ps db`)

### 5. Complete Sequences for Changes

When making changes that require multiple steps:
```bash
# Example: Adding a gem
# 1. Edit Gemfile (file operation)
# 2. Install gem
docker-compose exec -T web bundle install
# 3. Restart server
docker-compose restart web
# 4. Run migrations if needed
docker-compose exec -T web bin/rails db:migrate
```

## Quick Reference

### Most Common Commands

| Task | Command |
|------|---------|
| Install gems | `docker-compose exec -T web bundle install` |
| Run migrations | `docker-compose exec -T web bin/rails db:migrate` |
| Rails console | `docker-compose exec web rails console` |
| Run tests | `docker-compose exec -T web rails test` |
| View logs | `docker-compose logs -f web` |
| Restart Rails | `docker-compose restart web` |
| Access shell | `docker-compose exec web bash` |
| Generate scaffold | `docker-compose exec web bin/rails generate scaffold Model` |

### Container Management

| Task | Command |
|------|---------|
| Start | `docker-compose up` |
| Start detached | `docker-compose up -d` |
| Stop | `docker-compose down` |
| Stop + clean | `docker-compose down -v` |
| Restart | `docker-compose restart` |
| Rebuild | `docker-compose up --build` |
| Status | `docker-compose ps` |

---

**Remember:** Everything Rails/Ruby-related runs in Docker. When in doubt, prefix with `docker-compose exec -T web`.


# Coolify Admin

A Rails 8.0.3 application with Docker support.

## Features

- **Rails 8.0.3** - Latest Rails version
- **Hotwire** - Turbo and Stimulus for modern, reactive UIs
- **Solid Gems** - SolidCache, SolidQueue, and SolidCable
- **PostgreSQL** - Production-ready database (in Docker)
- **SQLite3** - Fallback for local development
- **Kamal** - Docker-based deployment tool
- **Thruster** - HTTP/2 proxy for Rails
- **RuboCop** - Code linting with Rails Omakase style
- **Brakeman** - Security vulnerability scanning

## Getting Started with Docker

### Prerequisites

- Docker and Docker Compose installed
- That's it! No Ruby or Rails installation needed locally.

### Quick Start

1. **Build and start the application:**

```bash
docker-compose up --build
```

2. **Access the application:**

Open your browser and navigate to `http://localhost:3000`

3. **Create the database:**

The database will be created automatically on first run. If you need to manually run migrations:

```bash
docker-compose exec web rails db:create db:migrate
```

### Common Docker Commands

**Start the application:**
```bash
docker-compose up
```

**Start in detached mode (background):**
```bash
docker-compose up -d
```

**Stop the application:**
```bash
docker-compose down
```

**View logs:**
```bash
docker-compose logs -f web
```

**Run Rails console:**
```bash
docker-compose exec web rails console
```

**Run migrations:**
```bash
docker-compose exec web rails db:migrate
```

**Run tests:**
```bash
docker-compose exec web rails test
```

**Install new gems:**
```bash
docker-compose exec web bundle install
```

**Generate a controller:**
```bash
docker-compose exec web rails generate controller Welcome index
```

**Access bash shell in the container:**
```bash
docker-compose exec web bash
```

### Database

The application is configured to use:
- **PostgreSQL** when running in Docker (via `DATABASE_URL`)
- **SQLite3** for local development without Docker

Database credentials (Docker):
- Host: `db`
- Port: `5432`
- Username: `postgres`
- Password: `password`
- Database: `coolify_admin_development`

### Security

**🔒 Localhost-Only Binding (Secure by Default)**

This development environment is configured for security:
- Rails server is bound to `127.0.0.1:3000` (localhost only)
- PostgreSQL is bound to `127.0.0.1:5432` (localhost only)
- External network access is **blocked**
- Only accessible from your local machine

This prevents:
- ❌ Remote access attempts
- ❌ Network port scans finding your dev server
- ❌ Accidental exposure of development database
- ❌ Security vulnerabilities from open ports

To verify security:
```bash
# Check port bindings
docker-compose ps
# Should show: 127.0.0.1:3000->3000/tcp and 127.0.0.1:5432->5432/tcp

# Verify network bindings
netstat -tuln | grep -E "(3000|5432)"
# Should show: 127.0.0.1:3000 and 127.0.0.1:5432
```

### File Structure

```
.
├── app/                    # Application code (models, views, controllers)
├── bin/                    # Executables and scripts
├── config/                 # Configuration files
├── db/                     # Database migrations and schema
├── lib/                    # Library code
├── public/                 # Static files
├── storage/                # Active Storage files
├── test/                   # Test suite
├── Dockerfile              # Production Docker configuration
├── Dockerfile.dev          # Development Docker configuration
├── docker-compose.yml      # Docker Compose configuration
└── README.md              # This file
```

### Development Workflow

1. **Make code changes** - Files are mounted as volumes, so changes are reflected immediately
2. **Restart the server** if needed - Press `Ctrl+C` and run `docker-compose up` again
3. **Run migrations** after creating them
4. **Commit your changes**

### Production Deployment

This app includes Kamal for Docker-based deployment:

```bash
# Initialize Kamal configuration
kamal init

# Deploy to production
kamal deploy
```

See `config/deploy.yml` for Kamal configuration.

### Troubleshooting

**Port already in use:**
```bash
# Stop any process using port 3000
lsof -ti:3000 | xargs kill -9
# Or change the port in docker-compose.yml
```

**Permission issues:**
```bash
# Rebuild with proper permissions
docker-compose down
docker-compose up --build
```

**Database connection errors:**
```bash
# Ensure database container is running
docker-compose ps
# Restart database
docker-compose restart db
```

**Clean slate:**
```bash
# Remove all containers and volumes
docker-compose down -v
docker-compose up --build
```

## License

This project is available for use under your preferred license.

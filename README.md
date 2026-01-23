<p align="center">
  <img src="./logo.svg" width="180" alt="PHP Laravel Base Image Logo">
</p>

<h1 align="center">PHP Laravel Base Image</h1>

<p align="center">
  <strong>A highly optimized, multi-platform Docker base image for Laravel projects.</strong><br>
  Pre-configured with all essential PHP extensions, tools, and optimizations for production-ready Laravel applications.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/PHP-8.2%20|%208.3%20|%208.4-777BB4?style=flat-square&logo=php&logoColor=white" alt="PHP Versions">
  <img src="https://img.shields.io/badge/Laravel-Ready-FF2D20?style=flat-square&logo=laravel&logoColor=white" alt="Laravel Ready">
  <img src="https://img.shields.io/badge/Docker-Multi--Platform-2496ED?style=flat-square&logo=docker&logoColor=white" alt="Docker">
</p>

## Features

- 🚀 **Optimized for Laravel** - Pre-configured PHP settings and extensions
- 🏗️ **Multi-Platform** - Supports `linux/amd64` and `linux/arm64`
- 📦 **Multiple PHP Versions** - 8.2, 8.3, and 8.4
- ⚡ **OPcache + JIT** - Enabled for maximum performance
- 🛠️ **Global Tools** - Composer, Laravel Installer, PHPUnit, Pest, and more
- 🔒 **Security** - Non-root user available, minimal attack surface

## Quick Start

### Pull from Docker Hub

```bash
# Latest (PHP 8.4)
docker pull yourusername/php-laravel-base:latest

# Specific PHP version
docker pull yourusername/php-laravel-base:8.3
```

### Use in Your Project

```dockerfile
FROM yourusername/php-laravel-base:8.3

WORKDIR /var/www/html

# Copy application
COPY . .

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions
RUN chown -R appuser:appgroup storage bootstrap/cache

USER appuser

CMD ["php-fpm"]
```

### Create New Laravel Project

```bash
docker run --rm -v $(pwd):/app -w /app yourusername/php-laravel-base:8.3 \
    laravel new my-project
```

## Included PHP Extensions

| Extension | Purpose |
|-----------|---------|
| `pdo_mysql` | MySQL database |
| `pdo_pgsql` | PostgreSQL database |
| `mysqli` | MySQL improved |
| `redis` | Redis cache/queue |
| `gd` | Image processing |
| `imagick` | ImageMagick support |
| `exif` | Image metadata |
| `intl` | Internationalization |
| `mbstring` | Multibyte strings |
| `bcmath` | Arbitrary precision math |
| `opcache` | Bytecode caching |
| `pcntl` | Process control (queues) |
| `sockets` | Socket communication |
| `zip` | ZIP archives |
| `soap` | SOAP protocol |
| `xsl` | XSL transformations |

## Global Tools

| Tool | Command | Description |
|------|---------|-------------|
| Composer | `composer` | PHP dependency manager |
| Laravel Installer | `laravel new` | Create Laravel projects |
| Laravel Envoy | `envoy` | Deployment scripting |
| PHPUnit | `phpunit` | Testing framework |
| Pest | `pest` | Modern testing framework |
| PHP-CS-Fixer | `php-cs-fixer` | Code style fixer |
| PHP_CodeSniffer | `phpcs` / `phpcbf` | Code standards |

## Environment Variables

Customize PHP settings via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` | Set to `1` for development |
| `PHP_OPCACHE_MEMORY_CONSUMPTION` | `256` | OPcache memory (MB) |
| `PHP_OPCACHE_MAX_ACCELERATED_FILES` | `20000` | Max cached files |
| `PHP_OPCACHE_JIT_BUFFER_SIZE` | `128M` | JIT buffer size |

### Development vs Production

```yaml
# docker-compose.yml
services:
  app:
    image: yourusername/php-laravel-base:8.3
    environment:
      # Development - enable file watching
      PHP_OPCACHE_VALIDATE_TIMESTAMPS: 1
      
      # Production - disable for performance
      # PHP_OPCACHE_VALIDATE_TIMESTAMPS: 0
```

## Building Images

### Prerequisites

1. Clone this repository
2. Copy `.env.example` to `.env`
3. Add your Docker Hub credentials:

```bash
cp .env.example .env
```

```env
DOCKER_USERNAME=your-dockerhub-username
DOCKER_TOKEN=dckr_pat_xxxxxxxxxxxxx
IMAGE_NAME=php-laravel-base
```

Get your Docker Hub token at: https://hub.docker.com/settings/security

### Build Commands

```bash
# Build locally for testing
./build.sh local 8.3

# Build and push single platform (fast)
./build.sh quick 8.3

# Push existing local image
./build.sh push 8.3

# Push all local images
./build.sh push-all

# Build and push multi-platform (amd64 + arm64)
./build.sh version 8.3

# Build and push ALL versions + latest
./build.sh all
```

## Docker Compose Example

```yaml
version: '3.8'

services:
  app:
    image: yourusername/php-laravel-base:8.3
    volumes:
      - ./:/var/www/html
    depends_on:
      - mysql
      - redis

  caddy:
    image: caddy:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./:/var/www/html
      - ./Caddyfile:/etc/caddy/Caddyfile

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: laravel
      MYSQL_ROOT_PASSWORD: secret

  redis:
    image: redis:alpine
```

## PHP Configuration

### Default Settings

```ini
memory_limit = 512M
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 300
max_input_vars = 5000
realpath_cache_size = 4096K
realpath_cache_ttl = 600
```

### Override Settings

Mount a custom PHP configuration:

```yaml
volumes:
  - ./php-custom.ini:/usr/local/etc/php/conf.d/99-custom.ini
```

## Image Sizes

| Tag | Size |
|-----|------|
| 8.2 | ~380MB |
| 8.3 | ~382MB |
| 8.4 | ~385MB |

## Tags

| Tag | PHP Version | Description |
|-----|-------------|-------------|
| `latest` | 8.4 | Latest stable |
| `8.4` | 8.4.x | PHP 8.4 |
| `8.3` | 8.3.x | PHP 8.3 (LTS recommended) |
| `8.2` | 8.2.x | PHP 8.2 |

## Running Tests

```bash
# Run PHPUnit
docker run --rm -v $(pwd):/var/www/html yourusername/php-laravel-base:8.3 phpunit

# Run Pest
docker run --rm -v $(pwd):/var/www/html yourusername/php-laravel-base:8.3 pest

# Run with coverage
docker run --rm -v $(pwd):/var/www/html yourusername/php-laravel-base:8.3 \
    pest --coverage
```

## Security

- Run as non-root user: `USER appuser`
- Minimal Alpine base image
- No unnecessary packages
- Regular security updates via base image

## License

MIT License

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Author

**Abdelilah EZZOUINI**  
📧 abdelilah.ezzouini@gmail.com

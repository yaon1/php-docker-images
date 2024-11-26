# php-docker-images

Production-ready PHP images on Alpine for **PHP 8.2 / 8.3 / 8.4**, `fpm` and `cli`, `amd64` and `arm64`.
Rebuilt weekly and scanned with Trivy.

```bash
docker pull ghcr.io/yaon1/php-docker-images:8.4-fpm       # production
docker pull ghcr.io/yaon1/php-docker-images:8.4-fpm-dev   # + Xdebug, php.ini-development
```

## What's inside

| | prod | dev |
|---|---|---|
| Extensions | bcmath, intl, opcache (JIT), pcntl, pdo_mysql, pdo_pgsql, redis, sockets, zip | same + xdebug |
| Composer 2 | ✓ | ✓ |
| User | `www-data` | `root` |
| OPcache timestamps | off | on |
| `php-fpm-healthcheck` | ✓ | ✓ |

## Configuration through env

| Variable | prod default | dev default |
|---|---|---|
| `PHP_MEMORY_LIMIT` | `256M` | `256M` |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` | `1` |
| `XDEBUG_MODE` | — | `off` (set `debug`, `coverage`, …) |

## Healthcheck

FPM images expose `/ping` and `/status`:

```yaml
services:
  app:
    image: ghcr.io/yaon1/php-docker-images:8.4-fpm
    healthcheck:
      test: php-fpm-healthcheck
      interval: 10s
```

`/status` works out of the box with [php-fpm-exporter](https://github.com/yaon1/php-fpm-exporter).

## Extending

```dockerfile
FROM ghcr.io/yaon1/php-docker-images:8.4-fpm
USER root
RUN install-php-extensions gd imagick
USER www-data
COPY --chown=www-data . /app
```

## Building locally

```bash
docker build --build-arg PHP_VERSION=8.3 --build-arg VARIANT=cli --target dev -t php:8.3-cli-dev .
tests/run.sh php:8.3-cli-dev cli dev
```

## License

MIT

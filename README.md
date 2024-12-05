# php-docker-images

**Готовые production-образы PHP, чтобы не собирать Dockerfile с расширениями в каждом проекте заново.** Внутри набор расширений, который нужен почти любому Laravel/Symfony-приложению, Composer, healthcheck для FPM и настройки через переменные окружения. Один образ подходит и для dev, и для prod.

- PHP **8.2 / 8.3 / 8.4**, варианты `fpm` и `cli`, архитектуры `amd64` и `arm64`.
- Еженедельная пересборка: свежие патчи безопасности из upstream.
- Сканирование Trivy в CI, результаты в GitHub Security.

## Пример использования

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/yaon1/php-docker-images:8.4-fpm
    volumes: ['./:/app']
    environment:
      PHP_MEMORY_LIMIT: 512M
    healthcheck:
      test: php-fpm-healthcheck
      interval: 10s
```

Для разработки, с Xdebug и `php.ini-development`:

```bash
docker run --rm -it -e XDEBUG_MODE=debug -v "$PWD:/app" ghcr.io/yaon1/php-docker-images:8.4-cli-dev php artisan test
```

Добавить своё расширение:

```dockerfile
FROM ghcr.io/yaon1/php-docker-images:8.4-fpm
USER root
RUN install-php-extensions gd imagick
USER www-data
COPY --chown=www-data . /app
```

## Что внутри

| | prod | dev |
|---|---|---|
| Расширения | bcmath, intl, opcache (JIT), pcntl, pdo_mysql, pdo_pgsql, redis, sockets, zip | то же + xdebug |
| Composer 2 | ✓ | ✓ |
| Пользователь | `www-data` | `root` |
| Проверка timestamps в OPcache | выкл | вкл |
| `php-fpm-healthcheck` | ✓ | ✓ |

FPM-образы отдают `/ping` и `/status`. `/status` сразу работает с [php-fpm-exporter](https://github.com/yaon1/php-fpm-exporter).

## Переменные окружения

| Переменная | prod | dev |
|---|---|---|
| `PHP_MEMORY_LIMIT` | `256M` | `256M` |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` | `1` |
| `XDEBUG_MODE` | — | `off` (`debug`, `coverage`, …) |

## Локальная сборка и тесты

```bash
docker build --build-arg PHP_VERSION=8.3 --build-arg VARIANT=cli --target dev -t php:8.3-cli-dev .
tests/run.sh php:8.3-cli-dev cli dev
```

## Лицензия

MIT

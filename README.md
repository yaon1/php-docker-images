# php-docker-images

**Готовые production-образы PHP, чтобы не собирать Dockerfile с расширениями в каждом проекте заново.** Внутри набор расширений, который нужен почти любому Laravel/Symfony-приложению, Composer, healthcheck для FPM и настройки через переменные окружения. Один образ подходит и для dev, и для prod.

- PHP **8.2 / 8.3 / 8.4 / 8.5**, варианты `fpm` и `cli`, архитектуры `amd64` и `arm64`.
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
RUN install-php-extensions mongodb   # gd/imagick уже есть в тегах -media
USER www-data
COPY --chown=www-data . /app
```

## Теги

`ghcr.io/yaon1/php-docker-images:<версия>-<вариант>[-debian][-dev|-media]`

| Часть | Значения |
|---|---|
| версия | `8.2`, `8.3`, `8.4`, `8.5` |
| вариант | `fpm`, `cli` |
| `-debian` | Debian (glibc) вместо Alpine (musl), если нужны бинарники или расширения, плохо работающие с musl |
| `-dev` | + Xdebug, `php.ini-development`, проверка изменений файлов |
| `-media` | + gd, imagick, exif для обработки изображений |
| `-YYYYMMDD` | Неизменяемый тег конкретной еженедельной сборки, например `8.4-fpm-20261020` |

## Что внутри

| | prod | dev | media |
|---|---|---|---|
| Расширения | bcmath, intl, opcache (JIT), pcntl, pdo_mysql, pdo_pgsql, redis, sockets, zip | + xdebug | + gd, imagick, exif |
| Composer 2 (домашняя папка доступна `www-data`) | ✓ | ✓ | ✓ |
| Пользователь | `www-data` | `root` | `www-data` |
| `HEALTHCHECK` | ✓ | — | ✓ |
| `php-fpm-healthcheck`, `wait-for` | ✓ | ✓ | ✓ |

Каждый опубликованный образ подписан cosign (keyless), содержит SBOM и provenance; публикация блокируется, если Trivy находит исправимые критические уязвимости.

```bash
cosign verify ghcr.io/yaon1/php-docker-images:8.4-fpm \
  --certificate-identity-regexp 'https://github.com/yaon1/php-docker-images/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Переменные окружения: PHP

| Переменная | По умолчанию | Директива |
|---|---|---|
| `PHP_MEMORY_LIMIT` | `256M` | `memory_limit` |
| `PHP_UPLOAD_MAX_FILESIZE` / `PHP_POST_MAX_SIZE` | `32M` | размер загрузок |
| `PHP_MAX_EXECUTION_TIME` | `30` | `max_execution_time` |
| `PHP_MAX_INPUT_VARS` | `1000` | `max_input_vars` |
| `PHP_DATE_TIMEZONE` | `UTC` | `date.timezone` |
| `PHP_SESSION_SAVE_HANDLER` / `PHP_SESSION_SAVE_PATH` | `files` / `/tmp` | сессии, например `redis` + `tcp://redis:6379` |
| `PHP_REALPATH_CACHE_SIZE` | `4096K` | кэш путей для фреймворков |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` (dev: `1`) | проверять изменения файлов |
| `PHP_OPCACHE_MEMORY` | `128` | `opcache.memory_consumption`, МБ |
| `PHP_OPCACHE_MAX_FILES` | `20000` | `opcache.max_accelerated_files` |
| `PHP_OPCACHE_JIT` | `tracing` | `opcache.jit` (`disable`, `function`, …) |
| `PHP_OPCACHE_PRELOAD` | — | путь к preload-скрипту |
| `PHP_OPCACHE_INTERNED_STRINGS` | `16` | `opcache.interned_strings_buffer`, МБ |
| `PHP_OPCACHE_ENABLE_CLI` | `0` | OPcache для долгоживущих CLI-воркеров |
| `PHP_DISPLAY_ERRORS` | `0` (dev: `1`) | `display_errors`; ошибки всегда пишутся в stderr контейнера |
| `PHP_ERROR_REPORTING` | `22527` (dev: `32767`) | `error_reporting` (`E_ALL & ~E_DEPRECATED & ~E_STRICT` / `E_ALL`) |
| `PHP_ZEND_ASSERTIONS` | `-1` (dev: `1`) | `zend.assertions` |
| `PHP_SESSION_COOKIE_SECURE` | `1` (dev: `0`) | cookie сессии только по HTTPS; также всегда HttpOnly, SameSite=Lax, strict mode |
| `PHP_ALLOW_URL_FOPEN` | `1` | `0` запрещает `file_get_contents('http://…')` |
| `PHP_DISABLE_FUNCTIONS` | — | например `exec,shell_exec,system` |
| `PHP_OPCACHE_JIT_BUFFER` | `64M` | `opcache.jit_buffer_size`; в dev JIT выключен (несовместим с Xdebug) |
| `XDEBUG_MODE` / `XDEBUG_CLIENT_HOST` | `off` / `host.docker.internal` | только dev-образы |

## Переменные окружения: PHP-FPM

| Переменная | По умолчанию | |
|---|---|---|
| `FPM_PM` | `dynamic` | `static`, `dynamic` или `ondemand` |
| `FPM_PM_MAX_CHILDREN` | `10` | Максимум воркеров; считайте как `память контейнера / память на запрос` |
| `FPM_PM_START_SERVERS`, `FPM_PM_MIN_SPARE_SERVERS`, `FPM_PM_MAX_SPARE_SERVERS` | `2`, `1`, `3` | Должно выполняться `min ≤ start ≤ max`, иначе FPM не стартует |
| `FPM_PM_MAX_REQUESTS` | `500` | Перезапуск воркера после N запросов (лечит утечки памяти) |
| `FPM_REQUEST_TERMINATE_TIMEOUT` | `60s` | Убить зависший запрос |
| `FPM_SLOWLOG_TIMEOUT` | `0s` (выкл.) | Стек медленных запросов в лог контейнера |
| `FPM_LISTEN` | `9000` | Порт или unix-сокет (`/run/php/fpm.sock`) |
| `FPM_STATUS_PATH` | `/status` | Страница статуса для [php-fpm-exporter](https://github.com/yaon1/php-fpm-exporter) |
| `FPM_ACCESS_LOG` | `/dev/null` | `/proc/self/fd/2`, чтобы включить |
| `FPM_SHUTDOWN_TIMEOUT` | `20s` | Сколько ждать текущие запросы при остановке |
| `FPM_PM_PROCESS_IDLE_TIMEOUT` | `10s` | Когда гасить простаивающие воркеры в `ondemand` |
| `FPM_RLIMIT_FILES` | `4096` | Лимит открытых файлов на воркер |

Переменные окружения контейнера доступны PHP-коду через `getenv()` и `$_ENV` (это проверяется тестом), поэтому `DATABASE_URL` и прочее можно передавать как обычно.

Контейнер останавливается сигналом `SIGQUIT`: FPM перестаёт принимать соединения и дожидается запросов в работе, поэтому деплой не обрывает их.

## Старт контейнера

Перед командой контейнер выполняет:

1. встроенные шаги, если включены переменными:

| Переменная | Что делает |
|---|---|
| `REQUIRED_ENV=APP_KEY,DATABASE_URL` | Не запускаться, если какая-то из переменных пуста |
| `WAIT_FOR=db:5432,redis:6379` (+ `WAIT_FOR_TIMEOUT=60`) | Ждёт, пока зависимости начнут принимать соединения |
| `LARAVEL_MIGRATE=1` / `LARAVEL_OPTIMIZE=1` | `php artisan migrate --force` / `php artisan optimize` |
| `SYMFONY_MIGRATE=1` / `SYMFONY_CACHE_WARMUP=1` | `doctrine:migrations:migrate` / `cache:warmup` |

2. ваши скрипты `*.sh` из `/docker-entrypoint.d` в порядке имён.

Если скрипт падает, контейнер не стартует, и сломанная миграция не уходит в трафик. `SKIP_ENTRYPOINT_HOOKS=1` пропускает все шаги. Отдельно доступна утилита `wait-for host:port 30`.

```yaml
services:
  app:
    image: ghcr.io/yaon1/php-docker-images:8.4-fpm
    environment:
      WAIT_FOR: postgres:5432
      LARAVEL_OPTIMIZE: 1
    volumes:
      - ./docker/entrypoint.d:/docker-entrypoint.d:ro
```

## Планировщик

В образе есть [supercronic](https://github.com/aptible/supercronic): cron для контейнеров с логами в stdout и корректной остановкой.

```yaml
scheduler:
  image: ghcr.io/yaon1/php-docker-images:8.4-cli
  command: ['/usr/local/bin/supercronic', '/app/docker/crontab']   # абсолютный путь обязателен
```

## Документация

- [Как подобрать настройки FPM](docs/tuning-fpm.md)
- [Переход с официального образа](docs/migrating-from-official.md)
- [Если что-то не так](docs/troubleshooting.md)
- [Расширения](docs/extensions.md) и [усиление безопасности](docs/hardening.md)
- Ещё примеры: [nginx с unix-сокетом](examples/nginx-unix-socket.conf), [CI в dev-образе](examples/github-actions-ci.yml)
- Примеры: [Laravel](examples/laravel/compose.yaml), [Symfony](examples/symfony/compose.yaml), [Kubernetes](examples/kubernetes/deployment.yaml)

## Локальная сборка и тесты

```bash
make test                          # 8.4 fpm prod: сборка и все проверки
make test PHP=8.5 VARIANT=cli TARGET=dev
docker buildx bake php84-fpm-media # готовые цели из docker-bake.hcl
make lint                          # shellcheck для скриптов образа
```

Тесты (`tests/run.sh`) запускают настоящие контейнеры: проверяют расширения, пользователя, каждую переменную окружения, хуки старта, `wait-for`, healthcheck и размер образа.

## Лицензия

MIT

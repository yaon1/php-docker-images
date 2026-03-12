# Переход с официального образа `php`

| Было (`php:8.4-fpm-alpine`) | Стало |
|---|---|
| `RUN docker-php-ext-install pdo_pgsql intl zip …` | Уже установлено; дополнительные — `install-php-extensions <ext>` |
| Свой `php.ini` с `memory_limit`, `upload_max_filesize` | Переменные `PHP_*` |
| Свой `www.conf` для `pm.max_children` | Переменные `FPM_*` |
| Скрипт `entrypoint.sh` с миграциями и ожиданием БД | `WAIT_FOR`, `LARAVEL_MIGRATE` / `SYMFONY_MIGRATE` или файлы в `/docker-entrypoint.d` |
| `HEALTHCHECK` через curl к nginx | Встроенный `php-fpm-healthcheck` |
| `USER root` по умолчанию | `www-data` в prod-образах |

Порядок перехода:

1. Замените `FROM` и удалите установку расширений, которые уже есть (`docker run --rm <образ> php -m`).
2. Перенесите значения из своих `.ini` и `www.conf` в `environment:`.
3. Если приложение пишет в каталоги внутри `/app`, проверьте права: процесс работает от `www-data`.
4. Проверьте сессии: cookie теперь `Secure` по умолчанию; для локального HTTP задайте `PHP_SESSION_COOKIE_SECURE=0` или используйте dev-тег.

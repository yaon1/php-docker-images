# Если что-то не так

| Симптом | Причина и решение |
|---|---|
| Контейнер сразу завершается без логов | Упал скрипт в `/docker-entrypoint.d` или `WAIT_FOR` не дождался зависимости. Запустите с `SKIP_ENTRYPOINT_HOOKS=1`, чтобы проверить |
| `pm.start_servers … must not be less than …` | Нарушено условие `FPM_PM_MIN_SPARE_SERVERS ≤ FPM_PM_START_SERVERS ≤ FPM_PM_MAX_SPARE_SERVERS` |
| `Permission denied` при записи в `/app/storage` или `var/` | Процесс работает от `www-data`; выдайте права каталогу (`chown -R www-data`) или смонтируйте volume |
| Изменения кода не видны | В prod OPcache не проверяет файлы. Для разработки используйте `-dev` или `PHP_OPCACHE_VALIDATE_TIMESTAMPS=1` |
| Сессия теряется на localhost | Cookie `Secure`, а сайт открыт по HTTP: `PHP_SESSION_COOKIE_SECURE=0` или dev-тег |
| Unhealthy при `FPM_LISTEN=/run/php/fpm.sock` | Обновите образ: healthcheck следует за `FPM_LISTEN` с версии 0.2 |
| `supercronic: Failed to fork exec` | Запускайте по абсолютному пути `/usr/local/bin/supercronic` |
| Xdebug не подключается | Проверьте `XDEBUG_MODE=debug`, порт 9003 в IDE и `XDEBUG_CLIENT_HOST` (на Linux — IP хоста) |

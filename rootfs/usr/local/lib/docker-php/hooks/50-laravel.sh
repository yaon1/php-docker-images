#!/bin/sh
# Laravel startup tasks, each opt-in:
#   LARAVEL_MIGRATE=1   php artisan migrate --force   (run in one replica or a release job, not every pod)
#   LARAVEL_OPTIMIZE=1  php artisan optimize          (config, routes, events, views caches)
set -e
[ -f artisan ] || exit 0
[ "${LARAVEL_MIGRATE:-0}" = 1 ] && php artisan migrate --force --no-interaction
[ "${LARAVEL_OPTIMIZE:-0}" = 1 ] && php artisan optimize --no-interaction
exit 0

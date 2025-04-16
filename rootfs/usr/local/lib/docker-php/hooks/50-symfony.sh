#!/bin/sh
# Symfony startup tasks, each opt-in:
#   SYMFONY_MIGRATE=1        doctrine:migrations:migrate
#   SYMFONY_CACHE_WARMUP=1   cache:warmup for the current APP_ENV
set -e
[ -f bin/console ] || exit 0
[ "${SYMFONY_MIGRATE:-0}" = 1 ] && php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration
[ "${SYMFONY_CACHE_WARMUP:-0}" = 1 ] && php bin/console cache:warmup --no-interaction
exit 0

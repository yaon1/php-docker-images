#!/bin/sh
# Usage: tests/run.sh <image> <variant: fpm|cli> <target: prod|dev>
set -eu
IMAGE=$1 VARIANT=$2 TARGET=$3
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

modules=$(docker run --rm --entrypoint php "$IMAGE" -m)
for ext in bcmath intl pcntl pdo_mysql pdo_pgsql redis sockets zip "Zend OPcache"; do
    echo "$modules" | grep -qx "$ext" || fail "missing extension $ext"
done

if [ "$TARGET" = dev ]; then
    echo "$modules" | grep -qx xdebug || fail "xdebug missing in dev"
else
    echo "$modules" | grep -qx xdebug && fail "xdebug present in prod"
    [ "$(docker run --rm --entrypoint id "$IMAGE" -un)" = www-data ] || fail "prod must run as www-data"
fi

docker run --rm --entrypoint composer "$IMAGE" --version >/dev/null || fail "composer missing"
ini_is PHP_MEMORY_LIMIT=64M memory_limit 64M
ini_default opcache.memory_consumption 128
ini_is PHP_OPCACHE_MEMORY=256 opcache.memory_consumption 256
fpm_conf_is "" listen 9000
fpm_conf_is FPM_LISTEN=/run/php/fpm.sock listen /run/php/fpm.sock
fpm_conf_is "" request_slowlog_timeout 0s
fpm_conf_is FPM_SLOWLOG_TIMEOUT=5s request_slowlog_timeout 5s
fpm_conf_is "" request_terminate_timeout 60s
fpm_conf_is FPM_REQUEST_TERMINATE_TIMEOUT=30s request_terminate_timeout 30s
fpm_conf_is "" pm.max_requests 500
fpm_conf_is FPM_PM_MAX_REQUESTS=1000 pm.max_requests 1000
fpm_conf_is "" request_terminate_timeout 60s
fpm_conf_is FPM_REQUEST_TERMINATE_TIMEOUT=30s request_terminate_timeout 30s
fpm_conf_is "" pm.max_requests 500
fpm_conf_is FPM_PM_MAX_REQUESTS=1000 pm.max_requests 1000
fpm_conf_is "" pm.max_spare_servers 3
fpm_conf_is FPM_PM_MAX_SPARE_SERVERS=6 pm.max_spare_servers 6
fpm_conf_is "" pm.min_spare_servers 1
fpm_conf_is FPM_PM_MIN_SPARE_SERVERS=2 pm.min_spare_servers 2
fpm_conf_is "" pm.start_servers 2
fpm_conf_is FPM_PM_START_SERVERS=3 pm.start_servers 3
fpm_conf_is "" pm.max_children 10
fpm_conf_is FPM_PM_MAX_CHILDREN=32 pm.max_children 32
fpm_conf_is "" pm dynamic
fpm_conf_is "" catch_workers_output yes
fpm_conf_is FPM_PM=ondemand pm ondemand
ini_default max_input_vars 1000
ini_is PHP_MAX_INPUT_VARS=5000 max_input_vars 5000
ini_default date.timezone UTC
ini_is PHP_DATE_TIMEZONE=Europe/Moscow date.timezone Europe/Moscow
fpm_ini_is "" max_execution_time 30
fpm_ini_is PHP_MAX_EXECUTION_TIME=120 max_execution_time 120
ini_default post_max_size 32M
ini_is PHP_POST_MAX_SIZE=100M post_max_size 100M
ini_default upload_max_filesize 32M
ini_is PHP_UPLOAD_MAX_FILESIZE=100M upload_max_filesize 100M

if [ "$VARIANT" = fpm ]; then
    cid=$(docker run -d "$IMAGE")
    trap 'docker rm -f "$cid" >/dev/null' EXIT
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        docker exec "$cid" php-fpm-healthcheck 2>/dev/null && break
        sleep 1
    done || fail "fpm healthcheck"
    docker exec "$cid" php-fpm-healthcheck || fail "fpm healthcheck"
fi

echo "OK $IMAGE"

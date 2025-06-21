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

if [ "$TARGET" = media ]; then
    for ext in gd imagick exif; do echo "$modules" | grep -qx "$ext" || fail "media image lacks $ext"; done
    pass "media extensions present"
fi

if [ "$TARGET" = dev ]; then
    echo "$modules" | grep -qx xdebug || fail "xdebug missing in dev"
else
    echo "$modules" | grep -qx xdebug && fail "xdebug present in prod"
    [ "$(docker run --rm --entrypoint id "$IMAGE" -un)" = www-data ] || fail "prod must run as www-data"
fi

docker run --rm --entrypoint composer "$IMAGE" --version >/dev/null || fail "composer missing"
ini_is PHP_MEMORY_LIMIT=64M memory_limit 64M
ini_default opcache.jit tracing
ini_is PHP_OPCACHE_JIT=disable opcache.jit disable
ini_default opcache.max_accelerated_files 20000
ini_is PHP_OPCACHE_MAX_FILES=50000 opcache.max_accelerated_files 50000
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

if [ "$VARIANT" = fpm ]; then
    out=$(docker run --rm -e PHP_OPCACHE_PRELOAD=/tmp/preload.php --entrypoint sh "$IMAGE" -c \
        'echo "<?php function preloaded_marker() {}" > /tmp/preload.php && php-fpm -tt >/dev/null 2>&1 && echo ok')
    [ "$out" = ok ] || fail "FPM should start with a preload script"
    pass "PHP_OPCACHE_PRELOAD accepted by FPM"
fi

hooks=$(mktemp -d)
printf '#!/bin/sh\necho hook-one > /tmp/order\n' > "$hooks/10-one.sh"
printf '#!/bin/sh\necho hook-two >> /tmp/order\n' > "$hooks/20-two.sh"
chmod +x "$hooks"/*.sh
order=$(docker run --rm -v "$hooks:/docker-entrypoint.d:ro" "$IMAGE" sh -c 'cat /tmp/order' 2>/dev/null | tr '\n' ' ')
[ "$order" = "hook-one hook-two " ] || fail "entrypoint hooks should run in order, got '$order'"
pass "entrypoint hooks run in name order"

printf '#!/bin/sh\nexit 3\n' > "$hooks/30-fail.sh" && chmod +x "$hooks/30-fail.sh"
if docker run --rm -v "$hooks:/docker-entrypoint.d:ro" "$IMAGE" true 2>/dev/null; then fail "a failing hook must stop the container"; fi
pass "failing hook stops the container"
skipped=$(docker run --rm -e SKIP_ENTRYPOINT_HOOKS=1 -v "$hooks:/docker-entrypoint.d:ro" "$IMAGE" echo started 2>/dev/null)
[ "$skipped" = started ] || fail "SKIP_ENTRYPOINT_HOOKS=1 should skip hooks"
pass "SKIP_ENTRYPOINT_HOOKS skips hooks"
rm -rf "$hooks"

docker run --rm --entrypoint wait-for "$IMAGE" 127.0.0.1:1 1 2>/dev/null && fail "wait-for should time out on a closed port"
pass "wait-for times out on closed ports"
up=$(docker run --rm --entrypoint sh "$IMAGE" -c 'php -S 127.0.0.1:8099 -t /tmp >/dev/null 2>&1 & wait-for 127.0.0.1:8099 5 && echo up')
[ "$up" = up ] || fail "wait-for should succeed once the port opens"
pass "wait-for succeeds when the port is open"

docker run --rm -e WAIT_FOR=127.0.0.1:1 -e WAIT_FOR_TIMEOUT=1 "$IMAGE" true 2>/dev/null && fail "WAIT_FOR should block startup"
pass "WAIT_FOR blocks startup until dependencies are up"

app=$(mktemp -d)
printf '<?php file_put_contents("/tmp/calls", implode(" ", array_slice($argv, 1)) . "\\n", FILE_APPEND);\n' > "$app/artisan"
calls=$(docker run --rm -v "$app:/app:ro" -e LARAVEL_MIGRATE=1 -e LARAVEL_OPTIMIZE=1 "$IMAGE" cat /tmp/calls 2>/dev/null | tr '\n' '|')
[ "$calls" = "migrate --force --no-interaction|optimize --no-interaction|" ] || fail "Laravel hooks ran '$calls'"
pass "LARAVEL_MIGRATE and LARAVEL_OPTIMIZE run artisan"
idle=$(docker run --rm -v "$app:/app:ro" "$IMAGE" sh -c 'cat /tmp/calls 2>/dev/null || echo none')
[ "$idle" = none ] || fail "Laravel hooks must be opt-in"
pass "Laravel hooks are opt-in"

mkdir -p "$app/bin" && rm "$app/artisan" && cp /dev/null "$app/bin/console"
printf '<?php file_put_contents("/tmp/calls", implode(" ", array_slice($argv, 1)) . "\\n", FILE_APPEND);\n' > "$app/bin/console"
calls=$(docker run --rm -v "$app:/app:ro" -e SYMFONY_CACHE_WARMUP=1 "$IMAGE" cat /tmp/calls 2>/dev/null | tr -d '\n')
[ "$calls" = "cache:warmup --no-interaction" ] || fail "Symfony hook ran '$calls'"
pass "SYMFONY_CACHE_WARMUP runs cache:warmup"
rm -rf "$app"

if [ "$TARGET" != dev ]; then
    hc=$(docker inspect --format '{{json .Config.Healthcheck.Test}}' "$IMAGE")
    case "$hc" in *php-fpm-healthcheck*) pass "image declares a HEALTHCHECK" ;; *) fail "missing HEALTHCHECK, got $hc" ;; esac
fi

src=$(docker inspect --format '{{index .Config.Labels "org.opencontainers.image.source"}}' "$IMAGE")
[ "$src" = https://github.com/yaon1/php-docker-images ] || fail "missing OCI source label"
pass "OCI labels present"

docker run --rm --entrypoint sh "$IMAGE" -c 'cd /tmp && printf "{\"require\":{}}" > composer.json && composer install --no-interaction -q' \
    || fail "composer install should work as the image user"
pass "composer install works as the image user"

[ "$(docker inspect --format '{{.Config.StopSignal}}' "$IMAGE")" = SIGQUIT ] || fail "stop signal should be SIGQUIT"
pass "graceful stop signal"
if [ "$VARIANT" = fpm ]; then
    t=$(docker run --rm --entrypoint php-fpm "$IMAGE" -tt 2>&1 | awk '$4 == "process_control_timeout" { print $6 }')
    [ "$t" = 20s ] || fail "process_control_timeout should default to 20s, got '$t'"
    pass "process_control_timeout = 20s"
fi

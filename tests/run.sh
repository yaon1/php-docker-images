#!/bin/sh
# Usage: tests/run.sh <image> <variant: fpm|cli> <target: prod|dev>
set -eu
IMAGE=$1 VARIANT=$2 TARGET=$3
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"


for case in extensions settings; do
    # shellcheck disable=SC1090
    . "$(dirname "$0")/cases/$case.sh"
done

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

# Keep the production image lean; a jump usually means build tools leaked into a layer.
size=$(docker image inspect --format '{{.Size}}' "$IMAGE")
# Debian's upstream base alone is ~500 MB, Alpine's ~100 MB.
if docker run --rm --entrypoint test "$IMAGE" -f /etc/alpine-release; then max_mb=350; else max_mb=800; fi
[ "$TARGET" = prod ] && [ "$size" -gt $((max_mb * 1024 * 1024)) ] && fail "image is $((size / 1024 / 1024)) MB, over $max_mb MB"
pass "image size $((size / 1024 / 1024)) MB"

if [ "$VARIANT" = fpm ]; then
    cid=$(docker run -d -e FPM_LISTEN=/run/php/fpm.sock "$IMAGE")
    ok=no
    for _ in 1 2 3 4 5 6 7 8 9 10; do docker exec "$cid" php-fpm-healthcheck 2>/dev/null && { ok=yes; break; }; sleep 1; done
    docker rm -f "$cid" >/dev/null
    [ "$ok" = yes ] || fail "healthcheck should follow FPM_LISTEN to the unix socket"
    pass "healthcheck works with a unix socket"
fi

crontab=$(mktemp)
echo '* * * * * echo tick' > "$crontab"
docker run --rm -v "$crontab:/etc/crontab:ro" --entrypoint /usr/local/bin/supercronic "$IMAGE" -test /etc/crontab >/dev/null 2>&1 \
    || fail "supercronic should validate a crontab"
pass "supercronic is available"
rm -f "$crontab"

if [ "$VARIANT" = fpm ]; then
    # Apps read DATABASE_URL & co. from the environment; FPM must not clear it.
    cid=$(docker run -d -e APP_SECRET_TEST=visible "$IMAGE")
    sleep 2
    seen=$(docker exec "$cid" sh -c 'echo "<?php echo getenv(\"APP_SECRET_TEST\");" > /tmp/env.php &&
        SCRIPT_FILENAME=/tmp/env.php SCRIPT_NAME=/env.php REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 | tail -1')
    docker rm -f "$cid" >/dev/null
    [ "$seen" = visible ] || fail "container env should reach PHP in FPM requests, got '$seen'"
    pass "environment variables reach FPM workers"
fi

docker run --rm -e REQUIRED_ENV=APP_KEY,DATABASE_URL -e APP_KEY=x "$IMAGE" true 2>/dev/null && fail "missing DATABASE_URL should stop the container"
out=$(docker run --rm -e REQUIRED_ENV=APP_KEY,DATABASE_URL -e APP_KEY=x "$IMAGE" true 2>&1 || true)
case "$out" in *DATABASE_URL*) pass "REQUIRED_ENV names missing variables" ;; *) fail "REQUIRED_ENV message should name DATABASE_URL" ;; esac
docker run --rm -e REQUIRED_ENV=APP_KEY -e APP_KEY=x "$IMAGE" true 2>/dev/null || fail "present variables should pass"
pass "REQUIRED_ENV passes when variables are set"

[ "$(docker run --rm --entrypoint printenv "$IMAGE" COMPOSER_NO_INTERACTION)" = 1 ] || fail "composer should run non-interactively"
pass "composer is non-interactive"

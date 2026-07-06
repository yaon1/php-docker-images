#!/bin/sh
# Sourced by tests/run.sh with IMAGE, VARIANT and TARGET set.
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

docker run --rm -e REQUIRED_ENV=APP_KEY,DATABASE_URL -e APP_KEY=x "$IMAGE" true 2>/dev/null && fail "missing DATABASE_URL should stop the container"
out=$(docker run --rm -e REQUIRED_ENV=APP_KEY,DATABASE_URL -e APP_KEY=x "$IMAGE" true 2>&1 || true)
case "$out" in *DATABASE_URL*) pass "REQUIRED_ENV names missing variables" ;; *) fail "REQUIRED_ENV message should name DATABASE_URL" ;; esac
docker run --rm -e REQUIRED_ENV=APP_KEY -e APP_KEY=x "$IMAGE" true 2>/dev/null || fail "present variables should pass"
pass "REQUIRED_ENV passes when variables are set"

#!/bin/sh
# Sourced by tests/run.sh with IMAGE, VARIANT and TARGET set.
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



[ "$(docker run --rm --entrypoint printenv "$IMAGE" COMPOSER_NO_INTERACTION)" = 1 ] || fail "composer should run non-interactively"
pass "composer is non-interactive"

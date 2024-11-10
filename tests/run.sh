#!/bin/sh
# Usage: tests/run.sh <image> <variant: fpm|cli> <target: prod|dev>
set -eu
IMAGE=$1 VARIANT=$2 TARGET=$3
fail() { echo "FAIL: $*" >&2; exit 1; }

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
docker run --rm -e PHP_MEMORY_LIMIT=64M --entrypoint php "$IMAGE" -r 'exit(ini_get("memory_limit") === "64M" ? 0 : 1);' \
    || fail "PHP_MEMORY_LIMIT not applied"

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

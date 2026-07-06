#!/bin/sh
# Sourced by tests/run.sh with IMAGE, VARIANT and TARGET set.
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
    ini_is XDEBUG_CLIENT_HOST=10.0.0.1 xdebug.client_host 10.0.0.1
    ini_default xdebug.start_with_request trigger
    ini_default display_errors 1
    ini_default zend.assertions 1
    ini_default opcache.jit disable
else
    echo "$modules" | grep -qx xdebug && fail "xdebug present in prod"
    [ "$(docker run --rm --entrypoint id "$IMAGE" -un)" = www-data ] || fail "prod must run as www-data"
fi

docker run --rm --entrypoint composer "$IMAGE" --version >/dev/null || fail "composer missing"

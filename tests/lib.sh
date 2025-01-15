#!/bin/sh
# Shared helpers for image tests. Expects IMAGE to be set.

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok   $*"; }

# ini_is ENV=VALUE DIRECTIVE EXPECTED: run php with the env var and compare ini_get()
ini_is() {
    actual=$(docker run --rm -e "$1" --entrypoint php "$IMAGE" -r "echo ini_get('$2');")
    [ "$actual" = "$3" ] || fail "$1 should set $2=$3, got '$actual'"
    pass "$1 → $2=$3"
}

# ini_default DIRECTIVE EXPECTED: value without any env override
ini_default() {
    actual=$(docker run --rm --entrypoint php "$IMAGE" -r "echo ini_get('$1');")
    [ "$actual" = "$2" ] || fail "default $1 should be $2, got '$actual'"
    pass "default $1=$2"
}

# fpm_ini_is ENV=VALUE DIRECTIVE EXPECTED: value as php-fpm sees it. Needed for directives
# the CLI SAPI forces (max_execution_time is always 0 in CLI). No-op for cli images.
fpm_ini_is() {
    [ "$VARIANT" = fpm ] || { pass "skip $2 check on cli"; return 0; }
    actual=$(docker run --rm ${1:+-e "$1"} --entrypoint php-fpm "$IMAGE" -i 2>/dev/null | awk -v d="$2" '$1 == d { print $3; exit }')
    [ "$actual" = "$3" ] || fail "${1:-default} should configure $2=$3 for FPM, got '$actual'"
    pass "${1:-default} → $2=$3 (php-fpm)"
}

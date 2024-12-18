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

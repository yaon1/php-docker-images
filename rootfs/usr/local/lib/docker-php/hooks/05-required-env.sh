#!/bin/sh
# REQUIRED_ENV=APP_KEY,DATABASE_URL: refuse to start when any listed variable is empty,
# instead of failing later on the first request with a confusing error.
[ -n "${REQUIRED_ENV:-}" ] || exit 0
missing=""
for name in $(echo "$REQUIRED_ENV" | tr ',' ' '); do
    eval "value=\${$name:-}"
    # shellcheck disable=SC2154 # value is assigned by eval above
    [ -n "$value" ] || missing="$missing $name"
done
if [ -n "$missing" ]; then
    echo "required environment variables are not set:$missing" >&2
    exit 1
fi

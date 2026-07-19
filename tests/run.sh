#!/bin/sh
# Usage: tests/run.sh <image> <variant: fpm|cli> <target: prod|dev|media>
set -eu
# Exported for the case files sourced below.
export IMAGE="$1" VARIANT="$2" TARGET="$3"
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"
for case in extensions settings startup image; do
    # shellcheck disable=SC1090
    . "$(dirname "$0")/cases/$case.sh"
done

echo "All checks passed for $IMAGE"

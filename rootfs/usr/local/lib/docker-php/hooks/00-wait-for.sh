#!/bin/sh
# WAIT_FOR=db:5432,redis:6379 [WAIT_FOR_TIMEOUT=60]: block startup until dependencies listen.
[ -n "${WAIT_FOR:-}" ] || exit 0
exec wait-for "$WAIT_FOR" "${WAIT_FOR_TIMEOUT:-60}"

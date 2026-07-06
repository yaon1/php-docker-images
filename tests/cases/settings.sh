#!/bin/sh
# Sourced by tests/run.sh with IMAGE, VARIANT and TARGET set.
ini_is PHP_MEMORY_LIMIT=64M memory_limit 64M
ini_default disable_functions ""
ini_is PHP_DISABLE_FUNCTIONS=exec,shell_exec disable_functions exec,shell_exec
ini_default opcache.jit_buffer_size 64M
ini_is PHP_OPCACHE_JIT_BUFFER=128M opcache.jit_buffer_size 128M
ini_default allow_url_fopen 1
ini_is PHP_ALLOW_URL_FOPEN=0 allow_url_fopen 0
[ "$TARGET" = dev ] || ini_default session.cookie_secure 1
ini_default session.cookie_httponly 1
ini_default session.use_strict_mode 1
ini_is PHP_SESSION_COOKIE_SECURE=0 session.cookie_secure 0
fpm_conf_is "" pm.process_idle_timeout 10
fpm_conf_is FPM_PM_PROCESS_IDLE_TIMEOUT=30s pm.process_idle_timeout 30
ini_default opcache.enable_cli 0
ini_is PHP_OPCACHE_ENABLE_CLI=1 opcache.enable_cli 1
[ "$TARGET" = dev ] || ini_default zend.assertions -1
ini_is PHP_ZEND_ASSERTIONS=1 zend.assertions 1
ini_default opcache.interned_strings_buffer 16
ini_is PHP_OPCACHE_INTERNED_STRINGS=32 opcache.interned_strings_buffer 32
[ "$TARGET" = dev ] || ini_default display_errors 0
ini_is PHP_DISPLAY_ERRORS=1 display_errors 1
ini_default realpath_cache_size 4096K
ini_is PHP_REALPATH_CACHE_SIZE=8M realpath_cache_size 8M
ini_default session.save_handler files
ini_is PHP_SESSION_SAVE_HANDLER=redis session.save_handler redis
fpm_conf_is "" access.log /dev/null
fpm_conf_is FPM_ACCESS_LOG=/proc/self/fd/2 access.log /proc/self/fd/2
fpm_conf_is "" pm.status_path /status
fpm_conf_is FPM_STATUS_PATH=/-/fpm-status pm.status_path /-/fpm-status
[ "$TARGET" = dev ] || ini_default opcache.jit tracing
ini_is PHP_OPCACHE_JIT=disable opcache.jit disable
ini_default opcache.max_accelerated_files 20000
ini_is PHP_OPCACHE_MAX_FILES=50000 opcache.max_accelerated_files 50000
ini_default opcache.memory_consumption 128
ini_is PHP_OPCACHE_MEMORY=256 opcache.memory_consumption 256
fpm_conf_is "" listen 9000
fpm_conf_is FPM_LISTEN=/run/php/fpm.sock listen /run/php/fpm.sock
fpm_conf_is "" request_slowlog_timeout 0s
fpm_conf_is FPM_SLOWLOG_TIMEOUT=5s request_slowlog_timeout 5s
fpm_conf_is "" request_terminate_timeout 60s
fpm_conf_is FPM_REQUEST_TERMINATE_TIMEOUT=30s request_terminate_timeout 30s
fpm_conf_is "" pm.max_requests 500
fpm_conf_is FPM_PM_MAX_REQUESTS=1000 pm.max_requests 1000
fpm_conf_is "" request_terminate_timeout 60s
fpm_conf_is FPM_REQUEST_TERMINATE_TIMEOUT=30s request_terminate_timeout 30s
fpm_conf_is "" pm.max_requests 500
fpm_conf_is FPM_PM_MAX_REQUESTS=1000 pm.max_requests 1000
fpm_conf_is "" pm.max_spare_servers 3
fpm_conf_is FPM_PM_MAX_SPARE_SERVERS=6 pm.max_spare_servers 6
fpm_conf_is "" pm.min_spare_servers 1
fpm_conf_is FPM_PM_MIN_SPARE_SERVERS=2 pm.min_spare_servers 2
fpm_conf_is "" pm.start_servers 2
fpm_conf_is FPM_PM_START_SERVERS=3 pm.start_servers 3
fpm_conf_is "" pm.max_children 10
fpm_conf_is FPM_PM_MAX_CHILDREN=32 pm.max_children 32
fpm_conf_is "" pm dynamic
fpm_conf_is "" catch_workers_output yes
fpm_conf_is FPM_PM=ondemand pm ondemand
ini_default max_input_vars 1000
ini_is PHP_MAX_INPUT_VARS=5000 max_input_vars 5000
ini_default date.timezone UTC
ini_is PHP_DATE_TIMEZONE=Europe/Moscow date.timezone Europe/Moscow
fpm_ini_is "" max_execution_time 30
fpm_ini_is PHP_MAX_EXECUTION_TIME=120 max_execution_time 120
ini_default post_max_size 32M
ini_is PHP_POST_MAX_SIZE=100M post_max_size 100M
ini_default upload_max_filesize 32M
ini_is PHP_UPLOAD_MAX_FILESIZE=100M upload_max_filesize 100M

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

if [ "$VARIANT" = fpm ]; then
    out=$(docker run --rm -e PHP_OPCACHE_PRELOAD=/tmp/preload.php --entrypoint sh "$IMAGE" -c \
        'echo "<?php function preloaded_marker() {}" > /tmp/preload.php && php-fpm -tt >/dev/null 2>&1 && echo ok')
    [ "$out" = ok ] || fail "FPM should start with a preload script"
    pass "PHP_OPCACHE_PRELOAD accepted by FPM"
fi

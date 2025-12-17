# syntax=docker/dockerfile:1.7
ARG PHP_VERSION=8.4
ARG VARIANT=fpm
# "-alpine" (small, musl) or "" for the Debian-based upstream image (glibc).
ARG DISTRO_SUFFIX=-alpine

FROM php:${PHP_VERSION}-${VARIANT}${DISTRO_SUFFIX} AS base
ARG PHP_VERSION
ARG VARIANT
LABEL org.opencontainers.image.title="php-${VARIANT}" \
      org.opencontainers.image.description="Production-ready PHP ${PHP_VERSION} ${VARIANT} image with common extensions" \
      org.opencontainers.image.source="https://github.com/yaon1/php-docker-images" \
      org.opencontainers.image.licenses="MIT"

COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
        bcmath \
        intl \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        redis \
        sockets \
        zip \
    && if command -v apk >/dev/null; then \
           apk add --no-cache fcgi; \
       else \
           apt-get update && apt-get install -y --no-install-recommends libfcgi-bin \
           && rm -rf /var/lib/apt/lists/*; \
       fi

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# supercronic: cron for containers (logs to stdout, no root, reacts to SIGTERM).
# Call it by absolute path: as PID 1 its process reaper re-executes argv[0].
ARG SUPERCRONIC_VERSION=0.2.33
ARG TARGETARCH
RUN arch=${TARGETARCH:-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')} \
    && curl -fsSL -o /usr/local/bin/supercronic \
       "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-${arch}" \
    && chmod +x /usr/local/bin/supercronic
COPY rootfs/ /
# Writable socket directory for FPM_LISTEN=/run/php/fpm.sock setups (nginx in the same pod).
RUN mkdir -p /run/php /docker-entrypoint.d && chown www-data:www-data /run/php

# Composer needs a writable home as www-data; keep its cache in a mountable location.
RUN mkdir -p /app /var/cache/composer /var/www/.composer && chown -R www-data:www-data /var/cache/composer /var/www/.composer /app
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/var/www/.composer \
    COMPOSER_CACHE_DIR=/var/cache/composer \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_MEMORY_LIMIT=256M \
    PHP_REALPATH_CACHE_SIZE=4096K \
    PHP_SESSION_SAVE_HANDLER=files \
    PHP_SESSION_SAVE_PATH=/tmp \
    FPM_ACCESS_LOG=/dev/null \
    FPM_STATUS_PATH=/status \
    FPM_SHUTDOWN_TIMEOUT=20s \
    PHP_OPCACHE_PRELOAD= \
    PHP_OPCACHE_JIT=tracing \
    PHP_OPCACHE_MAX_FILES=20000 \
    PHP_OPCACHE_MEMORY=128 \
    FPM_LISTEN=9000 \
    FPM_SLOWLOG_TIMEOUT=0 \
    FPM_REQUEST_TERMINATE_TIMEOUT=60s \
    FPM_PM_MAX_REQUESTS=500 \
    FPM_REQUEST_TERMINATE_TIMEOUT=60s \
    FPM_PM_MAX_REQUESTS=500 \
    FPM_PM_MAX_SPARE_SERVERS=3 \
    FPM_PM_MIN_SPARE_SERVERS=1 \
    FPM_PM_START_SERVERS=2 \
    FPM_PM_MAX_CHILDREN=10 \
    FPM_PM=dynamic \
    PHP_MAX_INPUT_VARS=1000 \
    PHP_DATE_TIMEZONE=UTC \
    PHP_MAX_EXECUTION_TIME=30 \
    PHP_POST_MAX_SIZE=32M \
    PHP_UPLOAD_MAX_FILESIZE=32M

WORKDIR /app
# php-fpm treats SIGQUIT as graceful stop (SIGTERM kills workers immediately).
STOPSIGNAL SIGQUIT

FROM base AS prod
USER www-data
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s \
    CMD if command -v php-fpm >/dev/null; then php-fpm-healthcheck; else php -v >/dev/null; fi

# Image processing on top of prod: thumbnails, EXIF orientation, PDF/HEIC via ImageMagick.
FROM base AS media
RUN install-php-extensions gd imagick exif
USER www-data
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s \
    CMD if command -v php-fpm >/dev/null; then php-fpm-healthcheck; else php -v >/dev/null; fi

FROM base AS dev
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    XDEBUG_MODE=off \
    XDEBUG_CLIENT_HOST=host.docker.internal
RUN install-php-extensions xdebug \
    && cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY dev/zz-xdebug.ini /usr/local/etc/php/conf.d/

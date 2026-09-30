# Changelog

## [0.2.0] — 2026-10-20

### Добавлено
- PHP 8.5, Debian-варианты (`-debian`), образы `-media` с gd, imagick и exif.
- Настройка PHP, OPcache и FPM через переменные окружения (`PHP_*`, `FPM_*`).
- Хуки старта: `/docker-entrypoint.d`, `WAIT_FOR`, шаги Laravel и Symfony; утилита `wait-for`.
- Корректная остановка FPM (`SIGQUIT`, `FPM_SHUTDOWN_TIMEOUT`), `HEALTHCHECK`, unix-сокет через `FPM_LISTEN`.
- supercronic, рабочие каталоги Composer для `www-data`, готовые настройки Xdebug в dev.
- OCI-метки, SBOM и provenance, подпись cosign, блокировка публикации при критичных CVE.
- `docker-bake.hcl`, Makefile, руководства и примеры для Laravel, Symfony и Kubernetes.

- `REQUIRED_ENV`, `PHP_DISABLE_FUNCTIONS`, `PHP_ALLOW_URL_FOPEN`, `PHP_ERROR_REPORTING`, `FPM_RLIMIT_FILES`, `PHP_OPCACHE_JIT_BUFFER`, датированные теги, hadolint в CI.

### Безопасность
- Cookie сессий: `Secure`, `HttpOnly`, `SameSite=Lax`, strict mode.

### Исправлено
- Healthcheck работает при прослушивании unix-сокета.
- В dev-образах снова показываются ошибки и включены assertions.
- В dev-образах выключен JIT: он несовместим с Xdebug и выдавал предупреждение.

## [0.1.0]

- Образы PHP 8.2–8.4 `fpm`/`cli`, `prod`/`dev`, сканирование Trivy, еженедельная пересборка.

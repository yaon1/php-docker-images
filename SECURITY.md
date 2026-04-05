# Безопасность

Об уязвимостях в образах сообщайте через [приватный advisory](https://github.com/yaon1/php-docker-images/security/advisories/new).

- Образы пересобираются еженедельно, чтобы подтянуть исправления из базовых образов Alpine/Debian и PHP.
- Публикация блокируется, если Trivy находит исправимые уязвимости уровня CRITICAL; отчёт уровня HIGH — во вкладке Security.
- Подлинность проверяется `cosign verify` (команда в README).
- Prod-образы работают от `www-data`; не запускайте их с `--privileged`.

# Усиление безопасности

Уже по умолчанию: пользователь `www-data`, `expose_php = Off`, cookie сессий `Secure`/`HttpOnly`/`SameSite=Lax`, strict mode сессий, assertions выключены.

Дополнительно, если приложение позволяет:

```yaml
environment:
  PHP_DISABLE_FUNCTIONS: exec,passthru,shell_exec,system,proc_open,popen
  PHP_ALLOW_URL_FOPEN: 0          # HTTP-запросы только через HTTP-клиент
read_only: true                    # корневая ФС только для чтения
tmpfs: [/tmp, /run/php]
cap_drop: [ALL]
security_opt: ['no-new-privileges:true']
```

- Проверяйте подпись образа перед деплоем (`cosign verify`, см. README) и закрепляйте тег по дате (`8.4-fpm-20261020`) или digest.
- `REQUIRED_ENV` не даст стартовать с пустыми секретами.
- Не включайте `PHP_DISPLAY_ERRORS` в продакшене: сообщения об ошибках раскрывают пути и запросы.

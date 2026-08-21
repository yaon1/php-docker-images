# Расширения

| Расширение | Зачем | prod | dev | media |
|---|---|---|---|---|
| bcmath | Точная арифметика (деньги, brick/math) | ✓ | ✓ | ✓ |
| intl | Локали, форматирование чисел и дат, транслитерация | ✓ | ✓ | ✓ |
| opcache | Кэш байткода и JIT | ✓ | ✓ | ✓ |
| pcntl | Сигналы для воркеров очередей (корректная остановка) | ✓ | ✓ | ✓ |
| pdo_mysql, pdo_pgsql | Базы данных | ✓ | ✓ | ✓ |
| redis | Кэш, сессии, очереди | ✓ | ✓ | ✓ |
| sockets | AMQP-клиенты, длинные соединения | ✓ | ✓ | ✓ |
| zip | Composer, экспорт файлов | ✓ | ✓ | ✓ |
| xdebug | Отладка и покрытие | | ✓ | |
| gd, imagick, exif | Изображения, PDF-превью, ориентация фото | | | ✓ |

## Добавить своё

```dockerfile
FROM ghcr.io/yaon1/php-docker-images:8.4-fpm
USER root
RUN install-php-extensions mongodb amqp
USER www-data
```

`install-php-extensions` ([mlocati](https://github.com/mlocati/docker-php-extension-installer)) уже в образе: он сам ставит системные зависимости и удаляет инструменты сборки.

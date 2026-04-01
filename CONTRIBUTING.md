# Как внести вклад

```bash
make test               # сборка 8.4 fpm prod и все проверки
make test TARGET=dev
make lint
```

- Новая настройка: строка в `rootfs/.../zz-*.ini` или `zz-*.conf` с `${VAR}`, значение по умолчанию в `ENV` Dockerfile, проверка в `tests/run.sh` (`ini_is`, `fpm_conf_is`) и строка в README.
- Скрипты в образе — POSIX `sh` (Alpine без bash), проверяются shellcheck.
- Изменения, увеличивающие prod-образ больше чем на 10 МБ, обоснуйте в PR.
- Коммиты в формате [Conventional Commits](https://www.conventionalcommits.org/ru/).

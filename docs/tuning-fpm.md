# Настройка PHP-FPM под контейнер

## Сколько воркеров

```
FPM_PM_MAX_CHILDREN = (лимит памяти контейнера − 50 МБ на FPM и OPcache) / память одного запроса
```

Память одного запроса берите из [php-fpm-exporter](https://github.com/yaon1/php-fpm-exporter) (`phpfpm_process_max_request_memory_bytes`) или из slowlog. Пример: 1 ГБ, запросы до 60 МБ → `(1024 − 50) / 60 ≈ 16`.

## Какой process manager

| Нагрузка | `FPM_PM` |
|---|---|
| Постоянный трафик, фиксированный лимит памяти (Kubernetes) | `static` — предсказуемо, без задержки на старт воркеров |
| Неровный трафик, память в дефиците | `dynamic` |
| Много маленьких пулов, редкие запросы | `ondemand` |

## Признаки, что пора менять

| Симптом | Что делать |
|---|---|
| `phpfpm_max_children_reached_total` растёт | Больше воркеров или больше реплик |
| Растёт `phpfpm_listen_queue` | То же, плюс искать медленные запросы (`FPM_SLOWLOG_TIMEOUT=3s`) |
| Память воркеров растёт со временем | Уменьшить `FPM_PM_MAX_REQUESTS` |
| 502 при деплое | Увеличить `FPM_SHUTDOWN_TIMEOUT` и `terminationGracePeriodSeconds` в Kubernetes |

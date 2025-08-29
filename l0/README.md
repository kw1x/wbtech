# Order Microservice

Микросервис на Go для получения заказов из Kafka, сохранения их в PostgreSQL и кэширования в памяти.

## Функционал
- Получение заказов из Kafka
- Сохранение заказов в PostgreSQL
- Кэширование заказов в памяти
- Восстановление кеша из БД при старте
- HTTP API для получения заказа по ID

## Запуск
1. Настройте переменные окружения:
   - `DATABASE_URL` — строка подключения к PostgreSQL
   - `KAFKA_BROKER` — адрес брокера Kafka
   - `KAFKA_TOPIC` — топик Kafka
2. Запустите сервис:
   ```sh
   go run main.go
   ```

## Эндпоинты
- `GET /order/{order_id}` — получить заказ по ID

## Зависимости
- [segmentio/kafka-go](https://github.com/segmentio/kafka-go)
- [jackc/pgx](https://github.com/jackc/pgx)
2025/08/20 18:08:40 📦 Received order from Kafka: test123
2025/08/20 18:08:40 💾 Order saved to DB: test123
2025/08/20 18:08:40 📦 Received order from Kafka: order_550264
2025/08/20 18:08:40 💾 Order saved to DB: order_550264
2025/08/20 18:08:40 📦 Received order from Kafka: order_259022
2025/08/20 18:08:40 💾 Order saved to DB: order_259022
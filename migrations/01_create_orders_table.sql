CREATE TABLE IF NOT EXISTS orders (
    order_uid TEXT PRIMARY KEY,
    data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Индекс для быстрого поиска по order_uid
CREATE INDEX IF NOT EXISTS idx_orders_order_uid ON orders(order_uid);

-- Индекс для JSONB полей (если нужен поиск по содержимому)
CREATE INDEX IF NOT EXISTS idx_orders_data ON orders USING GIN(data);

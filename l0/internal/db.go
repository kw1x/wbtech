package internal

import (
	"context"
	"encoding/json"

	"github.com/jackc/pgx/v4"
)

// Ожидается, что таблица orders создана так:
// CREATE TABLE orders (
//   order_uid TEXT PRIMARY KEY,
//   data JSONB NOT NULL
// );

func NewDB(connStr string) (*pgx.Conn, error) {
	return pgx.Connect(context.Background(), connStr)
}

func SaveOrder(conn *pgx.Conn, order Order) error {
	js, err := json.Marshal(order)
	if err != nil {
		return err
	}
	_, err = conn.Exec(context.Background(),
		`INSERT INTO orders (order_uid, data) VALUES ($1, $2)
		ON CONFLICT (order_uid) DO UPDATE SET data = EXCLUDED.data`,
		order.OrderUID, js)
	return err
}

func GetOrder(conn *pgx.Conn, id string) (Order, error) {
	row := conn.QueryRow(context.Background(), "SELECT data FROM orders WHERE order_uid=$1", id)
	var js []byte
	var o Order
	if err := row.Scan(&js); err != nil {
		return o, err
	}
	if err := json.Unmarshal(js, &o); err != nil {
		return o, err
	}
	return o, nil
}

func LoadOrders(conn *pgx.Conn) ([]Order, error) {
	rows, err := conn.Query(context.Background(), "SELECT data FROM orders")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var orders []Order
	for rows.Next() {
		var js []byte
		var o Order
		if err := rows.Scan(&js); err != nil {
			continue
		}
		if err := json.Unmarshal(js, &o); err != nil {
			continue
		}
		orders = append(orders, o)
	}
	return orders, nil
}

func GetAllOrders(conn *pgx.Conn) ([]Order, error) {
	return LoadOrders(conn)
}

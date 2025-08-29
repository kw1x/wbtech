package internal

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/segmentio/kafka-go"
	"log"
	"math/rand"
	"time"
)

func Consume(broker, topic string, handler func(Order)) {
	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers:     []string{broker},
		Topic:       topic,
		GroupID:     "order-consumer-group",
		MinBytes:    10e3,
		MaxBytes:    10e6,
		MaxWait:     1 * time.Second,
		StartOffset: kafka.FirstOffset,
	})
	defer r.Close()

	log.Printf("Starting Kafka consumer for broker: %s, topic: %s", broker, topic)

	for {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)

		m, err := r.ReadMessage(ctx)
		cancel()

		if err != nil {
			log.Printf("Kafka read error: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}

		log.Printf("Received message from Kafka: key=%s", string(m.Key))

		var order Order
		if err := json.Unmarshal(m.Value, &order); err != nil {
			log.Printf("Unmarshal error: %v", err)
			continue
		}

		handler(order)
	}
}

func GenerateAndSendOrder(broker, topic string) (string, error) {
	rand.Seed(time.Now().UnixNano())
	orderUID := fmt.Sprintf("%d", rand.Intn(1000000))
	order := Order{
		OrderUID:    orderUID,
		TrackNumber: "WBILMTESTTRACK",
		Entry:       "WBIL",
		Delivery: Delivery{
			Name:    "Test Testov",
			Phone:   "+9720000000",
			Zip:     "2639809",
			City:    "Kiryat Mozkin",
			Address: "Ploshad Mira 15",
			Region:  "Kraiot",
			Email:   "test@gmail.com",
		},
		Payment: Payment{
			Transaction:  orderUID,
			RequestID:    "",
			Currency:     "USD",
			Provider:     "wbpay",
			Amount:       1817,
			PaymentDT:    1637907727,
			Bank:         "alpha",
			DeliveryCost: 1500,
			GoodsTotal:   317,
			CustomFee:    0,
		},
		Items: []Item{
			{
				ChrtID:      9934930,
				TrackNumber: "WBILMTESTTRACK",
				Price:       453,
				Rid:         "ab4219087a764ae0btest",
				Name:        "Mascaras",
				Sale:        30,
				Size:        "0",
				TotalPrice:  317,
				NmID:        2389212,
				Brand:       "Vivienne Sabo",
				Status:      202,
			},
		},
		Locale:            "en",
		InternalSignature: "",
		CustomerID:        "test",
		DeliveryService:   "meest",
		ShardKey:          "9",
		SmID:              99,
		DateCreated:       time.Now().Format(time.RFC3339),
		OofShard:          "1",
	}

	orderJSON, err := json.Marshal(order)
	if err != nil {
		return "", fmt.Errorf("JSON marshal error: %w", err)
	}

	w := kafka.NewWriter(kafka.WriterConfig{
		Brokers: []string{broker},
		Topic:   topic,
	})
	defer w.Close()

	err = w.WriteMessages(context.Background(), kafka.Message{
		Key:   []byte(order.OrderUID),
		Value: orderJSON,
	})
	if err != nil {
		return "", fmt.Errorf("Kafka write error: %w", err)
	}

	log.Printf("Order sent to Kafka successfully: %s", order.OrderUID)
	log.Printf("Order JSON: %s", string(orderJSON))
	return orderUID, nil
}

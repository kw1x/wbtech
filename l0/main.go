package main

import (
	"context"
	"log"
	"os"
	"wbtech/l0/internal"

	_ "wbtech/l0/docs"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v4"
	"github.com/joho/godotenv"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

var dbConn *pgx.Conn
var orderCache *internal.Cache

// @title Order Service API
// @version 1.0
// @description Микросервис для заказов: Kafka, PostgreSQL, кэш, Gin, Swagger
// @host localhost:8080
// @BasePath /

func main() {
	// Загружаем переменные окружения из .env файла
	err := godotenv.Load()
	if err != nil {
		log.Println("Warning: .env file not found, using system environment variables")
	}

	var dbErr error
	dbConn, dbErr = internal.NewDB(os.Getenv("DATABASE_URL"))
	if dbErr != nil {
		log.Fatal(dbErr)
	}
	defer dbConn.Close(context.Background())

	orderCache = internal.NewCache()
	orders, err := internal.LoadOrders(dbConn)
	if err != nil {
		log.Fatal(err)
	}
	orderCache.Load(orders)

	log.Printf("Kafka Broker: %s", os.Getenv("KAFKA_BROKER"))
	log.Printf("Kafka Topic: %s", os.Getenv("KAFKA_TOPIC"))

	go internal.Consume(os.Getenv("KAFKA_BROKER"), os.Getenv("KAFKA_TOPIC"), func(order internal.Order) {
		log.Printf("📦 Received order from Kafka: %s", order.OrderUID)
		orderCache.Set(order.OrderUID, order)
		if err := internal.SaveOrder(dbConn, order); err != nil {
			log.Println("DB save error:", err)
		} else {
			log.Printf("💾 Order saved to DB: %s", order.OrderUID)
		}
	})

	r := gin.Default()
	
	// Статические файлы для frontend
	r.Static("/static", "./frontend")
	
	// Главная страница - возвращает frontend
	r.GET("/", func(c *gin.Context) {
		c.File("./frontend/index.html")
	})
	
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
	r.GET("/order/:id", GetOrderHandler)
	r.GET("/orders", GetAllOrdersHandler)
	r.POST("/orders/generate", GenerateOrderHandler)
	log.Println("HTTP server started on :8080")
	log.Fatal(r.Run(":8080"))
}

// @Summary Получить заказ по ID
// @Description Возвращает заказ по order_uid
// @Tags orders
// @Produce json
// @Param id path string true "Order UID"
// @Success 200 {object} internal.Order
// @Failure 404 {object} map[string]string
// @Router /order/{id} [get]
func GetOrderHandler(c *gin.Context) {
	orderUID := c.Param("id")
	order, ok := orderCache.Get(orderUID)
	if !ok {
		var err error
		order, err = internal.GetOrder(dbConn, orderUID)
		if err != nil {
			c.JSON(404, gin.H{"error": "order not found"})
			return
		}
		orderCache.Set(orderUID, order)
	}
	c.JSON(200, order)
}

// @Summary Получить все заказы
// @Description Возвращает список всех заказов
// @Tags orders
// @Produce json
// @Success 200 {array} internal.Order
// @Failure 500 {object} map[string]string
// @Router /orders [get]
func GetAllOrdersHandler(c *gin.Context) {
	orders := orderCache.GetAll()
	if len(orders) == 0 {
		var err error
		orders, err = internal.GetAllOrders(dbConn)
		if err != nil {
			c.JSON(500, gin.H{"error": "failed to retrieve orders"})
			return
		}
		orderCache.Load(orders)
	}
	c.JSON(200, orders)
}

// @Summary Сгенерировать и отправить заказ
// @Description Генерирует новый заказ и отправляет его в Kafka
// @Tags orders
// @Produce json
// @Success 200 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /orders/generate [post]
func GenerateOrderHandler(c *gin.Context) {
	orderUID, err := internal.GenerateAndSendOrder(os.Getenv("KAFKA_BROKER"), os.Getenv("KAFKA_TOPIC"))
	if err != nil {
		c.JSON(500, gin.H{"error": "failed to generate and send order"})
		return
	}
	c.JSON(200, gin.H{
		"status":    "order generated and sent",
		"order_uid": orderUID,
	})
}

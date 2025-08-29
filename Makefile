# Order Management System Makefile
# Автоматизация развертывания и управления проектом

# Переменные
COMPOSE_FILE := docker-compose.yml
PROJECT_NAME := l0
DB_NAME := ordersdb
DB_USER := postgres
DB_PASSWORD := postgres
KAFKA_TOPIC := orders
KAFKA_PARTITIONS := 1
KAFKA_REPLICATION := 1

# Цвета для вывода
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help build up down restart clean logs status init-db init-kafka init setup test health check-containers

# Помощь - показывает все доступные команды
help:
	@echo "$(BLUE)📦 Order Management System - Makefile Commands$(NC)"
	@echo ""
	@echo "$(GREEN)🚀 Основные команды:$(NC)"
	@echo "  make setup         - Полная инициализация проекта (сборка + запуск + инициализация)"
	@echo "  make up            - Запуск всех сервисов"
	@echo "  make down          - Остановка всех сервисов"
	@echo "  make restart       - Перезапуск всех сервисов"
	@echo "  make build         - Сборка образов"
	@echo ""
	@echo "$(GREEN)🛠️  Инициализация:$(NC)"
	@echo "  make init          - Инициализация БД и Kafka после запуска"
	@echo "  make init-db       - Создание таблиц в PostgreSQL"
	@echo "  make init-kafka    - Создание топиков в Kafka"
	@echo ""
	@echo "$(GREEN)🔍 Мониторинг:$(NC)"
	@echo "  make logs          - Просмотр логов всех сервисов"
	@echo "  make logs-app      - Просмотр логов приложения"
	@echo "  make logs-kafka    - Просмотр логов Kafka"
	@echo "  make logs-db       - Просмотр логов PostgreSQL"
	@echo "  make status        - Статус всех контейнеров"
	@echo "  make health        - Проверка здоровья сервисов"
	@echo ""
	@echo "$(GREEN)🧪 Тестирование:$(NC)"
	@echo "  make test          - Запуск тестов API"
	@echo "  make test-api      - Тестирование API endpoints"
	@echo "  make create-order  - Создание тестового заказа"
	@echo ""
	@echo "$(GREEN)🧹 Очистка:$(NC)"
	@echo "  make clean         - Полная очистка (остановка + удаление volumes)"
	@echo "  make clean-images  - Удаление образов проекта"
	@echo "  make clean-all     - Полная очистка всего"
	@echo "  make clear-orders  - Удаление всех заказов (БД + кэш)"

# Сборка образов
build:
	@echo "$(BLUE)🔨 Сборка образов...$(NC)"
	docker-compose -f $(COMPOSE_FILE) build

# Запуск всех сервисов
up:
	@echo "$(BLUE)🚀 Запуск сервисов...$(NC)"
	docker-compose -f $(COMPOSE_FILE) up -d

# Остановка всех сервисов
down:
	@echo "$(BLUE)⏹️  Остановка сервисов...$(NC)"
	docker-compose -f $(COMPOSE_FILE) down

# Перезапуск с пересборкой
restart:
	@echo "$(BLUE)🔄 Перезапуск сервисов...$(NC)"
	docker-compose -f $(COMPOSE_FILE) down
	docker-compose -f $(COMPOSE_FILE) up --build -d
	@sleep 5
	@make init

# Проверка запущенных контейнеров
check-containers:
	@echo "$(BLUE)🔍 Проверка контейнеров...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) ps

# Ожидание готовности PostgreSQL
wait-db:
	@echo "$(YELLOW)⏳ Ожидание готовности PostgreSQL...$(NC)"
	@timeout=30; \
	while [ $$timeout -gt 0 ]; do \
		if docker exec $(PROJECT_NAME)-postgres-1 pg_isready -h localhost -p 5432 -U $(DB_USER) >/dev/null 2>&1; then \
			echo "$(GREEN)✅ PostgreSQL готов!$(NC)"; \
			break; \
		fi; \
		echo "Ожидание PostgreSQL... ($$timeout сек)"; \
		sleep 2; \
		timeout=$$((timeout-2)); \
	done; \
	if [ $$timeout -le 0 ]; then \
		echo "$(RED)❌ Timeout: PostgreSQL не готов$(NC)"; \
		exit 1; \
	fi

# Ожидание готовности Kafka
wait-kafka:
	@echo "$(YELLOW)⏳ Ожидание готовности Kafka...$(NC)"
	@timeout=60; \
	while [ $$timeout -gt 0 ]; do \
		if docker exec $(PROJECT_NAME)-kafka-1 kafka-topics.sh --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then \
			echo "$(GREEN)✅ Kafka готов!$(NC)"; \
			break; \
		fi; \
		echo "Ожидание Kafka... ($$timeout сек)"; \
		sleep 3; \
		timeout=$$((timeout-3)); \
	done; \
	if [ $$timeout -le 0 ]; then \
		echo "$(RED)❌ Timeout: Kafka не готов$(NC)"; \
		exit 1; \
	fi

# Инициализация базы данных
init-db: wait-db
	@echo "$(BLUE)🗄️  Инициализация базы данных...$(NC)"
	@if docker exec $(PROJECT_NAME)-postgres-1 psql -U $(DB_USER) -d $(DB_NAME) -c "\dt" | grep -q "orders"; then \
		echo "$(YELLOW)⚠️  Таблица orders уже существует$(NC)"; \
	else \
		echo "$(GREEN)📋 Создание таблицы orders...$(NC)"; \
		docker exec $(PROJECT_NAME)-postgres-1 psql -U $(DB_USER) -d $(DB_NAME) -c " \
			CREATE TABLE IF NOT EXISTS orders ( \
				order_uid VARCHAR(255) PRIMARY KEY, \
				track_number VARCHAR(255), \
				entry VARCHAR(255), \
				locale VARCHAR(10), \
				internal_signature VARCHAR(255), \
				customer_id VARCHAR(255), \
				delivery_service VARCHAR(255), \
				shardkey VARCHAR(10), \
				sm_id INTEGER, \
				date_created TIMESTAMP, \
				oof_shard VARCHAR(10), \
				delivery_name VARCHAR(255), \
				delivery_phone VARCHAR(50), \
				delivery_zip VARCHAR(20), \
				delivery_city VARCHAR(255), \
				delivery_address TEXT, \
				delivery_region VARCHAR(255), \
				delivery_email VARCHAR(255), \
				payment_transaction VARCHAR(255), \
				payment_request_id VARCHAR(255), \
				payment_currency VARCHAR(10), \
				payment_provider VARCHAR(255), \
				payment_amount INTEGER, \
				payment_dt BIGINT, \
				payment_bank VARCHAR(255), \
				payment_delivery_cost INTEGER, \
				payment_goods_total INTEGER, \
				payment_custom_fee INTEGER, \
				items JSONB \
			);"; \
		echo "$(GREEN)✅ Таблица orders создана!$(NC)"; \
	fi

# Инициализация Kafka топиков
init-kafka: wait-kafka
	@echo "$(BLUE)📨 Инициализация Kafka топиков...$(NC)"
	@if docker exec $(PROJECT_NAME)-kafka-1 kafka-topics.sh --bootstrap-server localhost:9092 --list | grep -q "^$(KAFKA_TOPIC)$$"; then \
		echo "$(YELLOW)⚠️  Топик $(KAFKA_TOPIC) уже существует$(NC)"; \
	else \
		echo "$(GREEN)🎯 Создание топика $(KAFKA_TOPIC)...$(NC)"; \
		docker exec $(PROJECT_NAME)-kafka-1 kafka-topics.sh \
			--bootstrap-server localhost:9092 \
			--create \
			--topic $(KAFKA_TOPIC) \
			--partitions $(KAFKA_PARTITIONS) \
			--replication-factor $(KAFKA_REPLICATION); \
		echo "$(GREEN)✅ Топик $(KAFKA_TOPIC) создан!$(NC)"; \
	fi
	@echo "$(BLUE)📋 Список топиков:$(NC)"
	@docker exec $(PROJECT_NAME)-kafka-1 kafka-topics.sh --bootstrap-server localhost:9092 --list

# Полная инициализация
init: init-db init-kafka
	@echo "$(GREEN)🎉 Инициализация завершена!$(NC)"

# Полная настройка проекта
setup: down build up init
	@echo "$(GREEN)🚀 Проект полностью настроен и запущен!$(NC)"
	@echo ""
	@echo "$(BLUE)📍 Доступные URLs:$(NC)"
	@echo "  • Frontend:    http://localhost:8080"
	@echo "  • API:         http://localhost:8080/orders"
	@echo "  • Swagger:     http://localhost:8080/swagger/index.html"
	@echo "  • Kafka UI:    http://localhost:8081"
	@echo "  • PostgreSQL:  localhost:5432"
	@echo "  • Kafka:       localhost:9092"
	@echo ""
	@make health

# Просмотр логов
logs:
	@docker-compose -f $(COMPOSE_FILE) logs -f

logs-app:
	@docker-compose -f $(COMPOSE_FILE) logs -f app

logs-kafka:
	@docker-compose -f $(COMPOSE_FILE) logs -f kafka

logs-db:
	@docker-compose -f $(COMPOSE_FILE) logs -f postgres

# Статус контейнеров
status:
	@echo "$(BLUE)📊 Статус сервисов:$(NC)"
	@docker-compose -f $(COMPOSE_FILE) ps

# Проверка здоровья сервисов
health:
	@echo "$(BLUE)🏥 Проверка здоровья сервисов:$(NC)"
	@echo ""
	@echo "$(YELLOW)🐘 PostgreSQL:$(NC)"
	@if docker exec $(PROJECT_NAME)-postgres-1 pg_isready -h localhost -p 5432 -U $(DB_USER) >/dev/null 2>&1; then \
		echo "  $(GREEN)✅ PostgreSQL работает$(NC)"; \
	else \
		echo "  $(RED)❌ PostgreSQL недоступен$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)📨 Kafka:$(NC)"
	@if docker exec $(PROJECT_NAME)-kafka-1 kafka-topics.sh --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then \
		echo "  $(GREEN)✅ Kafka работает$(NC)"; \
		echo "  📋 Топики: $$(docker exec $(PROJECT_NAME)-kafka-1 kafka-topics.sh --bootstrap-server localhost:9092 --list | tr '\n' ' ')"; \
	else \
		echo "  $(RED)❌ Kafka недоступен$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)🚀 Application:$(NC)"
	@if curl -s http://localhost:8080/orders >/dev/null 2>&1; then \
		echo "  $(GREEN)✅ Application работает$(NC)"; \
		echo "  📊 Заказов в системе: $$(curl -s http://localhost:8080/orders | jq length 2>/dev/null || echo 'N/A')"; \
	else \
		echo "  $(RED)❌ Application недоступен$(NC)"; \
	fi

# Тестирование API
test-api:
	@echo "$(BLUE)🧪 Тестирование API endpoints...$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Получение всех заказов:$(NC)"
	@curl -s -w "Status: %{http_code}\n" http://localhost:8080/orders | head -3
	@echo ""
	@echo "$(YELLOW)2. Создание нового заказа:$(NC)"
	@curl -s -X POST -w "Status: %{http_code}\n" http://localhost:8080/orders/generate
	@echo ""

# Создание тестового заказа
create-order:
	@echo "$(BLUE)📦 Создание тестового заказа...$(NC)"
	@curl -X POST http://localhost:8080/orders/generate
	@echo ""

# Запуск тестов
test: test-api
	@echo "$(GREEN)✅ Тесты завершены$(NC)"

# Очистка всех заказов (БД + кэш)
clear-orders:
	@echo "$(BLUE)🗑️  Очистка всех заказов (БД + кэш)...$(NC)"
	@echo "$(RED)⚠️  Это удалит ВСЕ заказы из базы данных И кэша!$(NC)"
	@read -p "Продолжить? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(BLUE)1. Очистка базы данных...$(NC)"; \
		docker exec $(PROJECT_NAME)-postgres-1 psql -U $(DB_USER) -d $(DB_NAME) -c "DELETE FROM orders;" > /dev/null; \
		echo "$(BLUE)2. Перезапуск приложения (очистка кэша)...$(NC)"; \
		docker-compose restart app > /dev/null; \
		echo "$(GREEN)✅ Все заказы удалены (БД + кэш)$(NC)"; \
	else \
		echo "$(YELLOW)Операция отменена$(NC)"; \
	fi

# Очистка
clean:
	@echo "$(BLUE)🧹 Очистка проекта...$(NC)"
	docker-compose -f $(COMPOSE_FILE) down -v
	@echo "$(GREEN)✅ Очистка завершена$(NC)"

# Удаление образов
clean-images:
	@echo "$(BLUE)🗑️  Удаление образов проекта...$(NC)"
	docker rmi $(PROJECT_NAME)-app:latest 2>/dev/null || true
	@echo "$(GREEN)✅ Образы удалены$(NC)"

# Полная очистка
clean-all: clean clean-images
	@echo "$(GREEN)🎯 Полная очистка завершена$(NC)"

# Мониторинг в реальном времени
monitor:
	@echo "$(BLUE)📊 Мониторинг сервисов (Ctrl+C для выхода)...$(NC)"
	@while true; do \
		clear; \
		echo "$(BLUE)📊 Order Management System - Monitor$(NC)"; \
		echo "$(YELLOW)Время: $$(date)$(NC)"; \
		echo ""; \
		make status; \
		echo ""; \
		make health; \
		sleep 10; \
	done

# Быстрый перезапуск приложения (без пересборки инфраструктуры)
quick-restart:
	@echo "$(BLUE)⚡ Быстрый перезапуск приложения...$(NC)"
	docker-compose -f $(COMPOSE_FILE) restart app
	@sleep 3
	@make health

# Просмотр логов ошибок
logs-errors:
	@echo "$(BLUE)🔍 Поиск ошибок в логах...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) logs | grep -i "error\|fail\|exception" || echo "$(GREEN)Ошибок не найдено$(NC)"

# Backup базы данных
backup-db:
	@echo "$(BLUE)💾 Создание backup базы данных...$(NC)"
	@mkdir -p backups
	@docker exec $(PROJECT_NAME)-postgres-1 pg_dump -U $(DB_USER) $(DB_NAME) > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)✅ Backup создан в папке backups/$(NC)"

# Восстановление базы данных
restore-db:
	@echo "$(BLUE)🔄 Восстановление базы данных...$(NC)"
	@echo "$(RED)⚠️  Эта операция удалит все текущие данные!$(NC)"
	@read -p "Введите имя файла backup (в папке backups/): " backup_file; \
	if [ -f "backups/$$backup_file" ]; then \
		docker exec -i $(PROJECT_NAME)-postgres-1 psql -U $(DB_USER) -d $(DB_NAME) < backups/$$backup_file; \
		echo "$(GREEN)✅ База данных восстановлена$(NC)"; \
	else \
		echo "$(RED)❌ Файл backups/$$backup_file не найден$(NC)"; \
	fi

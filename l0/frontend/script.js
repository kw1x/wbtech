class OrderManager {
    constructor() {
        this.apiBase = ''; 
        this.orders = [];
        this.filteredOrders = [];
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadOrders();
    }

    setupEventListeners() {
        document.getElementById('searchBtn').addEventListener('click', () => {
            const searchTerm = document.getElementById('searchInput').value.trim();
            if (searchTerm) {
                this.searchOrderByUID(searchTerm);
            } else {
                this.showError('Введите Order UID для поиска');
            }
        });

        document.getElementById('refreshBtn').addEventListener('click', () => {
            document.getElementById('searchInput').value = '';
            this.loadOrders();
        });

        document.getElementById('createOrderBtn').addEventListener('click', () => {
            this.createOrder();
        });

        document.getElementById('searchInput').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                const searchTerm = e.target.value.trim();
                if (searchTerm) {
                    this.searchOrderByUID(searchTerm);
                } else {
                    this.showError('Введите Order UID для поиска');
                }
            }
        });
    }

    async loadOrders() {
        try {
            this.showLoading();
            this.hideMessages();
            
            const response = await fetch(`${this.apiBase}/orders`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            this.orders = await response.json() || [];
            this.filteredOrders = [...this.orders];
            this.renderOrders();
            this.updateStats();
            this.hideLoading();
        } catch (error) {
            this.hideLoading();
            this.showError(`Ошибка загрузки заказов: ${error.message}`);
            console.error('Error loading orders:', error);
        }
    }

    async createOrder() {
        try {
            const createBtn = document.getElementById('createOrderBtn');
            createBtn.disabled = true;
            createBtn.textContent = 'Создание...';
            
            const response = await fetch(`${this.apiBase}/orders/generate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            const result = await response.json();
            console.log('API Response:', result); // DEBUG
            this.showSuccess(`Заказ ${result.order_uid} успешно создан!`);
            
            // Быстрая перезагрузка без задержки
            this.loadOrders();
            
        } catch (error) {
            this.showError(`Ошибка создания заказа: ${error.message}`);
            console.error('Error creating order:', error);
        } finally {
            const createBtn = document.getElementById('createOrderBtn');
            createBtn.disabled = false;
            createBtn.textContent = 'Создать заказ';
        }
    }

    async searchOrderByUID(orderUID) {
        try {
            this.showLoading();
            this.hideMessages();
            
            const response = await fetch(`${this.apiBase}/order/${orderUID}`);
            if (response.status === 404) {
                this.orders = [];
                this.filteredOrders = [];
                this.renderOrders();
                this.updateStats();
                this.showError(`Заказ с ID "${orderUID}" не найден`);
                this.hideLoading();
                return;
            }
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            const order = await response.json();
            this.orders = [order]; 
            this.filteredOrders = [order];
            this.renderOrders();
            this.updateStats();
            this.showSuccess(`Найден заказ: ${orderUID}`);
            this.hideLoading();
        } catch (error) {
            this.hideLoading();
            this.showError(`Ошибка поиска заказа: ${error.message}`);
            console.error('Error searching order:', error);
        }
    }

    filterOrders(searchTerm) {
        if (!searchTerm.trim()) {
            this.filteredOrders = [...this.orders];
        } else {
            const term = searchTerm.toLowerCase();
            this.filteredOrders = this.orders.filter(order => 
                order.order_uid.toLowerCase().includes(term) ||
                order.delivery.name.toLowerCase().includes(term) ||
                order.delivery.phone.toLowerCase().includes(term) ||
                order.delivery.city.toLowerCase().includes(term) ||
                order.delivery.address.toLowerCase().includes(term) ||
                order.track_number.toLowerCase().includes(term)
            );
        }
        this.renderOrders();
        this.updateStats();
    }

    renderOrders() {
        const container = document.getElementById('ordersContainer');
        
        if (this.filteredOrders.length === 0) {
            container.innerHTML = '<div class="no-orders">Заказы не найдены</div>';
            return;
        }

        // Используем DocumentFragment для оптимизации DOM операций
        const fragment = document.createDocumentFragment();
        
        this.filteredOrders.forEach(order => {
            const orderCard = document.createElement('div');
            orderCard.className = 'order-card';
            orderCard.onclick = () => this.showOrderDetails(order.order_uid);
            
            orderCard.innerHTML = `
                <div class="order-header">
                    <div class="order-id">ID: ${order.order_uid}</div>
                    <div class="order-date">${this.formatDate(order.date_created)}</div>
                </div>
                
                <div class="order-info">
                    <strong>Получатель:</strong> 
                    <span>${order.delivery.name}</span>
                </div>
                
                <div class="order-info">
                    <strong>Адрес:</strong> 
                    <span>${order.delivery.address}, ${order.delivery.city}</span>
                </div>
            `;
            
            fragment.appendChild(orderCard);
        });
        
        // Одна DOM операция вместо множества
        container.innerHTML = '';
        container.appendChild(fragment);
    }

    async showOrderDetails(orderId) {
        try {
            const response = await fetch(`${this.apiBase}/order/${orderId}`);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            const order = await response.json();
            
            // Формируем детальную информацию о заказе
            const items = order.items.map(item => 
                `• ${item.name} (${item.brand}) - ${item.size || '1'}`
            ).join('\n');
            
            const details = `ДЕТАЛИ ЗАКАЗА ${orderId}
            
Основная информация:
• Трек номер: ${order.track_number}
• Точка входа: ${order.entry}
• Создан: ${this.formatDate(order.date_created)}
• Клиент: ${order.customer_id}

Доставка:
• Получатель: ${order.delivery.name}
• Телефон: ${order.delivery.phone}
• Email: ${order.delivery.email}
• Адрес: ${order.delivery.address}, ${order.delivery.city}
• Регион: ${order.delivery.region}
• Индекс: ${order.delivery.zip}
• Служба доставки: ${order.delivery_service}

Оплата:
• Транзакция: ${order.payment.transaction}
• Провайдер: ${order.payment.provider}
• Банк: ${order.payment.bank}
• Валюта: ${order.payment.currency}

Товары:
${items}`;
            
            alert(details);
        } catch (error) {
            this.showError(`Ошибка загрузки деталей заказа: ${error.message}`);
            console.error('Error loading order details:', error);
        }
    }

    updateStats() {
        const count = this.filteredOrders.length;
        const total = this.orders.length;
        
        document.getElementById('orderCount').textContent = 
            `Показано ${count} из ${total} заказов`;
    }

    formatDate(dateString) {
        try {
            const date = new Date(dateString);
            if (isNaN(date.getTime())) {
                return 'Дата не указана';
            }
            return date.toLocaleDateString('ru-RU') + ' ' + date.toLocaleTimeString('ru-RU', {
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch (error) {
            return 'Некорректная дата';
        }
    }

    showLoading() {
        document.getElementById('loadingMessage').style.display = 'block';
        document.getElementById('ordersContainer').style.display = 'none';
    }

    hideLoading() {
        document.getElementById('loadingMessage').style.display = 'none';
        document.getElementById('ordersContainer').style.display = 'grid';
    }

    showError(message) {
        const errorDiv = document.getElementById('errorMessage');
        errorDiv.innerHTML = `<div class="error">${message}</div>`;
        setTimeout(() => this.hideMessages(), 5000);
    }

    showSuccess(message) {
        console.log('showSuccess called with:', message); // DEBUG
        const successDiv = document.getElementById('successMessage');
        console.log('successDiv element:', successDiv); // DEBUG
        successDiv.innerHTML = `<div class="success">${message}</div>`;
        setTimeout(() => this.hideMessages(), 5000);
    }

    hideMessages() {
        document.getElementById('errorMessage').innerHTML = '';
        document.getElementById('successMessage').innerHTML = '';
    }


    startAutoRefresh(intervalMs = 30000) {
        setInterval(() => {
            this.loadOrders();
        }, intervalMs);
    }
}

document.addEventListener('DOMContentLoaded', function() {
    window.orderManager = new OrderManager();
    
});

if (typeof module !== 'undefined' && module.exports) {
    module.exports = OrderManager;
}

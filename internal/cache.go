package internal

import "sync"

type Cache struct {
	mu    sync.RWMutex
	items map[string]Order
}

func NewCache() *Cache {
	return &Cache{items: make(map[string]Order)}
}

func (c *Cache) Set(orderUID string, order Order) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.items[orderUID] = order
}

func (c *Cache) Get(orderUID string) (Order, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	order, ok := c.items[orderUID]
	return order, ok
}

func (c *Cache) Load(orders []Order) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, o := range orders {
		c.items[o.OrderUID] = o
	}
}

func (c *Cache) GetAll() []Order {
	c.mu.RLock()
	defer c.mu.RUnlock()
	orders := make([]Order, 0, len(c.items))
	for _, order := range c.items {
		orders = append(orders, order)
	}
	return orders
}

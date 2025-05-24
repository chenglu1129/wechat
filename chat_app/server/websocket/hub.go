package websocket

import (
	"log"
	"sync"
)

// Hub 维护活跃的客户端连接集合，并广播消息
type Hub struct {
	// 注册的客户端
	clients map[*Client]bool

	// 通过用户ID索引客户端
	userClients map[string]*Client

	// 从客户端接收的入站消息
	broadcast chan []byte

	// 注册请求
	register chan *Client

	// 注销请求
	unregister chan *Client

	// 互斥锁保护映射
	mu sync.RWMutex
}

// NewHub 创建一个新的Hub
func NewHub() *Hub {
	return &Hub{
		broadcast:   make(chan []byte),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
		clients:     make(map[*Client]bool),
		userClients: make(map[string]*Client),
		mu:          sync.RWMutex{},
	}
}

// Run 启动Hub处理循环
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			if client.userID != "" {
				h.userClients[client.userID] = client
			}
			h.mu.Unlock()
			log.Printf("新客户端连接。当前连接数: %d", len(h.clients))

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				if client.userID != "" {
					delete(h.userClients, client.userID)
				}
				close(client.send)
			}
			h.mu.Unlock()
			log.Printf("客户端断开连接。当前连接数: %d", len(h.clients))

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					h.mu.RUnlock()
					h.mu.Lock()
					delete(h.clients, client)
					if client.userID != "" {
						delete(h.userClients, client.userID)
					}
					h.mu.Unlock()
					h.mu.RLock()
				}
			}
			h.mu.RUnlock()
		}
	}
}

// SendToUser 发送消息给特定用户
func (h *Hub) SendToUser(userID string, message []byte) bool {
	h.mu.RLock()
	client, ok := h.userClients[userID]
	h.mu.RUnlock()

	if !ok {
		return false
	}

	select {
	case client.send <- message:
		return true
	default:
		h.mu.Lock()
		delete(h.clients, client)
		delete(h.userClients, userID)
		close(client.send)
		h.mu.Unlock()
		return false
	}
} 
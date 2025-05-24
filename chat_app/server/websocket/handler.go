package websocket

import (
	"log"
	"net/http"
	
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	// 允许所有CORS请求，生产环境应该限制
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// Handler 处理WebSocket连接
type Handler struct {
	hub *Hub
}

// NewHandler 创建一个新的WebSocket处理器
func NewHandler(hub *Hub) *Handler {
	return &Handler{hub: hub}
}

// HandleWebSocket 处理WebSocket连接请求
func (h *Handler) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	// 从请求中获取用户ID
	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		log.Println("WebSocket连接请求缺少user_id参数")
		http.Error(w, "缺少user_id参数", http.StatusBadRequest)
		return
	}
	
	// 升级HTTP连接为WebSocket连接
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("升级为WebSocket连接失败:", err)
		return
	}
	
	// 创建客户端
	client := NewClient(h.hub, conn, userID)
	
	// 注册客户端
	client.hub.register <- client
	
	// 启动goroutine处理消息
	go client.WritePump()
	go client.ReadPump()
	
	log.Printf("用户 %s 的WebSocket连接已建立", userID)
} 
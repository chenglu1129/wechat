package websocket

import (
	"bytes"
	"log"
	"time"
	
	"github.com/gorilla/websocket"
)

const (
	// 允许写入对等方的最大消息大小
	maxMessageSize = 8192

	// 写入对等方的时间
	writeWait = 10 * time.Second

	// 读取下一个pong消息的时间
	pongWait = 60 * time.Second

	// 在此期间向对等方发送ping
	pingPeriod = (pongWait * 9) / 10

	// 发送消息的缓冲区大小
	sendBufferSize = 256
)

var (
	newline = []byte{'\n'}
	space   = []byte{' '}
)

// Client 是websocket连接和hub之间的中间人
type Client struct {
	// Hub
	hub *Hub

	// WebSocket连接
	conn *websocket.Conn

	// 缓冲的发送消息通道
	send chan []byte
	
	// 用户ID
	userID string
}

// NewClient 创建一个新的客户端
func NewClient(hub *Hub, conn *websocket.Conn, userID string) *Client {
	return &Client{
		hub:    hub,
		conn:   conn,
		send:   make(chan []byte, sendBufferSize),
		userID: userID,
	}
}

// readPump 从WebSocket连接泵取消息并将其转发到hub
func (c *Client) ReadPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error { 
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil 
	})
	
	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("错误: %v", err)
			}
			break
		}
		message = bytes.TrimSpace(bytes.Replace(message, newline, space, -1))
		c.hub.broadcast <- message
	}
}

// writePump 将消息从hub泵送到WebSocket连接
func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	
	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// hub关闭了通道
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// 添加排队的聊天消息
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write(newline)
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
} 
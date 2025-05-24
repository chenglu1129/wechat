package database

import (
	"chat_app/server/config"
	
	"github.com/nats-io/nats.go"
)

// NATSDB 持有NATS连接
type NATSDB struct {
	Conn *nats.Conn
}

// NewNATSDB 创建新的NATS连接
func NewNATSDB(config *config.NATSConfig) (*NATSDB, error) {
	// 连接到NATS服务器
	conn, err := nats.Connect(config.URL)
	if err != nil {
		return nil, err
	}
	
	return &NATSDB{Conn: conn}, nil
}

// Close 关闭NATS连接
func (n *NATSDB) Close() error {
	n.Conn.Close()
	return nil
}

// PublishMessage 发布消息到指定主题
func (n *NATSDB) PublishMessage(subject string, data []byte) error {
	return n.Conn.Publish(subject, data)
}

// SubscribeToMessages 订阅指定主题的消息
func (n *NATSDB) SubscribeToMessages(subject string, callback func(*nats.Msg)) (*nats.Subscription, error) {
	return n.Conn.Subscribe(subject, callback)
}

// QueueSubscribeToMessages 队列订阅指定主题的消息
func (n *NATSDB) QueueSubscribeToMessages(subject, queue string, callback func(*nats.Msg)) (*nats.Subscription, error) {
	return n.Conn.QueueSubscribe(subject, queue, callback)
} 
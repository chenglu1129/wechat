package models

import (
	"time"
	
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// MessageType 消息类型
type MessageType string

const (
	// TextMessage 文本消息
	TextMessage MessageType = "text"
	
	// ImageMessage 图片消息
	ImageMessage MessageType = "image"
	
	// VideoMessage 视频消息
	VideoMessage MessageType = "video"
	
	// AudioMessage 音频消息
	AudioMessage MessageType = "audio"
	
	// FileMessage 文件消息
	FileMessage MessageType = "file"
	
	// LocationMessage 位置消息
	LocationMessage MessageType = "location"
	
	// SystemMessage 系统消息
	SystemMessage MessageType = "system"
)

// Message 表示聊天消息
type Message struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	SenderID  string             `bson:"sender_id" json:"sender_id"`
	ReceiverID string            `bson:"receiver_id,omitempty" json:"receiver_id,omitempty"`
	GroupID   string             `bson:"group_id,omitempty" json:"group_id,omitempty"`
	Type      MessageType        `bson:"type" json:"type"`
	Content   string             `bson:"content" json:"content"`
	MediaURL  string             `bson:"media_url,omitempty" json:"media_url,omitempty"`
	Timestamp time.Time          `bson:"timestamp" json:"timestamp"`
	Read      bool               `bson:"read" json:"read"`
	Metadata  map[string]interface{} `bson:"metadata,omitempty" json:"metadata,omitempty"`
}

// MessageRepository 定义消息相关的数据库操作接口
type MessageRepository interface {
	// 保存消息
	SaveMessage(message *Message) error
	
	// 获取单个消息
	GetMessageByID(id string) (*Message, error)
	
	// 获取两个用户之间的消息历史
	GetMessagesBetweenUsers(userID1, userID2 string, limit, offset int) ([]*Message, error)
	
	// 获取群组消息历史
	GetGroupMessages(groupID string, limit, offset int) ([]*Message, error)
	
	// 标记消息为已读
	MarkMessageAsRead(id string) error
	
	// 标记用户之间的所有消息为已读
	MarkAllMessagesAsReadBetweenUsers(senderID, receiverID string) error
	
	// 获取用户的未读消息数
	GetUnreadMessageCount(userID string) (int, error)
	
	// 删除消息
	DeleteMessage(id string) error
	
	// 删除两个用户之间的所有消息
	DeleteMessagesBetweenUsers(userID1, userID2 string) error
	
	// 删除群组的所有消息
	DeleteGroupMessages(groupID string) error
} 
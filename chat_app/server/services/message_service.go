package services

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"chat_app/server/database"
	"chat_app/server/models"
	"chat_app/server/websocket"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// MessageService 处理消息相关的业务逻辑
type MessageService struct {
	messageRepo models.MessageRepository
	redisDB     *database.RedisDB
	natsDB      *database.NATSDB
	wsHub       *websocket.Hub
}

// NewMessageService 创建新的消息服务
func NewMessageService(
	messageRepo models.MessageRepository,
	redisDB *database.RedisDB,
	natsDB *database.NATSDB,
	wsHub *websocket.Hub,
) *MessageService {
	return &MessageService{
		messageRepo: messageRepo,
		redisDB:     redisDB,
		natsDB:      natsDB,
		wsHub:       wsHub,
	}
}

// SendMessage 发送消息
func (s *MessageService) SendMessage(message *models.Message) error {
	// 设置消息ID和时间戳
	message.ID = primitive.NewObjectID()
	message.Timestamp = time.Now()
	message.Read = false

	// 保存消息到数据库
	err := s.messageRepo.SaveMessage(message)
	if err != nil {
		return err
	}

	// 将消息转换为JSON
	messageJSON, err := json.Marshal(message)
	if err != nil {
		return err
	}

	// 如果是私聊消息
	if message.ReceiverID != "" {
		// 检查接收者是否在线
		ctx := context.Background()
		isOnline, err := s.redisDB.IsUserOnline(ctx, message.ReceiverID)
		if err != nil {
			return err
		}

		// 如果接收者在线，通过WebSocket发送消息
		if isOnline {
			s.wsHub.SendToUser(message.ReceiverID, messageJSON)
		}

		// 无论如何都通过NATS发布消息，以便其他服务可以处理
		err = s.natsDB.PublishMessage("message.private."+message.ReceiverID, messageJSON)
		if err != nil {
			return err
		}
	} else if message.GroupID != "" {
		// 如果是群组消息，通过NATS发布
		err = s.natsDB.PublishMessage("message.group."+message.GroupID, messageJSON)
		if err != nil {
			return err
		}
	} else {
		return errors.New("消息必须指定接收者ID或群组ID")
	}

	return nil
}

// GetMessageHistory 获取消息历史
func (s *MessageService) GetMessageHistory(userID1, userID2 string, limit, offset int) ([]*models.Message, error) {
	// 打印请求参数
	println("获取私聊消息历史: 用户1=", userID1, "用户2=", userID2, "限制=", limit, "偏移=", offset)

	messages, err := s.messageRepo.GetMessagesBetweenUsers(userID1, userID2, limit, offset)
	if err != nil {
		println("获取消息历史失败:", err.Error())
		return nil, err
	}

	// 打印找到的消息数量
	println("找到", len(messages), "条私聊消息")

	// 确保消息按时间升序排序（从旧到新）
	// MongoDB已经按时间戳降序排序，所以这里需要反转
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, nil
}

// GetGroupMessageHistory 获取群组消息历史
func (s *MessageService) GetGroupMessageHistory(groupID string, limit, offset int) ([]*models.Message, error) {
	// 打印请求参数
	println("获取群组消息历史: 群组ID=", groupID, "限制=", limit, "偏移=", offset)

	messages, err := s.messageRepo.GetGroupMessages(groupID, limit, offset)
	if err != nil {
		println("获取群组消息历史失败:", err.Error())
		return nil, err
	}

	// 打印找到的消息数量
	println("找到", len(messages), "条群组消息")

	// 确保消息按时间升序排序（从旧到新）
	// MongoDB已经按时间戳降序排序，所以这里需要反转
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, nil
}

// MarkMessageAsRead 标记消息为已读
func (s *MessageService) MarkMessageAsRead(messageID string) error {
	return s.messageRepo.MarkMessageAsRead(messageID)
}

// MarkAllMessagesAsRead 标记用户之间的所有消息为已读
func (s *MessageService) MarkAllMessagesAsRead(senderID, receiverID string) error {
	return s.messageRepo.MarkAllMessagesAsReadBetweenUsers(senderID, receiverID)
}

// GetUnreadMessageCount 获取用户的未读消息数
func (s *MessageService) GetUnreadMessageCount(userID string) (int, error) {
	return s.messageRepo.GetUnreadMessageCount(userID)
}

// DeleteMessage 删除消息
func (s *MessageService) DeleteMessage(messageID string) error {
	return s.messageRepo.DeleteMessage(messageID)
}

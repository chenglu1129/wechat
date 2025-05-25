package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/go-redis/redis/v8"
)

// 用户FCM令牌信息
type UserFCMToken struct {
	UserID    string `json:"user_id"`
	Token     string `json:"token"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}

// FCM请求结构
type FCMRequest struct {
	To           string          `json:"to"`
	Notification FCMNotification `json:"notification"`
	Data         interface{}     `json:"data"`
}

// FCM通知结构
type FCMNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
	Image string `json:"image,omitempty"`
}

// 通知服务
type NotificationService struct {
	redisClient  *redis.Client
	fcmServerKey string
	fcmAPIURL    string
	mutex        sync.RWMutex
	userTokens   map[string]string // 用户ID到FCM令牌的映射
}

// 创建新的通知服务
func NewNotificationService(redisClient *redis.Client) *NotificationService {
	service := &NotificationService{
		redisClient:  redisClient,
		fcmServerKey: "YOUR_FCM_SERVER_KEY", // 需要替换为实际的FCM服务器密钥
		fcmAPIURL:    "https://fcm.googleapis.com/fcm/send",
		userTokens:   make(map[string]string),
	}

	// 从Redis加载用户令牌
	service.loadUserTokensFromRedis()

	return service
}

// 从Redis加载用户令牌
func (s *NotificationService) loadUserTokensFromRedis() {
	ctx := context.Background()
	keys, err := s.redisClient.Keys(ctx, "fcm_token:*").Result()
	if err != nil {
		log.Printf("无法从Redis加载FCM令牌: %v", err)
		return
	}

	for _, key := range keys {
		userID := key[10:] // 移除 "fcm_token:" 前缀
		token, err := s.redisClient.Get(ctx, key).Result()
		if err != nil {
			log.Printf("无法获取用户 %s 的FCM令牌: %v", userID, err)
			continue
		}

		s.mutex.Lock()
		s.userTokens[userID] = token
		s.mutex.Unlock()
	}

	log.Printf("从Redis加载了 %d 个用户FCM令牌", len(keys))
}

// 保存用户FCM令牌
func (s *NotificationService) SaveUserFCMToken(userID, token string) error {
	ctx := context.Background()
	key := fmt.Sprintf("fcm_token:%s", userID)

	// 存储到Redis
	err := s.redisClient.Set(ctx, key, token, 0).Err()
	if err != nil {
		return fmt.Errorf("保存FCM令牌到Redis失败: %v", err)
	}

	// 更新内存缓存
	s.mutex.Lock()
	s.userTokens[userID] = token
	s.mutex.Unlock()

	return nil
}

// 获取用户FCM令牌
func (s *NotificationService) GetUserFCMToken(userID string) (string, error) {
	// 先从内存缓存中查找
	s.mutex.RLock()
	token, exists := s.userTokens[userID]
	s.mutex.RUnlock()

	if exists {
		return token, nil
	}

	// 从Redis中查找
	ctx := context.Background()
	key := fmt.Sprintf("fcm_token:%s", userID)
	token, err := s.redisClient.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return "", fmt.Errorf("用户 %s 的FCM令牌不存在", userID)
		}
		return "", fmt.Errorf("从Redis获取FCM令牌失败: %v", err)
	}

	// 更新内存缓存
	s.mutex.Lock()
	s.userTokens[userID] = token
	s.mutex.Unlock()

	return token, nil
}

// 发送消息通知
func (s *NotificationService) SendChatMessageNotification(
	receiverID string,
	senderID string,
	senderName string,
	senderAvatar string,
	messageContent string,
) error {
	// 获取接收者的FCM令牌
	token, err := s.GetUserFCMToken(receiverID)
	if err != nil {
		return err
	}

	// 准备通知内容
	notification := FCMNotification{
		Title: senderName,
		Body:  messageContent,
	}

	// 准备数据负载
	data := map[string]string{
		"type":          "chat_message",
		"sender_id":     senderID,
		"sender_name":   senderName,
		"sender_avatar": senderAvatar,
	}

	// 发送通知
	return s.sendFCMNotification(token, notification, data)
}

// 发送好友请求通知
func (s *NotificationService) SendFriendRequestNotification(
	receiverID string,
	senderID string,
	senderName string,
) error {
	// 获取接收者的FCM令牌
	token, err := s.GetUserFCMToken(receiverID)
	if err != nil {
		return err
	}

	// 准备通知内容
	notification := FCMNotification{
		Title: "新的好友请求",
		Body:  fmt.Sprintf("%s 请求添加您为好友", senderName),
	}

	// 准备数据负载
	data := map[string]string{
		"type":        "friend_request",
		"sender_id":   senderID,
		"sender_name": senderName,
	}

	// 发送通知
	return s.sendFCMNotification(token, notification, data)
}

// 发送新联系人通知
func (s *NotificationService) SendNewContactNotification(
	receiverID string,
	contactID string,
	contactName string,
) error {
	// 获取接收者的FCM令牌
	token, err := s.GetUserFCMToken(receiverID)
	if err != nil {
		return err
	}

	// 准备通知内容
	notification := FCMNotification{
		Title: "添加联系人成功",
		Body:  fmt.Sprintf("%s 已成为您的联系人", contactName),
	}

	// 准备数据负载
	data := map[string]string{
		"type":         "new_contact",
		"contact_id":   contactID,
		"contact_name": contactName,
	}

	// 发送通知
	return s.sendFCMNotification(token, notification, data)
}

// 发送FCM通知
func (s *NotificationService) sendFCMNotification(
	token string,
	notification FCMNotification,
	data interface{},
) error {
	// 准备FCM请求
	request := FCMRequest{
		To:           token,
		Notification: notification,
		Data:         data,
	}

	// 转换为JSON
	payload, err := json.Marshal(request)
	if err != nil {
		return fmt.Errorf("JSON编码失败: %v", err)
	}

	// 创建HTTP请求
	req, err := http.NewRequest("POST", s.fcmAPIURL, bytes.NewBuffer(payload))
	if err != nil {
		return fmt.Errorf("创建HTTP请求失败: %v", err)
	}

	// 设置请求头
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("key=%s", s.fcmServerKey))

	// 发送请求
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("发送HTTP请求失败: %v", err)
	}
	defer resp.Body.Close()

	// 检查响应状态码
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("FCM服务器返回错误状态码: %d", resp.StatusCode)
	}

	return nil
}

// 删除用户FCM令牌
func (s *NotificationService) DeleteUserFCMToken(userID string) error {
	ctx := context.Background()
	key := fmt.Sprintf("fcm_token:%s", userID)

	// 从Redis中删除
	err := s.redisClient.Del(ctx, key).Err()
	if err != nil {
		return fmt.Errorf("从Redis删除FCM令牌失败: %v", err)
	}

	// 从内存缓存中删除
	s.mutex.Lock()
	delete(s.userTokens, userID)
	s.mutex.Unlock()

	return nil
}

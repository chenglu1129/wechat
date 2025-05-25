package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"chat_app/server/models"
	"chat_app/server/services"
	"chat_app/server/utils"
)

// MessageHandler 处理消息相关的API请求
type MessageHandler struct {
	messageService *services.MessageService
}

// NewMessageHandler 创建新的消息处理器
func NewMessageHandler(messageService *services.MessageService) *MessageHandler {
	return &MessageHandler{messageService: messageService}
}

// SendMessageRequest 发送消息请求
type SendMessageRequest struct {
	ReceiverID string             `json:"receiver_id,omitempty"`
	GroupID    string             `json:"group_id,omitempty"`
	Type       models.MessageType `json:"type"`
	Content    string             `json:"content"`
	MediaURL   string             `json:"media_url,omitempty"`
}

// SendMessage 处理发送消息请求
func (h *MessageHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	// 只接受POST请求
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 从请求头获取令牌
	tokenString := r.Header.Get("Authorization")
	if tokenString == "" {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 打印请求头信息（仅用于调试）
	println("SendMessage收到的Authorization头:", tokenString)

	// 提取令牌
	if strings.HasPrefix(tokenString, "Bearer ") {
		// 标准格式：Bearer {token}
		tokenString = strings.TrimPrefix(tokenString, "Bearer ")
	}

	// 验证令牌
	claims, err := utils.ParseToken(tokenString)
	if err != nil {
		println("SendMessage令牌解析错误:", err.Error())
		http.Error(w, "无效的令牌", http.StatusUnauthorized)
		return
	}

	// 解析请求
	var req SendMessageRequest
	err = json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	// 打印请求体（仅用于调试）
	requestBody, _ := json.Marshal(req)
	println("SendMessage请求体:", string(requestBody))

	// 验证请求
	if req.ReceiverID == "" && req.GroupID == "" {
		http.Error(w, "接收者ID或群组ID不能为空", http.StatusBadRequest)
		return
	}
	if req.Type == "" {
		req.Type = models.TextMessage
	}
	if req.Content == "" && req.MediaURL == "" {
		http.Error(w, "消息内容不能为空", http.StatusBadRequest)
		return
	}

	// 创建消息
	message := &models.Message{
		SenderID:   strconv.Itoa(claims.UserID),
		ReceiverID: req.ReceiverID,
		GroupID:    req.GroupID,
		Type:       req.Type,
		Content:    req.Content,
		MediaURL:   req.MediaURL,
	}

	// 发送消息
	err = h.messageService.SendMessage(message)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回响应
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(message)
}

// GetMessages 处理获取消息历史请求
func (h *MessageHandler) GetMessages(w http.ResponseWriter, r *http.Request) {
	// 只接受GET请求
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 从请求头获取令牌
	tokenString := r.Header.Get("Authorization")
	if tokenString == "" {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 打印请求头信息（仅用于调试）
	println("GetMessages收到的Authorization头:", tokenString)

	// 提取令牌
	if strings.HasPrefix(tokenString, "Bearer ") {
		// 标准格式：Bearer {token}
		tokenString = strings.TrimPrefix(tokenString, "Bearer ")
	}

	// 验证令牌
	claims, err := utils.ParseToken(tokenString)
	if err != nil {
		println("GetMessages令牌解析错误:", err.Error())
		http.Error(w, "无效的令牌", http.StatusUnauthorized)
		return
	}

	// 获取查询参数
	query := r.URL.Query()

	// 打印查询参数（仅用于调试）
	println("GetMessages查询参数:", r.URL.RawQuery)

	// 获取对话类型（私聊或群组）
	chatType := query.Get("type")

	// 获取分页参数
	limitStr := query.Get("limit")
	offsetStr := query.Get("offset")

	limit := 20 // 默认值
	offset := 0 // 默认值

	if limitStr != "" {
		limit, err = strconv.Atoi(limitStr)
		if err != nil || limit <= 0 {
			limit = 20
		}
	}

	if offsetStr != "" {
		offset, err = strconv.Atoi(offsetStr)
		if err != nil || offset < 0 {
			offset = 0
		}
	}

	var messages []*models.Message

	// 根据对话类型获取消息
	if chatType == "private" {
		// 获取对话对象ID
		receiverID := query.Get("receiver_id")
		if receiverID == "" {
			http.Error(w, "接收者ID不能为空", http.StatusBadRequest)
			return
		}

		println("获取私聊消息, 用户ID:", claims.UserID, "接收者ID:", receiverID)

		// 获取私聊消息
		messages, err = h.messageService.GetMessageHistory(strconv.Itoa(claims.UserID), receiverID, limit, offset)
		if err != nil {
			println("获取私聊消息失败:", err.Error())
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// 标记所有消息为已读
		err = h.messageService.MarkAllMessagesAsRead(receiverID, strconv.Itoa(claims.UserID))
		if err != nil {
			// 不中断流程，只记录错误
			println("标记消息为已读失败:", err.Error())
		}
	} else if chatType == "group" {
		// 获取群组ID
		groupID := query.Get("group_id")
		if groupID == "" {
			http.Error(w, "群组ID不能为空", http.StatusBadRequest)
			return
		}

		println("获取群组消息, 群组ID:", groupID)

		// 获取群组消息
		messages, err = h.messageService.GetGroupMessageHistory(groupID, limit, offset)
		if err != nil {
			println("获取群组消息失败:", err.Error())
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	} else {
		http.Error(w, "无效的对话类型", http.StatusBadRequest)
		return
	}

	// 返回响应
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(messages)
}

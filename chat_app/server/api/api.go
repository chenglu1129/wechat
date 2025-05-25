package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"

	"chat_app/server/services"
)

// API响应结构
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// API结构体
type API struct {
	UserService         *services.UserService
	ContactService      *services.ContactService
	NotificationService *services.NotificationService
}

// 创建新的API实例
func NewAPI(
	userService *services.UserService,
	contactService *services.ContactService,
	notificationService *services.NotificationService,
) *API {
	return &API{
		UserService:         userService,
		ContactService:      contactService,
		NotificationService: notificationService,
	}
}

// 从上下文中获取用户ID
func (a *API) GetUserIDFromContext(ctx context.Context) (int, error) {
	userIDVal := ctx.Value("user_id")
	if userIDVal == nil {
		return 0, fmt.Errorf("user_id not found in context")
	}

	userID, ok := userIDVal.(int)
	if !ok {
		// 尝试字符串转换
		userIDStr, ok := userIDVal.(string)
		if !ok {
			return 0, fmt.Errorf("user_id in context is not an int or string")
		}

		var err error
		userID, err = strconv.Atoi(userIDStr)
		if err != nil {
			return 0, fmt.Errorf("failed to convert user_id to int: %v", err)
		}
	}

	return userID, nil
}

// 响应JSON
func RespondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	response, err := json.Marshal(payload)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"success":false,"error":"Internal Server Error"}`))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}

// 响应错误
func RespondWithError(w http.ResponseWriter, code int, message string) {
	RespondWithJSON(w, code, APIResponse{
		Success: false,
		Error:   message,
	})
}

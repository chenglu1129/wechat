package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
)

// FCM令牌请求
type FCMTokenRequest struct {
	Token string `json:"token"`
}

// 保存FCM令牌
// @Summary 保存FCM令牌
// @Description 保存用户的FCM令牌，用于发送通知
// @Tags notification
// @Accept json
// @Produce json
// @Param token body FCMTokenRequest true "FCM令牌"
// @Success 200 {object} APIResponse
// @Failure 400 {object} APIResponse
// @Failure 401 {object} APIResponse
// @Failure 500 {object} APIResponse
// @Router /api/notifications/token [post]
func (a *API) SaveFCMToken(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := a.GetUserIDFromContext(r.Context())
	if err != nil {
		RespondWithError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// 解析请求体
	var req FCMTokenRequest
	decoder := json.NewDecoder(r.Body)
	if err := decoder.Decode(&req); err != nil {
		RespondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}
	defer r.Body.Close()

	// 验证令牌
	if req.Token == "" {
		RespondWithError(w, http.StatusBadRequest, "Token is required")
		return
	}

	// 保存令牌
	err = a.NotificationService.SaveUserFCMToken(strconv.Itoa(userID), req.Token)
	if err != nil {
		RespondWithError(w, http.StatusInternalServerError, "Failed to save FCM token")
		return
	}

	RespondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Message: "FCM token saved successfully",
	})
}

// 删除FCM令牌
// @Summary 删除FCM令牌
// @Description 删除用户的FCM令牌
// @Tags notification
// @Accept json
// @Produce json
// @Success 200 {object} APIResponse
// @Failure 401 {object} APIResponse
// @Failure 500 {object} APIResponse
// @Router /api/notifications/token [delete]
func (a *API) DeleteFCMToken(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := a.GetUserIDFromContext(r.Context())
	if err != nil {
		RespondWithError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// 删除令牌
	err = a.NotificationService.DeleteUserFCMToken(strconv.Itoa(userID))
	if err != nil {
		RespondWithError(w, http.StatusInternalServerError, "Failed to delete FCM token")
		return
	}

	RespondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Message: "FCM token deleted successfully",
	})
}

// TestSendNotification 发送测试通知
// @Summary 测试发送通知
// @Description 发送测试通知到指定用户
// @Tags notification
// @Accept json
// @Produce json
// @Param user_id path int true "用户ID"
// @Success 200 {object} APIResponse
// @Failure 400 {object} APIResponse
// @Failure 401 {object} APIResponse
// @Failure 500 {object} APIResponse
// @Router /api/notifications/test/{user_id} [post]
func (a *API) TestSendNotification(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	senderID, err := a.GetUserIDFromContext(r.Context())
	if err != nil {
		RespondWithError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// 获取接收者ID
	vars := mux.Vars(r)
	receiverIDStr, ok := vars["user_id"]
	if !ok {
		RespondWithError(w, http.StatusBadRequest, "User ID is required")
		return
	}

	receiverID, err := strconv.Atoi(receiverIDStr)
	if err != nil {
		RespondWithError(w, http.StatusBadRequest, "Invalid user ID")
		return
	}

	// 获取发送者信息
	user, err := a.UserService.GetUserByID(senderID)
	if err != nil {
		RespondWithError(w, http.StatusInternalServerError, "Failed to get user information")
		return
	}

	// 发送测试消息通知
	err = a.NotificationService.SendChatMessageNotification(
		strconv.Itoa(receiverID),
		strconv.Itoa(senderID),
		user.Username,
		user.AvatarURL, // AvatarURL可能为空，但这是允许的
		"这是一条测试消息，发送于 "+time.Now().Format("15:04:05"),
	)
	if err != nil {
		RespondWithError(w, http.StatusInternalServerError, "Failed to send notification: "+err.Error())
		return
	}

	RespondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Message: "Test notification sent successfully",
	})
}

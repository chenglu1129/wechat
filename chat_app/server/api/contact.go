package api

import (
	"encoding/json"
	"net/http"
	"strconv"

	"chat_app/server/services"
	"chat_app/server/utils"
)

// ContactHandler 处理联系人相关的API请求
type ContactHandler struct {
	contactService *services.ContactService
}

// NewContactHandler 创建新的联系人处理器
func NewContactHandler(contactService *services.ContactService) *ContactHandler {
	return &ContactHandler{contactService: contactService}
}

// ContactRequest 联系人请求结构
type ContactRequest struct {
	ContactID int `json:"contact_id"`
}

// SearchUserRequest 搜索用户请求
type SearchUserRequest struct {
	Query  string `json:"query"`
	Offset int    `json:"offset,omitempty"`
	Limit  int    `json:"limit,omitempty"`
}

// AddContact 添加联系人
func (h *ContactHandler) AddContact(w http.ResponseWriter, r *http.Request) {
	// 只允许POST方法
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 验证用户身份
	userID, err := utils.GetUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 解析请求体
	var req ContactRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求数据", http.StatusBadRequest)
		return
	}

	// 添加联系人
	err = h.contactService.AddContact(userID, req.ContactID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// 返回成功响应
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "联系人添加成功"})
}

// RemoveContact 删除联系人
func (h *ContactHandler) RemoveContact(w http.ResponseWriter, r *http.Request) {
	// 只允许DELETE方法
	if r.Method != http.MethodDelete {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 验证用户身份
	userID, err := utils.GetUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 从URL获取联系人ID
	contactIDStr := r.URL.Query().Get("contact_id")
	if contactIDStr == "" {
		http.Error(w, "缺少联系人ID", http.StatusBadRequest)
		return
	}

	contactID, err := strconv.Atoi(contactIDStr)
	if err != nil {
		http.Error(w, "无效的联系人ID", http.StatusBadRequest)
		return
	}

	// 删除联系人
	err = h.contactService.RemoveContact(userID, contactID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// 返回成功响应
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "联系人删除成功"})
}

// GetContacts 获取所有联系人
func (h *ContactHandler) GetContacts(w http.ResponseWriter, r *http.Request) {
	// 只允许GET方法
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 验证用户身份
	userID, err := utils.GetUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取联系人列表
	contacts, err := h.contactService.GetContacts(userID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回联系人列表
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(contacts)
}

// SearchUsers 搜索用户
func (h *ContactHandler) SearchUsers(w http.ResponseWriter, r *http.Request) {
	// 只允许POST方法
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 验证用户身份
	_, err := utils.GetUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 解析请求体
	var req SearchUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求数据", http.StatusBadRequest)
		return
	}

	// 设置默认值
	if req.Limit <= 0 {
		req.Limit = 20
	}

	// 搜索用户
	users, err := h.contactService.SearchUsers(req.Query, req.Offset, req.Limit)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回用户列表
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

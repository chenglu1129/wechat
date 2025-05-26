package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"chat_app/server/services"
)

// ContactHandler 处理联系人相关的请求
type ContactHandler struct {
	contactService *services.ContactService
}

// NewContactHandler 创建新的联系人处理器
func NewContactHandler(contactService *services.ContactService) *ContactHandler {
	return &ContactHandler{
		contactService: contactService,
	}
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

// SearchUsers 搜索用户
func (h *ContactHandler) SearchUsers(w http.ResponseWriter, r *http.Request) {
	// 获取查询参数
	query := r.URL.Query().Get("q")
	if query == "" {
		http.Error(w, "缺少查询参数", http.StatusBadRequest)
		return
	}

	// 获取分页参数
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page <= 0 {
		page = 1
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	// 搜索用户
	users, err := h.contactService.SearchUsers(query, page, limit)
	if err != nil {
		http.Error(w, "搜索用户失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回结果
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

// GetContacts 获取联系人列表
func (h *ContactHandler) GetContacts(w http.ResponseWriter, r *http.Request) {
	// 从上下文获取用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取联系人列表
	contacts, err := h.contactService.GetContacts(userID)
	if err != nil {
		http.Error(w, "获取联系人失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回联系人列表
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(contacts)
}

// AddContact 添加联系人
func (h *ContactHandler) AddContact(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 解析请求体
	var req struct {
		ContactID int `json:"contact_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	// 验证联系人ID
	if req.ContactID <= 0 {
		http.Error(w, "无效的联系人ID", http.StatusBadRequest)
		return
	}

	// 添加联系人
	err = h.contactService.AddContact(userID, req.ContactID)
	if err != nil {
		// 检查是否是已存在的联系人
		if strings.Contains(err.Error(), "已经是联系人") {
			http.Error(w, err.Error(), http.StatusConflict)
			return
		}
		http.Error(w, "添加联系人失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回成功
	w.WriteHeader(http.StatusCreated)
}

// RemoveContact 移除联系人
func (h *ContactHandler) RemoveContact(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 解析请求体
	var req struct {
		ContactID int `json:"contact_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	// 验证联系人ID
	if req.ContactID <= 0 {
		http.Error(w, "无效的联系人ID", http.StatusBadRequest)
		return
	}

	// 移除联系人
	err = h.contactService.RemoveContact(userID, req.ContactID)
	if err != nil {
		http.Error(w, "移除联系人失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回成功
	w.WriteHeader(http.StatusOK)
}

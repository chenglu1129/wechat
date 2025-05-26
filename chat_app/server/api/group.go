package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"

	"chat_app/server/models"
	"chat_app/server/services"
)

// GroupHandler 处理群组相关的API请求
type GroupHandler struct {
	groupService *services.GroupService
}

// NewGroupHandler 创建新的群组处理器
func NewGroupHandler(groupService *services.GroupService) *GroupHandler {
	return &GroupHandler{
		groupService: groupService,
	}
}

// RegisterRoutes 注册群组相关的路由
func (h *GroupHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/groups", h.CreateGroup).Methods("POST")
	r.HandleFunc("/groups/user", h.GetUserGroups).Methods("GET")
	r.HandleFunc("/groups/{id}", h.GetGroupInfo).Methods("GET")
	r.HandleFunc("/groups/{id}", h.UpdateGroup).Methods("PUT")
	r.HandleFunc("/groups/{id}", h.DeleteGroup).Methods("DELETE")
	r.HandleFunc("/groups/{id}/members", h.GetGroupMembers).Methods("GET")
	r.HandleFunc("/groups/{id}/members", h.AddGroupMembers).Methods("POST")
	r.HandleFunc("/groups/{id}/members/{userId}", h.RemoveGroupMember).Methods("DELETE")
	r.HandleFunc("/groups/{id}/members/{userId}/admin", h.SetGroupAdmin).Methods("PUT")
	r.HandleFunc("/groups/{id}/leave", h.LeaveGroup).Methods("DELETE")
	r.HandleFunc("/groups/avatar", h.UploadGroupAvatar).Methods("POST")
}

// CreateGroup 创建新群组
func (h *GroupHandler) CreateGroup(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 解析请求体
	var req struct {
		Name      string `json:"name"`
		MemberIDs []int  `json:"member_ids"`
		AvatarURL string `json:"avatar_url,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	// 验证群组名称
	if req.Name == "" {
		http.Error(w, "群组名称不能为空", http.StatusBadRequest)
		return
	}

	// 创建群组
	group := &models.Group{
		Name:      req.Name,
		CreatedBy: userID,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	// 调用服务创建群组
	err = h.groupService.CreateGroup(group, req.MemberIDs)
	if err != nil {
		http.Error(w, "创建群组失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 计算成员数量（创建者 + 成员）
	memberCount := len(req.MemberIDs) + 1

	// 返回创建的群组信息，包括成员数量
	response := map[string]interface{}{
		"id":           group.ID,
		"name":         group.Name,
		"created_by":   group.CreatedBy,
		"created_at":   group.CreatedAt,
		"updated_at":   group.UpdatedAt,
		"member_count": memberCount,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

// GetUserGroups 获取用户加入的群组
func (h *GroupHandler) GetUserGroups(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取用户加入的群组
	groups, err := h.groupService.GetUserGroups(userID)
	if err != nil {
		http.Error(w, "获取群组失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 为每个群组添加成员数量
	var response []map[string]interface{}
	for _, group := range groups {
		memberCount, err := h.groupService.GetGroupMemberCount(group.ID)
		if err != nil {
			http.Error(w, "获取群组成员数量失败: "+err.Error(), http.StatusInternalServerError)
			return
		}

		response = append(response, map[string]interface{}{
			"id":           group.ID,
			"name":         group.Name,
			"created_by":   group.CreatedBy,
			"created_at":   group.CreatedAt,
			"updated_at":   group.UpdatedAt,
			"member_count": memberCount,
		})
	}

	// 返回群组列表
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// GetGroupInfo 获取群组信息
func (h *GroupHandler) GetGroupInfo(w http.ResponseWriter, r *http.Request) {
	// 获取群组ID
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "无效的群组ID", http.StatusBadRequest)
		return
	}

	// 获取群组信息
	group, err := h.groupService.GetGroupByID(groupID)
	if err != nil {
		http.Error(w, "获取群组信息失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 获取群组成员数量
	memberCount, err := h.groupService.GetGroupMemberCount(groupID)
	if err != nil {
		http.Error(w, "获取群组成员数量失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 将成员数量添加到响应中
	response := map[string]interface{}{
		"id":           group.ID,
		"name":         group.Name,
		"created_by":   group.CreatedBy,
		"created_at":   group.CreatedAt,
		"updated_at":   group.UpdatedAt,
		"member_count": memberCount,
	}

	// 返回群组信息
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// UpdateGroup 更新群组信息
func (h *GroupHandler) UpdateGroup(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取群组ID
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "无效的群组ID", http.StatusBadRequest)
		return
	}

	// 检查用户是否为群组管理员
	isAdmin, err := h.groupService.IsGroupAdmin(groupID, userID)
	if err != nil {
		http.Error(w, "检查权限失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	if !isAdmin {
		http.Error(w, "没有权限更新群组信息", http.StatusForbidden)
		return
	}

	// 解析请求体
	var req struct {
		Name         string `json:"name,omitempty"`
		Announcement string `json:"announcement,omitempty"`
		AvatarURL    string `json:"avatar_url,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	// 获取群组信息
	group, err := h.groupService.GetGroupByID(groupID)
	if err != nil {
		http.Error(w, "获取群组信息失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 更新群组信息
	if req.Name != "" {
		group.Name = req.Name
	}
	group.UpdatedAt = time.Now()

	// 调用服务更新群组
	err = h.groupService.UpdateGroup(group)
	if err != nil {
		http.Error(w, "更新群组失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回更新后的群组信息
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(group)
}

// DeleteGroup 删除群组
func (h *GroupHandler) DeleteGroup(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取群组ID
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "无效的群组ID", http.StatusBadRequest)
		return
	}

	// 获取群组信息
	group, err := h.groupService.GetGroupByID(groupID)
	if err != nil {
		http.Error(w, "获取群组信息失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 检查用户是否为群主
	if group.CreatedBy != userID {
		http.Error(w, "只有群主可以解散群组", http.StatusForbidden)
		return
	}

	// 调用服务删除群组
	err = h.groupService.DeleteGroup(groupID)
	if err != nil {
		http.Error(w, "删除群组失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回成功
	w.WriteHeader(http.StatusNoContent)
}

// GetGroupMembers 获取群组成员
func (h *GroupHandler) GetGroupMembers(w http.ResponseWriter, r *http.Request) {
	// 获取群组ID
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "无效的群组ID", http.StatusBadRequest)
		return
	}

	// 获取群组信息以确定群主
	group, err := h.groupService.GetGroupByID(groupID)
	if err != nil {
		http.Error(w, "获取群组信息失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 获取群组成员
	users, err := h.groupService.GetGroupMembers(groupID)
	if err != nil {
		http.Error(w, "获取群组成员失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 获取群组管理员列表
	admins, err := h.groupService.GetGroupAdmins(groupID)
	if err != nil {
		http.Error(w, "获取群组管理员失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 构建管理员ID集合，方便查询
	adminMap := make(map[int]bool)
	for _, admin := range admins {
		adminMap[admin.ID] = true
	}

	// 构建完整的成员信息列表
	var members []map[string]interface{}
	for _, user := range users {
		// 确定用户角色
		var role string
		if user.ID == group.CreatedBy {
			role = "owner"
		} else if adminMap[user.ID] {
			role = "admin"
		} else {
			role = "member"
		}

		// 获取加入时间
		joinedAt := time.Now()
		if user.Metadata != nil {
			if joinedAtValue, ok := user.Metadata["joined_at"]; ok {
				if joinedAtTime, ok := joinedAtValue.(time.Time); ok {
					joinedAt = joinedAtTime
				}
			}
		}

		// 构建成员信息
		member := map[string]interface{}{
			"group_id": groupID,
			"user": map[string]interface{}{
				"id":         user.ID,
				"username":   user.Username,
				"email":      user.Email,
				"avatar_url": user.AvatarURL,
				"created_at": user.CreatedAt,
			},
			"role":      role,
			"joined_at": joinedAt,
		}
		members = append(members, member)
	}

	// 返回成员列表
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(members)
}

// AddGroupMembers 添加群组成员
func (h *GroupHandler) AddGroupMembers(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取群组ID
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "无效的群组ID", http.StatusBadRequest)
		return
	}

	// 检查用户是否为群组管理员
	isAdmin, err := h.groupService.IsGroupAdmin(groupID, userID)
	if err != nil {
		http.Error(w, "检查权限失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	if !isAdmin {
		http.Error(w, "没有权限添加群组成员", http.StatusForbidden)
		return
	}

	// 解析请求体
	var req struct {
		UserIDs []int `json:"user_ids"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	// 调用服务添加成员
	err = h.groupService.AddGroupMembers(groupID, req.UserIDs)
	if err != nil {
		http.Error(w, "添加群组成员失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回成功
	w.WriteHeader(http.StatusCreated)
}

// RemoveGroupMember 移除群组成员
func (h *GroupHandler) RemoveGroupMember(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取群组ID和要移除的成员ID
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "无效的群组ID", http.StatusBadRequest)
		return
	}

	memberID, err := strconv.Atoi(vars["userId"])
	if err != nil {
		http.Error(w, "无效的用户ID", http.StatusBadRequest)
		return
	}

	// 检查用户是否为群组管理员
	isAdmin, err := h.groupService.IsGroupAdmin(groupID, userID)
	if err != nil {
		http.Error(w, "检查权限失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 获取群组信息
	group, err := h.groupService.GetGroupByID(groupID)
	if err != nil {
		http.Error(w, "获取群组信息失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 检查权限：只有群主可以移除管理员，管理员可以移除普通成员
	if !isAdmin {
		http.Error(w, "没有权限移除群组成员", http.StatusForbidden)
		return
	}

	// 如果要移除的是管理员，检查当前用户是否为群主
	targetIsAdmin, err := h.groupService.IsGroupAdmin(groupID, memberID)
	if err != nil {
		http.Error(w, "检查权限失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	if targetIsAdmin && group.CreatedBy != userID {
		http.Error(w, "只有群主可以移除管理员", http.StatusForbidden)
		return
	}

	// 调用服务移除成员
	err = h.groupService.RemoveGroupMember(groupID, memberID)
	if err != nil {
		http.Error(w, "移除群组成员失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回成功
	w.WriteHeader(http.StatusNoContent)
}

// SetGroupAdmin 设置或取消群组管理员
func (h *GroupHandler) SetGroupAdmin(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取群组ID和目标用户ID
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "无效的群组ID", http.StatusBadRequest)
		return
	}

	targetID, err := strconv.Atoi(vars["userId"])
	if err != nil {
		http.Error(w, "无效的用户ID", http.StatusBadRequest)
		return
	}

	// 获取群组信息
	group, err := h.groupService.GetGroupByID(groupID)
	if err != nil {
		http.Error(w, "获取群组信息失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 检查当前用户是否为群主
	if group.CreatedBy != userID {
		http.Error(w, "只有群主可以设置管理员", http.StatusForbidden)
		return
	}

	// 解析请求体
	var req struct {
		IsAdmin bool `json:"is_admin"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	// 调用服务设置管理员
	err = h.groupService.SetGroupAdmin(groupID, targetID, req.IsAdmin)
	if err != nil {
		http.Error(w, "设置管理员失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回成功
	w.WriteHeader(http.StatusOK)
}

// LeaveGroup 退出群组
func (h *GroupHandler) LeaveGroup(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取群组ID
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "无效的群组ID", http.StatusBadRequest)
		return
	}

	// 获取群组信息
	group, err := h.groupService.GetGroupByID(groupID)
	if err != nil {
		http.Error(w, "获取群组信息失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 群主不能直接退出群组，必须先转让群主或解散群组
	if group.CreatedBy == userID {
		http.Error(w, "群主不能直接退出群组，请先转让群主或解散群组", http.StatusBadRequest)
		return
	}

	// 调用服务退出群组
	err = h.groupService.RemoveGroupMember(groupID, userID)
	if err != nil {
		http.Error(w, "退出群组失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回成功
	w.WriteHeader(http.StatusNoContent)
}

// UploadGroupAvatar 上传群组头像
func (h *GroupHandler) UploadGroupAvatar(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	_, err := GetUserIDFromContext(r.Context())
	if err != nil {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 解析多部分表单
	err = r.ParseMultipartForm(10 << 20) // 限制上传大小为10MB
	if err != nil {
		http.Error(w, "无法解析表单: "+err.Error(), http.StatusBadRequest)
		return
	}

	// 获取上传的文件
	file, handler, err := r.FormFile("avatar")
	if err != nil {
		http.Error(w, "无法获取上传的文件: "+err.Error(), http.StatusBadRequest)
		return
	}
	defer file.Close()

	// 检查文件类型
	contentType := handler.Header.Get("Content-Type")
	if contentType != "image/jpeg" && contentType != "image/png" && contentType != "image/gif" {
		http.Error(w, "不支持的文件类型，仅支持JPEG、PNG和GIF", http.StatusBadRequest)
		return
	}

	// 保存文件并获取URL
	avatarURL, err := h.groupService.SaveGroupAvatar(file, handler.Filename)
	if err != nil {
		http.Error(w, "保存头像失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 返回头像URL
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"avatar_url": avatarURL,
	})
}

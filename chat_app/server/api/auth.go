package api

import (
	"encoding/json"
	"net/http"
	
	"chat_app/server/services"
	"chat_app/server/utils"
)

// AuthHandler 处理认证相关的API请求
type AuthHandler struct {
	userService *services.UserService
}

// NewAuthHandler 创建新的认证处理器
func NewAuthHandler(userService *services.UserService) *AuthHandler {
	return &AuthHandler{userService: userService}
}

// RegisterRequest 注册请求
type RegisterRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginRequest 登录请求
type LoginRequest struct {
	UsernameOrEmail string `json:"username_or_email"`
	Password        string `json:"password"`
}

// AuthResponse 认证响应
type AuthResponse struct {
	Token string `json:"token"`
	User  struct {
		ID       int    `json:"id"`
		Username string `json:"username"`
		Email    string `json:"email"`
	} `json:"user"`
}

// Register 处理用户注册
func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	// 只接受POST请求
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}
	
	// 解析请求
	var req RegisterRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}
	
	// 验证请求
	if req.Username == "" || req.Email == "" || req.Password == "" {
		http.Error(w, "用户名、邮箱和密码不能为空", http.StatusBadRequest)
		return
	}
	
	// 注册用户
	user, err := h.userService.RegisterUser(req.Username, req.Email, req.Password)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	// 生成令牌
	token, err := utils.GenerateToken(user.ID)
	if err != nil {
		http.Error(w, "令牌生成失败", http.StatusInternalServerError)
		return
	}
	
	// 构建响应
	var resp AuthResponse
	resp.Token = token
	resp.User.ID = user.ID
	resp.User.Username = user.Username
	resp.User.Email = user.Email
	
	// 返回响应
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(resp)
}

// Login 处理用户登录
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	// 只接受POST请求
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}
	
	// 解析请求
	var req LoginRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}
	
	// 验证请求
	if req.UsernameOrEmail == "" || req.Password == "" {
		http.Error(w, "用户名/邮箱和密码不能为空", http.StatusBadRequest)
		return
	}
	
	// 验证用户
	user, err := h.userService.AuthenticateUser(req.UsernameOrEmail, req.Password)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	
	// 生成令牌
	token, err := utils.GenerateToken(user.ID)
	if err != nil {
		http.Error(w, "令牌生成失败", http.StatusInternalServerError)
		return
	}
	
	// 构建响应
	var resp AuthResponse
	resp.Token = token
	resp.User.ID = user.ID
	resp.User.Username = user.Username
	resp.User.Email = user.Email
	
	// 返回响应
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
} 
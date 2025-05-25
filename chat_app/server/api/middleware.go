package api

import (
	"context"
	"net/http"
	"strings"

	"chat_app/server/utils"
)

// 上下文键
type contextKey string

const (
	// UserIDKey 用户ID上下文键
	UserIDKey contextKey = "user_id"
)

// AuthMiddleware 认证中间件
func AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 从请求头获取令牌
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "未授权", http.StatusUnauthorized)
			return
		}

		// 令牌格式：Bearer {token}
		tokenParts := strings.Split(authHeader, " ")
		if len(tokenParts) != 2 || tokenParts[0] != "Bearer" {
			http.Error(w, "无效的授权格式", http.StatusUnauthorized)
			return
		}

		tokenString := tokenParts[1]

		// 验证令牌
		claims, err := utils.ParseToken(tokenString)
		if err != nil {
			http.Error(w, "无效的令牌", http.StatusUnauthorized)
			return
		}

		// 将用户ID添加到请求上下文
		ctx := context.WithValue(r.Context(), utils.UserIDKey, claims.UserID)

		// 使用更新后的上下文调用下一个处理器
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// CORSMiddleware CORS中间件
func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 允许的源 - 允许所有来源
		w.Header().Set("Access-Control-Allow-Origin", "*")

		// 允许的方法 - 允许所有常用方法
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")

		// 允许的头 - 允许更多头部
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With, Accept, Origin")

		// 允许凭证
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		// 缓存预检请求结果
		w.Header().Set("Access-Control-Max-Age", "3600")

		// 处理预检请求
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		// 调用下一个处理器
		next.ServeHTTP(w, r)
	})
}

// LoggingMiddleware 日志中间件
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 记录请求
		// log.Printf("%s %s %s", r.RemoteAddr, r.Method, r.URL)

		// 调用下一个处理器
		next.ServeHTTP(w, r)
	})
}

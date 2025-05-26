package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v4"
)

// 上下文键
type ContextKey string

const (
	// UserIDKey 用户ID上下文键
	UserIDKey ContextKey = "user_id"
)

// 密钥（实际应用中应从环境变量或配置文件中获取）
var jwtSecret = []byte("chat_app_secret_key")

// Claims JWT声明
type Claims struct {
	UserID int `json:"user_id"`
	jwt.RegisteredClaims
}

// GenerateToken 生成JWT令牌
func GenerateToken(userID int) (string, error) {
	// 设置过期时间（7天）
	expirationTime := time.Now().Add(7 * 24 * time.Hour)

	// 创建声明
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	// 创建令牌
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	// 签名令牌
	tokenString, err := token.SignedString(jwtSecret)
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

// ParseToken 解析JWT令牌
func ParseToken(tokenString string) (*Claims, error) {
	// 解析令牌
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return jwtSecret, nil
	})

	if err != nil {
		return nil, err
	}

	// 验证令牌
	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("无效的令牌")
}

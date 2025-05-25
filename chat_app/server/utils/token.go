package utils

import (
	"errors"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// 密钥，实际应用中应该从环境变量或配置文件中获取
var jwtSecret = []byte("your_jwt_secret_key")

// Claims 自定义JWT声明
type Claims struct {
	UserID int `json:"user_id"`
	jwt.RegisteredClaims
}

// 上下文键
type contextKey string

const (
	// UserIDKey 用户ID上下文键
	UserIDKey contextKey = "user_id"
)

// GenerateToken 生成JWT令牌
func GenerateToken(userID int) (string, error) {
	// 设置过期时间为24小时
	expirationTime := time.Now().Add(24 * time.Hour)

	// 创建声明
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
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

	return nil, jwt.ErrSignatureInvalid
}

// GetUserIDFromRequest 从请求中获取用户ID
func GetUserIDFromRequest(r *http.Request) (int, error) {
	// 从上下文中获取用户ID
	userID, ok := r.Context().Value(UserIDKey).(int)
	if !ok {
		return 0, errors.New("未授权：上下文中没有用户ID")
	}
	return userID, nil
}

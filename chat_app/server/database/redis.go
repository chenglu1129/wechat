package database

import (
	"context"
	"time"
	
	"chat_app/server/config"
	
	"github.com/go-redis/redis/v8"
)

// RedisDB 持有Redis数据库连接
type RedisDB struct {
	Client *redis.Client
}

// NewRedisDB 创建新的Redis连接
func NewRedisDB(config *config.RedisConfig) (*RedisDB, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     config.Addr,
		Password: config.Password,
		DB:       config.DB,
	})
	
	// 测试连接
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	_, err := client.Ping(ctx).Result()
	if err != nil {
		return nil, err
	}
	
	return &RedisDB{Client: client}, nil
}

// Close 关闭数据库连接
func (r *RedisDB) Close() error {
	return r.Client.Close()
}

// SetUserOnlineStatus 设置用户在线状态
func (r *RedisDB) SetUserOnlineStatus(ctx context.Context, userID string, isOnline bool) error {
	key := "user:online:" + userID
	if isOnline {
		// 设置用户在线，有效期30分钟（如果30分钟内没有活动，状态会自动过期）
		return r.Client.Set(ctx, key, "1", 30*time.Minute).Err()
	} else {
		// 用户离线，删除键
		return r.Client.Del(ctx, key).Err()
	}
}

// IsUserOnline 检查用户是否在线
func (r *RedisDB) IsUserOnline(ctx context.Context, userID string) (bool, error) {
	key := "user:online:" + userID
	val, err := r.Client.Get(ctx, key).Result()
	if err == redis.Nil {
		// 键不存在，用户离线
		return false, nil
	} else if err != nil {
		// 发生错误
		return false, err
	}
	
	// 键存在且值为"1"，用户在线
	return val == "1", nil
}

// RefreshUserSession 刷新用户会话
func (r *RedisDB) RefreshUserSession(ctx context.Context, userID string) error {
	key := "user:online:" + userID
	// 刷新用户在线状态的过期时间
	return r.Client.Expire(ctx, key, 30*time.Minute).Err()
}

// StoreUserSession 存储用户会话信息
func (r *RedisDB) StoreUserSession(ctx context.Context, sessionID, userID string, duration time.Duration) error {
	key := "session:" + sessionID
	return r.Client.Set(ctx, key, userID, duration).Err()
}

// GetUserIDFromSession 从会话ID获取用户ID
func (r *RedisDB) GetUserIDFromSession(ctx context.Context, sessionID string) (string, error) {
	key := "session:" + sessionID
	userID, err := r.Client.Get(ctx, key).Result()
	if err == redis.Nil {
		// 会话不存在或已过期
		return "", nil
	}
	return userID, err
} 
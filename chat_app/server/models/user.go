package models

import (
	"time"
)

// User 表示应用中的用户
type User struct {
	ID           int       `json:"id"`
	Username     string    `json:"username"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"` // 不在JSON中暴露密码哈希
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// UserRepository 定义用户相关的数据库操作接口
type UserRepository interface {
	// 创建新用户
	CreateUser(user *User) error
	
	// 通过ID查找用户
	GetUserByID(id int) (*User, error)
	
	// 通过用户名查找用户
	GetUserByUsername(username string) (*User, error)
	
	// 通过邮箱查找用户
	GetUserByEmail(email string) (*User, error)
	
	// 更新用户信息
	UpdateUser(user *User) error
	
	// 删除用户
	DeleteUser(id int) error
	
	// 获取用户列表
	ListUsers(offset, limit int) ([]*User, error)
	
	// 搜索用户
	SearchUsers(query string, offset, limit int) ([]*User, error)
}

// Contact 表示用户的联系人关系
type Contact struct {
	ID        int       `json:"id"`
	UserID    int       `json:"user_id"`
	ContactID int       `json:"contact_id"`
	CreatedAt time.Time `json:"created_at"`
}

// ContactRepository 定义联系人相关的数据库操作接口
type ContactRepository interface {
	// 添加联系人
	AddContact(userID, contactID int) error
	
	// 删除联系人
	RemoveContact(userID, contactID int) error
	
	// 获取用户的所有联系人
	GetContacts(userID int) ([]*User, error)
	
	// 检查是否为联系人
	IsContact(userID, contactID int) (bool, error)
} 
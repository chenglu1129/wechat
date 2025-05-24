package models

import (
	"time"
)

// Group 表示聊天群组
type Group struct {
	ID        int       `json:"id"`
	Name      string    `json:"name"`
	CreatedBy int       `json:"created_by"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// GroupMember 表示群组成员
type GroupMember struct {
	ID       int       `json:"id"`
	GroupID  int       `json:"group_id"`
	UserID   int       `json:"user_id"`
	IsAdmin  bool      `json:"is_admin"`
	JoinedAt time.Time `json:"joined_at"`
}

// GroupRepository 定义群组相关的数据库操作接口
type GroupRepository interface {
	// 创建新群组
	CreateGroup(group *Group) error
	
	// 获取群组信息
	GetGroupByID(id int) (*Group, error)
	
	// 更新群组信息
	UpdateGroup(group *Group) error
	
	// 删除群组
	DeleteGroup(id int) error
	
	// 获取用户创建的群组
	GetGroupsByCreator(userID int) ([]*Group, error)
	
	// 获取用户加入的群组
	GetGroupsByMember(userID int) ([]*Group, error)
	
	// 搜索群组
	SearchGroups(query string, offset, limit int) ([]*Group, error)
}

// GroupMemberRepository 定义群组成员相关的数据库操作接口
type GroupMemberRepository interface {
	// 添加群组成员
	AddMember(groupID, userID int, isAdmin bool) error
	
	// 移除群组成员
	RemoveMember(groupID, userID int) error
	
	// 获取群组的所有成员
	GetMembers(groupID int) ([]*User, error)
	
	// 获取群组的管理员
	GetAdmins(groupID int) ([]*User, error)
	
	// 检查用户是否为群组成员
	IsMember(groupID, userID int) (bool, error)
	
	// 检查用户是否为群组管理员
	IsAdmin(groupID, userID int) (bool, error)
	
	// 设置或取消管理员权限
	SetAdmin(groupID, userID int, isAdmin bool) error
} 
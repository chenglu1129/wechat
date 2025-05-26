package services

import (
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"time"

	"chat_app/server/models"
)

// GroupService 提供群组相关的服务
type GroupService struct {
	groupRepo       models.GroupRepository
	groupMemberRepo models.GroupMemberRepository
	uploadPath      string
	serverBaseURL   string
}

// NewGroupService 创建新的群组服务
func NewGroupService(
	groupRepo models.GroupRepository,
	groupMemberRepo models.GroupMemberRepository,
	uploadPath string,
	serverBaseURL string,
) *GroupService {
	return &GroupService{
		groupRepo:       groupRepo,
		groupMemberRepo: groupMemberRepo,
		uploadPath:      uploadPath,
		serverBaseURL:   serverBaseURL,
	}
}

// CreateGroup 创建新群组
func (s *GroupService) CreateGroup(group *models.Group, memberIDs []int) error {
	// 创建群组
	err := s.groupRepo.CreateGroup(group)
	if err != nil {
		return err
	}

	// 添加创建者为群组管理员
	err = s.groupMemberRepo.AddMember(group.ID, group.CreatedBy, true)
	if err != nil {
		return err
	}

	// 添加其他成员
	for _, memberID := range memberIDs {
		err = s.groupMemberRepo.AddMember(group.ID, memberID, false)
		if err != nil {
			return err
		}
	}

	return nil
}

// GetGroupByID 获取群组信息
func (s *GroupService) GetGroupByID(groupID int) (*models.Group, error) {
	return s.groupRepo.GetGroupByID(groupID)
}

// UpdateGroup 更新群组信息
func (s *GroupService) UpdateGroup(group *models.Group) error {
	return s.groupRepo.UpdateGroup(group)
}

// DeleteGroup 删除群组
func (s *GroupService) DeleteGroup(groupID int) error {
	return s.groupRepo.DeleteGroup(groupID)
}

// GetUserGroups 获取用户加入的群组
func (s *GroupService) GetUserGroups(userID int) ([]*models.Group, error) {
	return s.groupRepo.GetGroupsByMember(userID)
}

// GetGroupMembers 获取群组成员
func (s *GroupService) GetGroupMembers(groupID int) ([]*models.User, error) {
	return s.groupMemberRepo.GetMembers(groupID)
}

// AddGroupMembers 添加群组成员
func (s *GroupService) AddGroupMembers(groupID int, userIDs []int) error {
	for _, userID := range userIDs {
		err := s.groupMemberRepo.AddMember(groupID, userID, false)
		if err != nil {
			return err
		}
	}
	return nil
}

// RemoveGroupMember 移除群组成员
func (s *GroupService) RemoveGroupMember(groupID int, userID int) error {
	return s.groupMemberRepo.RemoveMember(groupID, userID)
}

// IsGroupAdmin 检查用户是否为群组管理员
func (s *GroupService) IsGroupAdmin(groupID int, userID int) (bool, error) {
	return s.groupMemberRepo.IsAdmin(groupID, userID)
}

// SetGroupAdmin 设置或取消群组管理员
func (s *GroupService) SetGroupAdmin(groupID int, userID int, isAdmin bool) error {
	return s.groupMemberRepo.SetAdmin(groupID, userID, isAdmin)
}

// SaveGroupAvatar 保存群组头像
func (s *GroupService) SaveGroupAvatar(file multipart.File, filename string) (string, error) {
	// 确保上传目录存在
	avatarDir := filepath.Join(s.uploadPath, "group_avatars")
	err := os.MkdirAll(avatarDir, 0755)
	if err != nil {
		return "", err
	}

	// 生成唯一文件名
	ext := filepath.Ext(filename)
	newFilename := "group_" + time.Now().Format("20060102150405") + ext
	filePath := filepath.Join(avatarDir, newFilename)

	// 创建目标文件
	dst, err := os.Create(filePath)
	if err != nil {
		return "", err
	}
	defer dst.Close()

	// 复制文件内容
	_, err = io.Copy(dst, file)
	if err != nil {
		return "", err
	}

	// 返回可访问的URL
	return s.serverBaseURL + "/uploads/group_avatars/" + newFilename, nil
}

// GetGroupMemberCount 获取群组成员数量
func (s *GroupService) GetGroupMemberCount(groupID int) (int, error) {
	members, err := s.groupMemberRepo.GetMembers(groupID)
	if err != nil {
		return 0, err
	}
	return len(members), nil
}

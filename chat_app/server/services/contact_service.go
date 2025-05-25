package services

import (
	"errors"

	"chat_app/server/models"
)

// ContactService 处理联系人相关的业务逻辑
type ContactService struct {
	userRepo    models.UserRepository
	contactRepo models.ContactRepository
}

// NewContactService 创建新的联系人服务
func NewContactService(userRepo models.UserRepository, contactRepo models.ContactRepository) *ContactService {
	return &ContactService{
		userRepo:    userRepo,
		contactRepo: contactRepo,
	}
}

// AddContact 添加联系人
func (s *ContactService) AddContact(userID, contactID int) error {
	// 检查联系人是否存在
	contact, err := s.userRepo.GetUserByID(contactID)
	if err != nil || contact == nil {
		return errors.New("联系人不存在")
	}

	// 检查是否已经是联系人
	isContact, err := s.contactRepo.IsContact(userID, contactID)
	if err != nil {
		return err
	}
	if isContact {
		return errors.New("已经是联系人")
	}

	// 添加联系人
	return s.contactRepo.AddContact(userID, contactID)
}

// RemoveContact 删除联系人
func (s *ContactService) RemoveContact(userID, contactID int) error {
	return s.contactRepo.RemoveContact(userID, contactID)
}

// GetContacts 获取用户的所有联系人
func (s *ContactService) GetContacts(userID int) ([]*models.User, error) {
	return s.contactRepo.GetContacts(userID)
}

// SearchUsers 搜索用户
func (s *ContactService) SearchUsers(query string, offset, limit int) ([]*models.User, error) {
	return s.userRepo.SearchUsers(query, offset, limit)
}

package services

import (
	"errors"
	"time"
	
	"chat_app/server/models"
	"chat_app/server/utils"
)

// UserService 处理用户相关的业务逻辑
type UserService struct {
	userRepo    models.UserRepository
	contactRepo models.ContactRepository
}

// NewUserService 创建新的用户服务
func NewUserService(userRepo models.UserRepository, contactRepo models.ContactRepository) *UserService {
	return &UserService{
		userRepo:    userRepo,
		contactRepo: contactRepo,
	}
}

// RegisterUser 注册新用户
func (s *UserService) RegisterUser(username, email, password string) (*models.User, error) {
	// 检查用户名是否已存在
	existingUser, err := s.userRepo.GetUserByUsername(username)
	if err == nil && existingUser != nil {
		return nil, errors.New("用户名已被使用")
	}
	
	// 检查邮箱是否已存在
	existingUser, err = s.userRepo.GetUserByEmail(email)
	if err == nil && existingUser != nil {
		return nil, errors.New("邮箱已被使用")
	}
	
	// 哈希密码
	passwordHash, err := utils.HashPassword(password)
	if err != nil {
		return nil, err
	}
	
	// 创建用户
	now := time.Now()
	user := &models.User{
		Username:     username,
		Email:        email,
		PasswordHash: passwordHash,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	
	// 保存用户
	err = s.userRepo.CreateUser(user)
	if err != nil {
		return nil, err
	}
	
	return user, nil
}

// AuthenticateUser 验证用户登录
func (s *UserService) AuthenticateUser(usernameOrEmail, password string) (*models.User, error) {
	// 尝试通过用户名查找用户
	user, err := s.userRepo.GetUserByUsername(usernameOrEmail)
	if err != nil || user == nil {
		// 如果通过用户名找不到，尝试通过邮箱查找
		user, err = s.userRepo.GetUserByEmail(usernameOrEmail)
		if err != nil || user == nil {
			return nil, errors.New("用户名或密码不正确")
		}
	}
	
	// 验证密码
	if !utils.CheckPasswordHash(password, user.PasswordHash) {
		return nil, errors.New("用户名或密码不正确")
	}
	
	return user, nil
}

// GetUserByID 通过ID获取用户
func (s *UserService) GetUserByID(id int) (*models.User, error) {
	return s.userRepo.GetUserByID(id)
}

// UpdateUserProfile 更新用户资料
func (s *UserService) UpdateUserProfile(user *models.User) error {
	// 更新时间戳
	user.UpdatedAt = time.Now()
	
	return s.userRepo.UpdateUser(user)
}

// ChangePassword 修改用户密码
func (s *UserService) ChangePassword(userID int, oldPassword, newPassword string) error {
	// 获取用户
	user, err := s.userRepo.GetUserByID(userID)
	if err != nil {
		return err
	}
	
	// 验证旧密码
	if !utils.CheckPasswordHash(oldPassword, user.PasswordHash) {
		return errors.New("旧密码不正确")
	}
	
	// 哈希新密码
	passwordHash, err := utils.HashPassword(newPassword)
	if err != nil {
		return err
	}
	
	// 更新密码
	user.PasswordHash = passwordHash
	user.UpdatedAt = time.Now()
	
	return s.userRepo.UpdateUser(user)
}

// AddContact 添加联系人
func (s *UserService) AddContact(userID, contactID int) error {
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
func (s *UserService) RemoveContact(userID, contactID int) error {
	return s.contactRepo.RemoveContact(userID, contactID)
}

// GetContacts 获取用户的所有联系人
func (s *UserService) GetContacts(userID int) ([]*models.User, error) {
	return s.contactRepo.GetContacts(userID)
}

// SearchUsers 搜索用户
func (s *UserService) SearchUsers(query string, offset, limit int) ([]*models.User, error) {
	return s.userRepo.SearchUsers(query, offset, limit)
} 
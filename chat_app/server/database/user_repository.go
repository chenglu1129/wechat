package database

import (
	"database/sql"
	"time"

	"chat_app/server/models"
)

// UserRepository 实现models.UserRepository接口
type UserRepository struct {
	db *PostgresDB
}

// NewUserRepository 创建一个新的UserRepository
func NewUserRepository(db *PostgresDB) models.UserRepository {
	return &UserRepository{db: db}
}

// CreateUser 创建新用户
func (r *UserRepository) CreateUser(user *models.User) error {
	query := `
		INSERT INTO users (username, email, password_hash, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`
	return r.db.DB.QueryRow(
		query,
		user.Username,
		user.Email,
		user.PasswordHash,
		user.CreatedAt,
		user.UpdatedAt,
	).Scan(&user.ID)
}

// GetUserByID 通过ID查找用户
func (r *UserRepository) GetUserByID(id int) (*models.User, error) {
	query := `
		SELECT id, username, email, password_hash, created_at, updated_at
		FROM users
		WHERE id = $1
	`
	user := &models.User{}
	err := r.db.DB.QueryRow(query, id).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.PasswordHash,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return user, nil
}

// GetUserByUsername 通过用户名查找用户
func (r *UserRepository) GetUserByUsername(username string) (*models.User, error) {
	query := `
		SELECT id, username, email, password_hash, created_at, updated_at
		FROM users
		WHERE username = $1
	`
	user := &models.User{}
	err := r.db.DB.QueryRow(query, username).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.PasswordHash,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return user, nil
}

// GetUserByEmail 通过邮箱查找用户
func (r *UserRepository) GetUserByEmail(email string) (*models.User, error) {
	query := `
		SELECT id, username, email, password_hash, created_at, updated_at
		FROM users
		WHERE email = $1
	`
	user := &models.User{}
	err := r.db.DB.QueryRow(query, email).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.PasswordHash,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return user, nil
}

// UpdateUser 更新用户信息
func (r *UserRepository) UpdateUser(user *models.User) error {
	query := `
		UPDATE users
		SET username = $1, email = $2, password_hash = $3, updated_at = $4
		WHERE id = $5
	`
	_, err := r.db.DB.Exec(
		query,
		user.Username,
		user.Email,
		user.PasswordHash,
		time.Now(),
		user.ID,
	)
	return err
}

// DeleteUser 删除用户
func (r *UserRepository) DeleteUser(id int) error {
	query := "DELETE FROM users WHERE id = $1"
	_, err := r.db.DB.Exec(query, id)
	return err
}

// ListUsers 获取用户列表
func (r *UserRepository) ListUsers(offset, limit int) ([]*models.User, error) {
	query := `
		SELECT id, username, email, password_hash, created_at, updated_at
		FROM users
		ORDER BY username
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.DB.Query(query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []*models.User
	for rows.Next() {
		user := &models.User{}
		err := rows.Scan(
			&user.ID,
			&user.Username,
			&user.Email,
			&user.PasswordHash,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	return users, nil
}

// SearchUsers 搜索用户
func (r *UserRepository) SearchUsers(query string, offset, limit int) ([]*models.User, error) {
	sqlQuery := `
		SELECT id, username, email, password_hash, created_at, updated_at
		FROM users
		WHERE username ILIKE $1 OR email ILIKE $1
		ORDER BY username
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.DB.Query(sqlQuery, "%"+query+"%", limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []*models.User
	for rows.Next() {
		user := &models.User{}
		err := rows.Scan(
			&user.ID,
			&user.Username,
			&user.Email,
			&user.PasswordHash,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	return users, nil
}

package database

import (
	"chat_app/server/models"
)

// ContactRepository 实现models.ContactRepository接口
type ContactRepository struct {
	db *PostgresDB
}

// NewContactRepository 创建一个新的ContactRepository
func NewContactRepository(db *PostgresDB) models.ContactRepository {
	return &ContactRepository{db: db}
}

// AddContact 添加联系人
func (r *ContactRepository) AddContact(userID, contactID int) error {
	query := `
		INSERT INTO contacts (user_id, contact_id)
		VALUES ($1, $2)
		ON CONFLICT (user_id, contact_id) DO NOTHING
	`
	_, err := r.db.DB.Exec(query, userID, contactID)
	return err
}

// RemoveContact 删除联系人
func (r *ContactRepository) RemoveContact(userID, contactID int) error {
	query := `DELETE FROM contacts WHERE user_id = $1 AND contact_id = $2`
	_, err := r.db.DB.Exec(query, userID, contactID)
	return err
}

// GetContacts 获取用户的所有联系人
func (r *ContactRepository) GetContacts(userID int) ([]*models.User, error) {
	query := `
		SELECT u.id, u.username, u.email, u.password_hash, u.created_at, u.updated_at
		FROM users u
		JOIN contacts c ON u.id = c.contact_id
		WHERE c.user_id = $1
		ORDER BY u.username
	`
	rows, err := r.db.DB.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var contacts []*models.User
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
		contacts = append(contacts, user)
	}
	return contacts, nil
}

// IsContact 检查是否为联系人
func (r *ContactRepository) IsContact(userID, contactID int) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM contacts WHERE user_id = $1 AND contact_id = $2)`
	var exists bool
	err := r.db.DB.QueryRow(query, userID, contactID).Scan(&exists)
	return exists, err
}

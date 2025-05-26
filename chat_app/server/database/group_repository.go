package database

import (
	"database/sql"
	"time"

	"chat_app/server/models"
)

// SQLGroupRepository 实现基于SQL的群组存储库
type SQLGroupRepository struct {
	db *sql.DB
}

// NewSQLGroupRepository 创建新的SQL群组存储库
func NewSQLGroupRepository(db *sql.DB) *SQLGroupRepository {
	return &SQLGroupRepository{db: db}
}

// CreateGroup 创建新群组
func (r *SQLGroupRepository) CreateGroup(group *models.Group) error {
	query := `
		INSERT INTO groups (name, created_by, created_at, updated_at)
		VALUES (?, ?, ?, ?)
		RETURNING id
	`

	now := time.Now()
	group.CreatedAt = now
	group.UpdatedAt = now

	err := r.db.QueryRow(
		query,
		group.Name,
		group.CreatedBy,
		group.CreatedAt,
		group.UpdatedAt,
	).Scan(&group.ID)

	return err
}

// GetGroupByID 获取群组信息
func (r *SQLGroupRepository) GetGroupByID(id int) (*models.Group, error) {
	query := `
		SELECT id, name, created_by, created_at, updated_at
		FROM groups
		WHERE id = ?
	`

	group := &models.Group{}
	err := r.db.QueryRow(query, id).Scan(
		&group.ID,
		&group.Name,
		&group.CreatedBy,
		&group.CreatedAt,
		&group.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // 群组不存在
		}
		return nil, err
	}

	return group, nil
}

// UpdateGroup 更新群组信息
func (r *SQLGroupRepository) UpdateGroup(group *models.Group) error {
	query := `
		UPDATE groups
		SET name = ?, updated_at = ?
		WHERE id = ?
	`

	group.UpdatedAt = time.Now()

	_, err := r.db.Exec(
		query,
		group.Name,
		group.UpdatedAt,
		group.ID,
	)

	return err
}

// DeleteGroup 删除群组
func (r *SQLGroupRepository) DeleteGroup(id int) error {
	// 开启事务
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}

	// 删除群组成员
	_, err = tx.Exec("DELETE FROM group_members WHERE group_id = ?", id)
	if err != nil {
		tx.Rollback()
		return err
	}

	// 删除群组
	_, err = tx.Exec("DELETE FROM groups WHERE id = ?", id)
	if err != nil {
		tx.Rollback()
		return err
	}

	// 提交事务
	return tx.Commit()
}

// GetGroupsByCreator 获取用户创建的群组
func (r *SQLGroupRepository) GetGroupsByCreator(userID int) ([]*models.Group, error) {
	query := `
		SELECT id, name, created_by, created_at, updated_at
		FROM groups
		WHERE created_by = ?
		ORDER BY updated_at DESC
	`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanGroups(rows)
}

// GetGroupsByMember 获取用户加入的群组
func (r *SQLGroupRepository) GetGroupsByMember(userID int) ([]*models.Group, error) {
	query := `
		SELECT g.id, g.name, g.created_by, g.created_at, g.updated_at
		FROM groups g
		JOIN group_members gm ON g.id = gm.group_id
		WHERE gm.user_id = ?
		ORDER BY g.updated_at DESC
	`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanGroups(rows)
}

// SearchGroups 搜索群组
func (r *SQLGroupRepository) SearchGroups(query string, offset, limit int) ([]*models.Group, error) {
	sqlQuery := `
		SELECT id, name, created_by, created_at, updated_at
		FROM groups
		WHERE name LIKE ?
		ORDER BY updated_at DESC
		LIMIT ? OFFSET ?
	`

	rows, err := r.db.Query(sqlQuery, "%"+query+"%", limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanGroups(rows)
}

// scanGroups 扫描查询结果并返回群组列表
func (r *SQLGroupRepository) scanGroups(rows *sql.Rows) ([]*models.Group, error) {
	var groups []*models.Group

	for rows.Next() {
		group := &models.Group{}
		err := rows.Scan(
			&group.ID,
			&group.Name,
			&group.CreatedBy,
			&group.CreatedAt,
			&group.UpdatedAt,
		)

		if err != nil {
			return nil, err
		}

		groups = append(groups, group)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return groups, nil
}

// SQLGroupMemberRepository 实现基于SQL的群组成员存储库
type SQLGroupMemberRepository struct {
	db *sql.DB
}

// NewSQLGroupMemberRepository 创建新的SQL群组成员存储库
func NewSQLGroupMemberRepository(db *sql.DB) *SQLGroupMemberRepository {
	return &SQLGroupMemberRepository{db: db}
}

// AddMember 添加群组成员
func (r *SQLGroupMemberRepository) AddMember(groupID, userID int, isAdmin bool) error {
	query := `
		INSERT INTO group_members (group_id, user_id, is_admin, joined_at)
		VALUES (?, ?, ?, ?)
		ON CONFLICT (group_id, user_id) DO UPDATE SET is_admin = ?
	`

	_, err := r.db.Exec(
		query,
		groupID,
		userID,
		isAdmin,
		time.Now(),
		isAdmin,
	)

	return err
}

// RemoveMember 移除群组成员
func (r *SQLGroupMemberRepository) RemoveMember(groupID, userID int) error {
	query := `DELETE FROM group_members WHERE group_id = ? AND user_id = ?`
	_, err := r.db.Exec(query, groupID, userID)
	return err
}

// GetMembers 获取群组的所有成员
func (r *SQLGroupMemberRepository) GetMembers(groupID int) ([]*models.User, error) {
	query := `
		SELECT u.id, u.username, u.email, u.avatar_url, u.created_at
		FROM users u
		JOIN group_members gm ON u.id = gm.user_id
		WHERE gm.group_id = ?
		ORDER BY gm.joined_at
	`

	rows, err := r.db.Query(query, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []*models.User

	for rows.Next() {
		user := &models.User{}
		var avatarURL sql.NullString

		err := rows.Scan(
			&user.ID,
			&user.Username,
			&user.Email,
			&avatarURL,
			&user.CreatedAt,
		)

		if err != nil {
			return nil, err
		}

		if avatarURL.Valid {
			user.AvatarURL = avatarURL.String
		}

		users = append(users, user)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return users, nil
}

// GetAdmins 获取群组的管理员
func (r *SQLGroupMemberRepository) GetAdmins(groupID int) ([]*models.User, error) {
	query := `
		SELECT u.id, u.username, u.email, u.avatar_url, u.created_at
		FROM users u
		JOIN group_members gm ON u.id = gm.user_id
		WHERE gm.group_id = ? AND gm.is_admin = true
		ORDER BY gm.joined_at
	`

	rows, err := r.db.Query(query, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []*models.User

	for rows.Next() {
		user := &models.User{}
		var avatarURL sql.NullString

		err := rows.Scan(
			&user.ID,
			&user.Username,
			&user.Email,
			&avatarURL,
			&user.CreatedAt,
		)

		if err != nil {
			return nil, err
		}

		if avatarURL.Valid {
			user.AvatarURL = avatarURL.String
		}

		users = append(users, user)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return users, nil
}

// IsMember 检查用户是否为群组成员
func (r *SQLGroupMemberRepository) IsMember(groupID, userID int) (bool, error) {
	query := `SELECT 1 FROM group_members WHERE group_id = ? AND user_id = ? LIMIT 1`

	var exists int
	err := r.db.QueryRow(query, groupID, userID).Scan(&exists)

	if err != nil {
		if err == sql.ErrNoRows {
			return false, nil
		}
		return false, err
	}

	return true, nil
}

// IsAdmin 检查用户是否为群组管理员
func (r *SQLGroupMemberRepository) IsAdmin(groupID, userID int) (bool, error) {
	query := `SELECT is_admin FROM group_members WHERE group_id = ? AND user_id = ? LIMIT 1`

	var isAdmin bool
	err := r.db.QueryRow(query, groupID, userID).Scan(&isAdmin)

	if err != nil {
		if err == sql.ErrNoRows {
			return false, nil
		}
		return false, err
	}

	return isAdmin, nil
}

// SetAdmin 设置或取消管理员权限
func (r *SQLGroupMemberRepository) SetAdmin(groupID, userID int, isAdmin bool) error {
	query := `UPDATE group_members SET is_admin = ? WHERE group_id = ? AND user_id = ?`
	_, err := r.db.Exec(query, isAdmin, groupID, userID)
	return err
}

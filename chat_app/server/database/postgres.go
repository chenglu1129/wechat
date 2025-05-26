package database

import (
	"database/sql"
	"fmt"

	"chat_app/server/config"

	_ "github.com/lib/pq"
)

// PostgresDB 持有PostgreSQL数据库连接
type PostgresDB struct {
	DB *sql.DB
}

// NewPostgresDB 创建新的PostgreSQL连接
func NewPostgresDB(config *config.PostgresConfig) (*PostgresDB, error) {
	connStr := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		config.Host, config.Port, config.User, config.Password, config.DBName, config.SSLMode)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, err
	}

	// 测试连接
	if err := db.Ping(); err != nil {
		return nil, err
	}

	return &PostgresDB{DB: db}, nil
}

// Close 关闭数据库连接
func (p *PostgresDB) Close() error {
	return p.DB.Close()
}

// InitSchema 初始化数据库结构
func (p *PostgresDB) InitSchema() error {
	// 创建用户表
	_, err := p.DB.Exec(`
	CREATE TABLE IF NOT EXISTS users (
		id SERIAL PRIMARY KEY,
		username VARCHAR(50) UNIQUE NOT NULL,
		email VARCHAR(100) UNIQUE NOT NULL,
		password_hash VARCHAR(100) NOT NULL,
		avatar_url VARCHAR(255),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	)`)
	if err != nil {
		return err
	}

	// 创建联系人表
	_, err = p.DB.Exec(`
	CREATE TABLE IF NOT EXISTS contacts (
		id SERIAL PRIMARY KEY,
		user_id INTEGER REFERENCES users(id),
		contact_id INTEGER REFERENCES users(id),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		UNIQUE(user_id, contact_id)
	)`)
	if err != nil {
		return err
	}

	// 创建群组表
	_, err = p.DB.Exec(`
	CREATE TABLE IF NOT EXISTS groups (
		id SERIAL PRIMARY KEY,
		name VARCHAR(100) NOT NULL,
		created_by INTEGER REFERENCES users(id),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	)`)
	if err != nil {
		return err
	}

	// 创建群组成员表
	_, err = p.DB.Exec(`
	CREATE TABLE IF NOT EXISTS group_members (
		id SERIAL PRIMARY KEY,
		group_id INTEGER REFERENCES groups(id),
		user_id INTEGER REFERENCES users(id),
		is_admin BOOLEAN DEFAULT FALSE,
		joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		UNIQUE(group_id, user_id)
	)`)

	return err
}

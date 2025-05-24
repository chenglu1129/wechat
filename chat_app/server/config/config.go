package config

import (
	"encoding/json"
	"os"
)

// Config 存储应用配置
type Config struct {
	Server   ServerConfig   `json:"server"`
	Postgres PostgresConfig `json:"postgres"`
	MongoDB  MongoDBConfig  `json:"mongodb"`
	Redis    RedisConfig    `json:"redis"`
	NATS     NATSConfig     `json:"nats"`
}

// ServerConfig 服务器配置
type ServerConfig struct {
	Port int `json:"port"`
}

// PostgresConfig PostgreSQL配置
type PostgresConfig struct {
	Host     string `json:"host"`
	Port     int    `json:"port"`
	User     string `json:"user"`
	Password string `json:"password"`
	DBName   string `json:"dbname"`
	SSLMode  string `json:"sslmode"`
}

// MongoDBConfig MongoDB配置
type MongoDBConfig struct {
	URI      string `json:"uri"`
	Database string `json:"database"`
}

// RedisConfig Redis配置
type RedisConfig struct {
	Addr     string `json:"addr"`
	Password string `json:"password"`
	DB       int    `json:"db"`
}

// NATSConfig NATS配置
type NATSConfig struct {
	URL string `json:"url"`
}

// LoadConfig 从文件加载配置
func LoadConfig(path string) (*Config, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var config Config
	decoder := json.NewDecoder(file)
	err = decoder.Decode(&config)
	if err != nil {
		return nil, err
	}

	return &config, nil
}

// GetDefaultConfig 返回默认配置
func GetDefaultConfig() *Config {
	return &Config{
		Server: ServerConfig{
			Port: 8080,
		},
		Postgres: PostgresConfig{
			Host:     "localhost",
			Port:     5432,
			User:     "postgres",
			Password: "password",
			DBName:   "chat_app",
			SSLMode:  "disable",
		},
		MongoDB: MongoDBConfig{
			URI:      "mongodb://localhost:27017",
			Database: "chat_app",
		},
		Redis: RedisConfig{
			Addr:     "localhost:6379",
			Password: "",
			DB:       0,
		},
		NATS: NATSConfig{
			URL: "nats://localhost:4222",
		},
	}
} 
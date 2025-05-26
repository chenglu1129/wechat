//go:build ignore
// +build ignore

// 此文件不会被包含在项目的主构建中
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"chat_app/server/config"
	"chat_app/server/database"
)

func main() {
	// 加载配置
	cfg := config.GetDefaultConfig()

	// 连接数据库
	db, err := database.NewPostgresDB(&cfg.Postgres)
	if err != nil {
		fmt.Printf("连接数据库失败: %v\n", err)
		os.Exit(1)
	}
	defer db.Close()

	fmt.Println("数据库连接成功，准备运行迁移...")

	// 读取迁移文件夹
	migrations, err := os.ReadDir("migrations")
	if err != nil {
		fmt.Printf("读取迁移文件夹失败: %v\n", err)
		os.Exit(1)
	}

	// 按文件名排序
	for _, file := range migrations {
		if file.IsDir() || !strings.HasSuffix(file.Name(), ".sql") {
			continue
		}

		fmt.Printf("运行迁移: %s\n", file.Name())

		// 读取迁移文件内容
		content, err := os.ReadFile(filepath.Join("migrations", file.Name()))
		if err != nil {
			fmt.Printf("读取迁移文件失败: %v\n", err)
			continue
		}

		// 执行SQL
		_, err = db.DB.Exec(string(content))
		if err != nil {
			fmt.Printf("执行迁移失败: %v\n", err)
			continue
		}

		fmt.Printf("迁移 %s 执行成功\n", file.Name())
	}

	fmt.Println("所有迁移执行完成")
}

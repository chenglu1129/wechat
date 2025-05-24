package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"chat_app/server/api"
	"chat_app/server/config"
	"chat_app/server/database"
	"chat_app/server/services"
	"chat_app/server/websocket"
)

func main() {
	// 初始化配置
	fmt.Println("聊天服务器启动中...")

	// 加载配置
	cfg, err := config.LoadConfig("config/config.json")
	if err != nil {
		// 如果配置文件不存在，使用默认配置
		fmt.Println("无法加载配置文件，使用默认配置:", err)
		cfg = config.GetDefaultConfig()
	}

	// 初始化数据库连接
	var postgresDB *database.PostgresDB
	var mongodb *database.MongoDB
	var redisDB *database.RedisDB
	var natsDB *database.NATSDB

	// PostgreSQL
	postgresDB, err = database.NewPostgresDB(&cfg.Postgres)
	if err != nil {
		fmt.Println("PostgreSQL连接失败:", err)
		fmt.Println("继续启动服务器，但某些功能可能不可用...")
	} else {
		defer postgresDB.Close()

		// 初始化数据库结构
		err = postgresDB.InitSchema()
		if err != nil {
			fmt.Println("PostgreSQL初始化失败:", err)
		}
	}

	// MongoDB
	mongodb, err = database.NewMongoDB(&cfg.MongoDB)
	if err != nil {
		fmt.Println("MongoDB连接失败:", err)
		fmt.Println("继续启动服务器，但某些功能可能不可用...")
	} else {
		defer mongodb.Close(context.Background())

		// 初始化MongoDB集合
		err = mongodb.InitCollections()
		if err != nil {
			fmt.Println("MongoDB初始化失败:", err)
		}
	}

	// Redis
	redisDB, err = database.NewRedisDB(&cfg.Redis)
	if err != nil {
		fmt.Println("Redis连接失败:", err)
		fmt.Println("继续启动服务器，但某些功能可能不可用...")
	} else {
		defer redisDB.Close()
	}

	// NATS
	natsDB, err = database.NewNATSDB(&cfg.NATS)
	if err != nil {
		fmt.Println("NATS连接失败:", err)
		fmt.Println("继续启动服务器，但某些功能可能不可用...")
	} else {
		defer natsDB.Close()
	}

	// 初始化WebSocket Hub
	hub := websocket.NewHub()
	go hub.Run()

	// 初始化WebSocket处理器
	wsHandler := websocket.NewHandler(hub)

	// 设置HTTP路由
	mux := http.NewServeMux()

	// API路由
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "欢迎使用聊天应用API")
	})

	// 初始化认证处理器
	userRepo := database.NewUserRepository(postgresDB)
	contactRepo := database.NewContactRepository(postgresDB)
	userService := services.NewUserService(userRepo, contactRepo)
	authHandler := api.NewAuthHandler(userService)

	// 认证路由
	mux.HandleFunc("/auth/register", authHandler.Register)
	mux.HandleFunc("/auth/login", authHandler.Login)

	// WebSocket路由
	mux.HandleFunc("/ws", wsHandler.HandleWebSocket)

	// 应用中间件
	handler := api.CORSMiddleware(api.LoggingMiddleware(mux))

	// 创建HTTP服务器
	server := &http.Server{
		Addr:    fmt.Sprintf(":%d", cfg.Server.Port),
		Handler: handler,
	}

	// 优雅关闭
	go func() {
		// 监听中断信号
		sigint := make(chan os.Signal, 1)
		signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
		<-sigint

		// 收到中断信号，优雅关闭
		fmt.Println("正在关闭服务器...")

		// 创建一个超时上下文
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := server.Shutdown(ctx); err != nil {
			log.Fatal("服务器关闭错误:", err)
		}
	}()

	// 启动服务器
	fmt.Printf("服务器运行在 http://localhost:%d\n", cfg.Server.Port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal("HTTP服务器启动失败:", err)
	}
}

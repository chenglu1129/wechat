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

	"github.com/gorilla/mux"
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

	// 初始化服务
	userRepo := database.NewUserRepository(postgresDB)
	contactRepo := database.NewContactRepository(postgresDB)
	userService := services.NewUserService(userRepo, contactRepo)
	contactService := services.NewContactService(userRepo, contactRepo)

	// 初始化消息服务和处理器
	messageRepo := database.NewMessageRepository(mongodb)
	messageService := services.NewMessageService(messageRepo, redisDB, natsDB, hub)
	messageHandler := api.NewMessageHandler(messageService)

	// 初始化通知服务
	var notificationService *services.NotificationService
	if redisDB != nil {
		notificationService = services.NewNotificationService(redisDB.Client)
	}

	// 初始化API
	apiHandler := api.NewAPI(userService, contactService, notificationService)

	// 初始化认证处理器
	authHandler := api.NewAuthHandler(userService)

	// 创建联系人处理器
	contactHandler := api.NewContactHandler(contactService)

	// 创建路由器
	router := mux.NewRouter()

	// 主页路由
	router.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "欢迎使用聊天应用API")
	}).Methods("GET")

	// 认证路由
	router.HandleFunc("/auth/register", authHandler.Register).Methods("POST")
	router.HandleFunc("/auth/login", authHandler.Login).Methods("POST")

	// 联系人路由（带认证）
	router.Handle("/contacts", api.AuthMiddleware(http.HandlerFunc(contactHandler.GetContacts))).Methods("GET")
	router.Handle("/contacts/add", api.AuthMiddleware(http.HandlerFunc(contactHandler.AddContact))).Methods("POST")
	router.Handle("/contacts/remove", api.AuthMiddleware(http.HandlerFunc(contactHandler.RemoveContact))).Methods("POST")
	router.Handle("/users/search", api.AuthMiddleware(http.HandlerFunc(contactHandler.SearchUsers))).Methods("GET")

	// 消息路由（带认证）
	router.Handle("/messages", api.AuthMiddleware(http.HandlerFunc(messageHandler.SendMessage))).Methods("POST")
	router.Handle("/messages", api.AuthMiddleware(http.HandlerFunc(messageHandler.GetMessages))).Methods("GET")

	// 通知路由（带认证）
	router.Handle("/notifications/token", api.AuthMiddleware(http.HandlerFunc(apiHandler.SaveFCMToken))).Methods("POST")
	router.Handle("/notifications/token", api.AuthMiddleware(http.HandlerFunc(apiHandler.DeleteFCMToken))).Methods("DELETE")
	router.Handle("/notifications/test/{user_id}", api.AuthMiddleware(http.HandlerFunc(apiHandler.TestSendNotification))).Methods("POST")

	// 媒体路由
	router.Handle("/media/upload", api.AuthMiddleware(http.HandlerFunc(apiHandler.UploadMedia))).Methods("POST")
	router.HandleFunc("/media/{type}/{filename}", apiHandler.GetMedia).Methods("GET")

	// WebSocket路由
	router.HandleFunc("/ws", wsHandler.HandleWebSocket)

	// 创建上传目录
	os.MkdirAll("uploads", 0755)

	// 添加CORS和日志中间件
	handler := api.CORSMiddleware(api.LoggingMiddleware(router))

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

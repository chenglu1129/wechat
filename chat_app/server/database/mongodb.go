package database

import (
	"context"
	"time"
	
	"chat_app/server/config"
	
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/bson"
)

// MongoDB 持有MongoDB数据库连接
type MongoDB struct {
	Client   *mongo.Client
	Database *mongo.Database
}

// NewMongoDB 创建新的MongoDB连接
func NewMongoDB(config *config.MongoDBConfig) (*MongoDB, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	
	clientOptions := options.Client().ApplyURI(config.URI)
	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		return nil, err
	}
	
	// 测试连接
	err = client.Ping(ctx, nil)
	if err != nil {
		return nil, err
	}
	
	database := client.Database(config.Database)
	
	return &MongoDB{
		Client:   client,
		Database: database,
	}, nil
}

// Close 关闭数据库连接
func (m *MongoDB) Close(ctx context.Context) error {
	return m.Client.Disconnect(ctx)
}

// InitCollections 初始化集合
func (m *MongoDB) InitCollections() error {
	ctx := context.Background()
	
	// 创建消息集合
	err := m.Database.CreateCollection(ctx, "messages")
	if err != nil {
		// 如果集合已存在，忽略错误
		if !isCollectionExistsError(err) {
			return err
		}
	}
	
	// 创建索引
	messagesCollection := m.Database.Collection("messages")
	
	// 为发送者和接收者创建索引
	_, err = messagesCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{
			{Key: "sender_id", Value: 1},
			{Key: "receiver_id", Value: 1},
		},
	})
	if err != nil {
		return err
	}
	
	// 为群组消息创建索引
	_, err = messagesCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{
			{Key: "group_id", Value: 1},
		},
	})
	if err != nil {
		return err
	}
	
	// 为时间戳创建索引
	_, err = messagesCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{
			{Key: "timestamp", Value: 1},
		},
	})
	
	return err
}

// 检查错误是否为"集合已存在"错误
func isCollectionExistsError(err error) bool {
	// MongoDB的错误处理比较复杂，这里简化处理
	// 实际应用中可能需要更精确的错误类型检查
	return err != nil && err.Error() == "collection already exists"
} 
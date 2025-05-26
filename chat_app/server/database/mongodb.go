package database

import (
	"context"
	"fmt"
	"time"

	"chat_app/server/config"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
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

	// 检查消息集合是否存在
	collections, err := m.Database.ListCollectionNames(ctx, bson.M{"name": "messages"})
	if err != nil {
		return err
	}

	// 如果消息集合不存在，创建它
	if len(collections) == 0 {
		err := m.Database.CreateCollection(ctx, "messages")
		if err != nil {
			return err
		}
		fmt.Println("创建消息集合成功")
	} else {
		fmt.Println("消息集合已存在，跳过创建")
	}

	// 获取消息集合
	messagesCollection := m.Database.Collection("messages")

	// 检查并创建索引
	cursor, err := messagesCollection.Indexes().List(ctx)
	if err != nil {
		return err
	}
	defer cursor.Close(ctx)

	// 解析现有索引
	var existingIndexes []bson.M
	if err = cursor.All(ctx, &existingIndexes); err != nil {
		return err
	}

	// 检查发送者和接收者索引
	hasSenderReceiverIndex := false
	hasGroupIndex := false
	hasTimestampIndex := false

	for _, idx := range existingIndexes {
		if idx["name"] == "sender_id_1_receiver_id_1" {
			hasSenderReceiverIndex = true
		}
		if idx["name"] == "group_id_1" {
			hasGroupIndex = true
		}
		if idx["name"] == "timestamp_1" {
			hasTimestampIndex = true
		}
	}

	// 创建缺失的索引
	if !hasSenderReceiverIndex {
		_, err = messagesCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
			Keys: bson.D{
				{Key: "sender_id", Value: 1},
				{Key: "receiver_id", Value: 1},
			},
		})
		if err != nil {
			return err
		}
		fmt.Println("创建发送者和接收者索引成功")
	}

	if !hasGroupIndex {
		_, err = messagesCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
			Keys: bson.D{
				{Key: "group_id", Value: 1},
			},
		})
		if err != nil {
			return err
		}
		fmt.Println("创建群组索引成功")
	}

	if !hasTimestampIndex {
		_, err = messagesCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
			Keys: bson.D{
				{Key: "timestamp", Value: 1},
			},
		})
		if err != nil {
			return err
		}
		fmt.Println("创建时间戳索引成功")
	}

	return nil
}

// 检查错误是否为"集合已存在"错误
func isCollectionExistsError(err error) bool {
	// MongoDB的错误处理比较复杂，这里简化处理
	// 实际应用中可能需要更精确的错误类型检查
	return err != nil && err.Error() == "collection already exists"
}

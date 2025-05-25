package database

import (
	"context"
	"time"

	"chat_app/server/models"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// MongoMessageRepository MongoDB实现的消息仓库
type MongoMessageRepository struct {
	db         *mongo.Database
	collection *mongo.Collection
}

// NewMessageRepository 创建新的MongoDB消息仓库
func NewMessageRepository(mongodb *MongoDB) models.MessageRepository {
	if mongodb == nil || mongodb.Client == nil {
		return nil
	}

	return &MongoMessageRepository{
		db:         mongodb.Database,
		collection: mongodb.Database.Collection("messages"),
	}
}

// SaveMessage 保存消息到MongoDB
func (r *MongoMessageRepository) SaveMessage(message *models.Message) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := r.collection.InsertOne(ctx, message)
	return err
}

// GetMessageByID 根据ID获取消息
func (r *MongoMessageRepository) GetMessageByID(id string) (*models.Message, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	objectID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		return nil, err
	}

	var message models.Message
	err = r.collection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&message)
	if err != nil {
		return nil, err
	}

	return &message, nil
}

// GetMessagesBetweenUsers 获取两个用户之间的消息历史
func (r *MongoMessageRepository) GetMessagesBetweenUsers(userID1, userID2 string, limit, offset int) ([]*models.Message, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 构建查询条件：(sender=userID1 AND receiver=userID2) OR (sender=userID2 AND receiver=userID1)
	filter := bson.M{
		"$or": []bson.M{
			{
				"sender_id":   userID1,
				"receiver_id": userID2,
			},
			{
				"sender_id":   userID2,
				"receiver_id": userID1,
			},
		},
	}

	// 设置排序、分页
	opts := options.Find().
		SetSort(bson.M{"timestamp": -1}).
		SetLimit(int64(limit)).
		SetSkip(int64(offset))

	cursor, err := r.collection.Find(ctx, filter, opts)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var messages []*models.Message
	if err = cursor.All(ctx, &messages); err != nil {
		return nil, err
	}

	return messages, nil
}

// GetGroupMessages 获取群组消息历史
func (r *MongoMessageRepository) GetGroupMessages(groupID string, limit, offset int) ([]*models.Message, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	filter := bson.M{"group_id": groupID}

	opts := options.Find().
		SetSort(bson.M{"timestamp": -1}).
		SetLimit(int64(limit)).
		SetSkip(int64(offset))

	cursor, err := r.collection.Find(ctx, filter, opts)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var messages []*models.Message
	if err = cursor.All(ctx, &messages); err != nil {
		return nil, err
	}

	return messages, nil
}

// MarkMessageAsRead 标记消息为已读
func (r *MongoMessageRepository) MarkMessageAsRead(id string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	objectID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		return err
	}

	_, err = r.collection.UpdateOne(
		ctx,
		bson.M{"_id": objectID},
		bson.M{"$set": bson.M{"read": true}},
	)

	return err
}

// MarkAllMessagesAsReadBetweenUsers 标记用户之间的所有消息为已读
func (r *MongoMessageRepository) MarkAllMessagesAsReadBetweenUsers(senderID, receiverID string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := r.collection.UpdateMany(
		ctx,
		bson.M{
			"sender_id":   senderID,
			"receiver_id": receiverID,
			"read":        false,
		},
		bson.M{"$set": bson.M{"read": true}},
	)

	return err
}

// GetUnreadMessageCount 获取用户的未读消息数
func (r *MongoMessageRepository) GetUnreadMessageCount(userID string) (int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	count, err := r.collection.CountDocuments(
		ctx,
		bson.M{
			"receiver_id": userID,
			"read":        false,
		},
	)

	return int(count), err
}

// DeleteMessage 删除消息
func (r *MongoMessageRepository) DeleteMessage(id string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	objectID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		return err
	}

	_, err = r.collection.DeleteOne(ctx, bson.M{"_id": objectID})
	return err
}

// DeleteMessagesBetweenUsers 删除两个用户之间的所有消息
func (r *MongoMessageRepository) DeleteMessagesBetweenUsers(userID1, userID2 string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := r.collection.DeleteMany(
		ctx,
		bson.M{
			"$or": []bson.M{
				{
					"sender_id":   userID1,
					"receiver_id": userID2,
				},
				{
					"sender_id":   userID2,
					"receiver_id": userID1,
				},
			},
		},
	)

	return err
}

// DeleteGroupMessages 删除群组的所有消息
func (r *MongoMessageRepository) DeleteGroupMessages(groupID string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := r.collection.DeleteMany(ctx, bson.M{"group_id": groupID})
	return err
}

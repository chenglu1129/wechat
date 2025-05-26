-- 添加avatar_url列到users表
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(255);

-- 更新group_repository.go中的查询
-- 这个文件在SQL查询中包含了avatar_url字段
-- 但数据库中可能还没有这个字段 
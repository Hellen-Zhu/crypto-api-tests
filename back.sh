#!/bin/bash

# --- 配置 ---
DB_NAME="autotest"
DB_USER="admin"
BACKUP_DIR="./database/backups" # 备份到项目目录下的 database/backups 文件夹
DATE=$(date +"%Y-%m-%d_%H%M%S")

# 确保备份目录存在
mkdir -p $BACKUP_DIR

# --- 执行备份 ---
# pg_dump 会提示输入密码。为了自动化，请使用 .pgpass 文件
echo "Starting backup for database: $DB_NAME"
echo "Backup will be saved to: $BACKUP_DIR/$DB_NAME-$DATE.backup"

# 检查是否安装了 PostgreSQL 客户端工具
if ! command -v pg_dump &> /dev/null; then
    echo "Error: pg_dump not found. Please install PostgreSQL client tools."
    echo "On macOS: brew install postgresql"
    echo "On Ubuntu: sudo apt-get install postgresql-client"
    exit 1
fi

# 执行备份
pg_dump -U $DB_USER -d $DB_NAME -F c -b -v -f "$BACKUP_DIR/$DB_NAME-$DATE.backup"

if [ $? -eq 0 ]; then
    echo "✅ Backup completed successfully!"
    echo "📁 Backup file: $BACKUP_DIR/$DB_NAME-$DATE.backup"
    
    # --- 清理旧的备份 (可选，但推荐) ---
    # 删除超过7天的备份文件
    echo "🧹 Cleaning up old backups..."
    find $BACKUP_DIR -type f -mtime +7 -name '*.backup' -delete
    
    # 显示备份文件列表
    echo "📋 Current backup files:"
    ls -la $BACKUP_DIR/*.backup 2>/dev/null || echo "No backup files found"
else
    echo "❌ Backup failed!"
    exit 1
fi

#!/bin/bash
# backup.sh — ежедневный бэкап БД пивной энциклопедии.
#
# Запускать через cron на VPS:
#   crontab -e
#   0 3 * * * /app/backup.sh
#
# Или через docker exec:
#   docker exec beer_app /app/backup.sh
#
# Хранит последние 7 бэкапов (ротация).

set -e

BACKUP_DIR="/app/data/backups"
DB_PATH="/app/data/beer_database.db"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/beer_$TIMESTAMP.db"

mkdir -p "$BACKUP_DIR"

echo "📦 Создание бэкапа: $BACKUP_FILE"

# Используем SQLite Online Backup API (не блокирует чтение/запись)
sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'" 2>/dev/null || cp "$DB_PATH" "$BACKUP_FILE"

# Сжимаем
gzip -f "$BACKUP_FILE"
echo "✅ Сжато: $(ls -lh ${BACKUP_FILE}.gz | awk '{print $5}')"

# Ротация: удаляем бэкапы старше 7 дней
find "$BACKUP_DIR" -name "beer_*.db.gz" -mtime +7 -delete
echo "🧹 Удалены бэкапы старше 7 дней"

# Статистика
COUNT=$(find "$BACKUP_DIR" -name "beer_*.db.gz" | wc -l)
SIZE=$(du -sh "$BACKUP_DIR" | awk '{print $1}')
echo "📊 Всего бэкапов: $COUNT, размер: $SIZE"

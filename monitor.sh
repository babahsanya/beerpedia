#!/bin/bash
# monitor.sh — проверка здоровья системы пивной энциклопедии.
# Запускать вручную или через cron для алертов.
#
# Использование на VPS:
#   docker exec beer_app /app/monitor.sh
# Или снаружи:
#   bash monitor.sh

set -e

echo "🏥 Проверка здоровья пивной энциклопедии"
echo "========================================"

# 1. Flask/Gunicorn отвечает?
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Flask: отвечает (200)"
else
    echo "❌ Flask: НЕ отвечает (HTTP $HTTP_CODE)"
fi

# 2. БД доступна и не повреждена?
DB_SIZE=$(stat -c%s /app/data/beer_database.db 2>/dev/null || echo "0")
if [ "$DB_SIZE" -gt 1000000 ]; then
    echo "✅ БД: $((DB_SIZE / 1024 / 1024)) МБ"
else
    echo "❌ БД: подозрительно маленькая или отсутствует ($DB_SIZE байт)"
fi

# 3. Диск не переполнен?
DISK_USAGE=$(df /app/data 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -lt 90 ]; then
    echo "✅ Диск: ${DISK_USAGE}% занято"
else
    echo "⚠️  Диск: ${DISK_USAGE}% занято (близко к пределу!)"
fi

# 4. Память контейнера?
MEM_USAGE=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo "0")
if [ "$MEM_USAGE" -gt 0 ]; then
    MEM_MB=$((MEM_USAGE / 1024 / 1024))
    if [ "$MEM_MB" -lt 500 ]; then
        echo "✅ Память: ${MEM_MB} МБ"
    else
        echo "⚠️  Память: ${MEM_MB} МБ (много!)"
    fi
fi

# 5. Кол-во позиций в БД (через sqlite3 если есть)
if command -v sqlite3 &> /dev/null; then
    BEER_COUNT=$(sqlite3 /app/data/beer_database.db "SELECT COUNT(*) FROM products_full" 2>/dev/null || echo "0")
    if [ "$BEER_COUNT" -gt 1000 ]; then
        echo "✅ Данные: $BEER_COUNT позиций в базе"
    else
        echo "⚠️  Данные: только $BEER_COUNT позиций"
    fi
fi

# 6. Последний бэкап
LATEST_BACKUP=$(ls -t /app/data/backups/*.gz 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_AGE=$(( ($(date +%s) - $(stat -c%Y "$LATEST_BACKUP")) / 3600 ))
    if [ "$BACKUP_AGE" -lt 48 ]; then
        echo "✅ Бэкап: ${BACKUP_AGE}ч назад"
    else
        echo "⚠️  Бэкап: ${BACKUP_AGE}ч назад (устарел!)"
    fi
else
    echo "⚠️  Бэкап: не найден"
fi

echo "========================================"
echo "Проверка завершена."

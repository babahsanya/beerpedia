#!/bin/sh
# entrypoint.sh — инициализация при первом запуске контейнера.
#
# Проверяет есть ли beer_database.db. Если нет — запускает полный конвейер
# (парсер → картинки → стили). Если есть — просто стартует gunicorn.

set -e

echo "🍺 Пивная энциклопедия — запуск..."

# Проверка наличия базы данных
if [ ! -f /app/data/beer_database.db ]; then
    echo "📦 База данных не найдена. Первичная инициализация..."
    echo "   Это займёт ~1-2 часа (парсинг + картинки)."
    mkdir -p /app/data

    # Запускаем полный конвейер (парсер создаст БД в текущей директории)
    cd /app/data
    python /app/run_full_pipeline.py --fresh
    cd /app

    echo "✅ Инициализация завершена."
else
    echo "✅ База данных найдена."
fi

# Проверка справочника стилей
if [ ! -f /app/data/beer_styles.db ]; then
    python /app/style_guide.py 2>/dev/null || true
fi

echo "🚕 Запуск Gunicorn (production server)..."
# Gunicorn с ротацией логов и ограничением memory/timeout.
# --max-requests: воркер перезапускается после 1000 запросов (защита от memory leaks).
# --access-logfile -: логи доступа в stdout (Docker их собирает).
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers ${GUNICORN_WORKERS:-4} \
    --timeout 120 \
    --graceful-timeout 30 \
    --max-requests 1000 \
    --max-requests-jitter 50 \
    --access-logfile - \
    --error-logfile - \
    --log-level warning \
    app:app

# Dockerfile для пивной энциклопедии.
# Многоэтапная сборка: сначала парсер/кеш/зависимости, потом тонкий runtime.
FROM python:3.12-slim AS base

# Системные зависимости для lxml/BeautifulSoup (на всякий случай)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ libxml2-dev libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Сначала копируем только requirements — для кэша слоёв Docker
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# Копируем код проекта
COPY . .

# Точка входа: инициализация БД при первом запуске + gunicorn
RUN chmod +x entrypoint.sh

EXPOSE 8000

# Gunicorn: 4 воркера, таймаут 120 (для долгих каталог-запросов),
# bind на 8000 (Nginx проксирует сюда).
CMD ["./entrypoint.sh"]

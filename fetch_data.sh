#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# 📦 Beerpedia — скачивание данных (база + картинки) с GitHub Releases
# ============================================================================
# Запускать в Termux, в папке ~/beerpedia:
#   bash fetch_data.sh
#
# Скачивает beerpedia_data.zip (~250 МБ) с GitHub и распаковывает.
# Требует: curl, unzip (установит сам если нужно).
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Репозиторий ( babahsanya / beer )
OWNER="babahsanya"
REPO="beer"
TAG="data-v1"
ASSET_NAME="beerpedia_data.zip"

cd "$(dirname "$0")"

echo -e "${CYAN}📦 Beerpedia — загрузка данных${NC}"
echo "============================================"

# ──────────────────────────────────────────────────────────────────────────────
# 0. ПРОВЕРКА ЗАВИСИМОСТЕЙ
# ──────────────────────────────────────────────────────────────────────────────
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${YELLOW}Устанавливаю curl...${NC}"
    pkg install curl -y >/dev/null
fi
if ! command -v unzip >/dev/null 2>&1; then
    echo -e "${YELLOW}Устанавливаю unzip...${NC}"
    pkg install unzip -y >/dev/null
fi

# ──────────────────────────────────────────────────────────────────────────────
# 1. ПРОВЕРКА: МОЖЕТ ДАННЫЕ УЖЕ ЕСТЬ?
# ──────────────────────────────────────────────────────────────────────────────
if [ -f "beer_database.db" ]; then
    ROWS=$(python -c "import sqlite3; print(sqlite3.connect('beer_database.db').execute('SELECT COUNT(*) FROM products_full').fetchone()[0])" 2>/dev/null || echo "?")
    if [ "$ROWS" != "?" ] && [ "$ROWS" -gt 100 ]; then
        echo -e "${GREEN}✓ Полная база уже на месте: ${ROWS} позиций${NC}"
        echo -e "${YELLOW}Перезаписать? (y/N)${NC}"
        read -r ANSWER
        if [ "$ANSWER" != "y" ] && [ "$ANSWER" != "Y" ]; then
            echo "Отмена. Данные не тронуты."
            exit 0
        fi
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2. ПОИСК РЕЛИЗА ЧЕРЕЗ GitHub API
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[1/3] Ищу релиз ${TAG}...${NC}"

# Пробуем публичный API (без токена). Если репозиторий приватный — нужен токен.
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${OWNER}/${REPO}/releases/tags/${TAG}" 2>/dev/null || echo "")

if [ -z "$RELEASE_JSON" ]; then
    echo -e "${RED}❌ Релиз ${TAG} не найден!${NC}"
    echo ""
    echo -e "${YELLOW}Возможные причины:${NC}"
    echo "  • Релиз ещё не создан на ПК (см. README_MOBILE.md → раздел «Релизы»)"
    echo "  • Репозиторий приватный (нужен токен)"
    echo ""
    echo -e "${YELLOW}Альтернативный способ:${NC}"
    echo "  Запустите на ПК: bash pack_data.sh"
    echo "  Затем перенесите beerpedia_data.zip на телефон вручную."
    exit 1
fi

# Извлекаем URL для скачивания ассета (browser_download_url)
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for asset in data.get('assets', []):
        if asset.get('name') == '${ASSET_NAME}':
            print(asset.get('browser_download_url', ''))
            break
except Exception:
    pass
")

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}❌ В релизе ${TAG} нет файла ${ASSET_NAME}!${NC}"
    echo "   Создайте релиз на ПК: bash pack_data.sh && bash publish_release.sh"
    exit 1
fi

# Размер ассета для информации
ASSET_SIZE=$(echo "$RELEASE_JSON" | python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for asset in data.get('assets', []):
        if asset.get('name') == '${ASSET_NAME}':
            mb = asset.get('size', 0) / 1024 / 1024
            print(f'{mb:.0f} МБ')
            break
except Exception:
    pass
" 2>/dev/null || echo "?")

echo -e "${GREEN}✓ Релиз найден. Размер: ${ASSET_SIZE}${NC}"

# ──────────────────────────────────────────────────────────────────────────────
# 3. СКАЧИВАНИЕ
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[2/3] Скачиваю ${ASSET_NAME} (~${ASSET_SIZE})...${NC}"
echo -e "   Это займёт несколько минут в зависимости от скорости Wi-Fi."
echo ""

# Прогресс-бар через curl
curl -L --progress-bar -o "${ASSET_NAME}.tmp" "$DOWNLOAD_URL"

# Проверка что файл скачался и ненулевой
if [ ! -s "${ASSET_NAME}.tmp" ]; then
    echo -e "${RED}❌ Ошибка скачивания — файл пустой!${NC}"
    rm -f "${ASSET_NAME}.tmp"
    exit 1
fi

mv "${ASSET_NAME}.tmp" "$ASSET_NAME"
echo -e "${GREEN}✓ Скачано: $(du -h $ASSET_NAME | cut -f1)${NC}"

# ──────────────────────────────────────────────────────────────────────────────
# 4. РАСПАКОВКА
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[3/3] Распаковываю...${NC}"

# Бэкап старой базы на всякий случай (если была демо)
if [ -f "beer_database.db" ]; then
    mv beer_database.db "beer_database.db.bak.$(date +%s)" 2>/dev/null || true
fi

unzip -o "$ASSET_NAME" >/dev/null
rm -f "$ASSET_NAME"

# Очистка старых бэкапов (оставляем только последний)
ls -t beer_database.db.bak.* 2>/dev/null | tail -n +2 | xargs rm -f 2>/dev/null || true

# Проверка результата
if [ -f "beer_database.db" ]; then
    ROWS=$(python -c "import sqlite3; print(sqlite3.connect('beer_database.db').execute('SELECT COUNT(*) FROM products_full').fetchone()[0])" 2>/dev/null || echo "?")
    IMG_COUNT=$(ls static/images 2>/dev/null | wc -l)
    LOGO_COUNT=$(ls static/breweries 2>/dev/null | wc -l)
    echo ""
    echo "============================================"
    echo -e "${GREEN}🎉 ДАННЫЕ ЗАГРУЖЕНЫ!${NC}"
    echo "============================================"
    echo -e "${CYAN}📦 База данных:${NC}  ${ROWS} позиций"
    echo -e "${CYAN}🖼  Картинки:${NC}     ${IMG_COUNT} шт."
    echo -e "${CYAN}🏭 Логотипы:${NC}     ${LOGO_COUNT} шт."
    echo ""
    echo -e "Запустите: ${CYAN}beerpedia${NC}"
    echo -e "Браузер:   ${CYAN}http://127.0.0.1:8000${NC}"
else
    echo -e "${RED}❌ Ошибка: beer_database.db не появился после распаковки!${NC}"
    exit 1
fi

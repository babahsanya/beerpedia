#!/bin/bash
# ============================================================================
# 🚀 Beerpedia — публикация данных в GitHub Release (для скачивания на Android)
# ============================================================================
# Запускается НА ПК (где есть полная база и картинки).
#
# Что делает:
#   1. Упаковывает beer_database.db + картинки в beerpedia_data.zip
#   2. Создаёт (или обновляет) GitHub Release с тегом data-v1
#   3. Загружает zip как asset (прямая ссылка для fetch_data.sh)
#
# Требования:
#   - Установленный gh CLI (GitHub CLI): https://cli.github.com/
#   - Авторизация: gh auth login
#
# Запуск:
#   bash publish_release.sh
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

cd "$(dirname "$0")"

TAG="data-v1"
ASSET_NAME="beerpedia_data.zip"

echo -e "${CYAN}🚀 Beerpedia — публикация данных в GitHub Release${NC}"
echo "============================================"

# ──────────────────────────────────────────────────────────────────────────────
# 0. ПРОВЕРКИ
# ──────────────────────────────────────────────────────────────────────────────
if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}❌ GitHub CLI (gh) не установлен!${NC}"
    echo "   Установите: https://cli.github.com/"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}❌ Не авторизован в GitHub CLI!${NC}"
    echo "   Выполните: gh auth login"
    exit 1
fi

if [ ! -f "beer_database.db" ]; then
    echo -e "${RED}❌ beer_database.db не найден!${NC}"
    exit 1
fi

DB_ROWS=$(python -c "import sqlite3; print(sqlite3.connect('beer_database.db').execute('SELECT COUNT(*) FROM products_full').fetchone()[0])" 2>/dev/null || echo "?")
echo -e "${GREEN}✓ База: ${DB_ROWS} позиций${NC}"

# ────────────────────────────────────────────────────────────────
# 1. УПАКОВКА
# ────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[1/3] Упаковываю данные...${NC}"
rm -f "$ASSET_NAME"

# Упаковываем через Python (работает везде, не требует системного zip)
python pack_data.py

ZIP_SIZE=$(du -h "$ASSET_NAME" | cut -f1)
echo -e "${GREEN}✓ Создан архив: ${ASSET_NAME} (${ZIP_SIZE})${NC}"

# ────────────────────────────────────────────────────────────────
# 2. УДАЛЕНИЕ СТАРОГО РЕЛИЗА (если есть)
# ────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[2/3] Обновляю релиз ${TAG}...${NC}"

if gh release view "$TAG" >/dev/null 2>&1; then
    echo "   Старый релиз найден — удаляю..."
    gh release delete "$TAG" --yes --cleanup-tag >/dev/null 2>&1 || true
fi

# ────────────────────────────────────────────────────────────────
# 3. СОЗДАНИЕ НОВОГО РЕЛИЗА
# ────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[3/3] Публикую новый релиз...${NC}"

RELEASE_NOTES="## 📦 Данные Beerpedia ($(date '+%Y-%m-%d'))

**Состав:**
- \`beer_database.db\` — база данных (${DB_ROWS} позиций)
- \`static/images/\` — картинки пива
- \`static/breweries/\` — логотипы пивоварен
- Размер архива: ${ZIP_SIZE}

**Как использовать на Android:**
\`\`\`bash
cd ~/beerpedia
bash fetch_data.sh
\`\`\`
"

gh release create "$TAG" \
    "$ASSET_NAME" \
    --title "Данные Beerpedia ($(date '+%Y-%m-%d'))" \
    --notes "$RELEASE_NOTES" \
    >/dev/null

# Очистка локального архива (он уже в релизе)
rm -f "$ASSET_NAME"

echo ""
echo "============================================"
echo -e "${GREEN}🎉 ОПУБЛИКОВАНО!${NC}"
echo "============================================"
echo ""
echo -e "${CYAN}📥 Прямая ссылка для скачивания:${NC}"
echo "   https://github.com/babahsanya/beerpedia/releases/tag/${TAG}"
echo ""
echo -e "${CYAN}📱 На телефоне теперь можно:${NC}"
echo "   cd ~/beerpedia"
echo "   bash fetch_data.sh"
echo ""
echo -e "${YELLOW}💡 Чтобы обновить данные в будущем:${NC}"
echo "   Снова запустите этот скрипт на ПК — он пересоздаст релиз."

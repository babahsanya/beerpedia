#!/bin/bash
# ============================================================================
# 📦 Beerpedia — упаковка данных для переноса на Android
# ============================================================================
# Запускается НА ПК (где есть полная база и картинки).
# Создаёт один zip-архив с базой + картинками (~500 МБ → ~250 МБ после сжатия).
#
# Запуск:
#   bash pack_data.sh
#
# Результат: beerpedia_data.zip в корне проекта.
# Перенести на телефон (через Telegram/USB/облако) и распаковать в ~/beerpedia.
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

cd "$(dirname "$0")"

echo -e "${CYAN}📦 Beerpedia — упаковка данных${NC}"
echo "============================================"

# Проверки
if [ ! -f "beer_database.db" ]; then
    echo -e "${RED}❌ Ошибка: beer_database.db не найден!${NC}"
    echo "   Сначала запустите полный парсинг."
    exit 1
fi

DB_SIZE=$(du -h beer_database.db | cut -f1)
echo -e "${GREEN}✓ База данных: ${DB_SIZE}${NC}"

# Удаляем старый архив
rm -f beerpedia_data.zip

echo -e "${YELLOW}📦 Упаковываю (это займёт ~1-2 минуты)...${NC}"

# Упаковываем через Python (работает везде, не требует системного zip)
python pack_data.py

FINAL_SIZE=$(du -h beerpedia_data.zip | cut -f1)
echo ""
echo "============================================"
echo -e "${GREEN}🎉 ГОТОВО!${NC}"
echo "============================================"
echo ""
echo -e "${CYAN}📦 Архив:${NC} beerpedia_data.zip (${FINAL_SIZE})"
echo ""
echo -e "${YELLOW}📱 Как перенести на Android:${NC}"
echo ""
echo -e "   ${CYAN}Способ 1 (USB):${NC}"
echo "      1. Скопируйте beerpedia_data.zip на телефон"
echo "      2. В Termux: pkg install unzip"
echo "      3. cd ~/beerpedia && unzip /путь/к/beerpedia_data.zip"
echo ""
echo -e "   ${CYAN}Способ 2 (по Wi-Fi, рекомендуется для 500 МБ):${NC}"
echo "      На ПК:   python -m http.server 8000"
echo "      На телефоне (в Termux):"
echo "         cd ~/beerpedia"
echo "         curl -O http://[IP_ПК]:8000/beerpedia_data.zip"
echo "         unzip beerpedia_data.zip"
echo "         rm beerpedia_data.zip"
echo ""
echo -e "   ${CYAN}Способ 3 (Telegram/облако):${NC}"
echo "      Отправьте архив себе в Telegram, скачайте в Termux через"
echo "      путь /sdcard/Download/, затем распакуйте."
echo ""

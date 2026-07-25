#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# 🍺 Beerpedia — автоустановщик для Android (Termux)
# ============================================================================
# Что делает этот скрипт:
#   1. Устанавливает Python, Git, SQLite, OpenSSL
#   2. Клонирует проект beerpedia в папку ~/beerpedia
#   3. Создаёт виртуальное окружение и ставит зависимости
#   4. Проверяет наличие базы данных и картинок
#   5. Создаёт ярлык для быстрого запуска
#
# Запуск в Termux:
#   pkg install curl -y
#   curl -fsSL https://raw.githubusercontent.com/babahsanya/pars-craftbeer/main/setup.sh | bash
#   (или просто: bash setup.sh)
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🍺 Beerpedia — установка на Android${NC}"
echo "============================================"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 1. УСТАНОВКА СИСТЕМНЫХ ПАКЕТОВ
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[1/5] Устанавливаю системные пакеты...${NC}"
pkg update -y >/dev/null 2>&1
pkg upgrade -y >/dev/null 2>&1
pkg install -y python git openssl-tool >/dev/null 2>&1
echo -e "${GREEN}✓ Python, Git, OpenSSL установлены${NC}"

# ──────────────────────────────────────────────────────────────────────────────
# 2. КЛОНИРОВАНИЕ ПРОЕКТА
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[2/5] Клонирую проект...${NC}"
PROJECT_DIR="$HOME/beerpedia"

# Удаляем старую версию, если есть (полная переустановка)
if [ -d "$PROJECT_DIR" ]; then
    echo "  Найдена старая установка. Обновляю..."
    cd "$PROJECT_DIR"
    git pull origin main >/dev/null 2>&1 || true
else
    cd "$HOME"
    git clone https://github.com/babahsanya/pars-craftbeer.git beerpedia
    cd "$PROJECT_DIR"
fi
echo -e "${GREEN}✓ Проект клонирован в ~/beerpedia${NC}"

# ──────────────────────────────────────────────────────────────────────────────
# 3. ВИРТУАЛЬНОЕ ОКРУЖЕНИЕ + ЗАВИСИМОСТИ
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[3/5] Создаю виртуальное окружение и ставлю зависимости...${NC}"

# Создаём venv (если нет)
if [ ! -d "venv" ]; then
    python -m venv venv
fi

# Активируем и ставим зависимости
source venv/bin/activate
pip install --upgrade pip >/dev/null 2>&1
pip install -r requirements.txt
echo -e "${GREEN}✓ Зависимости установлены:$(cat requirements.txt | grep -v '^#' | tr '\n' ' ')${NC}"

# ──────────────────────────────────────────────────────────────────────────────
# 4. ПРОВЕРКА БАЗЫ ДАННЫХ И КАРТИНОК
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[4/5] Проверяю данные...${NC}"

# --- 4.1. База данных ---
if [ -f "beer_database.db" ]; then
    DB_SIZE=$(du -h beer_database.db | cut -f1)
    ROWS=$(python -c "import sqlite3; print(sqlite3.connect('beer_database.db').execute('SELECT COUNT(*) FROM products_full').fetchone()[0])" 2>/dev/null || echo "?")
    echo -e "${GREEN}✓ База данных найдена: ${DB_SIZE} (${ROWS} позиций)${NC}"
else
    echo -e "${RED}  ⚠️  База данных beer_database.db НЕ найдена!${NC}"
    echo -e "${RED}     Проект запустится, но будет ПУСТОЙ.${NC}"
    echo ""
    echo -e "${YELLOW}     📦 Как получить базу:${NC}"
    echo "     1. Скачайте beer_database.db с ПК (через Telegram/облако)"
    echo "     2. Скопируйте в: $PROJECT_DIR/"
    echo "     3. Перезапустите: ~/beerpedia/run.sh"
    echo ""
    echo -e "${YELLOW}     Или (вариант B) — запустите мини-демо-базу:${NC}"
    echo "        cd ~/beerpedia && bash create_demo_db.sh"
fi

# --- 4.2. Картинки пива ---
if [ -d "static/images" ]; then
    IMG_COUNT=$(ls static/images 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ Картинки пива: ${IMG_COUNT} шт.${NC}"
else
    echo -e "${YELLOW}  ℹ️  Картинки пива (static/images/) не найдены.${NC}"
    echo -e "${YELLOW}     Проект будет показывать эмодзи 🍺 вместо фото.${NC}"
    echo -e "${YELLOW}     Это нормально — без картинок проект работает.${NC}"
fi

# --- 4.3. Логотипы пивоварен ---
if [ -d "static/breweries" ]; then
    LOGO_COUNT=$(ls static/breweries 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ Логотипы пивоварен: ${LOGO_COUNT} шт.${NC}"
else
    echo -e "${YELLOW}  ℹ️  Логотипы (static/breweries/) не найдены — проект работает без них.${NC}"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 5. ЯРЛЫК ЗАПУСКА
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[5/6] Создаю ярлык запуска...${NC}"

# run.sh — быстрый запуск (без переустановки)
cat > run.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Быстрый запуск Beerpedia
cd "$HOME/beerpedia"
source venv/bin/activate
echo "🍺 Запуск Beerpedia на http://127.0.0.1:8000"
echo "   Остановить: Ctrl+C"
echo ""
python app.py
EOF
chmod +x run.sh
echo -e "${GREEN}✓ Ярлык создан: ~/beerpedia/run.sh${NC}"

# Добавляем алиас в .bashrc для быстрого доступа
BASHRC="$HOME/.bashrc"
if ! grep -q "alias beerpedia=" "$BASHRC" 2>/dev/null; then
    echo 'alias beerpedia="bash ~/beerpedia/run.sh"' >> "$BASHRC"
    echo -e "${GREEN}✓ Добавлен алиас: введите ${CYAN}beerpedia${NC} ${GREEN}в любом месте для запуска${NC}"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6. ПРЕДЛОЖИТЬ СКАЧАТЬ ДАННЫЕ
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[6/6] Проверяю данные...${NC}"

NEED_DATA=false
if [ ! -f "beer_database.db" ]; then
    NEED_DATA=true
elif [ "$(python -c "import sqlite3; print(sqlite3.connect('beer_database.db').execute('SELECT COUNT(*) FROM products_full').fetchone()[0])" 2>/dev/null || echo 0)" -lt 100 ]; then
    NEED_DATA=true
fi

if [ "$NEED_DATA" = true ]; then
    echo ""
    echo -e "${YELLOW}📦 База данных отсутствует или неполная.${NC}"
    echo -e "${YELLOW}   Можно скачать полную базу + картинки (~250 МБ) с GitHub.${NC}"
    echo ""
    echo -e "   ${CYAN}y${NC} = скачать полные данные (рекомендуется, нужен Wi-Fi)"
    echo -e "   ${CYAN}d${NC} = создать демо-базу (5 позиций, без интернета)"
    echo -e "   ${CYAN}n${NC} = пропустить (разобраться позже)"
    echo ""
    read -r -p "   Ваш выбор [y/d/n]: " CHOICE

    case "$CHOICE" in
        y|Y)
            echo ""
            bash fetch_data.sh || echo -e "${RED}   Не удалось скачать. Попробуйте позже: bash fetch_data.sh${NC}"
            ;;
        d|D)
            echo ""
            bash create_demo_db.sh
            ;;
        *)
            echo -e "${YELLOW}   Пропущено. Данные можно добавить позже:${NC}"
            echo "     bash fetch_data.sh        # скачать с GitHub"
            echo "     bash create_demo_db.sh    # демо-база"
            ;;
    esac
fi

# ──────────────────────────────────────────────────────────────────────────────
# ФИНАЛ
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo -e "${GREEN}🎉 УСТАНОВКА ЗАВЕРШЕНА!${NC}"
echo "============================================"
echo ""
echo -e "${CYAN}🚀 ЗАПУСК:${NC}"
echo "   beerpedia"
echo ""
echo -e "${CYAN}🌐 В БРАУЗЕРЕ:${NC}"
echo "   http://127.0.0.1:8000"
echo ""
echo -e "${CYAN}📦 УПРАВЛЕНИЕ ДАННЫМИ:${NC}"
echo "   bash fetch_data.sh        # скачать полные данные (~250 МБ)"
echo "   bash create_demo_db.sh    # демо-база (5 позиций)"
echo ""
echo -e "${CYAN}🔄 ОБНОВЛЕНИЕ КОДА:${NC}"
echo "   cd ~/beerpedia && git pull"


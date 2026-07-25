#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# 🍺 Beerpedia — создание ДЕМО-базы данных (если нет основной)
# ============================================================================
# Запускать только если beer_database.db отсутствует!
# Создаёт минимальную БД с тестовыми данными для проверки интерфейса.
# ============================================================================

set -e

cd "$(dirname "$0")"

if [ -f "beer_database.db" ]; then
    echo "⚠️  beer_database.db уже существует!"
    echo "   Удалите её сначала: rm beer_database.db"
    exit 1
fi

echo "🍺 Создаю демо-базу данных..."

python << 'PYEOF'
import sqlite3

conn = sqlite3.connect('beer_database.db')
c = conn.cursor()

# Точная схема как в products_full
c.execute("""
CREATE TABLE products_full (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    producer TEXT,
    brewery_full_name TEXT,
    brewery_country TEXT,
    brewery_city TEXT,
    category TEXT,
    style TEXT,
    substyle TEXT,
    abv REAL,
    volume INTEGER,
    ibu INTEGER,
    color TEXT,
    aroma TEXT,
    taste TEXT,
    description TEXT,
    mouthfeel TEXT,
    appearance TEXT,
    ingredients TEXT,
    hops TEXT,
    malt TEXT,
    yeast TEXT,
    additives TEXT,
    price TEXT,
    availability TEXT,
    barcode TEXT,
    rating REAL,
    rating_count INTEGER,
    reviews_count INTEGER,
    food_pairing TEXT,
    serving_temp TEXT,
    serving_glass TEXT,
    original_url TEXT UNIQUE,
    url_hash TEXT UNIQUE,
    image_url TEXT,
    additional_images TEXT,
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    parse_date TIMESTAMP,
    parse_success INTEGER DEFAULT 0,
    parse_attempts INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    local_image TEXT,
    local_gallery TEXT,
    og_value TEXT,
    style_family TEXT,
    category_detailed TEXT,
    color_ebc TEXT,
    container TEXT,
    untappd_url TEXT,
    brewery_logo TEXT,
    style_canonical TEXT
)
""")

# Демо-данные — 30 полей на каждую запись:
# name, producer, brewery_full_name, brewery_country, brewery_city,
# category, style, substyle, abv, volume, ibu, color,
# aroma, taste, description, mouthfeel, appearance,
# hops, malt, yeast, additives,
# price, availability, rating, rating_count, reviews_count,
# serving_temp, serving_glass,
# original_url, url_hash
beers = [
    ('Test IPA', 'AF Brew', 'AF Brew', 'Россия', 'Санкт-Петербург',
     'Пиво', 'American IPA', 'IPA', 6.5, 500, 65, 'Золотистый',
     'Хвойный, цитрусовый', 'Горький, хмелевой',
     'Свежий IPA с мощным хмелевым ароматом', 'Среднетелое', 'Пена стойкая',
     'Citra, Mosaic', 'Pale Ale', None, None,
     '350 ₽', 'В наличии', 4.2, 15, 3, '6-8°C', 'Tulip',
     'http://example.com/1', 'hash1'),
    ('Wheat Lager', 'Jaws', 'Jaws Brewery', 'Россия', 'Заречный',
     'Пиво', 'Wheat Beer', 'Weissbier', 4.8, 500, 18, 'Соломенный',
     'Банан, гвоздика', 'Мягкий, сладковатый',
     'Классический немецкий вайсбир', 'Полнотелое', 'Пена густая',
     None, 'Pilsner', 'Weihenstephan', None,
     '280 ₽', 'В наличии', 3.9, 22, 5, '4-6°C', 'Weizen',
     'http://example.com/2', 'hash2'),
    ('Imperial Stout', 'Saldens', 'Saldens', 'Россия', 'Тюмень',
     'Пиво', 'Stout', 'Imperial Stout', 11.0, 500, 75, 'Чёрный',
     'Шоколад, кофе', 'Сладкий, плотный',
     'Мощный империал стаут с нотами кофе и какао', 'Плотное', 'Пена кремовая',
     None, 'Chocolate', 'American', None,
     '550 ₽', 'В наличии', 4.5, 8, 2, '10-12°C', 'Snifter',
     'http://example.com/3', 'hash3'),
    ('Pilsner Urquell Clone', 'Bakunin', 'Bakunin Brewery', 'Россия', 'Екатеринбург',
     'Пиво', 'Pilsner', 'Czech Pilsner', 4.4, 500, 35, 'Золотистый',
     'Солод, травы', 'Горьковатый, чистый',
     'Классический чешский пилзнер', 'Лёгкое', 'Пена пышная',
     'Saaz', 'Pilsner', None, None,
     '220 ₽', 'В наличии', 3.7, 30, 8, '4-6°C', 'Pilsner',
     'http://example.com/4', 'hash4'),
    ('Sour Cherry', 'Velka Morava', 'Velka Morava', 'Россия', 'Москва',
     'Пиво', 'Sour', 'Flanders Red', 6.2, 330, 15, 'Красный',
     'Вишня, дуб', 'Кислый, фруктовый',
     'Кислый эль с вишней', 'Среднетелое', 'Пена розовая',
     None, None, None, 'Вишня',
     '420 ₽', 'В наличии', 4.0, 12, 4, '8-10°C', 'Sour',
     'http://example.com/5', 'hash5'),
]

c.executemany("""
    INSERT INTO products_full (
        name, producer, brewery_full_name, brewery_country, brewery_city,
        category, style, substyle, abv, volume, ibu, color,
        aroma, taste, description, mouthfeel, appearance,
        hops, malt, yeast, additives,
        price, availability, rating, rating_count, reviews_count,
        serving_temp, serving_glass,
        original_url, url_hash
    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
""", beers)

# Таблица стилей
c.execute("""
CREATE TABLE IF NOT EXISTS beer_styles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    family TEXT,
    title TEXT,
    style TEXT,
    slug TEXT UNIQUE,
    description TEXT,
    avg_abv REAL,
    min_abv REAL,
    max_abv REAL,
    ibu TEXT,
    srm TEXT,
    og TEXT,
    fg TEXT,
    in_guide INTEGER DEFAULT 1
)
""")

styles_data = [
    ('IPA', 'Американская семья IPA', 'American IPA', 'ipa', 'Ароматный, горький', 6.5, 5.5, 7.5, '40-70', '6-14', '1.056-1.070', '1.008-1.014', 1),
    ('WEIZEN', 'Пшеничное пиво', 'Weissbier', 'weissbier', 'Банан и гвоздика', 5.0, 4.3, 5.6, '8-15', '2-9', '1.044-1.052', '1.010-1.014', 1),
    ('STOUT', 'Тёмное пиво', 'Imperial Stout', 'imperial-stout', 'Кофейно-шоколадный', 9.0, 8.0, 12.0, '50-90', '40+', '1.075-1.115', '1.018-1.030', 1),
    ('LAGER', 'Лагер', 'Czech Pilsner', 'czech-pilsner', 'Чистый, солодовый', 4.4, 4.2, 4.8, '30-45', '3-7', '1.044-1.060', '1.013-1.017', 1),
    ('SOUR', 'Кислое пиво', 'Flanders Red', 'flanders-red', 'Кислый, фруктовый', 6.0, 4.8, 7.2, '10-25', '10-16', '1.048-1.057', '1.008-1.016', 1),
]

c.executemany("""
    INSERT INTO beer_styles (family, title, style, slug, description, avg_abv, min_abv, max_abv, ibu, srm, og, fg, in_guide)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
""", styles_data)

conn.commit()
conn.close()

print(f"✅ Создана демо-база: 5 позиций, 5 стилей")
print(f"   Это позволит проверить интерфейс на телефоне.")
print(f"   Для полных данных (7733 позиции) скопируйте beer_database.db с ПК.")
PYEOF

echo ""
echo "🎉 Демо-база создана! Теперь запустите: bash run.sh"

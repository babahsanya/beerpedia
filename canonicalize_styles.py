"""Канонизация названий стилей к 49 категориям сайта craftbeer78.ru.

У нас 842 «грязных» значения в поле style (смесь ru/en, синонимы, опечатки).
Этот скрипт добавляет колонку style_canonical с чистым каноническим названием,
соответствующим каталогу /beer-styles сайта.

Оригинальный style сохраняется без изменений (для сохранности данных).

CLI:
    python canonicalize_styles.py            # заполнить
    python canonicalize_styles.py --stats    # статистика
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parent
DB_PATH = APP_ROOT / "beer_database.db"

# Канонические стили (основные из /beer-styles) + keyword-паттерны.
# Порядок важен: более специфичные (lambic, gose) раньше общих (sour).
# Каждый стиль = (canonical_name, [keywords]).
CANONICAL_STYLES: list[tuple[str, list[str]]] = [
    # IPA — разные подвиды дают разный канон
    ("IPA — American",       ["ipa - american", "американский ипа", "american ipa"]),
    ("IPA — New England",    ["new england", "новой англии", "hazy", "милкшейк ипа", "milkshake ipa"]),
    ("IPA — Imperial/Double NE", ["double new england", "двойной ипа в стиле новой", "imperial ne"]),
    ("IPA — Imperial/Double", ["imperial / double", "двойной ипа", "double ipa"]),
    ("IPA — Triple",         ["triple ipa", "тройной ипа"]),
    ("IPA — Other",          ["ipa", "ипа", "cold ipa", "black ipa", "колд ипа"]),

    # Sour подвиды
    ("Sour — Fruited",       ["фруктовый кислый", "fruited sour", "фруктовый берлинер"]),
    ("Sour — Smoothie/Pastry", ["smoothie", "смузи", "pastry sour"]),
    ("Sour — Gose",          ["гозе", "gose", "томатный гозе", "грибной гозе", "гозе суп"]),
    ("Sour — Other",         ["sour", "кисл", "фламандск", "flanders"]),

    # Stout подвиды
    ("Stout — Imperial/Double", ["imperial", "имперск", "russian imperial", "русский имперск"]),
    ("Stout — Milk/Sweet",   ["milk", "молочн", "sweet stout"]),
    ("Stout — Pastry/Dessert", ["pastry", "десертн"]),
    ("Stout — Other",        ["stout", "стаут", "овсян", "oatmeal", "сухой стаут"]),

    ("Porter",               ["porter", "портер", "балтийск"]),
    ("Pale Ale — American",  ["pale ale", "американский светлый", "apa"]),
    ("Pale Ale — NE",        ["светлый эль в стиле новой", "ne pale"]),

    # Lager подвиды
    ("Pilsner",              ["pilsner", "пилснер", "пизлнер", "пилс", "чешский пил"]),
    ("Lager — Helles",       ["helles", "хеллес"]),
    ("Lager — Bock",         ["bock", "бок", "доппельбок", "doppelbock"]),
    ("Lager — Other",        ["lager", "лагер", "rauchbier", "копч", "кёльш", "vienna",
                              "festbier", "фестбир", "märzen", "мерцен", "kellerbier", "келлербир"]),

    # Lambic
    ("Lambic — Gueuze",      ["гёз", "gueuze", "гёза"]),
    ("Lambic — Fruit",       ["фруктовый ламбик", "вишневый ламбик", "малиновый ламбик"]),
    ("Lambic — Other",       ["lambic", "ламбик"]),

    # Belgian
    ("Belgian — Tripel",     ["tripel", "трипел", "трипл"]),
    ("Belgian — Quadrupel",  ["quadrupel", "квадрюпель", "quad"]),
    ("Belgian — Dubbel",     ["dubbel", "дюббель"]),
    ("Belgian — Saison",     ["saison", "сейзон", "сэзон", "сельский"]),
    ("Belgian — Blonde",     ["blond", "блонд"]),
    ("Belgian — Other",      ["belgian", "бельгий", "trappist", "траппист"]),

    # Mead
    ("Mead — Melomel",       ["melomel", "медомел", "ягодная медовух"]),
    ("Mead — Other",         ["mead", "медовух", "брагот", "braggot", "metheglin"]),

    # Cider
    ("Cider — Dry",          ["сухой сидр"]),
    ("Cider — Semi-sweet",   ["полусладкий сидр"]),
    ("Cider — Semi-dry",     ["полусухой сидр"]),
    ("Cider — Other",        ["cider", "сидр", "сайзер"]),

    ("Wheat",                ["wheat", "пшенич", "hefeweizen", "witbier", "бланш"]),
    ("Wild Ale",             ["wild ale", "дикий эль", "brett"]),
    ("Brown Ale",            ["brown ale", "коричневый"]),
    ("Red Ale",              ["red ale", "красный"]),
    ("Strong Ale / Barleywine", ["barleywine", "барливайн", "strong ale", "wee heavy", "крепкий эль"]),

    ("Non-Alcoholic",        ["non-alcoholic", "безалког", "без алкогол", "безакоголь"]),
    ("Fruit Beer",           ["fruit beer", "фруктовое пиво", "фруктовый эль", "grape ale",
                              "вишневый эль", "вишнёвый эль", "fruit ale", "pumpkin"]),
    ("Historical Beer",      ["historical", "историческ"]),
    ("English Bitter",       ["bitter", "горький английский", "esb"]),
    ("Golden Ale / Blond",   ["golden ale", "янтарный", "amber"]),
    ("Radler / Shandy",      ["radler", "радлер", "shandy"]),
]

FALLBACK = "Other"


def canonicalize(style: str | None) -> str:
    """Возвращает каноническое название стиля."""
    if not style:
        return FALLBACK
    s = style.lower()
    for canonical, keywords in CANONICAL_STYLES:
        for kw in keywords:
            if kw in s:
                return canonical
    return FALLBACK


def populate() -> tuple[int, int]:
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.execute("SELECT id, style FROM products_full ORDER BY id")
        rows = cur.fetchall()
        updates = []
        for beer_id, style in rows:
            canon = canonicalize(style)
            updates.append((canon, beer_id))
        conn.executemany(
            "UPDATE products_full SET style_canonical = ? WHERE id = ?", updates
        )
        conn.commit()
        total = len(rows)
        classified = sum(1 for c, _ in updates if c != FALLBACK)
        return total, classified
    finally:
        conn.close()


def show_stats() -> int:
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.execute(
            "SELECT style_canonical, COUNT(*) AS n FROM products_full "
            "GROUP BY style_canonical ORDER BY n DESC"
        )
        rows = cur.fetchall()
        total = sum(n for _, n in rows)
        print("=" * 60)
        print("Канонические стили (после нормализации)")
        print("=" * 60)
        for canon, n in rows:
            pct = 100 * n / total if total else 0
            print(f"  {canon:35s} {n:5d} ({pct:5.1f}%)")
        print(f"  {'ИТОГО':35s} {total:5d}")
        return 0
    finally:
        conn.close()


def main() -> int:
    ap = argparse.ArgumentParser(description="Канонизация стилей")
    ap.add_argument("--stats", action="store_true")
    args = ap.parse_args()

    if args.stats:
        return show_stats()

    if not DB_PATH.exists():
        print(f"База не найдена: {DB_PATH}")
        return 2

    #确保 колонка существует
    conn = sqlite3.connect(DB_PATH)
    cur = conn.execute("PRAGMA table_info(products_full)")
    cols = {row[1] for row in cur.fetchall()}
    if "style_canonical" not in cols:
        conn.execute("ALTER TABLE products_full ADD COLUMN style_canonical TEXT")
        conn.commit()
    conn.close()

    total, classified = populate()
    print(f"Готово: {total} позиций, {classified} ({100*classified/total:.1f}%) канонизировано")
    show_stats()
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Сбор логотипов пивоварен с craftbeer78.ru/breweries.

Парсит страницу /breweries (159 пивоварен), скачивает логотипы в
static/breweries/, добавляет колонку brewery_logo в products_full.

CLI:
    python fetch_brewery_logos.py            # скачать + обновить БД
    python fetch_brewery_logos.py --dry-run  # только показать что найдёт
"""

from __future__ import annotations

import argparse
import logging
import sqlite3
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
from bs4 import BeautifulSoup

APP_ROOT = Path(__file__).resolve().parent
DB_PATH = APP_ROOT / "beer_database.db"
LOGOS_DIR = APP_ROOT / "static" / "breweries"
BREWeries_URL = "https://craftbeer78.ru/breweries"

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("brewery_logos")

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0",
})


def fetch_breweries_list() -> list[dict]:
    """Парсит /breweries, возвращает список [{name, slug, logo_url}]."""
    r = SESSION.get(BREWeries_URL, timeout=20)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")
    cards = soup.select(".brewery_block2")
    result = []
    for card in cards:
        a = card.select_one('a[href*="/brewery/"]')
        img = card.select_one("img")
        name_el = card.select_one(".brew_name_block")
        if not a or not img:
            continue
        href = a.get("href", "")
        slug = href.strip("/").split("/")[-1] if href else ""
        name = name_el.get_text(strip=True) if name_el else slug
        logo_url = img.get("data-src") or img.get("src") or ""
        if "/images/breweries/" in logo_url and slug:
            result.append({"name": name, "slug": slug, "logo_url": logo_url})
    return result


def download_logo(brewery: dict) -> tuple[str, str | None]:
    """Скачивает логотип. Возвращает (slug, local_path | None)."""
    slug = brewery["slug"]
    url = brewery["logo_url"]
    ext = ".jpg"
    for e in (".png", ".jpg", ".jpeg", ".webp"):
        if url.lower().endswith(e):
            ext = e
            break
    dest = LOGOS_DIR / f"{slug}{ext}"
    if dest.exists() and dest.stat().st_size > 0:
        return slug, f"static/breweries/{slug}{ext}"
    try:
        resp = SESSION.get(url, timeout=15)
        if resp.status_code != 200:
            return slug, None
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(resp.content)
        return slug, f"static/breweries/{slug}{ext}"
    except Exception as e:
        log.debug("Ошибка загрузки %s: %s", url, e)
        return slug, None


def ensure_column():
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.execute("PRAGMA table_info(products_full)")
        cols = {row[1] for row in cur.fetchall()}
        if "brewery_logo" not in cols:
            conn.execute("ALTER TABLE products_full ADD COLUMN brewery_logo TEXT")
            conn.commit()
            log.info("Добавлена колонка brewery_logo")
    finally:
        conn.close()


def update_db(breweries: list[dict], logo_map: dict[str, str]):
    """Обновляет brewery_logo в products_full по slug пивоварни."""
    conn = sqlite3.connect(DB_PATH)
    updated = 0
    try:
        # для каждого slug находим все producer в БД с тем же slug
        from app import slugify  # переиспользуем
        # строим slug → producer маппинг
        cur = conn.execute(
            "SELECT DISTINCT producer FROM products_full WHERE producer IS NOT NULL AND producer != ''"
        )
        producer_to_slug = {}
        for (producer,) in cur.fetchall():
            producer_to_slug[producer] = slugify(producer)

        for producer, prod_slug in producer_to_slug.items():
            local = logo_map.get(prod_slug)
            if local:
                conn.execute(
                    "UPDATE products_full SET brewery_logo = ? WHERE producer = ?",
                    (local, producer),
                )
                updated += 1
        conn.commit()
    finally:
        conn.close()
    return updated


def main() -> int:
    ap = argparse.ArgumentParser(description="Сбор логотипов пивоварен")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    LOGOS_DIR.mkdir(parents=True, exist_ok=True)
    ensure_column()

    log.info("Парсинг %s ...", BREWeries_URL)
    breweries = fetch_breweries_list()
    log.info("Найдено пивоварен с логотипами: %d", len(breweries))

    if args.dry_run:
        for b in breweries[:10]:
            print(f"  {b['name']:25s} → {b['logo_url'].split('/')[-1]}")
        print(f"  ...всего {len(breweries)}")
        return 0

    # Скачиваем параллельно
    logo_map: dict[str, str] = {}
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(download_logo, b): b for b in breweries}
        done = 0
        for fut in as_completed(futures):
            slug, local = fut.result()
            done += 1
            if local:
                logo_map[slug] = local
            if done % 30 == 0:
                log.info("Скачано %d/%d", done, len(breweries))

    log.info("Логотипов скачано: %d/%d", len(logo_map), len(breweries))

    updated = update_db(breweries, logo_map)
    log.info("Обновлено записей в БД: %d пивоварен", updated)
    return 0


if __name__ == "__main__":
    sys.exit(main())

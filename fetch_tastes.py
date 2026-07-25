"""Сбор тегов вкусов с craftbeer78.ru/beer-tastes.

Обходит все 132 страницы вкусов (/beer-taste/<slug>), для каждого пива
на странице добавляет название вкуса в поле taste (дополнительно к
существующим значениям, через запятую).

Поля aroma/taste сейчас заполнены слабо (17%/33%) — этот скрипт
дотягивает их через каталог вкусов сайта, который мы не использовали.

CLI:
    python fetch_tastes.py            # полный обход
    python fetch_tastes.py --dry-run  # только отчёт
    python fetch_tastes.py --limit 10 # только первые 10 вкусов (тест)
"""

from __future__ import annotations

import argparse
import logging
import sqlite3
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
from bs4 import BeautifulSoup

APP_ROOT = Path(__file__).resolve().parent
DB_PATH = APP_ROOT / "beer_database.db"
TASTES_URL = "https://craftbeer78.ru/beer-tastes"

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("fetch_tastes")

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0",
    "Accept-Language": "ru-RU,ru;q=0.8",
})


def fetch_all_tastes() -> list[dict]:
    """Парсит /beer-tastes, возвращает список вкусов [{name, slug, url}]."""
    r = SESSION.get(TASTES_URL, timeout=20)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")
    links = soup.select('a[href*="/beer-taste/"]')
    result = []
    seen = set()
    for a in links:
        href = a.get("href", "")
        text = a.get_text(strip=True)
        slug = href.strip("/").split("/")[-1]
        if slug in seen or not text or text == "Вкусы":
            continue
        seen.add(slug)
        result.append({
            "name": text,
            "slug": slug,
            "url": f"https://craftbeer78.ru{href}" if href.startswith("/") else href,
        })
    return result


def fetch_beers_for_taste(taste: dict) -> list[str]:
    """Возвращает список URL пив для данного вкуса."""
    try:
        r = SESSION.get(taste["url"], timeout=20)
        if r.status_code != 200:
            return []
        soup = BeautifulSoup(r.text, "html.parser")
        beer_links = soup.select('a[href*="/beer/"]')
        urls = set()
        for a in beer_links:
            href = a.get("href", "")
            if "/beer/" in href and "/beer-taste/" not in href and "/beer-style/" not in href:
                if href.startswith("/"):
                    href = "https://craftbeer78.ru" + href
                urls.add(href)
        return list(urls)
    except Exception as e:
        log.debug("Ошибка для вкуса %s: %s", taste["name"], e)
        return []


def update_taste_in_db(conn: sqlite3.Connection, beer_url: str, taste_name: str) -> int:
    """Добавляет вкус в поле taste для пива с данным original_url.

    Если taste уже заполнен — дополняет через запятую (без дубликатов).
    Возвращает кол-во обновлённых строк.
    """
    cur = conn.execute("SELECT taste FROM products_full WHERE original_url = ?", (beer_url,))
    row = cur.fetchone()
    if not row:
        return 0
    existing = row[0] or ""
    # проверяем, нет ли уже этого вкуса
    existing_lower = existing.lower()
    if taste_name.lower() in existing_lower:
        return 0
    # дополняем
    new_taste = f"{existing}, {taste_name}" if existing else taste_name
    conn.execute(
        "UPDATE products_full SET taste = ? WHERE original_url = ?",
        (new_taste[:500], beer_url),
    )
    return 1


def main() -> int:
    ap = argparse.ArgumentParser(description="Сбор тегов вкусов")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()

    log.info("Парсинг каталога вкусов %s ...", TASTES_URL)
    tastes = fetch_all_tastes()
    log.info("Найдено вкусов: %d", len(tastes))

    if args.limit:
        tastes = tastes[:args.limit]
        log.info("Ограничение: обрабатываем первые %d", len(tastes))

    if args.dry_run:
        for t in tastes[:10]:
            print(f"  {t['name']:25s} → {t['url']}")
        print(f"  ...всего {len(tastes)}")
        return 0

    # Собираем маппинг beer_url → [taste_names]
    beer_tastes: dict[str, list[str]] = {}
    processed = 0

    def worker(taste):
        urls = fetch_beers_for_taste(taste)
        return taste["name"], urls

    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(worker, t): t for t in tastes}
        for fut in as_completed(futures):
            taste_name, urls = fut.result()
            processed += 1
            for url in urls:
                beer_tastes.setdefault(url, []).append(taste_name)
            if processed % 20 == 0:
                log.info(
                    "Обработано вкусов: %d/%d, пив с вкусами: %d",
                    processed, len(tastes), len(beer_tastes),
                )

    log.info("Всего пив с вкусами: %d", len(beer_tastes))

    # Записываем в БД
    conn = sqlite3.connect(DB_PATH)
    updated = 0
    for beer_url, taste_list in beer_tastes.items():
        for taste_name in taste_list:
            updated += update_taste_in_db(conn, beer_url, taste_name)
    conn.commit()
    conn.close()

    log.info("Обновлено записей: %d", updated)

    # Статистика
    conn = sqlite3.connect(DB_PATH)
    cur = conn.execute("SELECT COUNT(*) FROM products_full WHERE taste IS NOT NULL AND taste != ''")
    n = cur.fetchone()[0]
    log.info("Итого пив с полем taste: %d/7733 (%.1f%%)", n, 100 * n / 7733)
    conn.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())

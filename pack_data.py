#!/usr/bin/env python3
"""🍺 Beerpedia — упаковка данных в beerpedia_data.zip.

Работает везде, где есть Python (Windows, Linux, Android/Termux).
Не требует установки zip в системе.

Упаковывает:
  - beer_database.db
  - static/images/   (картинки пива)
  - static/breweries/ (логотипы пивоварен)

Запуск:
  python pack_data.py
"""
from __future__ import annotations

import os
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ZIP_NAME = "beerpedia_data.zip"

# Что упаковываем (относительно корня проекта)
TARGETS = [
    "beer_database.db",
    "static/images",
    "static/breweries",
]

# Что пропускаем
EXCLUDE_SUFFIXES = {".log", ".tmp", ".bak"}


def human_size(num_bytes: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if num_bytes < 1024:
            return f"{num_bytes:.0f} {unit}"
        num_bytes /= 1024
    return f"{num_bytes:.1f} TB"


def collect_files() -> list[Path]:
    """Собирает список файлов для архивации."""
    files: list[Path] = []
    for target in TARGETS:
        path = ROOT / target
        if not path.exists():
            print(f"  ⚠️  Пропускаю (нет): {target}")
            continue
        if path.is_file():
            files.append(path)
        else:
            for p in path.rglob("*"):
                if p.is_file() and p.suffix.lower() not in EXCLUDE_SUFFIXES:
                    files.append(p)
    return files


def main() -> int:
    print("📦 Beerpedia — упаковка данных")
    print("=" * 40)

    # Проверка базы
    db_path = ROOT / "beer_database.db"
    if not db_path.exists():
        print(f"❌ Ошибка: {db_path} не найден!")
        print("   Сначала запустите полный парсинг.")
        return 1

    db_size = db_path.stat().st_size
    print(f"✓ База данных: {human_size(db_size)}")

    # Удаляем старый архив
    zip_path = ROOT / ZIP_NAME
    if zip_path.exists():
        zip_path.unlink()

    # Собираем файлы
    print("\nСобираю файлы...")
    files = collect_files()
    if not files:
        print("❌ Нет файлов для упаковки!")
        return 1

    total_size = sum(f.stat().st_size for f in files)
    print(f"✓ Найдено файлов: {len(files)} ({human_size(total_size)})")

    # Упаковываем
    print(f"\nУпаковываю в {ZIP_NAME}...")
    count = 0
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for i, f in enumerate(files, 1):
            # Относительный путь (для распаковки в нужную структуру)
            arcname = f.relative_to(ROOT).as_posix()
            zf.write(f, arcname)
            count = i
            if i % 1000 == 0:
                print(f"   ...{i} файлов")
                sys.stdout.flush()

    final_size = zip_path.stat().st_size
    ratio = (1 - final_size / total_size) * 100 if total_size else 0

    print()
    print("=" * 40)
    print("🎉 ГОТОВО!")
    print("=" * 40)
    print(f"📦 Архив: {ZIP_NAME}")
    print(f"   Размер:        {human_size(final_size)}")
    print(f"   Исходный объём: {human_size(total_size)}")
    print(f"   Сжатие:        {ratio:.0f}%")
    print(f"   Файлов:        {count}")
    print()
    print("📱 Для переноса на Android используйте fetch_data.sh")
    print("   или перенесите архив вручную (см. README_MOBILE.md)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

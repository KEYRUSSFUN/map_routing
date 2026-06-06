"""
Перенос данных из SQLite (kurs.db) в PostgreSQL.

Использование:
    python scripts/migrate_sqlite_to_postgres.py
    python scripts/migrate_sqlite_to_postgres.py --sqlite-path kurs.db
"""
from __future__ import annotations

import argparse
import os
import sys

from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

load_dotenv(os.path.join(ROOT, '.env'))

DEFAULT_SQLITE_CANDIDATES = [
    os.path.join(ROOT, 'kurs.db'),
    os.path.join(ROOT, '..', 'kurs.db'),
    os.path.join(ROOT, '..', '..', 'kurs.db'),
]


def _resolve_sqlite_path(path: str | None) -> str:
    """Находит SQLite-файл: явный путь, cwd, корень проекта или типичные места."""
    if path:
        candidates = [path]
        if not os.path.isabs(path):
            candidates.extend([
                os.path.join(os.getcwd(), path),
                os.path.join(ROOT, path),
            ])
    else:
        candidates = list(DEFAULT_SQLITE_CANDIDATES)

    seen = set()
    for candidate in candidates:
        resolved = os.path.abspath(candidate)
        if resolved in seen:
            continue
        seen.add(resolved)
        if os.path.isfile(resolved):
            return resolved

    if path:
        searched = '\n  '.join(sorted(seen))
        raise FileNotFoundError(
            f'SQLite файл не найден: {path}\n'
            f'Проверены пути:\n  {searched}\n'
            'Укажите полный путь: --sqlite-path "C:\\path\\to\\kurs.db"'
        )

    searched = '\n  '.join(os.path.abspath(c) for c in DEFAULT_SQLITE_CANDIDATES)
    raise FileNotFoundError(
        'SQLite файл kurs.db не найден.\n'
        f'Проверены пути:\n  {searched}\n'
        'Если база в другом месте, укажите: --sqlite-path "C:\\path\\to\\kurs.db"'
    )

TABLES_IN_ORDER = [
    'users',
    'user_info',
    'friendships',
    'group_chat',
    'user_group_chat',
    'group_message',
    'user_statistic',
    'routes',
]


def _normalize_database_url(url: str) -> str:
    if url.startswith('postgres://'):
        return url.replace('postgres://', 'postgresql://', 1)
    return url


def _reset_sequence(engine, table: str, column: str) -> None:
    with engine.begin() as conn:
        sequence = conn.execute(
            text('SELECT pg_get_serial_sequence(:table, :column)'),
            {'table': table, 'column': column},
        ).scalar()
        if not sequence:
            return
        conn.execute(
            text(
                f"""
                SELECT setval(
                    :sequence,
                    COALESCE((SELECT MAX("{column}") FROM "{table}"), 1),
                    (SELECT MAX("{column}") IS NOT NULL FROM "{table}")
                )
                """
            ),
            {'sequence': sequence},
        )


def migrate(sqlite_path: str, postgres_url: str) -> None:
    sqlite_path = _resolve_sqlite_path(sqlite_path)
    print(f'Источник SQLite: {sqlite_path}')

    sqlite_url = f'sqlite:///{sqlite_path}'
    postgres_url = _normalize_database_url(postgres_url)

    source_engine = create_engine(sqlite_url)
    target_engine = create_engine(postgres_url)

    existing = set(inspect(target_engine).get_table_names())
    missing = [table for table in TABLES_IN_ORDER if table not in existing]
    if missing:
        raise RuntimeError(
            'В PostgreSQL нет таблиц: '
            f'{", ".join(missing)}. Сначала выполните: flask db upgrade'
        )

    with target_engine.begin() as target_conn:
        tables_list = ', '.join(f'"{table}"' for table in TABLES_IN_ORDER)
        target_conn.execute(text(f'TRUNCATE TABLE {tables_list} RESTART IDENTITY CASCADE'))

    with source_engine.connect() as source_conn:
        for table in TABLES_IN_ORDER:
            rows = source_conn.execute(text(f'SELECT * FROM "{table}"')).mappings().all()
            if not rows:
                print(f'{table}: 0 строк')
                continue

            columns = rows[0].keys()
            placeholders = ', '.join(f':{col}' for col in columns)
            column_list = ', '.join(f'"{col}"' for col in columns)
            insert_sql = text(
                f'INSERT INTO "{table}" ({column_list}) VALUES ({placeholders})'
            )

            with target_engine.begin() as target_conn:
                for row in rows:
                    target_conn.execute(insert_sql, dict(row))

            print(f'{table}: перенесено {len(rows)} строк')

    _reset_sequence(target_engine, 'friendships', 'id')
    print('Миграция данных завершена.')


def main() -> None:
    parser = argparse.ArgumentParser(description='Перенос данных SQLite -> PostgreSQL')
    parser.add_argument(
        '--sqlite-path',
        default=None,
        help='Путь к файлу SQLite (по умолчанию ищется kurs.db в корне проекта)',
    )
    parser.add_argument(
        '--database-url',
        default=os.environ.get('DATABASE_URL'),
        help='URL PostgreSQL (по умолчанию берётся из DATABASE_URL)',
    )
    args = parser.parse_args()

    if not args.database_url:
        raise SystemExit('Укажите DATABASE_URL в .env или через --database-url')

    migrate(args.sqlite_path, args.database_url)


if __name__ == '__main__':
    main()

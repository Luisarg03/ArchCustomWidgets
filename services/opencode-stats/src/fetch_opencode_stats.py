#!/usr/bin/env python3
"""Query OpenCode SQLite database and output usage statistics as JSON.

Usage:
    fetch_opencode_stats.py [database_path]

Default database path: ~/.local/share/opencode/opencode.db
"""

import json
import sqlite3
import sys
from pathlib import Path

DEFAULT_DB = Path.home() / ".local" / "share" / "opencode" / "opencode.db"
THIRTY_DAYS_MS = "(strftime('%s', 'now', '-30 days') || '000')"


def default_response():
    return {
        "monthly_cost": None,
        "input_tokens": None,
        "output_tokens": None,
        "top_models": [],
        "error": None,
    }


def fetch_stats(db_path: str) -> dict:
    result = default_response()

    db = Path(db_path).expanduser().resolve()
    if not db.exists():
        result["error"] = f"Database not found: {db}"
        return result

    try:
        conn = sqlite3.connect(
            f"file:{db}?mode=ro",
            uri=True,
            timeout=5,
        )
        conn.row_factory = sqlite3.Row
    except sqlite3.Error as e:
        result["error"] = f"Cannot open database (locked/permission): {e}"
        return result

    try:
        cur = conn.cursor()

        cur.execute(
            f"SELECT ROUND(SUM(cost), 6) FROM session "
            f"WHERE time_created >= {THIRTY_DAYS_MS}"
        )
        row = cur.fetchone()
        total_cost = row[0]
        result["monthly_cost"] = round(total_cost, 2) if total_cost else 0.0

        cur.execute(
            f"SELECT SUM(tokens_input), SUM(tokens_output) FROM session "
            f"WHERE time_created >= {THIRTY_DAYS_MS}"
        )
        row = cur.fetchone()
        result["input_tokens"] = row[0] if row[0] else 0
        result["output_tokens"] = row[1] if row[1] else 0

        cur.execute(
            f"""
            SELECT
                json_extract(model, '$.id') AS model_name,
                json_extract(model, '$.providerID') AS provider,
                SUM(tokens_input + tokens_output) AS total_tokens,
                ROUND(SUM(cost), 6) AS total_cost,
                SUM(tokens_input) AS input_tokens,
                SUM(tokens_output) AS output_tokens
            FROM session
            WHERE time_created >= {THIRTY_DAYS_MS}
                AND model_name IS NOT NULL
            GROUP BY model_name, provider
            HAVING total_tokens > 0
            ORDER BY total_cost DESC
            """
        )
        result["top_models"] = [
            {
                "name": r["model_name"],
                "provider": r["provider"],
                "total_tokens": r["total_tokens"],
                "cost": round(r["total_cost"], 2) if r["total_cost"] else 0.0,
                "input_tokens": r["input_tokens"] if r["input_tokens"] else 0,
                "output_tokens": r["output_tokens"] if r["output_tokens"] else 0,
            }
            for r in cur.fetchall()
        ]

    except sqlite3.Error as e:
        result["error"] = f"Query failed: {e}"
        return result
    finally:
        conn.close()

    return result


def main():
    db_path = sys.argv[1] if len(sys.argv) > 1 else str(DEFAULT_DB)
    stats = fetch_stats(db_path)
    print(json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()

"""Run schema.sql + every tagged answer in solutions.sql in an in-memory SQLite DB.
Usage:  python run_solutions.py"""
import re
import sqlite3
from pathlib import Path

here = Path(__file__).parent
con = sqlite3.connect(":memory:")
con.executescript((here / "schema.sql").read_text())
parts = re.split(r"^-- @(\w+) ?(.*)$", (here / "solutions.sql").read_text(), flags=re.M)
for i in range(1, len(parts), 3):
    tag, title, sql = parts[i], parts[i + 1], parts[i + 2].strip()
    cur = con.execute(sql)
    cols = [c[0] for c in cur.description]
    rows = cur.fetchall()
    print(f"\n### {tag}: {title}")
    print("| " + " | ".join(cols) + " |")
    print("|" + "---|" * len(cols))
    for r in rows:
        print("| " + " | ".join("" if v is None else str(v) for v in r) + " |")

#!/usr/bin/env python3
"""Fetch Figma node hierarchies (batched) into .figma_cache/screens/<name>.json.

Usage:
  python tools/fetch_nodes.py <out_name> <node_id_csv> [--depth 6]
"""
from __future__ import annotations
import argparse, json, sys, time, urllib.request, urllib.parse, os
from pathlib import Path

FILE_KEY = "w8KXSwOOskaCLTdZU7ERa9"
TOKEN = os.environ.get("FIGMA_TOKEN", "")
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / ".figma_cache" / "screens"

def fetch(ids: str, depth: int) -> dict:
    url = f"https://api.figma.com/v1/files/{FILE_KEY}/nodes?ids={urllib.parse.quote(ids, safe=',')}&depth={depth}"
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"X-Figma-Token": TOKEN})
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 429:
                print(f"429, sleeping 60s (attempt {attempt+1})", file=sys.stderr)
                time.sleep(60)
                continue
            raise
    raise RuntimeError("3x 429")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("ids")
    ap.add_argument("--depth", type=int, default=6)
    args = ap.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    out = CACHE / f"{args.name}.json"
    if out.exists() and out.stat().st_size > 100:
        print(f"cached: {out}")
        return 0
    data = fetch(args.ids, args.depth)
    out.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    print(f"saved: {out} ({out.stat().st_size} bytes)")
    time.sleep(2.5)
    return 0

if __name__ == "__main__":
    sys.exit(main())

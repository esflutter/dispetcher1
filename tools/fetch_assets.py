#!/usr/bin/env python3
"""
Скачивание ассетов из Figma в WebP/SVG для проекта «Диспетчер №1».

Использование:
    python tools/fetch_assets.py <node_id> <out_subdir> --name <basename> [--scale 2] [--svg]

Примеры:
    # PNG из Figma -> WebP в assets/images/onboarding/splash_logo.webp
    python tools/fetch_assets.py 0:2230 onboarding --name splash_logo

    # SVG-иконка -> assets/icons/nav/catalog.svg
    python tools/fetch_assets.py 6:2691 nav --name catalog --svg --icon

Возвращает (stdout) относительный путь к созданному файлу — его подставлять в Image.asset/SvgPicture.asset.
"""
from __future__ import annotations

import argparse
import io
import os
import sys
import time
from pathlib import Path

import urllib.request
import urllib.parse
import json

FILE_KEY = "w8KXSwOOskaCLTdZU7ERa9"
TOKEN = os.environ.get("FIGMA_TOKEN", "")
PROJECT_ROOT = Path(__file__).resolve().parent.parent

API_BASE = "https://api.figma.com/v1"


def figma_get(path: str) -> dict:
    req = urllib.request.Request(
        f"{API_BASE}{path}",
        headers={"X-Figma-Token": TOKEN},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_image_url(node_id: str, fmt: str, scale: int) -> str:
    ids = urllib.parse.quote(node_id, safe="")
    data = figma_get(f"/images/{FILE_KEY}?ids={ids}&format={fmt}&scale={scale}")
    if data.get("err"):
        raise RuntimeError(f"Figma error: {data['err']}")
    images = data.get("images", {})
    url = images.get(node_id)
    if not url:
        raise RuntimeError(f"No image returned for node {node_id}: {data}")
    return url


def download(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as resp:
        return resp.read()


def to_webp(png_bytes: bytes, dest: Path, quality: int = 90) -> None:
    from PIL import Image  # type: ignore

    dest.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(io.BytesIO(png_bytes)) as im:
        if im.mode not in ("RGB", "RGBA"):
            im = im.convert("RGBA")
        im.save(dest, format="WEBP", quality=quality, method=6)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("node_id", help="Figma node id, например 2:4130")
    parser.add_argument(
        "out_subdir",
        help="подкаталог внутри assets/images или assets/icons",
    )
    parser.add_argument("--name", required=True, help="базовое имя файла без расширения")
    parser.add_argument("--scale", type=int, default=2, help="масштаб (1|2|3|4)")
    parser.add_argument("--svg", action="store_true", help="скачать как svg")
    parser.add_argument(
        "--icon",
        action="store_true",
        help="класть в assets/icons/<sub> вместо assets/images/<sub>",
    )
    parser.add_argument(
        "--quality",
        type=int,
        default=90,
        help="WebP quality (0..100)",
    )
    args = parser.parse_args()

    base = "assets/icons" if args.icon else "assets/images"
    out_dir = PROJECT_ROOT / base / args.out_subdir
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.svg:
        url = get_image_url(args.node_id, "svg", args.scale)
        data = download(url)
        dest = out_dir / f"{args.name}.svg"
        dest.write_bytes(data)
    else:
        url = get_image_url(args.node_id, "png", args.scale)
        data = download(url)
        dest = out_dir / f"{args.name}.webp"
        to_webp(data, dest, quality=args.quality)

    rel = dest.relative_to(PROJECT_ROOT).as_posix()
    print(rel)
    return 0


if __name__ == "__main__":
    sys.exit(main())

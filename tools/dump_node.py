#!/usr/bin/env python3
"""Dump useful info (texts, structure, colors) from cached figma node json."""
import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def fmt_color(fills):
    if not fills: return ''
    f = fills[0]
    if f.get('type') != 'SOLID': return f.get('type','')
    c = f.get('color', {})
    r,g,b = int(c.get('r',0)*255), int(c.get('g',0)*255), int(c.get('b',0)*255)
    return f"#{r:02X}{g:02X}{b:02X}"

def walk(n, depth=0, max_depth=8):
    if depth > max_depth: return
    name = n.get('name','')
    typ = n.get('type','')
    bb = n.get('absoluteBoundingBox') or {}
    size = f"{int(bb.get('width',0))}x{int(bb.get('height',0))}" if bb else ''
    extra = ''
    if typ == 'TEXT':
        extra = ' TEXT=' + repr(n.get('characters',''))
        st = n.get('style',{})
        extra += f" sz={st.get('fontSize')} w={st.get('fontWeight')}"
    fills = n.get('fills') or []
    color = fmt_color(fills) if fills else ''
    print('  '*depth + f"[{typ}] {name} {size} {color}{extra}")
    for c in n.get('children') or []:
        walk(c, depth+1, max_depth)

def main():
    path = sys.argv[1]
    nid = sys.argv[2] if len(sys.argv) > 2 else None
    md = int(sys.argv[3]) if len(sys.argv) > 3 else 6
    d = json.load(open(path, encoding='utf-8'))
    nodes = d.get('nodes', {})
    for k,v in nodes.items():
        if nid and k != nid: continue
        print(f"=== {k} ===")
        walk(v['document'], 0, md)

if __name__ == "__main__":
    main()

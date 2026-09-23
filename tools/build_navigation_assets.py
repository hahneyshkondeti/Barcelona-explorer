#!/usr/bin/env python3
"""Build offline address lookup and a lightweight map from the shipped city data."""
import json
from pathlib import Path
import sys


def build(city):
    city = Path(city)
    manifest = json.loads((city / 'manifest.json').read_text())
    streets = {}
    for key, resource in manifest['tiles'].items():
        tile = json.loads((city / 'tiles' / Path(resource).name).read_text())
        for record in tile['addresses']:
            if record['street']:
                streets.setdefault(record['street'], set()).add(key)
    (city / 'address_index.json').write_text(json.dumps({name: sorted(keys) for name, keys in sorted(streets.items())}, ensure_ascii=False, separators=(',', ':')))
    lo, hi = manifest['bounds']
    width, height = hi[0]-lo[0], hi[1]-lo[1]
    # Original vector rendering of OSM road coordinates, no proprietary map tiles.
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="2048" viewBox="{lo[0]} {lo[1]} {width} {height}" preserveAspectRatio="none">',f'<rect x="{lo[0]}" y="{lo[1]}" width="{width}" height="{height}" fill="#233d40"/>','<g stroke="#91a49a" stroke-width="9" fill="none">']
    for road in manifest['roads']:
        a,b = road['a'],road['b']
        parts.append(f'<path d="M{a[0]} {a[1]}L{b[0]} {b[1]}"/>')
    parts.append('</g></svg>')
    (city / 'overview.svg').write_text(''.join(parts))
    print(f'Navigation assets: {len(streets)} named address streets')


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv)>1 else 'data/city')

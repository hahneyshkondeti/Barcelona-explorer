#!/usr/bin/env python3
"""Validate provenance, source identity, tile coverage and unchanged survey positions."""
import gzip,json,math,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
d=json.loads((ROOT/'data/lighting/street_lights.json').read_text())
with gzip.open(ROOT/'data/source/cartobcn-lamps.json.gz','rt') as f: source=json.load(f)
records={r['id']:r for r in source['records']}
assert len(records)==d['metadata']['source_count']
seen=set()
for key,items in d['cells'].items():
 for r in items:
  assert r['id'] not in seen;seen.add(r['id'])
  assert r['id'] in records and records[r['id']]['OCULT']=='No'
  x,z=r['point'];assert math.isfinite(x) and math.isfinite(z)
  assert key==f'{math.floor(x/192)}:{math.floor(z/192)}'
assert len(seen)==d['metadata']['render_count']>130000
# Independent checkpoint transformed from EPSG:25831 with PROJ during import review.
r=next(r for items in d['cells'].values() for r in items if r['id']==3602)
assert all(abs(a-b)<0.00001 for a,b in zip(records[3602]['utm_25831'],[432722.483,4581985.852]))
assert all(abs(a-b)<0.001 for a,b in zip(r['point'],[1747.3903,1893.7078]))
assert d['metadata']['license']=='CC BY 3.0 ES'
print(f'PASS: {len(seen)} unique official lamps, tile coverage, provenance and source checkpoint')

#!/usr/bin/env python3
"""Extract CartoBCN ENE_06_PT survey points; fixture shape is NOT supplied."""
import argparse, datetime, gzip, hashlib, json, math, pathlib, sqlite3, struct
from pyproj import Transformer
ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = 'https://w20.bcn.cat/CartoBCN/getFile.ashx?prod=144.BARCELONA.42'

def point(blob):
    assert blob[:2] == b'GP'
    envelope = (blob[3] >> 1) & 7
    offset = 8 + {0:0, 1:32, 2:48, 3:48, 4:64}[envelope]
    endian = '<' if blob[offset] else '>'
    kind, count = struct.unpack_from(endian+'II', blob, offset+1)
    if kind != 4 or count != 1: raise ValueError('Expected one surveyed point per feature')
    offset += 9
    endian = '<' if blob[offset] else '>'
    if struct.unpack_from(endian+'I', blob, offset+1)[0] != 1: raise ValueError('Expected 2D point')
    return struct.unpack_from(endian+'dd', blob, offset+5)

def build(source, output, archive, source_updated):
    datetime.date.fromisoformat(source_updated)
    con = sqlite3.connect(source); con.row_factory = sqlite3.Row
    assert con.execute('select srs_id from gpkg_contents').fetchone()[0] == 25831
    transform = Transformer.from_crs(25831,4326,always_xy=True)
    manifest = json.loads((ROOT/'data/city/manifest.json').read_text())
    lon0,lat0=manifest['origin_lonlat']; west,south,east,north=manifest['bbox_lonlat']
    records=[]; cells={}; skipped=0; seen=set()
    for row in con.execute("select * from TOPO1000_PUNTS where NIVELL='ENE_06_PT' order by id"):
        x,y=point(row['geometria']); lon,lat=transform.transform(x,y)
        raw={k:row[k] for k in row.keys() if k!='geometria'}; raw['utm_25831']=[x,y]; records.append(raw)
        if row['OCULT']!='No' or not (west<=lon<=east and south<=lat<=north): skipped+=1; continue
        if (x,y) in seen: skipped+=1; continue
        seen.add((x,y))
        px=math.radians(lon-lon0)*6378137*math.cos(math.radians(lat0)); pz=-math.radians(lat-lat0)*6378137
        key=f'{math.floor(px/192)}:{math.floor(pz/192)}'
        cells.setdefault(key,[]).append({'id':row['id'],'point':[round(px,4),round(pz,4)]})
    if len(seen)<100000: raise ValueError('Unexpected survey coverage; leave installed data unchanged')
    metadata={'source':URL,'publisher':'Ajuntament de Barcelona — CartoBCN','layer':'ENE_06_PT (Fanal)', 'license':'CC BY 3.0 ES','license_url':'https://creativecommons.org/licenses/by/3.0/es/','terms_url':'https://w20.bcn.cat/CartoBCN/getFile.ashx?f=82071224678486&t=bdd','source_updated':source_updated,'retrieved_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'gpkg_sha256':hashlib.file_digest(open(source,'rb'),'sha256').hexdigest(),'source_count':len(records),'render_count':len(seen),'excluded_hidden_outside_or_duplicate':skipped,'limitations':'Survey positions, not live inventory. Heights, shapes, colors and lighting photometry are illustrative; no fixture models supplied. COTA is retained in source only, not interpreted as pole height. Terrain supplies base elevation. No inferred road offsets.'}
    output.parent.mkdir(parents=True,exist_ok=True); archive.parent.mkdir(parents=True,exist_ok=True)
    with gzip.open(archive,'wt',encoding='utf8') as f: json.dump({'metadata':metadata,'records':records},f,ensure_ascii=False,separators=(',',':'))
    output.write_text(json.dumps({'metadata':metadata,'cells':cells},ensure_ascii=False,separators=(',',':')))
    print(json.dumps(metadata,indent=2))
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('gpkg',type=pathlib.Path);p.add_argument('--output',type=pathlib.Path,default=ROOT/'data/lighting/street_lights.json');p.add_argument('--source-output',type=pathlib.Path,default=ROOT/'data/source/cartobcn-lamps.json.gz');p.add_argument('--source-updated',required=True,help='Publication date from the official feed (YYYY-MM-DD)');a=p.parse_args();build(a.gpkg,a.output,a.source_output,a.source_updated)

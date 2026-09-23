#!/usr/bin/env python3
"""Build an offline street-tree layer from Open Data BCN (CC BY 4.0).
Keep municipal trunk coordinates exactly; never snap trees to estimated roads.
OSM trees are retained only inside mapped parks, away from municipal records.
"""
import argparse, csv, datetime, gzip, hashlib, io, json, math, pathlib, subprocess, tempfile
import xml.etree.ElementTree as ET
from import_map import ROOT, inside, project, contains
URL='https://opendata-ajuntament.barcelona.cat/data/dataset/27b3f8a7-e536-4eea-b025-ce094817b2bd/resource/23124fd5-521f-40f8-85b8-efb1e71c2ec8/download'
PAGE='https://opendata-ajuntament.barcelona.cat/data/en/dataset/arbrat-viari'
SOURCE=ROOT/'data/source/street_trees.csv.gz'
OUTPUT=ROOT/'data/trees.json'

def bounded_csv(raw):
    reader=csv.DictReader(io.StringIO(raw.decode('utf-8-sig')))
    required={'codi','longitud','latitud','cat_nom_cientific','tipus_element','adreca','data_plantacio'}
    if not required.issubset(reader.fieldnames or []): raise ValueError('Unexpected municipal CSV columns')
    rows=[]; ids=set()
    for row in reader:
        lon,lat=float(row['longitud']),float(row['latitud'])
        if not math.isfinite(lon) or not math.isfinite(lat): raise ValueError('Non-finite tree coordinate')
        if not inside(lon,lat): continue
        if not row['codi'] or row['codi'] in ids: raise ValueError('Missing/duplicate municipal tree ID')
        ids.add(row['codi']); rows.append(row)
    if len(rows)<100: raise ValueError('Incomplete tree coverage; keeping installed inventory')
    out=io.StringIO(newline=''); writer=csv.DictWriter(out,fieldnames=reader.fieldnames)
    writer.writeheader();writer.writerows(sorted(rows,key=lambda r:r['codi']))
    return out.getvalue().encode('utf-8')

def build(raw, retrieved_at, district=None, osm_raw=None):
    bounded=bounded_csv(raw)
    records=[]
    for row in csv.DictReader(io.StringIO(bounded.decode())):
        ll=[float(row['longitud']),float(row['latitud'])]
        records.append({'id':'bcn/'+row['codi'],'source':'Open Data BCN','point':project(*ll),'lonlat':ll,
            'species':row['cat_nom_cientific'],'address':row['adreca'],'planted_at':row['data_plantacio'],
            'form':'palm' if 'PALMERA' in row['tipus_element'] else 'broadleaf',
            'appearance':'estimated; no surveyed height or crown geometry in this layer'})
    municipal=records[:]
    district=district or json.loads((ROOT/'data/eixample.json').read_text())
    if osm_raw is None: osm_raw=gzip.decompress((ROOT/'data/source/eixample.osm.gz').read_bytes())
    omitted_duplicates=0
    for node in ET.fromstring(osm_raw).findall('node'):
        tags={t.get('k'):t.get('v') for t in node.findall('tag')}
        if tags.get('natural')!='tree': continue
        ll=[float(node.get('lon')),float(node.get('lat'))]; p=project(*ll)
        if not inside(*ll) or not any(contains(p,park['ring']) for park in district['parks']): continue
        if any(math.dist(p,t['point'])<3 for t in municipal):
            omitted_duplicates+=1;continue
        records.append({'id':'osm/node/'+node.get('id'),'source':'OpenStreetMap','point':p,'lonlat':ll,
            'species':tags.get('species',''),'timestamp':node.get('timestamp','unknown'),'form':'broadleaf',
            'appearance':'estimated; park fallback, not a municipal survey'})
    return {'metadata':{'source_url':PAGE,'download_url':URL,'retrieved_at':retrieved_at,
        'attribution':'Ajuntament de Barcelona / Open Data BCN — CC BY 4.0; park fallback © OpenStreetMap contributors — ODbL 1.0',
        'license_url':'https://creativecommons.org/licenses/by/4.0/',
        'bounded_source_sha256':hashlib.sha256(bounded).hexdigest(),
        'municipal_street_trees':len(municipal),'osm_park_trees':len(records)-len(municipal),
        'suppressed_nearby_osm_park_points':omitted_duplicates,
        'accuracy':'Recorded trunk coordinates; not independently field-verified. Snapshot date is not survey date. Crown, height and seasonal appearance remain estimates.'},'trees':records}

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--download',action='store_true',help='Fetch and replace inventory after validation')
    ap.add_argument('--source',type=pathlib.Path,default=SOURCE)
    args=ap.parse_args()
    old=json.loads(OUTPUT.read_text()) if OUTPUT.exists() else None
    if args.download:
        with tempfile.TemporaryDirectory() as tmp:
            path=pathlib.Path(tmp)/'trees.csv'
            subprocess.run(['curl','-L','--fail','--max-time','180',URL,'-o',str(path)],check=True)
            raw=path.read_bytes()
        retrieved=datetime.datetime.now(datetime.timezone.utc).isoformat()
    else:
        raw=gzip.decompress(args.source.read_bytes()) if args.source.suffix=='.gz' else args.source.read_bytes()
        retrieved=old['metadata']['retrieved_at'] if old else datetime.datetime.now(datetime.timezone.utc).isoformat()
    bounded=bounded_csv(raw); result=build(bounded,retrieved)
    if old:
        ratio=result['metadata']['municipal_street_trees']/old['metadata']['municipal_street_trees']
        if not 0.7<=ratio<=1.3: raise ValueError('Tree coverage changed over 30%; review source before replacement')
    source_temp=SOURCE.with_suffix('.tmp');source_temp.write_bytes(gzip.compress(bounded,mtime=0))
    output_temp=OUTPUT.with_suffix('.tmp');output_temp.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
    source_temp.replace(SOURCE); output_temp.replace(OUTPUT)
    print(json.dumps(result['metadata'],indent=2,ensure_ascii=False))

if __name__=='__main__': main()

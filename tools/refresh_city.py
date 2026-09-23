#!/usr/bin/env python3
"""Weekly developer refresh: stage, validate, then promote a full offline city."""
import argparse,datetime,hashlib,json,pathlib,shutil,subprocess,sys,tempfile
from import_map import ROOT
CITY=ROOT/'data/city';STAGE=ROOT/'data/.refresh/city'
BULK='https://download.bbbike.org/osm/bbbike/Barcelona/Barcelona.osm.gz'
BOUNDARY='https://api.openstreetmap.org/api/0.6/relation/347950/full'
TREES='https://opendata-ajuntament.barcelona.cat/data/dataset/27b3f8a7-e536-4eea-b025-ce094817b2bd/resource/23124fd5-521f-40f8-85b8-efb1e71c2ec8/download'
def fetch(url,path):
    subprocess.run(['curl','-L','--fail','--max-time','600','--max-filesize','300000000',url,'-o',str(path)],check=True)
def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def fingerprints(root):return {str(p.relative_to(root)):digest(p) for p in sorted(root.rglob('*')) if p.is_file() and p.name!='checksums.json'}
def flags(old,new):
    errors=[]
    for key in ('buildings','roads','places'):
        before=old['metadata']['counts'][key];after=new['metadata']['counts'][key]
        if not .75*before<=after<=1.5*before:errors.append(f'{key}: unexpected change {before} -> {after}')
    if old['bbox_lonlat']!=new['bbox_lonlat']:errors.append('Municipal envelope changed; review boundary')
    if new.get('district_id')!='barcelona_city_v1':errors.append('Wrong city ID')
    return errors

def main():
    ap=argparse.ArgumentParser(description=__doc__);g=ap.add_mutually_exclusive_group(required=True)
    for name in ('check','download','apply'):g.add_argument('--'+name,action='store_true')
    args=ap.parse_args();old=json.loads((CITY/'manifest.json').read_text())
    if args.check:
        fetched=datetime.datetime.fromisoformat(old['metadata']['retrieved_at'])
        age=(datetime.datetime.now(datetime.timezone.utc)-fetched).days
        print(json.dumps({'retrieved_at':fetched.isoformat(),'age_days':age,'refresh_due':age>=7,'counts':old['metadata']['counts']},indent=2));return
    if args.download:
        STAGE.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=STAGE.parent) as temp:
            root=pathlib.Path(temp);src=root/'source';src.mkdir()
            fetch(BULK,root/'bulk.osm.gz');fetch(BOUNDARY,src/'barcelona-boundary.osm');fetch(TREES,root/'trees.csv')
            now=datetime.datetime.now(datetime.timezone.utc).isoformat()
            subprocess.run([sys.executable,str(ROOT/'tools/build_city.py'),'--bulk',str(root/'bulk.osm.gz'),'--source',str(src/'barcelona.osm.gz'),'--boundary',str(src/'barcelona-boundary.osm'),'--trees',str(root/'trees.csv'),'--tree-source-output',str(src/'city_street_trees.csv.gz'),'--output',str(root/'city'),'--retrieved-at',now,'--tree-retrieved-at',now],check=True)
            subprocess.run([sys.executable,str(ROOT/'tests/check_city.py'),'--city',str(root/'city')],check=True)
            (root/'bulk.osm.gz').unlink();(root/'trees.csv').unlink()
            (root/'checksums.json').write_text(json.dumps(fingerprints(root),sort_keys=True))
            if STAGE.exists():shutil.rmtree(STAGE)
            shutil.copytree(root,STAGE)
        new=json.loads((STAGE/'city/manifest.json').read_text())
        print(json.dumps({'staged':str(STAGE),'review_flags':flags(old,new),'next':'Run --apply after reviewing counts; installed city unchanged'},indent=2))
    else:
        expected=json.loads((STAGE/'checksums.json').read_text())
        if fingerprints(STAGE)!=expected:raise ValueError('Staged files changed or are incomplete; city unchanged')
        new=json.loads((STAGE/'city/manifest.json').read_text());errors=flags(old,new)
        if errors:raise ValueError('; '.join(errors))
        subprocess.run([sys.executable,str(ROOT/'tests/check_city.py'),'--city',str(STAGE/'city')],check=True)
        backup=STAGE.parent/'previous-city'
        if backup.exists():shutil.rmtree(backup)
        CITY.rename(backup)
        try:(STAGE/'city').rename(CITY)
        except Exception:
            backup.rename(CITY);raise
        for source in (STAGE/'source').iterdir():shutil.copy2(source,ROOT/'data/source'/source.name)
        print('Applied city. Restart the desktop game; rebuild/reinstall iPhone app. Previous runtime retained in data/.refresh/previous-city.')
if __name__=='__main__':main()

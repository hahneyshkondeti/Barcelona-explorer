#!/usr/bin/env python3
"""Refresh a dated offline OSM snapshot. No API key, scheduler, or paid service.
--check is offline; --download fetches and stages; --apply promotes validated files.
"""
import argparse, datetime, gzip, json, pathlib, shutil, tempfile, subprocess
from import_map import BBOX, ROOT, build
CURRENT = ROOT/'data/eixample.json'
STAGE = ROOT/'data/.refresh'

def validate_change(old, new):
    problems=[]
    for key in ('roads','buildings'):
        before=len(old[key]); after=len(new[key])
        if after < before*.75 or after > before*1.5:
            problems.append(f'{key}: {before} -> {after} exceeds automatic acceptance range')
    if old['bbox_lonlat'] != new['bbox_lonlat']: problems.append('Coverage changed')
    return problems

def summary(data):
    date=datetime.datetime.fromisoformat(data['metadata']['retrieved_at'].replace('Z','+00:00'))
    days=(datetime.datetime.now(datetime.timezone.utc)-date).days
    return {'retrieved_at':data['metadata']['retrieved_at'],'age_days':days,'refresh_due':days>=7,'counts':data['metadata']['counts']}

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    group=ap.add_mutually_exclusive_group(required=True)
    group.add_argument('--check',action='store_true');group.add_argument('--download',action='store_true');group.add_argument('--apply',action='store_true')
    args=ap.parse_args();old=json.loads(CURRENT.read_text())
    if args.check: print(json.dumps(summary(old),indent=2));return
    if args.download:
        STAGE.mkdir(parents=True,exist_ok=True)
        (STAGE/'.gdignore').touch()
        url='https://api.openstreetmap.org/api/0.6/map?bbox='+','.join(map(str,BBOX))
        # macOS system curl uses the system trust store; TLS verification stays enabled.
        raw=subprocess.run(['curl','--fail','--location','--silent','--show-error','--max-time','90','--max-filesize','35000000',url],check=True,capture_output=True).stdout
        if len(raw)>35_000_000:raise ValueError('Map response exceeds the bounded snapshot limit')
        with tempfile.TemporaryDirectory(dir=STAGE) as temp:
            source=pathlib.Path(temp)/'source.osm';source.write_bytes(raw)
            candidate=build(source)
        changes=validate_change(old,candidate)
        with gzip.open(STAGE/'eixample.osm.gz','wb') as output:output.write(raw)
        (STAGE/'eixample.json').write_text(json.dumps(candidate,ensure_ascii=False,separators=(',',':')))
        print(json.dumps({'staged':summary(candidate),'review_flags':changes,'next':'Run tests/check_map.py --candidate data/.refresh/eixample.json, then refresh_map.py --apply'},indent=2))
    else:
        candidate=json.loads((STAGE/'eixample.json').read_text())
        changes=validate_change(old,candidate)
        if changes:raise ValueError('Manual review required; keeping current map: '+ '; '.join(changes))
        # Rebuild from staged source, so modified or truncated staged JSON cannot be promoted.
        rebuilt=build(STAGE/'eixample.osm.gz',candidate['metadata']['retrieved_at'])
        if rebuilt != candidate: raise ValueError('Candidate differs from source rebuild; current map untouched')
        shutil.copy2(CURRENT,ROOT/'data/.refresh/previous.json')
        next_path=CURRENT.with_suffix('.tmp');next_path.write_text(json.dumps(candidate,ensure_ascii=False,separators=(',',':')))
        next_path.replace(CURRENT)
        shutil.copy2(STAGE/'eixample.osm.gz',ROOT/'data/source/eixample.osm.gz')
        print('Applied offline snapshot. Restart the desktop game; rebuild/reinstall the iPhone app to distribute it. Previous data retained in data/.refresh/previous.json.')

if __name__=='__main__':main()

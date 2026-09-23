#!/usr/bin/env python3
"""Extract dated OSM transit and street furniture; never invent missing locations."""
import argparse, collections, gzip, json, math, pathlib, xml.etree.ElementTree as ET
from import_map import ROOT, project


def classify(tags):
    if tags.get('railway') == 'subway_entrance': return 'metro_entrance'
    if tags.get('railway') == 'station' and (tags.get('station') == 'subway' or tags.get('subway') == 'yes'): return 'metro_station'
    if tags.get('highway') == 'bus_stop' or (tags.get('public_transport') == 'platform' and tags.get('bus') == 'yes'): return 'bus_stop'
    if tags.get('highway') == 'traffic_signals': return 'traffic_signal'
    if tags.get('highway') in ('stop', 'give_way'): return tags['highway']
    if tags.get('traffic_sign'): return 'traffic_sign'
    return None


def elements(source):
    with gzip.open(source, 'rb') as stream:
        parser = ET.iterparse(stream, events=('start', 'end')); _, root = next(parser)
        for event, element in parser:
            if event == 'end' and element.tag in ('node', 'way', 'relation'):
                yield element
                root.clear()


def build(source, city):
    manifest = json.loads((city / 'manifest.json').read_text())
    bbox = manifest['bbox_lonlat']; cell_size = manifest['cell_size']
    records = {}; areas = {}; wanted = set(); ways = []
    def record(e, tags, kind, ll):
        if not (bbox[0] <= ll[0] <= bbox[2] and bbox[1] <= ll[1] <= bbox[3]): return
        identity = e if isinstance(e, dict) else e.attrib
        identity_kind = 'way' if isinstance(e, dict) else e.tag
        rid = identity_kind + '/' + identity['id']
        records[rid] = dict(id=rid, kind=kind, name=tags.get('name', ''), ref=tags.get('ref', ''),
                            point=project(*ll), lonlat=ll, tags=tags,
                            timestamp=identity.get('timestamp', 'unknown'))
    for e in elements(source):
        tags = {t.get('k'): t.get('v') for t in e.findall('tag')}
        kind = classify(tags)
        if e.tag == 'node' and kind:
            record(e, tags, kind, [float(e.get('lon')), float(e.get('lat'))])
        elif e.tag == 'way' and kind in ('bus_stop', 'metro_station'):
            refs = list(dict.fromkeys(n.get('ref') for n in e.findall('nd')))
            ways.append((dict(e.attrib), tags, kind, refs)); wanted.update(refs)
        elif e.tag == 'relation' and tags.get('public_transport') == 'stop_area':
            for member in e.findall('member'):
                areas[member.get('type') + '/' + member.get('ref')] = tags.get('name', '')
    coords = {}
    if wanted:
        for e in elements(source):
            if e.tag == 'node' and e.get('id') in wanted: coords[e.get('id')] = [float(e.get('lon')), float(e.get('lat'))]
        for attrs, tags, kind, refs in ways:
            if refs and all(ref in coords for ref in refs):
                record(attrs, tags, kind, [sum(coords[r][i] for r in refs)/len(refs) for i in range(2)])
    # A platform polygon and its stop pole can describe the same facility. Keep
    # the precise node, not a second pole at the polygon centroid.
    stops = [r for r in records.values() if r['kind'] == 'bus_stop' and r['id'].startswith('node/')]
    for rid, r in list(records.items()):
        if r['kind'] == 'bus_stop' and rid.startswith('way/') and any(math.dist(r['point'], n['point']) < 12 for n in stops): del records[rid]
    roads = collections.defaultdict(list)
    for road in manifest['roads']:
        a,b=road['a'],road['b']
        for x in range(math.floor(min(a[0],b[0])/cell_size),math.floor(max(a[0],b[0])/cell_size)+1):
            for z in range(math.floor(min(a[1],b[1])/cell_size),math.floor(max(a[1],b[1])/cell_size)+1): roads[x,z].append(road)
    cells = collections.defaultdict(list); counts = collections.Counter()
    for r in records.values():
        r['station_name'] = areas.get(r['id'], '')
        p = r['point']; x,z = [math.floor(v/cell_size) for v in p]
        closest=None; best=50.0
        for dx in (-1,0,1):
            for dz in (-1,0,1):
                for road in roads[x+dx,z+dz]:
                    a,b=road['a'],road['b']; v=[b[i]-a[i] for i in range(2)]; length=sum(t*t for t in v)
                    if not length: continue
                    t=max(0,min(1,sum((p[i]-a[i])*v[i] for i in range(2))/length)); q=[a[i]+t*v[i] for i in range(2)]
                    distance=math.dist(p,q)
                    if distance<best: best=distance; closest=(road,q,v)
        r['render_point']=p[:]; r['heading']=0.0; r['placement']='mapped'; r['orientation']='illustrative'
        if closest:
            road,q,v=closest; length=math.hypot(*v); forward=[v[0]/length,v[1]/length]
            tags=r['tags']; direction=tags.get('traffic_sign:direction',tags.get('direction',tags.get('traffic_signals:direction','')))
            if direction == 'backward': forward=[-v for v in forward]
            elif not direction and road['oneway']==-1: forward=[-v for v in forward]
            r['heading']=math.atan2(-forward[0],-forward[1]); r['orientation']='estimated_from_road'
            if r['kind'] in ('bus_stop','metro_entrance') and best>0.5: r['heading']=math.atan2(q[0]-p[0],q[1]-p[1])
            # OSM control nodes often lie ON the roadway, not at a physical pole.
            # Keep source coordinate; place illustrative pole on estimated verge.
            if r['kind'] in ('stop','give_way','traffic_signal','traffic_sign') and best<road['width']/2+0.3:
                side=[-forward[1],forward[0]]
                if tags.get('side')=='left': side=[-v for v in side]
                if not direction and best>0.5 and sum((p[i]-q[i])*side[i] for i in range(2))<0: side=[-v for v in side]
                r['render_point']=[round(q[i]+side[i]*(road['width']/2+0.65),3) for i in range(2)]
                r['placement']='estimated_roadside_offset'
        direction=r['tags'].get('traffic_sign:direction',r['tags'].get('direction',''))
        try:
            # OSM compass bearing specifies the direction the sign face points.
            bearing=float(direction)
            if 0<=bearing<360: r['heading']=math.radians(180-bearing);r['orientation']='mapped_bearing'
        except ValueError: pass
        cells[f'{x}:{z}'].append(r); counts[r['kind']]+=1
    result={'metadata':{'source':'OpenStreetMap','license':'ODbL-1.0','attribution':'© OpenStreetMap contributors',
            'retrieved_at':manifest['metadata']['retrieved_at'],'counts':dict(counts),
            'coverage':'Mapped features inside the city bounding envelope; not a complete official inventory.',
            'appearance':'Original illustrative assets. Station centers are map/search markers, not surface entrances. Roadside offsets and orientation may be estimated.'},'cells':dict(cells)}
    (city/'infrastructure.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
    print('Infrastructure:',dict(counts),flush=True)
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--source',type=pathlib.Path,default=ROOT/'data/source/barcelona.osm.gz');parser.add_argument('--city',type=pathlib.Path,default=ROOT/'data/city');args=parser.parse_args()
    build(args.source,args.city)

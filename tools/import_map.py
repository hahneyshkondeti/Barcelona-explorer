#!/usr/bin/env python3
"""Build a reproducible offline district from a bounded OSM XML snapshot (stdlib only).
Derived data is ODbL-1.0. Geometry is preserved; inferred appearance is flagged.
"""
import argparse, collections, datetime, gzip, hashlib, json, math, pathlib, re, xml.etree.ElementTree as ET
ROOT = pathlib.Path(__file__).resolve().parents[1]
BBOX = (2.169, 41.400, 2.180, 41.407)
ORIGIN = (2.1744, 41.4036)
DRIVABLE = {'primary','secondary','tertiary','residential','unclassified','service','living_street','primary_link','secondary_link','tertiary_link'}

def project(lon, lat):
    return [round(math.radians(lon-ORIGIN[0])*6378137*math.cos(math.radians(ORIGIN[1])),3), round(-math.radians(lat-ORIGIN[1])*6378137,3)]

def inside(lon, lat): return BBOX[0] <= lon <= BBOX[2] and BBOX[1] <= lat <= BBOX[3]
def num(v, default):
    try: return float(re.match(r'^[\d.]+', str(v)).group())
    except (ValueError, AttributeError): return default

def contains(p, poly):
    yes = False
    for a,b in zip(poly, poly[1:]+poly[:1]):
        if (a[1]>p[1]) != (b[1]>p[1]) and p[0] < (b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]: yes = not yes
    return yes

def stitch(paths):
    paths = [p[:] for p in paths if len(p)>1]; rings=[]
    while paths:
        chain=paths.pop()
        while chain[0]!=chain[-1]:
            found=False
            for i,p in enumerate(paths):
                if chain[-1]==p[0]: chain+=p[1:]
                elif chain[-1]==p[-1]: chain+=p[-2::-1]
                elif chain[0]==p[-1]: chain=p[:-1]+chain
                elif chain[0]==p[0]: chain=p[:0:-1]+chain
                else: continue
                paths.pop(i); found=True; break
            if not found: break
        if len(chain)>3 and chain[0]==chain[-1]: rings.append(chain[:-1])
    return rings

def clip_segment(a,b):
    t0,t1=0.,1.; dx=b[0]-a[0];dy=b[1]-a[1]
    for p,q in [(-dx,a[0]-BBOX[0]),(dx,BBOX[2]-a[0]),(-dy,a[1]-BBOX[1]),(dy,BBOX[3]-a[1])]:
        if abs(p)<1e-15:
            if q<0:return None
        elif p<0:t0=max(t0,q/p)
        else:t1=min(t1,q/p)
    if t0>t1:return None
    return ([a[0]+t0*dx,a[1]+t0*dy],[a[0]+t1*dx,a[1]+t1*dy],t0,t1)

def build(source, fetched_at=None, detailed_trees=False):
    raw=gzip.open(source,'rb').read() if str(source).endswith('.gz') else pathlib.Path(source).read_bytes()
    root=ET.fromstring(raw)
    if root.tag!='osm': raise ValueError('Expected an OSM XML map, not an error page')
    nodes={}; ways={}; relations=[]; records=[]; warnings=[]
    for e in root:
        if e.tag not in ('node','way','relation'): continue
        t={v.get('k'):v.get('v') for v in e.findall('tag')}
        record={'id':e.get('id'),'kind':e.tag,'tags':t,'timestamp':e.get('timestamp','unknown'),'version':e.get('version','')}
        if e.tag=='node': record['lonlat']=[float(e.get('lon')),float(e.get('lat'))]; nodes[record['id']]=record
        elif e.tag=='way': record['refs']=[v.get('ref') for v in e.findall('nd')]; ways[record['id']]=record
        else: record['members']=[dict(v.attrib) for v in e.findall('member')]; relations.append(record)
        records.append(record)
    data={'schema':2,'district_id':'sagrada_osm_v2','origin_lonlat':list(ORIGIN),'bbox_lonlat':list(BBOX),'bounds':[project(BBOX[0],BBOX[3]),project(BBOX[2],BBOX[1])], 'roads':[], 'buildings':[], 'places':[], 'parks':[], 'trees':[], 'addresses':[]}
    if detailed_trees: data["tree_records"]=[]
    used_members=set()
    for rel in relations:
        if not rel['tags'].get('building'): continue
        paths={'outer':[],'inner':[]}
        for m in rel['members']:
            if m['type']=='way' and m['ref'] in ways and m.get('role','outer') in paths:
                paths[m.get('role','outer')].append(ways[m['ref']]['refs'])
        outer=stitch(paths['outer']); holes=stitch(paths['inner'])
        for refs in outer:
            if any(v not in nodes for v in refs):continue
            rings=[refs]+[h for h in holes if all(v in nodes for v in h) and contains(nodes[h[0]]['lonlat'],[nodes[v]['lonlat'] for v in refs])]
            add_building(data,rel,rings,nodes)
        if outer: used_members.update(m['ref'] for m in rel['members'] if m['type']=='way')
    graph_nodes={}; graph_edges=[]
    for way in ways.values():
        t=way['tags']; refs=way['refs']
        if any(v not in nodes for v in refs): continue
        ll=[nodes[v]['lonlat'] for v in refs]
        if t.get('building') and way['id'] not in used_members and len(refs)>3 and refs[0]==refs[-1]: add_building(data,way,[refs[:-1]],nodes)
        if t.get('leisure')=='park' and refs[0]==refs[-1] and any(inside(*p) for p in ll): data['parks'].append({'id':way['id'],'name':t.get('name',''),'ring':[project(*p) for p in ll[:-1]]})
        if not t.get('highway') or t.get('area')=='yes': continue
        drivable=t['highway'] in DRIVABLE and t.get('access') not in ('no','private') and t.get('motor_vehicle') not in ('no','private') and t.get('motorcar') not in ('no','private')
        if t.get('tunnel')=='yes' or num(t.get('layer'),0)!=0: continue
        width=max(4,min(20,num(t.get('width'),num(t.get('lanes'),2)*3+2 if drivable else 3)))
        direction=-1 if t.get('oneway')=='-1' else 1 if t.get('oneway') in ('yes','1','true') or t.get('junction')=='roundabout' else 0
        for i,(a,b) in enumerate(zip(ll,ll[1:])):
            clipped=clip_segment(a,b)
            if not clipped: continue
            ca,cb,t0,t1=clipped; pa,pb=project(*ca),project(*cb)
            if math.dist(pa,pb)<0.2:continue
            aid=refs[i] if t0<1e-8 else f'edge:{way["id"]}:{i}:a'; bid=refs[i+1] if t1>1-1e-8 else f'edge:{way["id"]}:{i}:b'
            road={'id':f'{way["id"]}:{i}','osm_id':way['id'],'a':pa,'b':pb,'a_id':aid,'b_id':bid,'name':t.get('name','Unnamed mapped way'),'width':width,'width_source':'osm:width' if 'width' in t else 'estimated_from_lanes_or_default','drivable':drivable,'oneway':direction,'highway':t['highway'],'timestamp':way['timestamp']}
            data['roads'].append(road)
            if drivable:
                graph_nodes[aid]=pa;graph_nodes[bid]=pb
                graph_edges.append([aid,bid,direction])
    # Retain only the largest connected drivable component for routing and recovery.
    adjacent=collections.defaultdict(set)
    for a,b,_ in graph_edges: adjacent[a].add(b);adjacent[b].add(a)
    remaining=set(graph_nodes);groups=[]
    while remaining:
        todo=[min(remaining)];group=set(todo);remaining.difference_update(todo)
        while todo:
            for n in adjacent[todo.pop()]:
                if n in remaining:remaining.remove(n);group.add(n);todo.append(n)
        groups.append(group)
    main=max(groups,key=len) if groups else set()
    for road in data['roads']: road['routable']=road['drivable'] and road['a_id'] in main and road['b_id'] in main
    data['graph']={'nodes':{k:v for k,v in graph_nodes.items() if k in main},'edges':[e for e in graph_edges if e[0] in main and e[1] in main]}
    for record in records:
        t=record['tags']; ll=record.get('lonlat')
        if ll is None and record['kind']=='way':
            points=[nodes[v]['lonlat'] for v in record['refs'] if v in nodes]
            if points: ll=[sum(p[i] for p in points)/len(points) for i in range(2)]
        if ll is None or not inside(*ll):continue
        common={'id':record['kind']+'/'+record['id'],'point':project(*ll),'lonlat':ll,'timestamp':record['timestamp'],'version':record['version']}
        if t.get('natural')=='tree':
            data['trees'].append(common['point'])
            if detailed_trees: data['tree_records'].append(dict(common,species=t.get('species',''),source='OpenStreetMap',form='broadleaf'))
        if t.get('addr:housenumber'):
            data['addresses'].append(dict(common,street=t.get('addr:street',''),number=t['addr:housenumber'],postcode=t.get('addr:postcode','')))
        if t.get('shop') or t.get('amenity') in ('restaurant','cafe','bar','pharmacy','bank'):
            data['places'].append(dict(common,name=t.get('name','Unnamed '+t.get('shop',t.get('amenity','place'))),category=t.get('shop',t.get('amenity','')),street=t.get('addr:street',''),number=t.get('addr:housenumber',''),postcode=t.get('addr:postcode',''),check_date=t.get('check_date',t.get('check_date:opening_hours','')),opening_hours=t.get('opening_hours','')))
    data['places'].sort(key=lambda p:p['id']);data['buildings'].sort(key=lambda p:p['id'])
    # A playable curbside arrival location on mapped Carrer de Mallorca, not the building centroid.
    def nearest(p, name=None):
        best=None
        for r in data['roads']:
            if not r['routable'] or (name and name not in r['name']):continue
            a,b=r['a'],r['b']; d=[b[i]-a[i] for i in range(2)]; u=max(.1,min(.9,sum((p[i]-a[i])*d[i] for i in range(2))/sum(x*x for x in d)))
            q=[a[i]+u*d[i] for i in range(2)];cost=math.dist(p,q)
            if best is None or cost<best[0]:best=(cost,q,r)
        return best
    _,start,sr=nearest(project(2.1770,41.4047),'Mallorca')
    _,dest,dr=nearest(project(2.1746,41.4028),'Mallorca')
    delta=[sr['b'][i]-sr['a'][i] for i in range(2)]
    if sr['oneway']==-1:delta=[-x for x in delta]
    data['start']=start;data['start_heading']=math.atan2(-delta[0],-delta[1]);data['destination']=dest
    data['landmark_center']=project(2.17433,41.40358)
    data['metadata']={'source':'OpenStreetMap','attribution':'© OpenStreetMap contributors','license':'ODbL-1.0','license_url':'https://www.openstreetmap.org/copyright','retrieved_at':fetched_at or datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_sha256':hashlib.sha256(raw).hexdigest(),'coverage':'Sagrada Família area of Eixample; bounded pilot, not the whole district','accuracy':'Source coordinates preserved in a local tangent approximation. Not survey-certified. Heights without tags, widths without tags, façades, kerbs and surfaces are estimated. No live business verification.','warnings':warnings}
    data['metadata']['counts']={k:len(data[k]) for k in ['roads','buildings','places','addresses','trees','parks']}
    data['metadata']['counts']['places_with_full_address']=sum(bool(p['street'] and p['number']) for p in data['places'])
    data['metadata']['counts']['tagged_building_heights']=sum(b['height_source']!='estimated' for b in data['buildings'])
    if len(data['buildings'])<20 or len(main)<10 or len(data['roads'])<20:raise ValueError('Incomplete map; refusing to replace working snapshot')
    return data

def add_building(data,record,rings,nodes):
    ll=[nodes[v]['lonlat'] for v in rings[0]]
    if not any(inside(*p) for p in ll):return
    t=record['tags'];height=num(t.get('height'),num(t.get('building:levels'),6)*3.2+1.0)
    if t.get('building')=='church':height=num(t.get('height'),42)
    data['buildings'].append({'id':record['kind']+'/'+record['id'],'rings':[[project(*nodes[v]['lonlat']) for v in ring] for ring in rings],'height':min(175,max(3,height)),'height_source':'osm:height' if 'height' in t else 'osm:levels' if 'building:levels' in t else 'estimated','name':t.get('name',''),'material':t.get('building:material',''),'timestamp':record['timestamp'],'landmark':t.get('wikidata')=='Q48435'})

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--source',type=pathlib.Path,default=ROOT/'data/source/eixample.osm.gz');ap.add_argument('--output',type=pathlib.Path,default=ROOT/'data/eixample.json');ap.add_argument('--retrieved-at');args=ap.parse_args()
    result=build(args.source,args.retrieved_at);args.output.parent.mkdir(parents=True,exist_ok=True)
    temp=args.output.with_suffix('.tmp');temp.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')));temp.replace(args.output)
    print(json.dumps(result['metadata'],indent=2,ensure_ascii=False))

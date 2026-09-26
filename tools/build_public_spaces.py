#!/usr/bin/env python3
"""Mapped plaza and fountain footprints for two authored Barcelona sightseeing areas."""
import argparse, collections, json, math, pathlib
from build_infrastructure import elements
from import_map import ROOT, project, stitch, contains

SITES = {
    'catalunya': {'name':'Plaça de Catalunya', 'bbox':[2.1685,41.3858,2.1712,41.3880], 'outline':'19964084', 'source':'relation/1732345'},
    'espanya': {'name':"Plaça d’Espanya", 'bbox':[2.1485,41.3745,2.1498,41.3756], 'outline':'126832504', 'source':'way/126832504'},
}


def centroid(ring):
    terms=[a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]+ring[:1])]
    total=sum(terms)
    if abs(total)<1e-12: return [sum(p[i] for p in ring)/len(ring) for i in (0,1)]
    return [sum((a[i]+b[i])*cross for a,b,cross in zip(ring,ring[1:]+ring[:1],terms))/(3*total) for i in (0,1)]


def build(source, city):
    nodes={}; ways={}; relations=[]; node_tags={}
    for e in elements(source):
        tags={t.get('k'):t.get('v') for t in e.findall('tag')}
        if e.tag=='node':
            p=[float(e.get('lon')),float(e.get('lat'))]
            if any(b['bbox'][0]<=p[0]<=b['bbox'][2] and b['bbox'][1]<=p[1]<=b['bbox'][3] for b in SITES.values()):
                nodes[e.get('id')]=p
                if tags: node_tags[e.get('id')]=tags
        elif e.tag=='way':
            refs=[n.get('ref') for n in e.findall('nd')]
            if refs and all(r in nodes for r in refs): ways[e.get('id')]={'refs':refs,'tags':tags,'timestamp':e.get('timestamp','unknown')}
        elif e.tag=='relation' and tags.get('type')=='multipolygon':
            members=[dict(m.attrib) for m in e.findall('member')]
            if any(m['type']=='way' and m['ref'] in ways for m in members): relations.append((e.get('id'),tags,members))
    features=[]
    def kind(tags):
        if tags.get('name')=='Rosa dels Vents' and tags.get('artwork_type')=='tilework': return 'mosaic'
        if tags.get('amenity')=='fountain': return 'fountain'
        if tags.get('natural')=='water': return 'water'
        if tags.get('landuse')=='grass' or tags.get('leisure')=='garden': return 'garden'
        return None
    used=set()
    def add(identity,tags,rings):
        if not rings: return
        for outer in rings['outer']:
            if len(outer)<3: continue
            point=centroid([[nodes[r][0]-nodes[outer[0]][0],nodes[r][1]-nodes[outer[0]][1]] for r in outer])
            point=[point[i]+nodes[outer[0]][i] for i in (0,1)]
            site=next((k for k,v in SITES.items() if contains(point,[nodes[r] for r in ways[v['outline']]['refs']])),None)
            if not site: continue
            holes=[h for h in rings['inner'] if contains(nodes[h[0]],[nodes[r] for r in outer])]
            features.append({'id':identity,'site':site,'kind':kind(tags),'name':tags.get('name',''), 'point':project(*point),'rings':[[project(*nodes[r]) for r in ring] for ring in [outer]+holes], 'tags':tags})
    for rid,tags,members in relations:
        if not kind(tags): continue
        grouped={role:[ways[m['ref']]['refs'] for m in members if m['type']=='way' and m['ref'] in ways and m.get('role','outer')==role] for role in ('outer','inner')}
        if any(m['type']=='way' and m['ref'] not in ways for m in members): continue
        rings={role:stitch(paths) for role,paths in grouped.items()}
        if rings['outer']:
            add('relation/'+rid,tags,rings)
            used.update(m['ref'] for m in members if m['type']=='way')
    for wid,way in ways.items():
        refs=way['refs'];tags=way['tags']
        if wid not in used and kind(tags) and refs[0]==refs[-1]: add('way/'+wid,tags,{'outer':[refs[:-1]],'inner':[]})
    for nid,tags in node_tags.items():
        if tags.get('amenity')!='bench': continue
        point=nodes[nid]
        site=next((k for k,v in SITES.items() if contains(point,[nodes[r] for r in ways[v['outline']]['refs']])),None)
        if site: features.append({'id':'node/'+nid,'site':site,'kind':'bench','name':'','point':project(*point),'rings':[],'tags':tags})
    plazas=[]
    for key,site in SITES.items():
        ring=[project(*nodes[n]) for n in ways[site['outline']]['refs'][:-1]]
        center=[sum(p[i] for p in ring)/len(ring) for i in (0,1)]
        plazas.append({'id':site['source'],'site':key,'name':site['name'],'point':center,'rings':[ring],'kind':'square','timestamp':ways[site['outline']]['timestamp']})
    manifest=json.loads((city/'manifest.json').read_text())
    data={'metadata':{'source':'OpenStreetMap','attribution':'© OpenStreetMap contributors — ODbL 1.0','retrieved_at':manifest['metadata']['retrieved_at'],
        'appearance':'Mapped plaza, planting and basin outlines. Original architectural interpretation; dimensions above ground, sculptural details, paving pattern and water jets are approximations. Water is a simulated visual effect, not live operating status.',
        'architecture_sources':['https://www.barcelonaturisme.com/wv3/cat/page/1214/font-monumental-de-la-placa-espanya.html','https://www.jujol.org/placa-espanya','https://bid.barcelonaturisme.com/wv3/en/page/1241/placa-de-catalunya.html']},
        'sites':plazas,'features':features,'replaced_buildings':['way/126832508']}
    # These named features must not silently disappear after a source refresh.
    if not any(f['id']=='way/126832508' for f in features): raise ValueError('Espanya fountain footprint missing')
    if sum(f['id']=='relation/21286243' for f in features)!=2: raise ValueError('Catalunya twin fountain footprints missing')
    (city/'public_spaces.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
    print('Public spaces:',len(plazas),'squares;',dict(collections.Counter(f['kind'] for f in features)))
    return data

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=pathlib.Path,default=ROOT/'data/source/barcelona.osm.gz');parser.add_argument('--city',type=pathlib.Path,default=ROOT/'data/city');args=parser.parse_args();build(args.source,args.city)

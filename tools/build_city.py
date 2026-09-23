#!/usr/bin/env python3
"""Reproducible Barcelona-wide offline tiles from a bulk OSM extract."""
import argparse, collections, datetime, gzip, json, math, pathlib, sys, xml.etree.ElementTree as ET
import import_map as im
ROOT=im.ROOT
CELL=192

def boundary(path):
    root=ET.parse(path).getroot()
    nodes={n.get('id'):[float(n.get('lon')),float(n.get('lat'))] for n in root.findall('node')}
    ways={w.get('id'):[n.get('ref') for n in w.findall('nd')] for w in root.findall('way')}
    rel=root.find("relation[@id='347950']")
    if rel is None: raise ValueError('Expected Barcelona municipal boundary relation 347950')
    rings=im.stitch([ways[m.get('ref')] for m in rel.findall('member') if m.get('type')=='way' and m.get('role')=='outer'])
    if not rings: raise ValueError('Missing municipal boundary rings')
    rings=[[nodes[n] for n in ring] for ring in rings]
    points=[p for ring in rings for p in ring]
    return rings,(min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points))

def extract(source,output,bbox):
    # Keep a small fringe to preserve complete ways at the municipal envelope.
    kept=set(); ways=set(); count=collections.Counter()
    with gzip.open(source,'rb') as stream,gzip.open(output,'wb',compresslevel=6) as out:
        out.write(b'<osm version="0.6" generator="Brisa city envelope filter">\n')
        parser=ET.iterparse(stream,events=('start','end'));_,root=next(parser)
        for event,e in parser:
            if event!='end' or e.tag not in ('node','way','relation'):continue
            keep=False
            if e.tag=='node':
                lon,lat=float(e.get('lon')),float(e.get('lat'))
                keep=bbox[0]-.005<=lon<=bbox[2]+.005 and bbox[1]-.005<=lat<=bbox[3]+.005
                if keep:kept.add(e.get('id'))
            elif e.tag=='way':
                refs=[n.get('ref') for n in e.findall('nd')]
                keep=bool(refs) and all(n in kept for n in refs)
                if keep:ways.add(e.get('id'))
            else:
                keep=any(m.get('type')=='way' and m.get('ref') in ways for m in e.findall('member'))
            if keep:
                out.write(ET.tostring(e));count[e.tag]+=1
            root.clear()
        out.write(b'</osm>')
    print('Filtered source:',dict(count),flush=True)

def key(p):return f'{math.floor(p[0]/CELL)}:{math.floor(p[1]/CELL)}'
def cells(points):
    return [f'{x}:{y}' for x in range(math.floor(min(p[0] for p in points)/CELL),math.floor(max(p[0] for p in points)/CELL)+1) for y in range(math.floor(min(p[1] for p in points)/CELL),math.floor(max(p[1] for p in points)/CELL)+1)]
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))

def pack(data,tree_data,rings,out):
    out.mkdir(parents=True,exist_ok=True); (out/'tiles').mkdir(exist_ok=True)
    tiles={}; dependencies=collections.defaultdict(set)
    def add(kind,record,points):
        owner=key(points[0]);tile=tiles.setdefault(owner,{k:[] for k in ('roads','buildings','trees','parks','addresses','places')})
        tile[kind].append(record)
        for cell in cells(points):dependencies[cell].add(owner)
    for r in data['roads']:
        # Short road pieces keep ownership/culling local; routing retains original graph.
        n=max(1,math.ceil(math.dist(r['a'],r['b'])/80))
        for i in range(n):
            a=[r['a'][j]+(r['b'][j]-r['a'][j])*i/n for j in range(2)]
            b=[r['a'][j]+(r['b'][j]-r['a'][j])*(i+1)/n for j in range(2)]
            add('roads',dict(r,a=a,b=b),[a,b])
    for b in data['buildings']:add('buildings',b,[p for ring in b['rings'] for p in ring])
    for p in data['parks']:add('parks',p,p['ring'])
    for t in tree_data['trees']:add('trees',t,[t['point']])
    for kind in ('places','addresses'):
        for r in data[kind]:add(kind,r,[r['point']])
    for k,tile in tiles.items():dump(out/'tiles'/f'{k.replace(":","_")}.json',tile)
    manifest={k:v for k,v in data.items() if k not in ('buildings','trees','tree_records','parks','addresses','roads')}
    manifest['roads']=[r for r in data['roads'] if r['routable']]
    manifest['buildings']=[{'id':b['id'],'landmark':b['landmark']} for b in data['buildings']]
    manifest['addresses']=[];manifest['parks']=[];manifest['trees']=[]
    manifest['cell_size']=CELL;manifest['tiles']={k:f'res://data/city/tiles/{k.replace(":","_")}.json' for k in tiles}
    manifest['tile_dependencies']={k:sorted(v) for k,v in dependencies.items()}
    manifest['municipal_boundary']=[[im.project(*p) for p in ring] for ring in rings]
    manifest['tree_metadata']=tree_data['metadata']
    manifest['district_id']='barcelona_city_v1'
    manifest['metadata']['coverage']='Entire Barcelona municipal bounding envelope, with neighboring fringe. Surface roads; flat terrain.'
    manifest['metadata']['bulk_source']='https://download.bbbike.org/osm/bbbike/Barcelona/Barcelona.osm.gz'
    manifest['metadata']['boundary_relation']='347950'
    dump(out/'manifest.json',manifest)
    print('Packed',len(tiles),'tiles;',data['metadata']['counts'],flush=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--source',type=pathlib.Path,default=ROOT/'data/source/barcelona.osm.gz');ap.add_argument('--bulk',type=pathlib.Path);ap.add_argument('--boundary',type=pathlib.Path,default=ROOT/'data/source/barcelona-boundary.osm');ap.add_argument('--trees',type=pathlib.Path,required=True);ap.add_argument('--output',type=pathlib.Path,default=ROOT/'data/city');ap.add_argument('--retrieved-at');ap.add_argument('--tree-retrieved-at');ap.add_argument('--tree-source-output',type=pathlib.Path,default=ROOT/'data/source/city_street_trees.csv.gz');args=ap.parse_args()
    rings,bbox=boundary(args.boundary);im.BBOX=bbox
    if args.bulk:extract(args.bulk,args.source,bbox)
    data=im.build(args.source,args.retrieved_at,detailed_trees=True)
    print('Map imported',data['metadata']['counts'],flush=True)
    # Municipality street inventory: avoid interpolating rows or fabricating trees.
    import csv,io
    raw=gzip.decompress(args.trees.read_bytes()) if args.trees.suffix=='.gz' else args.trees.read_bytes()
    records=[];selected=[];reader=csv.DictReader(io.StringIO(raw.decode('utf-8-sig')))
    for row in reader:
        ll=[float(row['longitud']),float(row['latitud'])]
        if not im.inside(*ll):continue
        selected.append(row)
        records.append({'id':'bcn/'+row['codi'],'source':'Open Data BCN','point':im.project(*ll),'lonlat':ll,'species':row['cat_nom_cientific'],'address':row['adreca'],'planted_at':row['data_plantacio'],'form':'palm' if 'PALMERA' in row['tipus_element'] else 'broadleaf'})
    buf=io.StringIO();writer=csv.DictWriter(buf,fieldnames=reader.fieldnames);writer.writeheader();writer.writerows(selected)
    args.tree_source_output.write_bytes(gzip.compress(buf.getvalue().encode(),mtime=0))
    # Preserve mapped park trees citywide; use a small spatial grid to deduplicate.
    park_cells=collections.defaultdict(list)
    for park_record in data['parks']:
        for cell in cells(park_record['ring']):park_cells[cell].append(park_record)
    municipal_grid=collections.defaultdict(list)
    for tree in records:
        p=tree['point'];municipal_grid[(math.floor(p[0]/3),math.floor(p[1]/3))].append(p)
    park=[]
    for tree in data['tree_records']:
        p=tree['point']
        if not any(im.contains(p,area['ring']) for area in park_cells.get(key(p),[])):continue
        x,z=math.floor(p[0]/3),math.floor(p[1]/3)
        if any(math.dist(p,q)<3 for dx in (-1,0,1) for dz in (-1,0,1) for q in municipal_grid.get((x+dx,z+dz),[])):continue
        tree['id']='osm/'+tree['id']
        park.append(tree)
    records.extend(park)
    trees={'trees':records,'metadata':{'municipal_street_trees':len(selected),'osm_park_trees':len(park),'retrieved_at':args.tree_retrieved_at or json.loads((ROOT/'data/trees.json').read_text())['metadata']['retrieved_at'],'attribution':'Ajuntament de Barcelona / Open Data BCN — CC BY 4.0; park fallback © OpenStreetMap contributors — ODbL 1.0','coverage':'Municipal street trees and mapped OSM park-tree fallback citywide'}}
    pack(data,trees,rings,args.output)
    groups=collections.defaultdict(list)
    for row in selected:
        if row['codi_districte']:
            groups[(row['codi_districte'],row['nom_districte'])].append([float(row['longitud']),float(row['latitud'])])
    areas=[]
    for (code,name),points in sorted(groups.items()):
        center=[sum(p[i] for p in points)/len(points) for i in range(2)]
        point=min(points,key=lambda p:math.dist(p,center))
        areas.append({'code':code,'name':name.title(),'lonlat':point})
    if len(areas)!=10: raise ValueError('Missing city district coverage')
    dump(args.output/'areas.json',areas)

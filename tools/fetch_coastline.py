#!/usr/bin/env python3
"""Complete only open coastline chains in the city extract using OSM's read API."""
import collections,datetime,gzip,json,subprocess,xml.etree.ElementTree as ET
from build_infrastructure import elements
from import_map import ROOT,project

def fetch(path):
    url='https://api.openstreetmap.org/api/0.6/'+path
    return ET.fromstring(subprocess.check_output(['curl','--fail','--silent','--show-error','--max-time','40','--retry','2',url]))

def main():
    source=ROOT/'data/source/barcelona.osm.gz';ways={};wanted=set();nodes={}
    for e in elements(source):
        if e.tag=='way' and any(t.get('k')=='natural' and t.get('v')=='coastline' for t in e.findall('tag')):
            ways[e.get('id')]=ET.fromstring(ET.tostring(e));wanted.update(n.get('ref') for n in e.findall('nd'))
    for e in elements(source):
        if e.tag=='node' and e.get('id') in wanted:nodes[e.get('id')]=ET.fromstring(ET.tostring(e))
    manifest=json.loads((ROOT/'data/city/manifest.json').read_text());lo,hi=manifest['bounds'];visited=set()
    for _ in range(30):
        counts=collections.Counter(r for w in ways.values() for r in [w.findall('nd')[0].get('ref'),w.findall('nd')[-1].get('ref')])
        ends=[]
        for r,count in counts.items():
            n=nodes[r];p=project(float(n.get('lon')),float(n.get('lat')))
            if count==1 and r not in visited and lo[0]-500<=p[0]<=hi[0]+500 and lo[1]-500<=p[1]<=hi[1]+500:ends.append(r)
        if not ends:break
        for r in ends:
            visited.add(r)
            for way in fetch('node/'+r+'/ways').findall('way'):
                if way.get('id') in ways or not any(t.get('k')=='natural' and t.get('v')=='coastline' for t in way.findall('tag')):continue
                full=fetch('way/'+way.get('id')+'/full')
                for n in full.findall('node'):nodes[n.get('id')]=n
                for w in full.findall('way'):ways[w.get('id')]=w
                print('Added coastline way',way.get('id'),flush=True)
    root=ET.Element('osm',version='0.6',generator='Brisa coastline completion; OSM API '+datetime.datetime.now(datetime.timezone.utc).date().isoformat())
    for n in nodes.values():root.append(n)
    for w in ways.values():root.append(w)
    out=ROOT/'data/source/barcelona-coast.osm.gz';out.write_bytes(gzip.compress(ET.tostring(root),mtime=0))
    print('Saved',len(ways),'ways',len(nodes),'nodes',flush=True)
if __name__=='__main__':main()

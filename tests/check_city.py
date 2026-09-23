#!/usr/bin/env python3
"""Check the shipped city tile manifest, ownership and all-district coverage."""
import argparse,collections,json,math,pathlib,sys,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from refresh_city import flags
ap=argparse.ArgumentParser();ap.add_argument('--city',type=pathlib.Path,default=ROOT/'data/city');args,rest=ap.parse_known_args()
M=json.loads((args.city/'manifest.json').read_text());AREAS=json.loads((args.city/'areas.json').read_text())
class CityChecks(unittest.TestCase):
    def test_city_envelope(self):
        self.assertEqual(M['metadata']['boundary_relation'],'347950')
        lo,hi=M['bounds']
        self.assertGreater(hi[0]-lo[0],14000);self.assertGreater(hi[1]-lo[1],16000)
        for ring in M['municipal_boundary']:
            for x,z in ring:self.assertTrue(lo[0]<=x<=hi[0] and lo[1]<=z<=hi[1])
    def test_all_districts(self):
        self.assertEqual({a['code'] for a in AREAS},{f'{i:02}' for i in range(1,11)})
        self.assertTrue(all(a['name'] for a in AREAS))
    def test_graph(self):
        nodes=M['graph']['nodes'];adj=collections.defaultdict(set)
        for a,b,d in M['graph']['edges']:
            self.assertIn(a,nodes);self.assertIn(b,nodes);self.assertIn(d,(-1,0,1))
            adj[a].add(b);adj[b].add(a)
        todo=[next(iter(nodes))];seen=set(todo)
        while todo:
            for other in adj[todo.pop()]:
                if other not in seen:seen.add(other);todo.append(other)
        self.assertEqual(len(seen),len(nodes))
    def test_dependencies(self):
        for cell,owners in M['tile_dependencies'].items():
            self.assertEqual(len(owners),len(set(owners)))
            for owner in owners:self.assertIn(owner,M['tiles'])
    def test_all_tile_payloads(self):
        counts=collections.Counter();building_ids=set();tree_ids=set();address_streets=collections.defaultdict(set)
        for key,path in M['tiles'].items():
            tile=json.loads((args.city/'tiles'/path.rsplit('/',1)[1]).read_text())
            for kind,records in tile.items(): counts[kind]+=len(records)
            for b in tile['buildings']:
                building_ids.add(b['id']);self.assertGreaterEqual(len(b['rings'][0]),3)
                for ring in b['rings']:
                    self.assertTrue(all(math.isfinite(v) for p in ring for v in p))
            for address in tile['addresses']:
                if address['street']: address_streets[address['street']].add(key)
            for t in tile['trees']:
                self.assertNotIn(t['id'],tree_ids);tree_ids.add(t['id'])
        index=json.loads((args.city/'address_index.json').read_text())
        self.assertEqual({name:set(keys) for name,keys in index.items()},dict(address_streets))
        for kind in ('buildings','places','addresses','parks'):
            self.assertEqual(counts[kind],M['metadata']['counts'][kind])
        self.assertEqual(building_ids,{b['id'] for b in M['buildings']})
        self.assertEqual(counts['trees'],M['tree_metadata']['municipal_street_trees']+M['tree_metadata']['osm_park_trees'])
        self.assertGreaterEqual(counts['roads'],M['metadata']['counts']['roads'])
    def test_offline_overview(self):
        import xml.etree.ElementTree as ET
        root=ET.parse(args.city/'overview.svg').getroot()
        lo,hi=M['bounds']
        self.assertEqual(list(map(float,root.attrib['viewBox'].split())),[lo[0],lo[1],hi[0]-lo[0],hi[1]-lo[1]])
        self.assertEqual(len(root.findall('.//{http://www.w3.org/2000/svg}path')),len(M['roads']))
    def test_refresh_rejects_truncated_city(self):
        new=dict(M,metadata=dict(M['metadata'],counts=dict(M['metadata']['counts'],roads=0)))
        self.assertTrue(flags(M,new))
    def test_refresh_rejects_coverage_change(self):
        self.assertTrue(flags(M,dict(M,bbox_lonlat=[0,0,1,1])))
        self.assertEqual(flags(M,M),[])
    def test_preserved_intro_location(self):
        pilot=json.loads((ROOT/'data/eixample.json').read_text())
        self.assertEqual(M['origin_lonlat'],pilot['origin_lonlat'])
        self.assertLess(math.dist(M['start'],pilot['start']),5)
        self.assertLess(math.dist(M['destination'],pilot['destination']),5)
if __name__=='__main__':unittest.main(argv=[sys.argv[0]]+rest)

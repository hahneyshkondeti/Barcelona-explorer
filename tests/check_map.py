#!/usr/bin/env python3
"""Validate the actual snapshot and importer, not just generated appearance."""
import argparse, collections, json, math, pathlib, sys, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from import_map import build, project, BBOX
from refresh_map import validate_change
ap=argparse.ArgumentParser();ap.add_argument('--candidate',type=pathlib.Path,default=ROOT/'data/eixample.json');args,rest=ap.parse_known_args()
DATA=json.loads(args.candidate.read_text())
class MapChecks(unittest.TestCase):
    def test_real_street_names(self):
        names={r['name'] for r in DATA['roads']}
        self.assertIn('Carrer de Mallorca',names);self.assertIn('Carrer de Provença',names);self.assertIn('Carrer de Sardenya',names)
    def test_source_projection(self):
        for p in DATA['places']:self.assertEqual(p['point'],project(*p['lonlat']))
    def test_building_rings(self):
        for b in DATA['buildings']:
            self.assertGreaterEqual(len(b['rings'][0]),3)
            self.assertTrue(3<=b['height']<=175)
            self.assertIn(b['height_source'],('estimated','osm:height','osm:levels'))
            for r in b['rings']:self.assertTrue(all(math.isfinite(v) for p in r for v in p))
    def test_drivable_graph(self):
        nodes=DATA['graph']['nodes'];adj=collections.defaultdict(set)
        for a,b,d in DATA['graph']['edges']:
            self.assertIn(a,nodes);self.assertIn(b,nodes);self.assertIn(d,(-1,0,1))
            adj[a].add(b);adj[b].add(a)
        seen={next(iter(nodes))};todo=list(seen)
        while todo:
            for n in adj[todo.pop()]:
                if n not in seen:seen.add(n);todo.append(n)
        self.assertEqual(len(seen),len(nodes))
    def test_partial_address_honesty(self):
        self.assertTrue(any(not p['street'] or not p['number'] for p in DATA['places']))
        self.assertEqual(sum(bool(p['street'] and p['number']) for p in DATA['places']),DATA['metadata']['counts']['places_with_full_address'])
        self.assertTrue(all(p['timestamp'] and p['id'] for p in DATA['places']))
    def test_oneway_data_exists(self):self.assertTrue(any(r['routable'] and r['oneway'] for r in DATA['roads']))
    def test_projection_scale(self):self.assertAlmostEqual(math.dist(project(2.1744,41.4036),project(2.1744,41.4046)),111.319,places=2)
    def test_refresh_rejects_truncation(self):
        truncated=dict(DATA,roads=DATA['roads'][:3]);self.assertTrue(validate_change(DATA,truncated))
    def test_refresh_accepts_same_snapshot(self):self.assertEqual(validate_change(DATA,DATA),[])
    def test_reproducible_import(self):
        if args.candidate.resolve()==(ROOT/'data/eixample.json').resolve():
            self.assertEqual(build(ROOT/'data/source/eixample.osm.gz',DATA['metadata']['retrieved_at']),DATA)
if __name__=='__main__':unittest.main(argv=[sys.argv[0]]+rest)

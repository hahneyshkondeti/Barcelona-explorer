#!/usr/bin/env python3
import gzip,json,math,pathlib,sys,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from refresh_trees import build,bounded_csv,SOURCE,OUTPUT
from import_map import project,contains
DATA=json.loads(OUTPUT.read_text()); MAP=json.loads((ROOT/'data/eixample.json').read_text())
class TreeChecks(unittest.TestCase):
    def test_source_coordinates_not_snapped(self):
        for tree in DATA['trees']:self.assertEqual(tree['point'],project(*tree['lonlat']))
    def test_distinct_records_and_provenance(self):
        self.assertEqual(len(DATA['trees']),len({t['id'] for t in DATA['trees']}))
        for tree in DATA['trees']:
            self.assertIn(tree['source'],('Open Data BCN','OpenStreetMap'))
            self.assertIn('estimated',tree['appearance'])
    def test_park_fallback_not_old_street_layer(self):
        municipal=[t for t in DATA['trees'] if t['source']=='Open Data BCN']
        for tree in DATA['trees']:
            if tree['source']=='OpenStreetMap':
                self.assertTrue(any(contains(tree['point'],p['ring']) for p in MAP['parks']))
                self.assertTrue(all(math.dist(tree['point'],t['point'])>=3 for t in municipal))
    def test_source_reproducible(self):
        self.assertEqual(build(gzip.decompress(SOURCE.read_bytes()),DATA['metadata']['retrieved_at']),DATA)
    def test_reject_bad_download(self):
        for raw in [b'<html>Error</html>',b'codi,longitud,latitud\n1,nan,1']:
            with self.assertRaises(ValueError):bounded_csv(raw)
    def test_record_counts(self):
        self.assertEqual(sum(t['source']=='Open Data BCN' for t in DATA['trees']),DATA['metadata']['municipal_street_trees'])
        self.assertEqual(sum(t['source']=='OpenStreetMap' for t in DATA['trees']),DATA['metadata']['osm_park_trees'])
if __name__=='__main__':unittest.main()

#!/usr/bin/env python3
"""Validate the shipped offline payload without geospatial build dependencies."""
import array,hashlib,json,pathlib,sys,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class TerrainBundle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.meta=json.loads((ROOT/'data/terrain/metadata.json').read_text())
        cls.raw=(ROOT/'data/terrain/heights.f32').read_bytes()
        cls.heights=array.array('f');cls.heights.frombytes(cls.raw)
        if sys.byteorder!='little':cls.heights.byteswap()
    def test_complete_grid_and_hash(self):
        self.assertEqual(len(self.heights),self.meta['columns']*self.meta['rows'])
        self.assertEqual(hashlib.sha256(self.raw).hexdigest(),self.meta['height_sha256'])
        self.assertEqual(min(self.heights),self.meta['min_m'])
        self.assertEqual(max(self.heights),self.meta['max_m'])
    def test_sources_retained(self):
        self.assertEqual(hashlib.sha256((ROOT/'data/source/barcelona-met5.tif').read_bytes()).hexdigest(),self.meta['source_sha256'])
        coast=json.loads((ROOT/'data/terrain/coast.json').read_text())
        self.assertEqual(hashlib.sha256((ROOT/'data/source/barcelona-coast.osm.gz').read_bytes()).hexdigest(),coast['source_sha256'])
        self.assertGreater(len(coast['triangles']),300)
        self.assertEqual(len(coast['triangles'])%3,0)
    def test_estimates_are_explicit(self):
        mask=(ROOT/'data/terrain/estimated.bin').read_bytes()
        self.assertEqual(len(mask),(len(self.heights)+7)//8)
        self.assertEqual(sum(v.bit_count() for v in mask),self.meta['shore_nodata_filled'])
        self.assertLess(self.meta['shore_nodata_filled']/len(self.heights),0.01)
        parks=(ROOT/'data/terrain/parks.bin').read_bytes()
        self.assertEqual(len(parks),len(mask))
        self.assertGreater(sum(v.bit_count() for v in parks),1000)
    def test_export_includes_runtime_payload(self):
        preset=(ROOT/'export_presets.cfg').read_text()
        for pattern in ['data/terrain/*.json','data/terrain/*.f32','data/terrain/*.bin']:self.assertIn(pattern,preset)
if __name__=='__main__':unittest.main()

"""Regression fixtures for mapped transit, deduplication and safe sign placement."""
import gzip, json, pathlib, sys, tempfile, unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from build_infrastructure import build, classify
from furniture_placement import place_stop, footprint, clear_of_roads

class InfrastructureChecks(unittest.TestCase):
    def test_transport_semantics(self):
        self.assertEqual(classify({'railway':'subway_entrance'}),'metro_entrance')
        self.assertEqual(classify({'railway':'station','station':'subway'}),'metro_station')
        self.assertIsNone(classify({'railway':'station','train':'yes'}))
        self.assertIsNone(classify({'public_transport':'stop_position','bus':'yes'}))
        self.assertEqual(classify({'highway':'bus_stop','public_transport':'platform','bus':'yes'}),'bus_stop')
        self.assertEqual(classify({'highway':'stop','traffic_sign':'ES:R2'}),'stop')

    def test_bus_clears_both_roads_at_intersection(self):
        roads=[{'a':[-30,0],'b':[30,0],'width':8},{'a':[0,-30],'b':[0,30],'width':8}]
        point=[1,1]
        result=place_stop(point,roads,[],True)
        self.assertTrue(result['render_visible'])
        self.assertGreater(abs(result['render_point'][0]),4.9)
        self.assertGreater(abs(result['render_point'][1]),4.9)
        self.assertTrue(clear_of_roads(footprint(result['render_point'],result['heading'],result['render_shelter']),roads))
        self.assertEqual(point,[1,1])

    def test_unsafe_shelter_is_omitted_on_narrow_sidewalk(self):
        road={'a':[-30,0],'b':[30,0],'width':8}
        building=[[[-30,6],[30,6],[30,30],[-30,30]]]
        result=place_stop([0,5.1],[road],[building],True)
        self.assertTrue(result['render_visible'])
        self.assertFalse(result['render_shelter'])
        blocked=[[[-30,-30],[30,-30],[30,30],[-30,30]]]
        self.assertFalse(place_stop([0,0],[road],[blocked],True)['render_visible'])

    def test_source_coordinates_relations_and_offsets(self):
        with tempfile.TemporaryDirectory() as temp:
            city=pathlib.Path(temp)
            (city/'manifest.json').write_text(json.dumps({'bbox_lonlat':[2.17,41.40,2.18,41.41], 'cell_size':192,'metadata':{'retrieved_at':'2026-09-22T00:00:00+00:00'},'roads':[{'a':[-100,0],'b':[100,0],'width':8,'oneway':0}]}))
            source=city/'test.osm.gz'
            source.write_bytes(gzip.compress(b'''<osm>
              <node id="1" lon="2.1744" lat="41.4036"><tag k="highway" v="stop"/><tag k="direction" v="forward"/></node>
              <node id="2" lon="2.175" lat="41.404"><tag k="railway" v="subway_entrance"/><tag k="name" v="Exit Street"/></node>
              <node id="3" lon="2.1751" lat="41.404"><tag k="highway" v="bus_stop"/><tag k="ref" v="12"/></node>
              <node id="4" lon="2.1751" lat="41.40401"/>
              <node id="5" lon="3" lat="41.404"><tag k="railway" v="subway_entrance"/></node>
              <way id="6"><nd ref="3"/><nd ref="4"/><tag k="public_transport" v="platform"/><tag k="bus" v="yes"/></way>
              <way id="7"><nd ref="1"/><nd ref="2"/><tag k="traffic_sign" v="maxspeed"/></way>
              <relation id="8"><member type="node" ref="2"/><tag k="public_transport" v="stop_area"/><tag k="name" v="Example Metro"/></relation>
            </osm>'''))
            data=build(source,city);records={r['id']:r for rs in data['cells'].values() for r in rs}
            self.assertEqual(set(records),{'node/1','node/2','node/3'})
            self.assertEqual(records['node/2']['station_name'],'Example Metro')
            self.assertEqual(records['node/2']['display_name'],'Example Metro')
            self.assertEqual(records['node/2']['entrance_name'],'Exit Street')
            stop=records['node/1'];self.assertEqual(stop['point'],[0,0])
            self.assertGreater(abs(stop['render_point'][1]),4)
            self.assertEqual(stop['placement'],'estimated_roadside_offset')
            self.assertEqual(records['node/2']['render_point'],records['node/2']['point'])
            self.assertEqual(data['metadata']['counts'],{'stop':1,'metro_entrance':1,'bus_stop':1})

if __name__=='__main__': unittest.main()

#!/usr/bin/env python3
"""Build the offline terrain from ICGC MET5 and a complete OSM coastline extract.
Developer-only dependencies: requirements-terrain.txt. Runtime needs no service.
"""
import argparse, hashlib, json, math, pathlib
import numpy as np
import rasterio
from rasterio.features import rasterize
from affine import Affine
from pyproj import Transformer
from scipy.ndimage import distance_transform_edt
from shapely.geometry import LineString, Point, box
from shapely.ops import unary_union, polygonize
from shapely import STRtree, contains_xy, constrained_delaunay_triangles
from build_infrastructure import elements
from import_map import ROOT, ORIGIN, project

SOURCE_URL = 'https://geoserveis.icgc.cat/icc_mdt/wcs/service?SERVICE=WCS&VERSION=1.0.0&REQUEST=GetCoverage&COVERAGE=icc:met&CRS=EPSG:25831&BBOX=419845,4573120,436410,4592255&RESX=5&RESY=5&FORMAT=ARCGRID'
PRODUCT_URL = 'https://www.icgc.cat/en/Geoinformation-and-Maps/Data-and-products/Bessons-digitals-Elevacions/5x5-m-Terrain-elevation-model'

def coastline(source, extent):
    ways=[]; wanted=set()
    for e in elements(source):
        if e.tag=='way' and any(t.get('k')=='natural' and t.get('v')=='coastline' for t in e.findall('tag')):
            refs=[n.get('ref') for n in e.findall('nd')]; ways.append(refs); wanted.update(refs)
    nodes={}
    for e in elements(source):
        if e.tag=='node' and e.get('id') in wanted: nodes[e.get('id')]=project(float(e.get('lon')),float(e.get('lat')))
    if any(r not in nodes for refs in ways for r in refs): raise ValueError('Incomplete coastline node references')
    lines=[LineString([nodes[r] for r in refs]) for refs in ways]
    segments=[LineString([a,b]) for line in lines for a,b in zip(line.coords,list(line.coords)[1:]) if a!=b]
    tree=STRtree(segments)
    faces=list(polygonize(unary_union([extent.boundary]+[line.intersection(extent) for line in lines])))
    water=[]
    for face in faces:
        p=face.representative_point(); line=segments[tree.nearest(p)]; a,b=list(line.coords)
        # OSM land lies left of a directed coast; game Z reverses latitude.
        cross=(b[0]-a[0])*(p.y-a[1])-(b[1]-a[1])*(p.x-a[0])
        if cross>0: water.append(face)
    ocean=unary_union(water)
    for ll, expected in [((2.1744,41.4036),False),((2.1200,41.4220),False),((2.205,41.375),True),((2.21,41.35),True)]:
        if ocean.contains(Point(project(*ll)))!=expected: raise ValueError(f'Coastline topology incomplete near {ll}')
    triangles=[]
    for tri in constrained_delaunay_triangles(ocean).geoms:
        coords=list(tri.exterior.coords)[:3]
        if (coords[1][0]-coords[0][0])*(coords[2][1]-coords[0][1])-(coords[1][1]-coords[0][1])*(coords[2][0]-coords[0][0])<0: coords.reverse()
        triangles.extend(coords)
    return ocean, {'triangles':triangles, 'attribution':'© OpenStreetMap contributors, ODbL 1.0', 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}

def build(dem, source, output):
    manifest=json.loads((ROOT/'data/city/manifest.json').read_text())
    lo,hi=manifest['bounds']; spacing=6
    # Align to streaming tiles and retain a small terrain margin beyond the world.
    lo=[math.floor((v-192)/192)*192 for v in lo]; hi=[math.ceil((v+192)/192)*192 for v in hi]
    xs=np.arange(lo[0],hi[0]+spacing,spacing,dtype=float); zs=np.arange(lo[1],hi[1]+spacing,spacing,dtype=float)
    ocean, coast=coastline(source,box(*lo,*hi))
    transform=Transformer.from_crs('EPSG:4326','EPSG:25831',always_xy=True)
    with rasterio.open(dem) as ds:
        data=ds.read(1); inverse=~ds.transform
        nearest=distance_transform_edt(data < -100,return_distances=False,return_indices=True)
        filled=data[nearest[0],nearest[1]]
        del nearest
        grid=np.empty((len(zs),len(xs)),dtype='<f4'); estimated=np.zeros(grid.shape,dtype=bool); missing=0
        for row,z in enumerate(zs):
            lon=ORIGIN[0]+np.degrees(xs/(6378137*math.cos(math.radians(ORIGIN[1]))))
            lat=np.full_like(xs,ORIGIN[1]-math.degrees(z/6378137))
            east,north=transform.transform(lon,lat)
            cx,cz=inverse*(east,north); cx-=0.5;cz-=0.5
            ix=np.floor(cx).astype(int);iz=np.floor(cz).astype(int)
            if np.any(ix<0) or np.any(iz<0) or np.any(ix+1>=ds.width) or np.any(iz+1>=ds.height): raise ValueError('DEM does not cover output extent')
            u=cx-ix;v=cz-iz
            sea=contains_xy(ocean,xs,np.full_like(xs,z))
            corners=np.stack([data[iz,ix],data[iz,ix+1],data[iz+1,ix],data[iz+1,ix+1]])
            bad=np.any(corners < -100,axis=0)
            estimated[row]=bad & ~sea
            # Missing sea-level data along shore is filled only within 1000 m of the coastline.
            for i in np.flatnonzero(bad & ~sea):
                if ocean.distance(Point(xs[i],z))>1000: raise ValueError(f'Missing inland height at {xs[i]},{z}')
                missing+=1
            replacement=np.stack([filled[iz,ix],filled[iz,ix+1],filled[iz+1,ix],filled[iz+1,ix+1]])
            if np.any(np.any(replacement < -100,axis=0) & ~sea): raise ValueError("Unresolved coastal height gap")
            corners=np.where(corners < -100,np.maximum(0,replacement),corners)
            heights=(1-v)*((1-u)*corners[0]+u*corners[1])+v*((1-u)*corners[2]+u*corners[3])
            grid[row]=np.where(sea,-4,np.maximum(0,heights))
    output.mkdir(parents=True,exist_ok=True)
    (output/'heights.f32').write_bytes(grid.tobytes())
    (output/'estimated.bin').write_bytes(np.packbits(estimated,bitorder='little').tobytes())
    parks=[]
    for tile in (ROOT/'data/city/tiles').glob('*.json'):
        for park in json.loads(tile.read_text())['parks']:
            ring=park['ring']
            if len(ring)>=3: parks.append(({'type':'Polygon','coordinates':[ring+[ring[0]]]},1))
    mask=rasterize(parks,out_shape=grid.shape,transform=Affine(spacing,0,lo[0]-spacing/2,0,spacing,lo[1]-spacing/2),dtype='uint8')
    (output/'parks.bin').write_bytes(np.packbits(mask,bitorder='little').tobytes())
    (output/'coast.json').write_text(json.dumps(coast,separators=(',',':')))
    meta={'schema':1,'origin':lo,'columns':len(xs),'rows':len(zs),'spacing_m':spacing,'encoding':'little-endian float32, row-major, +X east / +Z south',
          'source':'ICGC MET5','source_resolution_m':5,'source_crs':'EPSG:25831','vertical_datum':'orthometric metres','retrieved_at':'2026-09-27','capture_date':'See ICGC product metadata; retrieval date is not survey date',
          'source_url':SOURCE_URL,'product_url':PRODUCT_URL,'attribution':'Institut Cartogràfic i Geològic de Catalunya (ICGC), CC BY 4.0',
          'license_url':'https://creativecommons.org/licenses/by/4.0/','source_sha256':hashlib.sha256(dem.read_bytes()).hexdigest(),
          'park_mask_source':'Current committed OSM city park polygons, rasterized at 6 m; boundary interpolation is approximate',
          'height_sha256':hashlib.sha256(grid.tobytes()).hexdigest(),'min_m':float(grid.min()),'max_m':float(grid.max()),'shore_nodata_filled':missing,
          'adaptations':'MET5 bilinearly resampled to a 6 m game grid; triangular interpolation at runtime. Coastal MET5 nodata within 1000 m of current OSM water uses nearest valid MET5 elevations before resampling; these coastal heights are approximate. OSM sea cells set to -4 m solely for rendering, not bathymetry. Road grades follow bare earth; bridge decks, tunnels, retaining walls and surveyed road crossfalls are not reconstructed. Terrain colors are illustrative.'}
    (output/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
    print('Terrain:',grid.shape, 'range',grid.min(),grid.max(),'shore fill',missing,flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--dem',type=pathlib.Path,default=ROOT/'data/source/barcelona-met5.tif');p.add_argument('--coast',type=pathlib.Path,default=ROOT/'data/source/barcelona-coast.osm.gz');p.add_argument('--output',type=pathlib.Path,default=ROOT/'data/terrain');a=p.parse_args();build(a.dem,a.coast,a.output)

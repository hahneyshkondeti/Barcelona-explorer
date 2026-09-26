"""Conservative footprint clearance against the rendered road corridors."""
import math
from import_map import contains


def closest(point, a, b):
    v=[b[i]-a[i] for i in range(2)]; d=sum(x*x for x in v)
    t=max(0,min(1,sum((point[i]-a[i])*v[i] for i in range(2))/d)) if d else 0
    return [a[i]+t*v[i] for i in range(2)]


def segments_cross(a,b,c,d):
    def cross(p,q,r): return (q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
    return cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0


def footprint(point, heading, shelter):
    # Includes pole, board and (when present) the roof/posts behind the pole.
    half=1.5 if shelter else .55; back=-2.05 if shelter else -.55
    s,c=math.sin(heading),math.cos(heading)
    return [[point[0]+c*x+s*z,point[1]-s*x+c*z] for x,z in [(-half,back),(half,back),(half,.55),(-half,.55)]]


def clear_of_roads(polygon, roads):
    edges=list(zip(polygon,polygon[1:]+polygon[:1]))
    for road in roads:
        a,b=road['a'],road['b']; clearance=road['width']/2+.35
        if contains(a,polygon) or contains(b,polygon): return False
        if any(segments_cross(a,b,c,d) for c,d in edges): return False
        distance=min([math.dist(p,closest(p,a,b)) for p in polygon]+[math.dist(p,closest(p,c,d)) for p in (a,b) for c,d in edges])
        if distance<clearance: return False
    return True


def clear_of_buildings(polygon, buildings):
    edges=list(zip(polygon,polygon[1:]+polygon[:1]))
    for rings in buildings:
        ring=rings[0]
        if any(contains(p,ring) and not any(contains(p,hole) for hole in rings[1:]) for p in polygon): return False
        if any(contains(p,polygon) for p in ring): return False
        if any(segments_cross(a,b,c,d) for a,b in edges for c,d in zip(ring,ring[1:]+ring[:1])): return False
    return True


def place_stop(point, roads, buildings, wants_shelter):
    candidates=[]
    for road in sorted(roads,key=lambda r:math.dist(point,closest(point,r['a'],r['b'])))[:6]:
        a,b=road['a'],road['b']; length=math.dist(a,b)
        if length<.1: continue
        forward=[(b[i]-a[i])/length for i in range(2)]; q=closest(point,a,b)
        original_heading=math.atan2(q[0]-point[0],q[1]-point[1])
        candidates.append((point[:],original_heading))
        for side in (-1,1):
            normal=[-forward[1]*side,forward[0]*side]
            # Don't move a stop to the opposite carriageway side when known.
            if math.dist(point,q)>.75 and sum((point[i]-q[i])*normal[i] for i in range(2))<0: continue
            heading=math.atan2(-normal[0],-normal[1])
            for extra in (0,1.5,3):
                for along in (0,-3,3,-6,6):
                    p=[q[i]+normal[i]*(road['width']/2+1.05+extra)+forward[i]*along for i in range(2)]
                    if math.dist(p,point)<=12: candidates.append((p,heading))
    if not roads: candidates=[(point[:],0.0)]
    candidates.sort(key=lambda item:math.dist(point,item[0]))
    # Minimal movement first; omit an unsafe shelter rather than move the stop
    # farther solely to accommodate an estimated shelter footprint.
    for p,heading in candidates:
        polygon=footprint(p,heading,False)
        if not clear_of_roads(polygon,roads) or not clear_of_buildings(polygon,buildings): continue
        roof=footprint(p,heading,True)
        shelter=wants_shelter and clear_of_roads(roof,roads) and clear_of_buildings(roof,buildings)
        return {'render_point':[round(v,3) for v in p],'heading':heading,'render_shelter':shelter,'render_visible':True,'placement':'mapped' if math.dist(p,point)<.01 else 'estimated_clear_sidewalk'}
    return {'render_point':point[:],'heading':0.0,'render_shelter':False,'render_visible':False,'placement':'no_clear_footprint_found'}

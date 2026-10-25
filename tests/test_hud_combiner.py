"""Physical combiner mask and binocular head movement regressions."""
from pathlib import Path
import runpy, math
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tests/test_display_startup.py'))['runtime']()
lua.execute('dofile(SCRIPT_ROOT.."HUD/page.lua")')
elements=[e for _,e in lua.globals().elements.items()]
mask=elements[0]
assert mask['collimated'] is False, 'Glass must stay on the cockpit when the head translates'
scale=lua.globals().GetScale()
# Match the native readVectorArray X/Z exchange and the unanchored 1 m origin.
vertices=[(v[3]*scale+1,v[2]*scale,v[1]*scale) for _,v in mask['vertices'].items()]
assert len(vertices)==77
assert max(abs(.9704832435*x+.2411687*y-.7475863212) for x,y,z in vertices)<1e-5
indices=[v for _,v in mask['indices'].items()]
def subtract(a,b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def intersects(origin,direction):
    for i in range(0,len(indices),3):
        a,b,c=(vertices[indices[i+j]] for j in range(3))
        e1,e2=subtract(b,a),subtract(c,a)
        p=cross(direction,e2); det=dot(e1,p)
        if abs(det)<1e-9: continue
        t=subtract(origin,a); u=dot(t,p)/det
        q=cross(t,e1); v=dot(direction,q)/det
        distance=dot(e2,q)/det
        if u>=0 and v>=0 and u+v<=1 and distance>0: return True
    return False
for eye in (-.032,.032):
    assert intersects((.247411,-.067882,eye),(1,-.10,0)), 'Central binocular ray misses physical glass'
    for lean in (-.22,.22):
        assert not intersects((.247411,-.067882,eye+lean),(1,-.10,0)), 'Off-glass symbols must be rejected'
print('Exact EDM combiner plane, both eyes, +/-22 cm head translations: OK')

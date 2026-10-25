"""Check the real material/font registration and requested heading graduations."""
from pathlib import Path
import runpy,xml.etree.ElementTree as ET,math
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tests/test_display_startup.py'))['runtime']()
lua.execute('assert(loadfile(SCRIPT_ROOT.."materials.lua"))()')
font=lua.globals().fonts['F22_HUD_OWN_STROKE']
assert font[1]['class']=='ceSLineFont'
assert [font[3][i] for i in range(1,5)]==[0,218,20,255]
assert [lua.globals().materials['F22_HUD_GREEN'][i] for i in range(1,5)]==[0,218,20,255]
xml=ET.parse(root/'Cockpit/Scripts/HUD/f22_hud_font_current.svg')
ids={e.get('id') for e in xml.iter()}
for _,char in font[1]['chars'].items(): assert char[2] in ids, char[2]
device=(root/'Cockpit/Scripts/device_init.lua').read_text()
assert device.index('.."materials.lua")')<device.index('indicators = {}')
lua.execute('dofile(SCRIPT_ROOT.."HUD/page.lua")')
elements={e['name']:e for _,e in lua.globals().elements.items()}
assert elements['F22_HUD_APERTURE']['material']=='F22_HUD_GREEN'
assert not any(n.startswith('HUD_ACCEL_') for n in elements)
for index in range(-4,7): assert 'HUD_HEADING_GRAD_'+str(index) in elements
# The latest reference requests about six visible ticks, replacing the
# rejected dense half-degree ruler. Check the visible window as it scrolls.
for offset in (0,.25,.75,2.5,4.9,5,7.5,9.99):
    active=0
    for index in range(-4,7):
        c=elements['HUD_HEADING_GRAD_'+str(index)]['controllers'][1]
        if c[3]<=offset<=c[4]:active+=1
    assert active==6,(offset,active)
scale=lua.globals().GetScale()
gain=elements['HUD_HDG_TAPE']['controllers'][1][3]
assert abs(gain+3.3*scale)<1e-9
assert 'FA-18' not in (root/'Cockpit/Scripts/materials.lua').read_text()
print('Own font resources, matching green, complete glyphs, compact six-tick heading: OK')

# The current-heading box is above the scale's numbered row. A centre label
# at fractional headings must have one visible instance, with no centre mask.
current=[e for e in elements.values() if e['element_params'] and e['element_params'][1]=='NAV']
centre=[e for e in elements.values() if e['element_params'] and e['element_params'][1]=='HUD_TICK_C00']
assert len(current)==1 and len(centre)==1
assert current[0]['init_pos'][2]>centre[0]['init_pos'][2]
assert centre[0]['parent_element']=='HUD_HEADING_LABEL_0'
assert not any(n.endswith(('_LEFT','_RIGHT')) and n.startswith('HUD_HEADING_LABEL_') for n in elements)
edge=elements['HUD_HEADING_LABEL_0']['controllers'][1]
for offset in (0,1,4,5,7,9.99): assert edge[3]<=offset<=edge[4]
print('Current heading above scale; centre labels remain visible through heading transitions: OK')

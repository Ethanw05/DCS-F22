"""Native LCD fonts have complete symbol storage and preserve real page bindings."""
from pathlib import Path
import xml.etree.ElementTree as ET
from test_display_startup import runtime
ROOT=Path(__file__).resolve().parents[1]
lua=runtime()
descriptor=lua.execute("return dofile(SCRIPT_ROOT..'MFD_COMMON/font.lua')")
assert descriptor['class']=='ceSLineFont' and descriptor['thickness']>=1.2
paths={p.get('id') for p in ET.parse(ROOT/'Cockpit/Scripts/MFD_COMMON/f22_lcd_font.svg').iter() if p.tag.endswith('path')}
chars={}
for _,v in descriptor['chars'].items():
    assert v[1] not in chars,('duplicate codepoint',v[1])
    assert v[2] in paths,('missing SVG storage',v[2])
    chars[v[1]]=v[2]
for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<>%=*().,:/+-':assert ord(c) in chars,c
for page in ['MFD_LEFT/bay_page.lua','MFD_LEFT/menu_page.lua','MFD_LEFT/hsi_page.lua',
             'MFD_RIGHT/rwr_page.lua','PMFD_CENTER/radar_page.lua','ICP/page_1.lua']:
    sim=runtime();sim.execute(f"dofile(SCRIPT_ROOT..'{page}')")
    text_count=0
    for _,e in sim.globals().elements.items():
        if e['kind'] not in ('ceStringSLine','ceStringPoly'):continue
        assert e['kind']=='ceStringSLine',(page,e['name'],'bitmap text still active')
        assert e['material'].startswith(('F22_LCD_FONT_','F22_AA_FONT_')),(page,e['material'])
        assert abs(e['stringdefs'][2]/e['stringdefs'][1]-.6)<1e-8,(page,'square/condensed character metrics')
        text_count+=1
    assert text_count>0,page
print('Native LCD typography: distinct stronger font, complete SVG/codepoint storage, MFD/UFC stroke elements and 0.60 aspect PASS')

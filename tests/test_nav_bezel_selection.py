"""NAV source highlights belong to the common calibrated bezel renderer."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
local ui=dofile(SCRIPT_ROOT..'Systems/MFD_Controller.lua').new(get_param_handle,function()end,function()end)
put('MAIN_POWER',1);ui:update(true)
for index,panel in ipairs({'LMFD','RMFD','CMFD','PMFD'})do
 ui:select(index,7)
 for source=0,2 do
  put('F22_NAV_SOURCE',source);ui:publish()
  for b=6,8 do
   assert(get('F22_MFD_'..panel..'_SEL_'..b)==(b==source+6 and 1 or 0),'NAV source highlight missing or on wrong bezel key')
  end
 end
end
''')
for panel in ('LMFD','RMFD','CMFD','PMFD'):
    lua=ns['runtime']();lua.globals().panel=panel
    lua.execute(r'''
    dofile(SCRIPT_ROOT..'MFD_COMMON/formats.lua')(panel)
    local labels,frames={},{}
    for _,e in ipairs(elements)do
     assert(not e.name:find('SOURCE_SELECTED_',1,true),'legacy detached NAV source box still drawn')
     for b=6,8 do
      if e.name=='F22_BEZEL_'..panel..'_'..b then labels[b]=e end
      if e.name=='F22_BEZEL_'..panel..'_SEL_'..b then frames[b]=e end
     end
    end
    for b=6,8 do
     assert(labels[b]and frames[b])
     assert(labels[b].init_pos[2]==frames[b].init_pos[2],'selection box uses a different button row')
     assert(labels[b].alignment=='RightCenter','NAV source label not anchored to the shared outside edge')
    end
    ''')
print('All four NAV pages: exclusive WYPT/TCN/ILS highlighting uses the same physical bezel anchors as its text; detached legacy box absent PASS')

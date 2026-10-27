"""Default TSD has no route ray; a labeled bezel toggles the real NAV owner."""
from radar_test_runtime import ns
lua=ns['runtime']()
lua.execute("""
local values={HUD_MODE=2,MAIN_POWER=1}
local function get(n)return values[n]or 0 end
local function param(n)return {get=function()return get(n)end,set=function(_,v)values[n]=v end}end
local situation=dofile(SCRIPT_ROOT..'Systems/Tactical_Situation.lua').new(get,function(n,v)values[n]=v end,{})
local sent={}
local function send(device,command,value)
 if device=='RWR_SYSTEM' then
  assert(command==10915);sent[#sent+1]=value
  if value>0 then situation:command(command);values.F22_TSD_NAV_LAYER=situation.nav and 1 or 0 end
 end
end
local routing=dofile(SCRIPT_ROOT..'Systems/Display_Routing.lua')
local m=dofile(SCRIPT_ROOT..'Systems/MFD_Controller.lua').new(param,send,function()end)
assert(situation.nav==false)
m:update(true)
for panel=1,4 do
 m:select(panel,routing.pages.tsd)
 local prefix='F22_MFD_'..routing.panels[panel]
 assert(values[prefix..'_KEY_9']=='NAV' and values[prefix..'_SEL_9']==0)
 m:button(panel,9,true);m:button(panel,9,true);m:button(panel,9,false)
 assert(situation.nav==true and values[prefix..'_SEL_9']==1)
 m:button(panel,9,true);m:button(panel,9,false)
 assert(situation.nav==false and values[prefix..'_SEL_9']==0)
end
assert(#sent==16,'held bezel repeated the NAV toggle')
""")
lua.execute("dofile(SCRIPT_ROOT..'PMFD_CENTER/radar_page.lua')")
elements=list(lua.globals().elements.values())
assert not any('SERVICE_QUEUE' in (e['name'] or '') for e in elements)
assert not any(e['element_params'] and 'F22_RADAR_SERVICE_PENDING' in list(e['element_params'].values()) for e in elements)
assert any('SERVICE_DEGRADED' in (e['name'] or '') for e in elements)
print('Radar declutter: NAV off by default, real owner toggle/selection on four panels, no queue debug display; degradation cue retained PASS')

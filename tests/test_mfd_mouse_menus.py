"""Mouse clicks honor the real clickable descriptors, including absent releases."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
package.preload.i_18n=function()return {translate=function(s)return s end}end
class_type={BTN=1,TUMB=2,LEV=3,SW=4}
dofile(SCRIPT_ROOT..'clickabledata.lua');local clickable=elements
function get_aircraft_property()return 1 end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize();local ec=SetCommand
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mc,mu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize();local pc,pu=SetCommand,update
local events={}
function dispatch_action(d,c,v)
 events[#events+1]={d=d,c=c,v=v}
 if d==devices.MFD_SYSTEM then mc(c,v)end
 if d==devices.EW_SYSTEM then ec(c,v)end
end
local function tick()mu();pu()end
local function edge(point,down)
 local e=assert(clickable[point]);local owner=e.device==devices.PMFD_SYSTEM and pc or mc
 if down then owner(e.action[1],e.device+.375)
 elseif e.use_release_message[1]then owner(e.stop_action[1],e.device+.25)end
 tick()
end
local function click(stem,b)
 local point=stem..b..'_PNT';edge(point,true);edge(point,false)
end
put('MAIN_POWER',1);put('HUD_MODE',7);tick()
local panels={{'PMFD','PMFD_'},{'LMFD','L_MFD_'},{'RMFD','R_MFD_'},{'CMFD','B_MFD_'}}
for _,panel in ipairs(panels)do
 local name,stem=panel[1],panel[2]
 -- The exact reported sequence: MENU -> DEF -> MENU. A fixture that
 -- invents mouse-up events would incorrectly pass the previous code.
 click(stem,13);assert(get('F22_'..name..'_FORMAT')==0,'first MENU failed on '..name)
 click(stem,4);assert(get('F22_'..name..'_FORMAT')==13,'DEF selection failed on '..name)
 click(stem,13);assert(get('F22_'..name..'_FORMAT')==0,'second physical MENU stayed latched on '..name)
 -- Return, all nine formats, and every subsequent MENU use the same button.
 for b,page in ipairs({1,7,6,13,11,8,9,10,12})do
  click(stem,b);assert(get('F22_'..name..'_FORMAT')==page)
  click(stem,13);assert(get('F22_'..name..'_FORMAT')==0,'MENU failed after '..page..' on '..name)
  click(stem,12);assert(get('F22_'..name..'_FORMAT')==page,'RTN failed on '..name)
  click(stem,13);assert(get('F22_'..name..'_FORMAT')==0)
 end
 click(stem,4)
 -- Unlabeled primary buttons are inert; setup needs its explicit entry.
 click(stem,11);click(stem,12)
 assert(get('F22_'..name..'_VIEW')==0 and get('F22_DEF_DETAIL_'..name)==0)
 assert(get('F22_MFD_'..name..'_KEY_11')==''and get('F22_MFD_'..name..'_KEY_12')=='')
 local selected=get('F22_CM_NORMAL_BANK')
 local edit_bank=get('F22_CM_PROGRAM_SELECTED')
 events={};click(stem,1);click(stem,1)
 local downs,ups=0,0
 for _,e in ipairs(events)do
  if e.d==devices.EW_SYSTEM and e.c==11105 then
   if e.v==1 then downs=downs+1 else ups=ups+1 end
  end
 end
 assert(downs==2 and ups==2,'countermeasure program button stayed latched on '..name)
 assert(get('F22_CM_NORMAL_BANK')==(selected-1+2)%3+1,'PROG did not change the normal dispense bank')
 assert(get('F22_CM_PROGRAM_SELECTED')==edit_bank,'normal selection changed the draft bank')
 click(stem,10)
 assert(get('F22_'..name..'_VIEW')==1 and get('F22_DEF_DETAIL_'..name)==1)
 assert(get('F22_MFD_'..name..'_KEY_12')=='RTN')
 local normal=get('F22_CM_NORMAL_BANK')
 click(stem,1)
 assert(get('F22_CM_PROGRAM_SELECTED')==edit_bank%3+1 and get('F22_CM_NORMAL_BANK')==normal)
 -- Visible setup edits reach the real EW owner.
 local p='F22_CM_PROGRAM_'
 local chaff,flare=get(p..'CHAFF'),get(p..'FLARE')
 local interval,reps=get(p..'INTERVAL'),get(p..'REPETITIONS')
 click(stem,2);assert(get(p..'CHAFF')==(chaff+1)%5)
 click(stem,3);assert(get(p..'FLARE')==(flare+1)%5)
 click(stem,4);assert(get(p..'INTERVAL')~=interval)
 click(stem,5);assert(get(p..'REPETITIONS')==reps%8+1)
 assert(get('F22_CM_DRAFT_DIRTY')==1)
 click(stem,8);assert(get('F22_CM_DRAFT_DIRTY')==0,'SAVE did not commit the draft')
 local bank='F22_CM_PROGRAM_'..get('F22_CM_PROGRAM_SELECTED')..'_'
 assert(get(bank..'CHAFF')==get(p..'CHAFF')and get(bank..'FLARE')==get(p..'FLARE'))
 click(stem,12)
 assert(get('F22_'..name..'_VIEW')==0 and get('F22_DEF_DETAIL_'..name)==0)
 for b=1,20 do
  local e=clickable[stem..b..'_PNT']
  assert(e.use_release_message[1]and e.stop_action[1]==e.action[1],'missing physical button release')
 end
end
''')
print('Real clickable descriptor path: repeated mouse MENU/RTN, DEF and all 4 x 9 formats, all 80 physical releases PASS')
print('Actual mouse -> MFD -> EW owner: independent normal selection, explicit setup edits/save and RTN on all four screens PASS')

for panel in ('LMFD','RMFD','CMFD','PMFD'):
    lua=ns['runtime']();lua.globals().panel=panel
    lua.execute(r'''
    local original=dofile;local detail_loaded=false
    function dofile(path)
     if path:find('defensive_detail.lua',1,true)then detail_loaded=true end
     return original(path)
    end
    dofile(SCRIPT_ROOT..'MFD_COMMON/formats.lua')(panel)
    assert(not detail_loaded,'retired DEF detail format still registered')
    local lookup={};for _,e in ipairs(elements)do lookup[e.name]=e end
    local root=assert(lookup['F22_COMMON_'..panel..'_DEF_OV__ROOT'])
    assert(#root.element_params==2,'common DEF power/format root changed')
    local readouts={}
    for _,e in ipairs(elements)do
     for _,p in ipairs(e.element_params or{})do
      if p:find('F22_CM_PROGRAM_',1,true)==1 then readouts[p]=true end
     end
    end
    for _,field in ipairs({'SELECTED','CHAFF','FLARE','INTERVAL','CYCLES'})do
     assert(readouts['F22_CM_PROGRAM_'..field],'DEF setup omitted program readback '..field)
    end
    ''')
print('All four common formats use the shared DEF factory with setup program readbacks PASS')

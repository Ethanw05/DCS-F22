"""Surface returns, terrain/jammer discrimination and pilot-only designation."""
from pathlib import Path
import contextlib
import io
import runpy
ROOT = Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime = runpy.run_path(str(ROOT / 'tests/test_display_startup.py'))['runtime']
lua = runtime()
lua.execute('''
local Model=dofile(SCRIPT_ROOT..'Systems/AG_Radar_Computer.lua')
local m=Model.new()
local terrain={GetHeight=function(n,e)return 50 end}
local pose={north=0,altitude=1000,east=0,heading=0,pitch=0,roll=0}
local raw={{north=18520,altitude=50,east=0,stamp=10,rcs=4},
 {north=18520,altitude=500,east=0,stamp=10,rcs=8}, -- airborne jammer world point
 {north=15000,altitude=50,east=1000,stamp=0,rcs=4}}
m:observe(raw,pose,terrain,10)
assert(#m.returns==1 and m.candidate and m.candidate.altitude==50)
m:observe(raw,pose,terrain,13)
assert(#m.returns==1 and m.candidate,'stationary map pixel expired before next sweep')
m:observe(raw,pose,terrain,19)
assert(#m.returns==0 and not m.candidate,'expired image remained designatable')
m:observe(raw,pose,nil,10);assert(#m.returns==0 and not m.candidate)
pose.heading=math.pi/2
m:observe(raw,pose,terrain,10);assert(#m.returns==0,'world return did not rotate with aircraft')
pose.heading=0
package.preload.terrain=function()return terrain end
local handles={}
local function get(n)return handles[n] or 0 end
local function put(n,v)handles[n]=v end
local commands={}
local system=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(get,put,function(c)commands[#commands+1]=c end)
system:command('rws',1,true,10)
put('F22_AG_RADAR_NATIVE_READY',1);put('F22_AG_RETURN_TIME',10);put('F22_AG_RETURN_COUNT',2)
for i,p in ipairs(raw)do
 local prefix='F22G_'..i..'_'
 for k,v in pairs({N=p.north,U=p.altitude,E=p.east,TIME=p.stamp,RCS=p.rcs})do put(prefix..k,v)end
end
put('F22N_RADAR_MODE',3)
system:update(pose,10,.05,true,true)
assert(commands[1]==509 and get('F22_RADAR_STT_VALID')==0)
assert(get('F22_RADAR_FC_ENABLE')==1 and get('F22_TWS_ACTIVE')==0 and get('F22_RADAR_SUPPORT_ENABLED')==0)
assert(get('F22_AG_RADAR_RETURN_COUNT')==1 and get('F22_AG_RADAR_CANDIDATE')==1)
system:command('designate',1,false);assert(get('F22_AG_DESIGNATION_VALID')==0)
system:command('designate',1,true,10)
assert(get('F22_AG_DESIGNATION_VALID')==1 and get('F22_AG_DESIGNATION_SEQUENCE')==1)
assert(get('F22_AG_DESIGNATION_NORTH')==18550 and get('F22_AG_DESIGNATION_ALTITUDE')==50)
system:command('interrogate',1,true);assert(get('F22_AG_DESIGNATION_SEQUENCE')==1)
system:command('undesignate',1,true);assert(get('F22_AG_DESIGNATION_VALID')==0 and get('F22_AG_DESIGNATION_SEQUENCE')==2)
system:command('designate',1,true,13)
assert(get('F22_AG_DESIGNATION_SEQUENCE')==2,'stopped MAP owner was designatable')
system:update(pose,13.05,.05,false,true)
assert(get('F22_AG_MAP_1_VALID')==0 and get('F22_AG_RADAR_OPERATING')==0)
system:command('range_down',1,true);system:command('range_down',1,true);system:command('range_down',1,true)
assert(system.model.range_nm==5)
system:command('range_up',1,true);system:command('range_up',1,true);system:command('range_up',1,true)
system:command('range_up',1,true);assert(system.model.range_nm==80)
m.slew_x=1;m.slew_y=1;m:slew(10)
local cursor=m:point(pose,terrain);local x,y=m:project(cursor,pose)
assert(math.abs(x)<=.80001 and y<=.76,'cursor escaped visible surface map')
''')
ui = runtime()
ui.execute('''
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mfd_command=SetCommand
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize()
function dispatch_action(d,c,v)
 if d==devices.MFD_SYSTEM then mfd_command(c,v)else actions[#actions+1]={c,v,d}end
end
get_param_handle('MAIN_POWER'):set(1);get_param_handle('HUD_MODE'):set(7)
get_param_handle('F22_AG_GAIN_INDEX'):set(1);get_param_handle('F22_AG_RANGE_AVAILABLE'):set(1)
get_param_handle('F22_AG_OPTIONS_AVAILABLE'):set(1);get_param_handle('F22_AG_EXP1_AVAILABLE'):set(1)
for _,row in ipairs({{10131,10601},{10132,10602},{10133,10646},{10134,10647},{10135,10648},
 {device_commands.Button_1,10601},{device_commands.Button_2,10602},{device_commands.Button_3,10646},
 {device_commands.Button_4,10647},{device_commands.Button_5,10648}})do
 actions={};SetCommand(row[1],1);SetCommand(row[1],0)
 assert(actions[1][1]==10742 and actions[1][2]==2,'A/G bezel did not select primary focus')
 assert(#actions==3 and actions[2][1]==row[2] and actions[2][2]==1 and actions[3][1]==row[2]
  and actions[3][2]==0,'A/G bezel must deliver one mode/EXP press and matching release')
 -- Radar has no weapon programming actions.
end
''')
print('A/G MAP: only native surface returns, reject airborne noise/stale batches, rotate world geometry, retain payload observer, explicit pilot designation/clear, power and range bounds PASS')

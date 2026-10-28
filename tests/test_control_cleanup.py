"""Actual profiles: aliases collapse, canonical identities and keyboard combos survive."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
for kind in ('joystick', 'keyboard'):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().folder=(ROOT/f'Input/F-22A/{kind}').as_posix()+'/'
    lua.globals().keyboard=kind=='keyboard'
    lua.execute('''
function _(s)return s end
iCommandPlaneTrimUp=95;iCommandPlaneTrimDown=96
iCommandPlaneFire=84;iCommandPlaneRadarOnOff=86
iCommandPlaneWheelBrakeLeftOn=961;iCommandPlaneSelecterHorizontalAbs=2033
local inherited={
 {pressed=95,up=215,combos={{key='POV_U'}}},
 {pressed=96,up=215},
 {down=84,up=85,combos={{key=keyboard and 'Space' or 'JOY_BTN1'}}},
 {down=86,combos={{key='I'}}},
 {down=961,up=962,combos={{key='A',reformers={'LCtrl'}}}},
}
function external_profile()return {keyCommands=inherited,axisCommands={
 {action=2001,combos={{key='JOY_Y'}}},{action=2033}}}end
function ignore_features()end
function join(t,items)for _,item in ipairs(items)do t[#t+1]=item end end
local profile=dofile(folder..'default.lua')
local commands={};local names={}
for _,b in ipairs(profile.keyCommands)do
 if b.down then commands[b.down]=b end
 if b.name then names[b.name]=(names[b.name]or 0)+1 end
end
for _,old in ipairs({84,86,961,10007,10008,10021,10022,10026,10151,10152,10153,10154,
 10600,10606,10607,10608,10609,10619,10842,11100,11101,11110,11130,11131,11132,11701})do
 assert(not commands[old],'obsolete visible command '..old)
end
for command=10700,10741 do
 local b=assert(commands[command],'canonical HOTAS missing '..command)
 assert(b.up==command and b.value_down==1 and b.value_up==0 and b.cockpit_device_id==16)
end
assert(names['Nosewheel Steering / Undesignate; Hold: Next Weapon Station']==1)
assert(names['Radar Range - Increase']==1 and names['Radar Range - Decrease']==1)
local trims=0
for _,b in ipairs(profile.keyCommands)do
 if b.down==95 or b.pressed==95 then trims=trims+1;assert(b.pressed==95 and b.up==215)end
end
assert(trims==1,'duplicate or changed trim hat descriptor')
local function has(command,key)
 for _,combo in ipairs(commands[command].combos or {})do if combo.key==key then return true end end
 return false
end
assert(has(10717,'Space')==keyboard,'keyboard shortcut lost / inherited joystick fire installed')
assert(has(10725,'I')==keyboard)
assert(has(10056,'A')==keyboard)
assert(profile.axisCommands[1].action==2001 and profile.axisCommands[1].combos[1].key=='JOY_Y')
for _,b in ipairs(profile.axisCommands)do assert(b.action~=2033)end
-- Reapplying normalization is harmless and never duplicates default combos.
local count=#profile.keyCommands
dofile(folder..'../control_cleanup.lua')(profile,getfenv(1),keyboard)
assert(#profile.keyCommands==count)
''')
print('Canonical HOTAS/release IDs, one NWS entry, trim repeat, keyboard shortcuts, axes and idempotence PASS')

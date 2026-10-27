"""Editable manual programs captured at trigger time, with actual inventory gates."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local P=dofile(SCRIPT_ROOT..'Systems/EW_Programs.lua')
local programs=P.new();local values={}
local function put(k,v)values[k]=v end
local function get(k)return values[k]or 0 end
programs:publish(put)
local captured=P.read(get,1)
assert(captured.chaff==1 and captured.flare==1 and captured.repetitions==4)
programs:command(10911);programs:command(10913);programs:command(10914);programs:publish(put)
assert(captured.chaff==1 and captured.interval==.25,'editing mutated a running program')
local edited=P.read(get,1)
assert(edited.chaff==2 and edited.interval==.5 and edited.repetitions==5)
values.F22_CM_PROGRAM_1_INTERVAL=0/0;assert(not P.read(get,1))
values.F22_CM_PROGRAM_1_INTERVAL=.5;values.F22_CM_PROGRAM_1_CHAFF=0
values.F22_CM_PROGRAM_1_FLARE=0;assert(not P.read(get,1),'empty program dispenses')

-- Actual EW owner accepts one edit per physical press; power inhibits edits.
get_param_handle('MAIN_POWER'):set(1)
function GetDevice()return {drop_chaff=function()end,drop_flare=function()end,
 get_chaff_count=function()return 8 end,get_flare_count=function()return 8 end,
 get_ECM_status=function()return false end,set_ECM_status=function()end}end
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize()
SetCommand(10911,1);SetCommand(10911,1);SetCommand(10911,0)
assert(get_param_handle('F22_CM_PROGRAM_1_CHAFF'):get()==2)
get_param_handle('MAIN_POWER'):set(0);SetCommand(10911,1);SetCommand(10911,0)
assert(get_param_handle('F22_CM_PROGRAM_1_CHAFF'):get()==2)
-- Actual Combat owner snapshots the program, clips to inventory and completes
-- only its scheduled requests. Mid-program edits must not change the sequence.
get_param_handle('MAIN_POWER'):set(1)
local chaff,flare,calls=7,5,0
function GetDevice()return {
 get_chaff_count=function()return chaff end,get_flare_count=function()return flare end,
 drop_chaff=function(self,n)assert(n>0 and n<=chaff);chaff=chaff-n;calls=calls+1 end,
 drop_flare=function(self,n)assert(n>0 and n<=flare);flare=flare-n;calls=calls+1 end}end
dofile(SCRIPT_ROOT..'Systems/Combat_System.lua');post_initialize()
SetCommand(10708,1);SetCommand(10708,0);update()
get_param_handle('F22_CM_PROGRAM_1_CHAFF'):set(4)
get_param_handle('F22_CM_PROGRAM_1_INTERVAL'):set(.1)
for i=1,60 do update()end
assert(chaff==0 and flare==1,'program edited mid-flight or ignored actual cartridge count')
assert(get_param_handle('F22_CM_PROGRAM_RUNNING'):get()==0)
flare=0;local before=calls
SetCommand(10708,1);SetCommand(10708,0);update()
assert(calls==before and get_param_handle('F22_CM_BURSTS_REMAINING'):get()==0,'empty inventory keeps dispensing')
''')
print('EW programs: bounded settings, immutable capture, empty/invalid rejection, press edge and power gates PASS')

"""Request transport and coherent supply authority without a second Lua owner."""
from cockpit_fixture import runtime, power_frame

sim = runtime()
sim.execute('''
local Adapter = dofile(SCRIPT_ROOT..'Systems/Vehicle_Power_Adapter.lua')
adapter = Adapter.new()
assert(not adapter:update(1,1,0,1))
assert(not adapter.valid and adapter.apu_power == nil)
assert(handles.F22_POWER_REQUEST_VALID:get()==1)
assert(handles.F22_POWER_REQUEST_SEQUENCE:get()==1)
assert(handles.F22_BATTERY_REQUEST:get()==1 and handles.F22_R_GEN_REQUEST:get()==0)
-- Provider arrival must not reset an already selected bleed/ECS request.
handles.F22_L_BLEED_REQUEST:set(0)
handles.F22_ECS_REQUEST:set(0)
''')
power_frame(sim, battery=1, main=1, left=0, right=1, apu=1, spool=4)
sim.execute('''
assert(adapter:update(1,0,1,1) and adapter.valid)
assert(adapter.apu_power==1 and adapter.apu_rpm==4 and adapter.main==1)
assert(adapter.left_generator==0 and adapter.right_generator==1)
assert(handles.F22_L_BLEED_REQUEST:get()==0 and handles.F22_ECS_REQUEST:get()==0)
local function invalidate(key,value)
    local h=get_param_handle(key); local old=h:get(); h:set(value)
    assert(not adapter:update(0,0,0,0) and not adapter.valid, key)
    assert(adapter.apu_rpm==nil and adapter.apu_power==nil and adapter.main==nil)
    assert(not adapter.auto_shutdown)
    assert(handles.F22_BATTERY_REQUEST:get()==0)
    h:set(old)
    assert(adapter:update(1,0,1,1))
end
invalidate('EFM_POWER_OWNER',0)
invalidate('EFM_PHYSICAL_VALID',0)
invalidate('EFM_PHYSICAL_GENERATION',0)
invalidate('EFM_PHYSICAL_GENERATION',1.5)
invalidate('EFM_PHYSICAL_CLOCK_KIND',2)
invalidate('EFM_PHYSICAL_STAMP',9)
invalidate('EFM_PHYSICAL_STAMP',10.1)
invalidate('F22_ELECTRICAL_VALID',0)
invalidate('MAIN_POWER',.5)
invalidate('APU_RPM_STATE',0/0)
invalidate('APU_RPM_STATE',4.1)
invalidate('EFM_APU_AUTO_SHUTDOWN',2)
adapter.sequence=16777215
adapter:update(1,0,1,1)
assert(handles.F22_POWER_REQUEST_SEQUENCE:get()==1)
-- A changing envelope cannot be admitted as a completed sample.
local h=handles.EFM_PHYSICAL_STAMP; local original=h.get; local reads=0
h.get=function(self) reads=reads+1; return reads==1 and 10 or 10.01 end
assert(not adapter:update(1,0,1,1))
h.get=original
''')
power_frame(sim, battery=0, main=0, generation=2, stamp=0)
sim.execute('assert(adapter:update(0,0,0,0) and adapter.main==0)')

# The cockpit device must never integrate or overwrite physical supply, even
# before the native owner starts or after its publication is withdrawn.
sim = runtime()
sim.execute('''
for _,name in ipairs({'APU_POWER','APU_RPM_STATE','L_GEN_POWER','R_GEN_POWER',
    'MAIN_POWER','BATTERY_POWER','F22_BATTERY_SOC','F22_DC_VOLTS',
    'F22_ESSENTIAL_POWER','F22_ELECTRICAL_VALID'}) do
    local h=get_param_handle(name)
    h.set=function() error('Lua wrote physical supply '..name) end
end
dofile(SCRIPT_ROOT..'Systems/Engine_System.lua'); post_initialize()
for index=1,5000 do update() end
assert(handles.F22_BATTERY_REQUEST:get()==1)
assert(handles.MAIN_POWER:get()==0 and handles.F22_ELECTRICAL_VALID:get()==0)
SetCommand(10019,1); SetCommand(10019,1); update()
assert(handles.F22_PARK_REQUEST:get()==1)
SetCommand(10019,0); update()
assert(handles.F22_PARK_REQUEST:get()==0)
''')
print('Power requests independent of provider; coherent readback, invalidation and no Lua supply writes PASS')

sim = runtime()
sim.execute('''
audio={}; physical_draw_writes={}
function set_aircraft_draw_argument_value(key,value)
    if key==610 or key==611 then physical_draw_writes[#physical_draw_writes+1]=key end
end
function create_sound_host()
    return {create_sound=function(_,name)
        local sound={once=0,loops=0,stops=0,playing=false}
        function sound:is_playing() return self.playing end
        function sound:play_once() self.once=self.once+1; self.playing=true end
        function sound:play_continue() self.loops=self.loops+1; self.playing=true end
        function sound:stop() self.stops=self.stops+1; self.playing=false end
        audio[name]=sound
        return sound
    end}
end
LockOn_Options.init_conditions.birth_place='GROUND_COLD'
dofile(SCRIPT_ROOT..'Systems/Engine_System.lua'); post_initialize()
assert(#physical_draw_writes==0)
SetCommand(device_commands.Button_1,1)
draws[701]=1 -- deliberately stale drawing: commands own selection
SetCommand(10025,0); update()
assert(handles.F22_APU_REQUEST:get()==0, 'orphan release selected APU START')
SetCommand(10025,1); SetCommand(10025,1); SetCommand(10025,0); update()
assert(handles.F22_APU_REQUEST:get()==1, 'spring release cancelled START')
SetCommand(device_commands.Button_2,-1); SetCommand(10025,0); update()
assert(handles.F22_APU_REQUEST:get()==0, 'late neutral release restarted the APU')
SetCommand(device_commands.Button_2,1)
start_sound=audio['Aircrafts/F-22A/External/apu_start']
run_sound=audio['Aircrafts/F-22A/External/apu_run']
end_sound=audio['Aircrafts/F-22A/External/apu_stop']
''')
power_frame(sim, battery=1, main=0)
sim.execute('''
update()
assert(handles.F22_APU_REQUEST:get()==1)
assert(start_sound.once==0 and run_sound.loops==0, 'request alone played actual APU rotation')
handles.APU_RPM_STATE:set(.2); update()
assert(start_sound.once==1)
for index=1,600 do
    local time=handles.F22_AP_CLOCK:get()+.024
    handles.F22_AP_CLOCK:set(time); handles.EFM_PHYSICAL_STAMP:set(time)
    update()
end
assert(start_sound.once==1 and run_sound.loops>0)
handles.APU_RPM_STATE:set(4); handles.APU_POWER:set(1)
handles.EFM_APU_AUTO_SHUTDOWN:set(1); update()
update()
assert(handles.F22_APU_REQUEST:get()==0 and end_sound.once==0, 'request cut short spin-down audio')
handles.APU_RPM_STATE:set(0); handles.APU_POWER:set(0); update(); update()
assert(end_sound.once==1)
handles.APU_RPM_STATE:set(4); handles.APU_POWER:set(1); update()
assert(start_sound.once==1, 'already running APU replayed its start clip')
handles.EFM_POWER_OWNER:set(0); update()
assert(not run_sound.playing and end_sound.once==1, 'unknown state fabricated shutdown')
''')
power_frame(sim, battery=1, main=1, apu=1, spool=4, generation=2, stamp=0)
sim.execute('''
update()
assert(run_sound.playing and start_sound.once==1 and end_sound.once==1)
''')
print('Recorded APU audio follows qualified achieved rotation, spin-down and unavailable/recovery states PASS')

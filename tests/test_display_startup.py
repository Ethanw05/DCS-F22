"""Regression checks for the actual cockpit failures reported in dcs.log.

Uses write-only element proxies and reentrant clickable callbacks, rather than
ordinary Lua element tables that hide DCS property and recursion errors.
Optical alignment and native avionics still require in-game verification.
"""
from pathlib import Path
import re
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'Cockpit/Scripts'

def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().SCRIPT_ROOT = SCRIPTS.as_posix() + '/'
    lua.execute('''
        LockOn_Options = {script_path=SCRIPT_ROOT, common_script_path='common/',
            init_conditions={birth_place='GROUND_HOT'}}
        local original_dofile = dofile
        function dofile(path)
            if path == 'common/elements_defs.lua' then
                h_clip_relations={COMPARE=1, REWRITE_LEVEL=2, INCREASE_IF_LEVEL=4, DECREASE_IF_LEVEL=6}
                blend_mode={IBM_NO_WRITECOLOR=0}
                FOV=1; MILLYRADIANS=2; METERS=3
            elseif path == 'common/devices_defs.lua' then
                indicator_types={COMMON=0, COLLIMATOR=1}
                render_purpose={GENERAL=0, HUD_ONLY_VIEW=1}
            elseif string.find(path,'common/',1,true)==1 then
                return
            elseif path == SCRIPT_ROOT..'Systems/Radar_System.lua' then
                -- Explicit simulator inputs for workflow replays. Fault-owner
                -- cases opt out and publish their own current physical envelope.
                if TEST_RADAR_PHYSICAL_AUTO ~= false then
                    test_radar_physical=original_dofile(SCRIPT_ROOT..'../../tests/radar_physical_fixture.lua')()
                end
                local result=original_dofile(path)
                local actual=update
                function update(...)
                    if test_radar_physical then test_radar_physical:advance() end
                    return actual(...)
                end
                return result
            elseif path == SCRIPT_ROOT..'fonts.lua' then
                UFD_GRN='test-font';UFD_TEAL='test-cyan-font'
                UFD_YEL='test-yellow-font';UFD_RED='test-red-font';UFD_FONT='test-white-font';UFD_RADAR_BLUE='test-blue-font'
                UFD_RADAR_GREEN='test-green-font';UFD_RADAR_MAGENTA='test-magenta-font'
                UFD_RADAR_YELLOW='test-yellow-font';UFD_RADAR_RED='test-red-font'
            elseif path == SCRIPT_ROOT..'materials.lua' then
                return
            else
                return original_dofile(path)
            end
        end
        function MakeMaterial(...) return 'test-material' end
        function MakeFont(...) return 'test-font' end
        function SetScale(value) assert(value); selected_scale=value end
        function GetScale() return selected_scale==MILLYRADIANS and 0.00055 or 1 end
        elements={}
        element_data=setmetatable({}, {__mode='k'})
        function CreateElement(kind)
            local object={}
            local data={kind=kind}
            element_data[object]=data
            return setmetatable(object,{
                __newindex=function(_,key,value) data[key]=value end,
                __index=function() return '<native property>' end,
            })
        end
        function Add(object) table.insert(elements,element_data[object]) end
        handles={}; actions={}; draws={}; click_depth=0
        function get_param_handle(name)
            if not handles[name] then
                local p={value=0}
                function p:get() return self.value end
                function p:set(value) self.value=value end
                handles[name]=p
            end
            return handles[name]
        end
        -- The default fixture has the qualified owned avLua clock adapter.
        -- Missing/incompatible adapter behavior is exercised explicitly.
        get_param_handle('F22_AESA_DRIVER_READY'):set(1)
        function dispatch_action(_,command,value)
            table.insert(actions,{command,value})
        end
        function make_default_activity(_) end
        function get_base_data()
            return setmetatable({getSelfCoordinates=function() return 0,0,0 end}, {__index=function() return function() return 0 end end})
        end
        function get_cockpit_draw_argument_value(n) return draws[n] or 0 end
        function get_aircraft_draw_argument_value(_) return 0 end
        function get_aircraft_property(_) return 0 end
        function set_aircraft_draw_argument_value(...) end
        function get_clickable_element_reference(_) return nil end
        function print_message_to_user(...) end
        function create_sound_host(...)
            return {create_sound=function(...)
                return {is_playing=function() return false end,
                    play_once=function() end,play_continue=function() end,update=function() end,stop=function() end}
            end}
        end
        dev={listen_command=function() end, listen_event=function() end}
        function dev:performClickableAction(command,value,...)
            click_depth=click_depth+1
            assert(click_depth<12, 'recursive clickable callback')
            SetCommand(command,value)
            click_depth=click_depth-1
        end
        function GetSelf() return dev end
        function mount_vfs_texture_archives(...) end
    ''')
    return lua

for page in ('HUD/page.lua', 'PMFD_CENTER/radar_page.lua'):
    lua = runtime()
    lua.execute(f'dofile(SCRIPT_ROOT.."{page}")')
    lua.execute('''
        assert(#elements>20)
        for _,e in ipairs(elements) do
            assert(e.name and e.h_clip_relation)
            if e.element_params then assert(type(e.element_params)=='table') end
            if e.controllers then assert(type(e.controllers)=='table') end
            if e.kind=='ceMeshPoly' then assert(e.material) end
        end
    ''')
    print('DCS-style element construction:', page, 'OK')
    if page == 'HUD/page.lua':
        lua.execute('''
            for _,e in ipairs(elements) do
                if e.stringdefs then
                    assert(selected_scale==MILLYRADIANS, 'HUD must use explicit angular units')
                    assert(e.stringdefs[1] <= 0.015, 'font metrics must not receive vertex mrad multiplier')
                    assert(math.abs(e.init_pos[1]) <= 230)
                    if not string.find(e.parent_element or '', 'HUD_PITCH_STEP_',1,true) then
                        assert(math.abs(e.init_pos[2]) <= 230)
                    end
                end
                assert(e.level==8 or (e.level==9 and string.find(e.name,'HUD_HORIZON_REFERENCE_',1,true)==1))
            end
            assert(elements[1].name=='F22_HUD_APERTURE')
            assert(elements[1].isvisible==false)
            assert(elements[1].blend_mode==blend_mode.IBM_NO_WRITECOLOR)
        ''')

lua = runtime()
lua.execute('''
    dofile(SCRIPT_ROOT..'Systems/Avionics.lua')
    draws[704]=1; draws[705]=1
    handles.MAIN_POWER:set(1); handles.BATTERY_POWER:set(1)
    post_initialize()
    for i=1,20 do update() end
    for _,action in ipairs(actions) do
        assert(action[1]~=747 and action[1]~=156, 'legacy HUD workaround remains')
    end
    assert(handles.HUD_POWER:get()==1)
    assert(handles.MFD_OPACITY:get()==1)
''')
entry = (ROOT/'entry.lua').read_text()
assert 'MAC_flyable(' not in entry
assert not re.search(r'\bold\s*=\s*6', entry)
assert "make_flyable('F-22A'" in entry
print('Own HUD registration, no inherited cockpit and no dimming workaround OK')

lua = runtime()
lua.execute('dofile(SCRIPT_ROOT.."Systems/Electrical_System.lua"); post_initialize()')
lua.execute('''
    assert(handles.AAR:get()==0 and #actions==0)
    SetCommand(10015,1)
    assert(handles.AAR:get()==1 and #actions==1)
    SetCommand(10016,1)
    assert(handles.AAR:get()==0 and #actions==2)
    SetCommand(device_commands.Button_2,0.75)
    assert(handles.AAR_KNOB:get()==0.75)
    SetCommand(device_commands.Button_7,0.5)
    assert(handles.FORM_KNOB:get()==0.5)
''')
print('Electrical startup and reentrant click/axis handling OK')

for birth in ('GROUND_HOT', 'AIR_HOT', 'GROUND_COLD'):
    lua = runtime()
    lua.globals().LockOn_Options.init_conditions.birth_place = birth
    lua.execute('dofile(SCRIPT_ROOT.."Systems/Engine_System.lua"); post_initialize()')
    lua.execute('''
        for _,action in ipairs(actions) do
            assert(action[1]~=Keys.PowerOnOff, 'startup toggled native power')
        end
    ''')
    print('Native power initialization:', birth, 'OK')

# Exercise request transport and the current physical-provider -> avionics
# path. Native Power/DLL cases own energy and generator integration; this
# fixture declares achieved supply rather than recreating it in Lua.
from cockpit_fixture import power_frame
for birth in ('GROUND_HOT', 'AIR_HOT', 'GROUND_COLD'):
    for callbacks in (True, False):
        lua = runtime()
        lua.globals().LockOn_Options.init_conditions.birth_place = birth
        if not callbacks:
            lua.execute('function dev:performClickableAction(...) end')
        lua.execute('''
            dofile(SCRIPT_ROOT..'Systems/Engine_System.lua')
            post_initialize()
            engine_update=update; engine_command=SetCommand
            get_param_handle('EFM_ENGINE_VALID'):set(1)
            get_param_handle('EFM_ENGINE_LEFT_RPM_PCT'):set(67)
            get_param_handle('EFM_ENGINE_RIGHT_RPM_PCT'):set(67)
        ''')
        hot = birth != 'GROUND_COLD'
        power_frame(lua, battery=int(hot), main=int(hot), left=int(hot), right=int(hot))
        lua.execute('''
            engine_update()
            assert(handles.F22_POWER_REQUEST_VALID:get()==1)
            assert(handles.F22_BATTERY_REQUEST:get()==handles.BATTERY_POWER:get())
            dofile(SCRIPT_ROOT..'Systems/Avionics.lua')
            post_initialize()
            update()
        ''')
        hot = birth != 'GROUND_COLD'
        for name in ('MAIN_POWER', 'BATTERY_POWER', 'HUD_POWER', 'MFD_OPACITY', 'UFD_OPACITY'):
            assert lua.globals().handles[name].value == int(hot), (birth, callbacks, name)
        if hot:
            lua.execute('''
                -- All generators offline: displays must really lose power.
                handles.L_GEN_POWER:set(0); handles.R_GEN_POWER:set(0)
                handles.MAIN_POWER:set(0)
                engine_update(); update()
                assert(handles.MAIN_POWER:get()==0 and handles.HUD_POWER:get()==0)
                assert(handles.MFD_OPACITY:get()==0)
                -- Either engine can power the bus.
                handles.R_GEN_POWER:set(1); handles.MAIN_POWER:set(1)
                engine_update(); update()
                assert(handles.HUD_POWER:get()==1 and handles.MFD_OPACITY:get()==1)
                SetCommand(device_commands.Button_3,0)
                SetCommand(device_commands.Button_4,0)
                update()
                assert(handles.MFD_OPACITY:get()==0 and handles.UFD_OPACITY:get()==0)
                SetCommand(device_commands.Button_3,0.4)
                SetCommand(device_commands.Button_4,0.6)
                update()
                assert(handles.MFD_OPACITY:get()==0.4 and handles.UFD_OPACITY:get()==0.6)
                -- An absolute ON event must never toggle an already ON switch.
                engine_command(device_commands.Button_1,1)
                engine_command(device_commands.Button_1,1)
                engine_update(); update()
                assert(handles.BATTERY_POWER:get()==1)
                engine_command(device_commands.Button_1,0)
                engine_update(); update()
                assert(handles.F22_BATTERY_REQUEST:get()==0)
                assert(handles.BATTERY_POWER:get()==1, 'request overwrote achieved supply')
                handles.BATTERY_POWER:set(0)
                engine_update(); update()
                assert(handles.HUD_POWER:get()==0 and handles.MFD_OPACITY:get()==0)
            ''')
        print('Real electrical startup / display chain:', birth, 'callbacks=', callbacks, 'OK')

lua = runtime()
lua.execute('dofile(SCRIPT_ROOT.."device_init.lua")')
model = (ROOT/'Cockpit/Shape/Cockpit_F-22A.EDM').read_bytes()
for index in range(1, len(lua.globals().indicators) + 1):
    indicator = lua.globals().indicators[index]
    geometry = indicator[4]
    if geometry and geometry[1]:
        for _, anchor in geometry[1].items():
            assert isinstance(anchor, str) and anchor.encode() in model, anchor
assert lua.globals().indicators[1][4][2]['sw'] > 0
print('Indicator connector names exist in shipped EDM; HUD uses explicit geometry OK')

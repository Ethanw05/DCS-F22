"""Coherent physical indication data and native write-only rendering contracts."""
from pathlib import Path
from cockpit_fixture import runtime, engine_frame

ROOT = Path(__file__).resolve().parents[1]
ns = {'runtime': runtime}
lua = runtime()
left = dict(rpm=78, temperature=650, oil=0, nozzle=12, flow=.5, hydraulic=39)
right = dict(rpm=82, temperature=855, oil=210, nozzle=87, flow=1, hydraulic=3950)
lua.execute("reader=dofile(SCRIPT_ROOT..'Systems/Engine_Data.lua').new(get_param_handle)")
engine_frame(lua, left=left, right=right)
lua.execute("""
reader:update()
assert(reader.left.rpm==78 and reader.right.rpm==82)
assert(reader.left.temperature==650 and reader.right.temperature==855)
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
for _,test in ipairs({{'EFM_POWER_OWNER',0},{'EFM_PHYSICAL_VALID',0},
 {'EFM_PHYSICAL_GENERATION',0},{'EFM_PHYSICAL_GENERATION',1.5},
 {'EFM_PHYSICAL_CLOCK_KIND',2},{'EFM_PHYSICAL_STAMP',9},
 {'EFM_PHYSICAL_STAMP',10.1},{'EFM_ENGINE_INDICATION_SCHEMA',0},
 {'EFM_ENGINE_INDICATION_SCHEMA',2},{'EFM_ENGINE_VALID',0},{'EFM_VEHICLE_VALID',0}}) do
    local previous=get(test[1]); put(test[1],test[2]); reader:update()
    assert(reader.left.rpm==nil and reader.right.rpm==nil, test[1])
    put(test[1],previous); reader:update()
    assert(reader.left.rpm==78 and reader.right.rpm==82)
end
local stamp=get_param_handle('EFM_PHYSICAL_STAMP'); local original=stamp.get; local reads=0
stamp.get=function(self) reads=reads+1; return reads==1 and 10 or 10.01 end
reader:update(); assert(reader.left.rpm==nil, 'torn engine frame admitted')
stamp.get=original

dofile(SCRIPT_ROOT..'Systems/Avionics.lua'); post_initialize(); update()
avionics_update=update
assert(get('L_HYD_VALUE')==39 and get('R_HYD_VALUE')==3950)
assert(get('L_HYD_COLOR')==1 and get('R_HYD_COLOR')==0)
assert(get('OIL_L')==0 and get('OIL_R')==210)
assert(get('L_OIL_COLOR')==1 and get('R_OIL_COLOR')==0)
assert(get('L_NOZZLE_POS')==12 and get('R_NOZZLE_POS')==87)
assert(get('L_EGT_COLOR')==0 and get('R_EGT_COLOR')==1)
assert(get('OIL_L')==0 and get('F22_ENGINE_L_OIL_VALID')==1, 'physical zero was hidden as unavailable')
put('EFM_ENGINE_LEFT_TEMP_C',0/0); avionics_update()
assert(get('F22_ENGINE_L_EGT_VALID')==0)
assert(get('F22_ENGINE_R_EGT_VALID')==1)
put('EFM_HYD_LEFT_PSI',0/0); put('EFM_HYD_RIGHT_PSI',5000)
put('EFM_ENGINE_LEFT_NOZZLE_PCT',-20); put('EFM_ENGINE_RIGHT_NOZZLE_PCT',120)
avionics_update()
assert(get('F22_ENGINE_L_HYD_VALID')==0 and get('F22_ENGINE_R_HYD_VALID')==0)
assert(get('F22_ENGINE_L_NOZZLE_VALID')==0 and get('F22_ENGINE_R_NOZZLE_VALID')==0)
-- Drawing/refresh never repairs invalid data or reintegrates circuit pressure.
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua'); post_initialize()
for index=1,100 do update() end
assert(get('F22_ENGINE_L_HYD_VALID')==0 and get('F22_ENGINE_R_HYD_VALID')==0)
assert(get('EFM_ENGINE_LEFT_NOZZLE_PCT')==-20 and get('EFM_HYD_RIGHT_PSI')==5000)
""")
engine_frame(lua, left=left, right=right, generation=2, stamp=0)
lua.globals().avionics_update()
assert lua.globals().get_param_handle('EGT_L').value == 650
assert lua.globals().get_param_handle('F22_ENGINE_L_EGT_VALID').value == 1
print('Owned engine/circuit fields: finite/independent data, unavailable/schema/epoch/torn rejection and recovery PASS')

for panel in ('LEFT','RIGHT','CENTER'):
    lua=ns['runtime']()
    lua.execute(f"dofile(SCRIPT_ROOT..'MFD_{panel}/eng_page.lua')")
    lua.execute(r'''
    for _,gauge in ipairs({{'R_NEEDLE_OIL_R','OIL_R'},{'R_NEEDLE_OIL_G','OIL_R'},{'L_NEEDLE_OIL_L','OIL_L'},{'L_NEEDLE_OIL_G','OIL_L'}})do
     local element=element_data[_G[gauge[1]]];assert(element,'missing engine oil gauge')
     local rotation
     for _,controller in ipairs(element.controllers or {})do
      if controller[1]=='rotate_using_parameter'then
       assert(element.element_params[controller[2]+1]==gauge[2],'oil needle followed an unrelated engine channel')
       rotation=controller[3]*270
      end
     end
     assert(rotation and math.abs(rotation)>math.pi/2 and math.abs(rotation)<2*math.pi,'oil needle no longer has a useful PSI sweep')
    end
    ''')
print('Overhaul engine formats: all 12 oil needles use their corresponding physical PSI channel PASS')

lua = runtime()
lua.execute("dofile(SCRIPT_ROOT..'MFD_LEFT/eng_page.lua')")
lua.execute('''
local gated = 0
for _,element in ipairs(elements) do
    if element.kind=='ceTexPoly' then
        local valid_index
        for index,key in ipairs(element.element_params or {}) do
            if string.match(key,'^F22_ENGINE_[LR]_%u+_VALID$') then valid_index=index-1 end
        end
        if valid_index then
            local gate
            for _,controller in ipairs(element.controllers or {}) do
                if controller[1]=='parameter_in_range' and controller[2]==valid_index then gate=controller end
            end
            assert(gate and gate[3]>0 and gate[3]<=1 and gate[4]>=1)
            gated=gated+1
        end
    elseif string.find(element.kind,'ceString',1,true)==1 then
        for _,key in ipairs(element.element_params or {}) do
            if string.match(key,'^F22_ENGINE_[LR]_%u+_TEXT$') then
                error('retired mixed-type engine text parameter returned')
            end
        end
    end
end
assert(gated==36, 'engine rings/needles lost their field-specific availability gates')
''')
for panel in ('LEFT', 'RIGHT'):
    lua = runtime()
    lua.execute(f"dofile(SCRIPT_ROOT..'UFD_{panel}/base_page.lua')")
    lua.execute('''
    local count=0
    for _,element in ipairs(elements) do
        for _,key in ipairs(element.element_params or {}) do
            if string.match(key,'^F22_ENGINE_[LR]_[RE][PG][MT]_VALID$') and element.formats then
                assert(element.formats[1]=='%.0f'); count=count+1
            end
        end
    end
    assert(count==4)
    ''')
print('Native rendering: 36 independent gauge gates and eight UFD numeric/static-unavailable fields PASS')

lua = runtime()
lua.execute("dofile(SCRIPT_ROOT..'MFD_LEFT/fuel_page.lua')")
lua.execute('''
local count=0
for _,element in ipairs(elements) do
    for _,key in ipairs(element.element_params or {}) do
        if string.match(key,'^F22_ENGINE_[LR]_%u+_VALID$') and element.formats then
            assert(element.formats[1]:sub(-1)=='f'); count=count+1
        end
    end
end
assert(count==4, 'fuel format dropped a qualified fuel-flow/temperature field')
''')

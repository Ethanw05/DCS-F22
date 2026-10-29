-- GPL-3.0-or-later. Pod carriage/power/control owner; no world-object enumeration.
local dev=GetSelf()
dofile(LockOn_Options.script_path..'devices.lua')
local library=dofile(LockOn_Options.script_path..'Systems/IRST_Computer.lua')
local Snapshot=dofile(LockOn_Options.script_path..'Systems/IRST_Snapshot.lua')
local decode=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
local caps=dofile(LockOn_Options.script_path..'Systems/Store_Capabilities.lua')
local selected_profile=dofile(LockOn_Options.script_path..'Systems/Equipment_Profile.lua').supports('irst_pod')
local handles={}
local function h(name)
    if not handles[name] then handles[name]=get_param_handle(name)end
    return handles[name]
end
local function get(name)return h(name):get()end
local function put(name,value)h(name):set(value)end
local physical=dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua')
local supply={snapshot=physical.new(get,{'MAIN_POWER','F22_ELECTRICAL_VALID',
    'EFM_MISSION_POWER_AVAILABLE','EFM_PHYSICAL_WORLD_STAMP','EFM_PHYSICAL_WORLD_CLOCK_KIND'})}
local reader=Snapshot.new(get)
local computer=library.new()
local control_sequence,publish_sequence=0,0
local held,rows={},{}
local last_time,pod_check,present=-100,-100,false
local native_weapon
local last_log,last_status,last_reason=-100,nil,nil
local function diagnostic(now,status,ready)
    local reason=get('F22_IRST_NATIVE_REASON')
    if now-last_log<1 or status==last_status and reason==last_reason then return end
    last_log,last_status,last_reason=now,status,reason
    if log and log.write then
        log.write('F22_IRST',log.INFO,string.format('status=%d ready=%d pod=%d native=%d reason=%.0f contacts=%d',
            status,ready and 1 or 0,present and 1 or 0,get('F22_IRST_NATIVE_AVAILABLE'),reason,#computer.contacts))
    end
end
local function update_supply(now)
    local snapshot=supply.snapshot:update()
    local v=snapshot.values
    local stamp=v.EFM_PHYSICAL_WORLD_STAMP
    supply.valid=snapshot.valid and v.EFM_PHYSICAL_WORLD_CLOCK_KIND==2
        and Snapshot.finite(stamp) and stamp>=0 and now-stamp>=-.01 and now-stamp<=.25
        and v.F22_ELECTRICAL_VALID==1 and physical.boolean(v.MAIN_POWER)
        and physical.boolean(v.EFM_MISSION_POWER_AVAILABLE)
    supply.mission_valid=supply.valid
    supply.mission=supply.valid and v.MAIN_POWER==1 and v.EFM_MISSION_POWER_AVAILABLE==1
end
local control_fields={'SEQ','TIME','GENERATION','POWER','PRESENT','STATION',
    'AZ','EL','WIDTH','SELECTED','PHYSICAL_VALID'}
local output_fields={'SEQ','TIME','EPOCH','READY','REASON','SCAN_AZ','SCAN_EL','OVERFLOW','AVAILABLE',
    'POWER','PRESENT','STATUS','COUNT','WIDTH','TRACKING','SELECTED','HUD_VALID','HUD_X','HUD_Y',
    'SELECTED_AZ','SELECTED_EL','SELECTED_AGE','CUE_AVAILABLE','SUPPLY_VALID'}
for _,suffix in ipairs(control_fields)do h('F22_IRST_CONTROL_'..suffix)end
for _,suffix in ipairs(output_fields)do h('F22_IRST_'..suffix)end
for i=1,library.capacity do
    local p=string.format('F22_IRST_%02d_',i)
    local row={}
    for _,suffix in ipairs({'VALID','ID','TIME','AZ','EL','X','Y','SELECTED','COAST'})do
        row[suffix]=p..suffix;h(p..suffix)
    end
    rows[i]=row
end
local function pod_loaded()
    if not native_weapon then native_weapon=GetDevice(devices.WEAPON_NATIVE)end
    if not native_weapon then return false end
    local ok,info=pcall(native_weapon.get_station_info,native_weapon,5) -- Declared pylon6 only.
    if not ok or not caps.station(info) or info.count<1 then return false end
    if caps.key(info)=='{F22_IRST}'then return true end
    -- The shared station API can omit CLSID. This mod's pylon6 sensor has
    -- the registered4/15/45 pod type; other registered pylon6 store is fuel.
    local w=info.weapon or {}
    return w.level1==4 and w.level2==15 and w.level3==45
end
local function command_packet(now,powered,valid)
    control_sequence=control_sequence%15999998+2
    put('F22_IRST_CONTROL_SEQ',control_sequence-1)
    put('F22_IRST_CONTROL_TIME',valid and supply.snapshot.values.EFM_PHYSICAL_WORLD_STAMP or now)
    put('F22_IRST_CONTROL_GENERATION',supply.snapshot.generation)
    put('F22_IRST_CONTROL_POWER',powered and 1 or 0)
    put('F22_IRST_CONTROL_PRESENT',present and 1 or 0)
    put('F22_IRST_CONTROL_STATION',5)
    put('F22_IRST_CONTROL_AZ',computer.az*library.rad)
    put('F22_IRST_CONTROL_EL',computer.el*library.rad)
    put('F22_IRST_CONTROL_WIDTH',computer.width*library.rad)
    put('F22_IRST_CONTROL_SELECTED',computer.tracking and computer.selected or 0)
    put('F22_IRST_CONTROL_PHYSICAL_VALID',valid and 1 or 0)
    put('F22_IRST_CONTROL_SEQ',control_sequence)
end
local function publish_rows(now)
    for i=1,library.capacity do
        local row,c=rows[i],computer.contacts[i]
        local valid=c~=nil
        put(row.VALID,valid and 1 or 0);put(row.ID,c and c.id or 0)
        put(row.TIME,c and c.time or 0);put(row.AZ,c and c.az or 0);put(row.EL,c and c.el or 0)
        put(row.X,c and c.az/math.rad(90)*.60 or 0)
        put(row.Y,c and (c.el/math.rad(75)*.90-.27) or 0)
        put(row.SELECTED,c and c.id==computer.selected and 1 or 0)
        put(row.COAST,c and now-c.time>.25 and 1 or 0)
    end
end
local function selected_cues(now,ready)
    local target=ready and computer:target()
    local fresh=target and now-target.time>=0 and now-target.time<=.5
    local hud=fresh and math.abs(target.az)<math.rad(13) and math.abs(target.el)<math.rad(10)
    put('F22_IRST_SELECTED',target and target.id or 0)
    put('F22_IRST_SELECTED_AZ',target and target.az or 0)
    put('F22_IRST_SELECTED_EL',target and target.el or 0)
    put('F22_IRST_SELECTED_AGE',target and now-target.time or 999)
    put('F22_IRST_HUD_VALID',hud and 1 or 0)
    put('F22_IRST_HUD_X',hud and math.tan(target.az) or 0)
    put('F22_IRST_HUD_Y',hud and math.tan(target.el)/math.cos(target.az) or 0)
    put('F22_IRST_CUE_AVAILABLE',fresh and 1 or 0)
end
function SetCommand(command,value)
    if command<11300 or command>11310 or not Snapshot.finite(value)then return end
    local down=decode(value,devices.IRST_SYSTEM)>.5
    local previous=held[command];held[command]=down
    if not down or previous then return end
    if command==11310 then
        if get('F22_IRST_CUE_AVAILABLE')==1 then dispatch_action(devices.RADAR_COMPUTER,11311,1)end
    else computer:command(command)end
end
for command=11300,11310 do dev:listen_command(command)end
function post_initialize()
    computer=library.new();held={};native_weapon=nil
    present,pod_check,last_time=false,-100,-100
    put('F22_IRST_READY',0);put('F22_IRST_CONTROL_PHYSICAL_VALID',0)
end
function update()
    local ok,now=pcall(get_model_time)
    local clock_valid=ok and Snapshot.finite(now)and now>=0
    if not clock_valid then now=0 end
    if now<last_time then computer:clear();pod_check=-100 end
    last_time=now
    update_supply(now)
    if now-pod_check>=.2 then present=pod_loaded();pod_check=now end
    local physical_valid=clock_valid and supply.snapshot.valid and supply.mission_valid
    local powered=selected_profile and physical_valid and supply.mission and computer.enabled and present
    command_packet(now,powered,physical_valid)
    local packet=reader:read(now)
    local ready=powered and packet.ready
    computer:update(packet,ready)
    publish_sequence=publish_sequence%15999998+2
    put('F22_IRST_SEQ',publish_sequence-1)
    put('F22_IRST_TIME',packet.time);put('F22_IRST_EPOCH',packet.epoch)
    put('F22_IRST_READY',ready and 1 or 0)
    put('F22_IRST_POWER',powered and 1 or 0);put('F22_IRST_PRESENT',present and 1 or 0)
    put('F22_IRST_SUPPLY_VALID',physical_valid and 1 or 0)
    local status=not present and 2 or not selected_profile and 1
        or not computer.enabled and 1 or not physical_valid and 5
        or not supply.mission and 3 or not ready and 4 or computer.tracking and 7 or 6
    put('F22_IRST_STATUS',status);put('F22_IRST_REASON',get('F22_IRST_NATIVE_REASON'))
    put('F22_IRST_SCAN_AZ',packet.az or 0);put('F22_IRST_SCAN_EL',packet.el or 0)
    put('F22_IRST_OVERFLOW',ready and packet.overflow and 1 or 0)
    put('F22_IRST_AVAILABLE',get('F22_IRST_NATIVE_AVAILABLE'))
    put('F22_IRST_WIDTH',computer.width);put('F22_IRST_TRACKING',computer.tracking and 1 or 0)
    put('F22_IRST_COUNT',#computer.contacts)
    publish_rows(now);selected_cues(now,ready)
    put('F22_IRST_SEQ',publish_sequence)
    diagnostic(now,status,ready)
end
make_default_activity(.05)
need_to_be_closed=false

-- GPL-3.0-or-later. Single owner of independent mission-route navigation.
local dev,base=GetSelf(),get_base_data()
dofile(LockOn_Options.script_path..'devices.lua')
dofile(LockOn_Options.script_path..'command_defs.lua')
local guidance=dofile(LockOn_Options.script_path..'Systems/Nav_Guidance.lua')
local nav=dofile(LockOn_Options.script_path..'Systems/Nav_Computer.lua')
local commands=dofile(LockOn_Options.script_path..'Systems/Nav_Commands.lua')
local decode=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
local geom=dofile(LockOn_Options.script_path..'Systems/NavGeometry.lua')
local entry_format=dofile(LockOn_Options.script_path..'Systems/Nav_Entry.lua')
local project=dofile(LockOn_Options.script_path..'Systems/HUD_TargetMath.lua').new(dofile(LockOn_Options.script_path..'HUD/glass.lua'))
make_default_activity(.05)
local handles={}
local function get(k) if not handles[k] then handles[k]=get_param_handle(k) end return handles[k]:get() end
local function set(k,v) if not handles[k] then handles[k]=get_param_handle(k) end handles[k]:set(v) end
local request_sequence=0
local function designation_status(code,text)
    set('F22_NAV_DESIGNATE_STATUS',code);set('F22_NAV_DESIGNATE_STATUS_TEXT',text)
end
-- Allocate every shared handle during device construction, before the three
-- LCD indicator Lua states bind them concurrently. Lazy first creation from
-- multiple indicators can race the common native parameter registry.
for _,key in ipairs({'MAIN_POWER','HUD_GS_VALID','HUD_GS_MPS','HUD_WP_VALID','HUD_WP_INDEX','HUD_WP_RANGE_NM',
    'HUD_WP_BRG_VALID','HUD_WP_BEARING_DEG','HUD_WP_INFO','HUD_WP_TTG_TEXT','HUD_WP_TTG_VALID',
    'HUD_WP_AZ_RAD','HUD_WP_EL_RAD','HUD_WP_X','HUD_WP_Y','HUD_WP_CUE_VALID','HUD_WP_OFFSCREEN',
    'HUD_WP_ARROW_X','HUD_WP_ARROW_Y','HUD_WP_ARROW_ROT','F22_NAV_VALID','F22_NAV_AUTO','F22_NAV_AUTO_TEXT',
    'F22_NAV_SCALE_NM','F22_NAV_ROUTE_COUNT','F22_NAV_COMPASS_ROT','F22_NAV_HEADING_TEXT','F22_NAV_BRG_ROT',
    'F22_NAV_STATUS_TEXT','F22_NAV_FIX_TEXT','F22_NAV_BRG_TEXT','F22_NAV_DIST_TEXT','F22_NAV_ALT_TEXT',
    'F22_NAV_TTG_TEXT','F22_NAV_COURSE_TEXT','F22_NAV_XTK_TEXT',
    'F22_NAV_OWN_VALID','F22_NAV_OWN_N','F22_NAV_OWN_E','F22_NAV_SEQUENCE_COUNT','F22_NAV_AUTO_HOLD','HUD_LANDING_CONFIG','HUD_ILS_DISPLAY_ENABLE','F22_NAV_FIX_LAT','F22_NAV_FIX_LON','F22_NAV_FIX_GEO_VALID','F22_NAV_FIX_ALT_FT','F22_NAV_EDIT_STATUS',
    'F22_NAV_EDIT_ID','F22_NAV_EDIT_LAT','F22_NAV_EDIT_LON','F22_NAV_EDIT_ALT_FT','F22_TCN_TUNE_TEXT','F22_ILS_TUNE_TEXT','F22_NAV_SOURCE_TEXT','F22_INS_STATUS_TEXT','F22_AP_STATUS_TEXT',
    'F22_INS_ESTIMATE_VALID','F22_INS_POSITION_UNCERTAINTY_M','F22_INS_HEADING_UNCERTAINTY_DEG','F22_INS_COASTING','F22_NAV_GUIDANCE_VALID','F22_NAV_STEER_VALID','F22_NAV_STEER_TRACK','F22_NAV_STEER_STAMP',
    'F22_NAV_SOURCE','F22_NAV_DISPLAY_VALID','HUD_ILS_LOC_VALID','HUD_ILS_GS_VALID','HUD_ILS_LOC','HUD_ILS_GS',
    'F22_NAV_DESIGNATE_STATUS','F22_NAV_DESIGNATE_STATUS_TEXT','F22_NAV_TARGET_REQUEST_SEQUENCE',
    'F22_NAV_TARGET_REQUEST_VALID','F22_NAV_TARGET_REQUEST_N','F22_NAV_TARGET_REQUEST_E',
    'F22_NAV_TARGET_ACK_SEQUENCE','F22_NAV_TARGET_ACK_TARGET_SEQUENCE','F22_NAV_TARGET_RESULT',
    'HUD_NAV_TARGET_LABEL','F22_NAV_DESIGNATED','F22_NAV_WPT_OPTION','F22_NAV_LEG_COURSE_DEG','F22_NAV_LEG_COURSE_VALID',
    'HUD_NAV_STEER_VALID','HUD_NAV_STEER_ERROR','HUD_NAV_BUG_LABEL','HUD_NAV_BUG_VALID','HUD_NAV_BUG_DEG','HUD_NAV_BUG_EDGE','HUD_HDG_BUG_VALID','HUD_HDG_BUG_DEG','HUD_HEADING_REFERENCE',
    'F22_NAV_HDG_BUG_ROT','F22_NAV_CDI_VALID','F22_NAV_CDI','F22_NAV_COURSE_ROT','F22_NAV_TO_FROM',
    'F22_TCN_BRG_VALID','F22_TCN_RANGE_VALID','F22_TCN_BRG_MAG','F22_TCN_RANGE_M','F22_ILS_LOC_VALID','F22_ILS_GS_VALID',
    'F22_ILS_LOC','F22_ILS_GS','F22_MAG_VALID','F22_MAG_DECL','F22_RADIONAV_AVAILABLE','F22_RADIONAV_REASON'}) do handles[key]=get_param_handle(key) end
-- Native text controllers bind parameter type during concurrent indicator startup.
for _,key in ipairs({'HUD_WP_INFO','HUD_WP_TTG_TEXT','F22_NAV_AUTO_TEXT','F22_NAV_HEADING_TEXT',
 'F22_NAV_STATUS_TEXT','F22_NAV_FIX_TEXT','F22_NAV_BRG_TEXT','F22_NAV_DIST_TEXT','F22_NAV_ALT_TEXT',
 'F22_NAV_TTG_TEXT','F22_NAV_COURSE_TEXT','F22_NAV_XTK_TEXT','F22_NAV_TO_FROM','HUD_NAV_BUG_LABEL',
 'HUD_HEADING_REFERENCE','F22_NAV_SOURCE_TEXT','F22_INS_STATUS_TEXT','F22_AP_STATUS_TEXT',
 'HUD_NAV_TARGET_LABEL','F22_NAV_WPT_OPTION','F22_TCN_TUNE_TEXT','F22_ILS_TUNE_TEXT','F22_NAV_CRS_TEXT','F22_NAV_EDIT_STATUS',
 'F22_NAV_DESIGNATE_STATUS_TEXT'})do set(key,'')end
for _,key in ipairs({'F22_NAV_FIX_LAT_TEXT','F22_NAV_FIX_LON_TEXT','F22_NAV_FIX_ELEV_TEXT','F22_NAV_POINT_NAME_TEXT',
 'F22_NAV_TCN_BRG_TEXT','F22_NAV_TCN_DIST_TEXT'})do set(key,'--')end
for i=1,nav.slots do
    for _,suffix in ipairs({'VALID','X','Y','ID','ACTIVE'}) do local k=string.format('F22_NAV_PT_%02d_',i)..suffix;handles[k]=get_param_handle(k) end
    for _,suffix in ipairs({'VALID','X1','Y1','X2','Y2','ACTIVE'}) do local k=string.format('F22_NAV_LEG_%02d_',i)..suffix;handles[k]=get_param_handle(k) end
end
local computer=nav.new({});local terrain
local mission=dofile(LockOn_Options.script_path..'Systems/Mission_Data.lua').new()
local Marks=dofile(LockOn_Options.script_path..'Systems/Nav_Marks_Time.lua')
local extras=Marks.new()
local mark_navigation=nav.new({})
local mark_active=false
local function active_computer()return mark_active and mark_navigation or computer end
local function active_waypoint()
 local selected=active_computer()
 return selected.route[selected.selected]
end
local extra_outputs={'MARK_SLOT','MARK_COUNT','MARK_SEQUENCE','MARK_ACTIVE','MARK_RESULT','CLOCK_INPUT',
 'ARRIVAL_INPUT','ARRIVAL_DAY','TIMING_DESTINATION','TIMING_VALID','TIMING_RGS_KTS','ROUTE_SELECTED','ARRIVED'}
for _,key in ipairs(extra_outputs)do get('F22_NAV_'..key)end
for _,key in ipairs({'MARK_TEXT','MARK_LAT_TEXT','MARK_LON_TEXT','MARK_ALT_TEXT',
 'CLOCK_TEXT','ARRIVAL_TEXT','TIMING_TEXT','TIMING_DEST_TEXT'})do set('F22_NAV_'..key,'--')end

local publication=dofile(LockOn_Options.script_path..'Systems/Nav_Publication.lua').new(get,set)
set('F22_MISSION_DATA_STATUS','')
set('F22_NAV_POINT_LABEL','WYPT --')
get('F22_MISSION_ROUTE_GENERATION')
local function cancel_waypoint_request()
    computer.designation=nil;set('F22_NAV_TARGET_REQUEST_VALID',0);designation_status(0,'')
end
local estimate=dofile(LockOn_Options.script_path..'Systems/INS_Model.lua').new()
local function quality()
 set('F22_INS_ESTIMATE_VALID',estimate.valid and 1 or 0)
 set('F22_INS_POSITION_UNCERTAINTY_M',estimate.error);set('F22_INS_HEADING_UNCERTAINTY_DEG',estimate.heading_error)
 set('F22_INS_COASTING',estimate.valid and not estimate.aiding and 1 or 0)
end
for _,key in ipairs({'F22_NAV_HEADING_VALID','F22_NAV_ATTITUDE_VALID','F22_NAV_REFERENCE_STAMP',
 'F22_GPS_OBSERVATION_VALID','F22_GPS_OBSERVATION_TIME','F22_INS_LAST_FIX_AGE','F22_GPS_FAILURE'})do get(key)end
local own_frame,estimate_input={},{}
local function ownship()
    set('F22_NAV_OWN_VALID',0)
    local clock=get('F22_AP_CLOCK')
    local position_ok,n,a,e=pcall(base.getSelfCoordinates)
    local heading_ok,h=pcall(base.getHeading)
    local pitch_ok,p=pcall(base.getPitch)
    local roll_ok,r=pcall(base.getRoll)
    local heading_valid=heading_ok and nav.finite(h)
    local attitude_valid=pitch_ok and roll_ok and nav.finite(p) and nav.finite(r)
    local observed=position_ok and nav.finite(n) and nav.finite(a) and nav.finite(e)
    local gps_available=observed and get('F22_GPS_FAILURE')<.5
    set('F22_NAV_HEADING_VALID',heading_valid and 1 or 0)
    set('F22_NAV_ATTITUDE_VALID',attitude_valid and 1 or 0)
    set('F22_NAV_REFERENCE_STAMP',clock)
    set('F22_GPS_OBSERVATION_VALID',gps_available and 1 or 0)
    if gps_available then set('F22_GPS_OBSERVATION_TIME',clock)end
    local model=get('F22_INS_MODEL_ENABLED')>.5
    estimate_input.now=clock;estimate_input.powered=get('MAIN_POWER')>.5
    estimate_input.enabled=model;estimate_input.aligned=not model or get('F22_INS_READY')>.5
    estimate_input.aided=get('F22_GPS_AID')>.5 and gps_available
    estimate_input.n=observed and n or nil;estimate_input.e=observed and e or nil
    estimate_input.alt=observed and a or nil
    estimate_input.velocity_valid=get('EFM_HUD_VALID')>.5
    estimate_input.vn=get('EFM_HUD_VN');estimate_input.ve=get('EFM_HUD_VE');estimate_input.vu=get('EFM_HUD_VU')
    n,e,a=estimate:update(estimate_input);quality()
    set('F22_INS_LAST_FIX_AGE',estimate.last_positive_fix and math.max(0,clock-estimate.last_positive_fix)or -1)
    own_frame.x,own_frame.y,own_frame.alt=n,e,a
    own_frame.position_valid=n~=nil
    own_frame.heading=heading_valid and (-h)%(2*math.pi)or nil
    own_frame.pitch,own_frame.roll=attitude_valid and p or 0,attitude_valid and r or 0
    own_frame.attitude_valid=attitude_valid
    local vn,ve=estimate_input.vn,estimate_input.ve
    own_frame.gs=estimate_input.velocity_valid and nav.finite(vn) and nav.finite(ve) and math.sqrt(vn*vn+ve*ve)
        or get('HUD_GS_VALID')>.5 and get('HUD_GS_MPS')or nil
    if n then set('F22_NAV_OWN_N',n);set('F22_NAV_OWN_E',e);set('F22_NAV_OWN_VALID',1)end
    if heading_valid then return own_frame end
end
local function height(n,e)
    if not terrain or type(terrain.GetHeight)~='function' then return end
    local ok,h=pcall(terrain.GetHeight,n,e)
    if ok and nav.finite(h) then return h end
end
local function load_route()
    local ok,route=false,nil
    if type(get_mission_route)=='function' then ok,route=pcall(get_mission_route) end
    if not ok then set('F22_MISSION_DATA_STATUS','ROUTE UNAVAILABLE');return false end
    route=type(route)=='table' and (route.points or route.route or route) or route
    local accepted,partition=mission:replace('route',{
        schema=1,source='HOST MISSION ROUTE',date='UNSPECIFIED',items=route})
    if not accepted then set('F22_MISSION_DATA_STATUS',partition);return false end
    computer=nav.new(partition.items,height)
    mark_active=false;extras.destination=0;extras.arrival=nil
    set('F22_ENTRY_NAV_ACTIVE',0)
    set('F22_MISSION_ROUTE_GENERATION',partition.generation)
    set('F22_MISSION_DATA_STATUS','ROUTE LOADED')
    return true
end
local function clear()
    set('F22_NAV_FIX_LAT_TEXT','--');set('F22_NAV_FIX_LON_TEXT','--');set('F22_NAV_FIX_ELEV_TEXT','--')
    set('F22_NAV_POINT_NAME_TEXT','--');set('F22_NAV_POINT_LABEL','WYPT --')
    for _,n in ipairs({'F22_NAV_FIX_GEO_VALID','HUD_WP_VALID','HUD_WP_CUE_VALID','HUD_WP_OFFSCREEN','HUD_WP_BRG_VALID','HUD_WP_TTG_VALID','F22_NAV_VALID'}) do set(n,0) end
    set('F22_NAV_WPT_OPTION','WYPT');set('F22_NAV_DESIGNATED',0);set('F22_NAV_LEG_COURSE_VALID',0)
    set('HUD_WP_INFO','STPT --');set('HUD_WP_TTG_TEXT','--:--:--')
    for _,n in ipairs({'HUD_WP_INDEX','HUD_WP_RANGE_NM','HUD_WP_BEARING_DEG'}) do set(n,0) end
    for _,key in ipairs({'STATUS','FIX','BRG','DIST','ALT','TTG','COURSE','XTK'}) do set('F22_NAV_'..key..'_TEXT',key=='STATUS' and (#computer.route==0 and 'NO ROUTE' or 'NAV DATA UNAVAILABLE') or '--') end
    for i=1,nav.slots do
        set(string.format('F22_NAV_PT_%02d_VALID',i),0);set(string.format('F22_NAV_LEG_%02d_VALID',i),0)
    end
end
function post_initialize()
    extras=Marks.new();mark_navigation=nav.new({});mark_active=false
    request_sequence=0;set('F22_NAV_TARGET_REQUEST_SEQUENCE',0);set('F22_NAV_TARGET_REQUEST_VALID',0)
    designation_status(0,'')
    estimate=dofile(LockOn_Options.script_path..'Systems/INS_Model.lua').new();quality()
    local ok,t=pcall(require,'terrain');if ok and type(t)=='table' then terrain=t end
    load_route();clear();set('F22_NAV_HEADING_TEXT','---T')
    if log and log.write then log.write('F22_NAV',log.INFO,'mission route loaded: '..#computer.route..' selectable points') end
end
for _,c in pairs(commands) do dev:listen_command(c) end
dev:listen_command(Keys.PlaneChangeTarget);dev:listen_command(1315)
local function apply_command(command,value)
    if command>=10830 and command<=10842 then value=decode(value,devices.NAV_SYSTEM) end
    if value and value<=0 then return end
    if get('MAIN_POWER')<.5 then
        if command==commands.designate then designation_status(7,'POWER OFF') end
        return
    end
    if command==commands.designate then
        local selected_computer=active_computer()
        local w=active_waypoint()
        if w and nav.finite(w.x) and nav.finite(w.y) and math.abs(w.x)<1e7 and math.abs(w.y)<1e7 then
            request_sequence=request_sequence+1
            selected_computer.designation={id=w.id,n=w.x,e=w.y,time=get('F22_AP_CLOCK'),
                waiting=true,request=request_sequence}
            -- Preserve AUTO preference; the active designation suspends
            -- sequencing until UNDESG/manual waypoint selection clears it.
            -- Publish the selected command snapshot before dispatch. The NAV
            -- display coordinates may still belong to the previous waypoint.
            set('F22_NAV_TARGET_REQUEST_VALID',0)
            set('F22_NAV_TARGET_REQUEST_N',w.x);set('F22_NAV_TARGET_REQUEST_E',w.y)
            set('F22_NAV_TARGET_REQUEST_SEQUENCE',request_sequence)
            set('F22_NAV_TARGET_REQUEST_VALID',1)
            designation_status(1,'DESIGNATING')
            dispatch_action(devices.AG_MARK_SYSTEM,10843,1);dispatch_action(devices.AG_MARK_SYSTEM,10843,0)
        else designation_status(3,'NO WAYPOINT') end
        return
    elseif command==commands.undesignate then
        computer.designation=nil;mark_navigation.designation=nil
        set('F22_NAV_TARGET_REQUEST_VALID',0);designation_status(6,'TARGET CLEARED')
        dispatch_action(devices.AG_MARK_SYSTEM,10811,1);dispatch_action(devices.AG_MARK_SYSTEM,10811,0)
        return
    end
    if command==commands.select then
        local accepted=computer:select_id(get('F22_NAV_EDIT_ID'))
        if accepted then cancel_waypoint_request() end
        set('F22_NAV_EDIT_STATUS',accepted and 'SELECTED' or 'INVALID STPT')
        return
    elseif command==commands.undo then
        local accepted=computer:undo_edit()
        if accepted then cancel_waypoint_request() end
        set('F22_NAV_EDIT_STATUS',accepted and 'UNDO COMPLETE' or 'NOTHING TO UNDO');return
    elseif command==commands.mark then
        -- Legacy mark binding is handled by the same independent bank below.
        return
    elseif command==commands.commit then
        local lat,lon=get('F22_NAV_EDIT_LAT'),get('F22_NAV_EDIT_LON')
        if not nav.finite(lat)or not nav.finite(lon)or math.abs(lat)>90 or math.abs(lon)>180 or not terrain or type(terrain.convertLatLonToMeters)~='function'then
            set('F22_NAV_EDIT_STATUS','COORDINATE INVALID / UNAVAILABLE');return
        end
        local ok,n,e=pcall(terrain.convertLatLonToMeters,lat,lon)
        local accepted=ok and computer:edit(get('F22_NAV_EDIT_ID'),n,e,get('F22_NAV_EDIT_ALT_FT')/3.280839895)
        if accepted then cancel_waypoint_request() end
        set('F22_NAV_EDIT_STATUS',accepted and 'STPT STORED' or 'EDIT REJECTED');return
    end
    local old_designation=computer.designation
    if command==commands.next or command==Keys.PlaneChangeTarget then mark_active=false;computer:step(1)
    elseif command==commands.previous or command==1315 then mark_active=false;computer:step(-1)
    elseif command==commands.auto and not mark_active then computer.automatic=not computer.automatic
    elseif command==commands.range_in then active_computer():scale(-1)
    elseif command==commands.range_out then active_computer():scale(1)
    elseif command==commands.direct then active_computer():direct(ownship())
    elseif command==commands.reload then load_route() end
    if old_designation and computer.designation~=old_designation then
        set('F22_NAV_TARGET_REQUEST_VALID',0);designation_status(0,'')
    end
end
local function route_point(id)
 for index=1,#computer.route do
  if computer.route[index].id==id then return computer.route[index],index end
 end
end
local capture_point={}
local function capture_mark(target)
 if target then
  if get('HUD_AG_TARGET_VALID')<.5 then return false end
  capture_point.n=get('HUD_AG_MARK_NORTH');capture_point.e=get('HUD_AG_MARK_EAST')
  capture_point.alt=get('HUD_AG_MARK_ALT')
 else
  local own=ownship()
  if not own or not own.position_valid then return false end
  capture_point.n,capture_point.e,capture_point.alt=own.x,own.y,own.alt
 end
 return extras:capture(capture_point,target and'TARGET'or'OWN',get('F22_AP_CLOCK'))
end
local function mark_direct()
 local point=extras.marks[extras.selected]
 local own=ownship()
 if not point.valid or not own or not own.position_valid then return false end
 mark_navigation=nav.new({})
 mark_navigation.origin={x=own.x,y=own.y,alt=own.alt}
 mark_navigation.route[1]={id=-extras.selected,x=point.n,y=point.e,alt=point.alt,msl=point.alt,
  reference='MSL',name='MARK '..extras.selected,mark=true,sequence=point.sequence}
 mark_navigation:direct(own);mark_navigation.automatic=true
 computer.designation=nil;mark_active=true
 set('F22_NAV_TARGET_REQUEST_VALID',0)
 dispatch_action(devices.FLIGHT_GUIDANCE,11830,1)
 return true,-extras.selected
end
local function timing_command(command,value)
 if command==commands.clock_set then return extras:set_clock(value,get('F22_AP_CLOCK')),value
 elseif command==commands.arrival_set then return extras:set_arrival(value,get('F22_AP_CLOCK')),value
 elseif command==commands.arrival_day then return extras:set_day(value,get('F22_AP_CLOCK')),value
 elseif command==commands.timing_destination then
  if not route_point(value)then return false end
  extras.destination=value;return true,value
 elseif command==commands.timing_clear then extras.arrival=nil;return true end
 return false
end
local function mark_command(command,value)
 if command==commands.mark_capture or command==commands.mark then
  local accepted,slot=capture_mark(false)
  set('F22_NAV_MARK_RESULT',accepted and 1 or 2)
  return accepted,slot
 elseif command==commands.mark_target then return capture_mark(true)
 elseif command==commands.mark_select then return extras:select(value),extras.selected
 elseif command==commands.mark_previous or command==commands.mark_next then
  local direction=command==commands.mark_next and 1 or -1
  extras:select((extras.selected-1+direction)%Marks.slots+1);return true,extras.selected
 elseif command==commands.mark_direct then return mark_direct()
 elseif command==commands.route then mark_active=false;return true
 end
 return false
end
local function extra_command(command,value)
 if command>=commands.clock_set and command<=commands.timing_clear then return timing_command(command,value)end
 return mark_command(command,value)
end
local function is_extra(command)
 return command==commands.mark or command>=11810 and command<=11819
  or command==commands.mark_previous or command==commands.mark_next
end
local function timing_distance(own)
 local target,index=route_point(extras.destination)
 if not target or not own or not own.position_valid then return end
 local first=index<computer.selected and index or computer.selected
 local point=computer.route[first]
 local dn,de=point.x-own.x,point.y-own.y
 local distance=math.sqrt(dn*dn+de*de)
 for leg=first+1,index do
  local a,b=computer.route[leg-1],computer.route[leg]
  dn,de=b.x-a.x,b.y-a.y;distance=distance+math.sqrt(dn*dn+de*de)
 end
 return distance,index<computer.selected and'DIRECT'or'ROUTE'
end
local function publish_extras(own)
 local mark=extras.marks[extras.selected]
 local now=get('F22_AP_CLOCK')
 set('F22_NAV_MARK_SLOT',extras.selected);set('F22_NAV_MARK_COUNT',math.min(extras.sequence,Marks.slots))
 set('F22_NAV_MARK_SEQUENCE',extras.sequence);set('F22_NAV_MARK_ACTIVE',mark_active and 1 or 0)
 set('F22_NAV_ROUTE_SELECTED',mark_active and 0 or 1)
 set('F22_NAV_MARK_TEXT',string.format('MARK %d %s',extras.selected,mark.valid and mark.source or'EMPTY'))
 set('F22_NAV_MARK_LAT_TEXT','LAT --');set('F22_NAV_MARK_LON_TEXT','LON --');set('F22_NAV_MARK_ALT_TEXT','ELEV --')
 if mark.valid then
  set('F22_NAV_MARK_ALT_TEXT',string.format('ELEV %.0f FT MSL',mark.alt*3.280839895))
  if terrain and type(terrain.convertMetersToLatLon)=='function'then
   local ok,lat,lon=pcall(terrain.convertMetersToLatLon,mark.n,mark.e)
   if ok and nav.finite(lat)and nav.finite(lon)then
    set('F22_NAV_MARK_LAT_TEXT',entry_format.coord(lat,true));set('F22_NAV_MARK_LON_TEXT',entry_format.coord(lon,false))
   end
  end
 end
 local utc=extras:utc(now)
 set('F22_NAV_CLOCK_TEXT','UTC '..Marks.clock_text(utc));set('F22_NAV_CLOCK_INPUT',extras.clock_input or 0)
 set('F22_NAV_ARRIVAL_TEXT','ARR '..Marks.clock_text(extras.arrival))
 set('F22_NAV_ARRIVAL_INPUT',extras.arrival_input or 0)
 set('F22_NAV_ARRIVAL_DAY',extras.day);set('F22_NAV_TIMING_DESTINATION',extras.destination)
 set('F22_NAV_TIMING_DEST_TEXT',extras.destination>0 and'DEST W'..extras.destination or'DEST --')
 local distance,kind=timing_distance(own)
 local speed,status=extras:required_speed(distance,now)
 set('F22_NAV_TIMING_VALID',speed and 1 or 0);set('F22_NAV_TIMING_RGS_KTS',speed and speed*1.943844492 or 0)
 set('F22_NAV_TIMING_TEXT',speed and string.format('RGS %.0f KT %s',speed*1.943844492,kind)or status)
end
local transaction=dofile(LockOn_Options.script_path..'Systems/Entry_Transaction.lua').channel('NAV',get,set)
for _,key in ipairs({'ID','LAT','LON','ALT_FT'})do get('F22_NAV_EDIT_ACK_'..key);get('F22_ENTRY_NAV_'..key)end
dev:listen_command(11800)
function SetCommand(command,value)
    if command~=11800 then
        if is_extra(command)then
            if value and value>0 and get('MAIN_POWER')>.5 then extra_command(command,value);publish_extras(ownship())end
        else apply_command(command,value)end
        return
    end
    local requested,wanted=transaction:take(value)
    if not requested then return end
    if get('MAIN_POWER')<.5 then transaction:finish(value,false);return end
    if is_extra(requested)then
        local accepted,committed=extra_command(requested,wanted)
        publish_extras(ownship());transaction:finish(value,accepted,committed);return
    end
    if requested~=commands.commit then transaction:finish(value,false);return end
    for _,key in ipairs({'ID','LAT','LON','ALT_FT'})do
        set('F22_NAV_EDIT_'..key,get('F22_ENTRY_NAV_'..key))
    end
    apply_command(requested,1)
    local accepted=get('F22_NAV_EDIT_STATUS')=='STPT STORED'
    if accepted then
        for _,key in ipairs({'ID','LAT','LON','ALT_FT'})do
            set('F22_NAV_EDIT_ACK_'..key,get('F22_NAV_EDIT_'..key))
        end
    end
    transaction:finish(value,accepted)
end
local next_diagnostic=-1
local function diagnostic(own,s)
    local now=get('F22_AP_CLOCK')
    local hold=not computer.automatic and 1 or computer.designation and 2 or not own and 6
        or not s and 5 or not nav.finite(own.gs) and 3 or own.gs<=15 and 4 or s.arrived and 7 or 0
    set('F22_NAV_AUTO_HOLD',hold);set('F22_NAV_SEQUENCE_COUNT',computer.sequence_count)
    if log and log.write and (s and s.sequence_from or now>=next_diagnostic or now<next_diagnostic-2)then
        next_diagnostic=now+1
        log.write('F22_NAV_STATE',log.INFO,string.format(
            't=%.3f auto=%d hold=%d wp=%d route=%d seq=%d source=%.0f gs=%.3f range_m=%.3f along_m=%.3f cross_m=%.3f from=%d cause=%s radio=%.0f reason=%.0f ils_khz=%.0f loc_valid=%.0f gs_valid=%.0f loc=%.7f gs=%.7f approach=%.0f hud_mode=%.0f gear=%.0f',
            now,computer.automatic and 1 or 0,hold,s and s.waypoint.id or 0,#computer.route,computer.sequence_count,get('F22_NAV_SOURCE'),
            own and own.gs or -1,s and s.distance or -1,s and s.along or -1,s and s.cross or -1,s and s.sequence_from or 0,s and s.sequence_reason or '-',
            get('F22_RADIONAV_AVAILABLE'),get('F22_RADIONAV_REASON'),get('F22_ILS_FREQ_KHZ'),get('F22_ILS_LOC_VALID'),get('F22_ILS_GS_VALID'),get('F22_ILS_LOC'),get('F22_ILS_GS'),get('HUD_ILS_DISPLAY_ENABLE'),get('HUD_MODE'),get('HUD_LANDING_CONFIG')))
    end
end
local function time_text(t)
    if not nav.finite(t) or t<0 or t>359999 then return '--:--:--' end
    t=math.floor(t+.5)
    return string.format('%02d:%02d:%02d',math.floor(t/3600),math.floor(t/60)%60,t%60)
end
function update()
    local mag=get('F22_NAV_REFERENCE')>.5
    local bearing=get('F22_TCN_BRG_MAG')+(mag and 0 or get('F22_MAG_DECL'))
    set('F22_NAV_TCN_BRG_TEXT',get('F22_TCN_BRG_VALID')>.5 and get('F22_MAG_VALID')>.5 and
        nav.finite(bearing)and string.format('BRG %03d%s',math.floor(math.deg(bearing)+.5)%360,mag and'M'or'T')or'BRG --')
    local range=get('F22_TCN_RANGE_M')
    set('F22_NAV_TCN_DIST_TEXT',get('F22_TCN_RANGE_VALID')>.5 and nav.finite(range)and range>=0 and string.format('DME %.1fNM',range/1852)or'DME --')
    set('F22_NAV_AUTO',computer.automatic and 1 or 0)
    set('F22_NAV_AUTO_TEXT',mark_active and'MARK'or computer.automatic and'AUTO'or'MAN')
    set('F22_NAV_SCALE_NM',nav.ranges[active_computer().range_index]);set('F22_NAV_ROUTE_COUNT',#computer.route)
    if get('MAIN_POWER')<.5 then
        estimate:update({now=get('F22_AP_CLOCK'),powered=false});quality()
        computer.designation=nil;mark_navigation.designation=nil;mark_active=false
        set('F22_ENTRY_NAV_ACTIVE',0)
        extras.clock_epoch=nil;extras.arrival=nil
        set('F22_NAV_TARGET_REQUEST_VALID',0)
        designation_status(7,'POWER OFF')
    elseif get('F22_NAV_DESIGNATE_STATUS')==7 then
        -- Restored power permits route feedback, never a pre-outage request.
        cancel_waypoint_request()
    end
    local own=get('MAIN_POWER')>.5 and ownship() or nil
    publish_extras(own)
    set('F22_NAV_ARRIVED',0)
    set('F22_NAV_COMPASS_ROT',own and own.heading or 0)
    set('F22_NAV_HEADING_TEXT',own and string.format('%03dT',math.floor(math.deg(own.heading)+.5)%360) or '---T')
    local selected_computer=active_computer()
    local s=own and nav.solution(selected_computer,own)
    if not s then
        clear();guidance(get,set,own,nil);publication.publish();diagnostic(own,nil);return
    end
    local w=s.waypoint
    set('F22_NAV_ARRIVED',s.arrived and 1 or 0)
    local d=selected_computer.designation
    if d then
        local acknowledged=get('F22_NAV_TARGET_ACK_SEQUENCE')==d.request
        local result=get('F22_NAV_TARGET_RESULT')
        local same_target=get('HUD_AG_TARGET_VALID')>.5 and get('F22_AG_TARGET_SOURCE')==3 and
            get('F22_AG_TARGET_SEQUENCE')==get('F22_NAV_TARGET_ACK_TARGET_SEQUENCE') and
            math.abs(get('HUD_AG_MARK_NORTH')-d.n)<1 and math.abs(get('HUD_AG_MARK_EAST')-d.e)<1
        if acknowledged and result==1 and same_target then
            d.waiting=false;s.designated=true;s.designation_alt=get('HUD_AG_MARK_ALT')
            designation_status(2,'TARGET DESIGNATED')
        elseif acknowledged and result~=1 then
            selected_computer.designation=nil;set('F22_NAV_TARGET_REQUEST_VALID',0)
            designation_status(result==3 and 4 or result==4 and 7 or 5,
                result==3 and 'TERRAIN UNAVAIL' or result==4 and 'POWER OFF' or 'DESIGNATE FAILED')
        elseif not d.waiting or get('F22_AP_CLOCK')-d.time>.5 then
            selected_computer.designation=nil;set('F22_NAV_TARGET_REQUEST_VALID',0)
            designation_status(5,'DESIGNATE FAILED')
        end
    end
    set('F22_NAV_POINT_LABEL',w.mark and w.name or'WYPT '..w.id)
    set('HUD_NAV_TARGET_LABEL','TGT')
    set('F22_NAV_DESIGNATED',s.designated and 1 or 0)
    set('F22_NAV_WPT_OPTION',s.designated and 'TGT' or w.mark and'MARK'or'WYPT')
    set('F22_NAV_LEG_COURSE_VALID',s.course and 1 or 0)
    set('F22_NAV_LEG_COURSE_DEG',s.course and math.deg(s.course) or 0)
    set('F22_NAV_FIX_GEO_VALID',0);set('F22_NAV_FIX_ALT_FT',w.msl and w.msl*3.280839895 or 0)
    set('F22_NAV_FIX_LAT_TEXT','--');set('F22_NAV_FIX_LON_TEXT','--')
    set('F22_NAV_FIX_ELEV_TEXT',w.msl and string.format('%.0f FT MSL',w.msl*3.280839895)or'--')
    if terrain and type(terrain.convertMetersToLatLon)=='function'then
        local ok,lat,lon=pcall(terrain.convertMetersToLatLon,w.x,w.y)
        if ok and nav.finite(lat)and nav.finite(lon)then
            set('F22_NAV_FIX_LAT',lat);set('F22_NAV_FIX_LON',lon);set('F22_NAV_FIX_GEO_VALID',1)
            set('F22_NAV_FIX_LAT_TEXT',entry_format.coord(lat,true));set('F22_NAV_FIX_LON_TEXT',entry_format.coord(lon,false))
        end
    end
    local degrees=math.floor(math.deg(s.bearing)+.5)%360
    set('F22_NAV_VALID',1);set('F22_NAV_COMPASS_ROT',own.heading)
    set('F22_NAV_TARGET_N',w.x);set('F22_NAV_TARGET_E',w.y)
    set('F22_NAV_HEADING_TEXT',string.format('%03dT',math.floor(math.deg(own.heading)+.5)%360))
    set('F22_NAV_STATUS_TEXT',s.designated and 'TARGET DESIGNATED' or s.arrived and 'ARRIVED' or (s.direct and 'DIRECT TO' or 'MISSION ROUTE'))
    set('F22_NAV_FIX_TEXT',w.mark and w.name or string.format('WP%02d %s',w.id,w.name))
    set('F22_NAV_POINT_NAME_TEXT',w.mark and w.name or string.format('WP%02d %s',w.id,w.name))
    set('F22_NAV_BRG_TEXT',string.format('BRG %03dT',degrees))
    set('F22_NAV_DIST_TEXT',string.format('DIS %.1fNM',s.distance/1852))
    set('F22_NAV_ALT_TEXT',w.alt and string.format('ALT %.0f%s',w.alt*3.280839895,w.reference) or 'ALT --')
    local ttg=time_text(s.ttg);set('F22_NAV_TTG_TEXT','TTG '..ttg)
    set('F22_NAV_COURSE_TEXT',s.course and string.format('CRS %03dT',math.floor(math.deg(s.course)+.5)%360) or 'CRS --')
    set('F22_NAV_XTK_TEXT',s.cross and string.format('XTK %s%.1f',s.cross<0 and 'L' or 'R',math.abs(s.cross)/1852) or 'XTK --')
    set('F22_NAV_BRG_ROT',-s.relative)
    set('HUD_WP_VALID',1);set('HUD_WP_INDEX',w.id);set('HUD_WP_RANGE_NM',s.distance/1852)
    set('HUD_WP_BRG_VALID',s.distance>1 and 1 or 0);set('HUD_WP_BEARING_DEG',degrees)
    set('HUD_WP_INFO',s.designated and string.format('%.1f TGT',get('HUD_AG_TGT_RANGE_NM'))
        or string.format(w.mark and'%.1f M%d'or'%.1f W%d',s.distance/1852,math.abs(w.id)))
    set('HUD_WP_TTG_TEXT',ttg);set('HUD_WP_TTG_VALID',ttg~='--:--:--' and 1 or 0)
    set('HUD_WP_CUE_VALID',0);set('HUD_WP_OFFSCREEN',0)
    if s.designated and s.distance>1 and own.attitude_valid then
        local f,r,u=geom.body(w.x-own.x,w.y-own.y,s.designation_alt-own.alt,own.heading,own.pitch,own.roll)
        local az=nav.atan2(r,f);local el=nav.atan2(u,math.sqrt(f*f+r*r));local cue=project(az,el)
        set('HUD_WP_AZ_RAD',az);set('HUD_WP_EL_RAD',el);set('HUD_WP_X',cue.x);set('HUD_WP_Y',cue.y)
        set('HUD_WP_CUE_VALID',cue.visible and 1 or 0);set('HUD_WP_OFFSCREEN',cue.visible and 0 or 1)
        set('HUD_WP_ARROW_X',cue.arrow_x);set('HUD_WP_ARROW_Y',cue.arrow_y);set('HUD_WP_ARROW_ROT',cue.rotation)
    end
    for i=1,nav.slots do
        local p=s.points[i];local root=string.format('F22_NAV_PT_%02d_',i)
        set(root..'VALID',p and p.visible and 1 or 0)
        if p then set(root..'X',p.x);set(root..'Y',p.y);set(root..'ID',p.id);set(root..'ACTIVE',p.active and 1 or 0) end
        local l=s.legs[i];root=string.format('F22_NAV_LEG_%02d_',i)
        set(root..'VALID',l and 1 or 0)
        if l then for _,k in ipairs({'x1','y1','x2','y2'}) do set(root..k:upper(),l[k]) end;set(root..'ACTIVE',l.active and 1 or 0) end
    end
    guidance(get,set,own,s)
    publication.publish()
    diagnostic(own,s)
end
need_to_be_closed=false

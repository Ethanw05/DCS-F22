-- GPL-3.0-or-later. Single owner of independent mission-route navigation.
local dev,base=GetSelf(),get_base_data()
dofile(LockOn_Options.script_path..'devices.lua')
dofile(LockOn_Options.script_path..'command_defs.lua')
local nav=dofile(LockOn_Options.script_path..'Systems/Nav_Computer.lua')
local commands=dofile(LockOn_Options.script_path..'Systems/Nav_Commands.lua')
local decode=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
local geom=dofile(LockOn_Options.script_path..'Systems/NavGeometry.lua')
local project=dofile(LockOn_Options.script_path..'Systems/HUD_TargetMath.lua').new(dofile(LockOn_Options.script_path..'HUD/glass.lua'))
make_default_activity(.05)
local handles={}
local function get(k) if not handles[k] then handles[k]=get_param_handle(k) end return handles[k]:get() end
local function set(k,v) if not handles[k] then handles[k]=get_param_handle(k) end handles[k]:set(v) end
-- Allocate every shared handle during device construction, before the three
-- LCD indicator Lua states bind them concurrently. Lazy first creation from
-- multiple indicators can race the common native parameter registry.
for _,key in ipairs({'MAIN_POWER','HUD_GS_VALID','HUD_GS_MPS','HUD_WP_VALID','HUD_WP_INDEX','HUD_WP_RANGE_NM',
    'HUD_WP_BRG_VALID','HUD_WP_BEARING_DEG','HUD_WP_INFO','HUD_WP_TTG_TEXT','HUD_WP_TTG_VALID',
    'HUD_WP_AZ_RAD','HUD_WP_EL_RAD','HUD_WP_X','HUD_WP_Y','HUD_WP_CUE_VALID','HUD_WP_OFFSCREEN',
    'HUD_WP_ARROW_X','HUD_WP_ARROW_Y','HUD_WP_ARROW_ROT','F22_NAV_VALID','F22_NAV_AUTO','F22_NAV_AUTO_TEXT',
    'F22_NAV_SCALE_NM','F22_NAV_ROUTE_COUNT','F22_NAV_COMPASS_ROT','F22_NAV_HEADING_TEXT','F22_NAV_BRG_ROT',
    'F22_NAV_STATUS_TEXT','F22_NAV_FIX_TEXT','F22_NAV_BRG_TEXT','F22_NAV_DIST_TEXT','F22_NAV_ALT_TEXT',
    'F22_NAV_TTG_TEXT','F22_NAV_COURSE_TEXT','F22_NAV_XTK_TEXT'}) do handles[key]=get_param_handle(key) end
for i=1,nav.slots do
    for _,suffix in ipairs({'VALID','X','Y','ID','ACTIVE'}) do local k=string.format('F22_NAV_PT_%02d_',i)..suffix;handles[k]=get_param_handle(k) end
    for _,suffix in ipairs({'VALID','X1','Y1','X2','Y2','ACTIVE'}) do local k=string.format('F22_NAV_LEG_%02d_',i)..suffix;handles[k]=get_param_handle(k) end
end
local computer=nav.new({});local terrain
local function ownship()
    local ok,n,a,e=pcall(base.getSelfCoordinates)
    if not ok or not nav.finite(n) or not nav.finite(a) or not nav.finite(e) then return end
    local h,p,r=base.getHeading(),base.getPitch(),base.getRoll()
    if not nav.finite(h) or not nav.finite(p) or not nav.finite(r) then return end
    return {x=n,y=e,alt=a,heading=(-h)%(2*math.pi),pitch=p,roll=r,
        gs=get('HUD_GS_VALID')>.5 and get('HUD_GS_MPS') or nil}
end
local function height(n,e)
    if not terrain or type(terrain.GetHeight)~='function' then return end
    local ok,h=pcall(terrain.GetHeight,n,e)
    if ok and nav.finite(h) then return h end
end
local function load_route()
    local ok,route=false,nil
    if type(get_mission_route)=='function' then ok,route=pcall(get_mission_route) end
    computer=nav.new(ok and route or {},height)
end
local function clear()
    for _,n in ipairs({'HUD_WP_VALID','HUD_WP_CUE_VALID','HUD_WP_OFFSCREEN','HUD_WP_BRG_VALID','HUD_WP_TTG_VALID','F22_NAV_VALID'}) do set(n,0) end
    set('HUD_WP_INFO','STPT --');set('HUD_WP_TTG_TEXT','--:--:--')
    for _,n in ipairs({'HUD_WP_INDEX','HUD_WP_RANGE_NM','HUD_WP_BEARING_DEG'}) do set(n,0) end
    for _,key in ipairs({'STATUS','FIX','BRG','DIST','ALT','TTG','COURSE','XTK'}) do set('F22_NAV_'..key..'_TEXT',key=='STATUS' and (#computer.route==0 and 'NO ROUTE' or 'NAV DATA UNAVAILABLE') or '--') end
    for i=1,nav.slots do
        set(string.format('F22_NAV_PT_%02d_VALID',i),0);set(string.format('F22_NAV_LEG_%02d_VALID',i),0)
    end
end
function post_initialize()
    local ok,t=pcall(require,'terrain');if ok and type(t)=='table' then terrain=t end
    load_route();clear();set('F22_NAV_HEADING_TEXT','---T')
    if log and log.write then log.write('F22_NAV',log.INFO,'mission route loaded: '..#computer.route..' selectable points') end
end
for _,c in pairs(commands) do dev:listen_command(c) end
dev:listen_command(Keys.PlaneChangeTarget);dev:listen_command(1315)
function SetCommand(command,value)
    if command>=10830 and command<=10836 then value=decode(value,devices.NAV_SYSTEM) end
    if value and value<=0 then return end
    if get('MAIN_POWER')<.5 then return end
    if command==commands.next or command==Keys.PlaneChangeTarget then computer:step(1)
    elseif command==commands.previous or command==1315 then computer:step(-1)
    elseif command==commands.auto then computer.automatic=not computer.automatic
    elseif command==commands.range_in then computer:scale(-1)
    elseif command==commands.range_out then computer:scale(1)
    elseif command==commands.direct then computer:direct(ownship())
    elseif command==commands.reload then load_route() end
end
local function time_text(t)
    if not nav.finite(t) or t<0 or t>359999 then return '--:--:--' end
    t=math.floor(t+.5)
    return string.format('%02d:%02d:%02d',math.floor(t/3600),math.floor(t/60)%60,t%60)
end
function update()
    set('F22_NAV_AUTO',computer.automatic and 1 or 0)
    set('F22_NAV_AUTO_TEXT',computer.automatic and 'AUTO' or 'MAN')
    set('F22_NAV_SCALE_NM',nav.ranges[computer.range_index]);set('F22_NAV_ROUTE_COUNT',#computer.route)
    local own=get('MAIN_POWER')>.5 and ownship() or nil
    set('F22_NAV_COMPASS_ROT',own and own.heading or 0)
    set('F22_NAV_HEADING_TEXT',own and string.format('%03dT',math.floor(math.deg(own.heading)+.5)%360) or '---T')
    local s=own and nav.solution(computer,own)
    if not s then clear();return end
    local w=s.waypoint;local degrees=math.floor(math.deg(s.bearing)+.5)%360
    set('F22_NAV_VALID',1);set('F22_NAV_COMPASS_ROT',own.heading)
    set('F22_NAV_HEADING_TEXT',string.format('%03dT',math.floor(math.deg(own.heading)+.5)%360))
    set('F22_NAV_STATUS_TEXT',s.arrived and 'ARRIVED' or (s.direct and 'DIRECT TO' or 'MISSION ROUTE'))
    set('F22_NAV_FIX_TEXT',string.format('WP%02d %s',w.id,w.name))
    set('F22_NAV_BRG_TEXT',string.format('BRG %03dT',degrees))
    set('F22_NAV_DIST_TEXT',string.format('DIS %.1fNM',s.distance/1852))
    set('F22_NAV_ALT_TEXT',w.alt and string.format('ALT %.0f%s',w.alt*3.280839895,w.reference) or 'ALT --')
    local ttg=time_text(s.ttg);set('F22_NAV_TTG_TEXT','TTG '..ttg)
    set('F22_NAV_COURSE_TEXT',s.course and string.format('CRS %03dT',math.floor(math.deg(s.course)+.5)%360) or 'CRS --')
    set('F22_NAV_XTK_TEXT',s.cross and string.format('XTK %s%.1f',s.cross<0 and 'L' or 'R',math.abs(s.cross)/1852) or 'XTK --')
    set('F22_NAV_BRG_ROT',-s.relative)
    set('HUD_WP_VALID',1);set('HUD_WP_INDEX',w.id);set('HUD_WP_RANGE_NM',s.distance/1852)
    set('HUD_WP_BRG_VALID',s.distance>1 and 1 or 0);set('HUD_WP_BEARING_DEG',degrees)
    set('HUD_WP_INFO',string.format('%02d %03d/%.1f',w.id,degrees,s.distance/1852))
    set('HUD_WP_TTG_TEXT',ttg);set('HUD_WP_TTG_VALID',ttg~='--:--:--' and 1 or 0)
    set('HUD_WP_CUE_VALID',0);set('HUD_WP_OFFSCREEN',0)
    if w.msl and s.distance>1 then
        local f,r,u=geom.body(w.x-own.x,w.y-own.y,w.msl-own.alt,own.heading,own.pitch,own.roll)
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
end
need_to_be_closed=false

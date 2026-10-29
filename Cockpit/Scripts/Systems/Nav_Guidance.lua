-- GPL-3.0-or-later. Navigation references and fly-over course guidance.
local N=dofile(LockOn_Options.script_path..'Systems/Nav_Computer.lua')
local Radio=dofile(LockOn_Options.script_path..'Systems/Radio_Navigation.lua')
local Magnetic=dofile(LockOn_Options.script_path..'Systems/Magnetic_Reference.lua')
local Approach=dofile(LockOn_Options.script_path..'Systems/Manual_Approach.lua')
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function selected_course(get)
 local course=get('F22_NAV_COURSE_TRUE')
 if get('F22_NAV_COURSE_SCHEMA')~=1 or not N.finite(course)or course<0 or course>=360 then return end
 return math.rad(course)
end
return function(get,set,own,s,received)
 local ready=get('F22_INS_READY')==1
 local selection=get('F22_NAV_REFERENCE')
 local suffix=selection==1 and 'M' or selection==0 and 'T' or '?'
 local reference
 if selection==0 then reference=0
 elseif selection==1 and received.physical_current then reference=Magnetic.declination(get,received.physical.generation,received.now)end
 set('HUD_HEADING_REFERENCE',suffix)
 set('F22_NAV_GUIDANCE_VALID',0);set('F22_NAV_STEER_VALID',0);set('HUD_NAV_BUG_VALID',0);set('F22_NAV_CDI_VALID',0)
 set('F22_NAV_CDI_SCALE_TEXT','')
 set('HUD_NAV_STEER_VALID',0)
 set('F22_NAV_DISPLAY_VALID',0);set('F22_NAV_COMPASS_VALID',0)
 set('F22_NAV_HEADING_TEXT','---'..suffix)
 Approach.publish(get,set,received)
 local source=get('F22_NAV_SOURCE')
 set('HUD_HDG_BUG_VALID',own and get('MAIN_POWER')>.5 and 1 or 0)
 if not own then return end
 local hdg_delta=math.deg(N.wrap(math.rad(get('F22_AP_HEADING'))-own.heading))
 set('HUD_HDG_BUG_DEG',clamp(hdg_delta,-15,15));set('F22_NAV_HDG_BUG_ROT',-math.rad(hdg_delta))
 set('F22_NAV_HEADING_TEXT','---'..suffix)
 if reference~=nil then
  set('F22_NAV_COMPASS_ROT',(own.heading-reference)%(2*math.pi));set('F22_NAV_COMPASS_VALID',1)
  set('F22_NAV_HEADING_TEXT',string.format('%03d%s',math.floor(math.deg(own.heading-reference)+.5)%360,suffix))
 end
 if source~=0 then set('F22_NAV_DESIGNATED',0)end
 set('F22_NAV_DISPLAY_VALID',(source~=3 and (source~=0 or s~=nil))and 1 or 0)
 if source~=0 or not ready then
  set('HUD_WP_CUE_VALID',0);set('HUD_WP_OFFSCREEN',0);set('HUD_WP_VALID',0)
 end
 if source==1 then
  set('HUD_WP_INFO',get('F22_TCN_TUNE_TEXT'));set('HUD_WP_TTG_TEXT','--:--:--')
 elseif source==2 then
  set('HUD_WP_INFO',get('F22_ILS_TUNE_TEXT'));set('HUD_WP_TTG_TEXT','--:--:--')
 elseif source==3 then
  set('HUD_WP_INFO','');set('HUD_WP_TTG_TEXT','--:--:--');set('HUD_WP_TTG_VALID',0);set('HUD_WP_BRG_VALID',0)
  set('F22_NAV_STATUS_TEXT','NO NAV SOURCE')
 elseif not ready then set('HUD_WP_INFO','IRS ALIGN');set('HUD_WP_TTG_TEXT','--:--:--');set('F22_NAV_STATUS_TEXT',get('F22_INS_STATUS_TEXT'))end
 local bearing,distance,course,cross,steer
 local lookahead=math.max(1852,(own.gs or 0)*25)
 local c=selected_course(get)
 if source==0 and s and ready then
  bearing=s.bearing;distance=s.distance;course=s.course;cross=s.cross
  if get('F22_NAV_OBS')>.5 then
   course=c;cross=course and -math.sin(N.wrap(bearing-course))*distance or nil
  end
  steer=course and course-clamp(math.atan((cross or 0)/lookahead),-math.pi/4,math.pi/4) or bearing
  if get('F22_NAV_OBS')>.5 and not course then steer=nil end
  if s.along and s.along>s.length and get('F22_NAV_OBS')<.5 then steer=bearing end
 elseif source==1 then
  -- Common receiver reports magnetic bearing. Never silently mix it with true.
  distance=received:range()
  bearing=Radio.true_bearing(get,received)
  if bearing then
   steer=bearing
   if get('F22_NAV_OBS')>.5 then
    course=c;cross=course and distance and -math.sin(N.wrap(bearing-course))*distance
    steer=cross and course-clamp(math.atan(cross/lookahead),-math.pi/4,math.pi/4) or nil
   end
  end
  set('F22_NAV_FIX_TEXT',get('F22_TCN_TUNE_TEXT'))
  set('F22_NAV_STATUS_TEXT',bearing and (steer and 'TACAN' or 'TCN COURSE / NO RANGE')
   or distance and 'TCN DME ONLY' or 'TCN NO SIGNAL / REFERENCE')
  set('F22_NAV_DIST_TEXT',distance and string.format('DME %.1fNM',distance/1852) or 'DME --')
  set('F22_NAV_ALT_TEXT','');set('F22_NAV_TTG_TEXT','');set('F22_NAV_XTK_TEXT','')
 elseif source==2 then
  set('F22_NAV_FIX_TEXT',get('F22_ILS_TUNE_TEXT'))
  local loc,gs=received:ils()
  set('F22_NAV_STATUS_TEXT',loc~=nil and (gs~=nil and 'ILS LOC + GS' or 'ILS LOCALIZER')
   or gs~=nil and 'ILS GS / NO LOC' or 'ILS NO SIGNAL')
  set('F22_NAV_BRG_TEXT','');set('F22_NAV_DIST_TEXT','');set('F22_NAV_ALT_TEXT','');set('F22_NAV_TTG_TEXT','');set('F22_NAV_XTK_TEXT','')
  -- avILS is 0.6 * angular error (IDA update_LOC/update_Marker).
  -- Conventional +/-2.5 deg LOC and +/-0.7 deg GS display sensitivity.
  -- Approach is advisory; no unvalidated automatic localizer/glideslope coupling.
 end
 set('F22_NAV_GUIDANCE_VALID',bearing and 1 or 0)
 if bearing then
  set('HUD_NAV_BUG_LABEL',source==0 and ((s.waypoint.mark and'M'or'W')..math.abs(s.waypoint.id))or'T')
  local relative=math.deg(N.wrap(bearing-own.heading))
  set('HUD_NAV_BUG_VALID',distance and distance<1 and 0 or 1)
  set('HUD_NAV_BUG_DEG',clamp(relative,-15,15));set('HUD_NAV_BUG_EDGE',relative< -15 and -1 or (relative>15 and 1 or 0))
  set('F22_NAV_BRG_ROT',-math.rad(relative))
  set('F22_NAV_BRG_TEXT',reference~=nil and string.format('BRG %03d%s',math.floor(math.deg(bearing-reference)+.5)%360,suffix)or'BRG ---'..suffix)
  local vn,ve=get('EFM_HUD_VN'),get('EFM_HUD_VE')
  local track=get('EFM_HUD_VALID')>.5 and N.atan2(ve,vn) or own.heading
  local hud_steer=get('F22_NAV_OBS')>.5 and steer or bearing
  -- Lua's and/or idiom would turn a missing OBS solution into direct-to here.
  if get('F22_NAV_OBS')>.5 and not steer then hud_steer=nil end
  local hud_error=hud_steer and N.wrap(hud_steer-track) or 0
  set('HUD_NAV_STEER_VALID',hud_steer and get('HUD_FPM_VALID')>.5 and 1 or 0)
  set('HUD_NAV_STEER_ERROR',clamp(hud_error,-math.rad(8),math.rad(8)))
  set('HUD_NAV_STEER_MAG_DEG',math.abs(math.deg(hud_error)))
  set('F22_NAV_STEER_TRACK',steer and steer%(2*math.pi) or 0);set('F22_NAV_STEER_STAMP',get('F22_AP_CLOCK'))
  set('F22_NAV_STEER_VALID',ready and steer and 1 or 0)
 end
 if Radio.publish_cdi(set,source,bearing,course,cross) then
  set('F22_NAV_COURSE_ROT',N.wrap(own.heading-course))
  local text=reference~=nil and string.format('CRS %03d%s',math.floor(math.deg(course-reference)+.5)%360,suffix)
  set('F22_NAV_COURSE_TEXT',text or'CRS ---'..suffix)
  set('F22_NAV_TO_FROM',bearing and math.abs(N.wrap(bearing-course))<math.pi/2 and 'TO' or 'FROM')
 else set('F22_NAV_COURSE_TEXT','CRS --');set('F22_NAV_TO_FROM','')end
end

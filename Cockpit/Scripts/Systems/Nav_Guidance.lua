-- GPL-3.0-or-later. Navigation references and fly-over course guidance.
local N=dofile(LockOn_Options.script_path..'Systems/Nav_Computer.lua')
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
return function(get,set,own,s)
 local ready=get('F22_INS_MODEL_ENABLED')<.5 or get('F22_INS_READY')>.5
 local mag=get('F22_NAV_REFERENCE')>.5 and get('F22_MAG_VALID')>.5
 local variation=get('F22_MAG_VALID')>.5 and get('F22_MAG_DECL') or 0
 local reference=mag and variation or 0;local suffix=mag and 'M' or 'T'
 set('HUD_HEADING_REFERENCE',suffix)
 set('F22_NAV_GUIDANCE_VALID',0);set('F22_NAV_STEER_VALID',0);set('HUD_NAV_BUG_VALID',0);set('F22_NAV_CDI_VALID',0)
 set('HUD_NAV_STEER_VALID',0)
 set('F22_NAV_DISPLAY_VALID',0);set('HUD_ILS_LOC_VALID',0);set('HUD_ILS_GS_VALID',0)
 -- ILS reception is independent of TACAN/waypoint steering and IRS position.
 -- Explicit ILS selection enables acquisition in NAV; landing configuration
 -- enables received approach guidance even with TCN steering or A/G retained.
 local source=get('F22_NAV_SOURCE')
 local approach=get('MAIN_POWER')>.5 and (source==2 and get('HUD_MODE')==1 or get('HUD_LANDING_CONFIG')>.5)
 set('HUD_ILS_DISPLAY_ENABLE',approach and 1 or 0)
 local loc,gs=get('F22_ILS_LOC'),get('F22_ILS_GS')
 set('HUD_ILS_LOC_VALID',approach and get('F22_ILS_LOC_VALID')>.5 and N.finite(loc) and 1 or 0)
 set('HUD_ILS_GS_VALID',approach and get('F22_ILS_GS_VALID')>.5 and N.finite(gs) and 1 or 0)
 set('HUD_ILS_LOC',N.finite(loc) and clamp(loc/(.6*math.rad(2.5)),-1,1) or 0)
 set('HUD_ILS_GS',N.finite(gs) and clamp(-gs/(.6*math.rad(.7)),-1,1) or 0)
 set('HUD_HDG_BUG_VALID',own and get('MAIN_POWER')>.5 and 1 or 0)
 if not own then return end
 local hdg_delta=math.deg(N.wrap(math.rad(get('F22_AP_HEADING'))-own.heading))
 set('HUD_HDG_BUG_DEG',clamp(hdg_delta,-15,15));set('F22_NAV_HDG_BUG_ROT',-math.rad(hdg_delta))
 set('F22_NAV_COMPASS_ROT',(own.heading-reference)%(2*math.pi))
 set('F22_NAV_HEADING_TEXT',string.format('%03d%s',math.floor(math.deg(own.heading-reference)+.5)%360,suffix))
 if source~=0 then set('F22_NAV_DESIGNATED',0)end
 set('F22_NAV_DISPLAY_VALID',(source~=0 or s~=nil)and 1 or 0)
 if source~=0 or not ready then
  set('HUD_WP_CUE_VALID',0);set('HUD_WP_OFFSCREEN',0);set('HUD_WP_VALID',0)
 end
 if source==1 then
  set('HUD_WP_INFO',get('F22_TCN_TUNE_TEXT'));set('HUD_WP_TTG_TEXT','--:--:--')
 elseif source==2 then
  set('HUD_WP_INFO',get('F22_ILS_TUNE_TEXT'));set('HUD_WP_TTG_TEXT','--:--:--')
 elseif not ready then set('HUD_WP_INFO','IRS ALIGN');set('HUD_WP_TTG_TEXT','--:--:--');set('F22_NAV_STATUS_TEXT',get('F22_INS_STATUS_TEXT'))end
 local bearing,distance,course,cross,steer
 local lookahead=math.max(1852,(own.gs or 0)*25)
 local c=math.rad(get('F22_NAV_COURSE'))+reference
 if source==0 and s and ready then
  bearing=s.bearing;distance=s.distance;course=s.course;cross=s.cross
  if get('F22_NAV_OBS')>.5 then course=c;cross=-math.sin(N.wrap(bearing-course))*distance end
  steer=course and course-clamp(math.atan((cross or 0)/lookahead),-math.pi/4,math.pi/4) or bearing
  if s.along and s.along>s.length then steer=bearing end
 elseif source==1 then
  -- Common receiver reports magnetic bearing. Never silently mix it with true.
  if get('F22_TCN_BRG_VALID')>.5 and get('F22_MAG_VALID')>.5 then
   bearing=(get('F22_TCN_BRG_MAG')+variation)%(2*math.pi);steer=bearing
   if get('F22_TCN_RANGE_VALID')>.5 then distance=get('F22_TCN_RANGE_M') end
   if get('F22_NAV_OBS')>.5 and distance then
    course=c;cross=-math.sin(N.wrap(bearing-course))*distance
    steer=course-clamp(math.atan(cross/lookahead),-math.pi/4,math.pi/4)
   end
  end
  set('F22_NAV_FIX_TEXT',get('F22_TCN_TUNE_TEXT'));set('F22_NAV_STATUS_TEXT',bearing and 'TACAN' or 'TCN NO SIGNAL / REFERENCE')
  set('F22_NAV_DIST_TEXT',distance and string.format('DME %.1fNM',distance/1852) or 'DME --')
  set('F22_NAV_ALT_TEXT','');set('F22_NAV_TTG_TEXT','');set('F22_NAV_XTK_TEXT','')
 elseif source==2 then
  set('F22_NAV_FIX_TEXT',get('F22_ILS_TUNE_TEXT'))
  set('F22_NAV_STATUS_TEXT',get('F22_ILS_LOC_VALID')>.5 and (get('F22_ILS_GS_VALID')>.5 and 'ILS LOC + GS' or 'ILS LOCALIZER') or 'ILS NO SIGNAL')
  set('F22_NAV_BRG_TEXT','');set('F22_NAV_DIST_TEXT','');set('F22_NAV_ALT_TEXT','');set('F22_NAV_TTG_TEXT','');set('F22_NAV_XTK_TEXT','')
  -- avILS is 0.6 * angular error (IDA update_LOC/update_Marker).
  -- Conventional +/-2.5 deg LOC and +/-0.7 deg GS display sensitivity.
  -- Approach is advisory; no unvalidated automatic localizer/glideslope coupling.
 end
 set('F22_NAV_GUIDANCE_VALID',bearing and 1 or 0)
 if bearing then
  set('HUD_NAV_BUG_LABEL',source==0 and ('W'..s.waypoint.id) or 'T')
  local relative=math.deg(N.wrap(bearing-own.heading))
  set('HUD_NAV_BUG_VALID',distance and distance<1 and 0 or 1)
  set('HUD_NAV_BUG_DEG',clamp(relative,-15,15));set('HUD_NAV_BUG_EDGE',relative< -15 and -1 or (relative>15 and 1 or 0))
  set('F22_NAV_BRG_ROT',-math.rad(relative));set('F22_NAV_BRG_TEXT',string.format('BRG %03d%s',math.floor(math.deg(bearing-reference)+.5)%360,suffix))
  local vn,ve=get('EFM_HUD_VN'),get('EFM_HUD_VE')
  local track=get('EFM_HUD_VALID')>.5 and N.atan2(ve,vn) or own.heading
  local hud_steer=get('F22_NAV_OBS')>.5 and steer or bearing
  local hud_error=N.wrap(hud_steer-track)
  set('HUD_NAV_STEER_VALID',get('HUD_FPM_VALID')>.5 and 1 or 0)
  set('HUD_NAV_STEER_ERROR',clamp(hud_error,-math.rad(8),math.rad(8)))
  set('HUD_NAV_STEER_MAG_DEG',math.abs(math.deg(hud_error)))
  set('F22_NAV_STEER_TRACK',steer%(2*math.pi));set('F22_NAV_STEER_STAMP',get('F22_AP_CLOCK'))
  set('F22_NAV_STEER_VALID',ready and 1 or 0)
 end
 if course and cross then
  set('F22_NAV_CDI_VALID',1);set('F22_NAV_CDI',clamp(-cross/(2*1852),-1,1))
  set('F22_NAV_COURSE_ROT',N.wrap(own.heading-course))
  set('F22_NAV_COURSE_TEXT',string.format('CRS %03d%s',math.floor(math.deg(course-reference)+.5)%360,suffix))
  set('F22_NAV_TO_FROM',bearing and math.abs(N.wrap(bearing-course))<math.pi/2 and 'TO' or 'FROM')
 elseif source~=0 then set('F22_NAV_COURSE_TEXT','CRS --');set('F22_NAV_TO_FROM','')end
end

-- GPL-3.0-or-later. A/G mode of our one common radar; coordinates require returns.
local Model = dofile(LockOn_Options.script_path .. "Systems/AG_Radar_Computer.lua")
local Display = dofile(LockOn_Options.script_path .. "Systems/Radar_Display.lua")
local Modes=dofile(LockOn_Options.script_path .. "Systems/AG_Radar_Modes.lua")
local Collection=dofile(LockOn_Options.script_path .. "Systems/AG_Radar_Collection.lua")
local Protocol=dofile(LockOn_Options.script_path .. "Systems/AG_Radar_Protocol.lua")
local TargetSnapshot=dofile(LockOn_Options.script_path .. "Systems/AG_Target_Snapshot.lua")
local M = {}
local function search_family(mode)
 if mode==1 then return 1 end
 if Modes.sea(mode) then return 4 end
 return Modes.search(mode) and 2 or 0
end
local function matches_family(family,get)
 local map,sea=get("F22_AG_NATIVE_MAP")==1,get("F22_AG_NATIVE_SEA")==1
 if family==1 then return map and not sea end
 if family==4 then return sea and not map end
 return family==2 and not map and not sea
end
local native_prefix="F22_AG_NATIVE_TRACK_"
local function track_identity(get,now)
    local id,kind,stamp=get(native_prefix.."ID"),get(native_prefix.."TYPE"),get(native_prefix.."TIME")
    if not Model.finite(id) or id<0 or id%1~=0 or not Model.fresh(now,stamp,5.25) or now<stamp then return end
    if not ((kind==3 and id==0) or ((kind==1 or kind==2) and id>0)) then return end
    return id,kind,stamp
end
local function track_motion(get)
    local vn,vu,ve=get(native_prefix.."VN"),get(native_prefix.."VU"),get(native_prefix.."VE")
    local valid=get(native_prefix.."VELOCITY_VALID")==1 and Model.finite(vn) and Model.finite(vu) and Model.finite(ve)
    valid=valid and vn*vn+vu*vu+ve*ve<=1500^2
    return valid,vn,vu,ve
end
local function native_track(get,now)
    local id,kind,stamp=track_identity(get,now)
    if not id then return end
    local n,u,e=get(native_prefix.."N"),get(native_prefix.."U"),get(native_prefix.."E")
    if not Model.finite(n) or not Model.finite(u) or not Model.finite(e) then return end
    local motion,vn,vu,ve=track_motion(get)
    local age=math.max(0,now-stamp)
    local display={north=n,altitude=u,east=e}
    if motion then display.north=n+vn*age;display.altitude=u+vu*age;display.east=e+ve*age end
    local associated=kind==3 or get(native_prefix.."ASSOCIATION_VALID")==1
    motion=motion and associated and kind~=3
    return {id=id,kind=kind,stamp=stamp,measurement={north=n,altitude=u,east=e},display=display,
        association_valid=associated,motion_valid=motion,speed=motion and math.sqrt(vn*vn+ve*ve)*1.943844492440605 or 0,
        heading=motion and math.atan2(ve,vn) or 0,age=age}
end
function M.new(get, put, native_command)
	local ok, terrain = pcall(require, "terrain")
	local protocol=Protocol.new(get,put)
	put("F22_AG_MODE",1);put("F22_AG_MAP_VIDEO_SHOW",0);put("F22_AG_INTERLEAVE",0)
	put("F22_AG_CURSOR_PREVIEW",0);put("F22_AG_VIDEO_HOLD",0);put("F22_AG_FIXED_TRACK",0)
	put("F22_AG_TRACK_VALID",0);put("F22_AG_TRACK_REQUEST_ID",0)
	put("F22_AG_TRACK_TYPE",0);put("F22_AG_TRACK_MOTION_VALID",0)
	put("F22_AG_TRACK_REQUEST_ACTIVE",0);put("F22_AG_TRACK_REQUEST_SEQUENCE",0)
	put("F22_AG_DESIGNATION_VALID",0);put("F22_AG_DESIGNATION_SEQUENCE",0)
	put("F22_AG_DESIGNATION_LIVE",0)
 for _,n in ipairs({'VIDEO_FAN','VIDEO_FROZEN','SILENT','ACTIVE','ACTIVE_AVAILABLE','EXPANSION','EXP_PENDING','DATA','DECLUTTER',
  'PLOT_SHOW','EXP1_AVAILABLE','BEAM_AVAILABLE','CURSOR_SHOW','OPTIONS_AVAILABLE','RANGE_AVAILABLE','INTL_AVAILABLE','FAST_AVAILABLE','CORRAL_SHOW','FAST','VIDEO_EXPANSION','VIDEO_CENTER_M',
  'VIDEO_SPAN_M','VIDEO_ANTENNA_DEG','VIDEO_EPOCH','VIDEO_STABILIZED','VIDEO_PATCH_N','VIDEO_PATCH_U','VIDEO_PATCH_E',
  'VIDEO_PATCH_AZ','VIDEO_PATCH_DISTANCE','AGR_VALID','AGR_RANGE_FT','AGR_VELOCITY_KT'})do put('F22_AG_'..n,0)end
 put('F22_AG_VIDEO_FAN',1);put('F22_AG_GAIN_INDEX',5);put('F22_AG_VIDEO_QUALIFIED',1)
	for i=0,60 do put("F22_AG_CURSOR_ARC_"..i.."_X",0);put("F22_AG_CURSOR_ARC_"..i.."_Y",0)end
	put("F22_AG_CURSOR_AZ_X",0);put("F22_AG_CURSOR_AZ_Y",0)
	for i=1,64 do
		local prefix="F22_AG_GMT_DISPLAY_"..i.."_"
		for _,key in ipairs({"VALID","X","Y","ALPHA"})do put(prefix..key,0)end
	end
	return setmetatable(
		{ get = protocol.get, put = put, protocol = protocol, native_command = native_command, model = Model.new(), terrain = ok and terrain or nil,
		  operating = false, video_gain = .5, video_erase = 1, interleave = false,
          sweep_phase=0, sweep_direction=1, track_sequence=0, controls=Modes.new(), collection=Collection.new(get) },
		{ __index = M }
	)
end
function M:cancel_track()
	if self.model.mode==3 then self.model.mode=2 elseif self.model.mode==5 then self.model.mode=4 end
	self.selected_id=nil;self.track_requested=false;self.last_track_point=nil;self.last_track_designation=nil
	self.track_sequence=self.track_sequence%16777215+1
	self.put("F22_AG_TRACK_REQUEST_ACTIVE",0);self.put("F22_AG_TRACK_REQUEST_ID",0)
	self.put("F22_AG_TRACK_REQUEST_SEQUENCE",self.track_sequence)
end
function M:cancel_preview()
	self.preview_pose=nil;self.preview_view=nil
	self.preview_kind=nil
	self.put("F22_AG_CURSOR_PREVIEW",0)
	self.put("F22_AG_VIDEO_HOLD",self.video_frozen and 1 or 0)
end
function M:cursor_point(now)
	if Modes.ranging(self.model.mode)or (self.controls.expansion>0 and (not self.model.exp_view or not self.model.exp_view.qualified))then return end
	local m,c=self.model,self.controls
 if self.get('F22_AG_VIDEO_REFERENCE_SCHEMA')>=2 and
  (self.get('F22_AG_VIDEO_REFERENCE_VALID')<.5 or
   self.get('F22_AG_VIDEO_REFERENCE_MODE')~=m.mode or
   self.get('F22_AG_VIDEO_REFERENCE_RANGE_NM')~=m.range_nm or
   self.get('F22_AG_VIDEO_REFERENCE_EXPANSION')~=c.expansion or
   self.get('F22_AG_VIDEO_REFERENCE_EPOCH')~=(c.epoch or 0))then return end
 local qualified=Modes.search(self.model.mode) or self.get("F22_AG_VIDEO_SOURCE_PRESENT")<.5 or
		(self.get("F22_AG_VIDEO_READY")>.5 and self.get("F22_AG_VIDEO_GEOMETRY_QUALIFIED")>.5)
	if (not self.model.exp_view or self.model.exp_view.qualified)and self.operating and self.get("F22_AG_RADAR_NATIVE_READY")>.5 and self.pose and qualified and
		Model.fresh(now,self.update_time,Model.snapshot_seconds) then
		return self.model:point(self.pose,self.terrain)
	end
end
function M:begin_track(candidate, now)
	local expected = self.preview_kind == "acquire_begin" or self.preview_kind == "designate_begin"
	if self.controls.silent or self.get("F22_AG_GMT_READY") < .5 or
		(self.preview_kind and not expected) then return end
	local hit = self.model:mover_under_cursor(self.pose, now)
	if hit then candidate = hit.display end
	self:cancel_preview()
	self:hold_image(false)
	-- Acquisition is a coordinate cue, never a truth-ID selection. The native
	-- sensor must illuminate and measure an object before declaring a track.
	-- Keep the expanded patch while the native acquisition completes.
	self:cancel_track()
	if self.get("F22_AG_DESIGNATION_VALID") > .5 then
		self.model.sequence = self.model.sequence + 1
		self.put("F22_AG_DESIGNATION_VALID", 0)
		self.put("F22_AG_DESIGNATION_SEQUENCE", self.model.sequence)
	end
	self.track_requested = true
	self.track_requested_at = now
	self.put("F22_AG_TRACK_REQUEST_NORTH", candidate.north)
	self.put("F22_AG_TRACK_REQUEST_ALTITUDE", candidate.altitude)
	self.put("F22_AG_TRACK_REQUEST_EAST", candidate.east)
	self.put("F22_AG_TRACK_REQUEST_ACTIVE", 1)
	self.put("F22_AG_TRACK_REQUEST_SEQUENCE", self.track_sequence)
end
function M:command(name, value, powered, now)
	local m = self.model
	if not Model.finite(value) then return end
	if name == "axis_x" then
		m.slew_x = value
		return
	end
	if name == "axis_y" then
		m.slew_y = value
		return
	end
	if value <= 0 then
		return
	end
	if name=="preview_cancel" then self:cancel_preview();self.controls.pending=0;return end
	if self:control_command(name,powered,now)then return end
	if name=="designate_begin" or name=="acquire_begin" then
		if powered and self:cursor_point(now) then
			self.preview_pose={};for k,v in pairs(self.pose)do self.preview_pose[k]=v end
			self.preview_view=self.model.exp_view
			self.preview_kind=name
			self.put("F22_AG_CURSOR_PREVIEW",1);self.put("F22_AG_VIDEO_HOLD",1)
		end
		return
	end
	if name=="designate_end" then
		if self.preview_kind=="designate_begin" then self:command("designate",1,powered,now) end
		self:cancel_preview();return
	end
	if (self.video_frozen or self.preview_pose or self.controls.expansion>0) and (name=="range_up" or name=="range_down" or name=="azimuth")then return end
	if name=="rws" or name=="tws" or name=="toggle" then
		self:cancel_preview()
		m.mode=name=="rws" and 1 or name=="tws" and 2 or (m.mode==1 and 2 or 1)
		self:cancel_track()
		if m.mode==2 and m.width==120 then m.width=90 end
		return
	end
	if name=="interrogate" or name=="swap_targets" then if Modes.search(m.mode)and self.controls.expansion==0 then self.interleave=not self.interleave end;return end
	if name == "elevation_up" then self.controls.antenna=math.min(45,self.controls.antenna+1) end
	if name == "elevation_down" then self.controls.antenna=math.max(-45,self.controls.antenna-1) end
	if name == "vertical_span" then
		self:cancel_preview()
		self.video_frozen = not self.video_frozen
		self.frozen_pose=nil;self.frozen_view=nil
        if not self.video_frozen and self.pending_autorange then self:autorange(self.pending_autorange);self.pending_autorange=nil end
		if self.video_frozen and self.pose then
			self.frozen_pose={};for k,v in pairs(self.pose)do self.frozen_pose[k]=v end
			self.frozen_view=self.model.exp_view
		end
		self.put("F22_AG_RADAR_CANDIDATE", 0)
	end
	if name == "recenter" then
		m.cursor_az = 0
		m.cursor_fraction = 0.5
		m.exp_x, m.exp_y = 0, 0
	end
	if m.exp_view and ({cursor_left=true,cursor_right=true,cursor_up=true,cursor_down=true})[name]then
		m.exp_x=math.max(-.8,math.min(.8,(m.exp_x or 0)+(name=="cursor_right"and .04 or name=="cursor_left"and -.04 or 0)))
		m.exp_y=math.max(-.73,math.min(.73,(m.exp_y or 0)+(name=="cursor_up"and .04 or name=="cursor_down"and -.04 or 0)))
		return
	end
	if name == "cursor_left" then
		m.cursor_az = m.cursor_az - math.rad(2)
	end
	if name == "cursor_right" then
		m.cursor_az = m.cursor_az + math.rad(2)
	end
	if name == "cursor_up" then
		m.cursor_fraction = math.min(0.95, m.cursor_fraction + 0.025)
	end
	if name == "cursor_down" then
		m.cursor_fraction = math.max(0.05, m.cursor_fraction - 0.025)
	end
	if name == "range_up" then
		m.range_nm = Modes.range_step(m.mode,m.range_nm,1)
	end
	if name == "range_down" then
		m.range_nm = Modes.range_step(m.mode,m.range_nm,-1)
	end
	if name == "azimuth" then
		local widths=(m.mode==1 or Modes.sea(m.mode))and {120,90,45,20}or {90,45,20}
		local next_index=1;for i,w in ipairs(widths)do if m.width==w then next_index=i%#widths+1 end end
		m.width=widths[next_index]
	end
	if name == "recenter" or name == "cursor_left" or name == "cursor_right" or name == "cursor_up" or
		name == "cursor_down" or name == "range_up" or name == "range_down" or name == "azimuth" then
		m:slew(0)
		self.put("F22_AG_RADAR_CANDIDATE", 0)
	end
	if not powered then
		return
	end
	if name == "undesignate" or name == "clear_secondary" then
		self.pending_autorange=nil;self:cancel_preview();self.controls.pending=0;self.controls.expansion=0;self.controls.patch=nil;m.exp_view=nil
		self:cancel_track();if m.mode==3 then m.mode=2 elseif m.mode==5 then m.mode=4 end
		self.put("F22_AG_DESIGNATION_VALID", 0)
		m.sequence = m.sequence%16777215 + 1
		self.put("F22_AG_DESIGNATION_SEQUENCE", m.sequence)
		if log and log.write then
			log.write("F22_AG_UNDESIGNATE",log.INFO,string.format(
				"t=%.3f mode=%d frozen=%d designation=0 sequence=%d",
				now or m.clock,m.mode,self.video_frozen and 1 or 0,m.sequence))
		end
	elseif name == "designate" or name == "acquire" then
		-- A command can still arrive when the activity callback has stopped.
		-- Read an independent clock, never renew age from the cached model clock.
		if now == nil and type(get_model_time) == "function" then
			local ok, value = pcall(get_model_time)
			if ok then now = value end
		end
		-- MAP designation is a georeferenced terrain coordinate under the TDC.
		-- Anonymous air-radar NOISE records are not a prerequisite for it.
		local candidate = self:cursor_point(now)
		if not candidate then
				self.put("F22_AG_RADAR_CANDIDATE", 0)
			return
		end
		if self.controls.pending>0 then
			self:select_expansion(candidate);return
		end
		if name == "acquire" or Modes.search(m.mode) then
			self:begin_track(candidate, now)
			return
		end
		self:cancel_track();if m.mode==3 then m.mode=2 elseif m.mode==5 then m.mode=4 end
		if self.controls.expansion==0 then
			if self.video_frozen then self.pending_autorange=candidate else self:autorange(candidate)end
		elseif self.controls.expansion==1 then self.controls.patch=candidate;self.controls.stabilized=true end
		self.put("F22_AG_RADAR_CANDIDATE", 1)
		self:designate_point(candidate,now,3)
		-- This is a completed coordinate designation. Hornet 49FEE0 begins a
		-- temporary TDC preview; 4A2B80 clears that hold on release/handoff.
		-- Do not turn a completed designation into the separate FRZ function.
		if log and log.write then
			log.write("F22_AG_MAP_DESIGNATE",log.INFO,string.format(
				"t=%.3f mode=%d frozen=%d designation=1 sequence=%d north=%.2f east=%.2f",
				now,m.mode,self.video_frozen and 1 or 0,m.sequence,candidate.north,candidate.east))
		end
	end
end
function M:designate_point(p,now,kind)
	local put,m=self.put,self.model
	if not Model.finite(now) or now<0 or not Model.finite(p.north) or not Model.finite(p.altitude)
		or not Model.finite(p.east) or self.protocol.epoch<1 then return false end
	put("F22_AG_DESIGNATION_NORTH",p.north);put("F22_AG_DESIGNATION_ALTITUDE",p.altitude);put("F22_AG_DESIGNATION_EAST",p.east)
	put("F22_AG_DESIGNATION_SCHEMA",1);put("F22_AG_DESIGNATION_TIME",now)
	put("F22_AG_DESIGNATION_EPOCH",self.protocol.epoch)
	put("F22_AG_DESIGNATION_REQUEST",self.track_sequence);put("F22_AG_DESIGNATION_TYPE",kind or 3)
	put("F22_AG_DESIGNATION_LIVE",kind and kind~=3 and 1 or 0)
	put("F22_AG_DESIGNATION_VALID",1);m.sequence=m.sequence%16777215+1;put("F22_AG_DESIGNATION_SEQUENCE",m.sequence)
	self.last_track_designation=now
	self.last_track_point={north=p.north,altitude=p.altitude,east=p.east}
	return true
end
function M:update(pose, now, dt, powered, ready)
	local get, put, m = self.get, self.put, self.model
	local map_pose = Model.video_pose(pose)
	self.live_pose=map_pose
	self:expanded_view(map_pose)
	-- Overlay and TDC coordinates use the native sweep's source frame. Reading
	-- a newer INS pose here used to drag the cursor across retained terrain.
	if map_pose and (m.mode==1 or self.interleave) and get("F22_AG_VIDEO_REFERENCE_VALID")>.5 then
		map_pose={north=get("F22_AG_VIDEO_REFERENCE_NORTH"),altitude=get("F22_AG_VIDEO_REFERENCE_ALTITUDE"),
			east=get("F22_AG_VIDEO_REFERENCE_EAST"),heading=get("F22_AG_VIDEO_REFERENCE_HEADING"),pitch=0,roll=0}
	end
	self.update_time = now
	map_pose=self.preview_pose or (self.video_frozen and self.frozen_pose) or map_pose
	m.exp_view=self.preview_view or (self.video_frozen and self.frozen_view)or m.exp_view
	self.pose = map_pose
	if now < m.clock then
		m.sequence = 0
		put("F22_AG_DESIGNATION_SEQUENCE", 0)
		put("F22_AG_DESIGNATION_VALID", 0)
		self.video_erase = self.video_erase + 1
		self.video_frozen, self.video_frame = false, nil
		self.frozen_pose=nil;self:cancel_preview()
		self:cancel_track();self.sweep_phase=0;self.sweep_direction=1;self.controls=Modes.new();m.exp_view=nil
	end
	-- The retired noise observer used to advance this lifecycle clock. Keep
	-- rollback cancellation owned by the active ground computer itself.
	m.clock = now
	put("F22_AG_RADAR_PAGE", 1)
	put("F22_AG_RADAR_RANGE_NM", m.range_nm)
	put("F22_AG_RADAR_WIDTH_DEG", m.width)
	put("F22_AG_MODE",m.mode);put("F22_AG_INTERLEAVE",self.interleave and 1 or 0)
	local operating = powered and ready and self.protocol.ready and get("F22_AG_RADAR_NATIVE_READY") > 0.5 and pose ~= nil
	self.operating = operating
	if not operating then
		self.controls.active=false;self.controls.active_end=nil;self.controls.pending=0
		self:cancel_preview();if self.track_requested or self.selected_id then self:cancel_track() end
	end
	put("F22_AG_RADAR_OPERATING", operating and 1 or 0)
	for _, n in ipairs({
		"F22_RADAR_STT_VALID",
		"F22_RADAR_SELECTED_VALID",
		"F22_RADAR_DESIGNATION_VALID",
		"F22_TWS_ACTIVE",
		"F22_RADAR_SUPPORT_ENABLED",
		"F22_TWS_TARGET_ID",
		"F22_RADAR_WEAPON_TARGET_ID",
	}) do
		put(n, 0)
	end
	-- Keep the shared payload observer available; disable airborne responder
	-- selection/support through its real publication protocol, not its API gate.
	put("F22_RADAR_FC_ENABLE", 1)
	put("F22_TWS_PUBLISH_SEQUENCE", get("F22_TWS_PUBLISH_SEQUENCE") + 1)
	local mode = get("F22N_RADAR_MODE")
	if mode == 3 then
		self.native_command(509)
	elseif mode == 2 then
		self.native_command(510)
	end
	m:slew(dt)
	local image_selectable = (get("F22_AG_VIDEO_SOURCE_PRESENT") < .5 or
		(get("F22_AG_VIDEO_READY") > .5 and get("F22_AG_VIDEO_GEOMETRY_QUALIFIED") > .5))
	put("F22_AG_RADAR_CANDIDATE", operating and image_selectable and map_pose and m:point(map_pose,self.terrain) and 1 or 0)
	local movers={}
	local family=search_family(m.mode)
	self.search_family=family
	if operating and get("F22_AG_GMT_READY")>.5 and matches_family(family,get) then
		for i=1,math.min(64,get("F22_AG_GMT_COUNT"))do
			local p="F22_AG_GMT_"..i.."_"
			movers[#movers+1]={id=get(p.."ID"),north=get(p.."N"),altitude=get(p.."U"),east=get(p.."E"),
				vn=get(p.."VN"),vu=get(p.."VU"),ve=get(p.."VE"),stamp=get(p.."TIME"),az=get(p.."AZ"),range=get(p.."RANGE"),
				association_valid=get(p.."ASSOCIATION_VALID")==1}
		end
	end
	local mover
 if self.controls.silent and not self.controls.active and self.video_frozen and self.frozen_family==family then
  m.movers=self.frozen_movers or {}
 else mover=map_pose and m:observe_movers(movers,map_pose,now)end
	local selected
	for i=1,64 do
		local r=m.movers[i];local prefix="F22_AG_GMT_DISPLAY_"..i.."_"
		put(prefix.."VALID",r and (m.mode==1 or Modes.search(m.mode)) and operating and 1 or 0)
		if r then
			put(prefix.."X",r.x);put(prefix.."Y",r.y);put(prefix.."ALPHA",1-.6*r.age/6)
		end
	end
	local owned=self.track_requested and get("F22_AG_NATIVE_TRACK_REQUEST_SEQUENCE")==self.track_sequence
	local pending=self.track_requested and not self.selected_id and Model.fresh(now,self.track_requested_at,1)
	local acquiring=operating and (pending or (owned and get("F22_AG_NATIVE_TRACK_ACQUIRING")>.5))
	put("F22_AG_TRACK_ACQUIRING",acquiring and 1 or 0)
	if operating and owned and get("F22_AG_NATIVE_TRACK_VALID")>.5 and map_pose then
		selected = native_track(get, now)
	end
	if selected then
        if self.controls.expansion>0 then
            self.controls.patch={north=selected.display.north,altitude=selected.display.altitude,east=selected.display.east}
            self.controls.stabilized=true
            self:expanded_view(self.live_pose)
        end
		selected.x,selected.y=m:project(selected.display,map_pose)
		self.selected_id=selected.id
		-- Native type3 is a terrain FTT fallback after object acquisition
		-- fails. Never advertise it as a confirmed moving-object GMTT/SSTT.
		if selected.kind == 3 then
			if m.mode == 3 then m.mode = 2 elseif m.mode == 5 then m.mode = 4 end
		elseif selected.id > 0 then
			if Modes.sea(m.mode) then m.mode=5 elseif m.mode==2 then m.mode=3 end
		end
	end
	put("F22_AG_TRACK_VALID",selected and 1 or 0);put("F22_AG_TRACK_ID",selected and selected.id or 0)
	put("F22_AG_TRACK_TYPE",selected and selected.kind or 0)
    put("F22_AG_TRACK_MOTION_VALID",selected and selected.motion_valid and 1 or 0)
	put("F22_AG_FIXED_TRACK",selected and (selected.kind==3 or m.mode==1) and 1 or 0)
	if selected then
		put("F22_AG_TRACK_X",selected.x);put("F22_AG_TRACK_Y",selected.y)
		put("F22_AG_TRACK_SPEED",selected.speed);put("F22_AG_TRACK_HEADING",math.deg(selected.heading)%360)
		put("F22_AG_TRACK_VECTOR_ROT",-get("F22_AG_NATIVE_TRACK_ASPECT"))
		put("F22_AG_TRACK_COAST",get("F22_AG_NATIVE_TRACK_MEMORY"))
		if selected.association_valid and get("F22_AG_NATIVE_TRACK_MEMORY")<.5
			and (not self.last_track_designation or selected.stamp-self.last_track_designation>=.2) then
			self:designate_point(selected.measurement,selected.stamp,selected.kind)
		end
	elseif self.selected_id and not acquiring then
		self:cancel_track();if m.mode==3 then m.mode=2 elseif m.mode==5 then m.mode=4 end
		put("F22_AG_DESIGNATION_VALID",0);m.sequence=m.sequence%16777215+1;put("F22_AG_DESIGNATION_SEQUENCE",m.sequence)
	elseif self.track_requested and not acquiring then
		self:cancel_track()
	end
	put("F22_AG_DESIGNATION_LIVE",selected and selected.kind~=3 and selected.association_valid
		and get("F22_AG_NATIVE_TRACK_MEMORY")==0 and 1 or 0)
	if Modes.search(m.mode)then put("F22_AG_RADAR_CANDIDATE",operating and map_pose and 1 or 0)end
	local cursor = map_pose and m:point(map_pose, self.terrain)
	local scan = m:scan_plan(0)
	-- The video is an earth-level heading-up map. Its sector uses map azimuth;
	-- the separate physical acquisition volume below needs aircraft-body LOS.
	-- TDC movement designates a coordinate; it does not continuously slew
	-- the complete MAP camera. Search remains centered on the aircraft nose.
	local ev=m.exp_view
	local video_scan=ev and {az=ev.az,half_az=math.rad(ev.fov)/2}or m:scan_plan(0)
	if cursor then
		local x, y = m:project(cursor, map_pose)
		put("F22_AG_CURSOR_X", x)
		put("F22_AG_CURSOR_Y", y)
		put("F22_AG_CURSOR_AZ_X",math.sin(m.cursor_az)*1.65)
		put("F22_AG_CURSOR_AZ_Y",-.76+math.cos(m.cursor_az)*1.52)
		for i=0,60 do
			local a=math.rad(-60+2*i)
			put("F22_AG_CURSOR_ARC_"..i.."_X",math.sin(a)*m.cursor_fraction*1.65)
			put("F22_AG_CURSOR_ARC_"..i.."_Y",-.76+math.cos(a)*m.cursor_fraction*1.52)
		end
		local _, az = Display.body_observation(cursor, pose, 0)
		scan = m:scan_plan(az)
	end
	put("F22_AG_RADAR_SCAN_CENTER_AZ_DEG", math.deg(video_scan.az))
	put("F22_AG_RADAR_SCAN_AZ_DEG", math.deg(scan.half_az * 2))
	put("F22_AG_RADAR_SCAN_LIMITED", scan.limited and 1 or 0)
	put("F22_AG_RADAR_CURSOR_AZ_COVERED", cursor and scan.cursor_covered and 1 or 0)
	-- One shared scene renderer; the AESA job width is independent of the
	-- fixed 120-degree display field. Narrowing AZ never magnifies the image.
	-- Steering/narrowing the illuminated sector does not change pixel mapping.
	-- Preserve accumulated video; only a range or operating-state change erases.
	local hold=self.video_frozen or self.preview_pose~=nil
	local video_key = tostring(m.range_nm)..":"..tostring(m.width)..":"..tostring(m.mode)..":"..self.controls.expansion..":"..tostring(self.controls.epoch or 0)
	if (not hold and self.video_key ~= video_key) or self.video_operating ~= operating then
		self.video_operating = operating
		self.video_key = video_key
		self.video_erase = self.video_erase + 1
		self.video_frame = nil
		if not operating then self.video_frozen=false;self.frozen_pose=nil end
	end
	if pose then
		-- Image hold retains its frame while the independent AESA still senses.
		local credit=self.collection:sample(now)
		if operating then
			local c=self.controls
			if Modes.advance(c,not c.silent or c.active,credit)then
			 c.active=false;c.active_end=nil;self.video_frozen=true;self.frozen_pose=map_pose;self.frozen_view=m.exp_view;self.frozen_movers=m.movers;self.frozen_family=family;hold=true
			end
			self.sweep_phase=c.sweep;self.sweep_direction=c.direction
		end
		local direction=1
		local width=ev and ev.fov or m.width
		local angle=math.deg(self.get("F22_AESA_SURFACE_AZ"))
		local progress=math.max(0,math.min(1,(angle-math.deg(video_scan.az))/width+.5))
		-- Partial completed RF work refreshes the image. Flooring here retained
		-- the old texture until an entire multi-axis volume had completed.
		put("F22_AG_VIDEO_COLLECTION",self.controls.units)
		put("F22_AG_SENSOR_SCAN_AZ_DEG",angle);put("F22_AG_SENSOR_SCAN_DIRECTION",direction)
		local frame = self.video_frame
		if not hold or not frame then
			frame = { north=map_pose.north, altitude=map_pose.altitude, east=map_pose.east,
				heading=map_pose.heading, direction=direction, fraction=progress, angle=angle }
			self.video_frame = frame
		end
		for _, key in ipairs({"north", "altitude", "east", "heading"}) do
			put("F22_AG_VIDEO_" .. string.upper(key), frame[key])
		end
		put("F22_AG_VIDEO_SCAN_DIRECTION", frame.direction)
		put("F22_AG_VIDEO_SCAN_FRACTION", math.max(0, math.min(1, frame.fraction)))
		put("F22_AG_VIDEO_SCAN_AZ_DEG", frame.angle)
	end
	put("F22_AG_VIDEO_TIME", now)
	-- GMT and MAP share the renderer and the same finite AESA service budget.
	put("F22_AG_VIDEO_ENABLE",operating and m.mode~=7 and 1 or 0)
	put("F22_AG_MAP_VIDEO_SHOW",m.mode==7 and 0 or 1)
	put("F22_AG_VIDEO_FOV_DEG",ev and ev.fov or m.width)
	self:publish_controls(operating,ev,hold)
	self.video_gain=self.controls.gain/10
	put("F22_AG_VIDEO_GAIN", self.video_gain)
	put("F22_AG_VIDEO_GAIN_PCT", self.video_gain * 100)
	put("F22_AG_VIDEO_FROZEN",self.video_frozen and not self.preview_pose and 1 or 0)
	put("F22_AG_VIDEO_HOLD",hold and 1 or 0)
	put("F22_AG_VIDEO_ERASE_SEQUENCE", self.video_erase)
	put("F22_AG_MODE",m.mode)
	-- Persist production inputs and native/GPU measurements in every A/G flight.
	-- A parameter callback is deliberately not named a successful scan.
	if log and log.write and (not self.next_diagnostic or now >= self.next_diagnostic or now < self.next_diagnostic - 2) then
		self.next_diagnostic = now + 1
		local row = {string.format("t=%.3f operating=%d range=%.0f width=%.0f gain=%.3f erase=%.0f", now, operating and 1 or 0, m.range_nm, m.width, self.video_gain, self.video_erase)}
		for _,name in ipairs({"RADAR_NATIVE_READY","RADAR_NATIVE_REASON","VIDEO_READY","VIDEO_REASON","VIDEO_ENABLE",
			"EXPANSION","FAST","VIDEO_FOV_DEG","VIDEO_CENTER_M","VIDEO_SPAN_M","VIDEO_QUALIFIED",
			"VIDEO_FROZEN","DESIGNATION_VALID","DESIGNATION_SEQUENCE","RADAR_CANDIDATE","TRACK_REQUEST_ACTIVE","TRACK_REQUEST_SEQUENCE",
			"VIDEO_TIME","VIDEO_NORTH","VIDEO_ALTITUDE","VIDEO_EAST","VIDEO_HEADING","VIDEO_SCAN_DIRECTION","VIDEO_SCAN_FRACTION",
			"VIDEO_PROBE_FORWARD_M","VIDEO_PROBE_RIGHT_M","VIDEO_PROBE_UP_M","VIDEO_PROBE_EPOCH","VIDEO_RENDER_NORTH","VIDEO_RENDER_ALTITUDE","VIDEO_RENDER_EAST","VIDEO_RENDER_HEADING","VIDEO_MOTION_AGE_MS",
			"VIDEO_CONDITION_CALLS","VIDEO_CONDITION_ACCEPTED","VIDEO_CAMERA_CALLS","VIDEO_CAMERA_ACCEPTED",
			"VIDEO_PARAMETER_CALLS","VIDEO_PARAMETER_REJECTED","VIDEO_ERASE_CALLS","VIDEO_PRESET_CALLS",
			"VIDEO_CLOCK_CHECKS","VIDEO_FUTURE_REJECTS","VIDEO_STALE_REJECTS","VIDEO_CLOCK_DELTA_MS",
			"VIDEO_IMAGE_CAPTURES","VIDEO_RBM_RESTARTS","VIDEO_DBS_REQUESTS",
			"VIDEO_GPU_STATUS","VIDEO_GPU_TARGET","VIDEO_GPU_RENDER_THREAD","VIDEO_GPU_WIDTH","VIDEO_GPU_HEIGHT","VIDEO_GPU_FORMAT","VIDEO_GPU_OBSERVATIONS","VIDEO_GPU_CHANGES",
			"VIDEO_GPU_SAMPLES","VIDEO_GPU_NONZERO","VIDEO_GPU_MIN","VIDEO_GPU_MAX","VIDEO_GPU_MEAN","VIDEO_GPU_VARIANCE","VIDEO_GPU_CAPTURE_TIME",
			"VIDEO_GPU_R_NONZERO","VIDEO_GPU_G_NONZERO","VIDEO_GPU_B_NONZERO","VIDEO_GPU_R_MEAN","VIDEO_GPU_G_MEAN","VIDEO_GPU_B_MEAN",
			"MODE","GMT_READY","GMT_REASON","GMT_COUNT","GMT_QUERY_COUNT","GMT_CANDIDATES","GMT_GROUND_CANDIDATES",
			"GMT_TERRAIN_REJECTS","GMT_OBJECT_REJECTS","GMT_SPEED_REJECTS","GMT_RCS_REJECTS","GMT_TRUNCATED","GMT_LAST_TIME","GMT_ACTIVITY_DT",
			"GMT_MOTION_UNAVAILABLE","GMT_SLOW_REJECTS","GMT_FAST_REJECTS",
			"NATIVE_TRACK_VALID","NATIVE_TRACK_ID","NATIVE_TRACK_TYPE","NATIVE_TRACK_ACQUIRING","NATIVE_TRACK_MEMORY","NATIVE_TRACK_TIME","TRACK_VALID","TRACK_ID",
			"NATIVE_TRACK_REQUEST_SEQUENCE","CURSOR_PREVIEW","VIDEO_HOLD","FIXED_TRACK"}) do
			row[#row+1] = name .. "=" .. tostring(get("F22_AG_" .. name))
		end
		log.write("F22_AG_SCAN", log.INFO, table.concat(row, " "))
		for first=1,#m.movers,12 do
			local tracks={string.format("t=%.3f mode=%d reference=(%.2f,%.2f,%.6f)",now,m.mode,map_pose.north,map_pose.east,map_pose.heading)}
			for i=first,math.min(first+11,#m.movers)do local r=m.movers[i]
				tracks[#tracks+1]=string.format("id=%.0f p=(%.2f,%.2f,%.2f) v=(%.2f,%.2f,%.2f) age=%.3f screen=(%.4f,%.4f)",r.id,r.north,r.altitude,r.east,r.vn,r.vu,r.ve,r.age,r.x,r.y)
			end
			log.write("F22_AG_CONTACTS",log.INFO,table.concat(tracks," "))
		end
		local resources=get('F22_AG_VIDEO_GPU_RESOURCES')
		if type(resources)=='string' and resources~='' and resources~=self.logged_resources then
			self.logged_resources=resources;log.write('F22_AG_GPU_RESOURCES',log.INFO,resources)
		end
	end
end

local function copy(p)local q={};for k,v in pairs(p or {})do q[k]=v end;return q end
function M:emitting()return not self.controls.silent or self.controls.active end
function M:hold_image(value)
 self.video_frozen=value;self.frozen_pose=value and copy(self.pose)or nil
 self.frozen_movers=value and self.model.movers or nil
 self.frozen_family=value and self.search_family or nil
 if not value and self.pending_autorange then self:autorange(self.pending_autorange);self.pending_autorange=nil end
 self.frozen_view=value and self.model.exp_view or nil
end
function M:autorange(point)
 local pose=self.live_pose or self.pose;if not pose then return end
 local dn,de=point.north-pose.north,point.east-pose.east
 local distance=math.sqrt(dn*dn+de*de)
 self.model.range_nm=Modes.fit_range(self.model.mode,distance)
 self.model.cursor_fraction=math.max(.05,math.min(.95,distance/(self.model.range_nm*1852)))
 self.model.cursor_az=Modes.wrap(math.atan2(de,dn)-pose.heading)
end
function M:select_expansion(point,retained)
 local c,m=self.controls,self.model;local level=c.pending
 local view=Modes.exp_geometry(self.live_pose or self.pose,point,level)
 if not view or not view.qualified then return end
 c.patch=copy(point);c.expansion=level;c.pending=0;c.stabilized=retained or level>1
 c.patch_az=view.az;c.patch_distance=math.sqrt((point.north-view.north)^2+(point.east-view.east)^2)
 c.epoch=(c.epoch or 0)+1;m.exp_x=0;m.exp_y=0;m.exp_view=nil
 self:cancel_preview();self:hold_image(false)
end
function M:retained_point(now)
 if self.track_requested then
  if self.get('F22_AG_TRACK_VALID')>.5 then
   local track=native_track(self.get,now)
   if track then return track.display end
  end
  return
 end
 if self.get('F22_AG_DESIGNATION_VALID')>.5 then
  local p={north=self.get('F22_AG_DESIGNATION_NORTH'),
   altitude=self.get('F22_AG_DESIGNATION_ALTITUDE'),east=self.get('F22_AG_DESIGNATION_EAST')}
  if Model.finite(p.north)and Model.finite(p.altitude)and Model.finite(p.east)then return p end
 end
 return self.controls.patch
end
function M:switch_expansion(level,now)
 local c=self.controls
 if c.expansion==level then
  c.expansion=0;c.pending=0;c.epoch=(c.epoch or 0)+1;self.model.exp_view=nil;return
 end
 local point=self:retained_point(now)
 c.pending=level
 if point then self:select_expansion(point,true)end
end
function M:switch_mode(mode)
 local c,m=self.controls,self.model
 self.pending_autorange=nil;self:cancel_preview()
 if Modes.ranging(m.mode)or Modes.ranging(mode)then
  self:cancel_track();c.patch=nil
 end
 m.mode=mode;c.expansion=0;c.pending=0;m.exp_view=nil;self.interleave=false
 if mode==6 then m.width=70 elseif m.width==70 then m.width=90 end
 m.range_nm=math.min(m.range_nm,Modes.ranges(mode)[#Modes.ranges(mode)])
 if mode==2 and m.width==120 then m.width=90 end
 c.epoch=(c.epoch or 0)+1
end
function M:expanded_view(pose)
 local c,m=self.controls,self.model
 if c.expansion==0 or not pose or not c.patch then m.exp_view=nil;return end
 local point=c.patch
 if c.expansion==1 and not c.stabilized then
  local a=pose.heading+c.patch_az
  point={north=pose.north+c.patch_distance*math.cos(a),east=pose.east+c.patch_distance*math.sin(a),altitude=c.patch.altitude}
 end
 local v=Modes.exp_geometry(pose,point,c.expansion)
 -- Use the actual renderer's source frame when its mode/erase identity agrees.
 -- A late frame from the previous patch cannot move a new cursor selection.
 if v and self.get('F22_AG_VIDEO_REFERENCE_VALID')>.5 and
  self.get('F22_AG_VIDEO_REFERENCE_EXPANSION')==c.expansion and
  self.get('F22_AG_VIDEO_REFERENCE_EPOCH')==(c.epoch or 0)then
  v.north=self.get('F22_AG_VIDEO_REFERENCE_NORTH');v.east=self.get('F22_AG_VIDEO_REFERENCE_EAST')
  v.altitude=self.get('F22_AG_VIDEO_REFERENCE_ALTITUDE');v.heading=self.get('F22_AG_VIDEO_REFERENCE_HEADING')
  v.center=self.get('F22_AG_VIDEO_REFERENCE_CENTER_M');v.span=self.get('F22_AG_VIDEO_REFERENCE_SPAN_M')
 end
 m.exp_view=v
end
function M:control_command(name,powered,now)
 local c,m=self.controls,self.model
 if name=='vertical_span'and c.silent and not c.active then return true end
 local modes={rws=1,tws=2,sea=4,ta=6,agr=7}
 if modes[name]or name=='toggle'then
  if not powered or self.video_frozen or self.preview_pose then return true end
  local mode=modes[name]or ({[1]=2,[2]=4,[3]=4,[4]=6,[5]=6,[6]=7,[7]=1})[m.mode]or 1
  self:switch_mode(mode);return true
 end
 if name=='silent'then
  if powered then
   c.silent=not c.silent;c.active=false;c.active_end=nil
   self:cancel_preview();self:cancel_track();self:hold_image(c.silent)
  end
  return true
 elseif name=='active'then
  if powered and c.silent and not c.active then
   self:cancel_preview();self:cancel_track();c.active=true;c.active_end=c.units+1;self:hold_image(false)
  end
  return true
 elseif name=='data'then if powered then c.data=not c.data end;return true
 elseif name=='gain_up'or name=='gain_down'then
  if powered then c.gain=math.max(1,math.min(9,c.gain+(name=='gain_up'and 1 or -1)))end;return true
 elseif name=='declutter'then if powered and c.data then c.declutter=not c.declutter end;return true
 elseif name=='fast'then if powered and c.expansion>0 and not self.video_frozen then c.fast=not c.fast end;return true
 elseif name=='beam'then if powered and not Modes.ranging(m.mode)and not self.video_frozen and c.expansion<3 then c.fan=not c.fan;c.epoch=(c.epoch or 0)+1 end;return true
 elseif name=='reset'then
  if powered and not(c.silent and not c.active)then
   self:cancel_preview();self:cancel_track();local quiet=c.silent
   self.controls=Modes.new();self.controls.silent=quiet
   m.mode=m.mode==3 and 2 or m.mode==5 and 4 or m.mode
   m.range_nm=math.min(40,Modes.ranges(m.mode)[#Modes.ranges(m.mode)])
   m.width=m.mode==6 and 70 or 90;m.cursor_az=0;m.cursor_fraction=.5;m.exp_view=nil
   self.interleave=false;self.video_erase=self.video_erase+1;self.video_frame=nil;self:hold_image(quiet)
  end
  return true
 end
 local level=({exp1=1,exp2=2,exp3=3})[name]
 if name=='expand'then level=c.expansion%3+1 end
 if level then
  if powered and not Modes.ranging(m.mode)and not self.video_frozen then
   self:switch_expansion(level,now or m.clock)
  end
  return true
 end
 return false
end
function M:publish_controls(operating,view,hold)
 local c,m=self.controls,self.model;local put=self.put
 local tx=operating and self:emitting()
 put('F22_AG_RADAR_EMITTING',tx and 1 or 0)
 put('F22_AG_SILENT',c.silent and 1 or 0);put('F22_AG_ACTIVE',c.active and 1 or 0)
 put('F22_AG_ACTIVE_AVAILABLE',operating and c.silent and not c.active and 1 or 0)
 put('F22_AG_DATA',c.data and 1 or 0);put('F22_AG_DECLUTTER',c.declutter and 1 or 0)
 put('F22_AG_FAST',c.fast and c.expansion>0 and 1 or 0)
 put('F22_AG_EXPANSION',c.expansion);put('F22_AG_EXP_PENDING',c.pending)
 put('F22_AG_VIDEO_EXPANSION',c.expansion);put('F22_AG_VIDEO_EPOCH',c.epoch or 0)
 put('F22_AG_VIDEO_CENTER_M',view and view.center or 0);put('F22_AG_VIDEO_SPAN_M',view and view.span or 0)
 put('F22_AG_VIDEO_STABILIZED',c.stabilized and 1 or 0)
 put('F22_AG_VIDEO_PATCH_N',c.patch and c.patch.north or 0);put('F22_AG_VIDEO_PATCH_U',c.patch and c.patch.altitude or 0)
 put('F22_AG_VIDEO_PATCH_E',c.patch and c.patch.east or 0);put('F22_AG_VIDEO_PATCH_AZ',c.patch_az or 0)
 put('F22_AG_VIDEO_PATCH_DISTANCE',c.patch_distance or 0)
 put('F22_AG_VIDEO_ANTENNA_DEG',c.antenna);put('F22_AG_VIDEO_FAN',c.fan and 1 or 0)
 put('F22_AG_GAIN_INDEX',c.gain);put('F22_AG_ANTENNA_DEG',math.deg(m.mode==7 and (self.live_pose and self.live_pose.pitch or 0)or view and view.elevation or -math.atan((self.pose and self.pose.altitude or 0)/(m.range_nm*1852)))+c.antenna)
 put('F22_AG_OPTIONS_AVAILABLE',operating and not hold and not Modes.ranging(m.mode)and 1 or 0)
 put('F22_AG_RANGE_AVAILABLE',operating and not hold and c.expansion==0 and m.mode~=7 and 1 or 0)
 put('F22_AG_INTL_AVAILABLE',Modes.search(m.mode)and c.expansion==0 and 1 or 0)
 put('F22_AG_FAST_AVAILABLE',c.expansion>0 and 1 or 0)
 put('F22_AG_VIDEO_QUALIFIED',c.expansion>0 and (not view or not view.qualified)and 0 or 1)
 put('F22_AG_BEAM_AVAILABLE',operating and not hold and not Modes.ranging(m.mode)and c.expansion<3 and 1 or 0)
 put('F22_AG_CURSOR_SHOW',not Modes.ranging(m.mode)and 1 or 0)
 put('F22_AG_PLOT_SHOW',m.mode~=7 and 1 or 0)
 put('F22_AG_EXP1_AVAILABLE',(m.mode==1 or Modes.search(m.mode) or c.expansion>0)and operating and not hold and 1 or 0)
 local p=c.pending>0 and self:cursor_point(self.update_time)
 local v=p and Modes.exp_geometry(self.live_pose or self.pose,p,c.pending)
 put('F22_AG_CORRAL_SHOW',v and 1 or 0)
 if v then
  for i,corner in ipairs({{-.825,-.76},{.825,-.76},{.825,.76},{-.825,.76}})do
   local q=Modes.point(v,corner[1],corner[2],self.terrain)
   if q then local x,y=m:project(q,self.pose);put('F22_AG_CORRAL_'..i..'_X',x);put('F22_AG_CORRAL_'..i..'_Y',y)end
  end
 end
end

function M:source_transition()
 if not self.protocol.coherent or self.native_epoch==self.protocol.epoch then return end
 local changed=self.native_epoch~=nil
 self.native_epoch=self.protocol.epoch
 if not changed then return end
 self:cancel_track();self:cancel_preview()
 self.model.movers={};self.frozen_movers=nil;self.frozen_family=nil;self.pending_autorange=nil
 self.controls.active=false;self.controls.active_end=nil;self.controls.pending=0
 self.collection.generation=nil
 self.put("F22_AG_DESIGNATION_VALID",0)
 self.put("F22_AG_DESIGNATION_LIVE",0)
 self.model.sequence=self.model.sequence%16777215+1
 self.put("F22_AG_DESIGNATION_SEQUENCE",self.model.sequence)
 self.put("F22_AG_TRACK_VALID",0);self.put("F22_AG_TRACK_ACQUIRING",0)
end

local command_body,update_body,preview_body=M.command,M.update,M.cancel_preview
local function run_packet(self,operation,now,...)
 self.protocol:read(now)
 self:source_transition()
 return operation(self,...)
end
local function invoke(self,operation,now,...)
 if not self.protocol:begin(now)then return false end
 local valid=Protocol.finite(now)and now>=0
 local ok,reason=false,"invalid source clock"
 if valid then ok,reason=pcall(run_packet,self,operation,now,...)end
 if not ok then
  self.model.slew_x,self.model.slew_y=0,0
  self.track_requested=false;self.selected_id=nil
  self.preview_pose,self.preview_view,self.preview_kind=nil,nil,nil
  self.controls.active=false;self.controls.active_end=nil
  if not self.reported_protocol_failure and log and log.write then
   log.write("F22_AG_PACKET",log.ERROR or log.INFO,tostring(reason))
   self.reported_protocol_failure=true
  end
 end
 self.protocol:finish(ok)
 return ok
end
function M:command(name,value,powered,now)
 if now==nil and type(get_model_time)=="function"then
  local ok,time=pcall(get_model_time);if ok then now=time end
 end
 return invoke(self,command_body,now,name,value,powered,now)
end
function M:publish_mark(now,healthy)
 local target=healthy and TargetSnapshot.read(self.get,now)
 local x,y
 if target and self.pose then x,y=self.model:project({north=target.n,east=target.e},self.pose)end
 local valid=Model.finite(x)and Model.finite(y)and math.abs(x)<=.83 and y>=-.76 and y<=.76
 self.put("F22_AG_MAP_TARGET_X",valid and x or 0)
 self.put("F22_AG_MAP_TARGET_Y",valid and y or 0)
 self.put("F22_AG_MAP_TARGET_VALID",valid and 1 or 0)
end
function M:update(pose,now,dt,powered,ready)
 local healthy=invoke(self,update_body,now,pose,now,dt,powered,ready)
 self:publish_mark(now,healthy)
 return healthy
end
function M:cancel_preview()
 if self.protocol.depth>0 then return preview_body(self)end
 local now=self.update_time
 if type(get_model_time)=="function"then local ok,time=pcall(get_model_time);if ok then now=time end end
 return invoke(self,preview_body,now)
end

return M

-- GPL-3.0-or-later. Consumer of complete sensor snapshots; never a launch input.
local Tracks = dofile(LockOn_Options.script_path .. "Systems/Tactical_Tracks.lua")
local Situation = dofile(LockOn_Options.script_path .. "Systems/Tactical_Situation.lua")
local Geolocation = dofile(LockOn_Options.script_path .. "Systems/EW_Geolocation.lua")
local Datalink = dofile(LockOn_Options.script_path .. "Systems/Datalink_Tracks.lua")
local Identification = dofile(LockOn_Options.script_path .. 'Systems/Identification_State.lua')
local Donor = dofile(LockOn_Options.script_path .. 'Systems/Donor_Selection.lua')
local M = {}
local MWS = dofile(LockOn_Options.script_path..'Systems/Tactical_MWS_Snapshot.lua')
local Diagnostics = dofile(LockOn_Options.script_path..'Systems/Tactical_Diagnostics.lua')
local RadarSnapshot=dofile(LockOn_Options.script_path.."Systems/Radar_Tactical_Snapshot.lua")
local IRSTSnapshot=dofile(LockOn_Options.script_path..'Systems/IRST_Snapshot.lua')
local Labels=dofile(LockOn_Options.script_path..'Systems/RWR_Computer.lua')
function M.new(get, put, sensors)
	put('F22_DATALINK_ENABLE',1)
	put('F22_IFDL_ENABLE',1)
	local s = { radar = RadarSnapshot.new(get), irst = IRSTSnapshot.new(get,'F22_IRST_'),
        store = Tracks.new(), sequence = 0, diagnostics = Diagnostics.new(get),
        situation = Situation.new(get, put, sensors),
        datalink = Datalink.new(get, sensors), responder = Identification.responder(get, put),
        donor = Donor.new(get, put) }
	function s:reset()
		self.store:reset()
		self.datalink:reset()
		self.situation:reset()
        self.responder = Identification.responder(get, put)
        self.donor = Donor.new(get, put)
		self:update(0, {}, false)
	end
	function s:command(c)
        if c>=11130 and c<=11132 then self.responder:command(c);return end
        if c>=11140 and c<=11144 then self.donor:command(c);return end
		if c==10917 then put('F22_DATALINK_ENABLE',get('F22_DATALINK_ENABLE')>.5 and 0 or 1)
		elseif c==10918 then put('F22_IFDL_ENABLE',get('F22_IFDL_ENABLE')>.5 and 0 or 1) end
		self.situation:command(c)
	end
	function s:update(now, rf, power)
        self.responder:update(now)
		self.sequence = self.sequence % 15999998 + 2
		local radar_packet=self.radar:read(now)
		local infrared=self.irst:read(now)
		local batches = {
			irst={sequence=infrared.sequence,time=infrared.time,epoch=infrared.epoch,contacts={}},
			datalink = self.datalink:update(now, power),
			rf = { sequence = self.sequence, time = now, epoch = self.store.epoch, contacts = {} },
			radar = {
                sequence=radar_packet and radar_packet.sequence or -1,
                time=radar_packet and radar_packet.time or now,
                epoch=radar_packet and radar_packet.epoch or 0,contacts={},
            },
            mws = MWS.read(get, now),
		}
		for _, c in ipairs(rf) do
			batches.rf.contacts[#batches.rf.contacts + 1] = {
				source = c.source,
				age = c.age,
				az = -c.az,
				el = c.el,
				signal = c.signal,
				power = c.power,
				label = c.label,
				general = c.general,
				world = c.bearing_world,
                bearing_origin=c.bearing_origin,
				geolocation = c.geolocation,
				geolocation_status = c.geolocation_status,
				friendly = c.affiliation == 1,
				hostile = c.affiliation == 0 or c.hostile_act,
                identity_time = c.identity_time,
                hostile_time = c.hostile_time,
			}
		end
        if radar_packet then
            for i=1,#radar_packet.contacts do
                local v=radar_packet.contacts[i]
                batches.radar.contacts[i]={source=v.SOURCE,age=v.AGE,az=v.AZ,el=v.EL,
                    range=v.RANGE,measured_range=v.MEASURED_RANGE,quality=v.QUALITY,
                    label=Labels.label(v.TYPE_NAME,1),n=v.POSITION_VALID==1 and v.N or nil,
                    u=v.U,e=v.E,vn=v.VN,vu=v.VU,ve=v.VE,epoch=radar_packet.epoch,
                    measurement_source=v.MEASUREMENT_SOURCE,velocity_valid=v.VELOCITY_VALID==1,
                    position_sigma_m=v.POSITION_SIGMA_M,velocity_sigma_mps=v.VELOCITY_SIGMA_MPS,
                    selected=v.SELECTED==1,identity_known=v.IDENTITY_KNOWN==1,
                    identity_time=v.IDENTITY_KNOWN==1 and v.IDENTITY_TIME or nil,
                    friendly=v.FRIENDLY==1,
                    hostile=v.HOSTILE==1}
            end
        end

		for i=1,#infrared.contacts do
			local t=infrared.contacts[i]
			batches.irst.contacts[i]={source=t.id,age=infrared.time-t.time,az=t.az,el=t.el,
				epoch=infrared.epoch,label='U'}
		end
		if not infrared.ready then self.store.batches.irst=nil end
		self.store:update(now, batches, power)
        self.donor:update(now, self.store.contacts, power)
		self.situation:update(now, self.store.contacts, power)
        put('F22_TACTICAL_SEQUENCE', self.sequence-1)
        put('F22_TACTICAL_SCHEMA', 2)
        put('F22_TACTICAL_EPOCH', self.store.epoch)
		for i = 1, 64 do
			local p = string.format("F22_TACTICAL_%02d_", i)
			local t = self.store.contacts[i]
			put(p .. "SOURCE", t and t.source or 0)
			put(p .. "SOURCES", t and t.mask or 0)
			put(p .. "AGE", t and t.age or 999)
			put(p .. "AZ", t and t.az or 0)
			put(p .. "EL", t and t.el or 0)
			put(p .. "AFFILIATION", t and t.affiliation or -1)
            put(p..'LABEL_CODE',Labels.label_code(t and t.label or 'U'))
            put(p .. 'IDENTITY_CONFLICT', t and t.identity_conflict and 1 or 0)
            put(p .. 'FRIENDLY_PROTECTED', t and t.friendly_protected and 1 or 0)
			put(p .. "RANGE_VALID", t and t.range and 1 or 0)
			put(p .. "RANGE_M", t and t.range or 0)
			put(p .. "RANGE_ESTIMATED", t and t.range_estimated and 1 or 0)
			put(p .. "MEASURED_RANGE_M", t and t.measured_range or 0)
			put(p .. "RANGE_TIME", t and t.range_time or 0)
			put(p .. "RADAR_AGE", t and t.radar_age or 999)
			put(p .. "UNCERTAINTY_VALID", t and t.uncertainty and 1 or 0)
			put(p .. "UNCERTAINTY_RAD", t and t.uncertainty or 0)
			put(p .. "SELECTED", t and t.selected and 1 or 0)
            local radar=t and t.observations.radar
            put(p..'RADAR_SOURCE',radar and radar.source or 0)
            put(p..'RADAR_EPOCH',radar and radar.epoch or 0)
            put(p..'IRST_AGE',t and t.irst_age or 999)
            put(p .. 'RADAR_MEASUREMENT_SOURCE',radar and radar.measurement_source or 0)
            put(p .. 'WEAPON_AUTHORITY',0) -- This picture is never the release provider.
			local dl = t and t.datalink
			put(p .. "DATALINK", dl and dl.link or 0)
			put(p .. "DATALINK_AGE", t and t.datalink_age or 999)
			put(p .. "DATALINK_REPORTER", dl and dl.reporter or 0)
			put(p .. "DATALINK_COAST", dl and Datalink.coasting(dl, now) and 1 or 0)
            put(p .. 'DATALINK_OBSERVATION_KNOWN', dl and dl.observation_known and 1 or 0)
            put(p .. 'DATALINK_RECEIVE_AGE', dl and dl.received and math.max(0,now-dl.received)or 999)
			put(p .. "RF_SIGNAL", t and t.signal or 0)
			local rf=t and t.observations.rf
			put(p .. "RF_GENERAL",rf and rf.general or 0)
			put(p .. 'RF_POWER_VALID',rf and rf.power~=nil and 1 or 0)
			put(p .. 'RF_POWER',rf and rf.power or 0)
			put(p .. "RF_DIRECTION_VALID",rf and rf.world and 1 or 0)
			put(p .. "RF_WORLD_N",rf and rf.world and rf.world[1] or 0)
			put(p .. "RF_WORLD_U",rf and rf.world and rf.world[2] or 0)
			put(p .. "RF_WORLD_E",rf and rf.world and rf.world[3] or 0)
			local geo=t and Geolocation.current(t.geolocation,now)
			put(p .. "GEO_VALID",geo and 1 or 0)
			put(p .. "GEO_N",geo and geo.n or 0)
			put(p .. "GEO_U",geo and geo.u or 0)
			put(p .. "GEO_E",geo and geo.e or 0)
			put(p .. "GEO_RADIUS_M",geo and geo.radius or 0)
			put(p .. "GEO_AGE",geo and geo.age or 999)
			put(p .. "GEO_SAMPLES",geo and geo.samples or 0)
			put(p .. "OPTICAL", t and t.optical and 1 or 0)
			put(p .. "RF_AGE", t and t.rf_age or 999)
			put(p .. "RF_COAST", t and t.rf_coast and 1 or 0)
			put(p .. "OPTICAL_AGE", t and t.optical_age or 999)
			put(p .. "OPTICAL_COAST", t and t.optical_coast and 1 or 0)
			put(p .. "THREAT_PRIORITY", t and t.threat_priority or 0)
			put(p .. "DIRECTION_SOURCE", t and Tracks.bits[t.direction_sensor] or 0)
			put(p .. "VALID", t and 1 or 0)
		end
		put("F22_TACTICAL_COUNT", math.min(64, #self.store.contacts))
		put("F22_TACTICAL_OVERFLOW", math.max(0, #self.store.contacts - 64))
		put("F22_TACTICAL_TIME", now)
		put("F22_TACTICAL_SEQUENCE", self.sequence)
        self.diagnostics:update(now, self.store)
	end
	s:reset()
	return s
end
return M

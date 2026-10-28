-- GPL-3.0-or-later. Read-only, bounded radar test telemetry in dcs.log.
-- Changed values indicate export changes, not confirmed sensor refreshes.
local M = {}
local aesa_fields = {"ID","TIME","N","U","E","VN","VU","VE","FILTER_VALID","VELOCITY_VALID",
    "RAW_N","RAW_U","RAW_E","MEASURED_RANGE","MEASURED_AZ","MEASURED_EL","RANGE_RATE",
    "RANGE_SIGMA_M","ANGLE_SIGMA_RAD","RATE_SIGMA_MPS","POSITION_SIGMA_M","VELOCITY_SIGMA_MPS","HITS",
    "ORIGIN_N","ORIGIN_U","ORIGIN_E","OWN_VN","OWN_VU","OWN_VE",
    "FORWARD_N","FORWARD_U","FORWARD_E","UP_N","UP_U","UP_E","RIGHT_N","RIGHT_U","RIGHT_E"}
for i = 0, 5 do
    for j = i, 5 do aesa_fields[#aesa_fields+1] = string.format("COV_%d%d",i,j) end
end
local aesa_prefixes = {}
for i = 1, 64 do aesa_prefixes[i] = string.format("F22A_%02d_",i) end
local service_fields = {
    "F22_AESA_CUE_REQUEST", "F22_AESA_CUE_TIME", "F22_AESA_CUE_DWELLS",
    "F22_RADAR_DONOR_STATUS", "F22_RADAR_DONOR_SOURCE",
    "F22_AESA_FC_TARGET", "F22_AESA_FC_REVISIT_S", "F22_AESA_FC_LAST_LOOK", "F22_AESA_DEADLINE_MISSES",
	"F22_AESA_DRIVER_READY",
	"F22_AESA_READY",
	"F22_AESA_REASON",
	"F22_AESA_TIME",
	"F22_AESA_SEQUENCE",
	"F22_AESA_COUNT",
	"F22_AESA_DWELLS",
	"F22_AESA_SEARCH_DWELLS",
	"F22_AESA_TRACK_DWELLS",
	"F22_AESA_DETECTIONS",
	"F22_AESA_PENDING",
	"F22_AESA_BEAM_AZ",
	"F22_AESA_BEAM_EL",
	"F22_AESA_SURFACE_SERVICE",
	"F22_AESA_GENERATION",
	"F22_TSD_NAV_LAYER", "F22_TSD_NAV_LEG_01_VALID", "F22_RDR_LAR_VISIBLE", "F22_RDR_LAR_AXIS_VALID",

	"F22_RADAR_SERVICE_ENABLED", "F22_RADAR_SERVICE_STATE", "F22_RADAR_SERVICE_RESOURCE",
	"F22_RADAR_SERVICE_HEALTH_KNOWN", "F22_RADAR_SERVICE_PENDING", "F22_RADAR_SERVICE_DROPPED",
	"F22_RADAR_SERVICE_ACCEPTED", "F22_RADAR_SERVICE_WORK_S", "F22_RADAR_SERVICE_PROCESSING_S",
	"F22_RADAR_NATIVE_RESTRICTED", "F22_RADAR_BACKGROUND_AVAILABLE", "F22_RADAR_AIR_SURFACE_CONCURRENT",
	"F22_RADAR_SELECTED_MEASUREMENT_SOURCE", "F22_RADAR_SELECTED_AGE", "F22_AG_TRACK_TYPE",
}
local fields = {
	"RADAR_PWR",
	"MAIN_POWER",
	"F22_RADAR_BACKEND_READY",
	"F22N_RADAR_MODE",
	"F22_RADAR_STT_VALID",
	"F22N_RADAR_STT_RANGE",
	"F22N_RADAR_STT_AZIMUTH",
	"F22N_RADAR_STT_ELEVATION",
	"F22N_RADAR_STT_FRIENDLY",
	"F22_RADAR_NATIVE_CONFIGURED",
	"F22_RADAR_NATIVE_CONFIG_REASON",
	"HUD_MODE",
	"WS_GUN_PIPER_AVAILABLE",
	"WS_GUN_PIPER_AZIMUTH",
	"WS_GUN_PIPER_ELEVATION",
	"HUD_GUN_NATIVE_VALID",
	"HUD_GUN_NATIVE_AZ",
	"HUD_GUN_NATIVE_EL",
	"EFM_HUD_VALID",
	"EFM_HUD_VN",
	"EFM_HUD_VE",
	"EFM_HUD_VU",
	"EFM_HUD_WN",
	"EFM_HUD_WE",
	"EFM_HUD_WU",
	"F22_STT_MOTION_VALID",
	"F22_STT_ID",
	"F22_STT_TIME",
	"F22_STT_ACCEL_VALID",
	"F22_STT_PN",
	"F22_STT_PU",
	"F22_STT_PE",
	"F22_STT_VN",
	"F22_STT_VU",
	"F22_STT_VE",
	"F22_STT_AN",
	"F22_STT_AU",
	"F22_STT_AE",
	"F22_GUN_REQUEST_VALID",
	"F22_GUN_USING_DIRECTOR",
	"F22_GUN_SOLVER_REASON",
	"F22_GUN_TOF",
	"F22_GUN_RESIDUAL",
	"F22_GUN_MUZZLE_SPEED",
	"F22_GUN_MUZZLE_N",
	"F22_GUN_MUZZLE_U",
	"F22_GUN_MUZZLE_E",
	"F22_GUN_AIM_N",
	"F22_GUN_AIM_U",
	"F22_GUN_AIM_E",
	"F22_GUN_RESULT_TIME",
	"F22_GUN_RESULT_TRACK_ID",
	"F22_GUN_MEASUREMENT_AGE",
	"F22_GUN_TARGET_N",
	"F22_GUN_TARGET_U",
	"F22_GUN_TARGET_E",
	"F22_GUN_VN",
	"F22_GUN_VU",
	"F22_GUN_VE",
	"F22_GUN_AN",
	"F22_GUN_AU",
	"F22_GUN_AE",
	"F22_GUN_PREDICTED_N",
	"F22_GUN_PREDICTED_U",
	"F22_GUN_PREDICTED_E",
	"F22_GUN_ACTUAL_ENDPOINT_VALID",
	"F22_GUN_ACTUAL_END_N",
	"F22_GUN_ACTUAL_END_U",
	"F22_GUN_ACTUAL_END_E",
	"F22_GUN_BORE_N",
	"F22_GUN_BORE_U",
	"F22_GUN_BORE_E",
	"F22_GUN_REQUEST_SEQUENCE",
	"F22_GUN_RESPONSE_SEQUENCE",
	"F22_GUN_SOLUTION_SEQUENCE",
	"F22_GUN_PENDING",
	"F22_GUN_DISPLAY_REASON",
	"F22_GUN_RESPONSE_AGE",
	"F22_GUN_QUEUE_DELAY",
	"F22_GUN_MNV_VALID",
	"F22_GUN_MNV_SHOW",
	"F22_GUN_MNV_TIME",
	"F22_GUN_MNV_ID",
	"F22_GUN_MNV_COST_MS",
	"F22_GUN_MNV_OBSERVED_G",
	"F22_GUN_MNV_LEFT_LEN",
	"F22_GUN_MNV_RIGHT_LEN",

	"HUD_GUN_TRIGGER",
	"MASTER_ARM",
	"F22_GUN_AMMO_VALID",
	"F22_GUN_AMMO_COUNT",
}
-- Source/quality and weapon support stay in the same bounded CSV stream.
local avionics_fields = {
	"F22_RADAR_TRACK_COUNT",
	"F22_RADAR_DRAWN_COUNT",
	"F22_RADAR_MODE_CODE",
	"F22_RADAR_SELECTED_QUALITY",
	"F22_RADAR_SELECTED_AGE",
	"F22_RADAR_SELECTED_SUPPORT_ELIGIBLE",
	"F22_RADAR_SCAN_AUTO",
	"F22_RADAR_SCAN_AZ_DEG",
	"F22_RADAR_SCAN_EL_DEG",
	"F22_RADAR_SCAN_OBLIGATIONS",
	"F22_RADAR_SCAN_UNCOVERED",
	"F22_RADAR_SCAN_COVERAGE_COMPLETE",
	"F22_RADAR_SCAN_RANGE_NM",
	"F22_RADAR_SUPPORT_ENABLED",
	"F22_TWS_ACTIVE",
	"F22_TWS_TARGET_ID",
	"F22_TWS_TARGET_AGE",
	"F22_RADAR_WEAPON_TARGET_ID",
	"F22_TWS_SUPPORT_QUERIES",
	"F22_TWS_SUPPORT_ACCEPTS",
	"F22_LAUNCH_SEQUENCE",
	"F22_RWR_POWER",
	"F22_RWR_READY",
	"F22_RWR_COUNT",
	"F22_RWR_ALERT",
	"F22_RWR_AUDIO_LOOP",
	"F22_RWR_AUDIO_EVENT",
	"F22_FC_TARGET_VALID",
	"F22_FC_DLZ_VALID",
	"F22_FC_DLZ_DYNAMIC",
	"F22_FC_MIN_NM",
	"F22_FC_MAX_NM",
	"F22_FC_TURN_NM",
	"F22_FC_RANGE_NM",
	"F22_FC_CLOSURE_KTS",
	"F22_FC_SHOOT",
	"F22_FC_MISSILES",
	"F22_FC_TIMER_SEQUENCE",
	"F22_FC_TIMER_ACTIVE",
	"F22_FC_TIMER_EMITTING",
	"F22_FC_TTA_VALID",
	"F22_FC_TTA",
	"F22_FC_TTG_VALID",
	"F22_FC_TTG",
	"F22_FC_SUPPORT_DEGRADED",
	"F22_FC_SUPPORT_LOST",
	"F22_FC_SUPPORT_COAST_COUNT",
	"F22_FC_SUPPORT_LOST_COUNT",
	"F22_TOF_BACKEND_READY",
	"F22_TOF_NATIVE_VALID",
	"F22_TOF_TARGET_ID",
	"F22_TOF_TYPE",
	"F22_TOF_TIME",
	"F22_TOF_SECONDS",
	"F22_TOF_ACT_VALID",
	"F22_TOF_ACT_SECONDS",
	"F22_RADAR_ACQ_COORDINATES_READY",
	"F22_RADAR_SELECTED_RANGE_NM",
	"F22_RADAR_DESIGNATION_AZ",
	"F22_RADAR_DESIGNATION_EL",
	"F22_RADAR_SECONDARY_VALID",
	"F22_RADAR_SECONDARY_AGE",
	"F22_RADAR_NATIVE_PATTERN_AZ",
	"F22_RADAR_NATIVE_PATTERN_EL",
	"F22_RADAR_NATIVE_ACQ_METRIC_AZ",
	"F22_RADAR_NATIVE_ACQ_METRIC_EL",
	"F22_RADAR_NATIVE_ACQ_METRIC_TIME",
	"F22_RADAR_NATIVE_ACQ_METRIC_VALID",
	"F22_RADAR_NATIVE_ACQ_BODY_AZ",
	"F22_RADAR_NATIVE_ACQ_BODY_EL",
	"F22_RADAR_NATIVE_SCAN_PHASE",
	"F22_RADAR_NATIVE_BEAM_WORLD_N",
	"F22_RADAR_NATIVE_BEAM_WORLD_U",
	"F22_RADAR_NATIVE_BEAM_WORLD_E",
	"F22_RADAR_NATIVE_BEAM_WORLD_VALID",
	"F22_RADAR_NATIVE_SCAN_REF_BEAM_AZ",
	"F22_RADAR_NATIVE_SCAN_REF_BEAM_EL",
	"F22_RADAR_NATIVE_SCAN_REF_BEAM_VALID",
}
local missile_fields = {
	"VALID",
	"ID",
	"TARGET",
	"SEQUENCE",
	"SUPPORT_REQUIRED",
	"SUPPORT_STATE",
	"ACTIVE",
	"SELF_GUIDING",
	"TTA_VALID",
	"TTA",
	"TTG_VALID",
	"TTG",
	"TRACK_LOST",
	"TTA_SOURCE",
	"TTG_SOURCE",
}
local pose_fields = { "north_m", "altitude_m", "east_m", "heading_rad", "pitch_rad", "roll_rad" }
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e15
end
local function number(v)
	return finite(v) and string.format("%.9g", v) or "nan"
end
function M.new(get, write, limit)
	local r = {
		count = 0,
		limit = limit or 60000,
		previous = nil,
		next_time = nil,
		next_contacts = nil,
		started = nil,
		observed = {},
		emitters = {},
		missiles = {},
	}
	function r:emit(s)
		if self.count >= self.limit then
			return
		end
		self.count = self.count + 1
		if self.count == self.limit then
			s = "v1,limit,record_cap"
		end
		write(s)
	end
	-- Record source measurements only when their sensor timestamp advances.
	-- Row: v1,observation,t,slot,ID,AGE,NORTH,ALTITUDE,EAST,VN,VU,VE,IFF.
	-- Row: v1,emitter,t,slot,SOURCE,TIME,AZIMUTH,ELEVATION,SIGNAL,POWER,PRIORITY,GENERAL_TYPE.
	function r:avionics(t)
		local row = { "v1", "avionics_sample", number(t) }
		for _, key in ipairs(avionics_fields) do
			row[#row + 1] = number(get(key))
		end
		self:emit(table.concat(row, ","))
		for i = 1, 8 do
			local p = string.format("F22_MSL_%02d_", i)
			local alive = get(p .. "VALID") > 0.5
			if alive or self.missiles[i] then
				local shot = { "v1", "missile", number(t), tostring(i) }
				for _, key in ipairs(missile_fields) do
					shot[#shot + 1] = number(get(p .. key))
				end
				self:emit(table.concat(shot, ","))
			end
			self.missiles[i] = alive
		end
	end
	function r:observations(t)
		local sequence, generation = get("F22_AESA_SEQUENCE"), get("F22_AESA_GENERATION")
		if generation ~= self.aesa_generation then self.aesa_observed={};self.aesa_generation=generation end
		if get("F22_AESA_READY") == 1 and sequence % 2 == 0 then
			for i = 1, 64 do
				local p = aesa_prefixes[i]
				local stamp = get(p.."TIME")
				if get(p.."VALID") == 1 and self.aesa_observed[i] ~= stamp then
					local row = {"v2","aesa",number(t),tostring(generation),tostring(i)}
					for j = 1, #aesa_fields do row[#row+1] = number(get(p..aesa_fields[j])) end
					if get("F22_AESA_SEQUENCE") == sequence then
						self:emit(table.concat(row,","));self.aesa_observed[i]=stamp
					end
				end
			end
		end
		if get("F22_RADAR_OBSERVATIONS_READY") > 0.5 then
			for i = 1, math.min(64, math.max(0, get("F22_RADAR_OBSERVATION_COUNT"))) do
				local p = string.format("F22O_%02d_", i)
				local id, age = get(p .. "ID"), get(p .. "AGE")
				if finite(id) and id > 0 and finite(age) and age >= 0 and age <= 20 then
					local stamp = t - age
					if not self.observed[id] or stamp > self.observed[id] + 0.01 then
						local row = { "v1", "observation", number(t), tostring(i) }
						for _, key in ipairs({ "ID", "AGE", "NORTH", "ALTITUDE", "EAST", "VN", "VU", "VE", "IFF" }) do
							row[#row + 1] = number(get(p .. key))
						end
						self:emit(table.concat(row, ","))
						self.observed[id] = stamp
					end
				end
			end
		end
		for i = 1, 16 do
			local p = string.format("RWR_CONTACT_%02d_", i)
			local id, age, signal = get(p .. "SOURCE"), get(p .. "TIME"), get(p .. "SIGNAL")
			if
				finite(id)
				and id > 0
				and finite(age)
				and age >= 0
				and age <= 12
				and (signal == 1 or signal == 2 or signal == 3)
			then
				local stamp = t - age
				local old = self.emitters[id]
				if not old or stamp > old.stamp + 0.01 or signal ~= old.signal then
					local row = { "v1", "emitter", number(t), tostring(i) }
					for _, key in ipairs({
						"SOURCE",
						"TIME",
						"AZIMUTH",
						"ELEVATION",
						"SIGNAL",
						"POWER",
						"PRIORITY",
						"GENERAL_TYPE",
					}) do
						row[#row + 1] = number(get(p .. key))
					end
					self:emit(table.concat(row, ","))
					self.emitters[id] = { stamp = stamp, signal = signal }
				end
			end
		end
		for id, stamp in pairs(self.observed) do
			if t - stamp > 20 then
				self.observed[id] = nil
			end
		end
		for id, old in pairs(self.emitters) do
			if t - old.stamp > 12 then
				self.emitters[id] = nil
			end
		end
	end
	function r:sample(t, pose)
		if not finite(t) or self.count >= self.limit then
			return
		end
		if self.previous and t == self.previous then
			return
		end
		if not self.started or (self.previous and t < self.previous) then
			self:emit("v1,segment," .. number(t))
			self:emit("v1,schema,t_model_s," .. table.concat(fields, ",") .. "," .. table.concat(pose_fields, ","))
			self:emit("v1,avionics_schema,t_model_s," .. table.concat(avionics_fields, ","))
			self:emit("v1,missile_schema,t_model_s,slot," .. table.concat(missile_fields, ","))
			self:emit("v1,service_schema,t_model_s," .. table.concat(service_fields, ","))
			self:emit("v2,aesa_schema,t_model_s,generation,slot," .. table.concat(aesa_fields, ","))
			self.aesa_observed = {}
			self.started = t
			self.next_time = t
			self.next_contacts = t
			self.observed = {}
			self.emitters = {}
			self.missiles = {}
		end
		self.previous = t
		if t - self.started > 1200 then
			self:emit("v1,limit,model_duration")
			self.count = self.limit
			return
		end
		if t + 1e-8 < self.next_time then
			return
		end
		self.next_time = t + 0.05
		local row = { "v1", "sample", number(t) }
		for _, key in ipairs(fields) do
			row[#row + 1] = number(get(key))
		end
		for _, key in ipairs({ "north", "altitude", "east", "heading", "pitch", "roll" }) do
			row[#row + 1] = number(pose and pose[key])
		end
		self:emit(table.concat(row, ","))
		if t + 1e-8 >= self.next_contacts then
			self.next_contacts = t + 0.2
			self:avionics(t)
			local service = { "v1", "service", number(t) }
			for _, key in ipairs(service_fields) do service[#service + 1] = number(get(key)) end
			self:emit(table.concat(service, ","))
			self:observations(t)
			for i = 1, 64 do
				local p = string.format("F22N_RADAR_CONTACT_%02d_", i)
				local range, age = get(p .. "RANGE"), get(p .. "TIME")
				if finite(range) and range > 0 and finite(age) and age >= 0 and age <= 10 then
					local c = { "v1", "contact", number(t), tostring(i) }
					for _, key in ipairs({ "TIME", "RANGE", "AZIMUTH", "ELEVATION", "VX", "VY", "VZ", "FRIENDLY" }) do
						c[#c + 1] = number(get(p .. key))
					end
					self:emit(table.concat(c, ","))
				end
			end
		end
	end
	return r
end
return M

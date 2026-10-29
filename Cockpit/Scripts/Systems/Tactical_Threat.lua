-- GPL-3.0-or-later. Source-local freshness and defensive presentation priority.
local M = { holds = { rf_search = 6, rf_warning = 3.5, mws = 0.5, irst = 2.5 } }
function M.age(observation, now)
	return observation and math.max(0, now - observation.time) or 999
end
function M.coast(observation, sensor, signal, now)
	return not observation
		or M.age(observation, now)
			> (M.holds[sensor] or (signal > 1 and M.holds.rf_warning or M.holds.rf_search))
end
function M.direction(track, now)
	local ir, rf = track.observations.mws, track.observations.rf
	if ir and not M.coast(ir, "mws", 0, now) then
		return ir, "mws"
	end
	if rf and not M.coast(rf, "rf", track.signal, now) then
		return rf, "rf"
	end
	if ir and (not rf or ir.time >= rf.time) then
		return ir, "mws"
	end
	return rf, rf and "rf" or nil
end
-- IRST can supply an awareness bearing but cannot create a missile warning.
function M.awareness_direction(track, now)
	local observation, sensor = M.direction(track, now)
	if observation and not M.coast(observation, sensor, track.signal, now) then
		return observation, sensor
	end
	local infrared = track.observations.irst
	if infrared and not M.coast(infrared, "irst", 0, now) then
		return infrared, "irst"
	end
	return observation, sensor
end
function M.priority(track, now)
	local o, sensor = M.direction(track, now)
	if not o then
		return 0
	end
	if M.coast(o, sensor, track.signal, now) then
		return 1
	end
	return sensor == "mws" and 4 or track.signal
end
return M

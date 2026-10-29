-- GPL-3.0-or-later. Owned estimator metadata; N/U/E position, m and m/s.
local M = {}
local fields = {
    {"TYPE_NAME","type_name"},
    {"COALITION_KNOWN","coalition_known"}, {"COALITION_AFFILIATION","coalition_affiliation"},
    {"POSITION_SIGMA_M","position_sigma_m"}, {"VELOCITY_SIGMA_MPS","velocity_sigma_mps"},
    {"RANGE_SIGMA_M","range_sigma_m"}, {"ANGLE_SIGMA_RAD","angle_sigma_rad"},
    {"RAW_N","raw_north"}, {"RAW_U","raw_altitude"}, {"RAW_E","raw_east"},
    {"MEASURED_RANGE","measured_range"}, {"MEASURED_AZ","measured_azimuth"},
    {"MEASURED_EL","measured_elevation"}, {"RANGE_RATE","range_rate"}, {"RATE_SIGMA_MPS","rate_sigma_mps"},
}
local covariance_fields = {}
for i = 0, 5 do
    for j = i, 5 do covariance_fields[#covariance_fields+1] = string.format("COV_%d%d",i,j) end
end
function M.read(get, prefix, observation)
    observation.filter_valid = get(prefix.."FILTER_VALID") == 1
    for i = 1, #fields do observation[fields[i][2]] = get(prefix..fields[i][1]) end
    observation.covariance = observation.covariance or {}
    for i = 1, 21 do observation.covariance[i] = get(prefix..covariance_fields[i]) end
end
function M.copy(target, observation)
    target.filter_valid = observation.filter_valid
    for i = 1, #fields do target[fields[i][2]] = observation[fields[i][2]] end
    target.covariance = target.covariance or {}
    for i = 1, 21 do target.covariance[i] = observation.covariance and observation.covariance[i] or 0 end
end
function M.publish(put, prefix, track)
    put(prefix.."FILTER_VALID",track and track.filter_valid and 1 or 0)
    put(prefix.."VELOCITY_VALID",track and track.velocity_valid and 1 or 0)
    for i = 1, #fields do put(prefix..fields[i][1],track and track[fields[i][2]] or 0) end
    for i = 1, 21 do put(prefix..covariance_fields[i],track and track.covariance and track.covariance[i] or 0) end
end
return M

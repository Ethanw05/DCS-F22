-- GPL-3.0-or-later. Common optical detector; generic six-aperture simulation.
-- These are mod policies, not recovered AN/AAR-56 performance specifications.
arcade = false
angular_velocity_threshold = math.rad(5)
message_legth = 3 -- Native configuration spelling.
notify_delta = 5
message_table = { [0] = 0, 0, 0, 0, 0, 0, 0, 0 }
eyes = {}
for i, look in ipairs({ { 0, 0 }, { 90, 0 }, { 180, 0 }, { -90, 0 }, { 0, 90 }, { 0, -90 } }) do
	eyes[i] = {
		position = { x = 0, y = 0, z = 0 },
		orientation = { azimuth = math.rad(look[1]), elevation = math.rad(look[2]) },
		field_of_view = math.rad(120),
	}
end
-- NativeMWS drives the native scan from our powered bus. No Lua scan activity.
need_to_be_closed = true

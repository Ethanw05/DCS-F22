-- GPL-3.0-or-later. Dedicated clock for the owned C++ scene provider.
-- No avSimpleRadar sensor, antenna, acquisition or observation cache exists.
-- Requested clock cadence; actual host timestamps still govern completed work.
make_default_activity(1 / 240)
function update()
    -- The version-checked C++ owner wraps this native device callback.
end
need_to_be_closed = false

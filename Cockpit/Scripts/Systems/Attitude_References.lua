-- GPL-3.0-or-later. Fresh primary/standby display adapters; no gyro integration here.
local References = dofile(LockOn_Options.script_path .. 'Systems/Gins_References.lua')
local M = {}
local function finite(value)
    return type(value)=='number' and value==value and math.abs(value)<math.huge
end
function M.new(get, put)
    local nav, sfg = References.reader(get, 'NAV'), References.reader(get, 'SFG')
    local function attitude(reference, pitch, roll, valid_key, pitch_key, roll_key)
        local valid = finite(pitch) and finite(roll)
        if reference.present then
            valid = reference.valid and reference.values.ATTITUDE_VALID == 1
            pitch, roll = reference.values.PITCH, reference.values.ROLL
        end
        put(valid_key, valid and 1 or 0)
        if valid then put(pitch_key, pitch); put(roll_key, roll) end
        return valid
    end
    local self = {}
    put('F22_PRIMARY_ATTITUDE_VALID',0);put('F22_SFG_ATTITUDE_VALID',0)
    put('F22_SFG_PITCH',0);put('F22_SFG_ROLL',0)
    put('F22_SFG_SOURCE_TEXT', '')
    function self.update(pitch, roll)
        nav:update(); sfg:update()
        attitude(nav, pitch, roll, 'F22_PRIMARY_ATTITUDE_VALID', 'ADIPITCH', 'ADIROLL')
        local valid = attitude(sfg, pitch, roll, 'F22_SFG_ATTITUDE_VALID', 'F22_SFG_PITCH', 'F22_SFG_ROLL')
        local source = sfg.valid and sfg.values.SOURCE or 0
        local text = source == 1 and 'SFG GINS 1' or source == 2 and 'SFG GINS 2' or 'SFG SOURCE --'
        if not valid then text = 'SFG NO ATT' end
        if text ~= self.previous then self.previous = text; put('F22_SFG_SOURCE_TEXT', text) end
    end
    return self
end
return M

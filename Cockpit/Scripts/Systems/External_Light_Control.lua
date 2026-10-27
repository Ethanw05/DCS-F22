-- GPL-3.0-or-later. Binding adapter to existing cockpit light switches.
-- The white/anti-collision/navigation shortcuts select the existing coupled
-- switch positions. They do not add independently simulated light circuits.
local M = {}
local controls = {
    { argument = 709, owner = 'ELECTRICAL_SYSTEM', command = 3004 },
    { argument = 714, owner = 'AVIONICS', command = 3007 },
    { argument = 715, owner = 'ELECTRICAL_SYSTEM', command = 3003 },
    { argument = 713, owner = 'ELECTRICAL_SYSTEM', command = 3002 },
}
function M.new(read, apply)
    local saved = { -1, .5, .4, .5 }
    local controller = {}
    function controller:command(command)
        if command >= 10505 and command <= 10512 then command = command + 1400 end
        if command < 11905 or command > 11912 then return false end
        local index = command == 11905 and 1 or command == 11906 and 1
            or command == 11907 and 2 or command == 11910 and 4 or 3
        if command == 11912 then
            local on = false
            for _, control in ipairs(controls) do
                if math.abs(read(control.argument)) > .01 then on = true end
            end
            for i, control in ipairs(controls) do
                if on then saved[i] = read(control.argument) end
                apply(control.owner, control.command, on and 0 or saved[i])
            end
        else
            local control = controls[index]
            local target = command == 11905 and -1 or command == 11908 and .1
                or command == 11909 and .2 or command == 11911 and .4 or 1
            local current = read(control.argument)
            apply(control.owner, control.command, math.abs(current - target) < .01 and 0 or target)
        end
        return true
    end
    return controller
end
return M

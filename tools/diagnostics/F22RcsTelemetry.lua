-- GPL-3.0-or-later. Passive export recorder for the dedicated RCS mission only.
-- No cockpit commands, AI commands, pause, camera changes or file controls.
local callbacks = {}
local active, last, count = false, -1, 0
local arguments = {600, 601, 602, 0, 3, 5, 22}
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end
local function emit(text)
    log.write('F22_RCS_OBSERVATION', log.INFO, text)
end
function callbacks.onSimulationStart()
    local filename = (DCS.getMissionFilename() or ''):gsub('\\', '/')
    active = filename:match('/F22%-RCS%-SAM%-Qualification%.miz$') ~= nil
    last, count = -1, 0
    if active then
        emit('START|' .. filename)
        emit('FIELDS|model_s|main_bay|left_bay|right_bay|nose_gear|right_gear|left_gear|refuel_door|jamming|x|y|z|heading|pitch|bank')
    end
end
function callbacks.onSimulationFrame()
    if not active or count >= 600 then return end
    local now = DCS.getModelTime()
    if not finite(now) then return end
    if last >= 0 and now < last then active = false; emit('CLOCK_RESET'); return end
    if now - last < 1 then return end
    last, count = now, count + 1
    local fields = {string.format('%.3f', now)}
    for index = 1, #arguments do
        local ok, value = false, nil
        if type(Export.LoGetAircraftDrawArgumentValue) == 'function' then
            ok, value = pcall(Export.LoGetAircraftDrawArgumentValue, arguments[index])
        end
        fields[#fields + 1] = ok and finite(value) and string.format('%.6f', value) or 'unknown'
    end
    local ok, own = pcall(Export.LoGetSelfData)
    fields[#fields + 1] = ok and own and own.Flags and tostring(own.Flags.Jamming) or 'unknown'
    local position = ok and own and own.Position or {}
    for _, key in ipairs({'x', 'y', 'z'}) do
        local value = position[key]
        fields[#fields + 1] = finite(value) and string.format('%.3f', value) or 'unknown'
    end
    for _, key in ipairs({'Heading', 'Pitch', 'Bank'}) do
        local value = ok and own and own[key]
        fields[#fields + 1] = finite(value) and string.format('%.6f', value) or 'unknown'
    end
    emit(table.concat(fields, '|'))
end
function callbacks.onSimulationStop()
    if active then emit('STOP|' .. count) end
    active = false
end
DCS.setUserCallbacks(callbacks)

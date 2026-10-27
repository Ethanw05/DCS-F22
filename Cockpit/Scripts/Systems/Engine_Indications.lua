-- Sole producer of cockpit engine/circuit indications; never integrates physics.
local Data = dofile(LockOn_Options.script_path .. 'Systems/Engine_Data.lua')
local M = {}
local specifications = {
    {'rpm', 'RPM_', 'RPM', 1, '%d'}, {'temperature', 'EGT_', 'EGT', 1, '%d'},
    {'oil', 'OIL_', 'OIL', 1, '%d'}, {'nozzle', '_NOZZLE_POS', 'NOZZLE', 1, '%02d'},
    {'flow', '_FF_VALUE', 'FLOW', 2.20462 * 3600, '%02d'},
    {'hydraulic', '_HYD_VALUE', 'HYD', 1, '%d'},
}

-- Retained mod display thresholds; these are not production engine limits.
local function rpm_color(value)
    if not value then return .5 end
    return value > 100 and 1 or .5
end
local function temperature_color(value)
    if not value or value < 730 then return 0 end
    return value < 850 and .5 or 1
end
local function oil_color(value)
    return value and value < 100 and 1 or 0
end
local function hydraulic_color(value)
    return value and value <= 1000 and 1 or 0
end
local colors = {rpm = rpm_color, temperature = temperature_color,
    oil = oil_color, hydraulic = hydraulic_color}

local function publish_field(field, value)
    local valid = value ~= nil
    field.valid:set(valid and 1 or 0)
    if field.color then field.color:set(field.color_value(value)) end
    if not valid then
        if field.last_text ~= '---' then field.text:set('---'); field.last_text = '---' end
        field.last_integer = nil
        return
    end
    local scaled = value * field.scale
    if field.last_value ~= scaled then field.number:set(scaled); field.last_value = scaled end
    local integer = math.floor(scaled + .5)
    if field.last_integer ~= integer then
        local text = string.format(field.format, integer)
        field.text:set(text)
        field.last_text, field.last_integer = text, integer
    end
end

function M.new(get_handle)
    local reader, sides = Data.new(get_handle), {}
    for index, letter in ipairs({'L', 'R'}) do
        local fields = {}
        for field = 1, #specifications do
            local spec = specifications[field]
            local numeric = field <= 3 and (spec[2] .. letter) or (letter .. spec[2])
            local prefix = 'F22_ENGINE_' .. letter .. '_' .. spec[3]
            local item = {metric = spec[1], scale = spec[4], format = spec[5],
                number = get_handle(numeric), text = get_handle(prefix .. '_TEXT'),
                valid = get_handle(prefix .. '_VALID')}
            if field <= 3 or field == 6 then
                item.color_value = colors[spec[1]]
                item.color = get_handle(letter .. '_' .. (field == 6 and 'HYD' or spec[3]) .. '_COLOR')
            end
            fields[field] = item
            publish_field(item, nil)
        end
        sides[index] = fields
    end
    local adapter = {reader = reader, readers = {reader.left, reader.right}, outputs = sides}
    function adapter:update()
        self.reader:update()
        for index = 1, 2 do
            local side = self.readers[index]
            for field = 1, #specifications do
                local item = self.outputs[index][field]
                publish_field(item, side[item.metric])
            end
        end
    end
    return adapter
end
return M

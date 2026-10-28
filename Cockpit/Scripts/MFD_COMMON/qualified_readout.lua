-- Qualified numeric values use native double formats; missing data is static text.
-- Read declaration tables only: DCS element properties are write-only.
local M = {}
local properties = {'material','init_pos','init_rot','alignment','stringdefs',
    'additive_alpha','collimated','isdraw','use_mipfilter','h_clip_relation',
    'level','parent_element','isvisible','change_opacity'}
local function copy(values)
    local out = {}
    for index = 1, #values do out[index] = values[index] end
    return out
end
local function element(spec, kind)
    local object = CreateElement(kind)
    for index = 1, #properties do
        local field = properties[index]
        if spec[field] ~= nil then object[field] = spec[field] end
    end
    return object
end
local function controllers(spec, include_text)
    local out = {}
    for index = 1, #spec.controllers do
        local control = spec.controllers[index]
        if include_text or control[1] ~= 'text_using_parameter' then
            out[#out + 1] = copy(control)
        end
    end
    return out
end
function M.add(spec, valid_parameter, kind)
    assert(type(spec)=='table' and type(spec.element_params)=='table' and type(spec.controllers)=='table')
    local number, unavailable = element(spec, kind), element(spec, kind)
    local parameters = copy(spec.element_params)
    local parameter_index = #parameters
    parameters[parameter_index + 1] = valid_parameter
    local numeric_controls, unavailable_controls = controllers(spec, true), controllers(spec, false)
    numeric_controls[#numeric_controls + 1] = {'parameter_in_range',parameter_index,.9,1.1}
    unavailable_controls[#unavailable_controls + 1] = {'parameter_in_range',parameter_index,-.1,.1}
    number.name = spec.name
    number.element_params = parameters
    number.formats = spec.formats
    number.controllers = numeric_controls
    unavailable.name = spec.name .. '_' .. valid_parameter .. '_UNAVAILABLE'
    unavailable.value = '---'
    unavailable.element_params = copy(parameters)
    unavailable.controllers = unavailable_controls
    Add(number)
    Add(unavailable)
end
return M

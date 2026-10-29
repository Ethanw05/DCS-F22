-- A designation must fit both the combiner and the declared indicator viewport.
-- Geometry/presentation only; no target selection, lock or ranging authority.
local Target = dofile(LockOn_Options.script_path..'Systems/HUD_TargetMath.lua')
local M = {}
local visible_margin, edge_margin = .014, .022 -- Slopes; cover retained marker vertices/stroke.
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end
local function contains(cue, width, height)
    return math.abs(cue.x) + visible_margin <= width and math.abs(cue.y) + visible_margin <= height
end
local function inset(cue, width, height)
    local scale = 1
    local x, y = math.abs(cue.arrow_x), math.abs(cue.arrow_y)
    if x > width then scale = math.min(scale, width/x) end
    if y > height then scale = math.min(scale, height/y) end
    cue.arrow_x, cue.arrow_y = cue.arrow_x*scale, cue.arrow_y*scale
end
function M.new(glass, geometry)
    assert(type(geometry) == 'table', 'HUD viewport geometry required')
    assert(finite(geometry.width) and finite(geometry.height), 'Finite HUD viewport required')
    assert(finite(geometry.focal_length) and geometry.focal_length > 0, 'Positive HUD focal length required')
    local width = geometry.width/(2*geometry.focal_length)
    local height = geometry.height/(2*geometry.focal_length)
    assert(math.min(width, height) > edge_margin, 'HUD viewport cannot contain the designation marker')
    local project = Target.new(glass)
    return function(az, el)
        if not finite(az) or not finite(el) or math.abs(az) > math.pi or math.abs(el) > math.pi/2 then return end
        local cue = project(az, el)
        cue.visible = cue.visible and contains(cue, width, height)
        if not cue.visible then inset(cue, width-edge_margin, height-edge_margin) end
        return cue
    end
end
return M

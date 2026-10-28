-- Native declination admission. World seconds and physical generation are explicit.
local M = {}
local function finite(value)
    return type(value)=='number' and value==value and math.abs(value)<math.huge
end
local function committed(sequence)
    return finite(sequence) and sequence>=2 and sequence<=16777214 and sequence%2==0
end
local function fresh(stamp,now)
    if not finite(now) or now<0 or not finite(stamp) or stamp<0 then return false end
    return now-stamp>=-.01 and now-stamp<=.25
end
local function valid_generation(value)
    return finite(value) and value>=1 and value<=4294967295 and value%1==0
end
local function metadata(schema,kind,valid,generation,expected)
    return schema==1 and kind==2 and valid==1 and generation==expected and valid_generation(generation)
end
local function capture(get,generation,now)
    local sequence=get('F22_MAG_SEQUENCE')
    if not committed(sequence) then return end
    local schema,kind=get('F22_MAG_SCHEMA'),get('F22_MAG_CLOCK_KIND')
    local source_generation,stamp=get('F22_MAG_GENERATION'),get('F22_MAG_STAMP')
    local valid,declination=get('F22_MAG_VALID'),get('F22_MAG_DECL')
    if not metadata(schema,kind,valid,source_generation,generation) then return end
    if not fresh(stamp,now) then return end
    if not finite(declination) or math.abs(declination)>=1.57 then return end
    if get('F22_MAG_SEQUENCE')~=sequence or get('F22_MAG_GENERATION')~=source_generation
        or get('F22_MAG_VALID')~=1 then return end
    return declination
end
local function degrees(radians)
    local value=math.deg(radians)
    local nearest=math.floor(value+.5)
    if math.abs(value-nearest)<1e-9 then value=nearest end -- Degree/radian roundtrip precision only.
    return value%360
end
function M.heading(get,true_radians,reference,generation,now)
    if not finite(true_radians) then return end
    if reference==0 then return degrees(true_radians) end
    if reference~=1 then return end
    local ok,declination=pcall(capture,get,generation,now)
    if ok and declination~=nil then return degrees(true_radians-declination) end
end
return M

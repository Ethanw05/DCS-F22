-- GPL-3.0-or-later. Read-only values; no checklist item repairs hardware.
local Envelope=dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua')
local M={}
local fields={'EFM_VEHICLE_VALID','EFM_MASS_VALID','EFM_MASS_KG','EFM_TRIM_VALID',
    'EFM_TRIM_LEFT_DEG','EFM_TRIM_RIGHT_DEG','EFM_INTERNAL_FUEL_KG','EFM_EXTERNAL_FUEL_KG',
    'F22_ESSENTIAL_POWER','EFM_GEAR_DOWN_LOCKED','EFM_GEAR_UP_LOCKED','EFM_GEAR_UNSAFE'}
local function finite(value)return Envelope.finite(value)and math.abs(value)<1e9 end
local function mass(sample)
    local value=sample('EFM_MASS_KG')
    if sample('EFM_MASS_VALID')~=1 or not finite(value)or value<=0 then return 'WEIGHT --'end
    return string.format('WEIGHT %.0f LB',value*2.204622622)
end
local function trim(sample)
    local left,right=sample('EFM_TRIM_LEFT_DEG'),sample('EFM_TRIM_RIGHT_DEG')
    if sample('EFM_TRIM_VALID')~=1 or not finite(left)or not finite(right)then return 'TAIL --'end
    return string.format('TAIL L %.1f R %.1f DEG',left,right)
end
local function fuel(sample)
    local internal,external=sample('EFM_INTERNAL_FUEL_KG'),sample('EFM_EXTERNAL_FUEL_KG')
    if sample('EFM_VEHICLE_VALID')~=1 or not finite(internal)or not finite(external)
        or internal<0 or external<0 then return 'FUEL --'end
    return string.format('FUEL %.0f LB',(internal+external)*2.204622622)
end
local function supply(sample,snapshot,get)
    local value
    if snapshot.owned then value=sample('F22_ESSENTIAL_POWER')else value=get('MAIN_POWER')end
    if sample('EFM_VEHICLE_VALID')~=1 or not finite(value)then return 'SUPPLY --'end
    return value>.5 and 'SUPPLY AVAILABLE'or'SUPPLY LOST'
end
local function gear(sample,snapshot)
    local down,up,unsafe=sample('EFM_GEAR_DOWN_LOCKED'),sample('EFM_GEAR_UP_LOCKED'),sample('EFM_GEAR_UNSAFE')
    if not snapshot.valid or not Envelope.boolean(down)or not Envelope.boolean(up)
        or not Envelope.boolean(unsafe)or down+up>1 then return 'GEAR --'end
    if unsafe==1 then return 'GEAR UNSAFE'end
    if down==1 then return 'GEAR DOWN'end
    return up==1 and 'GEAR UP'or'GEAR TRANSIT'
end
function M.new(get,put)
    local snapshot=Envelope.new(get,fields)
    local function sample(key)
        if not snapshot.owned then return get(key)end
        if snapshot.valid then return snapshot.values[key]end
    end
    local previous,values={},{valid=false,owned=false,initialized=false}
    local function changed()
        local different=not values.initialized or values.valid~=snapshot.valid or values.owned~=snapshot.owned
        values.initialized,values.valid,values.owned=true,snapshot.valid,snapshot.owned
        for index=1,#fields do
            local key=fields[index];local value=sample(key)
            if values[key]~=value then values[key]=value;different=true end
        end
        local main=get('MAIN_POWER')
        if values.main~=main then values.main=main;different=true end
        return different
    end
    local function publish(key,value)
        if previous[key]~=value then previous[key]=value;put(key,value)end
    end
    for _,key in ipairs({'MASS','TRIM','FUEL','SUPPLY','GEAR'})do publish('F22_REFERENCE_'..key,key..' --')end
    local references={}
    function references.update()
        snapshot:update()
        if not changed()then return end
        publish('F22_REFERENCE_MASS',mass(sample));publish('F22_REFERENCE_TRIM',trim(sample))
        publish('F22_REFERENCE_FUEL',fuel(sample));publish('F22_REFERENCE_SUPPLY',supply(sample,snapshot,get))
        publish('F22_REFERENCE_GEAR',gear(sample,snapshot))
    end
    return references
end
return M

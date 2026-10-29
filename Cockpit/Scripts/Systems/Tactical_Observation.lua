-- GPL-3.0-or-later. Bounded admission; copying never renews source age.
local M = {}
local Geo = dofile(LockOn_Options.script_path .. 'Systems/EW_Geolocation.lua')
local function finite(v)
    return type(v)=='number' and v==v and math.abs(v)<1e12
end
local function source(v)
    return finite(v) and v>=1 and v<4294967296 and v%1==0
end
local function geometry(o, limit)
    return source(o.source) and finite(o.age) and o.age>=0 and o.age<=limit
        and finite(o.az) and math.abs(o.az)<=2*math.pi+.001
        and finite(o.el) and math.abs(o.el)<=math.pi/2+.001
end
local function range(v)
    return finite(v) and v>=40 and v or nil
end
local function world(c, o)
    local w = o.world
    if type(w)=='table' and finite(w[1]) and finite(w[2]) and finite(w[3])
        and math.abs(w[1]^2+w[2]^2+w[3]^2-1)<=.005 then
        c.world = {w[1],w[2],w[3]}
    end
    local origin = o.bearing_origin
    if type(origin)=='table' and finite(origin.n) and finite(origin.u) and finite(origin.e)
        and finite(origin.time) and math.abs(origin.time-c.time)<=.1 then
        c.bearing_origin = {n=origin.n,u=origin.u,e=origin.e,time=origin.time}
    end
end
local function rf(c, o, stamp)
    c.power = finite(o.power) and o.power>=0 and o.power<=1 and o.power or nil
    c.general = o.general
    world(c, o)
    if o.general~=2 or not c.world then return end
    c.geolocation_status = ({[1]=true,[2]=true,[3]=true,[4]=true})[o.geolocation_status]
        and o.geolocation_status or 0
    if Geo.current(o.geolocation, stamp) then
        c.geolocation = {}
        for k,v in pairs(o.geolocation) do c.geolocation[k] = v end
    end
end
local ranged_fields = {'n','u','e','vn','vu','ve','link','reporter','flight','ppli',
    'received','observation_known','observation_time','velocity_valid',
    'position_sigma_m','velocity_sigma_mps','motion_estimated'}
local function identity(c, o)
    c.friendly, c.hostile = o.friendly==true, o.hostile==true
    c.identity_known = o.identity_known
    c.identity_time = finite(o.identity_time) and o.identity_time or nil
    c.hostile_time = finite(o.hostile_time) and o.hostile_time or nil
end
local function copy(o, sensor, batch)
    local c = {source=o.source, time=batch.time-o.age, az=o.az, el=o.el,
        epoch=o.epoch or batch.epoch, signal=o.signal, label=o.label,
        selected=o.selected==true, quality=o.quality, estimated=o.estimated==true,
        uncertainty=finite(o.uncertainty) and o.uncertainty>=0 and o.uncertainty or nil,
        measurement_source=(o.measurement_source==1 or o.measurement_source==2)
            and o.measurement_source or 0}
    identity(c, o)
    if sensor=='radar' then c.range, c.measured_range = range(o.range), range(o.measured_range) end
    if sensor=='radar' or sensor=='datalink' then
        for _,k in ipairs(ranged_fields) do c[k] = o[k] end
    end
    if sensor=='rf' then rf(c, o, batch.time) end
    return c
end
local function key(c, sensor)
    if sensor~='datalink' then return c.source end
    return tostring(c.link)..':'..tostring(c.reporter)..':'..c.source..':'..(c.ppli and 'p' or 't')
end
function M.admit(batch, sensor, limit, capacity)
    local accepted, inputs = {}, batch.contacts or {}
    for index=1,math.min(#inputs, capacity) do
        local o = inputs[index]
        local signal = sensor~='rf' or o.signal==1 or o.signal==2 or o.signal==3
        if signal and geometry(o, limit) then
            local c = copy(o, sensor, batch)
            local id = key(c, sensor)
            if not accepted[id] or accepted[id].time<c.time then accepted[id] = c end
        end
    end
    return accepted
end
return M

-- GPL-3.0-or-later. Original radar coordinate evidence, not receipt freshness.
local M = {}
local function finite(v)
    return type(v)=="number" and v==v and math.abs(v)<1e9
end
local function integer(v,lo,hi)
    return finite(v) and v>=lo and v<=hi and v%1==0
end
local function header(get,now)
    local before=get("F22_AG_NATIVE_CONTROL_SEQUENCE")
    if not integer(before,2,16777214) or before%2~=0
        or get("F22_AG_NATIVE_CONTROL_SCHEMA")~=1 then return end
    local epoch,producer=get("F22_AG_NATIVE_CONTROL_EPOCH"),get("F22_AG_NATIVE_CONTROL_TIME")
    if not integer(epoch,1,16777215) or not finite(producer) or now<producer or now-producer>.5 then return end
    return before,epoch
end
local function geometry(r)
    for _,key in ipairs({"n","u","e"}) do if not finite(r[key]) then return false end end
    return math.abs(r.n)<=3e7 and math.abs(r.e)<=3e7 and r.u>=-500 and r.u<=100000
end
local function observation(r,now)
    return finite(r.time) and r.time>=0 and now>=r.time
        and integer(r.request,0,16777215) and integer(r.kind,1,3)
end
local function payload(get,now,epoch,r)
    r.n,r.u,r.e=get("F22_AG_DESIGNATION_NORTH"),get("F22_AG_DESIGNATION_ALTITUDE"),get("F22_AG_DESIGNATION_EAST")
    r.time,r.request=get("F22_AG_DESIGNATION_TIME"),get("F22_AG_DESIGNATION_REQUEST")
    r.kind=get("F22_AG_DESIGNATION_TYPE")
    local live=get("F22_AG_DESIGNATION_LIVE")
    if live~=0 and live~=1 then return false end
    r.live=live==1
    if get("F22_AG_DESIGNATION_SCHEMA")~=1 or get("F22_AG_DESIGNATION_EPOCH")~=epoch
        or not geometry(r) or not observation(r,now) then return false end
    if r.kind~=3 and (not r.live or now-r.time>5.25) then r.valid=false end
    return true
end
function M.read(get,now)
    if not finite(now) or now<0 then return end
    local before,epoch=header(get,now)
    if not before then return end
    local logical,valid=get("F22_AG_DESIGNATION_SEQUENCE"),get("F22_AG_DESIGNATION_VALID")
    if not integer(logical,0,16777215) or valid~=0 and valid~=1 then return end
    local r={sequence=logical,epoch=epoch,valid=valid==1}
    if r.valid and not payload(get,now,epoch,r) then return end
    if before~=get("F22_AG_NATIVE_CONTROL_SEQUENCE") or epoch~=get("F22_AG_NATIVE_CONTROL_EPOCH") then return end
    return r
end
function M.current(target,get,now)
    if not target or target.source~=2 then return target~=nil end
    if not finite(now) or not finite(target.time) or now<target.time then return false end
    local epoch=get("F22_AG_NATIVE_SOURCE_EPOCH")
    if integer(epoch,1,16777215) and epoch~=target.epoch then return false end
    if target.kind==3 then return true end -- Explicit retained fixed coordinate.
    local packet=M.read(get,now)
    return packet and packet.valid and packet.epoch==target.epoch
        and packet.request==target.request and now-target.time<=5.25 or false
end
return M

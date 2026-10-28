-- GPL-3.0-or-later. Checked target tuples; packet liveness is not sample age.
local Evidence = dofile(LockOn_Options.script_path.."Systems/AG_Target_Provenance.lua")
local M = { producer_lease = .5, read_failure = false }
local function finite(v)
    return type(v) == "number" and v == v and math.abs(v) < 1e9
end
local function integer(v, lo, hi)
    return finite(v) and v >= lo and v <= hi and v % 1 == 0
end
local function valid_clock(now)
    return finite(now) and now >= 0
end
local function geometry(p)
    return p and finite(p.n) and finite(p.u) and finite(p.e)
        and math.abs(p.n) <= 3e7 and math.abs(p.e) <= 3e7 and p.u >= -500 and p.u <= 100000
end
local function unmeasured(p)
    return not p.observation_known and p.time == -100 and p.epoch == 0
        and p.request == 0 and p.kind == 0 and p.observation_sequence == 0 and not p.live
end
local function live_kind(p)
    if p.kind == 3 then return not p.live end
    return p.live
end
local function measured(p)
    return p.observation_known and valid_clock(p.time)
        and integer(p.epoch, 1, 16777215) and integer(p.request, 0, 16777215)
        and integer(p.kind, 1, 3) and integer(p.observation_sequence, 0, 16777215)
        and live_kind(p)
end
local function provenance(p)
    if not integer(p.source, 1, 3) or type(p.observation_known) ~= "boolean"
        or type(p.live) ~= "boolean" then return false end
    if p.source ~= 2 then return unmeasured(p) end
    return measured(p)
end
local function live_evidence(p, get, now)
    local current = Evidence.read(get, now)
    return current and current.valid and current.kind == p.kind and current.live
        and current.epoch == p.epoch and current.request == p.request and current.time >= p.time or false
end
local function current_evidence(p, get, now)
    if now < p.time or get("F22_AG_NATIVE_SOURCE_EPOCH") ~= p.epoch then return false end
    if not Evidence.current(p, get, now) then return false end
    if p.kind == 3 then return true end -- An explicit fixed coordinate retains its sample time.
    return live_evidence(p, get, now)
end
local function current(p, get, now)
    if not geometry(p) or not provenance(p) or not valid_clock(now) then return false end
    if p.source ~= 2 then return true end
    return current_evidence(p, get, now)
end
function M.current(p, get, now)
    local ok, valid = pcall(current, p, get, now)
    M.read_failure = not ok
    return ok and valid or false
end
local mark = {
    packet="F22_AG_TARGET_PACKET_", prefix="F22_AG_TARGET_",
    valid="HUD_AG_TARGET_VALID", n="HUD_AG_MARK_NORTH", u="HUD_AG_MARK_ALT", e="HUD_AG_MARK_EAST",
    navigation_ack = true,
}
local delivery = {
    packet="F22_AG_DELIVERY_TARGET_PACKET_", prefix="F22_AG_DELIVERY_TARGET_",
    valid="F22_AG_DELIVERY_TARGET_VALID", n="F22_AG_DELIVERY_TARGET_N",
    u="F22_AG_DELIVERY_TARGET_U", e="F22_AG_DELIVERY_TARGET_E", routed=true,
}
local function metadata(get, prefix, p)
    local known, live = get(prefix.."OBSERVATION_KNOWN"), get(prefix.."SOURCE_LIVE")
    if known ~= 0 and known ~= 1 or live ~= 0 and live ~= 1 then return false end
    p.observation_known, p.live = known == 1, live == 1
    p.time = get(prefix.."OBSERVATION_TIME")
    p.observation_sequence = get(prefix.."OBSERVATION_SEQUENCE")
    p.epoch = get(prefix.."SOURCE_EPOCH")
    p.request = get(prefix.."SOURCE_REQUEST")
    p.kind = get(prefix.."SOURCE_TYPE")
    return true
end
local function fresh(stamp, now)
    return valid_clock(stamp) and valid_clock(now) and now >= stamp and now - stamp <= M.producer_lease
end
local function header(get, now, schema)
    local packet = schema.packet
    local sequence = get(packet.."SEQUENCE")
    if not integer(sequence, 2, 16777214) or sequence % 2 ~= 0
        or get(packet.."SCHEMA") ~= 1 then return end
    local epoch, stamp = get(packet.."EPOCH"), get(packet.."TIME")
    if not integer(epoch, 1, 16777215) or not fresh(stamp, now) then return end
    local valid = get(schema.valid)
    if valid ~= 0 and valid ~= 1 then return end
    return {sequence = sequence, epoch = epoch, stamp = stamp, valid = valid == 1}
end
local function navigation_ack(get, p)
    p.nav_request = get("F22_NAV_TARGET_ACK_SEQUENCE")
    p.nav_target_sequence = get("F22_NAV_TARGET_ACK_TARGET_SEQUENCE")
    p.nav_result = get("F22_NAV_TARGET_RESULT")
    return integer(p.nav_request, 0, 16777215) and integer(p.nav_target_sequence, 0, 16777215)
        and integer(p.nav_result, 0, 5)
end
local function payload(get, schema, accepted)
    local prefix = schema.prefix
    local p = {n = get(schema.n), u = get(schema.u), e = get(schema.e),
        sequence = get(prefix.."SEQUENCE"),
        source = get(prefix..(schema.routed and "ORIGIN_SOURCE" or "SOURCE")),
        packet_epoch = accepted.epoch, packet_time = accepted.stamp, valid = accepted.valid}
    if schema.routed then
        p.delivery_source = get(prefix.."SOURCE")
        if not integer(p.delivery_source, 1, 3) then return end
    end
    if schema.navigation_ack and not navigation_ack(get, p) then return end
    return p
end
local function coherent(get, schema, accepted)
    return accepted.sequence == get(schema.packet.."SEQUENCE")
        and accepted.epoch == get(schema.packet.."EPOCH")
end
local function read(get, now, schema, allow_invalid)
    local accepted = header(get, now, schema)
    if not accepted then return end
    if not accepted.valid and not allow_invalid then return end
    local p = payload(get, schema, accepted)
    if not p or not integer(p.sequence, 1, 16777215) or not metadata(get, schema.prefix, p) then return end
    if p.valid and not current(p, get, now) then return end
    if not coherent(get, schema, accepted) then return end
    return p
end
local function checked_read(get, now, schema, allow_invalid)
    local ok, point = pcall(read, get, now, schema, allow_invalid)
    M.read_failure = not ok
    if ok then return point end
end
function M.read(get, now)
    return checked_read(get, now, mark)
end
function M.read_delivery(get, now)
    return checked_read(get, now, delivery)
end
function M.read_packet(get, now)
    return checked_read(get, now, mark, true)
end
local copy_fields={"n","u","e","source","sequence","time","epoch","request","kind","live",
    "observation_known","observation_sequence","packet_time","packet_epoch"}
function M.copy(point)
    if not point then return end
    local result = {}
    for i = 1, #copy_fields do
        local key = copy_fields[i]
        result[key] = point[key]
    end
    return result
end
local unknown = {time = -100, observation_sequence = 0, epoch = 0, request = 0, kind = 0, live = false}
function M.publish_metadata(put, prefix, point)
    local known = point and point.source == 2 and point.observation_known
    local evidence = unknown
    if known then evidence = point end
    put(prefix.."OBSERVATION_KNOWN", known and 1 or 0)
    put(prefix.."OBSERVATION_TIME", evidence.time)
    put(prefix.."OBSERVATION_SEQUENCE", evidence.observation_sequence)
    put(prefix.."SOURCE_EPOCH", evidence.epoch)
    put(prefix.."SOURCE_REQUEST", evidence.request)
    put(prefix.."SOURCE_TYPE", evidence.kind)
    put(prefix.."SOURCE_LIVE", evidence.live and 1 or 0)
end
return M

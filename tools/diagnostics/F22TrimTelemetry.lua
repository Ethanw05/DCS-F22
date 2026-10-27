-- Passive trim recorder. No commands, cockpit state writes or flight controls.
-- Install in Saved Games/DCS/Scripts/Hooks. F-22A player sessions only.
local cb = {}
local recording_session = false
local file, filename, start_time, last_sample, last_flush, rows
local fields = {
    "VALID", "CLOCK", "IAS_KTS", "TAS_MPS", "MACH", "ALT_M", "AOA_DEG",
    "PITCH_DEG", "ROLL_DEG", "Q_DEGPS", "P_DEGPS", "NZ", "STICK",
    "PITCH", "ROLL", "YAW", "AUTO", "AUTO_ACTIVE", "AUTO_INHIBIT", "MANUAL",
    "TAKEOFF", "STICK_TERM", "DAMP_TERM", "RAW", "ELEVATOR", "LEFT_DEG",
    "RIGHT_DEG", "Q_PA", "EVENT_LEFT", "EVENT_RIGHT", "EVENT_UP", "EVENT_DOWN",
    "EVENT_RESET", "EVENT_RUDDER_LEFT", "EVENT_RUDDER_RIGHT", "EVENT_STOP",
    "LAST_COMMAND", "LAST_VALUE", "LAST_STAMP",
}
local parameters = {}
for _, name in ipairs(fields) do parameters[#parameters + 1] = "EFM_TRIM_" .. name end
for _, name in ipairs({
    "F22_AP_ACTIVE", "F22_AP_ROLL_MODE", "F22_AP_PITCH_MODE", "F22_AP_OVERRIDE",
    "EFM_ACTUATOR_AVAILABLE", "EFM_FCS_DAMAGED", "EFM_WEIGHT_ON_WHEELS",
    "EFM_HUD_VN", "EFM_HUD_VU", "EFM_HUD_VE",
}) do parameters[#parameters + 1] = name end
local quoted = {}
for _, name in ipairs(parameters) do quoted[#quoted + 1] = string.format("%q", name) end
local expression = [[
local s=LoGetSelfData()
if not s or s.Name~='F-22A' then return 'NOT_F22' end
if get_param_handle('EFM_TRIM_VALID'):get()<.5 then return 'NO_INSTRUMENTATION' end
local a={}
for _,n in ipairs({]] .. table.concat(quoted, ",") .. [[})do
 a[#a+1]=string.format('%.9g',get_param_handle(n):get())
end
a[#a+1]=string.format('%.9g',LoGetIndicatedAirSpeed() or 0)
a[#a+1]=string.format('%.9g',s.Position.y)
a[#a+1]=string.format('%.9g',s.Pitch)
a[#a+1]=string.format('%.9g',s.Bank)
return table.concat(a,',')
]]
local failed = false
local function close()
    if file then file:flush(); file:close(); file = nil end
end
function cb.onSimulationStart()
    close()
    recording_session = true
    filename = nil
    start_time = nil
    last_sample = -1
    last_flush = -1
    rows = 0
    failed = false
end
function cb.onSimulationFrame()
    if not recording_session or failed then return end
    local now = DCS.getModelTime()
    if now - last_sample < .05 then return end
    last_sample = now
    if start_time and now - start_time > 3600 then close(); failed = true; return end
    local ok, data, err = pcall(net.dostring_in, "export", expression)
    if not ok or not data then return end
    if data == "NOT_F22" or data == "NO_INSTRUMENTATION" then
        if file then close() end
        return
    end
    -- Accept only a complete numeric row. API errors never enter the CSV.
    local count = 0
    for item in tostring(data):gmatch("[^,]+") do
        if not tonumber(item) then return end
        count = count + 1
    end
    if count ~= #parameters + 4 then return end
    if not file then
        local directory = lfs.writedir() .. "Logs/F22-Trim/"
        lfs.mkdir(directory)
        filename = directory .. "trim-" .. os.date("%Y%m%d-%H%M%S") .. "-" .. tostring(math.floor(now * 1000)) .. ".csv"
        file = io.open(filename, "w")
        if not file then
            log.write("F22_TRIM", log.ERROR, "Cannot open trim CSV")
            failed = true
            return
        end
        file:write("MODEL_TIME," .. table.concat(parameters, ",") .. ",EXPORT_IAS_MPS,EXPORT_ALT_M,EXPORT_PITCH_RAD,EXPORT_BANK_RAD\n")
        start_time = now
        log.write("F22_TRIM", log.INFO, "Recording " .. filename)
    end
    file:write(string.format("%.6f,", now) .. data .. "\n")
    rows = rows + 1
    if now - last_flush >= 1 then file:flush(); last_flush = now end
end
function cb.onSimulationStop()
    recording_session = false
    close()
    if filename then log.write("F22_TRIM", log.INFO, "Closed " .. tostring(rows) .. " rows: " .. filename) end
end
DCS.setUserCallbacks(cb)

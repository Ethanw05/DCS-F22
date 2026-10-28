-- GPL-3.0-or-later. Local observer/control bridge, inert outside this one mission.
local callbacks = {}
local active, initialized, next_sample, last_nonce = false, false, 0, 0
local samples, start = 0, 0
local function emit(kind, ...)
    local row = {'F22_EW_TRIAL', kind, string.format('%.3f', DCS.getModelTime())}
    for i = 1, select('#', ...) do row[#row+1] = tostring(select(i, ...)) end
    log.write('F22_EW_TRIAL', log.INFO, table.concat(row, '|'))
end
function callbacks.onSimulationStart()
    local filename = (DCS.getMissionFilename() or ''):gsub('\\', '/')
    active = filename:match('/F22%-EW%-Duel%.miz$') ~= nil
    initialized, next_sample, last_nonce, samples = false, 0, 0, 0
    start = DCS.getModelTime()
    if active then emit('HOOK_START', filename) end
end
local function initialize()
    local ok, error = pcall(function()
        Export.GetDevice(4):SetCommand(106, 1)
        Export.GetDevice(14):SetCommand(10601, 1)
    end)
    emit('COCKPIT_SETUP', ok and 1 or 0, error or '')
    initialized = true
end
local function own_sample()
    local own = Export.LoGetSelfData()
    local flag = own and own.Flags and own.Flags.Jamming
    local device = Export.GetDevice(15)
    local ok, enabled = pcall(function() return device:get_ECM_status() end)
    local known = ok and (type(enabled)=='boolean' or enabled==0 or enabled==1)
    emit('OWN_ECM', known and 1 or 0, known and tostring(enabled) or 'unknown',
        flag == nil and 'unknown' or tostring(flag))
end
local function pilot_commands()
    local result = net.dostring_in('mission', 'return tostring(trigger.misc.getUserFlag(5102))')
    local nonce = tonumber(result)
    if not nonce or nonce == last_nonce then return end
    last_nonce = nonce
    local ok, error = pcall(function() Export.GetDevice(20):SetCommand(136, 1) end)
    emit('COCKPIT_COMMAND', nonce, ok and 1 or 0, error or '')
end
function callbacks.onSimulationFrame()
    if not active or samples >= 6000 then return end
    local now = DCS.getModelTime()
    if now-start < 2 or now < next_sample then return end
    next_sample = now+.2;samples=samples+1
    if not initialized then initialize() end
    local ok, error = pcall(function() own_sample();pilot_commands() end)
    if not ok then emit('HOOK_ERROR', error) end
end
function callbacks.onSimulationStop()
    if active then emit('HOOK_STOP', samples) end
    active = false
end
DCS.setUserCallbacks(callbacks)

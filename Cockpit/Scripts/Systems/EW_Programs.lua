-- GPL-3.0-or-later. Three game banks; flat Hornet-inspired total-cycle schema.
local M = { intervals = { 0.1, 0.25, 0.5, 1, 2 }, bank_count = 3 }
local function integer(value, low, high)
    return type(value) == 'number' and value >= low and value <= high and value % 1 == 0
end
local function copy(program)
    return { chaff = program.chaff, flare = program.flare,
        interval = program.interval, repetitions = program.repetitions }
end
function M.valid(program)
    if type(program) ~= 'table' or not integer(program.chaff, 0, 4)
        or not integer(program.flare, 0, 4) or program.chaff + program.flare == 0
        or not integer(program.repetitions, 1, 8) then
        return false
    end
    for i = 1, #M.intervals do
        if program.interval == M.intervals[i] then return true end
    end
    return false
end
function M.new()
    local state = { selected = 1, normal = 1, direct = 2, dirty = false, error = false,
        programs = {
            { chaff = 1, flare = 1, interval = 0.25, repetitions = 4 },
            { chaff = 0, flare = 1, interval = 0.25, repetitions = 2 },
            { chaff = 1, flare = 1, interval = 0.25, repetitions = 6 },
        } }
    state.draft = copy(state.programs[1])
    return setmetatable(state, { __index = M })
end
function M:capture(index)
    local program = integer(index, 1, M.bank_count) and self.programs[index]
    if M.valid(program) then return copy(program) end
end
function M:command(command)
    local program = self.draft
    if command == 10910 then
        self.selected = self.selected % M.bank_count + 1
        self.draft = copy(self.programs[self.selected])
        self.dirty, self.error = false, false
    elseif command == 11103 then
        self.error = not M.valid(program)
        if self.error then return false end
        self.programs[self.selected] = copy(program)
        self.dirty = false
    elseif command == 11104 then
        self.draft = copy(self.programs[self.selected])
        self.dirty, self.error = false, false
    elseif command == 11105 then
        self.normal = self.normal % M.bank_count + 1
    elseif command == 11106 then
        self.direct = self.direct % M.bank_count + 1
    elseif command >= 10911 and command <= 10914 then
        self:edit(command)
    else
        return false
    end
    return true
end
function M:edit(command)
    local program = self.draft
    if command == 10911 then program.chaff = (program.chaff + 1) % 5
    elseif command == 10912 then program.flare = (program.flare + 1) % 5
    elseif command == 10914 then program.repetitions = program.repetitions % 8 + 1
    elseif command == 10913 then
        for i = 1, #M.intervals do
            if program.interval == M.intervals[i] then
                program.interval = M.intervals[i % #M.intervals + 1]
                break
            end
        end
    end
    self.dirty, self.error = true, false
end
local function publish_program(put, prefix, program)
    put(prefix .. 'CHAFF', program.chaff)
    put(prefix .. 'FLARE', program.flare)
    put(prefix .. 'INTERVAL', program.interval)
    put(prefix .. 'REPETITIONS', program.repetitions) -- Legacy ABI: total cycles.
    put(prefix .. 'CYCLES', program.repetitions)
end
function M:publish(put)
    for index = 1, M.bank_count do
        publish_program(put, 'F22_CM_PROGRAM_' .. index .. '_', self.programs[index])
    end
    publish_program(put, 'F22_CM_PROGRAM_', self.draft)
    put('F22_CM_PROGRAM_SELECTED', self.selected) -- Edit bank, never dispense authority.
    put('F22_CM_NORMAL_BANK', self.normal)
    put('F22_CM_DIRECT_BANK', self.direct)
    put('F22_CM_DRAFT_DIRTY', self.dirty and 1 or 0)
    put('F22_CM_DRAFT_ERROR', self.error and 1 or 0)
end
function M.read(get, index)
    if not integer(index, 1, M.bank_count) then return nil end
    local prefix = 'F22_CM_PROGRAM_' .. index .. '_'
    local program = { chaff = get(prefix .. 'CHAFF'), flare = get(prefix .. 'FLARE'),
        interval = get(prefix .. 'INTERVAL'), repetitions = get(prefix .. 'REPETITIONS') }
    if M.valid(program) then return program end
end
return M

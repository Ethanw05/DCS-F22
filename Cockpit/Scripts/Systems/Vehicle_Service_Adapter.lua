-- Pilot request/read-only service adapter. The EFM owns receptacle travel.
local Envelope = dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua')
local M = {}
function M.new()
    local handles = {}
    local function handle(name)
        if not handles[name] then handles[name] = get_param_handle(name) end
        return handles[name]
    end
    local function get(name) return handle(name):get() end
    local snapshot = Envelope.new(get, {'EFM_REFUEL_DOOR_POSITION',
        'EFM_REFUEL_READY', 'EFM_REFUEL_TRANSFER'})
    local door = handle('F22_REFUEL_DOOR_REQUEST')
    local disconnect = handle('F22_REFUEL_DISCONNECT_REQUEST')
    local ready_valid = handle('F22_REFUEL_READY_VALID')
    local contact_valid = handle('F22_REFUEL_CONTACT_VALID')
    local self = {selected = 0, valid = false, ready = 0, transfer = false,
        momentary_pressed = false, momentary_owned = false}
    function self:select(value)
        if not Envelope.boolean(value) then return false end
        self.momentary_owned = false
        self.selected = value
        door:set(value)
        disconnect:set(value == 0 and 1 or 0)
        return true
    end
    function self:momentary(value)
        if not Envelope.boolean(value) then return false end
        if value == 1 then
            if self.momentary_pressed then return false end
            self.momentary_pressed = true
            self:select(1)
            self.momentary_owned = true
        else
            if not self.momentary_pressed then return false end
            self.momentary_pressed = false
            if self.momentary_owned then self:select(0) end
            self.momentary_owned = false
        end
        return true
    end
    function self:update()
        door:set(self.selected)
        disconnect:set(self.selected == 0 and 1 or 0)
        self.valid, self.ready, self.transfer = false, 0, false
        ready_valid:set(0)
        -- Accepted host fuel can be ground service; it cannot authenticate
        -- tanker contact. No qualified contact API is currently provided.
        contact_valid:set(0)
        local frame = snapshot:update()
        if not frame.valid then return false end
        if self.generation and self.generation ~= frame.generation then
            self:select(0)
            self.momentary_pressed = false
            self.generation = frame.generation
            return false
        end
        self.generation = frame.generation
        local v = frame.values
        if not Envelope.finite(v.EFM_REFUEL_DOOR_POSITION)
            or v.EFM_REFUEL_DOOR_POSITION < 0 or v.EFM_REFUEL_DOOR_POSITION > 1
            or not Envelope.boolean(v.EFM_REFUEL_READY)
            or not Envelope.boolean(v.EFM_REFUEL_TRANSFER) then return false end
        self.valid = true
        self.ready = self.selected == 1 and v.EFM_REFUEL_DOOR_POSITION >= .99
            and v.EFM_REFUEL_READY == 1 and 1 or 0
        self.transfer = v.EFM_REFUEL_TRANSFER == 1
        ready_valid:set(1)
        return true
    end
    self:select(0)
    return self
end
return M

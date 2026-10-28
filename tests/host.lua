-- Independent Lua 5.1 host-contract port. No aircraft or healthy source defaults.
local M = {}
function M.new(root)
    local self = { values = {}, sensors = {}, actions = {}, elements = {},
        commands = {}, time = 0, epoch = 1, capacity = 64 }
    local function unavailable(name)
        error('Unconfigured host export: '..name, 2)
    end
    function self.handle(name)
        assert(type(name) == 'string' and #name <= 128)
        -- Host parameter acquisition creates numeric storage initialized to 0.
        -- This is storage, never evidence of a valid measurement or source.
        if self.values[name] == nil then self.values[name] = 0 end
        return {
            get = function() return self.values[name] end,
            set = function(_, value)
                -- DCS numeric parameter storage may coerce numeric strings.
                if type(value) == 'string' and tonumber(value) then value = tonumber(value) end
                self.values[name] = value
            end,
        }
    end
    function self:advance(seconds)
        assert(type(seconds) == 'number' and seconds >= 0 and seconds < math.huge)
        self.time = self.time + seconds
    end
    function self:restart()
        self.epoch = self.epoch + 1
        self.time = 0
        self.values = {}
        self.actions = {}
    end
    function self:action(command, value)
        assert(#self.actions < self.capacity, 'Fixture action capacity exceeded')
        self.actions[#self.actions + 1] = { command = command, value = value, epoch = self.epoch }
    end
    local env = {
        LockOn_Options = { script_path = root, common_script_path = 'common/',
            init_conditions = { birth_place = 'GROUND_COLD' } },
        get_param_handle = self.handle,
        get_model_time = function() return self.time end,
        make_default_activity = function(period) self.period = period end,
        dispatch_action = function(_, command, value) self:action(command, value) end,
        get_base_data = function()
            return setmetatable({}, { __index = function(_, key)
                return self.sensors[key] or function() unavailable(key) end
            end })
        end,
        CreateElement = function(kind)
            local data = { kind = kind }
            local element = setmetatable({}, {
                __newindex = function(_, key, value) data[key] = value end,
                __index = function() error('Native element properties are write-only') end,
            })
            self.elements[element] = data
            return element
        end,
        Add = function(element)
            assert(self.elements[element], 'Unknown native element')
            self.elements[element].added = true
        end,
    }
    local dev = {}
    function dev:listen_command(command) self.commands[command] = true end
    -- Keep device registration separate from fixture state.
    dev.commands = self.commands
    function dev:listen_event(_) end
    function dev:performClickableAction(command, value)
        self.depth = (self.depth or 0) + 1
        assert(self.depth <= 8, 'Reentrant clickable capacity exceeded')
        local ok, reason = pcall(env.SetCommand, command, value)
        self.depth = self.depth - 1
        if not ok then error(reason) end
    end
    env.GetSelf = function() return dev end
    env.dofile = function(path)
        local chunk, reason = loadfile(path)
        assert(chunk, reason)
        setfenv(chunk, env)
        return chunk()
    end
    setmetatable(env, { __index = _G })
    self.env = env
    return self
end
return M

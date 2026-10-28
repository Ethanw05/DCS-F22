-- Physical demand/topology producer only; Weapon_System owns achieved doors.
-- Rates/weights are mod estimates, not a recovered F-22 hydraulic flow deck.
local M = {}
M.__index = M
local names = {'F22_HYD_DEMAND_VALID','F22_HYD_DEMAND_SCHEMA',
    'F22_HYD_DEMAND_GENERATION','F22_HYD_DEMAND_STAMP','F22_HYD_DEMAND_SEQUENCE',
    'F22_L_HYD_LOAD','F22_R_HYD_LOAD','F22_FUEL_INVENTORY_VALID',
    'F22_LEFT_TANK_INSTALLED','F22_RIGHT_TANK_INSTALLED',
    'F22_GUN_AMMO_VALID','F22_GUN_AMMO_COUNT','F22_SMS_SERVICE_SEQUENCE',
    'F22_FUEL_INVENTORY_STAMP'}
local arguments = {600, 601, 602, 614}
local rates = {2.5, 2.5, 2.5, 4.5}
local weights = {0.30, 0.15, 0.15, 0.10}
local tanks = {['{LDTP_FUEL_Tank}']=true,
    ['{E1F29B21-F291-4589-9FD8-3272EEC69506}']=true}

local function finite(value)
    return type(value)=='number' and value==value and math.abs(value)<math.huge
end

local function tank(info)
    if type(info)~='table' then return nil end
    if not finite(info.count) or info.count<0 or info.count>128
        or info.count%1~=0 then return nil end
    local id = info.CLSID or info.clsid
    local weapon = type(info.weapon)=='table' and info.weapon or {}
    -- Tank count is carriage inventory, never its remaining fuel quantity.
    return info.count>0 and (tanks[id] == true or weapon.level3 == 43)
end

function M.new()
    local self = setmetatable({handles={}, positions={}, sequence=0}, M)
    for index=1,#names do self.handles[index]=get_param_handle(names[index]) end
    self.handles[1]:set(0)
    return self
end

function M:motion(dt, generation)
    local load = 0
    for index=1,4 do
        local position = get_aircraft_draw_argument_value(arguments[index])
        if finite(position) and position>=0 and position<=1 then
            if self.generation==generation and self.positions[index] then
                load = load + weights[index] * math.min(1,
                    math.abs(position-self.positions[index])/(rates[index]*dt))
            end
            self.positions[index] = position
        else
            self.positions[index] = nil
        end
    end
    return load
end

function M:gun(dt, generation, servicing)
    local h = self.handles
    local ammo, service = h[12]:get(), h[13]:get()
    local valid = h[11]:get()==1 and finite(ammo) and ammo>=0 and ammo<=100000
        and ammo%1==0 and not servicing
    local load = 0
    if valid and self.generation==generation and self.service==service
        and self.ammo and ammo<=self.ammo then
        -- Confirmed rounds expended this interval, not commanded trigger or
        -- an invented continuous gun-rotation measurement. 100 rounds/s scale.
        load = 0.25 * math.min(1, (self.ammo-ammo)/(100*dt))
    end
    self.ammo, self.service = valid and ammo or nil, service
    return load
end

function M:update(physical, dt, infos, native_ready, servicing, inventory_stamp)
    local h = self.handles
    h[1]:set(0)
    h[8]:set(0)
    if not physical.valid or not finite(dt) or dt<=0 or dt>0.1 then
        self.generation, self.ammo = nil, nil
        return
    end
    local generation = physical.generation
    local load = self:motion(dt, generation) + self:gun(dt, generation, servicing)
    self.generation = generation
    self.sequence = self.sequence%4294967295+1
    h[2]:set(1)
    h[3]:set(generation)
    h[4]:set(physical.stamp)
    h[6]:set(0)
    h[7]:set(math.min(1, load))
    local left, right = tank(infos[1]), tank(infos[9])
    if native_ready and not servicing and left~=nil and right~=nil
        and finite(inventory_stamp) and inventory_stamp>=0 then
        h[9]:set(left and 1 or 0)
        h[10]:set(right and 1 or 0)
        h[14]:set(inventory_stamp)
        h[8]:set(1)
    end
    h[5]:set(self.sequence)
    h[1]:set(1)
end

return M

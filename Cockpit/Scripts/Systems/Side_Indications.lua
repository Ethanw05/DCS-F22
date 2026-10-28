-- One cockpit measurement adapter. Source leases are transport policy, not calibration.
local Envelope=dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua')
local References=dofile(LockOn_Options.script_path..'Systems/Gins_References.lua')
local Magnetic=dofile(LockOn_Options.script_path..'Systems/Magnetic_Reference.lua')
local Currentness=dofile(LockOn_Options.script_path..'Systems/Cockpit_Currentness.lua')
local M={}
M.fields={'EFM_PHYSICAL_WORLD_STAMP','EFM_PHYSICAL_WORLD_CLOCK_KIND',
    'EFM_AIRDATA_VALID','EFM_AIRDATA_STAMP','EFM_AIRDATA_HEALTH',
    'EFM_AIRDATA_CAS_MPS','EFM_AIRDATA_TAS_MPS','EFM_AIRDATA_MACH','EFM_HUD_VALID',
    'EFM_HUD_KINEMATICS_VALID','EFM_HUD_VU','MAIN_POWER','BATTERY_POWER','APU_RPM_STATE'}
local definitions={IAS='IAS',TAS='TAS',MACH='MACH',AOA='AOA',G='GFORCE',SLIP='SLIP',
    HEADING='NAV',SFG_HEADING='F22_SFG_HEADING',RADAR='RADALT',VS='VV',
    ROLLRATE='ROLLRATE',PITCHRATE='PITCHRATE',YAWRATE='YAWRATE'}
local rate_fields={{'ROLLRATE','getRateOfRoll'},{'PITCHRATE','getRateOfPitch'},{'YAWRATE','getRateOfYaw'}}
local function finite(value,minimum,maximum)
    return Envelope.finite(value) and value>=minimum and value<=maximum
end
local function observed(fn,minimum,maximum)
    local ok,value=pcall(fn)
    if ok and finite(value,minimum,maximum) then return value end
end
local function qualified_observation(healthy,fn,minimum,maximum)
    if healthy then return observed(fn,minimum,maximum)end
end
local function scaled(value,factor)
    if value~=nil then return value*factor end
end
local function air_value(values,key,healthy,maximum)
    if not healthy then return end
    local value=values[key]
    if finite(value,0,maximum) then return value end
end
function M.new(get,put,base)
    local state=setmetatable({get=get,put=put,base=base,references={NAV=References.reader(get,'NAV'),
        SFG=References.reader(get,'SFG')},valid_keys={},currentness=Currentness.new()},{__index=M})
    for field in pairs(definitions)do state.valid_keys[field]='F22_SIDE_'..field..'_VALID' end
    state:reset()
    return state
end
function M:publish(field,value)
    local valid=self.valid_keys[field]
    self.put(valid,0)
    if value~=nil then self.put(definitions[field],value);self.put(valid,1)end
end
function M:reset()
    for field in pairs(definitions)do self:publish(field,nil)end
    self.currentness:reset()
end
function M:current(physical,now)
    local current=self.currentness:update(physical,now)
    self.world_age=self.currentness.world_age
    return current
end
local function air_current(physical,world_age)
    local v=physical.values
    return v.EFM_AIRDATA_VALID==1 and Envelope.fresh(v.EFM_AIRDATA_STAMP,physical.clock)
        and world_age+physical.clock-v.EFM_AIRDATA_STAMP<=.25
        and (v.EFM_AIRDATA_HEALTH==0 or v.EFM_AIRDATA_HEALTH==2 or v.EFM_AIRDATA_HEALTH==3)
end
function M:air(physical,current)
    local v=physical.values
    local healthy=current and air_current(physical,self.world_age)
    local cas=air_value(v,'EFM_AIRDATA_CAS_MPS',healthy,1500)
    local tas=air_value(v,'EFM_AIRDATA_TAS_MPS',healthy,1500)
    local mach=air_value(v,'EFM_AIRDATA_MACH',healthy,10)
    self:publish('IAS',scaled(cas,1.943844492))
    self:publish('TAS',scaled(tas,1.943844492))
    self:publish('MACH',mach)
    local aoa=qualified_observation(healthy and v.EFM_AIRDATA_HEALTH==0,
        self.base.getAngleOfAttack,-math.pi,math.pi)
    self:publish('AOA',scaled(aoa,180/math.pi))
end
function M:rates(full)
    for index=1,#rate_fields do
        local field=rate_fields[index]
        local value=qualified_observation(full,self.base[field[2]],-10000,10000)
        self:publish(field[1],scaled(value,180/math.pi))
    end
end
function M:motion(physical,current)
    local v=physical.values
    local full=current and v.EFM_HUD_VALID==1
    self:publish('G',qualified_observation(full,self.base.getVerticalAcceleration,-1000,1000))
    self:publish('SLIP',qualified_observation(full,self.base.getAngleOfSlide,-math.pi,math.pi))
    self:rates(full)
    local vertical=current and v.EFM_HUD_KINEMATICS_VALID==1 and finite(v.EFM_HUD_VU,-1500,1500)
    self:publish('VS',vertical and v.EFM_HUD_VU*196.850394 or nil)
end
function M:heading(physical,current,now,role,field)
    local reference=self.references[role]
    reference:update()
    local heading
    if current and reference.valid and reference.values.HEADING_VALID==1 then
        heading=Magnetic.heading(self.get,reference.values.HEADING,self.get('F22_NAV_REFERENCE'),
            physical.generation,now)
    end
    self:publish(field,heading and math.floor(heading)%360 or nil)
end
function M:update(physical,altitude,now)
    local current=self:current(physical,now)
    self:air(physical,current)
    self:motion(physical,current)
    local radar=altitude.sources.RADAR
    self:publish('RADAR',current and radar.valid and radar.value or nil)
    self:heading(physical,current,now,'NAV','HEADING')
    self:heading(physical,current,now,'SFG','SFG_HEADING')
    if self.get('EFM_PHYSICAL_GENERATION')~=physical.generation or self.get('EFM_PHYSICAL_VALID')~=1 then
        for field in pairs(definitions)do self:publish(field,nil)end
        return false
    end
    return current
end
return M

-- Current observation of native receiver state; never synthesizes received signals.
local Physical=dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua')
local Currentness=dofile(LockOn_Options.script_path..'Systems/Cockpit_Currentness.lua')
local M={}
M.__index=M
local payload={
    'F22_RADIONAV_TCN_CHANNEL','F22_RADIONAV_TCN_BAND','F22_RADIONAV_TCN_MODE',
    'F22_RADIONAV_ILS_FREQ_KHZ','F22_TCN_POWER','F22_ILS_POWER',
    'F22_TCN_BRG_MAG','F22_TCN_RANGE_M','F22_ILS_LOC','F22_ILS_GS',
    'F22_TCN_BRG_VALID','F22_TCN_RANGE_VALID','F22_ILS_LOC_VALID','F22_ILS_GS_VALID'}
local metadata={'F22_RADIONAV_SEQUENCE','F22_RADIONAV_SCHEMA','F22_RADIONAV_VALID',
    'F22_RADIONAV_GENERATION','F22_RADIONAV_CLOCK_KIND','F22_RADIONAV_STAMP'}
local controls={'F22_TCN_CHANNEL','F22_TCN_BAND','F22_TCN_MODE','F22_ILS_FREQ_KHZ'}
local function integer(value,lo,hi)
    return Physical.finite(value) and value>=lo and value<=hi and value%1==0
end
local function frequency(value)
    return integer(value,108100,111950) and (value%200==100 or value%200==150)
end
local function committed(before)
    return integer(before[1],2,16777214) and before[1]%2==0 and before[2]==1 and before[3]==1
end
local function unchanged(get,names,before)
    for index=1,#names do if get(names[index])~=before[index] then return false end end
    return true
end
local function coherent(self)
    local get,before=self.get,self.before
    return unchanged(get,metadata,before) and unchanged(get,controls,self.requests)
        and get('EFM_PHYSICAL_VALID')==1 and get('EFM_PHYSICAL_GENERATION')==self.physical.generation
        and before[4]==self.physical.generation
end
function M.new(get)
    local self=setmetatable({get=get,values={},requests={},before={},valid=false,
        physical=Physical.new(get,{'EFM_PHYSICAL_WORLD_STAMP','EFM_PHYSICAL_WORLD_CLOCK_KIND','MAIN_POWER'}),
        currentness=Currentness.new(),observation=Currentness.new()},M)
    for _,list in ipairs({payload,metadata,controls})do
        for index=1,#list do get(list[index])end
    end
    return self
end
local function capture(self)
    local get,values,before=self.get,self.values,self.before
    for index=1,#metadata do before[index]=get(metadata[index])end
    if not committed(before) then return false end
    for index=1,#controls do self.requests[index]=get(controls[index])end
    for index=1,#payload do local key=payload[index];values[key]=get(key)end
    return coherent(self)
        and self.observation:sample(before[4],before[5],before[6],true,self.now)
end
function M:update()
    self.valid,self.physical_current=false,false
    self.now=Currentness.clock()
    local readable=pcall(self.physical.update,self.physical)
    if not readable or not self.currentness:update(self.physical,self.now) then return self end
    self.physical_current=true
    local ok,valid=pcall(capture,self)
    self.valid=ok and valid==true
    return self
end
function M:powered()
    return self.valid and self.physical.values.MAIN_POWER==1
end
local function tacan(self)
    local v,r=self.values,self.requests
    return self:powered() and v.F22_TCN_POWER==1
        and integer(r[1],1,126) and integer(r[2],0,1) and integer(r[3],0,4)
        and v.F22_RADIONAV_TCN_CHANNEL==r[1] and v.F22_RADIONAV_TCN_BAND==r[2]
        and v.F22_RADIONAV_TCN_MODE==r[3]
end
function M:bearing()
    local v=self.values
    if not tacan(self) or (self.requests[3]~=1 and self.requests[3]~=2) then return end
    local value=v.F22_TCN_BRG_MAG
    if v.F22_TCN_BRG_VALID==1 and Physical.finite(value) and math.abs(value)<=2*math.pi then
        return value%(2*math.pi)
    end
end
function M:range()
    local v=self.values
    if not tacan(self) or self.requests[3]<2 then return end
    local value=v.F22_TCN_RANGE_M
    if v.F22_TCN_RANGE_VALID==1 and Physical.finite(value) and value>=0 and value<1e9 then return value end
end
local function deviation(values,key,flag)
    local value=values[key]
    if values[flag]==1 and Physical.finite(value) and math.abs(value)<=math.pi then return value end
end
function M:ils()
    local v=self.values
    if not self:powered() or v.F22_ILS_POWER~=1 or not frequency(self.requests[4])
        or v.F22_RADIONAV_ILS_FREQ_KHZ~=self.requests[4] then return end
    return deviation(v,'F22_ILS_LOC','F22_ILS_LOC_VALID'),deviation(v,'F22_ILS_GS','F22_ILS_GS_VALID')
end
return M

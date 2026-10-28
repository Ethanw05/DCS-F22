-- GPL-3.0-or-later. Two declared references sharing healthy host observations.
-- Independent failures/selections are modeled; production wiring is unknown.
local Align = dofile(LockOn_Options.script_path .. 'Systems/Gins_Alignment.lua')
local Envelope = dofile(LockOn_Options.script_path .. 'Systems/Physical_Snapshot.lua')
local Currentness=dofile(LockOn_Options.script_path..'Systems/Cockpit_Currentness.lua')
local M, Producer = {}, {}
Producer.__index = Producer
local roles = { 'NAV', 'HUD', 'SFG' }
local components = { 'ATTITUDE_FAILURE', 'HEADING_FAILURE', 'POSITION_FAILURE', 'FAILURE', 'POWER_FAILURE' }
local payload = { 'SOURCE', 'POWER', 'ATTITUDE_VALID', 'HEADING_VALID', 'POSITION_READY', 'PITCH', 'ROLL', 'HEADING' }
local channel_fields = { 'ALIGN_PROGRESS', 'ALIGN_TOTAL', 'ALIGN_KIND', 'STATUS' }
local common = { 'VALID', 'SCHEMA', 'SEQUENCE', 'STAMP', 'GENERATION','WORLD_STAMP','WORLD_CLOCK_KIND',
    'COMMAND_STATUS', 'COMMAND_RESULT', 'NAV_STATUS' }
local function bind(get, prefix, names, keys)
    for index = 1, #names do
        local name = names[index]
        keys[name] = prefix .. name; get(keys[name])
    end
end
local function publish(self, key, value) self.put(self.keys[key], value) end
local function flag(value) return value and 1 or 0 end
local function observation(fn)
    if type(fn) ~= 'function' then return end
    local ok, value = pcall(fn)
    if ok and Envelope.finite(value) and math.abs(value) <= 4 * math.pi then return value end
end
local function owned_stationary(physical)
    local v = physical.values
    local speed = Envelope.finite(v.EFM_HUD_VN) and Envelope.finite(v.EFM_HUD_VE)
        and math.sqrt(v.EFM_HUD_VN^2 + v.EFM_HUD_VE^2) or math.huge
    return physical.valid and v.EFM_GROUND_VALID == 1 and v.EFM_WEIGHT_ON_WHEELS == 1
        and v.EFM_HUD_VALID == 1 and speed < 1
end
local function inputs(self)
    local input, base, get, physical = self.input, self.base, self.get, self.physical
    physical:update()
    input.world=Currentness.clock()
    input.current=self.currentness:update(physical,input.world)
    input.now = get('F22_AP_CLOCK')
    input.pitch, input.roll = observation(base.getPitch), observation(base.getRoll)
    local heading = observation(base.getHeading)
    input.heading = heading and (-heading) % (2 * math.pi) or nil
    local ok, n, _, e = false, nil, nil, nil
    if type(base.getSelfCoordinates) == 'function' then ok, n, _, e = pcall(base.getSelfCoordinates) end
    input.n, input.e = ok and n or nil, ok and e or nil
    input.powered = input.current and physical.values.F22_ESSENTIAL_POWER == 1
    input.stationary = owned_stationary(physical)
    return input
end
local function channel_input(self, channel, shared)
    local s, get = channel.input, self.get
    s.now, s.n, s.e, s.heading = shared.now, shared.n, shared.e, shared.heading
    s.stationary = shared.stationary
    s.powered = shared.powered and get(channel.keys.FAILURE) == 0 and get(channel.keys.POWER_FAILURE) == 0
    return s
end
local function channel_health(self, channel, shared)
    local a, get, powered = channel.alignment, self.get, channel.input.powered
    channel.powered = powered
    channel.attitude = powered and a.progress >= math.min(30, a.total)
        and Envelope.finite(shared.pitch) and Envelope.finite(shared.roll) and get(channel.keys.ATTITUDE_FAILURE) == 0
    channel.heading = powered and a.ready and Envelope.finite(shared.heading) and get(channel.keys.HEADING_FAILURE) == 0
    channel.position = powered and a.ready and get(channel.keys.POSITION_FAILURE) == 0
end
local function navigation_status(channel)
    if not channel.position then return 'POSITION FAILED' end
    if not channel.attitude then return 'ATTITUDE FAILED' end
    if not channel.heading then return 'HEADING FAILED' end
    return 'NAV'
end
local function channel_status(channel)
    local a, progress = channel.alignment, math.floor(channel.alignment.progress)
    local code = flag(channel.attitude) + 2*flag(channel.heading) + 4*flag(channel.position)
    if channel.phase == a.phase and channel.progress == progress
        and channel.total == a.total and channel.code == code then
        return channel.status
    end
    channel.phase, channel.progress, channel.total, channel.code = a.phase, progress, a.total, code
    local text = a.phase
    if a.phase == 'ALIGN' then text = string.format('ALIGN EST %03d/%03d', progress, a.total)
    elseif a.phase == 'NAV' then
        text = navigation_status(channel)
    end
    channel.status = text
    return text
end
local function channel_update(self, channel, shared)
    local put, k, a = self.put, channel.keys, channel.alignment
    a:update(channel_input(self, channel, shared)); channel_health(self, channel, shared)
    put(k.POWER, flag(channel.powered)); put(k.ATTITUDE_VALID, flag(channel.attitude))
    put(k.HEADING_VALID, flag(channel.heading)); put(k.POSITION_READY, flag(channel.position))
    put(k.PITCH, shared.pitch or 0); put(k.ROLL, shared.roll or 0); put(k.HEADING, shared.heading or 0)
    put(k.ALIGN_PROGRESS, a.progress); put(k.ALIGN_TOTAL, a.total); put(k.ALIGN_KIND, a.kind)
    put(k.STATUS, channel_status(channel))
end
local function role_publish(self, role, shared)
    local channel, put, k = self.channels[self.selected[role]], self.put, self.role_keys[role]
    put(k.SOURCE, self.selected[role]); put(k.POWER, flag(channel.powered))
    put(k.ATTITUDE_VALID, flag(channel.attitude)); put(k.HEADING_VALID, flag(channel.heading))
    put(k.POSITION_READY, flag(channel.position))
    put(k.PITCH, shared.pitch or 0); put(k.ROLL, shared.roll or 0); put(k.HEADING, shared.heading or 0)
end
function M.new(get, put, base)
    local self = setmetatable({get=get, put=put, base=base, channels={}, input={}, role_keys={}, keys={},
        selected={NAV=1, HUD=1, SFG=2}, sequence=0,currentness=Currentness.new()}, Producer)
    self.physical = Envelope.new(get, {'F22_ESSENTIAL_POWER','EFM_GROUND_VALID','EFM_WEIGHT_ON_WHEELS',
        'EFM_HUD_VALID','EFM_HUD_VN','EFM_HUD_VE','EFM_PHYSICAL_WORLD_STAMP','EFM_PHYSICAL_WORLD_CLOCK_KIND'})
    bind(get, 'F22_GINS_', common, self.keys)
    for index=1,#roles do
        local role=roles[index];self.role_keys[role]={}
        bind(get, 'F22_GINS_'..role..'_', payload, self.role_keys[role])
    end
    for index=1,2 do
        local channel={alignment=Align.new(false), input={}, keys={}}
        self.channels[index]=channel
        local prefix='F22_GINS_'..index..'_'
        bind(get,prefix,components,channel.keys);bind(get,prefix,payload,channel.keys)
        bind(get,prefix,channel_fields,channel.keys)
    end
    return self
end
function Producer:reset(aligned)
    self.sequence=0;self.generation=nil;self.currentness:reset()
    self.selected.NAV,self.selected.HUD,self.selected.SFG=1,1,2
    publish(self,'VALID',0);publish(self,'SCHEMA',2);publish(self,'SEQUENCE',0);publish(self,'GENERATION',0)
    publish(self,'WORLD_STAMP',-100);publish(self,'WORLD_CLOCK_KIND',0)
    publish(self,'COMMAND_STATUS','');publish(self,'COMMAND_RESULT',0)
    for index=1,2 do
        local channel=self.channels[index]
        channel.alignment,channel.phase,channel.progress=Align.new(aligned),nil,nil
        channel.powered,channel.attitude,channel.heading,channel.position=false,false,false,false
        self.put(channel.keys.SOURCE,index)
    end
    self:update()
end
function Producer:update()
    publish(self,'VALID',0)
    local shared=inputs(self)
    if not shared.current or not Envelope.finite(shared.now) then
        self.put('F22_INS_READY',0);publish(self,'NAV_STATUS','REFERENCE PUBLICATION INVALID');return
    end
    if self.generation and self.generation~=self.physical.generation then
        self.sequence=0
        for index=1,2 do self.channels[index].alignment=Align.new(false)end
    end
    if self.sequence>=16777215 then
        self.put('F22_INS_READY',0);publish(self,'NAV_STATUS','REFERENCE SEQUENCE EXHAUSTED');return
    end
    self.generation=self.physical.generation
    for index=1,2 do channel_update(self,self.channels[index],shared)end
    for index=1,#roles do role_publish(self,roles[index],shared)end
    publish(self,'STAMP',shared.now);publish(self,'SCHEMA',2);publish(self,'GENERATION',self.generation)
    publish(self,'WORLD_STAMP',shared.world);publish(self,'WORLD_CLOCK_KIND',2)
    self.sequence=self.sequence+1
    publish(self,'SEQUENCE',self.sequence);publish(self,'VALID',1)
    local selected=self.channels[self.selected.NAV]
    self.put('F22_INS_READY',selected.position and 1 or 0);publish(self,'NAV_STATUS',selected.status)
end
function Producer:select(role,value)
    if not self.selected[role] or (value~=1 and value~=2)then return false end
    local shared=inputs(self)
    if not shared.powered or not Envelope.finite(shared.now)then return false end
    self.selected[role]=value;self:update();return true
end
function Producer:align(kind)
    local shared=inputs(self)
    local channel=self.channels[self.selected.NAV]
    local accepted,reason=channel.alignment:request(kind,channel_input(self,channel,shared))
    publish(self,'COMMAND_RESULT',accepted and 1 or 2)
    if not accepted then publish(self,'COMMAND_STATUS',reason);return false end
    self:update();publish(self,'COMMAND_STATUS','ALIGNMENT STARTED');return true
end

local Reader = {}
Reader.__index = Reader
local fields = payload
function M.reader(get, role)
    local names, values = {}, {}
    for index = 1, #fields do
        names[index] = 'F22_GINS_' .. role .. '_' .. fields[index]; get(names[index]); values[fields[index]] = 0
    end
    for _, key in ipairs({ 'F22_GINS_SCHEMA', 'F22_GINS_VALID', 'F22_GINS_SEQUENCE',
        'F22_GINS_STAMP','F22_GINS_GENERATION','F22_GINS_WORLD_STAMP','F22_GINS_WORLD_CLOCK_KIND',
        'EFM_PHYSICAL_GENERATION','F22_AP_CLOCK' }) do get(key) end
    return setmetatable({ get=get,names=names,values=values,valid=false,currentness=Currentness.new() },Reader)
end
local function frame_epoch(sequence, stamp, get)
    return Envelope.finite(sequence) and sequence>=1 and sequence<=16777215 and sequence%1==0
        and Envelope.fresh(stamp,get('F22_AP_CLOCK'))
end
local function frame_payload(values)
    if values.SOURCE~=1 and values.SOURCE~=2 then return false end
    for index=2,5 do if not Envelope.boolean(values[fields[index]])then return false end end
    if values.POWER==0 and (values.ATTITUDE_VALID~=0 or values.HEADING_VALID~=0 or values.POSITION_READY~=0)then
        return false
    end
    for index=6,#fields do if not Envelope.finite(values[fields[index]])then return false end end
    return math.abs(values.PITCH)<=4*math.pi and math.abs(values.ROLL)<=4*math.pi
        and values.HEADING>=0 and values.HEADING<2*math.pi
end
local function generation_valid(value)
    return Envelope.finite(value) and value>=1 and value<=4294967295 and value%1==0
end
local function frame_unchanged(get,sequence,stamp,generation,world_stamp,kind)
    return get('F22_GINS_VALID')==1 and get('F22_GINS_SCHEMA')==2
        and get('F22_GINS_SEQUENCE')==sequence and get('F22_GINS_STAMP')==stamp
        and get('F22_GINS_WORLD_STAMP')==world_stamp and get('F22_GINS_WORLD_CLOCK_KIND')==kind
        and get('F22_GINS_GENERATION')==generation and generation==get('EFM_PHYSICAL_GENERATION')
        and get('EFM_PHYSICAL_VALID')==1
end
local function complete_frame(self)
    local get=self.get
    local sequence,stamp=get('F22_GINS_SEQUENCE'),get('F22_GINS_STAMP')
    local generation=get('F22_GINS_GENERATION')
    local world_stamp,kind=get('F22_GINS_WORLD_STAMP'),get('F22_GINS_WORLD_CLOCK_KIND')
    for index=1,#fields do self.values[fields[index]]=get(self.names[index])end
    if not frame_unchanged(get,sequence,stamp,generation,world_stamp,kind) then return false end
    if not generation_valid(generation) then return false end
    local valid=frame_epoch(sequence,stamp,get) and frame_payload(self.values)
        and self.currentness:sample(generation,kind,world_stamp,true,Currentness.clock())
    if valid then self.stamp,self.sequence=stamp,sequence end
    return valid
end
function Reader:update()
    local get=self.get
    self.valid=false;self.stamp,self.sequence=nil,nil
    local schema=get('F22_GINS_SCHEMA')
    if schema~=2 or get('F22_GINS_VALID')~=1 then return self end
    self.valid=complete_frame(self)
    return self
end

return M

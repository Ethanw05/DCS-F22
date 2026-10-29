-- AFCS annunciation only. Native modes/authority remain untouched.
local Physical = dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua')
local Current = dofile(LockOn_Options.script_path..'Systems/Cockpit_Currentness.lua')
local Alert = dofile(LockOn_Options.script_path..'Systems/AP_Annunciation.lua')
local M = {feedback_seconds = 5}
M.__index = M
local reasons = {[1]='AP INHIBIT', [2]='AP LIMIT', [3]='AP OVERRIDE',
    [4]='AP NAV LOST', [5]='AP ALT LOST', [6]='AP HDG LOST'}
local unexpected = {[2]=true, [4]=true, [5]=true, [6]=true}
local fields = {'MAIN_POWER','F22_AP_ACTIVE','F22_AP_LIMITED','F22_AP_REASON','F22_AP_OFF_SEQUENCE',
    'EFM_PHYSICAL_WORLD_STAMP','EFM_PHYSICAL_WORLD_CLOCK_KIND'}
local function valid(values)
    if not Physical.boolean(values.F22_AP_ACTIVE) or not Physical.boolean(values.F22_AP_LIMITED) then return false end
    return Alert.integer(values.F22_AP_REASON,0,6) and Alert.integer(values.F22_AP_OFF_SEQUENCE,0,999999999)
end
function M.new(get,put)
    local self = setmetatable({put=put, physical=Physical.new(get,fields), current=Current.new(),
        epoch=Alert.next_epoch(get('F22_AP_ANN_EPOCH')), ticket=0, sequence=0},M)
    self:invalidate()
    return self
end
function M:reset()
    self.last_active, self.last_reason, self.last_off, self.generation = nil,nil,nil,nil
    self.feedback, self.alert = nil,nil
end
function M:invalidate()
    self:reset()
    self.sequence = Alert.publish(self.put,self.sequence,self.epoch,0,Current.clock(),nil)
end
function M:observe(values,now)
    local active, reason, off = values.F22_AP_ACTIVE,values.F22_AP_REASON,values.F22_AP_OFF_SEQUENCE
    local commanded = self.last_off ~= nil and off ~= self.last_off
    if commanded or reason==0 and self.last_reason~=0 then self.feedback,self.alert=nil,nil end
    if self.last_reason ~= nil and reason ~= self.last_reason and reason > 0 and not commanded then
        self.feedback = {text=reasons[reason], until_time=now+M.feedback_seconds}
        if self.last_active == 1 and unexpected[reason] then
            if self.ticket == 16777215 then self.ticket=0;self.epoch=Alert.next_epoch(self.epoch) end
            self.ticket = self.ticket+1
            self.alert = {ticket=self.ticket, onset=now, until_time=now+M.feedback_seconds}
        end
    end
    self.last_active,self.last_reason,self.last_off = active,reason,off
end
function M:text(values,now)
    if self.feedback and now < self.feedback.until_time then return self.feedback.text end
    self.feedback = nil
    if values.F22_AP_ACTIVE == 0 then return '' end
    return values.F22_AP_LIMITED == 1 and 'AP LIMIT' or 'AP ON'
end
function M:update()
    local now = Current.clock()
    local frame = self.physical:update()
    local healthy = self.current:update(frame,now) and frame.values.MAIN_POWER == 1 and valid(frame.values)
    local text = ''
    if healthy then
        if self.generation ~= frame.generation then self:reset();self.generation=frame.generation end
        self:observe(frame.values,now)
        text = self:text(frame.values,now)
        if self.alert and now >= self.alert.until_time then self.alert=nil end
    else self:reset() end
    self.sequence = Alert.publish(self.put,self.sequence,self.epoch,frame.generation,now,healthy and self.alert or nil)
    return text
end
return M

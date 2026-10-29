-- GPL-3.0-or-later. Source-aware tactical picture, separate from fire control.
local M = {limits={radar=20, rf=12, mws=3, datalink=26, irst=2.5},
    bits={radar=1, rf=2, mws=4, datalink=8, irst=16}}
local Association = dofile(LockOn_Options.script_path .. 'Systems/Tactical_Association.lua')
local Observation = dofile(LockOn_Options.script_path .. 'Systems/Tactical_Observation.lua')
local Join = dofile(LockOn_Options.script_path .. 'Systems/Tactical_Track_Join.lua')
local capacities = {radar=64, rf=16, mws=16, datalink=64, irst=16}
local function finite(x)
    return type(x)=='number' and x==x and math.abs(x)<1e12
end
local function new_batch(batch, old, now)
    return finite(batch.sequence) and batch.sequence>=0
        and finite(batch.time) and batch.time<=now+.05 and now-batch.time<=.25
        and (not old or old.epoch~=batch.epoch or batch.time>=old.time)
        and (not old or old.epoch~=batch.epoch or old.sequence~=batch.sequence)
end
function M.new()
    local s = {batches={}, contacts={}, sequence=0, epoch=1, association=Association.new()}
    function s:reset()
        self.association:reset()
        self.batches, self.contacts, self.clock = {}, {}, nil
        self.epoch = self.epoch%4294967294+1
    end
    function s:update(now, batches, power)
        if not power or not finite(now) then
            if self.clock then self:reset() end
            return
        end
        if self.clock and now<self.clock then self:reset() end
        self.clock = now
        for sensor, batch in pairs(batches) do
            if capacities[sensor] and new_batch(batch, self.batches[sensor], now) then
                self.batches[sensor] = {sequence=batch.sequence, time=batch.time, epoch=batch.epoch,
                    contacts=Observation.admit(batch, sensor, M.limits[sensor], capacities[sensor])}
            end
        end
        self.association:associate(self.batches, now, M.limits)
        self.contacts = Join.build(self.batches, now, M.limits, M.bits)
        self.sequence = self.sequence%15999998+2
    end
    return s
end
return M

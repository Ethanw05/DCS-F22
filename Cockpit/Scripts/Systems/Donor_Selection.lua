-- GPL-3.0-or-later. Bounded awareness selection, never a radar/weapon target.
local Datalink = dofile(LockOn_Options.script_path .. 'Systems/Datalink_Tracks.lua')
local Link = dofile(LockOn_Options.script_path .. 'Systems/Radar_Donor_Link.lua')
local M = {}
local function by_source(a,b)return a.source < b.source end
function M.new(get, put)
    local state = { step = 0, accepted = false, status = 0, donors = {}, cue = Link.new(get, put) }
    function state:command(command)
        if command == 11143 then self.status = self.cue:command() and 6 or 5; return end
        if command == 11140 or command == 11141 or command == 11142 then self.cue:cancel(true) end
        if command == 11140 then self.step = 1
        elseif command == 11141 then self.step = -1
        elseif command == 11142 then self.source = nil; self.accepted = false; self.status = 4
        elseif command == 11144 and self.source then self.accepted = true; self.status = 2
        end
    end
    function state:update(now, tracks, power)
        local epoch = get('F22_DL_RX_EPOCH')
        if not power or epoch ~= self.epoch then
            self.source, self.accepted, self.status = nil, false, 0
            self.epoch = epoch
        end
        local donors = self.donors
        for index=#donors,1,-1 do donors[index]=nil end
        for index = 1, math.min(160, #tracks) do
            local track = tracks[index]
            local position = power and Datalink.position(track.datalink, now)
            if position and #donors < 64 then donors[#donors + 1] = track end
        end
        table.sort(donors, by_source)
        local index = 0
        for i = 1, #donors do if donors[i].source == self.source then index = i end end
        if self.step ~= 0 and #donors > 0 then
            index = index == 0 and (self.step > 0 and 1 or #donors)
                or (index - 1 + self.step) % #donors + 1
            self.source, self.accepted, self.status = donors[index].source, false, 1
        end
        self.step = 0
        local selected = donors[index]
        if not selected then
            if self.source then self.status=3 end
            self.source = nil; self.accepted = false
        end
        local donor = selected and selected.datalink
        local position = donor and Datalink.position(donor, now)
        put('F22_DONOR_VALID', selected and 1 or 0)
        put('F22_DONOR_SOURCE', selected and selected.source or 0)
        put('F22_DONOR_AWARENESS_ACCEPTED', self.accepted and 1 or 0)
        put('F22_DONOR_STATUS', self.status)
        put('F22_DONOR_COUNT', #donors)
        put('F22_DONOR_REPORTER', donor and donor.reporter or 0)
        put('F22_DONOR_LINK', donor and donor.link or 0)
        put('F22_DONOR_OBSERVATION_KNOWN', donor and donor.observation_known and 1 or 0)
        put('F22_DONOR_OBSERVATION_AGE', donor and donor.observation_known and position.age or 999)
        put('F22_DONOR_RECEIVE_AGE', donor and donor.received and math.max(0,now-donor.received)or 999)
        put('F22_DONOR_POSITION_STATE', position and position.state or 0)
        put('F22_DONOR_IDENTITY_CONFLICT', selected and selected.identity_conflict and 1 or 0)
        put('F22_DONOR_WEAPON_AUTHORITY', 0)
        self.cue:update(now, donor, power)
    end
    state:update(0, {}, false)
    return state
end
return M

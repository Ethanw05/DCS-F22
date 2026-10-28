-- GPL-3.0-or-later. Rotate remembered passive directions, never infer range.
-- Reuse the existing orthonormal body/world frame math.
local Frames = dofile(LockOn_Options.script_path .. "Systems/Gun_Frames.lua")
local M = {}
local function origin_at(history,stamp)
    for i=1,#history-1 do
        local a,b=history[i],history[i+1]
        if a.position and b.position and stamp>=a.time and stamp<=b.time and b.time>a.time then
            local f=(stamp-a.time)/(b.time-a.time)
            return {n=a.position.n*(1-f)+b.position.n*f,u=a.position.u*(1-f)+b.position.u*f,
                e=a.position.e*(1-f)+b.position.e*f,time=stamp}
        end
    end
    local last=history[#history]
    if last and last.position and stamp>=last.time and stamp-last.time<=.01 then
        return {n=last.position.n,u=last.position.u,e=last.position.e,time=stamp}
    end
end
local function finite(x)
	return type(x) == "number" and x == x and math.abs(x) < 1e12
end
local function changed(old,c,stamp)
    return not old or math.abs(math.atan2(math.sin(c.az-old.az),math.cos(c.az-old.az)))>1e-7
        or math.abs(c.el-old.el)>1e-7 or c.age<old.age-1e-4 or stamp>old.stamp+.075
end
local function reception(history,old,c,stamp)
    if changed(old,c,stamp)then
        local at=Frames.at(history,stamp)
        old={az=c.az,el=c.el,stamp=stamp}
        if at then
            local ce=math.cos(c.el)
            -- Native getEmitterPos uses -atan2(right,forward).
            old.world=Frames.world(at,{ce*math.cos(c.az),math.sin(c.el),-ce*math.sin(c.az)})
            old.origin=origin_at(history,stamp)
        end
    end
    old.age=c.age
    return old
end
local function compensate(frame,old,c)
    if not old.world then return end
    local body=Frames.body(frame,old.world)
    local horizontal=math.sqrt(body[1]^2+body[3]^2)
    -- At the vertical axis azimuth is undefined; retain the last bearing.
    if horizontal>1e-8 then c.az=(-math.atan2(body[3],body[1]))%(2*math.pi)
    else c.az=old.display_az or c.az end
    c.el=math.atan2(body[2],horizontal);old.display_az=c.az
    c.bearing_compensated=true;c.bearing_origin=old.origin
end
local function retain_history(history,now,frame,position)
    local last=history[#history]
    if last and last.time==now then table.remove(history)end
    history[#history+1]={time=now,frame=frame,position=position}
    while #history>256 or #history>2 and now-history[2].time>12.1 do table.remove(history,1)end
end
function M.frame(sensors)
	if not sensors then
		return
	end
	local ok, heading, pitch, roll = pcall(function()
		return sensors.getHeading(), sensors.getPitch(), sensors.getRoll()
	end)
	if ok and finite(heading) and finite(pitch) and finite(roll) then
		return Frames.from_pose({ heading = -heading, pitch = pitch, roll = roll })
	end
end
function M.new()
	local s = { history = {}, tracks = {} }
	function s:reset()
		self.history = {}
		self.tracks = {}
		self.time = nil
	end
	function s:update(now, frame, contacts, power, position)
		if not power or not finite(now) or not frame then
			self:reset()
			return
		end
		if self.time and (now < self.time or now - self.time > 0.25) then
			self:reset()
		end
		self.time = now
        retain_history(self.history,now,frame,position)
		local seen = {}
		for _, c in ipairs(contacts) do
			seen[c.source] = true
			local az, el = c.az, c.el
			c.bearing_compensated = false
            c.bearing_origin=nil
			if finite(az) and finite(el) and math.abs(el) <= math.pi / 2 + 0.001 then
                local old=reception(self.history,self.tracks[c.source],c,now-c.age)
                self.tracks[c.source]=old
                compensate(frame,old,c)
			end
		end
		for source in pairs(self.tracks) do
			if not seen[source] then
				self.tracks[source] = nil
			end
		end
	end
	return s
end
return M

-- GPL-3.0-or-later. Capability classification is separate from launch identity.
-- Hornet reference: FA18C 31B000/31C6A0, documented in the research notes.
local M={}
local Frames=dofile(LockOn_Options.script_path..'Systems/Gun_Frames.lua')
local Feedback=dofile(LockOn_Options.script_path..'Systems/IR_Feedback.lua')
local aim9x={['{5CE2FF2A-645A-4197-B48D-8720AC69394F}']=true,
    ['{AIM9X-BLKII}']=true,['{LAU_115_2xAIM9X-II}']=true,['{LAU_115_2xAIM9X-II}}']=true}
function M.profile(info)
    if not info or (info.count or 0)<=0 then return 0 end
    local w=info.weapon or {}
    return (w.level4==136 or aim9x[info.CLSID or info.clsid or '']) and 1 or 0
end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.project(frame,direction)
    for axis=1,3 do if not finite(direction[axis]) then return end end
    local b=Frames.body(frame,direction)
    local norm=math.sqrt(b[1]^2+b[2]^2+b[3]^2)
    if not finite(norm) or norm<.9 or norm>1.1 then return end
    -- Project the native WORLD beam into the current aircraft frame. The local
    -- platform matrix includes its mounting/parent frames and is not a HUD LOS.
    return math.atan2(b[3],b[1]),math.atan2(b[2],math.sqrt(b[1]^2+b[3]^2))
end
function M.new(sensors,get)
    -- Register native bridge handles before indicator controllers bind them.
    for _,n in ipairs({'F22_IR_HEAD_RELEASED','F22_IR_WORLD_VALID','F22_IR_WORLD_FWD_N',
        'F22_IR_WORLD_FWD_U','F22_IR_WORLD_FWD_E','F22_IR_AIM9X_PROFILE','F22_IR_AIM9X_CONFIGURED'}) do get(n) end
    local seeker={feedback=Feedback.new(get)}
    local direction={0,0,0}
    function seeker:reset()
        self.az,self.el,self.station,self.generation=nil,nil,nil,nil
        self.available,self.locked=false,false
        self.feedback:update(false,nil) -- Preserve the owned-provider latch across reset.
    end
    function seeker:update(enabled,dt,now)
        local sample=self.feedback:update(enabled,now)
        self.available,self.locked=sample.available,sample.locked
        if not sample.available or not sample.world_valid or not finite(dt) or dt<=0 or dt>.1 then
            self.az,self.el=nil,nil;return nil,nil,sample
        end
        local heading,pitch,roll=sensors.getHeading(),sensors.getPitch(),sensors.getRoll()
        if not finite(heading) or not finite(pitch) or not finite(roll) then
            self.az,self.el=nil,nil;return nil,nil,sample
        end
        direction[1],direction[2],direction[3]=sample.n,sample.u,sample.e
        local az,el=M.project(Frames.from_pose({heading=-heading,pitch=pitch,roll=roll}),direction)
        if not az then self.az,self.el=nil,nil;return nil,nil,sample end
        local station=get('F22_IR_STATION')
        local generation=get('F22_IR_STORE_GENERATION')
        if not self.az or self.station~=station or self.generation~=generation then self.az=az;self.el=el end
        self.station=station
        self.generation=generation
        local gain=math.min(1,dt/.05)
        self.az=self.az+math.atan2(math.sin(az-self.az),math.cos(az-self.az))*gain
        self.el=self.el+(el-self.el)*gain
        return self.az,self.el,sample
    end
    return seeker
end
return M

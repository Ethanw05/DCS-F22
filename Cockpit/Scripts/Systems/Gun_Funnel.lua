-- GPL-3.0-or-later. Wingspan ranging over native, historical shell trajectories.
local M={}
local Frames=dofile(LockOn_Options.script_path..'Systems/Gun_Frames.lua')
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.new(sensors,get,put,dispatch,device_id)
    local self={}
    for _,n in ipairs({'F22_FUNNEL_REQUEST_VALID','F22_FUNNEL_REQUEST_TIME','F22_FUNNEL_RESULT_TIME',
        'F22_FUNNEL_NATIVE_VALID','F22_FUNNEL_OWN_N','F22_FUNNEL_OWN_U','F22_FUNNEL_OWN_E',
        'HUD_GUN_FUNNEL_VALID','F22_GUN_WINGSPAN_M'}) do get(n) end
    for i=1,7 do
        local p=string.format('F22_FUNNEL_%02d_',i)
        for _,suffix in ipairs({'VALID','N','U','E'}) do get(p..suffix) end
        p=string.format('HUD_FUNNEL_%02d_',i)
        for _,suffix in ipairs({'VALID','L_X','L_Y','R_X','R_Y'}) do get(p..suffix) end
    end
    -- Explicit default target wingspan, independent of radar target identity.
    -- 40 feet is a pilot reference; the funnel does not know target wingspan.
    put('F22_GUN_WINGSPAN_M',12.192)
    function self:update(enabled)
        put('HUD_GUN_FUNNEL_VALID',0)
        for i=1,7 do put(string.format('HUD_FUNNEL_%02d_VALID',i),0) end
        put('F22_FUNNEL_REQUEST_VALID',0)
        if not enabled or type(get_model_time)~='function' or get('EFM_HUD_VALID')<.5 then self.sent=nil;return end
        local now=get_model_time()
        local n,u,e=sensors.getSelfCoordinates()
        local heading,pitch,roll=sensors.getHeading(),sensors.getPitch(),sensors.getRoll()
        for _,v in ipairs({now,n,u,e,heading,pitch,roll}) do if not finite(v) then return end end
        put('F22_FUNNEL_OWN_N',n);put('F22_FUNNEL_OWN_U',u);put('F22_FUNNEL_OWN_E',e)
        put('F22_FUNNEL_REQUEST_TIME',now);put('F22_GUN_DEVICE_ID',device_id)
        put('F22_FUNNEL_REQUEST_VALID',1)
        -- STT director requests already invoke the shared gun callback.
        if get('F22_RADAR_STT_VALID')<.5 and (not self.sent or now<self.sent or now-self.sent>=.039) then
            self.sent=now;dispatch(nil,10851,.04)
        end
        if get('F22_RADAR_STT_VALID')>.5 or get('F22_FUNNEL_NATIVE_VALID')<.5 then return end
        local age=now-get('F22_FUNNEL_RESULT_TIME')
        if not finite(age) or age<-.01 or age>.1 then return end
        local frame=Frames.from_pose({heading=-heading,pitch=pitch,roll=roll})
        local span=get('F22_GUN_WINGSPAN_M')
        if not finite(span) or span<6 or span>60 then return end
        local points={}
        for i=1,7 do
            local prefix=string.format('F22_FUNNEL_%02d_',i)
            if get(prefix..'VALID')>.5 then
                local body=Frames.body(frame,{get(prefix..'N')-n,get(prefix..'U')-u,get(prefix..'E')-e})
                local range=math.sqrt(body[1]^2+body[2]^2+body[3]^2)
                local az,el=math.atan2(body[3],body[1]),math.atan2(body[2],body[1])
                if finite(range) and range>50 and math.abs(az)<math.rad(20) and math.abs(el)<math.rad(20) then
                    points[i]={az,el,math.atan(span/(2*range))}
                end
            end
        end
        local count=0
        for i=1,7 do
            local p=points[i]
            if p then
                -- Wingspan is measured left/right across the sight, not normal
                -- to the curved stream. Muzzle parallax can otherwise rotate
                -- the width almost vertically during steady flight.
                for _,side in ipairs({'L','R'}) do
                    local sign=side=='L' and -1 or 1
                    local prefix=string.format('HUD_FUNNEL_%02d_%s_',i,side)
                    put(prefix..'X',p[1]+sign*p[3])
                    put(prefix..'Y',p[2])
                end
                put(string.format('HUD_FUNNEL_%02d_VALID',i),1);count=count+1
            end
        end
        put('HUD_GUN_FUNNEL_VALID',count>=2 and 1 or 0)
    end
    return self
end
return M

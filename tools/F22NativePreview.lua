-- Local native-render validation only. Inert outside the dedicated test mission.
local control = require("lfs").writedir() .. "Logs/f22-native-control.txt"
local callbacks = {}
local active=false
local frames=0
local freeze=true
local savedCamera=nil
local forcedCamera=nil
local pendingCapture=nil
local startModelTime=0
local warmed=false
local autoCaptureDone=false
local function emit(message) log.write("F22_NATIVE_PREVIEW",log.INFO,message) end
local function capture()
    local name="F22-HUD-native-"..os.date("%Y%m%d-%H%M%S").."-"..frames..".png"
    DCS.makeScreenShot(name)
    emit("native image: "..name)
end
local function snapshot()
    local c=Export.LoGetCameraPosition()
    local v=Export.LoGetVectorVelocity()
    local s=Export.LoGetSelfData()
    if c and v and s then
        emit(string.format("camera x=(%.6f,%.6f,%.6f) y=(%.6f,%.6f,%.6f) z=(%.6f,%.6f,%.6f) v=(%.3f,%.3f,%.3f) heading=%.6f pitch=%.6f bank=%.6f pause=%s",
            c.x.x,c.x.y,c.x.z,c.y.x,c.y.y,c.y.z,c.z.x,c.z.y,c.z.z,
            v.x,v.y,v.z,s.Heading or 0,s.Pitch or 0,s.Bank or 0,tostring(DCS.getPause())))
    end
end
function callbacks.onSimulationStart()
    local filename = DCS.getMissionFilename() or ""
    active = filename:gsub("\\","/"):find("F22%-HUD%-Native%-Validation.miz$") ~= nil
    frames=0
    freeze=true
    savedCamera=nil; forcedCamera=nil; pendingCapture=nil
    startModelTime=DCS.getModelTime()
    warmed=false; autoCaptureDone=false
    if active then emit("native validation started") end
end
function callbacks.onSimulationFrame()
    if not active then return end
    frames=frames+1
    if forcedCamera then Export.LoSetCameraPosition(forcedCamera) end
    if pendingCapture and frames>=pendingCapture then
        snapshot(); capture(); pendingCapture=nil
    end
    if frames%15==0 and freeze then
        -- Let real EFM and avionics ticks establish the hot-start buses.
        -- Freezing on the first render frame captures uninitialized displays.
        warmed=warmed or DCS.getModelTime()-startModelTime>=1.0
        DCS.setPause(warmed)
    end
    if warmed and not autoCaptureDone and frames%60==0 then
        snapshot(); capture(); autoCaptureDone=true
    end
    if frames%15~=0 then return end
    local f=io.open(control,"r")
    if not f then return end
    local command=f:read("*l"); f:close()
    if not command or command=="" then return end
    local clear=io.open(control,"w"); if clear then clear:close() end
    if command=="reload" then
        emit("reloading dedicated test mission")
        DCS.restartMission()
    elseif command=="run" then freeze=false; DCS.setPause(false)
    elseif command=="pause" then freeze=true; DCS.setPause(true)
    elseif command=="capture" then
        snapshot()
        capture()
    elseif command=="radar-rws" or command=="radar-tws" or command=="radar-acquire" then
        local ok,err=pcall(function()
            local radar=Export.GetDevice(14)
            if command=="radar-rws" then
                radar:SetCommand(10600,1);radar:SetCommand(10601,1)
                Export.GetDevice(6):SetCommand(10005,1)
                Export.GetDevice(4):SetCommand(106,1)
            elseif command=="radar-tws" then radar:SetCommand(10602,1)
            else radar:SetCommand(10618,1);radar:SetCommand(10606,1) end
        end)
        emit('radar test control '..command..' ok='..tostring(ok)..' '..tostring(err))
        freeze=false;DCS.setPause(false)
    elseif command=="head-right" or command=="head-left" or command=="head-center" then
        if not savedCamera then savedCamera=Export.LoGetCameraPosition() end
        if savedCamera then
            local offset=command=="head-right" and 0.22 or command=="head-left" and -0.22 or 0
            forcedCamera={x=savedCamera.x,y=savedCamera.y,z=savedCamera.z,
                p={x=savedCamera.p.x+savedCamera.z.x*offset,
                   y=savedCamera.p.y+savedCamera.z.y*offset,
                   z=savedCamera.p.z+savedCamera.z.z*offset}}
            pendingCapture=frames+30
            emit("native camera offset metres="..offset)
        end
    end
end
DCS.setUserCallbacks(callbacks)

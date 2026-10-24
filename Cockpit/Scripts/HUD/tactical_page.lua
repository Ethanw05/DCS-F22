-- Separate, evidence-labelled tactical HUD layer.
-- F-22 flight layout: USAF Flying Safety, June 2002.
-- Tactical representation: generic military symbology conventions only.
-- No false CCIP, WEZ, target tracks, or seeker lock indicators.
return function(api)
    local line, label, static, group = api.line, api.label, api.static, api.group
    local pi = math.pi
    local sequence = 0
    local function unique(part)
        sequence = sequence + 1
        return "HUD_TACT_"..part.."_"..sequence
    end
    local function visible(name, parameter, value, parent)
        local key = unique(name)
        group(key,0,0,{"HUD_POWER",parameter},
            {{"opacity_using_parameter",0},
             {"parameter_in_range",1,value-0.1,value+0.1}},parent)
        return key
    end
    local function ring(cx,cy,r,parent,segments)
        for i=0,segments-1 do
            local a=i*2*pi/segments
            local b=(i+1)*2*pi/segments
            line(cx+r*math.cos(a),cy+r*math.sin(a),
                 cx+r*math.cos(b),cy+r*math.sin(b),0.005,parent)
        end
    end
    local function cross(cx,cy,size,parent)
        line(cx-size,cy,cx-size*0.36,cy,0.006,parent)
        line(cx+size*0.36,cy,cx+size,cy,0.006,parent)
        line(cx,cy-size,cx,cy-size*0.36,0.006,parent)
        line(cx,cy+size*0.36,cx,cy+size,0.006,parent)
    end
    local function diamond(cx,cy,r,parent)
        line(cx,cy+r,cx+r,cy,0.006,parent)
        line(cx+r,cy,cx,cy-r,0.006,parent)
        line(cx,cy-r,cx-r,cy,0.006,parent)
        line(cx-r,cy,cx,cy+r,0.006,parent)
    end

    -- Shared combat SAFE/ARM cue (actual cockpit master arm, not launch permission).
    local combat = visible("COMBAT","HUD_MODE",2)
    -- All weapon modes are separate so power and master arm remain independent.
    for _,n in ipairs({3,4,5,6,7}) do
        local armRoot=visible("ARMROOT","HUD_MODE",n)
        local armed=visible("ARM","HUD_ARMED",1,armRoot)
        local safed=visible("SAFE","HUD_ARMED",0,armRoot)
        static(-0.84,-0.70,"ARM",0.042,armed)
        static(-0.84,-0.70,"SAFE",0.042,safed)
    end
    local combatArm = visible("ARM","HUD_ARMED",1,combat)
    local combatSafe = visible("SAFE","HUD_ARMED",0,combat)
    static(-0.84,-0.70,"ARM",0.042,combatArm)
    static(-0.84,-0.70,"SAFE",0.042,combatSafe)

    -- NAV: retain historical flight symbology and C-130-inspired heading tape.
    local nav = visible("NAV","HUD_MODE",1)
    static(-0.77,0.83,"NAV",0.05,nav)
    label(0.80,-0.47,"VV","V %.0f",0.043,nav)
    local noWP = visible("NO_WP","HUD_WP_VALID",0,nav)
    static(0.0,-0.78,"STPT --",0.039,noWP)
    local wp = visible("WP","HUD_WP_VALID",1,nav)
    label(-0.35,-0.78,"HUD_WP_INDEX","STPT %02.0f",0.039,wp)
    label(0.25,-0.78,"HUD_WP_RANGE_NM","%4.1f NM",0.038,wp)
    local bearing=visible("WP_BRG","HUD_WP_BRG_VALID",1,nav)
    label(0.72,0.83,"HUD_WP_BEARING_DEG","BRG %03.0f",0.037,bearing)
    group("HUD_NAV_STEERING",0,0,
        {"HUD_WP_AZ_RAD","HUD_WP_EL_RAD","HUD_POWER","HUD_WP_CUE_VALID","HUD_MODE"},
        {{"move_left_right_using_parameter",0,1.18},
         {"move_up_down_using_parameter",1,1.18},
         {"opacity_using_parameter",2},
         {"parameter_in_range",3,0.9,1.1},
         {"parameter_in_range",4,0.9,1.1}})
    diamond(0,0,0.047,"HUD_NAV_STEERING")

    -- AIM-120: missile mode identifier is requested, not an actual store count.
    -- Without track/kinematics the HUD MUST NOT show a DLZ or SHOOT cue.
    local mrm = visible("MRM","HUD_MODE",2)
    static(-0.77,0.83,"A/A",0.052,mrm)
    static(0.75,0.83,"AIM-120",0.044,mrm)
    local noMRM = visible("MRM_NO_TRACK","HUD_AA_TARGET_VALID",0,mrm)
    static(0,-0.80,"NO TRACK",0.042,noMRM)
    -- Target-designator box only if later sensor adapter supplies a valid LOS.
    group("HUD_AA_TRACK_SYMBOL",0,0,
        {"HUD_AA_TGT_AZ_RAD","HUD_AA_TGT_EL_RAD","HUD_POWER","HUD_AA_CUE_VALID","HUD_MODE"},
        {{"move_left_right_using_parameter",0,1.18},
         {"move_up_down_using_parameter",1,1.18},
         {"opacity_using_parameter",2},
         {"parameter_in_range",3,0.9,1.1},
         {"parameter_in_range",4,1.9,2.1}})
    local rect=0.07
    line(-rect,-rect,rect,-rect,0.006,"HUD_AA_TRACK_SYMBOL")
    line(rect,-rect,rect,rect,0.006,"HUD_AA_TRACK_SYMBOL")
    line(rect,rect,-rect,rect,0.006,"HUD_AA_TRACK_SYMBOL")
    line(-rect,rect,-rect,-rect,0.006,"HUD_AA_TRACK_SYMBOL")
    local tgtText = visible("MRM_TGT","HUD_AA_TARGET_VALID",1,mrm)
    label(0.70,-0.61,"HUD_AA_TGT_RANGE_NM","R %.1f",0.043,tgtText)
    static(0,-0.80,"STT TELEMETRY",0.037,tgtText)
    local iffFriend = visible("FRIEND","HUD_AA_TGT_IFF",1,tgtText)
    static(0.0,-0.67,"FRIEND",0.048,iffFriend)
    local radarPowered = visible("RDR_ON","RADAR_PWR",1,mrm)
    static(-0.76,0.53,"RDR ON",0.038,radarPowered)
    local radarOff = visible("RDR_OFF","RADAR_PWR",0,mrm)
    static(-0.76,0.53,"RDR OFF",0.038,radarOff)

    -- Requested radar submode labels are not proof of actual radar scan state.
    local requests={
        {1,"RWS REQ"},{2,"TWS REQ"},{3,"VS REQ"},
        {4,"ACM REQ"},{5,"FLOOD REQ"}
    }
    for _,entry in ipairs(requests) do
        for _,m in ipairs({2,3,4,5,6}) do
            local mode=visible("RADAR_MODE","HUD_MODE",m)
            local req=visible("RADAR_REQ","HUD_RADAR_REQUEST",entry[1],mode)
            static(0.76,0.55,entry[2],0.037,req)
        end
    end

    -- AIM-9 seeker reference: *boresight* circle only. No invented IR lock,
    -- uncage, tone, valid firing range or off-boresight cue.
    for _,m in ipairs({3,4,6}) do
        local sr=visible("IR","HUD_MODE",m)
        static(-0.77,0.83,"A/A",0.052,sr)
        static(0.75,0.83,"AIM-9",0.044,sr)
        ring(0,0,0.14,sr,32)
        cross(0,0,0.045,sr)
        local noSeeker=visible("IR_UNAVAILABLE","HUD_IR_SEEKER_VALID",0,sr)
        static(0,-0.8,"SEEKER DATA N/A",0.034,noSeeker)
        local seeker=visible("IR_SEEKER","HUD_IR_SEEKER_VALID",1,sr)
        -- A future live seeker LOS adapter can drive these offsets.
        static(0,-0.8,"SEEKER LOS",0.032,seeker)
    end

    -- A/A gun: boresight reticle only, not a lead-computing gunsight.
    local gun=visible("GUN","HUD_MODE",5)
    static(-0.77,0.83,"A/A",0.052,gun)
    static(0.77,0.83,"GUN",0.050,gun)
    ring(0,-0.025,0.13,gun,32)
    ring(0,-0.025,0.035,gun,20)
    cross(0,-0.025,0.18,gun)
    local noRange=visible("GUN_NO_RNG","HUD_GUN_TARGET_VALID",0,gun)
    static(0,-0.8,"GUN NO RNG",0.04,noRange)
    local withRange=visible("GUN_RANGE","HUD_GUN_TARGET_VALID",1,gun)
    label(0.72,-0.61,"HUD_AA_TGT_RANGE_NM","R %.1f",0.04,withRange)
    static(0,-0.80,"NO LEAD SOLUTION",0.032,withRange)
    local ready=visible("GUN_READY","HUD_GUN_READY",1,gun)
    static(0.76,-0.73,"GUN RDY",0.036,ready)

    -- A/G: generic manual depressed reticle. It is NOT a computed impact point.
    -- The requested CCIP/CCRP modes must show N/A until a valid solver exists.
    local ag=visible("AG","HUD_MODE",7)
    static(-0.77,0.83,"A/G",0.052,ag)
    local man=visible("MAN","HUD_AG_SUBMODE",1,ag)
    static(0.76,0.83,"MAN",0.050,man)
    local ccip=visible("CCIP","HUD_AG_SUBMODE",2,ag)
    static(0.73,0.83,"CCIP N/A",0.039,ccip)
    local ccrp=visible("CCRP","HUD_AG_SUBMODE",3,ag)
    static(0.73,0.83,"CCRP N/A",0.039,ccrp)
    local noAG=visible("NO_AG_TGT","HUD_AG_TARGET_VALID",0,ag)
    static(0,-0.80,"NO DESIGNATION",0.039,noAG)
    local mark=visible("AG_MARK","HUD_AG_TARGET_VALID",1,ag)
    static(0,-0.80,"MARKPOINT",0.037,mark)
    label(0.75,-0.46,"HUD_AG_TGT_RANGE_NM","R %.1f",0.037,mark)
    group("HUD_AG_MARKER",0,0,
        {"HUD_AG_TGT_AZ_RAD","HUD_AG_TGT_EL_RAD","HUD_POWER","HUD_AG_CUE_VALID","HUD_MODE"},
        {{"move_left_right_using_parameter",0,1.18},
         {"move_up_down_using_parameter",1,1.18},
         {"opacity_using_parameter",2},
         {"parameter_in_range",3,0.9,1.1},
         {"parameter_in_range",4,6.9,7.1}})
    diamond(0,0,0.060,"HUD_AG_MARKER")
    local manual=visible("AG_MAN_PIP","HUD_AG_SUBMODE",1,ag)
    ring(0,-0.28,0.065,manual,24)
    cross(0,-0.28,0.025,manual)
end

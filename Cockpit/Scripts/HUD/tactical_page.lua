-- Separate, evidence-labelled tactical HUD layer.
-- F-22 flight layout: USAF Flying Safety, June 2002.
-- Tactical representation: generic military symbology conventions only.
-- No false CCIP, WEZ, target tracks, or seeker lock indicators.
return function(api)
    local line, label, static, group = api.line, api.label, api.static, api.group
    local pi = math.pi
    local function angular(name,x,y,params,controllers,parent,reference_y)
        local corrected={}
        for i,c in ipairs(controllers) do
            local row={}
            for k,v in ipairs(c) do row[k]=v end
            if row[1]=="move_left_right_using_parameter" or row[1]=="move_up_down_using_parameter" then
                row[3]=(row[3]<0 and -1 or 1)/api.layout_scale
            end
            corrected[i]=row
        end
        return group(name,x,y+(parent and 0 or reference_y or api.boresight_y),params,corrected,parent)
    end
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

    -- EW azimuth repeater: same font/material as the existing HUD. The fixed
    -- bearing-circle placement is deliberately different from a radar TD box.
    for i=1,6 do
        local p=string.format('HUD_EW_%02d_',i);local n='HUD_EW_CONTACT_'..i
        group(n,0,0,{p..'X',p..'Y',p..'VALID','HUD_POWER'},
            {{'move_left_right_using_parameter',0,1},{'move_up_down_using_parameter',1,1},
             {'parameter_in_range',2,.9,1.1},{'opacity_using_parameter',3}})
        group(n..'_NUMBER',0,0,{p..'LABEL_CODE'},{{'parameter_in_range',0,-.1,99.9}},n)
        label(0,0,p..'LABEL_CODE','%.0f',.024,n..'_NUMBER')
        for code,symbol in ipairs(dofile(LockOn_Options.script_path..'Systems/RWR_Computer.lua').symbols) do
            local v=n..'_SYMBOL_'..code
            group(v,0,0,{p..'LABEL_CODE'},{{'parameter_in_range',0,98.9+code,99.1+code}},n)
            static(0,0,symbol,.024,v)
        end
        group(n..'_AZIMUTH',0,0,{p..'ROT'},{{'rotate_using_parameter',0,1}},n)
        for signal=1,3 do
            local state=visible('EW_LINE',p..'SIGNAL',signal,n..'_AZIMUTH')
            local fresh=visible('EW_FRESH',p..'COAST',0,state)
            local coast=visible('EW_MEMORY',p..'COAST',1,state)
            local length=.035*signal
            line(0,-.026,0,-.026-length,.004,fresh)
            for j=0,2 do line(0,-.026-j*length/3,0,-.026-(j+.6)*length/3,.004,coast) end
            if signal>1 then
                line(-.013,-.019,0,-.03,.004,state)
                line(0,-.03,.013,-.019,.004,state)
            end
        end
    end

    -- Shared combat SAFE/ARM cue (actual cockpit master arm, not launch permission).
    local combat = visible("COMBAT","HUD_MODE",2)
    -- All weapon modes are separate so power and master arm remain independent.
    for _,n in ipairs({3,4,5,6,7}) do
        local armRoot=visible("ARMROOT","HUD_MODE",n)
        local armed=visible("ARM","HUD_ARMED",1,armRoot)
        local safed=visible("SAFE","HUD_ARMED",0,armRoot)
        static(-0.40,-0.62,"ARM",0.023,armed)
        static(-0.40,-0.62,"SAFE",0.023,safed)
    end
    local combatArm = visible("ARM","HUD_ARMED",1,combat)
    local combatSafe = visible("SAFE","HUD_ARMED",0,combat)
    static(-0.40,-0.62,"ARM",0.023,combatArm)
    static(-0.40,-0.62,"SAFE",0.023,combatSafe)

    -- NAV: retain historical flight symbology and C-130-inspired heading tape.
    local nav = visible("NAV","HUD_MODE",1)
    -- Ordinary waypoints use steering marks. A 3-D diamond requires explicit WPDSG.
    angular("HUD_NAV_STEERING",0,0,
        {"HUD_WP_X","HUD_WP_Y","HUD_POWER","HUD_WP_CUE_VALID","HUD_MODE"},
        {{"move_left_right_using_parameter",0,1.18},
         {"move_up_down_using_parameter",1,1.18},
         {"opacity_using_parameter",2},
         {"parameter_in_range",3,0.9,1.1},
         {"parameter_in_range",4,0.9,1.1}})
    diamond(0,0,0.047,"HUD_NAV_STEERING")
    angular('HUD_NAV_OFFSCREEN',0,0,
        {'HUD_WP_ARROW_X','HUD_WP_ARROW_Y','HUD_POWER','HUD_WP_OFFSCREEN','HUD_MODE'},
        {{'move_left_right_using_parameter',0,1},{'move_up_down_using_parameter',1,1},
         {'opacity_using_parameter',2},{'parameter_in_range',3,.9,1.1},{'parameter_in_range',4,.9,1.1}})
    group('HUD_NAV_DIRECTION',0,0,{'HUD_WP_ARROW_ROT'},{{'rotate_using_parameter',0,1}},'HUD_NAV_OFFSCREEN')
    line(0,.025,-.018,-.012,.004,'HUD_NAV_DIRECTION')
    line(0,.025,.018,-.012,.004,'HUD_NAV_DIRECTION')
    label(0,-.04,'HUD_NAV_TARGET_LABEL','%s',.018,'HUD_NAV_OFFSCREEN')

    -- Selected payload identity/count, shared with the weapon controller.
    -- Without track/kinematics the HUD MUST NOT show a DLZ or SHOOT cue.
    local mrm = visible("MRM","HUD_MODE",2)
    static(-0.40,-0.48,"A/A",0.025,mrm)
    label(0.57,-0.59,"F22_WEAPON_NAME","%s",0.021,mrm)
    label(.72,-.63,"F22_WEAPON_COUNT","X %.0f",.021,mrm,"RightCenter")
    local noMRM = visible("MRM_NO_TRACK","HUD_TD_VALID",0,mrm)
    static(0,-1.01,"NO TRACK",0.023,noMRM)
    local tgtText = visible("MRM_TGT","HUD_TD_VALID",1,mrm)
    local closure=visible("MRM_CLOSURE","F22_RADAR_SELECTED_CLOSURE_VALID",1,tgtText)
    local iffFriend = visible("FRIEND","HUD_AA_TGT_IFF",1,tgtText)
    static(0.0,-1.01,"FRIEND",0.023,iffFriend)
    local radarPowered = visible("RDR_ON","RADAR_PWR",1,mrm)
    local radarOff = visible("RDR_OFF","RADAR_PWR",0,mrm)

    -- Actual radar computer status. Mode selection is not weapon consent.
    for _,m in ipairs({2,3,4,5,6}) do
        local root=visible("RADAR_STATUS","HUD_MODE",m)
        for code,value in ipairs({'OFF','STBY','RWS','TWS','ACQ','STT','BORE','VACQ','WIDE','SENSOR N/A'}) do
            local status=visible('RADAR_CODE','F22_RADAR_MODE_CODE',code-1,root)
            static(0.60,-0.37,value,0.021,status)
        end
    end

    -- AIM-9 states come from the typed native seeker; radar lock alone is not IR lock.
    for _,m in ipairs({3,4,6}) do
        local sr=visible("IR","HUD_MODE",m)
        static(-0.40,-0.48,"A/A",0.025,sr)
        label(0.57,-0.59,"F22_WEAPON_NAME","%s",0.021,sr)
        label(.72,-.63,"F22_WEAPON_COUNT","X %.0f",.021,sr,"RightCenter")
        local seekerPos="HUD_IR_NATIVE_"..m
        angular(seekerPos,0,0,
            {"HUD_IR_SEEKER_X_SLOPE","HUD_IR_SEEKER_Y_SLOPE","HUD_POWER","HUD_IR_SEEKER_AVAILABLE","HUD_MODE"},
            {{"move_left_right_using_parameter",0,1.18},{"move_up_down_using_parameter",1,1.18},
             {"opacity_using_parameter",2},{"parameter_in_range",3,.9,1.1},
             {"parameter_in_range",4,m-.1,m+.1}},nil,
             dofile(LockOn_Options.script_path..'HUD/optics.lua').frl_elevation/api.layout_scale)
        -- Hornet direction marker: 1.5 degrees diameter, separate from sensor FOV.
        ring(0,0,math.rad(.75)/api.layout_scale,seekerPos,32)
        local radarInfo=visible("IR_RADAR_INFO","HUD_AA_TARGET_VALID",1,sr)
        local irClosure=visible("IR_CLOSURE","HUD_AA_CLOSURE_VALID",1,radarInfo)
        local noSeeker=visible("IR_UNAVAILABLE","HUD_IR_BACKEND_READY",0,sr)
        static(-0.40,-0.69,"IR BACKEND N/A",0.023,noSeeker)
        local backend=visible("IR_BACKEND","HUD_IR_BACKEND_READY",1,sr)
        local empty=visible("IR_EMPTY","F22_WEAPON_COUNT",0,backend)
        label(-0.40,-0.69,"F22_WEAPON_EMPTY_TEXT","%s",0.023,empty)
        local searching=visible("IR_AVAILABLE","HUD_IR_SEEKER_AVAILABLE",1,backend)
        local noLock=visible("IR_SEARCH","HUD_IR_SEEKER_VALID",0,searching)
        static(-0.40,-0.69,"NO IR LOCK",0.023,noLock)
        local seeker=visible("IR_SEEKER","HUD_IR_SEEKER_VALID",1,sr)
        static(-0.40,-0.69,"IR TRACK",0.023,seeker)
    end

    -- Computed target-motion director; no alternate aiming source.
    local gun=visible("GUN","HUD_MODE",5)
    static(-0.40,-0.48,"A/A",0.025,gun)
    static(0.57,-0.59,"GUN",0.021,gun)
    local ammo=visible("GUN_AMMO","F22_GUN_AMMO_VALID",1,gun)
    label(-0.40,-0.69,"F22_GUN_AMMO_COUNT","AMMO %03.0f",0.023,ammo)
    local noAmmo=visible("GUN_AMMO_NA","F22_GUN_AMMO_VALID",0,gun)
    static(-0.40,-0.69,"AMMO N/A",0.023,noAmmo)
    local noRange=visible("GUN_NO_RNG","HUD_GUN_TARGET_VALID",0,gun)
    local withRange=visible("GUN_RANGE","HUD_GUN_TARGET_VALID",1,gun)
    local gunVC=visible("GUN_CLOSURE","HUD_AA_CLOSURE_VALID",1,withRange)
    local director=visible("GUN_DIRECTOR","F22_GUN_USING_DIRECTOR",1,withRange)
    static(0,-0.78,"TRACK  ARC 2KM",0.025,director)
    -- Native sight includes the gun transform. Project its body ray onto the
    -- same physical optical plane as the fixed aircraft reference and FPM.
    local gun_optics=dofile(LockOn_Options.script_path.."HUD/optics.lua")
    if log and log.write then
        log.write("F22_GUN_ALIGNMENT",log.INFO,string.format(
            "native gun transform retained; optical_zero=%.3f mrad; layout_zero=%.3f mrad",
            gun_optics.frl_elevation*1000,api.boresight_y*api.layout_scale*1000))
    end
    angular("HUD_GUN_NATIVE",0,0,
        {"HUD_GUN_NATIVE_X_SLOPE","HUD_GUN_NATIVE_Y_SLOPE","HUD_POWER","HUD_GUN_NATIVE_VALID","HUD_MODE"},
        {{"move_left_right_using_parameter",0,1.18},
         {"move_up_down_using_parameter",1,1.18},
         {"opacity_using_parameter",2},
         {"parameter_in_range",3,0.9,1.1},
         {"parameter_in_range",4,4.9,5.1}},nil,gun_optics.frl_elevation/api.layout_scale)
    dofile(LockOn_Options.script_path..'HUD/gun_maneuver.lua')(api,gun,gun_optics.frl_elevation/api.layout_scale)
    dofile(LockOn_Options.script_path..'HUD/gun_reticle.lua')(api,"HUD_GUN_NATIVE")
    dofile(LockOn_Options.script_path..'HUD/gun_funnel.lua')(api,noRange,gun_optics.frl_elevation/api.layout_scale)
    local noSight=visible("GUN_NO_SIGHT","HUD_GUN_NATIVE_VALID",0,withRange)
    static(0,-0.86,"GUN NO SOLUTION",0.025,noSight)
    local reference='HUD_GUN_FIXED_REFERENCE'
    group(reference,0,gun_optics.frl_elevation/api.layout_scale,{}, {},noSight)
    local reference_unit=1/(1000*api.layout_scale)
    line(-1.5*reference_unit,0,1.5*reference_unit,0,.75*reference_unit,reference)
    line(0,-1.5*reference_unit,0,1.5*reference_unit,.75*reference_unit,reference)
    static(.04,0,'REF',.018,reference) -- Fixed aircraft datum, never a computed lead.
    local ready=visible("GUN_READY","HUD_GUN_READY",1,gun)
    static(0.40,-0.69,"GUN RDY",0.025,ready)

    -- Hornet convention: solid confirmed track, segmented designation, locator
    -- line/angle when outside the HUD. Keep weapon consent on native STT only.
    local optical_y=gun_optics.frl_elevation/api.layout_scale
    local unit=1/api.layout_scale
    angular('HUD_RADAR_TD',0,0,{'HUD_TD_X','HUD_TD_Y','HUD_POWER','HUD_TD_BOX_VALID','HUD_MODE'},
        {{'move_left_right_using_parameter',0,1},{'move_up_down_using_parameter',1,1},
         {'opacity_using_parameter',2},{'parameter_in_range',3,.9,1.1},{'parameter_in_range',4,.9,6.1}},nil,optical_y)
    angular('HUD_SECONDARY_TD',0,0,{'HUD_DT2_X','HUD_DT2_Y','HUD_POWER','HUD_DT2_VALID','HUD_MODE'},
        {{'move_left_right_using_parameter',0,1},{'move_up_down_using_parameter',1,1},
         {'opacity_using_parameter',2},{'parameter_in_range',3,.9,1.1},{'parameter_in_range',4,.9,6.1}},nil,optical_y)
    local s2=.008/api.layout_scale
    line(-s2,-s2,s2,s2,.001/api.layout_scale,'HUD_SECONDARY_TD')
    line(-s2,s2,s2,-s2,.001/api.layout_scale,'HUD_SECONDARY_TD')
    local normal=visible('TD_NORMAL','HUD_TD_FRIENDLY',0,'HUD_RADAR_TD')
    local friend=visible('TD_FRIEND','HUD_TD_FRIENDLY',1,'HUD_RADAR_TD')
    local solid=visible('TD_SOLID','HUD_TD_LOCKED',1,normal)
    local segmented=visible('TD_DESIGNATED','HUD_TD_LOCKED',0,normal)
    local r,w=.0125*unit,.001*unit
    line(-r,-r,r,-r,w,friend);line(r,-r,r,r,w,friend)
    line(r,r,-r,r,w,friend);line(-r,r,-r,-r,w,friend)
    line(-r,-r,r,r,w,friend);line(-r,r,r,-r,w,friend)
    static(0,-r-.012*unit,'FRIENDLY',.018,friend)
    line(-r,-r,r,-r,w,solid);line(r,-r,r,r,w,solid)
    line(r,r,-r,r,w,solid);line(-r,r,-r,-r,w,solid)
    for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do
        line(sx*r,sy*r,sx*r*.4,sy*r,w,segmented)
        line(sx*r,sy*r,sx*r,sy*r*.4,w,segmented)
    end end
    angular('HUD_TARGET_LOCATOR',0,0,{'HUD_TD_ARROW_X','HUD_TD_ARROW_Y','HUD_POWER','HUD_TD_ARROW_VALID','HUD_MODE'},
        {{'move_left_right_using_parameter',0,1},{'move_up_down_using_parameter',1,1},
         {'opacity_using_parameter',2},{'parameter_in_range',3,.9,1.1},{'parameter_in_range',4,.9,6.1}},nil,optical_y)
    group('HUD_TARGET_LOCATOR_ROT',0,0,{'HUD_TD_ARROW_ROT'},{{'rotate_using_parameter',0,1}},'HUD_TARGET_LOCATOR')
    line(0,-.040*unit,0,0,w,'HUD_TARGET_LOCATOR_ROT')
    line(-.008*unit,-.014*unit,0,0,w,'HUD_TARGET_LOCATOR_ROT')
    line(.008*unit,-.014*unit,0,0,w,'HUD_TARGET_LOCATOR_ROT')
    local angle=visible('TARGET_ANGLE','HUD_TD_ARROW_VALID',1)
    label(0,optical_y-.13,'HUD_TD_ANGLE_DEG','TGT %03.0f',.021,angle)
    local shoot=visible('LAUNCH_CUE','F22_FC_SHOOT',1,'HUD_RADAR_TD')
    static(0,r+.017*unit,'SHOOT',.021,shoot)
    dofile(LockOn_Options.script_path..'HUD/engagement.lua')(api)
    -- Acquisition bounds in optical radians, clipped by the existing glass mask.
    local profiles=dofile(LockOn_Options.script_path..'Systems/Radar_Computer.lua').profiles
    for _,key in ipairs({'BORE','VACQ','WIDE'}) do
        local spec=profiles[key]
        local mode,az,lo,hi=spec.code,spec.az,spec.lo,spec.hi
        local name='HUD_ACM_VOLUME_'..mode
        angular(name,0,0,{'HUD_POWER','F22_ACM_MODE','F22_RADAR_STT_VALID','RADAR_PWR','HUD_MODE'},
            {{'opacity_using_parameter',0},{'parameter_in_range',1,mode-.1,mode+.1},
             {'parameter_in_range',2,-.1,.1},{'parameter_in_range',3,.9,1.1},{'parameter_in_range',4,2.9,6.1}})
        local x=math.rad(az)/api.layout_scale
        local y1=math.rad(lo)/api.layout_scale;local y2=math.rad(hi)/api.layout_scale
        line(-x,y1,-x,y2,.004,name);line(x,y1,x,y2,.004,name)
        line(-x,y1,-x+.04,y1,.004,name);line(x-.04,y1,x,y1,.004,name)
    end

    dofile(LockOn_Options.script_path..'HUD/ag.lua')(api)
    dofile(LockOn_Options.script_path..'HUD/pilot_warnings.lua')(api)
    group('HUD_SENSOR_FOCUS',0,0,{'HUD_POWER','F22_SOI'},
        {{'opacity_using_parameter',0},{'parameter_in_range',1,.9,1.1}})
    static(-.57,-.72,'HUD',.019,'HUD_SENSOR_FOCUS')
end

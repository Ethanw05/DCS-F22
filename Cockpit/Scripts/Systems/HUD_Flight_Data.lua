-- GPL-3.0-or-later. Authoritative producer for the independent flight HUD.
local data=get_base_data()
local mathhud=dofile(LockOn_Options.script_path.."Systems/HUD_FlightMath.lua")
local layout=dofile(LockOn_Options.script_path.."HUD/layout.lua")
local projection=dofile(LockOn_Options.script_path.."Systems/HUD_Projection.lua")
local dt=0.02
make_default_activity(dt)
local handles={}
local function h(name)
    if not handles[name] then handles[name]=get_param_handle(name) end
    return handles[name]
end
local function put(n,v) h(n):set(v) end
local function read(n) return h(n):get() end
-- Native indicators bind during construction, before post_initialize/update.
-- Publish only render-plane defaults and invalid gates; angular data retain
-- their existing owner/update contract.
for _,name in ipairs({"HUD_FPM_X_SLOPE","HUD_FPM_Y_SLOPE","HUD_FPM_VALID",
    "HUD_AIRDATA_VALID","HUD_WIND_VALID","HUD_GS_VALID","HUD_ALT_VALID","HUD_LANDING_CONFIG",
    "HUD_EBRACKET_OFFSET","HUD_EBRACKET_VALID"}) do put(name,0) end
local peak_g=1
local previous_cas=nil
local acceleration=0
local diagnostic_frames=0
local next_landing_log=0
function post_initialize()
    peak_g=1; previous_cas=nil; acceleration=0
    put("HUD_FPM_VALID",0); put("HUD_AIRDATA_VALID",0)
    put("HUD_WIND_VALID",0); put("HUD_GS_VALID",0);put("HUD_ALT_VALID",0)
end
function update()
    put("HUD_ALT_VALID",0)
    if read('F22_ALT_BARO_VALID')>.5 then
        local altitude=read('F22_ALT_BARO_FT')
        if mathhud.finite(altitude)then
            put('HUD_ALT_POINTER',-(altitude%1000)*2*math.pi/1000);put('HUD_ALT_VALID',1)
        end
    end
    local pitch,roll=data.getPitch(),data.getRoll()
    local heading=(2*math.pi-data.getHeading())%(2*math.pi)
    -- The existing UFD/MFD ADIs use raw getRoll() with rotation gain +1.
    -- Keep the HUD in that same frame; negating roll mirrors the ladder.
    put("HUD_PITCH",pitch); put("HUD_ROLL",roll)
    -- Keep attitude strokes out of the fixed heading/data/roll-scale zones.
    local function inside(center,halfwidth)
        local spread=halfwidth*math.abs(math.sin(roll))
        return center-spread>layout.ladder_y_min and center+spread<layout.ladder_y_max
    end
    put("HUD_HORIZON_VISIBLE",inside(layout.boresight_y*layout.angular_scale-pitch*math.cos(roll),0.27*layout.angular_scale) and 1 or 0)
    for step=-18,18 do
        if step~=0 then
            local center=layout.boresight_y*layout.angular_scale+(math.rad(step*5)-pitch)*math.cos(roll)
            put("HUD_LADDER_"..step,inside(center,0.27*layout.angular_scale) and 1 or 0)
        end
    end
    put("HUD_BANK_RAD",roll)
    local beta=data.getAngleOfSlide()
    put("HUD_BANK_SLIP",mathhud.clamp(beta/math.rad(10),-1,1)*0.045)
    local g=data.getVerticalAcceleration()
    if mathhud.finite(g) then peak_g=math.max(peak_g,g) end
    put("HUD_G_MAX",peak_g)
    local aoa=data.getAngleOfAttack()*180/math.pi
    put("HUD_AOA_DEG",aoa)
    local base_wow=data.getWOW_NoseLandingGear()
    local own_contact=read('EFM_GROUND_VALID')>.5
    local gear=own_contact and read('EFM_WEIGHT_ON_WHEELS') or base_wow
    local gear_down=get_aircraft_draw_argument_value(0)>0.95
    put("HUD_LANDING_CONFIG",gear_down and 1 or 0)
    -- Hornet presentation, this aircraft's existing 12-degree approach target.
    -- AOA error moves the complete bracket relative to the velocity vector.
    local bracket_valid=gear_down and gear<.5 and mathhud.finite(aoa)
    put('HUD_EBRACKET_VALID',bracket_valid and 1 or 0)
    put('HUD_EBRACKET_OFFSET',bracket_valid and math.tan(math.rad(mathhud.clamp(aoa-12,-10,10))) or 0)
    put("HUD_APPROACH_LOW",(gear_down and gear<0.5 and aoa<11.5) and 1 or 0)
    put("HUD_APPROACH_HIGH",(gear_down and gear<0.5 and aoa>12.5) and 1 or 0)
    local now=type(get_model_time)=='function'and get_model_time()or diagnostic_frames*dt
    if gear_down and now>=next_landing_log and log and log.write then
        next_landing_log=now+1
        log.write('F22_LANDING',log.INFO,string.format('t=%.3f gear_down=1 wow_base=%.0f contact=%.0f contact_native=%s aoa=%.3f bracket=%s offset=%.5f fpm=%.0f loc=%.0f gs=%.0f',
            now,base_wow,gear,tostring(own_contact),aoa,tostring(bracket_valid),read('HUD_EBRACKET_OFFSET'),read('HUD_FPM_VALID'),read('HUD_ILS_LOC_VALID'),read('HUD_ILS_GS_VALID')))
    end
    local vs=data.getVerticalVelocity()*196.850394
    put("HUD_VS_ARC_COUNT",math.floor(mathhud.clamp(math.abs(vs)/38000,0,1)*32+0.5))
    put("HUD_VS_SIGN",vs>=0 and 1 or -1)
    put("HUD_FPM_VALID",0); put("HUD_GS_VALID",0)
    put("HUD_WIND_VALID",0); put("HUD_AIRDATA_VALID",0)
    if read("EFM_HUD_VALID")<0.5 then previous_cas=nil;return end
    local n,e,u=read("EFM_HUD_VN"),read("EFM_HUD_VE"),read("EFM_HUD_VU")
    if not (mathhud.finite(n) and mathhud.finite(e) and mathhud.finite(u)) then
        previous_cas=nil;return
    end
    local gs=math.sqrt(n*n+e*e)
    put("HUD_GS_MPS",gs);put("HUD_GS_KTS",gs*1.943844492);put("HUD_GS_VALID",1)
    local az,el=mathhud.project(n,e,u,heading,pitch,roll)
    diagnostic_frames=diagnostic_frames+1
    if diagnostic_frames==50 and log and log.write then
        log.write("F22_HUD_DATA",log.INFO,string.format(
            "pitch_deg=%.3f roll_deg=%.3f heading_deg=%.3f aoa_deg=%.3f vn=%.3f ve=%.3f vu=%.3f fpm_az=%.6f fpm_el=%.6f",
            pitch*180/math.pi,roll*180/math.pi,heading*180/math.pi,aoa,n,e,u,az or 0,el or 0))
    end
    if az and math.abs(az)<0.20 and el> -0.25 and el<0.11 then
        put("HUD_FPM_X_RAD",az);put("HUD_FPM_Y_RAD",el)
        local x,y=projection.planar(az,el)
        put("HUD_FPM_X_SLOPE",x);put("HUD_FPM_Y_SLOPE",y);put("HUD_FPM_VALID",1)
    end
    local tas=read("EFM_HUD_TAS")
    local cas=mathhud.cas(tas,read("EFM_HUD_SOUND"),read("EFM_HUD_PRESSURE"))
    if cas then
        cas=cas*1.943844492
        put("HUD_CAS",cas);put("HUD_TAS",tas*1.943844492)
        -- Negative mathematical rotation gives a clockwise dial needle.
        put("HUD_IAS_POINTER",-(cas%100)*2*math.pi/100)

        put("HUD_AIRDATA_VALID",1)
        if previous_cas then
            local raw=(cas-previous_cas)/dt
            if math.abs(raw)<50 then acceleration=acceleration+(raw-acceleration)*(1-math.exp(-dt/0.5))
            else acceleration=0 end
        end
        previous_cas=cas
        put("HUD_ACCEL_UP",acceleration>0.5 and 1 or 0)
        put("HUD_ACCEL_DOWN",acceleration< -0.5 and 1 or 0)
    end
    local wn,we=read("EFM_HUD_WN"),read("EFM_HUD_WE")
    if not (mathhud.finite(wn) and mathhud.finite(we)) then return end
    local windspeed=math.sqrt(wn*wn+we*we)*1.943844492
    local bearing=mathhud.atan2(-we,-wn)
    put("HUD_WIND_KTS",windspeed)
    put("HUD_WIND_DEG",(bearing*180/math.pi+360)%360)
    -- Numeric bearing is wind-from; arrow points with the wind's flow.
    put("HUD_WIND_ROT",heading-bearing+math.pi)
    put("HUD_WIND_VALID",windspeed>=1 and 1 or 0)
end
need_to_be_closed=false

"""Render actual Lua-emitted HUD elements/controllers with the shipped font atlas.

This is a reference rasterizer, not the proprietary DCS optical compositor.
Run with Python containing Pillow and lupa.lua51. No DCS process is needed.
"""
from pathlib import Path
import argparse
import json
import math
import re
import runpy
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=ROOT.parent/'HUD-Previews')
parser.add_argument('--radar', action='store_true',help='Add explicitly synthetic radar/weapon sensor fixtures')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
runtime = runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
lua = runtime()
lua.execute('dofile(SCRIPT_ROOT.."HUD/page.lua")')
layout=lua.execute('return dofile(SCRIPT_ROOT.."HUD/layout.lua")')
glass=lua.execute('return dofile(SCRIPT_ROOT.."HUD/glass.lua")')
font_def=lua.execute('return dofile(SCRIPT_ROOT.."HUD/font.lua")')

def convert(value):
    if hasattr(value, 'items'):
        items = list(value.items())
        if items and all(isinstance(k, int) for k, _ in items):
            return [convert(v) for _, v in sorted(items)]
        return {str(k): convert(v) for k, v in items}
    return value

elements = convert(lua.globals().elements)
# DCS page is explicitly milliradians; the software projector uses radians.
# Normalize actual emitted positions and translation gains once.
# Stringdefs are final font metrics and do not receive the mrad conversion.
assert lua.globals().selected_scale == lua.globals().MILLYRADIANS
for element in elements:
    for field in ('init_pos',):
        if field in element:
            element[field] = [value / 1000 for value in element[field]]
    if 'vertices' in element:
        element['vertices'] = [[v / 1000 for v in point] for point in element['vertices']]
    for controller in element.get('controllers', []):
        if controller[0] in ('move_up_down_using_parameter', 'move_left_right_using_parameter'):
            controller[2] /= lua.globals().GetScale() * 1000
lookup = {e['name']: e for e in elements}
atlas = Image.open(ROOT/'Cockpit/Scripts/IndicationTextures/FONT_PFD.dds').convert('RGBA')
font_source = (ROOT/'Cockpit/Scripts/fonts.lua').read_text(errors='replace')
font_source = font_source.split('local F22_PFD =', 1)[1].split('F18_xsize', 1)[0]
glyphs = {}
for index, code in re.findall(r'\[(\d+)\]\s*=\s*\{(\d+),\s*141,\s*256\}', font_source):
    slot = int(index)-1
    glyphs[chr(int(code))] = atlas.crop(((slot%8)*256,(slot//8)*256,(slot%8)*256+141,(slot//8)*256+256))

SUPERSAMPLE=3
W, H, FOCAL = 1100*SUPERSAMPLE, 1000*SUPERSAMPLE, 1600*SUPERSAMPLE
CX, CY = W/2, 510*SUPERSAMPLE
GREEN = (1, 255, 2, 255)
CAMERA_PITCH=math.radians(-8.414850)
EYE=(.247411,-.067882,0)
FONT_DISTANCE=lua.globals().GetScale()*1000
stroke_ids={int(c[1]):c[2] for _,c in font_def['chars'].items()}
stroke_paths={}
svg=ET.parse(ROOT/'Cockpit/Scripts/HUD'/ (font_def['symb_storage']+'.svg'))
for element in svg.iter():
    if element.tag.endswith('path') and element.get('id'):
        paths=[]; path=[]; command=None
        tokens=re.findall(r'[MLZmlz]|[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?',element.get('d',''))
        i=0
        while i<len(tokens):
            token=tokens[i]
            if token in ('M','L','Z'):
                command=token; i+=1
                if command=='Z':
                    if path:path.append(path[0]);paths.append(path);path=[]
                    continue
                if command=='M' and path:paths.append(path);path=[]
            else:
                if command not in ('M','L'):raise ValueError('Unsupported stroke path command')
                path.append((float(tokens[i])/28.222222222,float(tokens[i+1])/28.222222222));i+=2
        if path:paths.append(path)
        stroke_paths[element.get('id')]=paths

def project_vector(x,y,z):
    depth=x*math.cos(CAMERA_PITCH)+y*math.sin(CAMERA_PITCH)
    up=-x*math.sin(CAMERA_PITCH)+y*math.cos(CAMERA_PITCH)
    return CX+z/depth*FOCAL,CY-up/depth*FOCAL

def angular_pixel(x,y):
    return project_vector(1,y-.022/.55,x)

glass_points=[project_vector(v[1]-EYE[0],v[2]-EYE[1],v[3]-EYE[2]) for _,v in glass['vertices'].items()]
glass_indices=[i for _,i in glass['indices'].items()]
states = {
    '01-runway': dict(IAS=0, BAROALT=41, RADALT=5, MACH=0, GFORCE=1, AOA=0.8,
        NAV=0, VV=0, HUD_POWER=1, HUD_MODE=1, HUD_PITCH=0, HUD_ROLL=0,
        HUD_FPA=0, HUD_SLIP=0, HUD_IAS_POINTER=0, HUD_ALT_POINTER=0.258,
        HUD_HEADING_OFFSET=0, HUD_TICK_M20=340, HUD_TICK_M10=350,
        HUD_TICK_C00=0, HUD_TICK_P10=10, HUD_TICK_P20=20),
    '02-flight': dict(IAS=350, BAROALT=12500, RADALT=11940, MACH=0.62, GFORCE=1,
        AOA=3.1, NAV=274, VV=600, HUD_POWER=1, HUD_MODE=1, HUD_PITCH=0.025,
        HUD_ROLL=0, HUD_FPA=0.017, HUD_SLIP=0, HUD_IAS_POINTER=math.pi,
        HUD_ALT_POINTER=math.pi, HUD_HEADING_OFFSET=4, HUD_TICK_M20=250,
        HUD_TICK_M10=260, HUD_TICK_C00=270, HUD_TICK_P10=280, HUD_TICK_P20=290,
        HUD_WP_VALID=1, HUD_WP_INDEX=2, HUD_WP_RANGE_NM=18.4,
        HUD_WP_BRG_VALID=1, HUD_WP_BEARING_DEG=276),
    '03-banked': dict(IAS=280, BAROALT=8000, RADALT=5200, MACH=0.48, GFORCE=1.4,
        AOA=5.2, NAV=90, VV=1200, HUD_POWER=1, HUD_MODE=1, HUD_PITCH=0.08,
        BANK_RAD=math.radians(25), HUD_FPA=0.04, HUD_SLIP=0.012,
        HUD_IAS_POINTER=1.6*math.pi, HUD_ALT_POINTER=0, HUD_HEADING_OFFSET=0,
        HUD_TICK_M20=70, HUD_TICK_M10=80, HUD_TICK_C00=90,
        HUD_TICK_P10=100, HUD_TICK_P20=110),
    '04-power-off': dict(HUD_POWER=0, HUD_MODE=1),
}

# Compute new display outputs by executing the actual producer against supplied
# host telemetry, rather than inventing FPM/pointer/approach positions in Python.
def flight_outputs(params):
    sim=runtime()
    inputs=dict(pitch=params.get('HUD_PITCH',0),roll=params.get('BANK_RAD',0),
        heading=math.radians(params.get('NAV',0)),aoa=params.get('AOA',0),
        g=params.get('GFORCE',1),vv=params.get('VV',0)/196.850394,
        altitude=params.get('BAROALT',0)/3.280839895,
        gear=params.get('GEAR',0),wow=params.get('WOW',0))
    sim.globals().SAMPLE=sim.table_from(inputs)
    sim.execute('''
        function get_base_data() return {
            getPitch=function() return SAMPLE.pitch end,
            getRoll=function() return SAMPLE.roll end,
            getHeading=function() return -SAMPLE.heading end,
            getAngleOfSlide=function() return 0 end,
            getVerticalAcceleration=function() return SAMPLE.g end,
            getAngleOfAttack=function() return math.rad(SAMPLE.aoa) end,
            getVerticalVelocity=function() return SAMPLE.vv end,
            getBarometricAltitude=function() return SAMPLE.altitude end,
            getWOW_NoseLandingGear=function() return SAMPLE.wow end,
        } end
        function get_aircraft_draw_argument_value(_) return SAMPLE.gear end
    ''')
    speed=params.get('GS_MPS',params.get('IAS',0)/1.943844492)
    track=inputs['heading']+params.get('DRIFT_RAD',0)
    host=dict(EFM_HUD_VALID=1,EFM_HUD_VN=speed*math.cos(track),
        EFM_HUD_VE=speed*math.sin(track),EFM_HUD_VU=inputs['vv'],
        EFM_HUD_WN=params.get('WIND_N',0),EFM_HUD_WE=params.get('WIND_E',0),
        EFM_HUD_TAS=params.get('TAS_MPS',speed),EFM_HUD_SOUND=340.293988,
        EFM_HUD_PRESSURE=params.get('STATIC_PA',101325))
    for key,value in host.items(): sim.globals().get_param_handle(key).set(sim.globals().get_param_handle(key),value)
    sim.execute('dofile(SCRIPT_ROOT.."Systems/HUD_Flight_Data.lua");post_initialize();update()')
    if 'RADAR_FIXTURE' in params:
        sim.execute('dofile(SCRIPT_ROOT.."Systems/Radar_Data_Bridge.lua");post_initialize()')
        fixture=dict(MAIN_POWER=1,RADAR_PWR=1,HUD_MODE=params['HUD_MODE'],
            F22_RADAR_BACKEND_READY=1,F22N_RADAR_MODE=params['RADAR_FIXTURE'],
            F22N_RADAR_STT_RANGE=12000,F22N_RADAR_STT_AZIMUTH=.025,
            F22N_RADAR_STT_ELEVATION=-.015,F22N_RADAR_STT_FRIENDLY=-1)
        fixture.update({key:value for key,value in params.items() if key.startswith(('F22N_RADAR_STT_','F22_RADAR_DESIGNATION_','F22_RADAR_SECONDARY_'))})
        for key,value in fixture.items():
            p=sim.globals().get_param_handle(key);p.set(p,value)
        sim.globals().update()
    if params.get('EW_FIXTURE'):
        sim.execute("function GetDevice() return {set_power=function() end} end")
        fixture={'MAIN_POWER':1,'RWR_CONTACT_01_SOURCE':1,'RWR_CONTACT_01_SIGNAL':2,
            'RWR_CONTACT_01_AZIMUTH':math.radians(-35),'RWR_CONTACT_01_TIME':0,'RWR_CONTACT_01_UNIT_TYPE':'MiG-29S',
            'RWR_CONTACT_02_SOURCE':2,'RWR_CONTACT_02_SIGNAL':1,'RWR_CONTACT_02_AZIMUTH':math.radians(75),
            'RWR_CONTACT_02_TIME':0,'RWR_CONTACT_02_UNIT_TYPE':'FA-18C_hornet'}
        for key,value in fixture.items():
            h=sim.globals().get_param_handle(key);h.set(h,value)
        sim.execute("dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();update()")
    if params.get('ENGAGEMENT_FIXTURE'):
        sim.globals().engagement_fixture=params['ENGAGEMENT_FIXTURE']
        sim.globals().engagement_heading=inputs['heading']
        sim.execute("""
            local original=get_base_data()
            original.getSelfCoordinates=function()return 0,SAMPLE.altitude,0 end
            function get_base_data()return original end
            local function p(n,v)get_param_handle(n):set(v)end
            local d=dofile(SCRIPT_ROOT..'Systems/Radar_Display.lua')
            local state={range=engagement_fixture==2 and 60000 or 12000,az=.025,el=-.015}
            d.world_observation(state,{north=0,altitude=SAMPLE.altitude,east=0,heading=engagement_heading,pitch=SAMPLE.pitch,roll=SAMPLE.roll})
            for n,v in pairs({MAIN_POWER=1,RADAR_PWR=1,MASTER_ARM=1,F22_WEAPON_COUNT=5,
                F22_RADAR_WEAPON_TARGET_ID=1001,F22_RADAR_OBSERVATIONS_READY=1,F22_RADAR_OBSERVATION_COUNT=1,
                F22O_01_ID=1001,F22O_01_NORTH=state.north,F22O_01_ALTITUDE=state.altitude,F22O_01_EAST=state.east,
                F22O_01_VN=-200*math.cos(engagement_heading),F22O_01_VE=-200*math.sin(engagement_heading),
                F22_MISSILE_DATA_VALID=1,F22_MISSILE_NATIVE_MIN=700,F22_MISSILE_NATIVE_MAX=38490,F22_MISSILE_LIFETIME=90,
                F22_DLZ_NATIVE_VALID=1,F22_DLZ_TARGET_ID=1001,F22_DLZ_RMIN=700,F22_DLZ_RMAX=38490,F22_DLZ_RTR=18000})do p(n,v)end
            if engagement_fixture>=3 then
                for n,v in pairs({F22_LAUNCH_SEQUENCE=1,F22_SHOT_01_SEQUENCE=1,F22_SHOT_01_ID=2001,F22_SHOT_01_TARGET=1001,
                    F22_SHOT_01_MODE=2,F22_SHOT_01_TIME=0,F22_SHOT_01_ALIVE=1,F22_SHOT_01_N=100*math.cos(engagement_heading),
                    F22_SHOT_01_U=SAMPLE.altitude,F22_SHOT_01_E=100*math.sin(engagement_heading),
                    F22_SHOT_01_VN=800*math.cos(engagement_heading),F22_SHOT_01_VE=800*math.sin(engagement_heading),
                    F22_SHOT_01_ACTIVE_RANGE=5000,F22_SHOT_01_ACTIVE_VALID=1,F22_SHOT_01_SEEKER_VALID=1,F22_SHOT_01_SEEKER_TRACK=engagement_fixture==4 and 1 or 0,F22_SHOT_01_ACTIVE=engagement_fixture==4 and 1 or 0})do p(n,v)end
            end
            dofile(SCRIPT_ROOT..'Systems/Engagement_System.lua');post_initialize();update()
        """)
    derived={k:v['value'] for k,v in sim.globals().handles.items() if k.startswith(('HUD_','F22_FC_','F22_MSL_'))}
    result=dict(params);result.update(derived)
    # Background attitude is independent of the HUD sign convention. These
    # are the raw sensor angles consumed by the unchanged, ground-truth ADIs.
    result['ADIROLL']=inputs['roll']; result['ADIPITCH']=inputs['pitch']
    result['HUD_WP_INFO']='02 276/18.4' if params.get('HUD_WP_VALID') else 'STPT --'
    functions=sim.execute('return dofile(SCRIPT_ROOT.."Systems/HUD_FlightMath.lua")')
    result['HUD_WP_TTG_TEXT']=(functions.ttg(params.get('HUD_WP_RANGE_NM',0)*1852,speed)
        if params.get('HUD_WP_VALID') else None) or '--:--:--'
    return result

states['01-runway'].update(GEAR=1,WOW=1)
states['02-flight'].update(HUD_PITCH=math.radians(3),VV=0,TAS_MPS=180,GS_MPS=185,
    WIND_N=-5,WIND_E=8)
states['03-banked'].update(HUD_PITCH=math.radians(8),GEAR=1,AOA=10,GS_MPS=95,
    TAS_MPS=100,VV=1200,DRIFT_RAD=0.03)
for name,aoa,pitch in [('05-approach-low',10,7),('06-approach-high',14,11)]:
    states[name]=dict(IAS=175,BAROALT=700,RADALT=400,MACH=0.27,GFORCE=1,AOA=aoa,
        NAV=90,VV=-1000,HUD_POWER=1,HUD_MODE=1,HUD_PITCH=math.radians(pitch),
        HUD_ROLL=0,HUD_HEADING_OFFSET=0,HUD_TICK_M20=70,HUD_TICK_M10=80,
        HUD_TICK_C00=90,HUD_TICK_P10=100,HUD_TICK_P20=110,GEAR=1,
        GS_MPS=95,TAS_MPS=100)
states['07-bank-left']=dict(states['03-banked'],BANK_RAD=-math.radians(25))
states['08-steep-climb']=dict(states['02-flight'],HUD_PITCH=math.radians(45),BANK_RAD=0)
states['09-steep-dive']=dict(states['02-flight'],HUD_PITCH=math.radians(-45),BANK_RAD=0)
if args.radar:
    for index,mode,native in [(10,'RWS',1),(11,'TWS',1),(12,'STT',3),(13,'ACQ',2)]:
        states[f'{index}-{mode}-sensor-fixture']=dict(states['02-flight'],HUD_MODE=2,
            RADAR_FIXTURE=native,F22_RADAR_MODE_TEXT=mode,RADAR_PWR=1,HUD_ARMED=0)
    for index,acm,name in [(14,1,'BORE'),(15,2,'VERT'),(16,3,'WIDE')]:
        states[f'{index}-GUN-{name}-fixture']=dict(states['02-flight'],HUD_MODE=5,
            F22_ACM_MODE=acm,F22_RADAR_MODE_TEXT=name,RADAR_PWR=1,HUD_ARMED=1)
    states['17-GUN-native-sight-fixture']=dict(states['02-flight'],HUD_MODE=5,
        RADAR_FIXTURE=3,F22_RADAR_MODE_TEXT='STT',RADAR_PWR=1,HUD_ARMED=1,
        HUD_GUN_NATIVE_VALID=1,HUD_GUN_NATIVE_AZ=.025,HUD_GUN_NATIVE_EL=-.015,
        HUD_GUN_READY=1)
    for suffix,rounds in [('full',480),('partial',326),('empty',0)]:
        states['17-GUN-ammo-'+suffix]=dict(states['17-GUN-native-sight-fixture'],
            F22_GUN_AMMO_VALID=1,F22_GUN_AMMO_COUNT=rounds)
if args.radar:
    for name,backend,available,locked,count in [('18-IR-backend-unavailable',0,0,0,2),('19-IR-searching',1,1,0,2),('20-IR-tracking',1,1,1,2),('21-IR-empty-station',1,0,0,0)]:
        states[name]=dict(states['02-flight'],HUD_MODE=3,RADAR_PWR=1,HUD_ARMED=1,
            HUD_IR_BACKEND_READY=backend,HUD_IR_SEEKER_AVAILABLE=available,
            HUD_IR_SEEKER_VALID=locked,F22_WEAPON_COUNT=count,
            HUD_IR_SEEKER_AZ=.035 if locked else 0,HUD_IR_SEEKER_EL=-.02 if locked else 0)
if args.radar:
    states['22-TWS-designated']=dict(states['02-flight'],HUD_MODE=2,RADAR_FIXTURE=1,
        F22_RADAR_DESIGNATION_VALID=1,F22_RADAR_DESIGNATION_RANGE=18520,
        F22_RADAR_DESIGNATION_AZ=.06,F22_RADAR_DESIGNATION_EL=-.03,F22_RADAR_DESIGNATION_AGE=0)
    states['23-TWS-coasting']=dict(states['22-TWS-designated'],F22_RADAR_DESIGNATION_AGE=2)
    for index,name,az,el in [(24,'right',30,0),(25,'left',-30,0),(26,'up',0,25),(27,'down',0,-30)]:
        states[f'{index}-STT-off-HUD-{name}']=dict(states['12-STT-sensor-fixture'],
            F22N_RADAR_STT_AZIMUTH=math.radians(az),F22N_RADAR_STT_ELEVATION=math.radians(el))
    states['28-MRM-stale-VACQ-suppressed']=dict(states['02-flight'],HUD_MODE=2,F22_ACM_MODE=2,RADAR_PWR=1)
if args.radar:
    states['32-EW-bearing-repeater']=dict(states['02-flight'],EW_FIXTURE=True)
    states['33-TWS-primary-secondary']=dict(states['22-TWS-designated'],F22_RADAR_SECONDARY_VALID=1,
        F22_RADAR_SECONDARY_RANGE=22000,F22_RADAR_SECONDARY_AZ=-.08,F22_RADAR_SECONDARY_EL=.025)
if args.radar:
    for code,label in [(1,'shoot-window'),(2,'outside-window'),(3,'time-to-active'),(4,'active-time-to-go')]:
        states[f'34-{code}-MRM-{label}']=dict(states['22-TWS-designated'],ENGAGEMENT_FIXTURE=code,F22_WEAPON_COUNT=5,
            F22_RADAR_DESIGNATION_RANGE=60000 if code==2 else 12000,F22_RADAR_DESIGNATION_AZ=.025,F22_RADAR_DESIGNATION_EL=-.015)
states={name:flight_outputs(params) for name,params in states.items()}

def controller_state(e, params):
    x,y = (e.get('init_pos') or [0,0])[:2]
    rotation = 0
    alpha = 1
    text = e.get('value', '')
    fields = e.get('element_params') or []
    for controller in e.get('controllers', []):
        name, *values = controller
        value = params.get(fields[int(values[0])],0) if fields and values else 0
        if name == 'opacity_using_parameter': alpha *= max(0,min(1,value))
        elif name == 'parameter_in_range': alpha *= int(values[1] <= value <= values[2])
        elif name == 'move_left_right_using_parameter': x += value*values[1]
        elif name == 'move_up_down_using_parameter': y += value*values[1]
        elif name == 'rotate_using_parameter': rotation += value*values[1]
        elif name == 'text_using_parameter': text = e['formats'][int(values[1])] % value
        else: raise ValueError('Unsupported controller: '+name)
    return x,y,rotation,alpha,text

def draw_state(name, params):
    image = Image.new('RGBA',(W,H),(6,16,22,255))
    bg = ImageDraw.Draw(image)
    roll=params.get('ADIROLL',0)
    # ADI horizon normalized to the HUD nose reference, using the same camera
    # projection as the strokes. It reads the raw ADI sensor pose, not HUD_ROLL.
    pitch=params.get('ADIPITCH',0)
    horizon_y=layout['boresight_y']*layout['angular_scale']-pitch/max(0.1,math.cos(roll))
    left_horizon=angular_pixel(-2,horizon_y-2*math.tan(roll))
    right_horizon=angular_pixel(2,horizon_y+2*math.tan(roll))
    bg.polygon((left_horizon,right_horizon,(W*3,H*3),(-W*2,H*3)),fill=(21,25,22,255))
    bg.line((*left_horizon,*right_horizon),fill=(55,65,68,255),width=SUPERSAMPLE)
    clip=Image.new('L',(W,H))
    clip_draw=ImageDraw.Draw(clip)
    for i in range(0,len(glass_indices),3):
        clip_draw.polygon([glass_points[j] for j in glass_indices[i:i+3]],fill=255)
    # Actual EDM glass silhouette, not an invented rounded rectangle.
    from PIL import ImageFilter,ImageChops
    small_clip=clip.resize((W//SUPERSAMPLE,H//SUPERSAMPLE),Image.Resampling.LANCZOS)
    border=ImageChops.subtract(small_clip.filter(ImageFilter.MaxFilter(13)),small_clip)
    border=border.resize((W,H),Image.Resampling.BICUBIC)
    frame=Image.new('RGBA',(W,H),(48,64,68,255)); frame.putalpha(border)
    image.alpha_composite(frame)
    caption_font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',10*SUPERSAMPLE)
    bg.text((30*SUPERSAMPLE,25*SUPERSAMPLE),'LUA HUD PREVIEW  /  '+name.upper(),font=caption_font,fill=(155,177,187))
    bg.text((30*SUPERSAMPLE,45*SUPERSAMPLE),'Actual Lua + own SVG strokes + EDM glass; optical compositor still needs native verification.',font=caption_font,fill=(108,130,140))
    layer = Image.new('RGBA',(W,H))
    draw = ImageDraw.Draw(layer)
    stencil_stack=[]
    resolved = {}
    def resolve(e):
        if e['name'] in resolved: return resolved[e['name']]
        x,y,angle,alpha,text = controller_state(e,params)
        if e.get('parent_element'):
            px,py,pa,palpha,_ = resolve(lookup[e['parent_element']])
            x,y = px+x*math.cos(pa)-y*math.sin(pa),py+x*math.sin(pa)+y*math.cos(pa)
            angle += pa
            alpha *= palpha
        resolved[e['name']] = x,y,angle,alpha,text
        return resolved[e['name']]
    for e in elements:
        x,y,angle,alpha,text = resolve(e)
        relation=e.get('h_clip_relation')
        if e.get('isvisible') is False and relation==4:
            region=Image.new('L',(W,H))
            region_draw=ImageDraw.Draw(region)
            points=[]
            for point in e['vertices']:
                vx,vy=point[:2]
                points.append(angular_pixel(x+vx*math.cos(angle)-vy*math.sin(angle),
                    y+vx*math.sin(angle)+vy*math.cos(angle)))
            for start in range(0,len(e['indices']),3):
                region_draw.polygon([points[i] for i in e['indices'][start:start+3]],fill=255)
            stencil_stack.append((layer,region))
            layer=Image.new('RGBA',(W,H));draw=ImageDraw.Draw(layer)
            continue
        if e.get('isvisible') is False and relation==6:
            parent,region=stencil_stack.pop()
            layer.putalpha(ImageChops.multiply(layer.getchannel('A'),region))
            parent.alpha_composite(layer)
            layer=parent;draw=ImageDraw.Draw(layer)
            continue
        if not alpha or e.get('isvisible') is False: continue
        color = (*GREEN[:3],round(alpha*255))
        if e['kind']=='ceMeshPoly':
            points=[]
            for point in e['vertices']:
                vx,vy=point[:2]
                px=x+vx*math.cos(angle)-vy*math.sin(angle)
                py=y+vx*math.sin(angle)+vy*math.cos(angle)
                points.append(angular_pixel(px,py))
            indices=e['indices']
            for start in range(0,len(indices),3):
                draw.polygon([points[i] for i in indices[start:start+3]],fill=color)
        elif e['kind']=='ceStringSLine' and text:
            gh=e['stringdefs'][0]/FONT_DISTANCE*FOCAL
            gw=e['stringdefs'][1]/FONT_DISTANCE*FOCAL
            spacing=e['stringdefs'][2]/FONT_DISTANCE*FOCAL
            width=len(text)*gw+max(0,len(text)-1)*spacing
            alignment=e.get('alignment','CenterCenter')
            left=-width/2 if alignment=='CenterCenter' else -width if alignment=='RightCenter' else 0
            anchor_x,anchor_y=angular_pixel(x,y)
            for index,char in enumerate(text):
                if char==' ':continue
                paths=stroke_paths[stroke_ids[ord(char)]]
                all_points=[p for path in paths for p in path]
                minx,maxx=min(p[0] for p in all_points),max(p[0] for p in all_points)
                miny,maxy=min(p[1] for p in all_points),max(p[1] for p in all_points)
                centerx,centery=(minx+maxx)/2,(miny+maxy)/2
                for path in paths:
                    points=[]
                    for gx,gy in path:
                        dx=left+index*(gw+spacing)+gw/2+(gx-centerx)*gw/12
                        dy=(gy-centery)*gh/20
                        points.append((anchor_x+dx*math.cos(angle)+dy*math.sin(angle),
                            anchor_y-dx*math.sin(angle)+dy*math.cos(angle)))
                    if len(points)>1:draw.line(points,fill=color,width=SUPERSAMPLE,joint='curve')
        elif e['kind']=='ceStringPoly' and text:
            # DCS font metrics are separate from angular element coordinates.
            # Use one consistent atlas-metric conversion for every label.
            gh=max(1,round(e['stringdefs'][0]*FOCAL*2.7))
            gw=max(1,round(gh*141/256))
            strip=Image.new('RGBA',(max(1,len(text)*gw),gh))
            for index,char in enumerate(text):
                if char not in glyphs: raise ValueError('Missing HUD glyph: '+repr(char))
                glyph=glyphs[char].resize((gw,gh),Image.Resampling.LANCZOS)
                ink=Image.new('RGBA',glyph.size,color)
                ink.putalpha(glyph.getchannel('A').point(lambda a:round(a*alpha)))
                strip.alpha_composite(ink,(index*gw,0))
            if angle: strip=strip.rotate(math.degrees(angle),expand=True,resample=Image.Resampling.BICUBIC)
            layer.alpha_composite(strip,(round(CX+x*FOCAL-strip.width/2),round(CY-y*FOCAL-strip.height/2)))
    from PIL import ImageChops
    assert not stencil_stack, 'Unclosed HUD stencil window'
    layer.putalpha(ImageChops.multiply(layer.getchannel('A'),clip))
    image=Image.alpha_composite(image,layer)
    image=image.resize((W//SUPERSAMPLE,H//SUPERSAMPLE),Image.Resampling.LANCZOS)
    image.convert('RGB').save(args.output/(name+'.png'))
    return image

images=[draw_state(name,params) for name,params in states.items()]
iw,ih=images[0].size
sheet=Image.new('RGB',(iw*3,ih*math.ceil(len(images)/3)))
for index,image in enumerate(images): sheet.paste(image,(index%3*iw,index//3*ih))
sheet.save(args.output/'HUD-contact-sheet.png')
print('Rendered',len(elements),'Lua elements in',len(states),'states to',args.output)

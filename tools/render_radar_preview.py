"""Actual Lua + native atlas rasterizer; synthetic sensor fixtures, no DCS required.

Optional cockpit composite fits this rendered page into a previously captured
DCS LCD quadrilateral. It is labelled as a composite, never a native capture.
"""
from pathlib import Path
import argparse,runpy,re,math
import xml.etree.ElementTree as ET
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,default=ROOT.parent/'Radar-Previews'/'TopMach-Style')
parser.add_argument('--ufd',action='store_true',help='Render upper-left compact EW page')
parser.add_argument('--aspect',type=float,default=1.0)
parser.add_argument('--rwr',action='store_true',help='Render the independent right-MFD EW page')
parser.add_argument('--attack',action='store_true',help='Render the left selected-engagement detail page')
parser.add_argument('--tactical',action='store_true',help='Add explicit synthetic NAV and uncorrelated passive observations for TSD QA')
parser.add_argument('--dense-tactical',action='store_true',help='Exercise close-bearing passive declutter using distinct synthetic source IDs')
parser.add_argument('--reference',type=Path)
parser.add_argument('--native-scale',type=float,default=.1)
parser.add_argument('--cockpit',type=Path)
args=parser.parse_args();OUT=args.output;OUT.mkdir(parents=True,exist_ok=True)
if args.dense_tactical:args.tactical=True
runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.globals().radar_native_scale=args.native_scale
lua.globals().preview_rwr=args.rwr
lua.globals().preview_attack=args.attack
lua.globals().preview_ufd=args.ufd
lua.globals().preview_aspect=args.aspect
lua.execute('''
    function GetScale() return radar_native_scale end
    function GetAspect() return preview_aspect end
    resource_colors={};local material_count=0
    function MakeMaterial(_,c)
        material_count=material_count+1;local name='material-'..material_count
        resource_colors[name]=c;return name
    end
    function MakeFont(_,c,name) resource_colors[name]=c;return name end
    local old_dofile=dofile
    function dofile(path)
        if path==SCRIPT_ROOT..'fonts.lua' then return assert(loadfile(path))() end
        return old_dofile(path)
    end
    dofile(SCRIPT_ROOT..(preview_attack and 'MFD_LEFT/attack_page.lua' or preview_ufd and 'UFD_LEFT/ew_page.lua' or preview_rwr and 'MFD_RIGHT/rwr_page.lua' or 'PMFD_CENTER/radar_page.lua'))
    if not preview_ufd then dofile(SCRIPT_ROOT..(preview_attack and 'MFD_LEFT/sensor_control.lua' or preview_rwr and 'MFD_RIGHT/sensor_control.lua' or 'PMFD_CENTER/sensor_control.lua')) end
''')
def convert(v):
    if hasattr(v,'items'):
        items=list(v.items())
        if items and all(isinstance(k,int) for k,_ in items): return [convert(v[k]) for k in sorted(v)]
        return {k:convert(x) for k,x in items}
    return v
elements=convert(lua.globals().elements);lookup={e['name']:e for e in elements}
colors=convert(lua.globals().resource_colors)
# Preview output is sRGB. A/A native resources are linear; use their authored
# display values here rather than pretending raw native bytes are image RGB.
aa_palette=lua.execute("return dofile(SCRIPT_ROOT..'MFD_COMMON/radar_palette.lua')")
for name,color in aa_palette['srgb'].items():
    colors[aa_palette['line'](name)]=convert(color)
    colors[aa_palette['font'](name)]=convert(color)
radar_colors={'WHITE':[240,247,246,255],'BLUE':[113,188,240,255],
    'GREEN':[0,255,0,255],'YELLOW':[255,220,64,255],'RED':[255,78,78,255],'MAGENTA':[235,80,211,255]}
for name,color in radar_colors.items():
    colors['F22_RDR_'+name]=color;colors['F22_RDR_FONT_'+name]=color
colors.update({'PFD_FONT':[0,255,0,255],'UFD_FONT':[255,255,255,255],'UFD_FONT_YELLOW':[255,255,0,255],'UFD_FONT_RED':[255,0,0,255]})
font_def=lua.execute('return dofile(SCRIPT_ROOT.."HUD/font.lua")')
# Use the same original SVG storage parser as the HUD preview.
font_parser=(ROOT/'tools/render_hud_preview.py').read_text()
exec(font_parser[font_parser.index('stroke_ids='):font_parser.index('def project_vector')])

atlas=Image.open(ROOT/'Cockpit/Scripts/IndicationTextures/FONT_PFD.dds').convert('RGBA')
source=(ROOT/'Cockpit/Scripts/fonts.lua').read_text().split('local F22_PFD =',1)[1].split('F18_xsize',1)[0]
glyphs={}
for index,code in re.findall(r'\[(\d+)\]\s*=\s*\{(\d+),\s*141,\s*256\}',source):
    i=int(index)-1;glyphs[chr(int(code))]=atlas.crop(((i%8)*256,(i//8)*256,(i%8)*256+141,(i//8)*256+256))
SS=3;S=900;PIX=S*SS;F=PIX/2
caption=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20)
images=[];screens={}
for mode,command,locked in [('RWS',10601,False),('TWS',10602,False),('STT',10602,True),('VACQ',10604,False),('BORE',10605,False),('IFF',10602,False),('BVR-launches',10602,False),('RWS-scan-controls',10601,False)]:
    sim=runtime()
    sim.execute('''
        function get_base_data() return {
            getSelfCoordinates=function() return 0,1500,0 end,
            getHeading=function() return -math.rad(271) end,
            getPitch=function() return 0 end,getRoll=function() return 0 end,
        } end
        native={set_power=function() end};function GetDevice(_) return native end
        dofile(SCRIPT_ROOT..'Systems/Radar_System.lua')
        dofile(SCRIPT_ROOT..'../../tests/radar_body_fixture.lua');post_initialize()
    ''')
    def put(n,v): p=sim.globals().get_param_handle(n);p.set(p,v)
    put('MAIN_POWER',1);put('F22N_RADAR_MODE',1)
    put('EFM_HUD_VALID',1);put('EFM_HUD_VN',200*math.cos(math.radians(271)))
    put('EFM_HUD_VE',200*math.sin(math.radians(271)));put('EFM_HUD_VU',0)
    for n,v in dict(HUD_WP_VALID=1,HUD_WP_BRG_VALID=1,HUD_WP_RANGE_NM=8,
        HUD_WP_BEARING_DEG=304,HUD_WP_INDEX=2).items():put(n,v)
    sim.globals().SetCommand(10600,1);sim.globals().SetCommand(command,1)
    if mode not in ('VACQ','BORE'):
        sim.globals().SetCommand(10608,1);sim.globals().SetCommand(10608,1)
        sim.globals().SetCommand(10617,1)
    if mode=='RWS-scan-controls':
        for c in (10616,10616,10623,10614,10614,10614):sim.globals().SetCommand(c,1)
    fixtures=[(8*1852,-12,5364,1),(7*1852,-12,5382,1),(4.5*1852,-8,6410,1)]
    if mode=='IFF':fixtures=[(10*1852,-28,5364,1),(7*1852,5,5382,-1),(11*1852,32,6410,0),(3.5*1852,-35,5200,2)]
    if mode in ('VACQ','BORE'):fixtures=[(3*1852,0,5364,-1)]
    for i,(r,az,alt_ft,iff) in enumerate(fixtures,1):
        el=math.asin((alt_ft/3.280839895-1500)/r)
        for suffix,v in dict(RANGE=r,AZIMUTH=math.radians(az),ELEVATION=el,TIME=0,
            FRIENDLY=iff,VX=0,VY=0,VZ=-170).items():put(f'F22N_RADAR_CONTACT_{i:02}_{suffix}',v)
    for _ in range(3):sim.globals().update()
    if mode in ('TWS','STT'):sim.globals().SetCommand(10618,1);sim.globals().update()
    if locked:
        put('F22N_RADAR_MODE',3);put('F22N_RADAR_STT_RANGE',fixtures[0][0])
        put('F22N_RADAR_STT_AZIMUTH',math.radians(fixtures[0][1]))
        put('F22N_RADAR_STT_ELEVATION',math.asin((5364/3.280839895-1500)/fixtures[0][0]))
        put('F22N_RADAR_STT_FRIENDLY',1)
        sim.globals().update()
    sim.execute('saved_radar_update=update; saved_radar_command=SetCommand')
    # Explicit synthetic native-RWR inputs, processed by the actual device owner.
    for i,(source,az,signal,label) in enumerate([(1001,-25,1,'29'),(1002,70,2,'15'),(1003,155,3,'M')],1):
        for suffix,v in dict(SOURCE=source,TIME=0,AZIMUTH=math.radians(az),SIGNAL=signal,UNIT_TYPE=label,PRIORITY=signal*100).items():
            put(f'RWR_CONTACT_{i:02}_{suffix}',v)
    sim.execute("dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();update()")
    sim.execute('saved_rwr_update=update')
    if args.rwr:
        sim.execute("dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize();update()")
    sim.globals().saved_radar_update()
    if mode=='TWS':
        sim.globals().saved_radar_command(10611,1)
        sim.globals().saved_radar_command(10611,1)
        sim.globals().saved_radar_command(10628,1)
        sim.globals().saved_radar_update()
    if mode=='BVR-launches':
        sim.globals().saved_radar_command(10618,1)
        sim.globals().saved_radar_update()
        sim.execute("""
            local function p(n,v)get_param_handle(n):set(v)end
            for n,v in pairs({HUD_MODE=2,MASTER_ARM=1,F22_WEAPON_COUNT=4,F22_RADAR_WEAPON_TARGET_ID=1001,
                F22_RADAR_OBSERVATIONS_READY=1,F22_RADAR_OBSERVATION_COUNT=2,F22_MISSILE_DATA_VALID=1,
                F22_MISSILE_NATIVE_MIN=700,F22_MISSILE_NATIVE_MAX=38490,F22_MISSILE_LIFETIME=90,
                F22_DLZ_NATIVE_VALID=1,F22_DLZ_TARGET_ID=1001,F22_DLZ_RMIN=700,F22_DLZ_RMAX=32457,F22_DLZ_RTR=11037,
                F22_LAUNCH_SEQUENCE=2})do p(n,v)end
            for i=1,2 do
                local q=string.format('F22O_%02d_',i);local m=string.format('F22_SHOT_%02d_',i)
                -- Retain the exact synthetic sensor points plotted by the radar.
                for n,v in pairs({SEQUENCE=i,ID=2000+i,TARGET=1000+i,MODE=2,ALIVE=1,N=6000,U=1500,E=(i==1 and -1200 or 1600),VN=800,ACTIVE_RANGE=4000,ACTIVE=i-1,ACTIVE_VALID=1,SEEKER_VALID=1,SEEKER_TRACK=i-1})do p(m..n,v)end
            end
            dofile(SCRIPT_ROOT..'Systems/Engagement_System.lua');post_initialize();update()
        """)
    if args.tactical:
        sim.globals().dense_tactical=args.dense_tactical
        sim.execute('''
            local function p(n,v)get_param_handle(n):set(v)end
            local now=get_model_time()
            -- Synthetic native optical input, consumed by the actual owner.
            p('F22_MWS_NATIVE_READY',1);p('F22_MWS_NATIVE_TIME',now)
            for k,v in pairs({VALID=1,SOURCE=5005,TIME=now,AZ=-.9,EL=.1})do p('F22_MWS_NATIVE_01_'..k,v)end
            dofile(SCRIPT_ROOT..'Systems/MWS_System.lua');post_initialize();update()
            for k,v in pairs({SOURCE=4004,TIME=0,AZIMUTH=.6,ELEVATION=0,SIGNAL=2,GENERAL_TYPE=1,UNIT_TYPE='16'})do p('RWR_CONTACT_04_'..k,v)end
            if dense_tactical then
                for i=5,16 do
                    for k,v in pairs({SOURCE=4000+i,TIME=0,AZIMUTH=.6+(i-4)*.005,ELEVATION=0,SIGNAL=2,GENERAL_TYPE=1,UNIT_TYPE='16'})do
                        p(string.format('RWR_CONTACT_%02d_',i)..k,v)
                    end
                end
            end
            -- Synthetic NAV producer contract, not a recovered mission route.
            local h=math.rad(271)
            for k,v in pairs({SOURCE=0,VALID=1,OWN_VALID=1,STEER_VALID=1,STEER_STAMP=now,SCALE_NM=40,
                COMPASS_ROT=h,OWN_N=0,OWN_E=0,TARGET_N=1852*(12*math.cos(h)-4*math.sin(h)),
                TARGET_E=1852*(12*math.sin(h)+4*math.cos(h))})do p('F22_NAV_'..k,v)end
            p('HUD_WP_INDEX',3)
            for k,v in pairs({VALID=1,ACTIVE=1,X1=-.08,Y1=.02,X2=.056,Y2=.168})do p('F22_NAV_LEG_01_'..k,v)end
            saved_rwr_update()
        ''')
    params={k:v.value for k,v in sim.globals().handles.items()};params.update(MFD_OPACITY=1,PMFD_RDR_PAGE=1,RMFD_RWR_PAGE=1,LMFD_SMS_PAGE=1,F22_UFD_EW_PAGE=1,UFD_OPACITY=1,F22_SOI=3 if args.attack else 4 if args.rwr else 2)
    cache={}
    def resolve(e):
        if e['name'] in cache:return cache[e['name']]
        x,y=(e.get('init_pos') or [0,0])[:2];angle=0;alpha=1;text=e.get('value','')
        fields=e.get('element_params',[])
        for c in e.get('controllers',[]):
            v=params.get(fields[c[1]],0)
            if c[0]=='opacity_using_parameter':alpha*=v
            elif c[0]=='parameter_in_range':alpha*=int(c[2]<v<c[3])
            elif c[0]=='move_left_right_using_parameter':x+=v*c[2]/args.native_scale
            elif c[0]=='move_up_down_using_parameter':y+=v*c[2]/args.native_scale
            elif c[0]=='rotate_using_parameter':angle+=v*c[2]
            elif c[0]=='text_using_parameter':text=e['formats'][c[2]]%v
            elif c[0]=='line_object_set_point_using_parameters':pass  # vertices resolved below
            elif c[0]=='change_color_when_parameter_equal_to_number':
                if abs(v-c[2])<1e-6:e['_preview_color']=tuple(round(255*n)for n in c[3:6])
            else:raise ValueError('Unimplemented renderer controller: '+str(c))
        if e.get('parent_element'):
            px,py,pa,pt,_=resolve(lookup[e['parent_element']])
            x,y=px+x*math.cos(pt)-y*math.sin(pt),py+x*math.sin(pt)+y*math.cos(pt)
            alpha*=pa;angle+=pt
        cache[e['name']]=(x,y,alpha,angle,text);return cache[e['name']]
    im=Image.new('RGB',(PIX,PIX),(0,0,0));draw=ImageDraw.Draw(im)
    def pixel(x,y):return (F+x*F,F-y*F)
    for e in elements:
        x,y,a,angle,text=resolve(e)
        if a<=0 or e.get('isvisible') is False:continue
        rgba=colors.get(e.get('material'),[240,247,246,255]);color=e.get('_preview_color',tuple(round(c) for c in rgba[:3]))
        ca,sa=math.cos(angle),math.sin(angle)
        if e['kind']=='ceMeshPoly':
            vs=e['vertices'];idx=e['indices']
            for i in range(0,len(idx),3):
                points=[pixel(x+vs[k][0]*ca-vs[k][1]*sa,y+vs[k][0]*sa+vs[k][1]*ca) for k in idx[i:i+3]]
                draw.polygon(points,fill=color)
        elif e['kind']=='ceSimpleLineObject':
            vs={};fields=e['element_params']
            for c in e['controllers']:
                if c[0]=='line_object_set_point_using_parameters':
                    vs[c[1]]=(params.get(fields[c[2]],0)*c[4]/args.native_scale,
                              params.get(fields[c[3]],0)*c[5]/args.native_scale)
            points=[pixel(x+vx*ca-vy*sa,y+vx*sa+vy*ca) for _,(vx,vy) in sorted(vs.items())]
            if len(points)==2:draw.line(points,fill=color,width=max(1,round(e['width']/args.native_scale*F)))
        elif e['kind']=='ceSMultiLine':
            vs=e['vertices'];idx=e['indices']
            for i in range(0,len(idx),2):
                draw.line([pixel(x+vs[k][0]*ca-vs[k][1]*sa,y+vs[k][0]*sa+vs[k][1]*ca) for k in idx[i:i+2]],fill=color,width=max(1,round(SS*e.get('thickness',.8))))
        elif e['kind']=='ceStringSLine' and text:
            gh=e['stringdefs'][0]/args.native_scale*F;gw=e['stringdefs'][1]/args.native_scale*F
            spacing=e['stringdefs'][2]/args.native_scale*F
            total=len(text)*gw+max(0,len(text)-1)*spacing;ax,ay=pixel(x,y)
            for index,char in enumerate(text):
                if char==' ':continue
                paths=stroke_paths[stroke_ids[ord(char)]]
                points=[p for path in paths for p in path]
                cx=(min(p[0] for p in points)+max(p[0] for p in points))/2
                cy=(min(p[1] for p in points)+max(p[1] for p in points))/2
                for path in paths:
                    points=[]
                    for gx,gy in path:
                        dx=-total/2+index*(gw+spacing)+gw/2+(gx-cx)*gw/12;dy=(gy-cy)*gh/20
                        points.append((ax+dx*ca+dy*sa,ay-dx*sa+dy*ca))
                    if len(points)>1:draw.line(points,fill=color,width=SS,joint='curve')
        elif e['kind']=='ceStringPoly' and text:
            height=round(e['stringdefs'][0]/args.native_scale*F);width=round(height*141/256)
            strip=Image.new('RGBA',(max(1,len(text)*width),height))
            for i,ch in enumerate(text):
                if ch==' ':continue
                if ch not in glyphs:raise ValueError(f'Missing actual MFD glyph {ch!r}')
                glyph=glyphs[ch].resize((width,height),Image.Resampling.LANCZOS)
                ink=Image.new('RGBA',glyph.size,color);ink.putalpha(glyph.getchannel('A'));strip.alpha_composite(ink,(i*width,0))
            if angle:strip=strip.rotate(math.degrees(angle),expand=True,resample=Image.Resampling.BICUBIC)
            px,py=pixel(x,y)
            alignment=e.get('alignment','CenterCenter')
            left=px if alignment.startswith('Left') else px-strip.width if alignment.startswith('Right') else px-strip.width/2
            im.paste(strip,(round(left),round(py-strip.height/2)),strip)
    im=im.resize((S,S),Image.Resampling.LANCZOS);screens[mode]=im
    im.save(OUT/f'{mode}-screen.png')
    titled=Image.new('RGB',(S,S+50),(5,14,20));titled.paste(im,(0,50))
    title=f'{"EW / " if args.rwr else ""}{mode}: ACTUAL LUA + SHIPPED FONT / SYNTHETIC SENSOR FIXTURE'
    if mode=='IFF':title='IFF FIXTURE: POSITIVE FRIEND GREEN / ALL NONREPLIES UNKNOWN YELLOW'
    ImageDraw.Draw(titled).text((18,15),title,font=caption,fill=(170,192,201))
    titled.save(OUT/f'{mode}.png');images.append(titled)
sheet=Image.new('RGB',(S*3,(S+50)*math.ceil(len(images)/3)),(5,14,20))
for i,im in enumerate(images):sheet.paste(im,(i%3*S,i//3*(S+50)))
sheet.save(OUT/'radar-contact-sheet.png')
if args.reference:
    reference=Image.open(args.reference).convert('RGB')
    reference.thumbnail((S,S),Image.Resampling.LANCZOS)
    comparison=Image.new('RGB',(S*2,S+70),(5,14,20));d=ImageDraw.Draw(comparison)
    d.text((18,18),'TOP MACH MANUAL - VISUAL REFERENCE',font=caption,fill='white')
    d.text((S+18,18),'OUR ACTUAL LUA PAGE - SENSOR FIXTURE',font=caption,fill='white')
    comparison.paste(reference,((S-reference.width)//2,70+(S-reference.height)//2))
    comparison.paste(screens['TWS'],(S,70));comparison.save(OUT/'reference-comparison.png')
if args.cockpit:
    base=Image.open(args.cockpit).convert('RGB')
    assert base.size==(3440,1440),'Cockpit fit is calibrated only to this native capture size'
    quad=[(1576,1060),(1868,1060),(1874,1352),(1568,1352)]
    # Inverse homography from native LCD pixel coordinates to rendered page.
    matrix=[]
    for (x,y),(u,v) in zip(quad,[(0,0),(S,0),(S,S),(0,S)]):
        matrix.extend([[x,y,1,0,0,0,-u*x,-u*y,u],[0,0,0,x,y,1,-v*x,-v*y,v]])
    for c in range(8):
        pivot=max(range(c,8),key=lambda r:abs(matrix[r][c]));matrix[c],matrix[pivot]=matrix[pivot],matrix[c]
        f=matrix[c][c];matrix[c]=[v/f for v in matrix[c]]
        for r in range(8):
            if r!=c:
                f=matrix[r][c];matrix[r]=[v-f*w for v,w in zip(matrix[r],matrix[c])]
    coefficients=[matrix[r][8] for r in range(8)]
    warp=screens['TWS'].transform(base.size,Image.Transform.PERSPECTIVE,coefficients,Image.Resampling.BICUBIC)
    mask=Image.new('L',base.size);ImageDraw.Draw(mask).polygon(quad,fill=255)
    base.paste(warp,(0,0),mask)
    d=ImageDraw.Draw(base);d.rectangle((1450,985,1960,1030),fill=(5,14,20))
    d.text((1456,992),'OFFLINE LCD COMPOSITE - NOT NATIVE RENDER',font=caption,fill='white')
    base.save(OUT/'cockpit-fit-composite.png')
    base.crop((1400,960,2020,1430)).resize((1240,940),Image.Resampling.LANCZOS).save(OUT/'cockpit-fit-detail.png')
print('Rendered',len(elements),'actual Lua elements in',len(images),'states to',OUT)

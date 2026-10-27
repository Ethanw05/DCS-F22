"""Actual NAV Lua + shipped LCD atlas. Fixtures are not native flight evidence."""
from pathlib import Path
import math,re,sys
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_display_startup import runtime
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT.parents[1]/'work/navigation-preview'
OUT.mkdir(parents=True,exist_ok=True)
def convert(v):
    if hasattr(v,'items'):
        items=list(v.items())
        if items and all(isinstance(k,int)for k,_ in items):return[convert(v[k])for k in sorted(v)]
        return{k:convert(x)for k,x in items}
    return v
atlas=Image.open(ROOT/'Cockpit/Scripts/IndicationTextures/FONT_PFD.dds').convert('RGBA')
source=(ROOT/'Cockpit/Scripts/fonts.lua').read_text().split('local F22_PFD =',1)[1].split('F18_xsize',1)[0]
glyphs={}
for index,code in re.findall(r'\[(\d+)\]\s*=\s*\{(\d+),\s*141,\s*256\}',source):
    i=int(index)-1;glyphs[chr(int(code))]=atlas.crop(((i%8)*256,(i//8)*256,(i%8)*256+141,(i//8)*256+256))
screens=[];S=900;SS=3;F=S*SS/2;native_scale=.1
for name,setup in [('route-north',''),('route-east','own.h=-math.pi/2'),
        ('direct-to','own.e=6000;SetCommand(10835,1)'),
        ('range-10nm','SetCommand(10833,1);SetCommand(10833,1)'),
        ('no-route','route={route[1]};SetCommand(10836,1)'),
        ('final-arrived','SetCommand(10830,1);SetCommand(10830,1);SetCommand(10832,1);own.n=18520;own.e=-18520')]:
    sim=runtime();sim.execute('''
        function GetScale()return .1 end
        function GetAspect()return 1 end
        resource_colors={};local seq=0
        function MakeMaterial(_,c)seq=seq+1;local n='nav-material-'..seq;resource_colors[n]=c;return n end
        own={n=0,e=0,alt=3000,h=0}
        function get_base_data()return {getSelfCoordinates=function()return own.n,own.alt,own.e end,
            getHeading=function()return own.h end,getPitch=function()return 0 end,getRoll=function()return 0 end}end
        route={{x=0,y=0,alt=3000},{x=27780,y=3704,alt=3000,name='INGRESS'},
            {x=46300,y=22224,alt=5000,name='TURN EAST'},{x=18520,y=-18520,alt=2000,name='RECOVERY'}}
        function get_mission_route()return route end
        get_param_handle('MAIN_POWER'):set(1)
        dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize();update()
        dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize()
        get_param_handle('MAIN_POWER'):set(1);get_param_handle('HUD_GS_VALID'):set(1);get_param_handle('HUD_GS_MPS'):set(200)
    ''')
    sim.execute(setup+'\nupdate()')
    sim.execute("dofile(SCRIPT_ROOT..'MFD_LEFT/hsi_page.lua')")
    elements=convert(sim.globals().elements);lookup={e['name']:e for e in elements};colors=convert(sim.globals().resource_colors)
    colors.update({'test-white-font':[240,247,246,255],'test-blue-font':[113,188,240,255],'test-font':[0,255,0,255]})
    params={k:v.value for k,v in sim.globals().handles.items()};params.update(MFD_OPACITY=1,LMFD_HSI_PAGE=1)
    cache={}
    def resolve(e):
        if e['name'] in cache:return cache[e['name']]
        x,y=(e.get('init_pos')or[0,0])[:2];angle=0;alpha=1;text=e.get('value','');vertices=[list(p)for p in e.get('vertices',[])]
        fields=e.get('element_params',[])
        for c in e.get('controllers',[]):
            if c[0]=='line_object_set_point_using_parameters':
                vertices[c[1]]=[params.get(fields[c[2]],0)*c[4]/native_scale,params.get(fields[c[3]],0)*c[5]/native_scale];continue
            v=params.get(fields[c[1]],0)
            if c[0]=='opacity_using_parameter':alpha*=v
            elif c[0]=='parameter_in_range':alpha*=int(c[2]<v<c[3])
            elif c[0]=='move_left_right_using_parameter':x+=v*c[2]/native_scale
            elif c[0]=='move_up_down_using_parameter':y+=v*c[2]/native_scale
            elif c[0]=='rotate_using_parameter':angle+=v*c[2]
            elif c[0]=='text_using_parameter':text=e['formats'][c[2]]%v
            else:raise ValueError(c)
        if e.get('parent_element'):
            px,py,pa,pt,_,_=resolve(lookup[e['parent_element']]);x,y=px+x*math.cos(pt)-y*math.sin(pt),py+x*math.sin(pt)+y*math.cos(pt);alpha*=pa;angle+=pt
        cache[e['name']]=(x,y,alpha,angle,text,vertices);return cache[e['name']]
    im=Image.new('RGB',(S*SS,S*SS),(3,3,12));draw=ImageDraw.Draw(im)
    def pixel(x,y):return(F+x*F,F-y*F)
    for e in elements:
        x,y,a,angle,text,vertices=resolve(e)
        if a<=0 or e.get('isvisible')is False:continue
        color=tuple(colors.get(e.get('material'),[240,247,246,255])[:3]);ca,sa=math.cos(angle),math.sin(angle)
        pts=[pixel(x+v[0]*ca-v[1]*sa,y+v[0]*sa+v[1]*ca)for v in vertices]
        if e['kind']=='ceMeshPoly':
            for i in range(0,len(e['indices']),3):draw.polygon([pts[k]for k in e['indices'][i:i+3]],fill=color)
        elif e['kind']=='ceSMultiLine':
            for i in range(0,len(e['indices']),2):draw.line([pts[k]for k in e['indices'][i:i+2]],fill=color,width=max(1,round(SS*e.get('thickness',1.6))))
        elif e['kind']=='ceSimpleLineObject':
            draw.line(pts,fill=color,width=max(1,round(e['width']/native_scale*F)))
        elif e['kind']=='ceStringPoly' and text:
            height=round(e['stringdefs'][0]/native_scale*F);width=round(height*141/256)
            strip=Image.new('RGBA',(max(1,len(text)*width),height))
            for i,ch in enumerate(text):
                if ch==' ':continue
                if ch not in glyphs:raise ValueError('Missing shipped LCD glyph '+repr(ch))
                glyph=glyphs[ch].resize((width,height),Image.Resampling.LANCZOS);ink=Image.new('RGBA',glyph.size,color);ink.putalpha(glyph.getchannel('A'));strip.alpha_composite(ink,(i*width,0))
            if angle:strip=strip.rotate(math.degrees(angle),expand=True,resample=Image.Resampling.BICUBIC)
            px,py=pixel(x,y);im.paste(strip,(round(px-strip.width/2),round(py-strip.height/2)),strip)
    im=im.resize((S,S),Image.Resampling.LANCZOS);im.save(OUT/(name+'.png'))
    frame=Image.new('RGB',(S,S+44),(5,14,20));frame.paste(im,(0,44))
    ImageDraw.Draw(frame).text((16,12),name.upper()+' / ACTUAL LUA + LCD ATLAS / SYNTHETIC ROUTE',fill='white',font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18));screens.append(frame)
sheet=Image.new('RGB',(S*3,(S+44)*2))
for i,im in enumerate(screens):sheet.paste(im,((i%3)*S,(i//3)*(S+44)))
sheet.save(OUT/'navigation-contact-sheet.png')
print('Rendered six actual Lua navigation states:',OUT)

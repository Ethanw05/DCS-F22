"""Current DEF/Stores Lua and shipped stroke font; synthetic inputs, not DCS captures."""
from pathlib import Path
import math
import re
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'out/previews/current-avionics'
OUT.mkdir(parents=True, exist_ok=True)
fixture = ROOT/'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)


def convert(value):
    if hasattr(value, 'items'):
        pairs = list(value.items())
        if pairs and all(isinstance(k, int) for k, _ in pairs):
            return [convert(value[k]) for k, _ in sorted(pairs)]
        return {k: convert(v) for k, v in pairs}
    return value


S, SS, NATIVE = 900, 3, .1
F = S*SS/2
caption = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 22)
images = {}
for name, stores, view in [('def', False, 0), ('def-setup', False, 1), ('stores', True, 0), ('stores-edit', True, 1)]:
    active = False
    lua = ns['runtime']()
    lua.execute('''
    function GetScale()return .1 end
    function GetAspect()return 1 end
    resource_colors={};resource_files={};local seq=0
    function MakeMaterial(file,c)seq=seq+1;local n='def-ink-'..seq;resource_colors[n]=c;resource_files[n]=file;return n end
    function MakeFont(_,c,n)resource_colors[n]=c;return n end
    local read=dofile
    function dofile(p)
      if p==SCRIPT_ROOT..'fonts.lua'then return assert(loadfile(p))()end
      return read(p)
    end
    function preview_get(k)return get_param_handle(k):get()end
    ''')
    g = lua.globals()
    factory = lua.execute("return dofile(SCRIPT_ROOT..'"+('MFD_COMMON/stores_page.lua' if stores else 'MFD_RIGHT/defensive_overview.lua')+"')")
    factory('RMFD_BAY_PAGE' if stores else 'RMFD_RWR_PAGE','AVIONICS_PREVIEW','F22_SMS_UI_PAGE_RMFD' if stores else 'F22_DEF_DETAIL_RMFD')
    lua.execute("dofile(SCRIPT_ROOT..'MFD_COMMON/bezel.lua')('RMFD')")
    params = dict(MFD_OPACITY=1, RMFD_RWR_PAGE=1, F22_DEF_DETAIL_RMFD=view,
                  F22_DEF_OV_CURRENT=1, F22_RWR_POWER=1, F22_EW_BACKEND_READY=1,
                  F22_DEF_DISPLAY_RANGE_NM=40,F22_MFD_LABEL_ONE=1,
                  F22_CHAFF_COUNT=120, F22_FLARE_COUNT=80, F22_CM_READY=1,
                  F22_CM_MODE=1, F22_CM_SYSTEM=2, F22_CM_NORMAL_BANK=1, F22_CM_DIRECT_BANK=2,
                  F22_CM_PROGRAM_SELECTED=1, F22_CM_PROGRAM_CHAFF=1, F22_CM_PROGRAM_FLARE=1,
                  F22_CM_PROGRAM_INTERVAL=.25, F22_CM_PROGRAM_CYCLES=4,
                  F22_CM_PROGRAM_RUNNING=int(active), F22_CM_EXECUTING=int(active),
                  F22_CM_RUNNING_BANK=1 if active else 0, F22_CM_STATUS=2 if active else 0,
                  F22_IFF_RESPONDER_STATUS=1, F22_DEF_OV_01_VALID=1,
                  F22_DEF_OV_01_X=.45, F22_DEF_OV_01_Y=.72, F22_DEF_OV_01_ROT=-.56,
                  F22_DEF_OV_01_AFFILIATION=-1, F22_DEF_OV_01_SELECTED=1)
    params.update(RMFD_BAY_PAGE=int(stores),RMFD_RWR_PAGE=int(not stores),HUD_MODE=7 if stores else 2,
                  F22_SMS_UI_PAGE_RMFD=view,F22_SMS_AA_CONTEXT=0,HUD_AG_SUBMODE=3,F22_SMS_LABEL=2,
                  F22_SMS_PROFILE=1,F22_SMS_QUANTITY=2,F22_SMS_PAIR=1,F22_SMS_INTERVAL_MS=200,
                  F22_SMS_INTERVAL_MODE=1,F22_SMS_SPACING_FT=200,F22_SMS_ENTRY_FIELD=1 if view else 0,
                  F22_SMS_ENTRY_VALUE=4,F22_SMS_ENTRY_LENGTH=1 if view else 0,F22_SMS_SELECTED_INDEX=1,
                  F22_ENGINE_L_RPM_TEXT='83',F22_ENGINE_R_RPM_TEXT='83',ARM_STATUS=0,
                  F22_ECM_DISPLAY_STATE=3,F22_ECM_TRANSMITTING_VALID=1,F22_ECM_TRANSMITTING=1,
                  F22_ECM_REQUESTED=1,F22_DEF_OV_RANGE_VALID=1,F22_DEF_OV_RANGE_NM=40,
                  F22_DEF_OV_PROXIMITY_COUNT=2)
    for i,(label,x,y,aff,rf,ranged) in enumerate([(29,.34,.46,-1,1,1),(106,-.54,.54,0,1,0),(22,-.26,-.05,-1,0,1),(18,.59,.12,-1,0,1)],1):
        for k,v in dict(VALID=1,LABEL_CODE=label,X=x,Y=y,ROT=-math.atan2(x,y),AFFILIATION=aff,
                        RF_CURRENT=rf,RF=rf,RANGED=ranged,PROXIMITY=int(not ranged),SELECTED=int(i==1),ALERT=int(i==2)).items():
            params[f'F22_DEF_OV_{i:02d}_{k}']=v
    for i in [2,3,4,6]:
        for k,v in dict(PRESENT=1,COUNT=1,LABEL=2,SELECTED=1,ACTIVE=1).items():params[f'F22_SMS_STATION_{i:02d}_{k}']=v
    params.update(F22_SMS_STORE_1_LABEL=2,F22_SMS_STORE_1_INDEX=1,F22_SMS_STORE_1_SELECTED=1)
    for key, value in params.items():
        h = g.get_param_handle(key)
        h.set(h, value)
    control_module = lua.execute("return dofile(SCRIPT_ROOT..'Systems/MFD_Controls.lua')")
    controls = control_module.for_page(6 if stores else 13, view, g.preview_get)
    label_span = lua.execute("return dofile(SCRIPT_ROOT..'MFD_COMMON/display_layout.lua').label_span")
    for button in range(1, 21):
        action = controls[button]
        label = (action['label'] or '') if action else ''
        if action and action['parameter']:
            label=(action['format'] or '%s') % params.get(action['parameter'],0)
        params[f'F22_MFD_RMFD_KEY_{button}'] = label
        params[f'F22_MFD_RMFD_SEL_{button}'] = 1 if action and action['selected'] else 0
        params[f'F22_MFD_RMFD_SPAN_{button}'] = label_span(label)
    elements = convert(g.elements)
    lookup = {e['name']: e for e in elements}
    colors = convert(g.resource_colors)
    resources = convert(g.resource_files)
    for color, rgb in {'WHITE': [240, 247, 246], 'BLUE': [113, 188, 240], 'GREEN': [0, 255, 0],
                       'YELLOW': [255, 220, 40], 'RED': [255, 35, 20], 'TEAL': [0, 255, 255]}.items():
        colors['F22_LCD_FONT_'+color] = rgb
    font_def = lua.execute("return dofile(SCRIPT_ROOT..'HUD/font.lua')")
    font_parser = (ROOT/'tools/render_hud_preview.py').read_text()
    exec(font_parser[font_parser.index('stroke_ids='):font_parser.index('def project_vector')])
    cache = {}

    def resolve(e):
        if e['name'] in cache:
            return cache[e['name']]
        x, y, *_ = e.get('init_pos', [0, 0, 0])
        alpha, angle, text = 1, e.get('init_rot', [0])[0], e.get('value')
        fields = e.get('element_params', [])
        for c in e.get('controllers', []):
            v = params.get(fields[c[1]], 0)
            if c[0] == 'parameter_in_range':
                alpha *= int(c[2] < v < c[3])
            elif c[0] == 'opacity_using_parameter':
                alpha *= v
            elif c[0] == 'move_left_right_using_parameter':
                x += v*c[2]/NATIVE
            elif c[0] == 'move_up_down_using_parameter':
                y += v*c[2]/NATIVE
            elif c[0] == 'rotate_using_parameter':
                angle += v*c[2]
            elif c[0] == 'text_using_parameter':
                text = e['formats'][c[2]] % v
            elif c[0] != 'line_object_set_point_using_parameters':
                raise ValueError(c)
        if e.get('parent_element'):
            px, py, pa, pt, _ = resolve(lookup[e['parent_element']])
            x, y = px+x*math.cos(pt)-y*math.sin(pt), py+x*math.sin(pt)+y*math.cos(pt)
            alpha *= pa
            angle += pt
        cache[e['name']] = (x, y, alpha, angle, text)
        return cache[e['name']]

    image = Image.new('RGB', (S*SS, S*SS), (0, 0, 0))
    draw = ImageDraw.Draw(image)

    def pixel(x, y):
        return F+x*F, F-y*F

    for e in elements:
        x, y, alpha, angle, text = resolve(e)
        if alpha <= 0 or e.get('isvisible') is False:
            continue
        color = tuple(round(c) for c in colors.get(e.get('material'), [240, 247, 246])[:3])
        ca, sa = math.cos(angle), math.sin(angle)
        points = [pixel(x+v[0]*ca-v[1]*sa, y+v[0]*sa+v[1]*ca) for v in e.get('vertices', [])]
        if e['kind'] == 'ceMeshPoly':
            for index in range(0, len(e['indices']), 3):
                draw.polygon([points[k] for k in e['indices'][index:index+3]], fill=color)
        elif e['kind'] == 'ceSMultiLine':
            for index in range(0, len(e['indices']), 2):
                draw.line([points[k] for k in e['indices'][index:index+2]], fill=color,
                          width=max(1, round(SS*e.get('thickness', .8))))
        elif e['kind'] == 'ceSimpleLineObject':
            vertices = {}
            fields = e['element_params']
            for c in e.get('controllers', []):
                if c[0] == 'line_object_set_point_using_parameters':
                    vertices[c[1]] = (params.get(fields[c[2]],0)*c[4]/NATIVE,
                                      params.get(fields[c[3]],0)*c[5]/NATIVE)
            line = [pixel(x+vx*ca-vy*sa,y+vx*sa+vy*ca) for _,(vx,vy) in sorted(vertices.items())]
            if len(line)==2:
                draw.line(line, fill=color, width=max(1,round(e['width']/NATIVE*F)))
        elif e['kind'] == 'ceTexPoly' and resources.get(e.get('material')):
            source=Image.open(resources[e['material']]).convert('RGBA')
            bounds=(round(min(v[0]for v in points)),round(min(v[1]for v in points)),round(max(v[0]for v in points)),round(max(v[1]for v in points)))
            texture=source.resize((max(1,bounds[2]-bounds[0]),max(1,bounds[3]-bounds[1])),Image.Resampling.LANCZOS)
            image.paste(texture,(bounds[0],bounds[1]),texture)
        elif e['kind'] == 'ceStringSLine' and text:
            gh, gw, gap = (n/NATIVE*F for n in e['stringdefs'][:3])
            total = len(text)*gw+max(0, len(text)-1)*gap
            align = e.get('alignment', 'CenterCenter')
            start = 0 if align.startswith('Left') else -total if align.startswith('Right') else -total/2
            ax, ay = pixel(x, y)
            for index, char in enumerate(text):
                if char == ' ':
                    continue
                paths = stroke_paths[stroke_ids[ord(char)]]
                all_points = [p for path in paths for p in path]
                cx = (min(p[0] for p in all_points)+max(p[0] for p in all_points))/2
                cy = (min(p[1] for p in all_points)+max(p[1] for p in all_points))/2
                for path in paths:
                    polygon = []
                    for gx, gy in path:
                        dx = start+index*(gw+gap)+gw/2+(gx-cx)*gw/12
                        dy = (gy-cy)*gh/20
                        polygon.append((ax+dx*ca+dy*sa, ay-dx*sa+dy*ca))
                    if len(polygon) > 1:
                        draw.line(polygon, fill=color, width=SS, joint='curve')
    image = image.resize((S, S), Image.Resampling.LANCZOS)
    image.save(OUT/(name+'.png'))
    images[name] = image

for names,filename in [([('def','DEF / JAM ACTIVE'),('def-setup','DEF / PROGRAM SETUP')],'def-pages.png'),
                        ([('stores','STORES'),('stores-edit','STORES / EDIT PROFILE')],'stores-pages.png')]:
    sheet=Image.new('RGB',(S*2,S+94),(12,18,22))
    for column,(name,label)in enumerate(names):
        sheet.paste(images[name],(column*S,52))
    d=ImageDraw.Draw(sheet)
    for column,(name,label)in enumerate(names):
        d.text((column*S+20,15),label,font=caption,fill='white')
    d.text((20,S+64),'Current Lua and shipped font. Synthetic data; not an in-game screenshot.',font=caption,fill=(170,186,192))
    sheet.save(OUT/filename)
print(OUT)

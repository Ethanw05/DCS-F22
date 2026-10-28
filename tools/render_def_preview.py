"""Actual DEF Lua/native stroke font, synthetic inputs; not a DCS screenshot."""
from pathlib import Path
import math
import re
import runpy
import subprocess
import sys
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'out/previews/def-workflow'
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


def before(path):
    return subprocess.run(['git', 'show', '7137887:'+path], cwd=ROOT,
                          check=True, capture_output=True, text=True).stdout


old_page = before('Cockpit/Scripts/MFD_RIGHT/defensive_overview.lua')
old_controls = before('Cockpit/Scripts/Systems/MFD_Controls.lua')
S, SS, NATIVE = 900, 3, .1
F = S*SS/2
caption = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 22)
images = {}
for name, original, view, active in [('before', True, 0, False), ('normal', False, 0, False),
                                      ('running', False, 0, True), ('setup', False, 1, False)]:
    lua = ns['runtime']()
    lua.execute('''
    function GetScale()return .1 end
    function GetAspect()return 1 end
    resource_colors={};local seq=0
    function MakeMaterial(_,c)seq=seq+1;local n='def-ink-'..seq;resource_colors[n]=c;return n end
    function MakeFont(_,c,n)resource_colors[n]=c;return n end
    local read=dofile
    function dofile(p)
      if p==SCRIPT_ROOT..'fonts.lua'then return assert(loadfile(p))()end
      return read(p)
    end
    function preview_get(k)return get_param_handle(k):get()end
    ''')
    g = lua.globals()
    factory = lua.execute(old_page) if original else lua.execute(
        "return dofile(SCRIPT_ROOT..'MFD_RIGHT/defensive_overview.lua')")
    factory('RMFD_RWR_PAGE', 'DEF_PREVIEW', 'F22_DEF_DETAIL_RMFD')
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
    if active:
        params.update(F22_DEF_OV_02_VALID=1, F22_DEF_OV_02_X=-.6, F22_DEF_OV_02_Y=.55,
                      F22_DEF_OV_02_ROT=.7, F22_DEF_OV_02_AFFILIATION=0, F22_DEF_OV_02_ALERT=1)
    for key, value in params.items():
        h = g.get_param_handle(key)
        h.set(h, value)
    control_module = lua.execute(old_controls) if original else lua.execute(
        "return dofile(SCRIPT_ROOT..'Systems/MFD_Controls.lua')")
    controls = control_module.for_page(13, view, g.preview_get)
    label_span = lua.execute("return dofile(SCRIPT_ROOT..'MFD_COMMON/display_layout.lua').label_span")
    for button in range(1, 21):
        action = controls[button]
        label = action['label'] if action else ''
        params[f'F22_MFD_RMFD_KEY_{button}'] = label
        params[f'F22_MFD_RMFD_SEL_{button}'] = 1 if action and action['selected'] else 0
        params[f'F22_MFD_RMFD_SPAN_{button}'] = label_span(label)
    elements = convert(g.elements)
    lookup = {e['name']: e for e in elements}
    colors = convert(g.resource_colors)
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

sheet = Image.new('RGB', (S*2, S+52), (12, 18, 22))
for column, (name, label) in enumerate([('before', 'BEFORE — 20 ACTIVE KEYS'),
                                        ('normal', 'NORMAL DEF — 5 ROUTINE KEYS')]):
    sheet.paste(images[name], (column*S, 52))
    ImageDraw.Draw(sheet).text((column*S+20, 15), label, font=caption, fill='white')
sheet.save(OUT/'comparison.png')
print('Rendered actual DEF Lua/stroke font:', OUT, '(synthetic data, not DCS screenshots)')

"""Clearance of actual fixed HUD readouts using their native font metrics."""
import itertools
from cockpit_fixture import runtime

fields = {'HUD_ALT_FT', 'HUD_ALT_SOURCE_TEXT', 'F22_ALT_DISPLAY_TEXT',
          'VV', 'RADALT', 'HUD_WP_INFO', 'HUD_WP_TTG_TEXT','F22_AP_STATUS_TEXT'}
radar = {'OFF','STBY','RWS','TWS','ACQ','STT','BORE','VACQ','WIDE','SENSOR N/A'}

for native_scale in (.00055, .001):
    lua = runtime()
    lua.globals().actual_scale = native_scale
    lua.execute('function GetScale() return actual_scale end; dofile(SCRIPT_ROOT.."HUD/page.lua")')
    layout = lua.execute('return dofile(SCRIPT_ROOT.."HUD/layout.lua")')
    angular = layout.angular_scale
    elements = {e['name']: e for _, e in lua.globals().elements.items()}
    labels = [e for e in elements.values() if e['kind']=='ceStringSLine' and
              ((e['element_params'] and e['element_params'][1] in fields) or e['value'] in radar or e['value']=='NWS')]
    assert len([e for e in labels if e['element_params'][1] in fields]) == len(fields)

    def active(element, state):
        while element:
            params = element['element_params']
            for _, control in (element['controllers'].items() if element['controllers'] else []):
                if control[1] == 'parameter_in_range':
                    value = state.get(params[control[2]+1], 0)
                    if not control[3] <= value <= control[4]: return False
                if control[1] == 'opacity_using_parameter' and state.get(params[control[2]+1], 0) <= 0:
                    return False
            element = elements.get(element['parent_element'])
        return True

    def bounds(element, state):
        param = element['element_params'][1]
        text = element['value'] or element['formats'][1] % state[param]
        x,y = element['init_pos'][1]/(1000*angular), element['init_pos'][2]/(1000*angular)
        parent = elements.get(element['parent_element'])
        while parent:
            if parent['init_pos']:
                x += parent['init_pos'][1]/(1000*angular)
                y += parent['init_pos'][2]/(1000*angular)
            parent = elements.get(parent['parent_element'])
        metrics = element['stringdefs']
        height = metrics[1]/(native_scale*1000*angular)
        width = (len(text)*metrics[2] + max(0,len(text)-1)*metrics[3])/(native_scale*1000*angular)
        alignment = element['alignment']
        left = x-width if alignment=='RightCenter' else x if alignment=='LeftCenter' else x-width/2
        # Include a small stroke/glow allowance on the native glyph box.
        pad = height*.1
        return (left-pad, y-height/2-pad, left+width+pad, y+height/2+pad, param, text)

    for mode, source, pressure, vv in itertools.product(range(1,8),
            ('BARO','BARO FB','RDR','STBY'), (0,1), (-30000,0,30000)):
        state = dict(HUD_POWER=1, HUD_ALT_VALID=1, HUD_AIRDATA_VALID=1,
                     HUD_MODE=mode, HUD_QNH_VISIBLE=pressure, F22_RADAR_MODE_CODE=9,HUD_NWS_ACTIVE=1,
                     HUD_ALT_FT=99999, HUD_ALT_SOURCE_TEXT=source,
                     F22_ALT_DISPLAY_TEXT='BARO 31.50 INHG', VV=vv, RADALT=99999,
                     HUD_WP_INFO='99 359/999.9', HUD_WP_TTG_TEXT='99:59:59',F22_AP_STATUS_TEXT='AP HDG BALT A/T')
        boxes = [bounds(e,state) for e in labels if active(e,state)]
        for a,b in itertools.combinations(boxes,2):
            overlap = min(a[2],b[2])>max(a[0],b[0]) and min(a[3],b[3])>max(a[1],b[1])
            assert not overlap, (mode, source, pressure, a[4:], b[4:], 'HUD text overlap')
print('HUD data rows: BARO/RDR/STBY, pressure, signed VV, radar altitude, NAV and combat text remain separate PASS')

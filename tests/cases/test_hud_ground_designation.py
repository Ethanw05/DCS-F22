"""NAV/radar designation -> actual owner -> native HUD declarations and viewport."""
import math
import unittest
from host import Host
from navigation_ports import avionics_sensors, seed_physical


def marker():
    h=Host();h.state.time=10
    h.seed({'MAIN_POWER':1,'HUD_POWER':1,'HUD_MODE':1})
    h.sensor('getSelfCoordinates',(0,1000,0))
    for key in ['getHeading','getPitch','getRoll']:h.sensor(key,0)
    h.execute('package.loaded.terrain={GetHeight=function()return 0 end}')
    h.load('Systems/AG_Mark_System.lua');h.env.post_initialize()
    return h


def nav_designate(h,north=1000,east=0,request=1):
    h.seed({'F22_NAV_TARGET_REQUEST_VALID':1,'F22_NAV_TARGET_REQUEST_SEQUENCE':request,
        'F22_NAV_TARGET_REQUEST_N':north,'F22_NAV_TARGET_REQUEST_E':east})
    h.env.SetCommand(10843,1);h.env.SetCommand(10843,0);h.update()


def radar_designate(h,north=1000,east=0,altitude=0,sequence=4):
    h.seed({'F22_AG_NATIVE_CONTROL_SCHEMA':1,'F22_AG_NATIVE_CONTROL_SEQUENCE':sequence,
        'F22_AG_NATIVE_CONTROL_EPOCH':3,'F22_AG_NATIVE_CONTROL_TIME':h.state.time,
        'F22_AG_NATIVE_SOURCE_EPOCH':3,'F22_AG_DESIGNATION_SCHEMA':1,
        'F22_AG_DESIGNATION_EPOCH':3,'F22_AG_DESIGNATION_VALID':1,
        'F22_AG_DESIGNATION_SEQUENCE':sequence,'F22_AG_DESIGNATION_TIME':h.state.time,
        'F22_AG_DESIGNATION_REQUEST':1,'F22_AG_DESIGNATION_TYPE':3,
        'F22_AG_DESIGNATION_LIVE':0,'F22_AG_DESIGNATION_NORTH':north,
        'F22_AG_DESIGNATION_ALTITUDE':altitude,'F22_AG_DESIGNATION_EAST':east})
    h.update()


def hud(h):
    h.execute('MILLYRADIANS=1;function SetScale()end;function GetScale()return .00055 end;'
        'function MakeMaterial(path,color)return path or color end;function MakeFont(name)return name end;'
        'h_clip_relations={REWRITE_LEVEL=1,INCREASE_IF_LEVEL=2,COMPARE=3};'
        'blend_mode={IBM_NO_WRITECOLOR=0}')
    original=h.env.dofile
    h.env.dofile=lambda path:None if str(path)=='common/elements_defs.lua' else original(path)
    h.load('HUD/page.lua')
    return {e['name']:e for _,e in h.state.elements.items() if e['added']}


def shown(h,elements,name):
    node=elements[name]
    if node['parent_element'] and not shown(h,elements,node['parent_element']):return False
    for _,row in (node['controllers'].items() if node['controllers'] else []):
        if row[1]=='parameter_in_range':
            value=h.get(node['element_params'][row[2]+1]) or 0
            if not row[3]<=value<=row[4]:return False
        if row[1]=='opacity_using_parameter' and (h.get(node['element_params'][row[2]+1]) or 0)<=0:return False
    return True


def marker_vertices(h,elements,name):
    """Actual declared native gains/vertices; final body-ray plane in metres."""
    parent=elements[name];x=parent['init_pos'][1]*.00055;y=parent['init_pos'][2]*.00055-.022
    for _,row in parent['controllers'].items():
        if row[1]=='move_left_right_using_parameter':x+=h.get(parent['element_params'][row[2]+1])*row[3]
        if row[1]=='move_up_down_using_parameter':y+=h.get(parent['element_params'][row[2]+1])*row[3]
    points=[]
    for node in elements.values():
        if node['parent_element']==name and node['vertices']:
            points.extend((x+v[1]*.00055,y+v[2]*.00055) for _,v in node['vertices'].items())
    return points


class HudGroundDesignation(unittest.TestCase):
    def test_actual_indicator_registration_keeps_the_existing_viewport(self):
        h=Host();h.execute('function mount_vfs_texture_archives()end;'
            'function MakeFont(name)return name end;function MakeMaterial(path,color)return path or color end')
        original=h.env.dofile
        h.env.dofile=lambda path:None if str(path).startswith('common/') else original(path)
        h.load('device_init.lua')
        registrations=[v for _,v in h.env.indicators.items() if 'HUD/init.lua' in str(v[2])]
        self.assertEqual(len(registrations),1)
        viewport=registrations[0][4][2]
        self.assertEqual((viewport['sw'],viewport['sh']),(.14,.12))

    def test_actual_nav_command_acknowledgement_and_undesignate_reach_actual_hud(self):
        h=marker();mark_command,mark_update=h.env.SetCommand,h.env.update
        avionics_sensors(h);seed_physical(h)
        h.execute('''
function read(k)return get_param_handle(k):get()end
function put(k,v)get_param_handle(k):set(v)end
local gins=dofile(LockOn_Options.script_path..'Systems/Gins_References.lua').new(read,put,get_base_data())
gins:reset(true);gins:update()
function get_mission_route()
 return {{x=0,y=0,alt=1000},{x=5000,y=0,alt=0,alt_type='BARO',name='TARGET'}}
end
''')
        h.seed({'F22_GPS_AID':1,'F22_NAV_SOURCE':0})
        h.load('Systems/Navigation_System.lua');h.env.post_initialize()
        nav_command,nav_update=h.env.SetCommand,h.env.update
        h.env.dispatch_action=h.lua.eval('function(mark,id)return function(owner,c,v)'
            'if owner==id then mark(c,v)end end end')(mark_command,h.env.devices.AG_MARK_SYSTEM)
        nav_update();nav_command(10841,1);nav_command(10841,0);mark_update();nav_update()
        self.assertEqual(h.get('F22_NAV_DESIGNATE_STATUS_TEXT'),'TARGET DESIGNATED')
        self.assertEqual(h.get('F22_NAV_DESIGNATED'),1)
        self.assertEqual(h.get('HUD_WP_OFFSCREEN'),1)
        elements=hud(h)
        self.assertTrue(shown(h,elements,'HUD_GROUND_TARGET_EDGE'))
        self.assertFalse(shown(h,elements,'HUD_NAV_STEERING'))
        nav_command(10842,1);nav_command(10842,0);mark_update();nav_update()
        self.assertEqual(h.get('F22_NAV_DESIGNATED'),0)
        self.assertFalse(shown(h,elements,'HUD_GROUND_TARGET_EDGE'))

    def test_nav_acknowledgement_reaches_visible_edge_inside_declared_hud_viewport(self):
        h=marker();nav_designate(h);elements=hud(h)
        self.assertEqual(h.get('F22_NAV_TARGET_RESULT'),1)
        self.assertEqual(h.get('HUD_AG_TARGET_VALID'),1)
        self.assertEqual(h.get('HUD_AG_EDGE_VALID'),1)
        self.assertTrue(shown(h,elements,'HUD_GROUND_TARGET_EDGE'))
        points=marker_vertices(h,elements,'HUD_GROUND_TARGET_EDGE')
        self.assertGreater(len(points),0)
        # Existing device_init geometry is 0.14m wide, 0.12m high.
        self.assertTrue(all(-.07<=x<=.07 and -.06<=y<=.06 for x,y in points),points)

    def test_radar_designation_is_accepted_while_hud_is_in_nav_mode(self):
        h=marker();radar_designate(h)
        self.assertEqual(h.get('HUD_AG_TARGET_VALID'),1)
        self.assertEqual(h.get('F22_AG_TARGET_SOURCE'),2)
        self.assertEqual(h.get('HUD_AG_EDGE_VALID'),1)

    def test_radar_clear_preserves_nav_point_and_withdraws_radar_point(self):
        h=marker();nav_designate(h);radar_designate(h)
        h.seed({'F22_AG_DESIGNATION_VALID':0,'F22_AG_DESIGNATION_SEQUENCE':5});h.update()
        self.assertEqual(h.get('HUD_AG_TARGET_VALID'),0)
        nav_designate(h,request=2)
        h.seed({'F22_AG_NATIVE_CONTROL_EPOCH':4,'F22_AG_DESIGNATION_SEQUENCE':0});h.update()
        self.assertEqual(h.get('F22_AG_TARGET_SOURCE'),3)
        self.assertEqual(h.get('HUD_AG_EDGE_VALID'),1)

    def test_power_loss_and_clock_rewind_retire_the_displayed_designation(self):
        for failure in ['power','clock']:
            h=marker();nav_designate(h);elements=hud(h)
            if failure=='power':h.seed({'MAIN_POWER':0})
            else:h.state.time=9
            h.update()
            self.assertFalse(shown(h,elements,'HUD_GROUND_TARGET_EDGE'),failure)
            h.seed({'MAIN_POWER':1});h.state.time=11;h.update()
            self.assertEqual(h.get('HUD_AG_TARGET_VALID'),0,failure)

    def test_pitch_bank_and_above_targets_stay_inside_the_viewport(self):
        for pitch,roll,alt in [(0,0,3000),(.5,1.2,0),(-.8,-1.5,0),(0,math.pi,0)]:
            h=marker();h.sensor('getPitch',pitch);h.sensor('getRoll',roll)
            radar_designate(h,1000,300,alt);elements=hud(h)
            self.assertEqual(h.get('HUD_AG_EDGE_VALID'),1)
            points=marker_vertices(h,elements,'HUD_GROUND_TARGET_EDGE')
            self.assertTrue(all(-.07<=x<=.07 and -.06<=y<=.06 for x,y in points),points)

    def test_projection_rejects_nonfinite_and_out_of_domain_angles(self):
        h=Host();project=h.load('Systems/HUD_Designation_Projection.lua').new(
            h.load('HUD/glass.lua'),h.load('HUD/geometry.lua'))
        for az,el in [(float('nan'),0),(0,float('inf')),(math.pi+.01,0),(0,math.pi)]:
            self.assertIsNone(project(az,el))

    def test_edge_square_does_not_disappear_with_a_flash_phase(self):
        h=marker();nav_designate(h);elements=hud(h)
        for now in [10.1,10.3,10.55,10.8]:
            h.state.time=now;h.update()
            self.assertTrue(shown(h,elements,'HUD_GROUND_TARGET_EDGE'),now)

    def test_conformal_target_outside_viewport_uses_edge_square(self):
        h=marker();nav_designate(h,5000)
        self.assertEqual(h.get('HUD_AG_CUE_VALID'),0)
        self.assertEqual(h.get('HUD_AG_EDGE_VALID'),1)

    def test_direction_and_all_vertices_fit_for_side_down_and_rear_targets(self):
        for n,e in [(1000,10000),(1000,-10000),(1000,0),(-1000,1000),(-1000,-1000)]:
            h=marker();nav_designate(h,n,e);elements=hud(h)
            self.assertEqual(h.get('HUD_AG_EDGE_VALID'),1,(n,e))
            if e:self.assertGreater(h.get('HUD_AG_EDGE_X')*e,0)
            points=marker_vertices(h,elements,'HUD_GROUND_TARGET_EDGE')
            self.assertTrue(all(-.07<=x<=.07 and -.06<=y<=.06 for x,y in points),(n,e,points))

    def test_in_view_diamond_and_edge_are_exclusive_and_clear_with_target(self):
        h=marker();nav_designate(h,50000);elements=hud(h)
        self.assertTrue(shown(h,elements,'HUD_NAV_STEERING'))
        self.assertFalse(shown(h,elements,'HUD_GROUND_TARGET_EDGE'))
        h.env.SetCommand(10811,1);h.env.SetCommand(10811,0);h.update()
        self.assertFalse(shown(h,elements,'HUD_NAV_STEERING'))
        self.assertFalse(shown(h,elements,'HUD_GROUND_TARGET_EDGE'))


if __name__=='__main__':unittest.main()

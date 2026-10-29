"""Actual indicator declarations with write-only elements and typed pilot gates.

Connector/aspect variants are software geometry tests, never native optics or VR
qualification. No synthetic scene/identity/weapon authority is supplied by UI.
"""
import ctypes
import math
import re
import unittest

from host import Host


def array(value):
    return [value[index] for index in range(1, len(value)+1)] if value is not None else []


def page_host(kind='radar_format', aspect=1.0, scale=.0932):
    h = Host()
    h.env.host_aspect, h.env.host_scale = aspect, scale
    h.execute("""
        FOV=1;MILLYRADIANS=2
        h_clip_relations={REWRITE_LEVEL=1,INCREASE_IF_LEVEL=2,COMPARE=3}
        function SetScale(_)end
        function GetScale()return host_scale end
        function GetAspect()return host_aspect end
        host_materials={};host_material_count=0
        function MakeMaterial(texture,color)
            host_material_count=host_material_count+1
            local name='HOST_MATERIAL_'..host_material_count
            host_materials[name]={texture=texture,color=color}
            return name
        end
        function MakeFont(_,_,name)return name or 'HOST_FONT' end
        local load=dofile
        function dofile(path)
            if path=='common/elements_defs.lua'then return end
            return load(path)
        end
    """)
    h.load('PMFD_CENTER/'+kind+'.lua')('TEST_PMFD_PAGE', 'TEST_', 'TEST_DETAIL')
    records = {}
    for _, record in h.state.elements.items():
        if record.added and record.name:
            if record.name in records:
                raise AssertionError('Duplicate indicator element: '+record.name)
            records[record.name] = record
    return h, records


def visible(h, records, name, visited=None):
    record = records[name]
    if record.isvisible is False:
        return False
    visited = set() if visited is None else visited
    if name in visited:
        raise AssertionError('Indicator parent cycle')
    visited.add(name)
    params = array(record.element_params)
    for controller in array(record.controllers):
        kind = controller[1]
        if kind == 'parameter_in_range':
            value = h.get(params[int(controller[2])])
            if not isinstance(value, (int, float)) or not controller[3] <= value <= controller[4]:
                return False
        elif kind == 'opacity_using_parameter':
            value = h.get(params[int(controller[2])])
            if not isinstance(value, (int, float)) or value <= 0:
                return False
    parent = record.parent_element
    return not parent or parent not in records or visible(h, records, parent, visited)


class RadarPilotPresentation(unittest.TestCase):
    def test_actual_aa_declarations_use_write_only_port_and_connector_units(self):
        for aspect, scale in ((1, .0932), (.7, .0775)):
            h, records = page_host(aspect=aspect, scale=scale)
            self.assertGreater(len(records), 100)
            content = .82*min(1, aspect)
            for name in ('TEST_F22_RDR_CURSOR', 'TEST_F22_RDR_TRACK_1', 'TEST_F22_RDR_WAYPOINT'):
                movements = [row for row in array(records[name].controllers)
                    if row[1] in ('move_left_right_using_parameter', 'move_up_down_using_parameter')]
                self.assertEqual(len(movements), 2)
                for row in movements:
                    self.assertAlmostEqual(row[3], scale*content, delta=1e-12)
            self.assertEqual(h.get('F22_RADAR_PAGE_SCALE'), scale)
            for record in records.values():
                if record.collimated is not None:
                    self.assertFalse(record.collimated)
                for vertex in array(record.vertices):
                    for coordinate in array(vertex):
                        self.assertTrue(math.isfinite(coordinate))

    def test_native_numeric_text_formats_accept_coerced_zero_and_numeric_strings(self):
        snprintf = ctypes.CDLL('msvcrt')._snprintf
        snprintf.restype = ctypes.c_int
        checked = 0
        for kind in ('radar_format', 'ag_radar_format'):
            h, records = page_host(kind)
            for record in records.values():
                for fmt in array(record.formats):
                    conversions = re.findall(r'%(?!%)[+\-0 #]*\d*(?:\.\d+)?([A-Za-z])', fmt)
                    self.assertEqual(len(conversions), 1, fmt)
                    self.assertIn(conversions[0], 'fFeEgG', fmt)
                    self.assertNotIn('%s', fmt)
                    for sample in (0, 70.0):
                        h.env.get_param_handle('TYPED_TEXT_SAMPLE').set(None, str(sample))
                        value = h.get('TYPED_TEXT_SAMPLE')
                        self.assertIsInstance(value, (int, float))
                        buffer = ctypes.create_string_buffer(256)
                        count = snprintf(buffer, ctypes.c_size_t(len(buffer)), fmt.encode('utf-8'), ctypes.c_double(value))
                        self.assertGreaterEqual(count, 0, fmt)
                        self.assertLess(count, len(buffer), fmt)
                    checked += 1
        self.assertGreater(checked, 100)

    def test_static_unavailable_mode_and_independent_closure_validity_gates(self):
        h, records = page_host()
        h.seed(dict(MFD_OPACITY=1, TEST_PMFD_PAGE=1, F22_AG_RADAR_PAGE=0, F22_RADAR_MODE_CODE=9,
            F22_RADAR_SELECTED_VALID=1, F22_RADAR_SELECTED_CLOSURE_VALID=0))
        unavailable = [name for name, record in records.items() if record.value == 'SENSOR N/A']
        self.assertEqual(len(unavailable), 1)
        self.assertTrue(visible(h, records, unavailable[0]))
        self.assertFalse(visible(h, records, 'TEST_F22_RDR_CLOSURE'))
        h.seed({'F22_RADAR_SELECTED_CLOSURE_VALID': 1})
        self.assertTrue(visible(h, records, 'TEST_F22_RDR_CLOSURE'))
        h.seed({'F22_AG_RADAR_PAGE': 1})
        self.assertFalse(visible(h, records, unavailable[0]))

    def test_selection_coast_and_identity_remain_separate_visual_gates(self):
        h, records = page_host()
        h.seed(dict(MFD_OPACITY=1, TEST_PMFD_PAGE=1, F22_AG_RADAR_PAGE=0, RADAR_PWR=1,
            F22_SCOPE_01_VALID=1, F22_SCOPE_01_AFFILIATION=-1, F22_SCOPE_01_SELECTED=1,
            F22_SCOPE_01_DESIGNATED=1, F22_SCOPE_01_COAST=1))
        self.assertTrue(visible(h, records, 'TEST_F22_RDR_TRACK_1_IFF_-1'))
        self.assertFalse(visible(h, records, 'TEST_F22_RDR_TRACK_1_IFF_0'))
        self.assertFalse(visible(h, records, 'TEST_F22_RDR_TRACK_1_IFF_1'))
        self.assertTrue(visible(h, records, 'TEST_F22_RDR_TRACK_1_BUG'))
        self.assertTrue(visible(h, records, 'TEST_F22_RDR_TRACK_1_COAST'))
        self.assertFalse(visible(h, records, 'TEST_F22_RDR_TRACK_1_RETAINED'))
        h.seed({'F22_SCOPE_01_SELECTED': 0})
        self.assertTrue(visible(h, records, 'TEST_F22_RDR_TRACK_1_RETAINED'))
        self.assertTrue(visible(h, records, 'TEST_F22_RDR_TRACK_1_IFF_-1'))
        h.seed({'F22_SCOPE_01_VALID': 0})
        self.assertFalse(visible(h, records, 'TEST_F22_RDR_TRACK_1_COAST'))

    def test_palette_retains_declared_srgb_and_separate_identity_meanings(self):
        h = Host(); palette = h.load('MFD_COMMON/radar_palette.lua')
        self.assertEqual(array(palette.srgb.blue), [113, 188, 240, 255])
        for name, srgb in palette.srgb.items():
            linear = palette.linear[name]
            for index in range(1, 4):
                value = srgb[index]/255
                expected = 255*(value/12.92 if value <= .04045 else ((value+.055)/1.055)**2.4)
                self.assertAlmostEqual(linear[index], expected, delta=1e-10)
            self.assertEqual(linear[4], srgb[4])
        identity = h.load('Systems/Tactical_Identity.lua')
        for code, expected in ((-1, 'yellow'), (0, 'red'), (1, 'green'), (3, 'cyan'), (2, 'yellow'), (None, 'yellow')):
            self.assertEqual(identity.color(code), expected)

    def test_ground_video_declares_one_owned_texture_and_honest_availability(self):
        for aspect in (1, .7):
            h, records = page_host('ag_radar_format', aspect)
            map_video = records['TEST_F22_AG_RADAR_VIDEO']
            ta_video = records['TEST_F22_AG_RADAR_TA_VIDEO']
            self.assertEqual(map_video.material, ta_video.material)
            self.assertEqual(h.env.host_materials[map_video.material].texture, 'mfd8')
            self.assertEqual(array(map_video.tex_coords[1]), [0, 1])
            self.assertEqual(array(ta_video.tex_coords[1]), [.09, .91])
            h.seed(dict(MFD_OPACITY=1, TEST_PMFD_PAGE=1, HUD_MODE=7, F22_AG_MODE=1,
                F22_AG_RADAR_OPERATING=1, F22_AG_MAP_VIDEO_SHOW=1, F22_AG_VIDEO_READY=0,
                F22_AG_VIDEO_GEOMETRY_QUALIFIED=0, F22_AG_EXPANSION=0))
            self.assertFalse(visible(h, records, 'TEST_F22_AG_RADAR_VIDEO'))
            unavailable = [name for name, record in records.items() if record.value == 'VIDEO']
            self.assertEqual(len(unavailable), 1)
            self.assertTrue(visible(h, records, unavailable[0]))
            h.seed({'F22_AG_VIDEO_READY': 1, 'F22_AG_VIDEO_GEOMETRY_QUALIFIED': 1})
            self.assertTrue(visible(h, records, 'TEST_F22_AG_RADAR_VIDEO'))
            self.assertFalse(visible(h, records, unavailable[0]))
            h.seed({'F22_AG_MODE': 6})
            self.assertFalse(visible(h, records, 'TEST_F22_AG_RADAR_VIDEO'))
            self.assertTrue(visible(h, records, 'TEST_F22_AG_RADAR_TA_VIDEO'))

    def test_ground_declutter_hides_grid_without_fabricating_or_hiding_sensor_authority(self):
        h, records = page_host('ag_radar_format')
        h.seed(dict(MFD_OPACITY=1, TEST_PMFD_PAGE=1, HUD_MODE=7, F22_AG_MODE=2,
            F22_AG_RADAR_OPERATING=1, F22_AG_PLOT_SHOW=1, F22_AG_EXPANSION=0,
            F22_AG_DECLUTTER=0, F22_AG_GMT_DISPLAY_1_VALID=1, F22_AG_GMT_DISPLAY_1_ALPHA=1))
        self.assertTrue(visible(h, records, 'TEST_F22_AG_GRID_VISIBLE'))
        self.assertTrue(visible(h, records, 'TEST_F22_AG_GMT_BRICK_1'))
        h.seed({'F22_AG_DECLUTTER': 1})
        self.assertFalse(visible(h, records, 'TEST_F22_AG_GRID_VISIBLE'))
        self.assertTrue(visible(h, records, 'TEST_F22_AG_GMT_BRICK_1'))
        self.assertIsNone(h.get('F22_AG_TRACK_VALID'))

    def test_hud_bridge_needs_fresh_owner_snapshot_not_native_polar_cache(self):
        h = Host(); h.load('Systems/Radar_Data_Bridge.lua'); h.env.post_initialize(); h.state.time = 10
        h.seed(dict(HUD_MODE=2, MAIN_POWER=1, RADAR_PWR=1, F22_RADAR_BACKEND_READY=1,
            F22N_RADAR_MODE=3, F22_RADAR_STT_VALID=1, F22_RADAR_STT_SOURCE_ID=42,
            F22_STT_MOTION_VALID=1, F22_STT_ID=42, F22_STT_TIME=10, F22_RADAR_STT_TIME=10,
            F22_RADAR_STT_RANGE=1852, F22_RADAR_STT_AZIMUTH=.01, F22_RADAR_STT_ELEVATION=.02,
            F22_RADAR_STT_IFF=-1, F22_RADAR_STT_CLOSURE_VALID=1, F22_RADAR_STT_CLOSURE_KTS=0,
            F22N_RADAR_STT_RANGE=99999))
        h.update()
        self.assertEqual(h.get('HUD_AA_TARGET_VALID'), 1)
        self.assertEqual(h.get('HUD_AA_TGT_RANGE_NM'), 1)
        self.assertEqual(h.get('HUD_AA_CLOSURE_VALID'), 1)
        self.assertEqual(h.get('HUD_AA_TGT_CLOSURE_KTS'), 0)
        h.state.time = 10.5001; h.update()
        self.assertEqual(h.get('HUD_AA_TARGET_VALID'), 0)
        self.assertEqual(h.get('HUD_GUN_TARGET_VALID'), 0)
        h.state.time = 11; h.seed({'F22_RADAR_STT_TIME': 11, 'F22_STT_TIME': 11}); h.update()
        self.assertEqual(h.get('HUD_AA_TARGET_VALID'), 1)
        h.seed({'F22_STT_ID': 99}); h.update()
        self.assertEqual(h.get('HUD_AA_TARGET_VALID'), 0)

    def test_unlocked_designation_is_only_pilot_cue_not_weapon_target(self):
        h = Host(); h.load('Systems/Radar_Data_Bridge.lua'); h.env.post_initialize(); h.state.time = 10
        h.seed(dict(HUD_MODE=2, MAIN_POWER=1, RADAR_PWR=1, F22_RADAR_BACKEND_READY=1,
            F22N_RADAR_MODE=1, F22_RADAR_DESIGNATION_VALID=1, F22_RADAR_DESIGNATION_RANGE=10000,
            F22_RADAR_DESIGNATION_AZ=.01, F22_RADAR_DESIGNATION_EL=.02, F22_RADAR_DESIGNATION_AGE=0))
        h.update()
        self.assertEqual(h.get('HUD_TD_VALID'), 1)
        self.assertEqual(h.get('HUD_AA_TARGET_VALID'), 0)
        self.assertEqual(h.get('HUD_GUN_TARGET_VALID'), 0)
        h.seed({'RADAR_PWR': 0}); h.update()
        self.assertEqual(h.get('HUD_TD_VALID'), 0)


if __name__ == '__main__':
    unittest.main()

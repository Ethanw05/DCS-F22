"""R-WPN-007 / R-REG-001/002: truthful player stores and optional presets."""
import unittest
from host import Host, ROOT


class StoreProfile(unittest.TestCase):
    def host(self):
        h = Host()
        h.execute("caps=dofile(LockOn_Options.script_path..'Systems/Store_Capabilities.lua');profile=dofile(LockOn_Options.script_path..'Systems/Equipment_Profile.lua')")
        return h

    def test_legacy_mission_alias_has_no_bomb_delivery_authority(self):
        h = self.host()
        h.execute("legacy=caps.describe({CLSID='{GBU32_JDAM}',count=1,weapon={level1=4,level2=4,level3=7,level4=777}})")
        self.assertFalse(h.env.legacy.supported)
        self.assertEqual(h.env.legacy.delivery, 'unsupported')
        self.assertFalse(h.execute('return caps.mode_available(legacy,2)'))
        self.assertFalse(h.execute('return caps.mode_available(legacy,3)'))
        h.execute("stock=caps.describe({CLSID='{GBU_32_V_2B}',count=1,weapon={level1=4,level2=5,level3=36,level4=778}})")
        self.assertTrue(h.env.stock.supported)
        self.assertEqual(h.env.stock.delivery, 'bomb')

    def test_requested_community_air_to_air_stores_keep_their_launch_capability(self):
        h = self.host()
        for identifier in ['{AIM-260A}', '{LAU_115_2xAIM-260A}', '{MAKO_A2A_C}']:
            h.env.identifier = identifier
            h.execute('store=caps.describe({CLSID=identifier,count=1,weapon={}})')
            self.assertTrue(h.env.store.supported, identifier)
            self.assertEqual(h.env.store.delivery, 'radar')
            self.assertEqual(h.env.store.kind, 2)
        self.assertTrue(h.env.profile.supports('additional_weapons'))
        for identifier in ['{MAKO_A2G_C}', '{F22_IRST}']:
            h.env.identifier = identifier
            h.execute('store=caps.describe({CLSID=identifier,count=1,weapon={}})')
            self.assertFalse(h.env.store.supported, identifier)
        for option in ['targeting_pod', 'hmd', 'irds',
                       'carrier_acls', 'autoland', 'automatic_gcas']:
            self.assertFalse(h.env.profile.supports(option))

    def test_supplied_ferry_uses_only_the_registered_sensor_station(self):
        h = self.host()
        payloads = h.env.dofile((ROOT/'UnitPayloads/F-22A.lua').as_posix()).payloads
        ferry = payloads[14]
        sensors = [(p.num, p.CLSID) for _, p in ferry.pylons.items()
                   if 'IRST' in p.CLSID]
        self.assertEqual(sensors, [(6, '{F22_IRST}')])
        self.assertEqual(ferry.name, '14) FERRY CONFIG VLO TANK, IRST POD')

    def test_optional_presets_are_labelled_without_changing_mission_names(self):
        h = self.host()
        payloads = h.env.dofile((ROOT/'UnitPayloads/F-22A.lua').as_posix()).payloads
        optional = {'{MAKO_A2G_C}'}
        for _, p in payloads.items():
            selected_off = any(row.CLSID in optional for _, row in p.pylons.items())
            self.assertEqual('OPTIONAL OFF' in p.displayName, selected_off, p.name)
            self.assertNotIn('OPTIONAL OFF', p.name)


if __name__ == '__main__':
    unittest.main()

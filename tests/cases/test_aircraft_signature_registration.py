"""Native aircraft descriptor must carry numeric host-assigned type placeholders."""
import unittest
from lupa.lua51 import LuaRuntime
from host import ROOT


class AircraftSignatureRegistration(unittest.TestCase):
    def load(self, prior=None):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('''
            wsType_Air=1;wsType_Airplane=1;wsType_Fighter=1
            WSTYPE_PLACEHOLDER=1000000;current_mod_path='explicit-registration-port'
            function _(text) return text end
            function pylon(number,...) return {Number=number} end
            function gun_mount(name,...) return {name=name} end
            function aircraft_task(id) return {id=id} end
            function add_aircraft(value) captured=value end
            CAP=1;Escort=2;FighterSweep=3;Intercept=4;Reconnaissance=5;GroundAttack=6
        ''')
        if prior is not None:
            lua.globals().F_22A = lua.table_from({'stale_registration': prior})
        lua.execute((ROOT / 'F-22A.lua').read_text(encoding='utf-8-sig'))
        return lua

    def check_native_type(self, lua):
        descriptor = lua.globals().captured
        self.assertEqual(descriptor.Name, 'F-22A')
        self.assertEqual(descriptor.WorldID, lua.globals().WSTYPE_PLACEHOLDER)
        self.assertEqual(descriptor.shape_table_data[1].index, lua.globals().WSTYPE_PLACEHOLDER)
        self.assertEqual(descriptor.attribute[4], lua.globals().WSTYPE_PLACEHOLDER)
        self.assertEqual([descriptor.attribute[i] for i in range(1, 4)], [1, 1, 1])

    def test_first_registration_has_complete_native_air_target_type(self):
        self.check_native_type(self.load())

    def test_previous_table_cannot_become_native_type_on_reload(self):
        self.check_native_type(self.load(prior=7))


if __name__ == '__main__':
    unittest.main()

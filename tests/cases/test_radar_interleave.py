"""Actual Lua -> native reader/model/writer -> Lua tactical path, no injected reports."""
import os
from pathlib import Path
import subprocess
import unittest

from host import Host
from test_radar_source_contract import system_host

DEFAULT_BINARY = Path(r'C:\Users\Ethans Desktop 2.0\Documents\ChatGPT\F22 MOD\out\radar-interleave\radar_interleave.exe')
INPUTS = ['F22_AESA_'+name for name in (
    'REQUEST', 'CONTROL_TIME', 'CONTROL_SEQUENCE', 'CONTROL_EMIT', 'CONTROL_RESOURCE',
    'CONTROL_SURFACE', 'CONTROL_AZ', 'CONTROL_EL', 'CONTROL_HALF_AZ', 'CONTROL_HALF_EL',
    'CONTROL_RANGE', 'CONTROL_CUE_VALID', 'CONTROL_CUE_AZ', 'CONTROL_CUE_EL', 'CONTROL_TARGET',
    'CONTROL_SURFACE_HALF_AZ', 'CONTROL_FC_TARGET', 'CONTROL_GUN_TRACK', 'CONTROL_CUE_HALF_AZ',
    'CONTROL_CUE_HALF_EL', 'CONTROL_CUE_REQUEST', 'CONTROL_CUE_RANGE')]
INPUTS += [f'F22_AESA_PRIORITY_{i:02}' for i in range(1, 11)]


class OwnerBridge:
    def __init__(self):
        binary = Path(os.environ.get('F22_RADAR_INTERLEAVE_EXE', DEFAULT_BINARY))
        if not binary.is_file():
            raise RuntimeError('Build the actual interleave native target externally and set F22_RADAR_INTERLEAVE_EXE')
        self.process = subprocess.Popen([str(binary), '--bridge'], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
        if self.process.stdout.readline().strip() != 'READY':
            raise RuntimeError('Actual native adapter fixture failed initialization')

    def step(self, h, now):
        producer_times = {h.get(f'F22A_{row:02}_ID'): h.get(f'F22A_{row:02}_TIME')
                          for row in range(1, 65) if h.get(f'F22A_{row:02}_VALID') == 1}
        h.state.time = now
        h.seed(dict(EFM_PHYSICAL_STAMP=now, F22_AP_CLOCK=now))
        h.update()
        for source, age in sources(h).items():
            if source in producer_times and abs(now-age-producer_times[source]) > 1e-9:
                raise AssertionError('Lua tactical copy renewed original native observation time')
        fields = ' '.join(f'{name} {h.get(name):.17g}' for name in INPUTS)
        self.process.stdin.write(f'{now:.17g} {len(INPUTS)} {fields}\n')
        self.process.stdin.flush()
        values = self.process.stdout.readline().split()
        if not values:
            raise RuntimeError('Native bridge stopped: '+self.process.stderr.read())
        count = int(values[0])
        if len(values) != 1+2*count:
            raise RuntimeError('Incomplete native publication fixture transport')
        h.seed({values[1+2*i]: float(values[2+2*i]) for i in range(count)})
        return h.get('F22_AESA_DWELLS'), h.get('F22_AESA_SURFACE_SEQUENCE')

    def close(self):
        self.process.stdin.write('STOP\n')
        self.process.stdin.flush()
        self.process.communicate(timeout=10)
        if self.process.returncode:
            raise RuntimeError('Native bridge failed with exit '+str(self.process.returncode))

    def advance_source_epoch(self):
        self.process.stdin.write('EPOCH\n')
        self.process.stdin.flush()
        if self.process.stdout.readline().strip() != 'EPOCH':
            raise RuntimeError('Native source epoch event was not acknowledged by test port')


def sources(h):
    return {h.get(f'F22_RADAR_TACTICAL_{i:02}_SOURCE'):
            h.get(f'F22_RADAR_TACTICAL_{i:02}_AGE') for i in range(1, 65)
            if h.get(f'F22_RADAR_TACTICAL_{i:02}_VALID') == 1}


class RadarInterleave(unittest.TestCase):
    def test_unavailable_epoch_requires_current_complete_header_and_recovers(self):
        for fault in ('odd', 'future', 'stale', 'bad_epoch', 'torn_sequence', 'torn_epoch'):
            h = Host()
            h.execute("adapter=dofile(LockOn_Options.script_path..'Systems/AESA_Control.lua').new("
                      "function(k)return get_param_handle(k):get()end,"
                      "function(k,v)get_param_handle(k):set(v)end)")
            h.seed(dict(F22_AESA_READY=1, F22_AESA_SEQUENCE=2, F22_AESA_GENERATION=1,
                        F22_AESA_TIME=10, F22A_01_VALID=1, F22A_01_ID=7, F22A_01_TIME=10,
                        F22A_01_N=10000, F22A_01_U=5000, F22A_01_E=0))
            h.execute('adapter:read(10)')
            self.assertEqual(h.env.adapter.generation, 1)
            h.seed(dict(F22_AESA_READY=0, F22_AESA_SEQUENCE=4, F22_AESA_GENERATION=2,
                        F22_AESA_TIME=10.1))
            if fault in ('odd', 'future', 'stale', 'bad_epoch'):
                key, value = {'odd': ('F22_AESA_SEQUENCE', 5),
                              'future': ('F22_AESA_TIME', 10.2),
                              'stale': ('F22_AESA_TIME', 9),
                              'bad_epoch': ('F22_AESA_GENERATION', float('nan'))}[fault]
                h.seed({key: value})
            else:
                name = 'F22_AESA_SEQUENCE' if fault == 'torn_sequence' else 'F22_AESA_GENERATION'
                h.env.torn_field = name
                h.execute("original_get=get_param_handle; local reads=0; get_param_handle=function(k) "
                          "local handle=original_get(k); if k~=torn_field then return handle end; "
                          "return {get=function() reads=reads+1; return handle:get()+(reads==2 and 2 or 0) end} end")
            h.execute('adapter:read(10.1)')
            self.assertEqual(h.env.adapter.generation, 1, fault)
            self.assertFalse(h.env.adapter.ready)
            self.assertFalse(h.env.adapter.generation_changed)
            self.assertEqual(len(h.env.adapter.observations), 0)
            if h.env.original_get is not None:
                h.env.get_param_handle = h.env.original_get
            h.seed(dict(F22_AESA_SEQUENCE=6, F22_AESA_GENERATION=2, F22_AESA_TIME=10.1))
            h.execute('adapter:read(10.1)')
            self.assertEqual(h.env.adapter.generation, 2)
            self.assertTrue(h.env.adapter.generation_changed)
            self.assertFalse(h.env.adapter.ready)
            self.assertIsNone(h.env.adapter.samples[1].observed)

    def test_saved_ag_intl_remains_surface_image_gmt_control(self):
        h = system_host()
        h.state.time = 1
        h.seed({'HUD_MODE': 7})
        h.update()
        h.env.SetCommand(10602, 1)  # GMT search exposes INTL; MAP does not.
        h.update()
        self.assertEqual(h.get('F22_AG_MODE'), 2)
        self.assertEqual(h.get('F22_AG_INTL_AVAILABLE'), 1)
        self.assertEqual(h.get('F22_AG_INTERLEAVE'), 0)
        h.env.SetCommand(10619, 14.375)
        h.update()
        self.assertEqual(h.get('F22_AG_INTERLEAVE'), 1)
        h.env.SetCommand(10619, 14.25)
        h.update()
        self.assertEqual(h.get('F22_AG_INTERLEAVE'), 1)
        h.env.SetCommand(10619, 14.375)
        h.update()
        self.assertEqual(h.get('F22_AG_INTERLEAVE'), 0)
        self.assertEqual(h.get('F22_AESA_CONTROL_SURFACE'), 1)

    def test_new_target_after_ag_entry_gets_actual_search_and_current_tactical_track(self):
        h = system_host()
        bridge = OwnerBridge()
        initial, late = set(), set()
        observed_surface = False
        try:
            for tick in range(801):
                now = tick*.02
                if tick == 50:
                    h.seed({'HUD_MODE': 7})
                dwells, surface = bridge.step(h, now)
                if now < 1:
                    initial.update(sources(h))
                if now > 2:
                    for row in range(1, 65):
                        prefix = f'F22_RADAR_TACTICAL_{row:02}_'
                        if h.get(prefix+'VALID') == 1 and h.get(prefix+'E') > 3000:
                            source = h.get(prefix+'SOURCE')
                            self.assertNotIn(source, initial)
                            self.assertGreaterEqual(now-h.get(prefix+'AGE'), 2)
                            self.assertLess(now-h.get(prefix+'AGE'), now)
                            late.add(source)
                    observed_surface |= surface > 0
                if h.get('HUD_MODE') == 7:
                    self.assertEqual(h.get('F22_AESA_CONTROL_SURFACE'), 1)
                    self.assertEqual(h.get('F22_AESA_CONTROL_FC_TARGET'), 0)
                    self.assertEqual(h.get('F22_RADAR_STT_VALID'), 0)
                self.assertLessEqual(h.get('TEST_ALLOCATED_SECONDS'), now+.02000001)
            self.assertTrue(initial, 'Initial actual native air search never detected the first object')
            self.assertTrue(observed_surface, 'No completed surface RF job occurred in ground role')
            self.assertTrue(late, 'No new source entered the actual tactical owner after AG entry')
            current = sources(h)
            self.assertTrue(any(source in current and current[source] < .8 for source in late))
            self.assertEqual(h.get('F22_RADAR_AIR_SURFACE_CONCURRENT'), 1)
            self.assertGreater(h.get('F22_AESA_SEARCH_DWELLS'), 0)
            self.assertGreater(h.get('F22_AESA_TRACK_DWELLS'), 0)
        finally:
            bridge.close()

    def test_source_epoch_retires_old_air_reports_while_ground_role_remains(self):
        h = system_host()
        h.seed({'HUD_MODE': 7})
        bridge = OwnerBridge()
        try:
            for tick in range(150):
                bridge.step(h, tick*.02)
            old = set(sources(h))
            self.assertTrue(old)
            bridge.advance_source_epoch()
            bridge.step(h, 3)
            bridge.step(h, 3.02)
            self.assertEqual(h.get('F22_RADAR_TACTICAL_SOURCE_EPOCH'), 2)
            self.assertFalse(set(sources(h)) & old)
            for tick in range(152, 220):
                bridge.step(h, tick*.02)
            self.assertTrue(sources(h))
            self.assertFalse(set(sources(h)) & old)
            self.assertEqual(h.get('F22_AESA_CONTROL_SURFACE'), 1)
            for age in sources(h).values():
                self.assertGreaterEqual(4.38-age, 3)
        finally:
            bridge.close()

    def test_silence_power_and_epoch_withdraw_then_new_measurements_recover(self):
        h = system_host()
        h.seed({'HUD_MODE': 7})
        bridge = OwnerBridge()
        try:
            for tick in range(700):
                bridge.step(h, tick*.02)
            self.assertTrue(sources(h))
            h.env.SetCommand(10638, 1)  # A/G SIL, entire shared array quiet.
            bridge.step(h, 14)
            self.assertEqual(h.get('F22_AESA_CONTROL_EMIT'), 0)
            self.assertEqual(h.get('F22_RADAR_AIR_SURFACE_CONCURRENT'), 0)
            bridge.step(h, 14.02)
            self.assertEqual(h.get('F22_AESA_READY'), 0)
            old = set(sources(h))
            h.env.SetCommand(10638, 1)
            for tick in range(702, 1500):
                bridge.step(h, tick*.02)
            self.assertTrue(set(sources(h))-old)
            h.seed({'MAIN_POWER': 0})
            bridge.step(h, 30)
            self.assertEqual(h.get('F22_AESA_REQUEST'), 0)
            bridge.step(h, 30.02)
            self.assertFalse(sources(h))
            self.assertEqual(h.get('F22_RADAR_AIR_SURFACE_CONCURRENT'), 0)
        finally:
            bridge.close()


if __name__ == '__main__':
    unittest.main()

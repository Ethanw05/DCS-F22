"""Actual Lua target producer -> the native reader used by the JDAM payload hook."""
import os
import subprocess
import unittest
from pathlib import Path

from test_radar_target_handoff import guided_handoff


def native_target(h):
    binary = Path(os.environ['F22_RADAR_GROUND_TARGET_EXE'])
    values = {name: value for name, value in h.state['values'].items()
              if name.startswith(('F22_AG_DELIVERY_TARGET_', 'F22_AG_NATIVE_', 'F22_AG_DESIGNATION_'))
              and isinstance(value, (int, float))}
    if len(values) > 256:
        raise AssertionError('Target test port capacity exceeded')
    fields = ' '.join(f'{name} {value:.17g}' for name, value in values.items())
    packet = f'{h.state.time:.17g} {len(values)} {fields}\n'
    result = subprocess.run([str(binary), '--packet'], input=packet, text=True,
                            capture_output=True, timeout=10, check=True)
    return tuple(float(value) for value in result.stdout.split())


class JDAMHandoff(unittest.TestCase):
    def test_station_coordinate_reaches_actual_native_target_reader(self):
        h, _ = guided_handoff()
        h.tick()
        self.assertEqual(native_target(h), (1, 2000, 100, 300))
        # A newer receipt retains the deliberately assigned fixed coordinate.
        h.tick()
        self.assertEqual(native_target(h), (1, 2000, 100, 300))

    def test_old_or_incomplete_delivery_tuple_cannot_arm_native_handoff(self):
        h, _ = guided_handoff()
        h.tick()
        self.assertEqual(native_target(h)[0], 1)
        sequence = h.get('F22_AG_DELIVERY_TARGET_PACKET_SEQUENCE')
        h.seed({'F22_AG_DELIVERY_TARGET_PACKET_SEQUENCE': sequence + 1})
        self.assertEqual(native_target(h)[0], 0)
        # The former installed publisher supplied coordinates without this header.
        h.seed({'F22_AG_DELIVERY_TARGET_PACKET_SEQUENCE': 0})
        self.assertEqual(native_target(h)[0], 0)


if __name__ == '__main__':
    unittest.main()

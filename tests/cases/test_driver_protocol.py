"""R-HOOK-003/004: dry-run ports only; never loads an installed hook."""
import unittest
from host import Host, ROOT


class DriverProtocol(unittest.TestCase):
    def driver(self):
        h = Host()
        h.env.DRIVER_PATH = str(ROOT / 'tools/diagnostics/BoundedDriver.lua')
        h.execute('driver=dofile(DRIVER_PATH).new(function(c,v) dispatch_action(nil,c,v) end)')
        return h

    def test_explicit_enable_and_request_capacity(self):
        h = self.driver()
        self.assertFalse(h.execute('return driver:start(1,0,false)'))
        self.assertFalse(h.execute('return driver:request(22,1,1)'))
        self.assertTrue(h.execute('return driver:start(1,0,true)'))
        for _ in range(64):
            self.assertTrue(h.execute('return driver:request(22,1,1)'))
        self.assertFalse(h.execute('return driver:request(22,1,1)'))
        self.assertEqual(len(h.state.actions), 0)

    def test_pause_rollback_generation_stop_and_deadline_release(self):
        for transition in ['driver:tick(1,0.2,true)', 'driver:tick(1,-1,false)',
                           'driver:tick(2,0.2,false)', 'driver:stop()',
                           'driver:tick(1,1,false)']:
            h = self.driver()
            h.execute('driver:start(1,0,true);driver:request(22,1,1);driver:tick(1,0,false)')
            self.assertEqual(h.state.actions[1].value, 1)
            h.execute(transition)
            self.assertEqual(h.state.actions[2].value, 0)
            h.execute('driver:tick(2,5,false)')
            self.assertEqual(len(h.state.actions), 2)

    def test_hold_limit_and_nonfinite_values(self):
        h = self.driver()
        h.execute('driver:start(1,0,true)')
        for args in ['22,1,2.00001', '22,1,-0.1', '0,1,1', '22,0/0,1', '22,1,math.huge']:
            self.assertFalse(h.execute('return driver:request('+args+')'))
        self.assertTrue(h.execute('return driver:request(22,1,2)'))
        h.execute('driver:tick(1,0,false);driver:tick(1,1.999,false)')
        self.assertEqual(len(h.state.actions), 1)
        h.execute('driver:tick(1,2,false)')
        self.assertEqual(h.state.actions[2].value, 0)

    def test_outstanding_holds_are_bounded_across_ticks(self):
        h = self.driver()
        h.execute('driver:start(1,0,true)')
        for command in range(1,65):
            self.assertTrue(h.execute(f'return driver:request({command},1,2)'))
        h.execute('driver:tick(1,0,false)')
        self.assertFalse(h.execute('return driver:request(65,1,2)'))


if __name__ == '__main__':
    unittest.main()

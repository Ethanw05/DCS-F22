"""Explicit weapon host ports for R-WPN-001. No legacy fixtures or owner stubs."""
from host import Host


class WeaponHost(Host):
    def __init__(self):
        super().__init__()
        self.env.fixture_values = self.state['values']
        self.execute("""
            -- Native numeric handles begin at zero. None of these zeros qualify
            -- a source: the case supplies every positive authority flag below.
            local declared, acquire = {}, get_param_handle
            function get_param_handle(name)
                if not declared[name] then
                    declared[name]=true
                    if fixture_values[name]==nil then fixture_values[name]=0 end
                end
                return acquire(name)
            end
            draw={}; selected_calls=0; launches=0
            device_state='ready'; selection_state='ready'; station_state='ready'
            payload={[2]={count=2,CLSID='{F22-MK83-TRAINING}',
                weapon={level1=4,level2=5,level3=9,level4=900}}}
            weapon={}
            function weapon:get_station_info(station)
                if station_state=='throw' then error('station service lost') end
                return payload[station] or {count=0}
            end
            function weapon:select_station(station)
                selected_calls=selected_calls+1
                if selection_state=='throw' then error('selection service lost') end
                if selection_state=='reject' then return false end
                native_station=station
            end
            function weapon:launch_station(station)
                launches=launches+1
                launched_station=station
                if launch_state=='throw' then error('uncertain native outcome') end
                if launch_state=='reject' then return false end
            end
            function GetDevice(_)
                if device_state=='throw' then error('device unavailable') end
                if device_state=='missing' then return nil end
                return weapon
            end
            function get_aircraft_property(_) return 1 end
            function get_aircraft_draw_argument_value(arg) return draw[arg] or 0 end
            function set_aircraft_draw_argument_value(arg,value) draw[arg]=value end
        """)
        self.seed({'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
                   'EFM_PHYSICAL_GENERATION': 3, 'EFM_PHYSICAL_STAMP': 10,
                   'EFM_PHYSICAL_CLOCK_KIND': 1, 'F22_AP_CLOCK': 10,
                   'EFM_UTILITY_AVAILABLE': 1, 'EFM_MISSION_POWER_AVAILABLE': 1,
                   'F22_ELECTRICAL_VALID': 1, 'MAIN_POWER': 1, 'WoW': 0,
                   'F22_AG_RELEASE_SEQUENCE': 0})
        self.state.time = 10
        self.load('Systems/Weapon_System.lua')
        self.env.post_initialize()
        self.command(10800, 7)
        self.command(10007, 1)
        self.tick()

    def command(self, command, value):
        self.env.SetCommand(command, value)

    def tick(self, seconds=.02, solve=False):
        self.state.time += seconds
        self.seed({'EFM_PHYSICAL_STAMP': self.state.time,
                   'F22_AP_CLOCK': self.state.time})
        if solve:
            self.seed({'F22_AG_SOLUTION_VALID': 1, 'F22_AG_SOLUTION_SCHEMA': 2,
                       'F22_AG_SOLUTION_TIME': self.state.time,
                       'F22_AG_SOLUTION_STATION': 2})
        self.update()
        # The port's bounded action ledger observes each callback independently.
        self.state.actions = self.lua.table()

    def request(self):
        self.command(10803, 1)
        for _ in range(30):
            self.tick(solve=True)
            if self.env.launches:
                break
        assert self.env.launches == 1, 'Fixture did not reach actual launch owner'

    def shot(self, sequence=1, station=2, kind=900, identity=71):
        self.seed({'F22_LAUNCH_SEQUENCE': sequence, 'F22_SHOT_01_SEQUENCE': sequence,
                   'F22_SHOT_01_ID': identity, 'F22_SHOT_01_STATION': station,
                   'F22_SHOT_01_MODE': 7, 'F22_SHOT_01_TYPE': kind,
                   'F22_SHOT_01_TIME': self.state.time})

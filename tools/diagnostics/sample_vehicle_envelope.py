"""Matched-state DLL bench grid; forces are sampled, never integrated as flight.

Uses only an explicitly supplied test CockpitBase and EFM DLL. It neither
installs a mod nor finds/starts/stops DCS. All atmosphere/attitude/contact inputs
are declared. Performance residuals from this synthetic fixture are calibration
data, not demonstrated F-22 climb, turn, cruise or landing performance.
"""
import argparse
import csv
import ctypes as C
import hashlib
import itertools
import json
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def signature(module, name, count, result=None, args=None):
    function = getattr(module, name)
    function.argtypes = args if args is not None else [C.c_double] * count
    function.restype = result
    return function

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cockpit', type=Path, required=True)
    parser.add_argument('--efm', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    cockpit = C.CDLL(str(args.cockpit.resolve()))
    handle = signature(cockpit, 'ed_cockpit_get_parameter_handle', 1, C.c_void_p, [C.c_char_p])
    read = signature(cockpit, 'ed_cockpit_parameter_value_to_number', 3, C.c_bool,
                     [C.c_void_p, C.POINTER(C.c_double), C.c_bool])
    fm = C.CDLL(str(args.efm.resolve()))
    air = signature(fm, 'ed_fm_hot_start_in_air', 0)
    release = signature(fm, 'ed_fm_release', 0)
    simulate = signature(fm, 'ed_fm_simulate', 1)
    fuel = signature(fm, 'ed_fm_set_internal_fuel', 1)
    unlimited = signature(fm, 'ed_fm_unlimited_fuel', 1, args=[C.c_bool])
    atmosphere = signature(fm, 'ed_fm_set_atmosphere', 8)
    mass = signature(fm, 'ed_fm_set_current_mass_state', 7)
    world = signature(fm, 'ed_fm_set_current_state', 19)
    body = signature(fm, 'ed_fm_set_current_state_body_axis', 20)
    surface = signature(fm, 'ed_fm_set_surface', 6,
                        args=[C.c_double, C.c_double, C.c_uint, C.c_double, C.c_double, C.c_double])
    command = signature(fm, 'ed_fm_set_command', 2, args=[C.c_int, C.c_float])
    force = signature(fm, 'ed_fm_add_local_force', 6, args=[C.POINTER(C.c_double)] * 6)
    moment = signature(fm, 'ed_fm_add_local_moment', 3, args=[C.POINTER(C.c_double)] * 3)
    channels = ['EFM_FORCE_VALID', 'EFM_MASS_VALID', 'EFM_ENGINE_LEFT_THRUST_N',
                'EFM_ENGINE_RIGHT_THRUST_N', 'EFM_TOTAL_FUEL_FLOW_KG_S', 'EFM_TRIM_LEFT_DEG',
                'EFM_TRIM_RIGHT_DEG', 'EFM_TVC_LEFT_DEG', 'EFM_TVC_RIGHT_DEG']
    handles = {name: handle(name.encode()) for name in channels}
    def get(name):
        value = C.c_double()
        if not read(handles[name], C.byref(value), False):
            raise RuntimeError('Invalid parameter: ' + name)
        return value.value
    rows = []
    settings = [('IDLE',0.0), ('DRY',.355/.43), ('AB',1.0)]
    grid = itertools.product([22000.0,27900.0], [0.0,10000.0],
                             [.3,.8,1.2,1.6,2.0,2.4], settings, [0.0,12.0], [-.2,.2])
    for total_mass, altitude, mach, setting, alpha_deg, cg_x in grid:
        air()
        fuel(total_mass - 19700.0)
        unlimited(True)
        temperature = 288.15 - .0065 * altitude
        pressure = 101325.0 * (temperature/288.15) ** 5.25588
        density = pressure / (287.05287 * temperature)
        sound = math.sqrt(1.4 * 287.05287 * temperature)
        speed = mach * sound
        alpha = math.radians(alpha_deg)
        atmosphere(altitude,temperature,sound,density,pressure,0,0,0)
        surface(-1000,0,0,0,1,0)  # explicit 1000+ m ground clearance, no contact
        mass(total_mass,cg_x,0,0,100000,150000,120000)
        world(0,0,0,speed,0,0,0,altitude,0,0,0,0,0,0,0,0,0,math.sin(alpha/2),math.cos(alpha/2))
        body(0,0,0,speed*math.cos(alpha),-speed*math.sin(alpha),0,0,0,0,0,0,0,0,0,0,0,alpha,0,alpha,0)
        command(2004,1 - 2*setting[1])
        for _ in range(800):
            simulate(.01)
        f = [C.c_double() for _ in range(6)]
        m = [C.c_double() for _ in range(3)]
        force(*(C.byref(value) for value in f))
        moment(*(C.byref(value) for value in m))
        fx,fy,fz = [value.value for value in f[:3]]
        excess_power_w = speed * (fx*math.cos(alpha) - fy*math.sin(alpha))
        row = dict(mass_kg=total_mass, internal_fuel_kg=total_mass-19700.0, cg_x_m=cg_x,
                   altitude_m=altitude, temperature_k=temperature, pressure_pa=pressure,
                   density_kg_m3=density, wind_mps=0, mach=mach, tas_mps=speed,
                   aoa_deg=alpha_deg, gear=0, external_stores=0, throttle=setting[0],
                   fx_n=fx, fy_n=fy, fz_n=fz, pitch_moment_nm=m[2].value,
                   excess_power_w=excess_power_w,
                   specific_excess_power_mps=excess_power_w/(total_mass*9.80665))
        row.update({name: get(name) for name in channels})
        if row['EFM_FORCE_VALID'] != 1 or row['EFM_MASS_VALID'] != 1:
            raise RuntimeError('Invalid bench condition: ' + str(row))
        rows.append(row)
    release()
    with (args.output/'callback-envelope.csv').open('w',newline='',encoding='utf-8') as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    metadata = dict(kind='fixed-state callback bench, not DCS flight qualification', samples=len(rows),
                    source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                    empty_mass_kg=19700, inertia_kgm2=[100000,150000,120000],
                    atmosphere='tropospheric ISA estimate through 10km',
                    contact=False, ground_effect='not added; native ownership unqualified',
                    coefficients='legacy/estimated F-22 mod deck, no production calibration',
                    efm_sha256=hashlib.sha256(args.efm.read_bytes()).hexdigest(),
                    case_duration_s=8, dt_s=.01)
    (args.output/'callback-envelope.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
    print(json.dumps(metadata,indent=2))

if __name__ == '__main__':
    main()

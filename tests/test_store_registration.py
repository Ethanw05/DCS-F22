"""Capture real mod payload declarations and validate offered drag/type metadata.

This models declaration data, not the closed DCS registry or qualified rack drag.
"""
from pathlib import Path
import math,re
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().current_mod_path=ROOT.as_posix()
lua.execute('''
weapons={};loadouts={};next_type=1000
WSTYPE_PLACEHOLDER=0;CAT_AIR_TO_AIR=4;CAT_BOMBS=3;CAT_FUEL_TANKS=5;CAT_PODS=6
wsType_Weapon=4;wsType_Missile=4;wsType_AA_Missile=7;wsType_Container=32
wsType_Bomb=5;wsType_Bomb_A=9;wsType_Air=1;wsType_Free_Fall=3;wsType_FuelTank=43
AIM_9_CX_PIL=1.03;Mk_83=32
function _(s)return s end
function predefined_warhead(name)return {name=name}end
function enhanced_a2a_warhead(...)return {}end
function declare_weapon(w)
 local t=w.wsTypeOfWeapon
 if not t[4]or t[4]==0 then next_type=next_type+1;t[4]=next_type end
 weapons[t[4]]=w
end
function declare_loadout(l)assert(not loadouts[l.CLSID],'duplicate CLSID '..l.CLSID);loadouts[l.CLSID]=l end
''')
lua.execute('dofile(current_mod_path.."/Weapons.lua");dofile(current_mod_path.."/VLO Fuel Tank.lua");dofile(current_mod_path.."/IRST Pod.lua")')
loadouts=lua.globals().loadouts
offered=set(re.findall(r'\bCLSID\s*=\s*[\'"]([^\'"]+)',(ROOT/'F-22A.lua').read_text()))
paired={f'{{LAU_115_2xAIM-{variant}}}'for variant in ('120C-7','120C-8','120D-3','260A')}
expected=.000739765625+2*.00061
for clsid in paired:
    table=loadouts[clsid]
    assert table is not None and table['Count']==2 and clsid in offered,clsid
    assert math.isclose(table['Cx_pil'],expected,rel_tol=0,abs_tol=1e-14),(clsid,'stock adapter/AMRAAM proxy missing')
    assert table['Elements'][1]['IsAdapter'] and table['wsTypeOfWeapon'][3]==7

checked=[]
for clsid in offered:
    table=loadouts[clsid]
    if table is None:
        assert not clsid.startswith('{LAU_115_2x'),(clsid,'offered launcher is not actually registered')
        continue  # Vendor-owned native payloads are outside this fixture.
    coefficient=table['Cx_pil']
    if coefficient is None:
        kind=table['wsTypeOfWeapon']or table['attribute']
        weapon=lua.globals().weapons[kind[4]]
        assert weapon is not None,(clsid,'no explicit payload drag or declared weapon fallback')
        coefficient=weapon['Cx_pil']
    assert isinstance(coefficient,(int,float))and math.isfinite(coefficient)and coefficient>=0,(clsid,coefficient)
    checked.append(clsid)
assert len(checked)>=16,checked
print(f'Stores registration: {len(checked)} offered mod payloads have nonnegative explicit/declared-weapon drag; four external paired launchers have explicit stock-rack proxy and valid count/type; offered launcher CLSIDs resolve PASS')

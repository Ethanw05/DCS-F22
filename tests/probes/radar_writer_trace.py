"""Emit the actual Lua writer order for the independently specified C++ tuples."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from host import Host, ROOT


def identity():
    names=('Radar_Tactical.lua','Radar_Computer.lua','Radar_Track_Metadata.lua')
    return {f'Cockpit/Scripts/Systems/{name}':hashlib.sha256(
        (ROOT/'Cockpit/Scripts/Systems'/name).read_bytes()).hexdigest() for name in names}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    output=args.output.resolve()
    if output==ROOT or ROOT in output.parents:
        parser.error('Trace output must be outside the aircraft checkout')
    before=identity()
    h=Host()
    h.execute("publisher=dofile(LockOn_Options.script_path..'Systems/Radar_Tactical.lua');"
        "computer=dofile(LockOn_Options.script_path..'Systems/Radar_Computer.lua').new();"
        "computer.power=true;computer.clock=10;computer.tracks[1]={id=1,native_id=84,"
        "observed=9.5,north=1000,altitude=2000,east=3000,vn=10,vu=20,ve=30,"
        "measurement_source=2,hits=3,association_valid=true,velocity_valid=true,filter_valid=true,"
        "position_sigma_m=1,velocity_sigma_mps=2,range=5000,az=0,el=0,ident_time=7,iff=1}")
    lines=[]
    def record(stage):
        def put(key,value):
            h.state['values'][key]=value
            if isinstance(value,(float,int)):
                lines.append(f'{stage} {key} {value:.17g}')
        h.env.record=put
    record('old')
    h.execute('publisher.publish(computer,record,true,nil,1)')
    h.execute('computer.clock=10.1;local t=computer.tracks[1];t.native_id=88;'
        't.north=4000;t.altitude=5000;t.east=6000;t.vn=-10;t.vu=5;t.ve=20;'
        't.observed=10;t.ident_time=nil;t.iff=-1')
    record('new')
    h.execute('publisher.publish(computer,record,true,nil,2)')
    after=identity()
    if before!=after:
        raise RuntimeError('Writer source changed during trace capture')
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    manifest=dict(producer_sources=before,source_stable=True,numeric_writes=len(lines),
        trace=str(output),trace_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
        scope='Actual Lua callback order; modeled preemption, no DCS scheduling claim')
    output.with_suffix('.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))


if __name__=='__main__':
    main()

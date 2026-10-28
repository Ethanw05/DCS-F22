"""Archive the dedicated EW flight and summarize observed effects, never commands as proof."""
import argparse
import collections
import datetime
import json
import math
from pathlib import Path
import statistics
import time


def number(value):
    try:
        result=float(value)
        return result if math.isfinite(result) else None
    except (TypeError, ValueError):
        return None


def distribution(values):
    good=[value for value in values if value is not None]
    return dict(count=len(good),minimum=min(good),median=statistics.median(good),maximum=max(good)) if good else None


class Trial:
    def __init__(self):
        self.schemas={}
        self.active=False
        self.complete=False
        self.end_reason=None
        self.phase='BASELINE'
        self.samples=collections.defaultdict(list)
        self.own=[]
        self.radars=[]
        self.errors=[]
        self.measurements=[]
        self.commands=[]

    def line(self, line):
        marker='F22_EW_TRIAL|'
        if marker in line:
            cells=line.split(marker,1)[1].strip().split('|')
            kind=cells[0]
            if kind in ('START','HOOK_START'):
                self.active=True
            if not self.active:
                return
            if kind=='PHASE' and len(cells)>2:
                self.phase=cells[2]
            elif kind=='OWN_ECM':
                self.own.append(cells[1:])
            elif kind=='RADAR':
                self.radars.append(cells[1:])
            elif kind in ('ERROR','HOOK_ERROR'):
                self.errors.append(cells[1:])
            elif kind in ('JAM_COMMAND','PLAYER_COMMAND','COCKPIT_COMMAND','COCKPIT_SETUP'):
                self.commands.append([kind]+cells[1:])
            elif kind in ('HOOK_STOP','END'):
                self.complete=True
                self.end_reason=kind
            return
        marker='F22_RADAR_TEST (Main): '
        if marker not in line:
            return
        cells=line.split(marker,1)[1].strip().split(',')
        if len(cells)<3:
            return
        kind=cells[1]
        names={'service_schema':'service','aesa_schema':'aesa','avionics_schema':'avionics_sample'}
        if kind in names:
            self.schemas[names[kind]]=cells[2:]
        elif self.active and kind in self.schemas:
            row=dict(zip(self.schemas[kind],map(number,cells[2:])))
            if kind=='service' and len(self.samples[self.phase])<10000:
                self.samples[self.phase].append(row)
            elif kind=='aesa' and len(self.measurements)<100000:
                self.measurements.append(row)
        if self.active and '=== Log closed.' in line:
            self.complete=True

    def result(self):
        phases={}
        for name, rows in self.samples.items():
            values=lambda key:[row.get(key) for row in rows]
            phases[name]=dict(samples=len(rows),receiver_known=sum(row.get('F22_AESA_INTERFERENCE_VALID')==1 for row in rows),
                noise_jnr=distribution(values('F22_AESA_INTERFERENCE_JNR')),
                tracks=distribution(values('F22_AESA_COUNT')))
        known_own=[row for row in self.own if len(row)>2 and row[1]=='1']
        own_on=sum(row[2] in ('true','1') for row in known_own)
        own_off=sum(row[2] in ('false','0') for row in known_own)
        received=[row for rows in self.samples.values() for row in rows]
        response=sum((row.get('F22_AESA_INTERFERENCE_JNR') or 0)>0 and row.get('F22_AESA_INTERFERENCE_VALID')==1 for row in received)
        return dict(status='complete' if self.complete else 'recording' if self.active else 'waiting_for_EW_mission',end_reason=self.end_reason,
            phases=phases,incoming_jam_response_samples=response,
            own_host_enabled_samples=own_on,own_host_disabled_samples=own_off,
            own_export_jamming_values=sorted({row[3] for row in known_own if len(row)>3}),
            enemy_radar_records=len(self.radars),radar_records=self.radars[-2400:],
            measurement_count=len(self.measurements),
            range_sigma_m=distribution([row.get('RANGE_SIGMA_M') for row in self.measurements]),
            future_measurements=sum(row.get('TIME') is not None and row.get('t_model_s') is not None
                and row['TIME']>row['t_model_s']+.01 for row in self.measurements),
            commands=self.commands[-200:],errors=self.errors[-100:],
            limits=['Host ECM enabled/command success is not independent RF transmission proof.',
                    'Radar detection/lock comparisons require matched geometry and range; raw records are retained.',
                    'Missing phases or missing receiver response are unqualified, not a pass.',
                    'Incoming interference uses the documented estimated equivalent-noise model.'])


def save(trial, directory):
    result=trial.result()
    directory.mkdir(parents=True,exist_ok=True)
    target=directory/'results.json'
    temporary=directory/'results.pending.json'
    temporary.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    temporary.replace(target)
    lines=['# F-22 EW flight results','',f'Status: {result["status"]}',
        f'Incoming interference response samples: {result["incoming_jam_response_samples"]}',
        f'Own host ECM ON/OFF samples: {result["own_host_enabled_samples"]}/{result["own_host_disabled_samples"]}',
        f'Enemy radar records: {result["enemy_radar_records"]}',
        f'Radar measurement packets: {result["measurement_count"]}',
        f'Future-dated measurement packets: {result["future_measurements"]}','',
        '| Phase | Samples | Receiver known | Median J/N |','| --- | ---: | ---: | ---: |']
    for name,phase in result['phases'].items():
        noise=phase['noise_jnr']
        lines.append(f'| {name} | {phase["samples"]} | {phase["receiver_known"]} | {noise["median"] if noise else "unknown"} |')
    lines+=['','Limits:']+['- '+limit for limit in result['limits']]
    if result['errors']:
        lines+=['','Recorded harness errors:','```',json.dumps(result['errors'],indent=2),'```']
    (directory/'results.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log',type=Path)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--watch',action='store_true')
    args=parser.parse_args()
    trial=Trial();offset=0;pending=b'';deadline=time.monotonic()+14400
    args.out.mkdir(parents=True,exist_ok=True)
    (args.out/'watcher.json').write_text(json.dumps(dict(started=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        log=str(args.log),watch=args.watch),indent=2),encoding='utf-8')
    with (args.out/'flight-evidence.log').open('a',encoding='utf-8') as archive:
        while time.monotonic()<deadline:
            if args.log.exists():
                if args.log.stat().st_size<offset:
                    if trial.active:
                        trial.complete=True;trial.end_reason='session_log_rotated';save(trial,args.out);return
                    offset=0;pending=b'';trial=Trial()
                with args.log.open('rb') as source:
                    source.seek(offset)
                    block=pending+source.read(16*1024*1024)
                    offset=source.tell()
                cut=block.rfind(b'\n')
                pending=block[cut+1:]
                if len(pending)>2*1024*1024:raise RuntimeError('Unexpected oversized log record')
                for line in block[:cut+1].decode('utf-8',errors='replace').splitlines():
                    trial.line(line)
                    if trial.active and ('F22_RADAR_TEST' in line or 'F22_EW_TRIAL' in line):
                        archive.write(line+'\n')
                    if trial.active and '=== Log closed.' in line:
                        trial.complete=True;trial.end_reason='session_closed'
                archive.flush()
            result=save(trial,args.out)
            if trial.complete or not args.watch:
                print(json.dumps({key:value for key,value in result.items() if key not in ('radar_records','commands')},indent=2))
                return
            time.sleep(10)
    result=save(trial,args.out)
    (args.out/'watcher-ended.json').write_text(json.dumps(dict(reason='four_hour_limit',status=result['status'])),encoding='utf-8')


if __name__=='__main__':
    main()

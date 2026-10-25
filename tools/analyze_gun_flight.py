"""Score logged predictions against subsequently observed positions of the SAME target.
Actual-endpoint values are ideal native ballistic candidates, not observed bullet tracks.
"""
import argparse,bisect,csv,math,statistics
from pathlib import Path

def load(path):
 rows=[];schema=None;segment=0
 for line in Path(path).read_text(encoding='utf8',errors='replace').splitlines():
  at=line.find('v1,')
  if at<0:continue
  parts=next(csv.reader([line[at:]]))
  if parts[1]=='segment':segment+=1;schema=None
  elif parts[1]=='schema':schema=parts[2:]
  elif parts[1]=='sample'and schema:
   if len(parts[2:])!=len(schema):continue
   try:r=dict(zip(schema,map(float,parts[2:])))
   except ValueError:continue
   r['segment']=segment;rows.append(r)
 return rows

def score(rows):
 tracks={}
 for r in rows:
  if r.get('F22_STT_MOTION_VALID',0)<.5:continue
  key=(r['segment'],r.get('F22_STT_ID'));t=r.get('F22_STT_TIME',math.nan)
  p=tuple(r.get('F22_STT_P'+axis,math.nan)for axis in ('N','U','E'))
  if math.isfinite(t)and all(map(math.isfinite,p)):tracks.setdefault(key,{})[t]=p
 lookup={k:(sorted(v),v)for k,v in tracks.items()}
 scored=[];seen=set()
 for r in rows:
  if r.get('F22_GUN_USING_DIRECTOR',0)<.5:continue
  stamp=r.get('F22_GUN_RESULT_TIME',math.nan);identity=r.get('F22_GUN_RESULT_TRACK_ID',math.nan)
  key=(r['segment'],identity);unique=(key,stamp)
  if unique in seen or key not in lookup:continue
  seen.add(unique);tof=r.get('F22_GUN_TOF',math.nan);time=stamp+tof
  if not math.isfinite(time)or tof<=0 or tof>4:continue
  times,points=lookup[key];i=bisect.bisect_left(times,time)
  if i==0 or i==len(times):continue
  lo,hi=times[i-1],times[i]
  if hi-lo>.16:continue
  alpha=(time-lo)/(hi-lo);truth=[points[lo][k]*(1-alpha)+points[hi][k]*alpha for k in range(3)]
  def distance(prefix):
   p=[r.get(prefix+axis,math.nan)for axis in ('N','U','E')]
   return math.dist(p,truth)if all(map(math.isfinite,p))else math.nan
  turn=distance('F22_GUN_PREDICTED_')
  horizon=tof+r.get('F22_GUN_MEASUREMENT_AGE',math.nan)
  ca=[r.get('F22_GUN_TARGET_'+axis,math.nan)+r.get('F22_GUN_V'+axis,math.nan)*horizon+.5*r.get('F22_GUN_A'+axis,math.nan)*horizon*horizon for axis in ('N','U','E')]
  fixed=math.dist(ca,truth)
  if not math.isfinite(turn)or not math.isfinite(fixed):continue
  bore=distance('F22_GUN_ACTUAL_END_')if r.get('F22_GUN_ACTUAL_ENDPOINT_VALID',0)>.5 else math.nan
  scored.append({'time':stamp,'target':identity,'tof':tof,'prediction_miss_m':turn,'fixed_accel_prediction_miss_m':fixed,
   'ideal_bore_endpoint_miss_m':bore,'trigger_requested':r.get('HUD_GUN_TRIGGER',0)>.5})
 return scored

def report(rows,scored):
 lines=['# Gun flight-data review','',f'Logged samples: {len(rows)}. Comparable future-target observations: {len(scored)}.','']
 if not scored:return '\n'.join(lines+['No score yet. Need the new logging fields, a valid computed solution, and continuous tracking beyond bullet flight time.'])
 lines+=['| Quantity | Mean (m) | P90 (m) | Worst (m) |','|---|---:|---:|---:|']
 for label,key in [('Turn-model position prediction','prediction_miss_m'),('Fixed-acceleration position prediction, same horizon','fixed_accel_prediction_miss_m'),('Ideal trajectory along actual bore, includes pilot aiming','ideal_bore_endpoint_miss_m')]:
  v=sorted(s[key]for s in scored if math.isfinite(s[key]))
  if v:lines.append(f'| {label} | {statistics.mean(v):.3f} | {v[int((len(v)-1)*.9)]:.3f} | {max(v):.3f} |')
 lines+=['',f"Samples with trigger request: {sum(s['trigger_requested']for s in scored)}.",
 '','These are comparisons with later logged positions of the same target. The endpoint is a native ideal trajectory candidate at solve time; it is not a measured individual round or a hit report. Trigger request is not proof of firing. Target switches, missing later observations and long sampling gaps are excluded. Fixed-acceleration comparison shares the new computed flight-time horizon; it does not reproduce complete Hornet/F-15 avionics.']
 return '\n'.join(lines)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('log',type=Path);ap.add_argument('--output',type=Path);a=ap.parse_args()
 rows=load(a.log);scored=score(rows);text=report(rows,scored)
 if a.output:a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(text,encoding='utf8')
 print(text)
if __name__=='__main__':main()

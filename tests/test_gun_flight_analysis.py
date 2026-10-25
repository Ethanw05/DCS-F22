from pathlib import Path
import importlib.util,math
p=Path(__file__).resolve().parents[1]/'tools/analyze_gun_flight.py'
spec=importlib.util.spec_from_file_location('gun_flight',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
rows=[]
for i in range(41):
 t=i*.05;r={'segment':1,'t_model_s':t,'F22_STT_MOTION_VALID':1,'F22_STT_ID':42,'F22_STT_TIME':t,
 'F22_STT_PN':1000+100*t,'F22_STT_PU':5000,'F22_STT_PE':0}
 if i==0:
  r.update(F22_GUN_USING_DIRECTOR=1,F22_GUN_RESULT_TIME=0,F22_GUN_RESULT_TRACK_ID=42,F22_GUN_TOF=1,F22_GUN_MEASUREMENT_AGE=0,
   F22_GUN_PREDICTED_N=1100,F22_GUN_PREDICTED_U=5000,F22_GUN_PREDICTED_E=0,
   F22_GUN_TARGET_N=1000,F22_GUN_TARGET_U=5000,F22_GUN_TARGET_E=0,
   F22_GUN_VN=100,F22_GUN_VU=0,F22_GUN_VE=0,F22_GUN_AN=0,F22_GUN_AU=0,F22_GUN_AE=0,
   F22_GUN_ACTUAL_ENDPOINT_VALID=1,F22_GUN_ACTUAL_END_N=1100,F22_GUN_ACTUAL_END_U=5000,F22_GUN_ACTUAL_END_E=3)
 rows.append(r)
a=m.score(rows);assert len(a)==1 and a[0]['prediction_miss_m']==0 and a[0]['fixed_accel_prediction_miss_m']==0
assert abs(a[0]['ideal_bore_endpoint_miss_m']-3)<1e-8
for r in rows[10:]:r['F22_STT_ID']=43
assert not m.score(rows),'must not compare a prediction with another target'
print('Flight-data scoring: future interpolation, target identity, position-prediction and ideal-bore errors OK')

"""Render declared callback-bench residuals; no flight-performance inference."""
import argparse
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
from matplotlib import pyplot as plt

parser = argparse.ArgumentParser()
parser.add_argument('directory', type=Path)
args = parser.parse_args()
with (args.directory/'callback-envelope.csv').open(encoding='utf-8',newline='') as stream:
    rows = list(csv.DictReader(stream))
rows = [row for row in rows if float(row['mass_kg'])==27900 and
        float(row['altitude_m'])==10000 and float(row['aoa_deg'])==0 and float(row['cg_x_m'])==.2]
figure, axes = plt.subplots(1,3,figsize=(12,4),layout='constrained')
for setting, color in [('IDLE','#64748b'),('DRY','#2563eb'),('AB','#dc2626')]:
    selected = sorted((row for row in rows if row['throttle']==setting), key=lambda row: float(row['mach']))
    mach = [float(row['mach']) for row in selected]
    thrust = [(float(row['EFM_ENGINE_LEFT_THRUST_N'])+float(row['EFM_ENGINE_RIGHT_THRUST_N']))/1000 for row in selected]
    power = [float(row['specific_excess_power_mps']) for row in selected]
    flow = [float(row['EFM_TOTAL_FUEL_FLOW_KG_S']) for row in selected]
    for axis, values in zip(axes,[thrust,power,flow]):
        axis.plot(mach,values,marker='o',label=setting,color=color,linewidth=1.8)
for axis, title in zip(axes,['Combined thrust (kN)','Specific excess power (m/s)','Total delivered fuel flow (kg/s)']):
    axis.set_title(title,fontsize=10)
    axis.set_xlabel('Mach')
    axis.grid(alpha=.2)
axes[1].axhline(0,color='#111827',linewidth=.8)
axes[0].legend(frameon=False)
figure.suptitle('Estimated mod deck: fixed-state DLL bench, 27,900 kg / 10 km / AoA 0 deg\nNo DCS flight integration or production F-22 performance validation',fontsize=11)
figure.savefig(args.directory/'callback-envelope.png',dpi=160)
print(args.directory/'callback-envelope.png')

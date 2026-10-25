"""Generate our original pulsed missile-warning tone; no aircraft recordings."""
from pathlib import Path
import math,struct,wave
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'Sounds/Effects/Aircrafts/F-22A/MWS/approach.wav'
out.parent.mkdir(parents=True,exist_ok=True)
rate=44100
frames=[]
for i in range(int(rate*.8)):
    t=i/rate;beat=int(t/.2);local=t% .2
    envelope=min(1,local/.006,max(0,(.12-local)/.006)) if local<.12 else 0
    f=1100 if beat%2==0 else 1600
    signal=.32*envelope*(.8*math.sin(2*math.pi*f*t)+.2*math.sin(2*math.pi*2*f*t))
    frames.append(struct.pack('<h',round(signal*32767)))
with wave.open(str(out),'wb')as wav:
    wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(rate);wav.writeframes(b''.join(frames))
print('Generated original MWS tone:',out)

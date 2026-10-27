"""Generate original warning speech with eSpeak NG's formant synthesizer.

Development tool only. Pass a local upstream libespeak-ng.dll and the directory
containing espeak-ng-data. No synthesizer executable/voice is required in DCS.
No recordings, protected aircraft audio or trained voice models are used.
"""
from pathlib import Path
import argparse
import ctypes as C
import struct
import wave

parser=argparse.ArgumentParser()
parser.add_argument('--library',type=Path,required=True)
parser.add_argument('--data',type=Path,required=True)
parser.add_argument('--only',help='Generate only this warning without rewriting other assets')
args=parser.parse_args()
engine=C.CDLL(str(args.library.resolve()))
engine.espeak_Initialize.argtypes=[C.c_int,C.c_int,C.c_char_p,C.c_int]
engine.espeak_Initialize.restype=C.c_int
rate=engine.espeak_Initialize(2,0,str(args.data.resolve()).encode('utf-8'),0)
assert rate>0,'eSpeak initialization failed'
engine.espeak_SetVoiceByName.argtypes=[C.c_char_p]
assert engine.espeak_SetVoiceByName(b'en-us+f3')==0
engine.espeak_SetParameter(1,165,0)
engine.espeak_SetParameter(3,48,0)
engine.espeak_SetParameter(4,25,0)
callback_type=C.CFUNCTYPE(C.c_int,C.POINTER(C.c_short),C.c_int,C.c_void_p)
chunks=[]
@callback_type
def receive(samples,count,events):
    if samples and count>0:chunks.append(C.string_at(samples,count*2))
    return 0
engine.espeak_SetSynthCallback.argtypes=[callback_type]
engine.espeak_SetSynthCallback(receive)
engine.espeak_Synth.argtypes=[C.c_void_p,C.c_size_t,C.c_uint,C.c_int,C.c_uint,C.c_uint,C.POINTER(C.c_uint),C.c_void_p]
root=Path(__file__).resolve().parents[1]
for name,text in {'pull_up':'Pull up. Pull up.','roll_left':'Roll left. Roll left.',
    'roll_right':'Roll right. Roll right.','altitude':'Altitude. Altitude.',
    'flight_controls':'Flight controls.','caution':'Caution.','terrain':'Terrain. Terrain.'}.items():
    if args.only and name!=args.only:continue
    chunks.clear();data=C.create_string_buffer(text.encode());identifier=C.c_uint()
    assert engine.espeak_Synth(data,len(data),0,1,0,1,C.byref(identifier),None)==0
    engine.espeak_Synchronize()
    raw=b''.join(chunks);samples=struct.unpack('<'+'h'*(len(raw)//2),raw)
    peak=max(abs(x)for x in samples);gain=.50*32767/max(1,peak)
    pcm=struct.pack('<'+'h'*len(samples),*(round(x*gain)for x in samples))
    output=root/'Sounds/Effects/Aircrafts/F-22A/Warnings'/f'{name}.wav'
    output.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(output),'wb')as wav:
        wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(rate);wav.writeframes(pcm)
    sdef=root/'Sounds/sdef/Aircrafts/F-22A/Warnings'/f'{name}.sdef'
    sdef.parent.mkdir(parents=True,exist_ok=True)
    sdef.write_text(f'wave = "Effects/Aircrafts/F-22A/Warnings/{name}"\ninner_radius = 1\nouter_radius = 10\ngain = 1.0\n')
    print(name,round(len(samples)/rate,2),'seconds')
engine.espeak_Terminate()

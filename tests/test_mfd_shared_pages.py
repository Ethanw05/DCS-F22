"""Snapshot guards for the original shared pages and intentional native NAV format."""
from pathlib import Path
import hashlib,json,sys
from lupa import lua_type
from test_display_startup import runtime
ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/'tests/fixtures/mfd_page_elements.json'
def convert(value):
 if lua_type(value)=='table':return{str(k):convert(v)for k,v in value.items()}
 if callable(value):return '<native function>'
 return value
actual={}
for panel in ('LEFT','RIGHT','CENTER'):
 for page in ('hsi','fuel','adi','checklist'):
  lua=runtime();lua.execute("dofile('common/elements_defs.lua')")
  path=f'MFD_{panel}/{page}_page.lua'
  lua.execute(f"dofile(SCRIPT_ROOT..'{path}')")
  elements=convert(lua.globals().elements)
  encoded=json.dumps(elements,sort_keys=True,separators=(',',':')).encode()
  actual[path]={'elements':len(lua.globals().elements),'sha256':hashlib.sha256(encoded).hexdigest()}
if '--record' in sys.argv:
 FIXTURE.parent.mkdir(exist_ok=True);FIXTURE.write_text(json.dumps(actual,indent=2)+'\n',encoding='utf8')
else:
 expected=json.loads(FIXTURE.read_text(encoding='utf8'))
 for path,properties in actual.items():assert expected[path]==properties,(path,'native element definitions changed')
 print('All 12 shared MFD page snapshots match; NAV behavior is separately exercised')

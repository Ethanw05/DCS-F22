"""Lua 5.1 compilation plus baseline-relative luacheck 1.2.0 for owned changes.

Clone tag v1.2.0 from lunarmodules/luacheck into out/luacheck first. This uses
its library through pinned lupa 2.6; no system-wide Lua installation is needed.
Legacy diagnostics remain visible as a count, not silently suppressed.
"""
from collections import Counter
from pathlib import Path
import subprocess
import sys
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
BASE='f22-overhaul-start-2026-10-27'
LUA_CHECK_COMMIT='cc089e3f65acdd1ef8716cc73a3eca24a6b845e4'
read_globals=['LockOn_Options','GetSelf','GetDevice','get_param_handle','get_base_data',
 'get_model_time','dispatch_action','devices','Keys','log','make_default_activity',
 'get_aircraft_property','get_aircraft_draw_argument_value','set_aircraft_draw_argument_value',
 'get_cockpit_draw_argument_value','create_sound_host','join','res','_']
entrypoints=['SetCommand','update','post_initialize','CockpitEvent','need_to_be_closed']

def git(*args,check=True):
 return subprocess.run(['git',*args],cwd=ROOT,capture_output=True,text=True,
                       encoding='utf-8',check=check).stdout

def main():
 path=ROOT/'out/luacheck'
 if not path.is_dir() or git('-C',str(path),'rev-parse','HEAD').strip()!=LUA_CHECK_COMMIT:
  raise SystemExit('Install the pinned luacheck v1.2.0 source in out/luacheck')
 lua=LuaRuntime(unpack_returned_tuples=True)
 prefix=(path/'src').as_posix()
 lua.execute("package.path="+repr(prefix+'/?.lua;'+prefix+'/?/init.lua;')+'..package.path')
 check=lua.eval("require('luacheck').check_strings")
 options=lua.table_from({'std':'lua51','max_line_length':120,
  'globals':lua.table_from(entrypoints),'read_globals':lua.table_from(read_globals)})
 names=set(git('diff','--name-only',BASE).splitlines())
 names.update(git('ls-files','--others','--exclude-standard').splitlines())
 failed=0;legacy_count=0;compiled=0
 for name in sorted(names):
  if not name.endswith('.lua'):continue
  source=(ROOT/name).read_text(encoding='utf-8-sig')
  lua.compile(source,name=name);compiled+=1
  baseline=git('show',BASE+':'+name,check=False)
  # These are host configuration exports, scoped to their declaration files.
  host_export={'Cockpit/Scripts/devices.lua':'devices','Cockpit/Scripts/device_init.lua':'creators'}.get(name)
  file_options=options
  if host_export:
   file_options=lua.table_from({'std':'lua51','max_line_length':120,
    'globals':lua.table_from(entrypoints+[host_export]),
    'read_globals':lua.table_from([key for key in read_globals if key!=host_export])})
  if name.startswith('Input/F-22A/') and name.endswith('/default.lua'):
   # DCS input profiles receive these command constants outside the cockpit
   # script environment. Keep their allowance scoped to those two profiles.
   file_options=lua.table_from({'std':'lua51','max_line_length':120,
    'globals':lua.table_from(entrypoints),
    'read_globals':lua.table_from(read_globals+[
     'iCommandPlaneDropFlareOnce','iCommandPlaneDropChaffOnce','iCommandActiveJamming'])})
  def lint(text):
   lines=text.splitlines();report=check(lua.table_from([text]),file_options)[1]
   return Counter((e['code'],e['name'],lines[e['line']-1].strip())for _,e in report.items())
  old,new=lint(baseline),lint(source)
  legacy_count+=sum((new&old).values())
  for (code,symbol,line),count in (new-old).items():
   # Imported shared helper keeps navigation's reviewed colon-method API.
   if name.endswith('/Entry_Transaction.lua')and code=='212'and symbol=='self':continue
   failed+=count;print(name,code,symbol,line)
 print(f'{compiled} Lua 5.1 files compiled; {failed} new lint diagnostics; {legacy_count} retained baseline diagnostics')
 return bool(failed)

if __name__=='__main__':sys.exit(main())

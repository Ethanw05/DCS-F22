-- GPL-3.0-or-later. Physical UFC transport; page/entry logic has one owner.
dofile(LockOn_Options.script_path..'devices.lua')
dofile(LockOn_Options.script_path..'command_defs.lua')
local dev=GetSelf()
local decode=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local function send(owner,c,v)
 dispatch_action(owner and devices[owner]or nil,c,v or 1)
 if owner=='PILOT_WARNING_SYSTEM'then dispatch_action(devices[owner],c,0)end
end
local ui=dofile(LockOn_Options.script_path..'Systems/UFC_Controller.lua').new(get,put,send,get_base_data())
local held={};make_default_activity(.006)
for c=10041,10053 do dev:listen_command(c)end
for c=11401,11402 do dev:listen_command(c)end
for c=10989,10994 do dev:listen_command(c)end
for c=11030,11034 do dev:listen_command(c)end
local pages={[3001]='COM1',[3002]='COM2',[3003]='NAV',[3004]='STPT',[3005]='ALT',[3006]='HUD',[3007]='OTHR',
 [3015]='AP',[3033]='IFF',[3034]='DVR',
 [10041]='COM1',[10042]='COM2',[10043]='NAV',[10044]='STPT',[10045]='ALT',[10046]='HUD',[10047]='AP',[10053]='OTHR',[11401]='IFF',[11402]='DVR'}
function post_initialize()
 held={};ui:cancel();ui.page='';ui.clock=0;ui:update(0)
 put('ICP_OPACITY',get('MAIN_POWER')>.5 and 1 or 0)
end
function SetCommand(c,v)
 v=decode(v,devices.ICP_SYSTEM);if c==3014 and v<0 then v=-v end
 if v<=0 then held[c]=nil;return end
 -- Historical keyboard/joystick aliases are down-only impulses.
 if not(c>=10041 and c<=10053)then if held[c]then return end;held[c]=true end
 if c==3035 or c==10993 then send('FLIGHT_GUIDANCE',10953,1);ui.status='AP / AT OFF';ui:update(0);return end
 if get('MAIN_POWER')<.5 then return end
 if c==10989 then
  if get('F22_SMS_PROGRAM_PAGE')>.5 and get('F22_SMS_LABEL')>0 and get('HUD_AG_SUBMODE')~=1 then ui:open('STORES')end
 elseif c==10994 then
  if ui.page=='STORES'and ui.entry then ui:option(ui.entry.option)end
 elseif c>=11030 and c<=11034 then
  ui:open(c==11030 and'STPT'or c==11033 and'HEADING'or c==11034 and'MARK/TIME'or'NAV',true)
 elseif pages[c]then ui:open(pages[c])
 elseif c>=3008 and c<=3012 then ui:option(c-3007)
 elseif c>=10048 and c<=10052 then ui:option(c-10047)
 elseif c>=3017 and c<=3025 then ui:digit(c-3016)
 elseif c==3027 then ui:digit(0)
 elseif c==3026 then ui:erase(true)
 elseif c==3028 then ui:erase(false)
 elseif c==3013 or c==3014 then ui:page_step(c==3013 and 1 or -1)
 elseif c==3016 then ui:request_action('NAV_SYSTEM',11810,1)
 end
 ui:update(0)
end
function update()
 put('ICP_OPACITY',get('MAIN_POWER')>.5 and 1 or 0);ui:update(.006)
end
need_to_be_closed=false

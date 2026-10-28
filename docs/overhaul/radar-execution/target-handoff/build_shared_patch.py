"""Prepare a review-only shared diff from current sources; never apply it."""
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = ROOT / 'Cockpit/Scripts/Systems'
changes = {}


def replace(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError('Shared source changed or ambiguous region: ' + old[:90])
    return text.replace(old, new, 1)


def mark(source):
    text = replace(source, 'local terrain, target, mark_sequence, radar_sequence, request, sequence = nil, nil, 0, 0, nil, 0',
        '''local evidence=dofile(LockOn_Options.script_path.."Systems/AG_Target_Provenance.lua")
local target_snapshot=dofile(LockOn_Options.script_path.."Systems/AG_Target_Snapshot.lua")
local terrain, target, mark_sequence, radar_sequence, request, sequence = nil, nil, 0, nil, nil, 0
local radar_epoch,packet_sequence,packet_epoch,last_clock=nil,0,1,nil
local empty_target={n=0,u=0,e=0,source=0}
local function model_clock()
 local ok,now=pcall(get_model_time)
 if ok and type(now)=="number" and now==now and now>=0 and now<1e9 then return now end
end
local function begin_packet()
 packet_sequence=packet_sequence>=16777212 and 2 or packet_sequence+2
 put("F22_AG_TARGET_PACKET_SEQUENCE",packet_sequence-1)
 put("HUD_AG_TARGET_VALID",0);put("HUD_AG_CUE_VALID",0);put("HUD_AG_EDGE_VALID",0)
end
local function finish_packet(now,healthy)
 local p=target or empty_target
 if not healthy then put("HUD_AG_TARGET_VALID",0)end
 put("F22_AG_TARGET_SOURCE",p.source)
 put("F22_AG_TARGET_SEQUENCE",sequence)
 put("HUD_AG_MARK_NORTH",p.n)
 put("HUD_AG_MARK_ALT",p.u)
 put("HUD_AG_MARK_EAST",p.e)
 target_snapshot.publish_metadata(put,"F22_AG_TARGET_",target)
 put("F22_AG_TARGET_PACKET_SCHEMA",1)
 put("F22_AG_TARGET_PACKET_EPOCH",packet_epoch)
 put("F22_AG_TARGET_PACKET_TIME",now or -100)
 put("F22_AG_TARGET_PACKET_SEQUENCE",packet_sequence)
end''')
    text = text.replace('sequence = sequence + 1', 'sequence = sequence>=16777215 and 1 or sequence+1')
    text = replace(text, 'local function assign(n, u, e, source)', 'local function assign(n, u, e, source, origin)')
    text = replace(text, 'target = { n = n, u = u, e = e, source = source }',
        '''target = { n=n,u=u,e=e,source=source,time=-100,epoch=0,request=0,kind=0,live=false,
        observation_known=false,observation_sequence=0 }
    if source==2 then
        if not origin then target=nil;return end
        target.time,target.epoch,target.request=origin.time,origin.epoch,origin.request
        target.kind,target.live=origin.kind,origin.live
        target.observation_known,target.observation_sequence=true,origin.sequence
    end''')
    text = replace(text, 'function post_initialize()\n', '''function post_initialize()
 begin_packet()
 local previous=get("F22_AG_TARGET_PACKET_EPOCH")
 packet_epoch=type(previous)=="number" and previous==previous and previous>=0
  and previous<16777215 and previous%1==0 and previous+1 or 1
''')
    text = replace(text, 'radar_sequence = get("F22_AG_DESIGNATION_SEQUENCE")',
        '''local now=model_clock()
 local packet=evidence.read(get,now)
 radar_sequence,radar_epoch=packet and packet.sequence,packet and packet.epoch
 last_clock=now
 finish_packet(now,true)''')
    text = replace(text, 'function update()\n', 'local function update_body(now)\n')
    text = replace(text, 'local radar = get("F22_AG_DESIGNATION_SEQUENCE")', 'local radar = evidence.read(get,now)')
    text = replace(text, 'radar_sequence = radar\n\t\treturn',
        'if radar then radar_sequence,radar_epoch=radar.sequence,radar.epoch end\n\t\treturn')
    old = '''if get("HUD_MODE") == 7 and radar ~= radar_sequence then
		radar_sequence = radar
		if get("F22_AG_DESIGNATION_VALID") > 0.5 then
			assign(
				get("F22_AG_DESIGNATION_NORTH"),
				get("F22_AG_DESIGNATION_ALTITUDE"),
				get("F22_AG_DESIGNATION_EAST"),
				2
			)
		else
			clear()
		end
	end'''
    new = '''if get("HUD_MODE")==7 and radar and (radar.sequence~=radar_sequence or radar.epoch~=radar_epoch) then
        radar_sequence,radar_epoch=radar.sequence,radar.epoch
        if radar.valid then assign(radar.n,radar.u,radar.e,2,radar)else clear()end
    end
    if target and target.source==2 and not evidence.current(target,get,now) then clear()end'''
    text = replace(text, old, new)
    text = replace(text, 'need_to_be_closed = false', '''function update()
 begin_packet()
 local now=model_clock()
 if now and last_clock and now<last_clock then
  packet_epoch=packet_epoch>=16777215 and 1 or packet_epoch+1
  clear();request=nil;waypoint_request=nil
  -- Keep the seen radar packet: rewind cannot replay an old designation.
 end
 local healthy=now~=nil
 if healthy then
  local ok,message=pcall(update_body,now)
  healthy=ok
  if not ok and log and log.write then log.write("F22_AG_TARGET",log.ERROR or log.INFO,tostring(message))end
 end
 if not healthy then clear();request=nil;waypoint_request=nil end
 last_clock=now
 finish_packet(now,healthy)
end
need_to_be_closed = false''')
    return text


def stores(source):
    text=replace(source,"local M={labels=caps.labels,short_labels=caps.short_labels,",
        "local target_snapshot=dofile(LockOn_Options.script_path..'Systems/AG_Target_Snapshot.lua')\nlocal M={labels=caps.labels,short_labels=caps.short_labels,")
    text=replace(text,'if live_point then self.program.live_target={n=live_point.n,u=live_point.u,e=live_point.e,sequence=live_point.sequence}end',
        'if live_point then self.program.live_target=target_snapshot.copy(live_point)end')
    text=replace(text,'generation=self:generation(station),slot=slot}',
        '''generation=self:generation(station),slot=slot,
  epoch=point.epoch,request=point.request,kind=point.kind,live=point.live,
  observation_known=point.observation_known,observation_sequence=point.observation_sequence,
  packet_time=point.packet_time,packet_epoch=point.packet_epoch}''')
    return text


def weapon(source):
    text=replace(source,"local function ground_parameter(name) return get_param_handle(name):get() end",
        '''local function ground_parameter(name) return get_param_handle(name):get() end
local target_snapshot=dofile(LockOn_Options.script_path..'Systems/AG_Target_Snapshot.lua')
local delivery_sequence,delivery_epoch=0,1
local function target_clock()
 local ok,now=pcall(get_model_time)
 if ok and type(now)=='number' and now==now and now>=0 and now<1e9 then return now end
end
local function guidance_target_matches(read,target)
 return target and read('F22_AG_GUIDANCE_CACHE_TARGET_SOURCE')==target.delivery_source
  and read('F22_AG_GUIDANCE_CACHE_TARGET_SEQUENCE')==target.sequence
  and read('F22_AG_GUIDANCE_CACHE_TARGET_N')==target.n
  and read('F22_AG_GUIDANCE_CACHE_TARGET_U')==target.u
  and read('F22_AG_GUIDANCE_CACHE_TARGET_E')==target.e or false
end''')
    start=text.index('local function publish_delivery_target()')
    end=text.index('local function publish_stores()',start)
    replacement='''local empty_ground_target={n=0,u=0,e=0,source=0,sequence=0}
local function ground_output(name,value)get_param_handle(name):set(value)end
local function delivery_output(name,value)ground_output('F22_AG_DELIVERY_TARGET_'..name,value)end
local function stored_delivery(station,program)
 local stored=program and program.targets[station]or ag_stores:target(station)
 local point=stored or program and program.live_target
 return point,stored~=nil
end
local function selected_delivery(station,program,now)
 local point,assigned=stored_delivery(station,program)
 if not point then
  if program or ag_stores:mission_mode(station)~=1 then return nil,false end
  point=target_snapshot.read(ground_parameter,now)
 end
 if not point or not target_snapshot.current(point,ground_parameter,now)then return nil,false end
 return point,assigned
end
local function ccip_delivery(program,now)
 local point=program and program.ccip_target
 if not point then return end
 local target={n=point.n,u=point.u,e=point.e,sequence=point.sequence,source=1,
  time=-100,epoch=0,request=0,kind=0,live=false,observation_known=false,observation_sequence=0}
 if target_snapshot.current(target,ground_parameter,now)then return target end
end
local function delivery_candidate(station,program,now)
 local group=ag_stores:group()
 if mode_state==7 and ag_submode==2 and group and group.guided then
  return ccip_delivery(program,now),false,3
 end
 local point,assigned=selected_delivery(station,program,now)
 return point,assigned,assigned and 2 or 1
end
local function write_delivery(point,route,now)
 local p=point or empty_ground_target
 if not point then route=0 end
 delivery_sequence=delivery_sequence>=16777212 and 2 or delivery_sequence+2
 delivery_output('PACKET_SEQUENCE',delivery_sequence-1)
 delivery_output('VALID',0);delivery_output('SOURCE',route)
 delivery_output('N',p.n);delivery_output('U',p.u);delivery_output('E',p.e)
 delivery_output('SEQUENCE',p.sequence);delivery_output('ORIGIN_SOURCE',p.source)
 target_snapshot.publish_metadata(ground_output,'F22_AG_DELIVERY_TARGET_',point)
 delivery_output('PACKET_SCHEMA',1);delivery_output('PACKET_EPOCH',delivery_epoch)
 delivery_output('PACKET_TIME',now or -100);delivery_output('VALID',point and 1 or 0)
 delivery_output('PACKET_SEQUENCE',delivery_sequence)
end
local function publish_target_status(station,point,assigned)
 local p=point or empty_ground_target
 local source=0;if point then source=assigned and 2 or 1 end
 ground_output('F22_SMS_TARGET_STATION',station)
 ground_output('F22_SMS_TARGET_STATION_DISPLAY',station>=0 and station+1 or 0)
 ground_output('F22_SMS_TARGET_VALID',point and 1 or 0)
 ground_output('F22_SMS_TARGET_SOURCE',source)
 ground_output('F22_SMS_MISSION_MODE',ag_stores:mission_mode(station))
 ground_output('F22_SMS_TARGET_SEQUENCE',p.sequence)
 ground_output('F22_SMS_TARGET_N',p.n);ground_output('F22_SMS_TARGET_U',p.u);ground_output('F22_SMS_TARGET_E',p.e)
end
local function publish_delivery_target()
 local now=target_clock()
 local station=target_station()
 local point,assigned,route=delivery_candidate(station,ag_stores.program,now)
 write_delivery(point,route,now)
 publish_target_status(station,point,assigned)
end
'''
    text=text[:start]+replacement+text[end:]
    text=replace(text,'function post_initialize()\n', '''function post_initialize()
 local old=ground_parameter('F22_AG_DELIVERY_TARGET_PACKET_EPOCH')
 delivery_epoch=type(old)=='number' and old==old and old>=0 and old<16777215 and old%1==0 and old+1 or 1
''')
    text=replace(text,"withdraw_native=function()\n", "withdraw_native=function()\n    delivery_epoch=delivery_epoch>=16777215 and 1 or delivery_epoch+1\n")
    old="""elseif get_param_handle('HUD_AG_TARGET_VALID'):get()>.5 then
                ag_stores:capture_target(station,{n=get_param_handle('HUD_AG_MARK_NORTH'):get(),
                    u=get_param_handle('HUD_AG_MARK_ALT'):get(),e=get_param_handle('HUD_AG_MARK_EAST'):get(),
                    source=get_param_handle('F22_AG_TARGET_SOURCE'):get(),
                    sequence=get_param_handle('F22_AG_TARGET_SEQUENCE'):get(),
                    time=type(get_model_time)=='function'and get_model_time()or diagnostic_clock})"""
    text=replace(text,old,"""else
                local point=target_snapshot.read(ground_parameter,target_clock())
                if point then ag_stores:capture_target(station,point)end""")
    text=replace(text,"ag_consent_target=mode_state==7 and ag_submode==3 and get_param_handle('F22_AG_TARGET_SEQUENCE'):get()or nil", "ag_consent_target=nil")
    old="""local point
                if get_param_handle('HUD_AG_TARGET_VALID'):get()>.5 then point={n=get_param_handle('HUD_AG_MARK_NORTH'):get(),u=get_param_handle('HUD_AG_MARK_ALT'):get(),e=get_param_handle('HUD_AG_MARK_EAST'):get(),sequence=get_param_handle('F22_AG_TARGET_SEQUENCE'):get()}end"""
    text=replace(text,old,"""local point=target_snapshot.read(ground_parameter,now)
                ag_consent_target=ag_submode==3 and point and point.sequence or nil""")
    old="""local live_sequence=get_param_handle('F22_AG_TARGET_SEQUENCE'):get()
        if ag_stores.program and not ag_stores:consent_current(selected_station,live_sequence)then"""
    new="""local now=target_clock()
        local live=target_snapshot.read(ground_parameter,now)
        local live_sequence=live and live.sequence
        local program=ag_stores.program
        local chosen=program and (program.targets[selected_station]or program.live_target)
        local source_current=not chosen or target_snapshot.current(chosen,ground_parameter,now)
        if program and (not source_current or not ag_stores:consent_current(selected_station,live_sequence))then"""
    text=replace(text,old,new)
    text=replace(text,"local permitted=solution and (ag_submode==2 or auto_ready)",
        "local delivery_target=target_snapshot.read_delivery(ground_parameter,now)\n        local permitted=solution and (ag_submode==2 or auto_ready)\n        if ag_submode==3 then permitted=permitted and delivery_target~=nil end")
    text=replace(text,"""for _,key in ipairs({'SOURCE','SEQUENCE','N','U','E'})do
                if r('F22_AG_GUIDANCE_CACHE_TARGET_'..key)~=r('F22_AG_DELIVERY_TARGET_'..key)then cached=false end
            end
            permitted=permitted and cached and r('F22_AG_DELIVERY_TARGET_VALID')>.5 and r('F22_AG_GUIDANCE_BACKEND_READY')>.5""",
        """cached=cached and guidance_target_matches(r,delivery_target)
            permitted=permitted and cached and delivery_target~=nil and r('F22_AG_GUIDANCE_BACKEND_READY')>.5""")
    return text


def navigation(source):
    text=replace(source,"local geom=dofile(LockOn_Options.script_path..'Systems/NavGeometry.lua')",
        "local geom=dofile(LockOn_Options.script_path..'Systems/NavGeometry.lua')\nlocal target_snapshot=dofile(LockOn_Options.script_path..'Systems/AG_Target_Snapshot.lua')")
    text=replace(text,"""if get('HUD_AG_TARGET_VALID')<.5 then return false end
  capture_point.n=get('HUD_AG_MARK_NORTH');capture_point.e=get('HUD_AG_MARK_EAST')
  capture_point.alt=get('HUD_AG_MARK_ALT')""", """local now=type(get_model_time)=='function' and get_model_time()or nil
  local point=target_snapshot.read(get,now)
  if not point then return false end
  capture_point.n,capture_point.e,capture_point.alt=point.n,point.e,point.u""")
    old="""local same_target=get('HUD_AG_TARGET_VALID')>.5 and get('F22_AG_TARGET_SOURCE')==3 and
            get('F22_AG_TARGET_SEQUENCE')==get('F22_NAV_TARGET_ACK_TARGET_SEQUENCE') and
            math.abs(get('HUD_AG_MARK_NORTH')-d.n)<1 and math.abs(get('HUD_AG_MARK_EAST')-d.e)<1
        if acknowledged and result==1 and same_target then
            d.waiting=false;s.designated=true;s.designation_alt=get('HUD_AG_MARK_ALT')"""
    new="""local target_time=type(get_model_time)=='function' and get_model_time()or nil
        local point=target_snapshot.read_packet(get,target_time)
        local acknowledged=point and point.nav_request==d.request
        local result=point and point.nav_result or 0
        local same_target=point and point.valid and point.source==3 and
            point.sequence==point.nav_target_sequence and
            math.abs(point.n-d.n)<1 and math.abs(point.e-d.e)<1
        if acknowledged and result==1 and same_target then
            d.waiting=false;s.designated=true;s.designation_alt=point.u"""
    text=replace(text,old,new)
    return replace(text,"""local acknowledged=get('F22_NAV_TARGET_ACK_SEQUENCE')==d.request
        local result=get('F22_NAV_TARGET_RESULT')
        local target_time""", 'local target_time')


def ballistic(source):
    text=replace(source,"local geom = dofile(LockOn_Options.script_path .. \"Systems/NavGeometry.lua\")",
        "local geom = dofile(LockOn_Options.script_path .. \"Systems/NavGeometry.lua\")\nlocal target_snapshot=dofile(LockOn_Options.script_path..'Systems/AG_Target_Snapshot.lua')")
    text=replace(text,'local target_seq = get("F22_AG_TARGET_SEQUENCE")',
        'local selected_target=target_snapshot.read_delivery(get,now)\n\tlocal target_seq=selected_target and selected_target.sequence or 0')
    old="""local source=get('F22_AG_DELIVERY_TARGET_SOURCE')
        local target=source>0 and get('F22_AG_DELIVERY_TARGET_VALID')>.5 or source==0 and get('HUD_AG_TARGET_VALID')>.5
        local target_point={n=source>0 and get('F22_AG_DELIVERY_TARGET_N')or get('HUD_AG_MARK_NORTH'),u=source>0 and get('F22_AG_DELIVERY_TARGET_U')or get('HUD_AG_MARK_ALT'),e=source>0 and get('F22_AG_DELIVERY_TARGET_E')or get('HUD_AG_MARK_EAST')}"""
    new="""local checked=selected_target
        local source=checked and checked.delivery_source or 0
        local target=checked~=nil
        local target_point=checked or {n=0,u=0,e=0}"""
    text=replace(text,old,new)
    text=replace(text,"target_n=target_point.n,target_u=target_point.u,target_e=target_point.e}",
        """target_n=target_point.n,target_u=target_point.u,target_e=target_point.e,
            target_observation_known=checked and checked.observation_known or false,
            target_observation_time=checked and checked.time or -100,
            target_epoch=checked and checked.epoch or 0,target_request=checked and checked.request or 0,
            target_kind=checked and checked.kind or 0}""")
    text=replace(text,"target_source=source,target_sequence=get('F22_AG_DELIVERY_TARGET_SEQUENCE'),target_valid=target and 1 or 0,",
        "target_source=source,target_sequence=checked and checked.sequence or 0,target_valid=target and 1 or 0,")
    old="""local source=get('F22_AG_DELIVERY_TARGET_SOURCE')
        local target={n=source>0 and get('F22_AG_DELIVERY_TARGET_N')or get('HUD_AG_MARK_NORTH'),u=source>0 and get('F22_AG_DELIVERY_TARGET_U')or get('HUD_AG_MARK_ALT'),e=source>0 and get('F22_AG_DELIVERY_TARGET_E')or get('HUD_AG_MARK_EAST')}"""
    new="""local target=target_snapshot.read_delivery(get,now)
        if not target then put('F22_AG_SOLUTION_VALID',0);put('F22_AG_BOMB_REQUEST_VALID',0);return end"""
    return replace(text,old,new)


def main():
    transforms={'AG_Mark_System.lua':mark,'AG_Stores.lua':stores,'Weapon_System.lua':weapon,
                'Navigation_System.lua':navigation,'AG_Ballistic_Computer.lua':ballistic}
    patches=[];manifest=[]
    for name,transform in transforms.items():
        path=BASE/name
        original=path.read_text(encoding='utf-8-sig')
        updated=transform(original)
        relative=path.relative_to(ROOT).as_posix()
        patches.extend(difflib.unified_diff(original.splitlines(True),updated.splitlines(True),
                       fromfile='a/'+relative,tofile='b/'+relative))
        manifest.append(dict(path=relative,expected_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                             proposed_text_sha256=hashlib.sha256(updated.encode()).hexdigest()))
    (HERE/'SHARED.patch').write_text(''.join(patches),encoding='utf-8',newline='\n')
    (HERE/'EXPECTED-SOURCES.json').write_text(json.dumps(dict(status='UNAPPLIED review patch; current actual files remain unchanged',files=manifest),indent=2)+'\n')
    print('Prepared unapplied shared patch for',len(manifest),'current files')


if __name__=='__main__':
    main()

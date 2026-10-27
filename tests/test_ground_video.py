from pathlib import Path
root=Path(__file__).resolve().parents[1]
system=root/'Cockpit/Scripts/Systems/AG_Radar_System.lua'
format_page=root/'Cockpit/Scripts/PMFD_CENTER/ag_radar_format.lua'
fixture=root/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.globals().VideoSystem=lua.execute(system.read_text())
lua.execute('''
local h={};local function get(n)return h[n]or 0 end
local function put(n,v)h[n]=v end
package.loaded.terrain=nil
package.preload.terrain=function()return {GetHeight=function()return 10 end}end
local s=VideoSystem.new(get,put,function()end)
s:command('rws',1,true,0)
local pose={north=0,east=0,altitude=2000,heading=0,pitch=0,roll=0}
put('F22_AG_RADAR_NATIVE_READY',1)
for _,width in ipairs({120,60,30})do
 s.model.width=width
 for az=-50,50,5 do
  s.model.cursor_az=math.rad(az)
  for tick=0,80 do
   s:update(pose,10+tick*.05,.05,true,true)
   assert(get('F22_AG_VIDEO_FOV_DEG')==width,'camera FOV must follow native antenna scan width')
   assert(get('F22_AG_VIDEO_SCAN_FRACTION')>=0 and get('F22_AG_VIDEO_SCAN_FRACTION')<=1)
   assert(get('F22_AG_VIDEO_SCAN_AZ_DEG')>=-60.000001 and get('F22_AG_VIDEO_SCAN_AZ_DEG')<=60.000001)
  end
 end
end
s:command('elevation_up',1,true)
assert(s.controls.antenna==1 and s.controls.gain==5,'antenna command changed gain')
s:command('gain_up',1,true);assert(s.controls.gain==6)
for i=1,50 do s:command('gain_up',1,true)end
assert(s.controls.gain==9)
for i=1,50 do s:command('gain_down',1,true)end
assert(s.controls.gain==1)
s:command('vertical_span',1,true)
s:update(pose,20,.05,true,true)
local north=s.video_frame.north
local generation=s.video_erase
pose.north=1000;s.model.cursor_az=math.rad(20)
s:update(pose,21,.05,true,true)
assert(s.video_frame.north==north and s.video_erase==generation,'frozen view changed on aircraft/cursor motion')
assert(get('F22_AG_RADAR_CANDIDATE')==1,'registered frozen image cannot be designated')
s:command('designate',1,true,21)
assert(get('F22_AG_DESIGNATION_VALID')==1,'registered frozen-image designation failed')
assert(math.abs(get('F22_AG_DESIGNATION_NORTH')-north-math.cos(s.model.cursor_az)*s.model.range_nm*1852*s.model.cursor_fraction)<1e-8,
 'frozen-image point followed current ownship')
s:command('vertical_span',1,true)
s:update(pose,21.05,.05,true,true)
assert(s.video_frame.north==1030 and s.video_erase==generation)
s:update(pose,21.1,.05,false,true)
assert(get('F22_AG_VIDEO_ENABLE')==0 and not s.video_frozen)
s:update(pose,1,.05,true,true)
assert(get('F22_AG_VIDEO_TIME')==1 and get('F22_AG_DESIGNATION_VALID')==0)
pose.north=0;s.model.cursor_az=0;s.model.cursor_fraction=.5;s.model.range_nm=20
put('F22_AG_VIDEO_SOURCE_PRESENT',1);put('F22_AG_VIDEO_READY',1)
put('F22_AG_RETURN_TIME',50);put('F22_AG_RETURN_COUNT',1)
for k,v in pairs({N=18520,U=10,E=0,TIME=50,RCS=4})do put('F22G_1_'..k,v)end
s:update(pose,50,.05,true,true)
assert(get('F22_AG_RADAR_CANDIDATE')==0)
s:command('designate',1,true,50)
assert(get('F22_AG_DESIGNATION_VALID')==0,'unqualified image authorized designation')
put('F22_AG_VIDEO_GEOMETRY_QUALIFIED',1)
s:update(pose,50.05,.05,true,true)
assert(get('F22_AG_RADAR_CANDIDATE')==1)
s:command('designate',1,true,50.05)
assert(get('F22_AG_DESIGNATION_VALID')==1,'qualified fresh footprint lost designation')

-- A fixed ground cursor and heading must not move or erase the stabilized
-- video sector when aircraft pitch/roll changes. Body acquisition still moves.
for _,width in ipairs({120,60,30})do
 local values={};local function rd(n)return values[n]or 0 end
 local function wr(n,v)values[n]=v end
 local v=VideoSystem.new(rd,wr,function()end)
 v:command('rws',1,true,0)
 v.model.width=width;v.model.cursor_az=math.rad(20)
 local p={north=0,east=0,altitude=5000,heading=.8,pitch=0,roll=0}
 local now=80;v:update(p,now,.05,true,true)
 local erased=rd('F22_AG_VIDEO_ERASE_SEQUENCE')
 local center=rd('F22_AG_RADAR_SCAN_CENTER_AZ_DEG')
 local body=rd('F22N_SCAN_ZONE_ORIGIN_AZIMUTH')
 for tick=1,100 do
  now=80+tick*.05;p.roll=math.rad(tick*.3);p.pitch=math.rad(tick*.1)
  v:update(p,now,.05,true,true)
  assert(rd('F22_AG_VIDEO_ERASE_SEQUENCE')==erased,'attitude erased accumulated map')
  assert(rd('F22_AG_RADAR_SCAN_CENTER_AZ_DEG')==center,'body attitude moved map sector')
 end
 if width<120 then
  assert(math.abs(rd('F22N_SCAN_ZONE_ORIGIN_AZIMUTH')-body)>1e-3,'body acquisition lost attitude compensation')
 end
 v.model.cursor_az=math.rad(-20);now=now+.05;v:update(p,now,.05,true,true)
 assert(rd('F22_AG_VIDEO_ERASE_SEQUENCE')==erased,'TDC steering erased accumulated map')
 v:command('azimuth',1,true,now);now=now+.05;v:update(p,now,.05,true,true)
 assert(rd('F22_AG_VIDEO_ERASE_SEQUENCE')==erased+1,'AZ width must rebuild changed camera geometry')
 v:command('range_up',1,true,now);now=now+.05;v:update(p,now,.05,true,true)
 assert(rd('F22_AG_VIDEO_ERASE_SEQUENCE')==erased+2,'range remap must erase once')
end

''')
ui=ns['runtime']()
ui.execute(format_page.read_text())('PMFD_RDR_PAGE','')
elements=ui.globals().elements
# Construct every element, then check that the real page uses one video quad.
source=format_page.read_text()
assert source.count('CreateElement("ceTexPoly")')==1
assert 'F22_AG_RDR_RETURN_' not in source
assert 'NO RETURN' not in source,'footprint selection must not report GPU scan results'
assert 'F22_AG_RDR_MAP_UNAVAILABLE' in source and 'VIDEO' in source
assert len(elements)<600
device=ns['runtime']()
device.execute("dofile(SCRIPT_ROOT..'Systems/Radar_System.lua')")
for _,element in elements.items():
    for _,controller in (element.controllers or ui.table()).items():
        if controller[1]=='line_object_set_point_using_parameters':
            assert element.kind=='ceSimpleLineObject', 'native line controller requires ceSimpleLineObject; ceSMultiLine crashes'
    for _,param in (element.element_params or ui.table()).items():
        if str(param).startswith('F22_AG_VIDEO_'):
            assert device.globals().handles[param] is not None,('video binding first created after construction',param)
source_init=ns['runtime']()
source_init.execute("dofile(SCRIPT_ROOT..'Systems/AG_Radar_Video/init.lua')")
expected_material='render_target_'+str(int(source_init.globals().render_target)+1)
quad=[element for _,element in elements.items() if element.kind=='ceTexPoly']
assert len(quad)==1 and quad[0].material==expected_material,'zero-based source / one-based material mismatch'
assert quad[0].name=='F22_AG_RADAR_VIDEO'
# A foreign MFD material does not inherit the consumer parser's .5/.5 inputs.
# Verify the actual Lua quad explicitly supplies neutral transfer via the
# common controller (CockpitBase 0x180387120 / GraphicsVista 0x180019990).
transfers=[c for _,c in quad[0].controllers.items() if c[1]=='change_color_when_parameter_equal_to_number']
assert len(transfers)==1 and [v for _,v in transfers[0].items()]==[
    'change_color_when_parameter_equal_to_number',0,1,.5,.5,1]
registration=(root/'Cockpit/Scripts/device_init.lua').read_text()
assert registration.index('HUD/init.lua') < registration.index('Systems/AG_Radar_Video/init.lua') < registration.index('PMFD_CENTER/init.lua')
print(f'Ground video controls: {len(elements)} elements, one video quad, scan bounds, fixed AZ scale, gain bounds, freeze, designation inhibit, power/time reset PASS')

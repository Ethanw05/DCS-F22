-- Exogenous measurements only. Real C++ sensing and timing have separate tests.
f={now=10,alive=true,driver=true,slots={},hits={},pose={north=0,altitude=3000,east=0,heading=0,pitch=0,roll=0}}
function f.put(n,v)get_param_handle(n):set(v)end
function f.get(n)return get_param_handle(n):get()end
function get_model_time()return f.now end
function get_base_data()return {
 getSelfCoordinates=function()return f.pose.north,f.pose.altitude,f.pose.east end,
 getHeading=function()return -f.pose.heading end,getPitch=function()return f.pose.pitch end,
 getRoll=function()return f.pose.roll end}end
function GetDevice()error('owned sensor called a mechanical radar')end
f.put('MAIN_POWER',1);f.put('HUD_MODE',2);f.put('F22_SOI',2);f.put('F22_PMFD_PAGE',1)
f.put('F22_TWS_GUIDANCE_BACKEND_READY',1)
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
f.command,f.update=SetCommand,update
function f.tick(dt)
 f.now=f.now+(dt or .05)
 f.put('F22_AESA_DRIVER_READY',f.driver and 1 or 0)
 f.put('F22_AESA_READY',f.alive and 1 or 0)
 f.put('F22_AESA_TIME',f.now);f.put('F22_AESA_SEQUENCE',4)
 f.put('F22_AESA_GENERATION',f.generation or 1)
 f.update()
end
function f.measure(id,n,u,e,vn,vu,ve)
 local slot=f.slots[id]
 if not slot then slot=1;while f.get(string.format('F22A_%02d_VALID',slot))==1 and slot<64 do slot=slot+1 end;f.slots[id]=slot end
 f.hits[id]=(f.hits[id]or 0)+1
 local p=string.format('F22A_%02d_',slot)
 for k,v in pairs({VALID=1,ID=id,TIME=f.now,N=n or 10000,U=u or 3000,E=e or 0,
  VN=vn or 0,VU=vu or 0,VE=ve or 0,VELOCITY_VALID=1,HITS=f.hits[id],
  RANGE_SIGMA_M=30,ANGLE_SIGMA_RAD=.001,FILTER_VALID=1,POSITION_SIGMA_M=20,VELOCITY_SIGMA_MPS=10})do f.put(p..k,v)end
end
function f.lock(id)
 f.command(10605,1);f.measure(id);f.tick();f.tick()
 f.measure(id);f.tick()
 assert(f.get('F22_RADAR_STT_VALID')==1,'owned acquisition failed')
end
f.tick()

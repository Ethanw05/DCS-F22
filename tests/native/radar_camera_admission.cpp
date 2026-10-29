// D-R-RAD-001: actual parameter adapter, captured-image owner and camera copies.
// The executable supplies only local numeric storage/clock/constructor ports.
#include "../../EFM/source/NativeGroundVideo.cpp"
#include <iostream>

namespace {
struct Field { double value{};bool converts=true, resolves=true; };
std::map<std::string,Field> bus;
unsigned checks{},failures{},reads{},constructors{},lookups{};
int replace_at=-1;
void (*read_action)(){};
EDPARAM* changing_context{};
double clock_value=10.2;
void require(bool condition,const char* description) {
  ++checks;
  if (!condition) {++failures;std::cout<<"FAIL "<<description<<'\n';}
}
double world_clock() { return clock_value; }
void* resolve(const char* name) {
  ++lookups;
  auto& field=bus[name];
  return field.resolves?&field:nullptr;
}
void store(void* handle,double value) { static_cast<Field*>(handle)->value=value; }
void ground_packet(bool newer=false) {
  bus["F22_AG_NATIVE_SCHEMA"].value=1;
  bus["F22_AG_NATIVE_SEQUENCE"].value=newer?4:2;
  bus["F22_AG_NATIVE_SOURCE_EPOCH"].value=newer?2:1;
  bus["F22_AG_GMT_LAST_TIME"].value=newer?10.1:10;
  bus["F22_AG_GMT_READY"].value=1;
  bus["F22_AG_NATIVE_TRACK_VALID"].value=newer?0:1;
  bus["F22_AG_NATIVE_TRACK_ACQUIRING"].value=0;
}
bool number(const void* handle,double& value,bool) {
  if (static_cast<int>(reads++)==replace_at) {
    if (read_action) read_action();
    else ground_packet(true);
  }
  const auto& field=*static_cast<const Field*>(handle);
  value=field.value;
  return field.converts;
}
void* camera_constructor(void* out,int) {
  ++constructors;
  std::memset(out,0,784);
  return out;
}
void seed(EDPARAM& p) {
  NativeGroundVideo::handles.clear();bus.clear();
  p.invalidate();p.ed_param_api={};
  p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=resolve;
  p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
  p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=store;
  NativeGroundVideo::api.clock=world_clock;
  const std::pair<const char*,double> fields[]={
      {"F22_AG_VIDEO_ENABLE",1},{"HUD_MODE",7},{"MAIN_POWER",1},{"RADAR_PWR",1},
      {"F22_AG_VIDEO_FROZEN",0},{"F22_AG_VIDEO_HOLD",0},{"F22_AG_VIDEO_TIME",10},
      {"F22_AG_VIDEO_NORTH",1000},{"F22_AG_VIDEO_ALTITUDE",5000},{"F22_AG_VIDEO_EAST",2000},
      {"F22_AG_VIDEO_HEADING",0},{"F22_AG_RADAR_RANGE_NM",20},{"F22_AG_VIDEO_FOV_DEG",120},
      {"F22_AG_VIDEO_COLLECTION",1},{"F22_AG_VIDEO_SCAN_DIRECTION",1},{"F22_AG_VIDEO_SCAN_FRACTION",.5},
      {"F22_AG_VIDEO_GAIN",.5},{"F22_AG_VIDEO_ERASE_SEQUENCE",0},{"F22_AG_MODE",1},
      {"F22_AG_VIDEO_EXPANSION",0},{"F22_AG_VIDEO_CENTER_M",0},{"F22_AG_VIDEO_SPAN_M",0},
      {"F22_AG_VIDEO_ANTENNA_DEG",0},{"F22_AG_FAST",0},{"F22_AG_VIDEO_FAN",1},
      {"F22_AG_VIDEO_EPOCH",1},{"F22_AG_VIDEO_STABILIZED",0},{"F22_AG_VIDEO_PATCH_N",0},
      {"F22_AG_VIDEO_PATCH_U",0},{"F22_AG_VIDEO_PATCH_E",0},{"F22_AG_VIDEO_PATCH_AZ",0},
      {"F22_AG_VIDEO_PATCH_DISTANCE",0},{"F22_AG_INTERLEAVE",0},{"F22_AG_RADAR_SCAN_CENTER_AZ_DEG",0},
      {"F22_AG_VIDEO_PROBE_FORWARD_M",0},{"F22_AG_VIDEO_PROBE_RIGHT_M",0},{"F22_AG_VIDEO_PROBE_UP_M",0},
      {"F22_AG_VIDEO_PROBE_TEXTURE",0}};
  for (const auto& field : fields) bus[field.first].value=field.second;
  bus["F22_AG_NATIVE_CONTROL_SEQUENCE"].value=2;
  bus["F22_AG_NATIVE_CONTROL_SCHEMA"].value=1;
  bus["F22_AG_NATIVE_CONTROL_EPOCH"].value=1;
  bus["F22_AG_NATIVE_CONTROL_TIME"].value=10;
  bus["F22_AG_VIDEO_SOURCE_PRESENT"].value=1;
  NativeGroundVideo::previous_probe={};NativeGroundVideo::probe_erase=0;
  ground_packet();replace_at=-1;reads=0;read_action=nullptr;
}
bool accepted(EDPARAM& p) {
  bool malformed=false;
  const auto frame=NativeGroundVideo::read_view(p,true,malformed);
  return GroundVideoView::prepare(frame,world_clock()).accepted;
}
void scalar_admission(EDPARAM& p) {
  seed(p);require(accepted(p),"explicit healthy adapter frame");
  const char* fields[]={"F22_AG_VIDEO_ENABLE","MAIN_POWER","RADAR_PWR","HUD_MODE",
      "F22_AG_VIDEO_TIME","F22_AG_VIDEO_NORTH","F22_AG_VIDEO_ALTITUDE",
      "F22_AG_VIDEO_EAST","F22_AG_VIDEO_HEADING","F22_AG_RADAR_RANGE_NM","F22_AG_VIDEO_FOV_DEG",
      "F22_AG_VIDEO_COLLECTION","F22_AG_VIDEO_SCAN_DIRECTION","F22_AG_VIDEO_SCAN_FRACTION",
      "F22_AG_VIDEO_GAIN","F22_AG_VIDEO_ERASE_SEQUENCE","F22_AG_MODE","F22_AG_VIDEO_EXPANSION",
      "F22_AG_VIDEO_CENTER_M","F22_AG_VIDEO_SPAN_M","F22_AG_VIDEO_ANTENNA_DEG","F22_AG_FAST",
      "F22_AG_VIDEO_FAN","F22_AG_VIDEO_EPOCH","F22_AG_VIDEO_STABILIZED","F22_AG_VIDEO_PATCH_N",
      "F22_AG_VIDEO_PATCH_U","F22_AG_VIDEO_PATCH_E","F22_AG_VIDEO_PATCH_AZ","F22_AG_VIDEO_PATCH_DISTANCE",
      "F22_AG_INTERLEAVE","F22_AG_RADAR_SCAN_CENTER_AZ_DEG","F22_AG_VIDEO_PROBE_FORWARD_M",
      "F22_AG_VIDEO_PROBE_RIGHT_M","F22_AG_VIDEO_PROBE_UP_M","F22_AG_VIDEO_FROZEN","F22_AG_VIDEO_HOLD"};
  for (const auto name : fields) {
    for (const double bad : {std::numeric_limits<double>::quiet_NaN(),
        std::numeric_limits<double>::infinity(),-std::numeric_limits<double>::infinity()}) {
      seed(p);bus[name].value=bad;
      require(!accepted(p),"every used nonfinite geometry/flag is rejected at actual adapter");
    }
    for (const double payload : {0.0,7.0}) {
      seed(p);bus[name]={payload,false,true};
      require(!accepted(p),"conversion status wins over retained zero/seven payload");
    }
    seed(p);bus[name].resolves=false;
    require(!accepted(p),"unresolved parameter is unavailable, not zero");
  }
  for (const auto name : {"F22_AG_MODE","F22_AG_VIDEO_EXPANSION"}) {
    for (const double invalid : {-1.0,.5,2147483648.0}) {
      seed(p);bus[name].value=invalid;
      require(!accepted(p),"raw enum is rejected before integer cast");
    }
  }
  seed(p);p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=nullptr;
  require(!accepted(p),"missing numeric export withdraws frame");
  seed(p);require(accepted(p),"fresh adapter context recovers");
  const auto previous_lookups=lookups;
  p.invalidate();
  p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=resolve;
  p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
  p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=store;
  require(accepted(p) && lookups>previous_lookups,"new parameter context reacquires video handles");
  for (int mode=1;mode<=7;++mode) {
    seed(p);bus["F22_AG_MODE"].value=mode;
    bus["F22_AG_RADAR_RANGE_NM"].value=mode==6?10:mode==7?5:20;
    require(accepted(p),"each current surface mode retains finite normal geometry");
  }
  for (int expansion=1;expansion<=3;++expansion) {
    seed(p);bus["F22_AG_VIDEO_EXPANSION"].value=expansion;
    bus["F22_AG_VIDEO_CENTER_M"].value=10000;bus["F22_AG_VIDEO_SPAN_M"].value=2000;
    bus["F22_AG_VIDEO_FOV_DEG"].value=45;
    require(accepted(p),"each expansion retains finite bounded projection geometry");
  }
}
void protected_tracking(EDPARAM& p) {
  seed(p);
  require(NativeGroundVideo::tracking(p,10.2).active,"committed selected flag grants tracking semantics");
  for (unsigned boundary=0;boundary<=9;++boundary) {
    seed(p);replace_at=static_cast<int>(boundary);reads=0;
    const auto result=NativeGroundVideo::tracking(p,10.2);
    // Complete old is active, complete new inactive; torn group is unavailable.
    const bool old=result.source_epoch==1 && result.stamp==10 && result.active;
    const bool newer=result.source_epoch==2 && result.stamp==10.1 && !result.active;
    require(!result.current || old || newer,
        "complete old/new/unavailable at every protected ground field boundary");
  }
  replace_at=-1;
  for (const auto name : {"F22_AG_NATIVE_SCHEMA","F22_AG_NATIVE_SOURCE_EPOCH","F22_AG_GMT_LAST_TIME",
      "F22_AG_GMT_READY","F22_AG_NATIVE_TRACK_VALID","F22_AG_NATIVE_TRACK_ACQUIRING","F22_AG_NATIVE_SEQUENCE"}) {
    seed(p);bus[name].converts=false;
    require(!NativeGroundVideo::tracking(p,10.2).current,"failed protected read withdraws tracking semantics");
    const bool flag_only=std::string(name)=="F22_AG_GMT_READY"
        || std::string(name)=="F22_AG_NATIVE_TRACK_VALID"
        || std::string(name)=="F22_AG_NATIVE_TRACK_ACQUIRING";
    require(accepted(p)==flag_only,"native identity failure withdraws imagery; tracking flag failure grants no tracking authority");
  }
  seed(p);bus["F22_AG_NATIVE_SEQUENCE"].value=3;
  require(!NativeGroundVideo::tracking(p,10.2).current,"odd ground output is unavailable");
  seed(p);bus["F22_AG_GMT_LAST_TIME"].value=9;
  require(!NativeGroundVideo::tracking(p,10.2).current,"stale ground output cannot grant tracking");
  seed(p);bus["F22_AG_GMT_LAST_TIME"].value=11;
  require(!NativeGroundVideo::tracking(p,10.2).current,"future ground output cannot grant tracking");
  seed(p);bus["F22_AG_NATIVE_SEQUENCE"].value=16777214;
  bus["F22_AG_NATIVE_SOURCE_EPOCH"].value=16777215;
  require(NativeGroundVideo::tracking(p,10.2).active,"near-wrap commit and maximum ground epoch are valid");
  bus["F22_AG_NATIVE_SEQUENCE"].value=16777216;
  require(!NativeGroundVideo::tracking(p,10.2).current,"ground commit beyond schema bound is unavailable");
  bus["F22_AG_NATIVE_SEQUENCE"].value=2;bus["F22_AG_NATIVE_SOURCE_EPOCH"].value=16777216;
  require(!NativeGroundVideo::tracking(p,10.2).current,"ground epoch beyond exact schema bound is unavailable");
}
void new_control_packet() {
  bus["F22_AG_NATIVE_CONTROL_SEQUENCE"].value=4;
  bus["F22_AG_NATIVE_CONTROL_TIME"].value=10.1;
  bus["F22_AG_VIDEO_TIME"].value=10.1;
  bus["F22_AG_VIDEO_NORTH"].value=3000;
  bus["F22_AG_VIDEO_EAST"].value=4000;
  bus["F22_AG_VIDEO_COLLECTION"].value=2;
  bus["F22_AG_VIDEO_PROBE_FORWARD_M"].value=1;
}
void replace_context() { changing_context->invalidate(); }
void change_schema() { bus["F22_AG_NATIVE_CONTROL_SCHEMA"].value=2; }
void change_control_time() { bus["F22_AG_NATIVE_CONTROL_TIME"].value=10.1; }
void change_control_epoch() { bus["F22_AG_NATIVE_CONTROL_EPOCH"].value=2; }
void withdraw_source() { bus["F22_AG_VIDEO_SOURCE_PRESENT"].value=0; }
void control_capture_boundaries(EDPARAM& p) {
  seed(p);require(accepted(p),"healthy control packet establishes read-boundary count");
  const unsigned boundaries=reads;
  require(boundaries<128,"control capture has bounded numeric reads");
  for (unsigned boundary=0;boundary<=boundaries;++boundary) {
    seed(p);replace_at=static_cast<int>(boundary);read_action=new_control_packet;
    bool malformed=false;
    const auto view=NativeGroundVideo::read_view(p,true,malformed);
    const bool current=GroundVideoView::prepare(view,clock_value).accepted;
    const bool old=view.north==1000 && view.east==2000 && view.collection==1 && view.stamp==10;
    const bool newer=view.north==3001 && view.east==4000 && view.collection==2 && view.stamp==10.1;
    require(!current || old || newer,"every payload boundary admits one whole control packet or unavailable");
    require(current || (NativeGroundVideo::probe_erase==0
        && NativeGroundVideo::previous_probe==std::array<double,3>{}),
        "rejected torn packet cannot advance probe erase/history");
    seed(p);changing_context=&p;replace_at=static_cast<int>(boundary);read_action=replace_context;
    const bool context_current=accepted(p);
    require(boundary==boundaries || !context_current,
        "parameter context replacement at every used read withdraws the capture");
    seed(p);replace_at=static_cast<int>(boundary);
    const bool source_current=accepted(p);
    require(boundary==boundaries || !source_current,
        "native generation replacement at every read cannot authenticate an old control echo");
  }
  for (auto action:{change_schema,change_control_time,change_control_epoch,withdraw_source}) {
    seed(p);read_action=action;replace_at=8;
    require(!accepted(p),"post-payload schema/time/epoch/source recheck detects change without a sequence advance");
  }
  seed(p);require(accepted(p),"fresh complete capture recovers after adversarial context changes");
}
void control_header_failures(EDPARAM& p) {
  const char* fields[]={"F22_AG_NATIVE_CONTROL_SEQUENCE","F22_AG_NATIVE_CONTROL_SCHEMA",
      "F22_AG_NATIVE_CONTROL_EPOCH","F22_AG_NATIVE_CONTROL_TIME","F22_AG_VIDEO_SOURCE_PRESENT"};
  for (const auto name:fields) {
    for (double bad:{NAN,INFINITY,-INFINITY}) {
      seed(p);bus[name].value=bad;
      require(!accepted(p),"nonfinite control identity/lease cannot authorize imagery");
    }
    seed(p);bus[name].converts=false;
    require(!accepted(p),"failed control header conversion cannot authorize retained payload");
    seed(p);bus[name].resolves=false;
    require(!accepted(p),"missing control header handle cannot authorize imagery");
  }
  for (double sequence:{0.,1.,3.,16777216.}) {
    seed(p);bus["F22_AG_NATIVE_CONTROL_SEQUENCE"].value=sequence;
    require(!accepted(p),"only committed bounded even sequence is admitted");
  }
  for (double source_epoch:{0.,1.5,16777216.}) {
    seed(p);bus["F22_AG_NATIVE_CONTROL_EPOCH"].value=source_epoch;
    require(!accepted(p),"control source epoch is an exact positive bounded integer");
  }
  for (double time:{9.699,10.201}) {
    seed(p);bus["F22_AG_NATIVE_CONTROL_TIME"].value=time;
    require(!accepted(p),"stale/future original command heartbeat is rejected");
  }
  seed(p);bus["F22_AG_NATIVE_CONTROL_TIME"].value=9.7;
  require(accepted(p),"control lease inclusive half-second boundary is accepted");
  seed(p);bus["F22_AG_NATIVE_CONTROL_TIME"].value=10.1;
  require(accepted(p),"command heartbeat may differ from still-current original video time");
  bus["F22_AG_VIDEO_TIME"].value=9.6;
  require(!accepted(p),"fresh command cannot renew old video time");
  seed(p);bus["F22_AG_NATIVE_CONTROL_SCHEMA"].value=2;
  require(!accepted(p),"unknown control schema is unavailable");
  seed(p);bus["F22_AG_VIDEO_SOURCE_PRESENT"].value=0;
  require(!accepted(p),"absent dedicated source cannot enable video");
  seed(p);bus["F22_AG_NATIVE_CONTROL_SEQUENCE"].value=16777214;
  require(accepted(p),"last bounded even control commit remains usable");
}
void control_source_identity(EDPARAM& p) {
  seed(p);bus["F22_AG_GMT_READY"].value=0;
  const auto unavailable=NativeGroundVideo::tracking(p,clock_value);
  require(!unavailable.current && unavailable.source_epoch==1 && accepted(p),
      "coherent unavailable GMT heartbeat identifies source without denying independent imagery");
  bus["F22_AG_NATIVE_TRACK_VALID"].value=1;
  require(!NativeGroundVideo::tracking(p,clock_value).active,
      "unavailable GMT cannot grant tracking through a retained selected flag");
  bus["F22_AG_NATIVE_SOURCE_EPOCH"].value=2;
  require(!accepted(p),"old control echo cannot cross native source generation");
  bus["F22_AG_NATIVE_CONTROL_EPOCH"].value=2;
  require(accepted(p),"new coherent source consent restores independent imagery");
  seed(p);clock_value=9.9;
  require(!accepted(p),"backwards native time withdraws future control and source packets");
  clock_value=20;
  require(!accepted(p),"large native time jump cannot replay old control and imagery");
  clock_value=10.2;seed(p);
  require(accepted(p),"reset clock plus fresh packets recovers checked capture");
}
void derived_geometry() {
  GroundVideoView::View v;v.enabled=true;v.stamp=10;
  require(GroundVideoView::prepare(v,10).accepted,"valid zero camera geometry");
  v.heading=1e308;v.scan_center=1e308;
  require(!GroundVideoView::prepare(v,10).accepted,"finite source angles cannot overflow native basis");
  v={};v.enabled=true;v.stamp=10;v.expansion=1;v.width_deg=45;v.center_m=1e300;v.span_m=1000;
  require(!GroundVideoView::prepare(v,10).accepted,"double-to-float projection overflow is rejected");
  v={};v.enabled=true;v.stamp=10;v.heading=GroundVideoView::pi/2;v.fan=false;
  const auto position=GroundVideoView::position(GroundVideoView::prepare(v,10));
  require(std::abs(position[0])<1e-6 && std::abs(position[2]-1)<1e-6
      && std::abs(position[4]-1)<1e-6 && std::abs(position[6]+1)<1e-6,
      "independent east-facing N/U/E camera basis");
  unsigned getters=0;
  const GroundVideoView::Binding expected{1,2,8};
  const auto binding=[&] {++getters;return expected;};
  require(!GroundVideoView::verify_binding(100,200,300,true,expected,binding) && getters==0,
      "foreign indicator is rejected before any class-specific getter");
  require(GroundVideoView::verify_binding(200,200,300,false,expected,binding) && getters==1,
      "exact original binding admits the typed getter");
  require(!GroundVideoView::verify_binding(300,200,300,false,expected,binding) && getters==1,
      "unowned cloned vtable cannot grant ownership");
}
void captured_camera(EDPARAM& p) {
  seed(p);bool malformed=false;
  const auto source=NativeGroundVideo::read_view(p,true,malformed);
  std::array<std::uintptr_t,2> object{};
  NativeGroundVideo::owned=object.data();NativeGroundVideo::guard.verify(true);
  NativeGroundVideo::api.camera=camera_constructor;
  NativeGroundVideo::view=source;
  AesaRadar::Pose aircraft;aircraft.position={1000,5000,2000};
  NativeGroundVideo::set_aircraft(&aircraft,clock_value);
  const auto first=static_cast<const std::byte*>(NativeGroundVideo::camera(object.data()));
  require(NativeGroundVideo::render.valid,"actual captured camera accepts healthy adapter frame");
  GroundVideoView::Projection projection{};std::memcpy(&projection,first+688,sizeof(projection));
  require(std::abs(projection.near_clip-10)<1e-6 && std::abs(projection.far_clip-37040)<1e-6,
      "actual camera copy retains near/far ABI order");
  const auto serial=NativeGroundVideo::image_state.serial;
  NativeGroundVideo::camera(object.data());
  require(NativeGroundVideo::image_state.serial==serial && constructors==1,
      "repeated eyes/callbacks share one RF image without recreating camera");
  std::array<GroundVideoView::Param,18> dynamic_parameters{};
  struct Buffer {std::uintptr_t data;int count,capacity;} buffer{
      reinterpret_cast<std::uintptr_t>(dynamic_parameters.data()),18,18};
  std::array<double,3> point{};
  NativeGroundVideo::point(object.data(),point.data());
  NativeGroundVideo::parameters(object.data(),&buffer);
  require(point==std::array<double,3>{1030,5000,2000} && dynamic_parameters[4].number==.5f
      && buffer.count==18 && buffer.capacity==18,"actual point/parameter copies share captured camera and preserve host buffer shape");
  auto bad=source;bad.scan_center=NAN;NativeGroundVideo::view=bad;
  NativeGroundVideo::camera(object.data());
  require(!NativeGroundVideo::render.valid && NativeGroundVideo::image_state.serial==serial,
      "invalid candidate cannot overwrite retained captured image");
  clock_value=11;NativeGroundVideo::view=source;
  NativeGroundVideo::view.frozen=true;NativeGroundVideo::view.stamp=clock_value;
  NativeGroundVideo::camera(object.data());
  require(NativeGroundVideo::render.valid && NativeGroundVideo::render.current.stamp==10.2,
      "fresh frozen controls retain original image observation epoch");
  buffer.count=17;dynamic_parameters[0].bits=0x1234;
  NativeGroundVideo::parameters(object.data(),&buffer);
  require(NativeGroundVideo::guard.reason()==7 && dynamic_parameters[0].bits==0x1234,
      "malformed native parameter capacity latches before copying any output");
  NativeGroundVideo::guard.verify(true);
  NativeGroundVideo::camera(object.data());
  require(!NativeGroundVideo::render.valid,"ownership recheck cannot clear latched render fault");
  NativeGroundVideo::reset();
  require(!NativeGroundVideo::image_state.cycle.available() && !NativeGroundVideo::guard.available(),
      "reset retires image/owner/guard transaction together");
  clock_value=10.2;
  NativeGroundVideo::view=source;NativeGroundVideo::view.stamp=clock_value;
  NativeGroundVideo::view.view_epoch=2;NativeGroundVideo::view.collection=2;
  NativeGroundVideo::owned=object.data();NativeGroundVideo::guard.verify(true);
  NativeGroundVideo::set_aircraft(&aircraft,clock_value);
  NativeGroundVideo::camera(object.data());
  require(NativeGroundVideo::render.valid && NativeGroundVideo::render.current.view_epoch==2
      && NativeGroundVideo::image_state.cycle.available(),"fresh owner/collection epoch recovers after reset");
  NativeGroundVideo::reset();
}
void begin_frame(EDPARAM& p,void* object) {
  seed(p);bool malformed=false;
  const auto source=NativeGroundVideo::read_view(p,true,malformed);
  NativeGroundVideo::owned=object;NativeGroundVideo::guard.verify(true);
  NativeGroundVideo::api.camera=camera_constructor;
  NativeGroundVideo::view=source;
  AesaRadar::Pose aircraft;aircraft.position={1000,5000,2000};
  NativeGroundVideo::set_aircraft(&aircraft,clock_value);
  NativeGroundVideo::camera(object);
  require(NativeGroundVideo::render.valid,"fresh actual owner creates an accepted captured frame");
}
void rejected_frame_outputs(void* object) {
  std::array<double,3> point{1,1,1};
  NativeGroundVideo::point(object,point.data());
  require(point==std::array<double,3>{},"retired captured frame cannot publish a stale world point");
  std::array<GroundVideoView::Param,18> params{};params[0].bits=0x123456;
  struct Buffer {std::uintptr_t data;int count,capacity;} buffer{
      reinterpret_cast<std::uintptr_t>(params.data()),18,18};
  NativeGroundVideo::parameters(object,&buffer);
  require(params[0].bits==0x123456 && buffer.count==18 && buffer.capacity==18,
      "retired frame leaves native parameter data and borrowed header untouched");
  bool refresh=false;
  require(!NativeGroundVideo::submit_parameters(object,params,buffer.data,refresh)
      && params[0].bits==0x123456,
      "locked final submission rechecks withdrawal after any earlier callback precheck");
}
void reset_between_callbacks(EDPARAM& p) {
  std::array<std::uintptr_t,2> object{};
  begin_frame(p,object.data());
  const auto before=NativeGroundVideo::epoch.load();
  const unsigned camera_constructors=constructors;
  NativeGroundVideo::reset();
  require(NativeGroundVideo::epoch.load()!=before && !NativeGroundVideo::guard.available()
      && !NativeGroundVideo::image_state.cycle.available(),"reset withdraws generation and image before further submission");
  rejected_frame_outputs(object.data());
  begin_frame(p,object.data());
  require(constructors==camera_constructors,"reset preserves the already-constructed thread-local native value object");
  NativeGroundVideo::reset();
}
void source_between_callbacks(EDPARAM& p) {
  std::array<std::uintptr_t,2> object{};
  begin_frame(p,object.data());
  const auto before=NativeGroundVideo::epoch.load();
  bus["F22_AG_NATIVE_SOURCE_EPOCH"].value=2;
  bool malformed=false;
  const auto rejected=NativeGroundVideo::read_view(p,true,malformed);
  require(!rejected.enabled && NativeGroundVideo::epoch.load()!=before
      && !NativeGroundVideo::image_state.cycle.available() && !NativeGroundVideo::map_reference.enabled,
      "coherent new native source retires image/reference before accepting any old-echo control");
  rejected_frame_outputs(object.data());
  bus["F22_AG_NATIVE_CONTROL_EPOCH"].value=2;
  NativeGroundVideo::view=NativeGroundVideo::read_view(p,true,malformed);
  NativeGroundVideo::camera(object.data());
  require(NativeGroundVideo::render.valid && NativeGroundVideo::image_state.cycle.available(),
      "matching new source consent admits a fresh image after retirement");
  const auto recovered=NativeGroundVideo::epoch.load();
  NativeGroundVideo::read_view(p,true,malformed);
  require(NativeGroundVideo::epoch.load()==recovered,"unchanged source identity does not retire every update");
  NativeGroundVideo::reset();
}
void context_between_callbacks(EDPARAM& p) {
  std::array<std::uintptr_t,2> object{};
  begin_frame(p,object.data());
  const auto before=NativeGroundVideo::epoch.load();
  p.invalidate();bool malformed=false;
  const auto unbound=NativeGroundVideo::read_view(p,true,malformed);
  require(!unbound.enabled && NativeGroundVideo::epoch.load()!=before
      && !NativeGroundVideo::image_state.cycle.available(),
      "unbound replacement context retires captured image before any fresh parameter ports exist");
  rejected_frame_outputs(object.data());
  p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=resolve;
  p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
  p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=store;
  const auto replacement=NativeGroundVideo::read_view(p,true,malformed);
  require(replacement.enabled && !NativeGroundVideo::image_state.cycle.available(),
      "fresh checked replacement context still requires capture with identical numeric controls");
  NativeGroundVideo::view=replacement;NativeGroundVideo::camera(object.data());
  require(NativeGroundVideo::render.valid,"new context recovers by capturing through the actual camera owner");
  NativeGroundVideo::reset();
}
void late_owner_callbacks() {
  std::array<std::uintptr_t,2> previous{},current{};
  NativeGroundVideo::owned=current.data();
  NativeGroundVideo::guard.verify(true);
  NativeGroundVideo::original_release=nullptr;
  NativeGroundVideo::original_destroy=nullptr;
  const auto generation=NativeGroundVideo::epoch.load();
  NativeGroundVideo::release(previous.data());
  NativeGroundVideo::destroy(previous.data(),0);
  require(NativeGroundVideo::guard.available() && NativeGroundVideo::owned.load()==current.data()
      && NativeGroundVideo::epoch.load()==generation,
      "a late previous-owner callback cannot withdraw the current owner");
  NativeGroundVideo::reset();
}
}
void no_strobing_footprint() {
  for (bool gmt : {false,true}) for (bool tracking : {false,true}) {
    GroundVideoView::View view;
    view.gmt=gmt;view.tracking=tracking;
    for (double fraction : {0.,.8,.1,1.}) {
      view.scan_fraction=fraction;
      const auto params=GroundVideoView::parameters(view,false,false);
      require(params[8].number==0,"AESA scan jumps must not draw a cosmetic bright footprint");
      require(params[1].number==static_cast<float>(fraction),"sensor-driven image progress was altered");
      require(params[9].number==(gmt?50.f:0.f),"GMT processing limits were altered");
    }
  }
}
int main() {
  EDPARAM port;
  scalar_admission(port);protected_tracking(port);control_capture_boundaries(port);
  control_header_failures(port);control_source_identity(port);derived_geometry();captured_camera(port);
  reset_between_callbacks(port);source_between_callbacks(port);context_between_callbacks(port);
  late_owner_callbacks();
  no_strobing_footprint();
  std::cout<<"radar camera checks="<<checks<<" failures="<<failures<<'\n';
  return failures?1:0;
}

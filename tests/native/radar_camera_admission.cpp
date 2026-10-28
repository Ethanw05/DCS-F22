// D-R-RAD-001: actual parameter adapter, captured-image owner and camera copies.
// The executable supplies only local numeric storage/clock/constructor ports.
#include "../../EFM/source/NativeGroundVideo.cpp"
#include <iostream>

namespace {
struct Field { double value{};bool converts=true, resolves=true; };
std::map<std::string,Field> bus;
unsigned checks{},failures{},reads{},constructors{},lookups{};
int replace_at=-1;
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
  if (static_cast<int>(reads++)==replace_at) ground_packet(true);
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
  ground_packet();replace_at=-1;reads=0;
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
    require(accepted(p),"unavailable tracking does not invalidate independent imagery");
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
}
int main() {
  EDPARAM port;
  scalar_admission(port);protected_tracking(port);derived_geometry();captured_camera(port);
  std::cout<<"radar camera checks="<<checks<<" failures="<<failures<<'\n';
  return failures?1:0;
}

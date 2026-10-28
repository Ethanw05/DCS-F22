#include "../EFM/source/NativeGroundSensor.cpp"
#include <iostream>
#include <stdexcept>
#define CHECK(x) do{if(!(x))throw std::runtime_error(#x);}while(0)
namespace {
struct Entry {double value{};};
std::map<std::string,Entry> values;
double now=10;
void* parameter(const char*n){return &values[n];}
void write(void*h,double v){static_cast<Entry*>(h)->value=v;}
bool read(const void*h,double&v,bool){v=static_cast<const Entry*>(h)->value;return true;}
double clock_now(){return now;}
void* no_aircraft(){return nullptr;}
struct NativeObject {void **table;};
void *la_table[41]{},*own_table[39]{},*land_table[14]{};
NativeObject la{la_table},own{own_table},land{land_table};void *land_pointer=&land;
void *with_aircraft(){return &la;}
void *get_own(void*){return &own;}
const float *basis(void*){static float p[16]{.953939201f,-.3f,0};return p;}
GroundMovingTargets::Vec *point(void*,GroundMovingTargets::Vec*out){*out={0,1000,0};return out;}
const NativeGroundSensor::VecF *velocity(const void*){static NativeGroundSensor::VecF v{200,0,0};return &v;}
bool ray(void*,const NativeGroundSensor::VecF&from,const NativeGroundSensor::VecF&dir,float max,NativeGroundSensor::VecF*out){
 const double t=-from.u/dir.u;if(t<0||t>max)return false;
 *out={static_cast<float>(from.n+t*dir.n),0,static_cast<float>(from.e+t*dir.e)};return true;
}
void sample_test() {
 using namespace NativeGroundSensor;
 ArrayService service{};
 service.granted=values["F22_AESA_SURFACE_SERVICE"].value==1;
 service.active=true;service.resource=1;
 service.azimuth=values["F22_AESA_SURFACE_AZ"].value;
 service.beam.direction={.953939201,-.3,0};service.beam.half_angle=3*GroundMovingTargets::pi/180;
 service.beam.range_m=5*1852;service.beam.started=now-.02;service.beam.completes=now;service.beam.surface=true;
 sample(reinterpret_cast<void*>(1),service);
}
}
int scenarios(){
 using namespace NativeGroundSensor;
 reset();api.ready=true;api.reason=0;api.clock=&clock_now;api.aircraft=&no_aircraft;
 EDPARAM p;p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=&parameter;
 p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=&write;
 p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=&read;
 for(auto n:{"MAIN_POWER","RADAR_PWR","F22_AG_RADAR_OPERATING"})values[n].value=1;
 values["F22_AESA_CONTROL_RESOURCE"].value=1;values["HUD_MODE"].value=7;values["F22_AG_MODE"].value=2;
 values["F22_AG_VIDEO_FROZEN"].value=1;values["F22_AG_VIDEO_HOLD"].value=1;
 values["F22_AG_VIDEO_SCAN_AZ_DEG"].value=-30;values["F22_AESA_SURFACE_AZ"].value=20*GroundMovingTargets::pi/180;values["F22_AESA_SURFACE_SERVICE"].value=1;
 update(p);CHECK(controls.active&&controls.search);
 CHECK(controls.az==0); // A completed-grant parameter cannot become a new pointing command.
 sample_test();CHECK(last_query==now);
 // Holding the pixels must not prevent the production sampler from running.
 now+=.1;update(p);sample_test();CHECK(last_query==now);
 values["F22_AG_MODE"].value=1;now+=.1;update(p);
 CHECK(controls.active&&controls.search&&controls.map);
 values["F22_AG_RADAR_RANGE_NM"].value=40;update(p);
 AesaRadar::Pose map_pose;map_pose.position.u=3000;
 const auto map_request=pointing(now,map_pose);
 CHECK(map_request.valid&&!map_request.point&&map_request.range_m==40*1852);

 values["F22_AG_TRACK_REQUEST_ACTIVE"].value=1;now+=.1;update(p);
 CHECK(controls.active&&controls.search&&controls.request);
 sample_test();CHECK(last_query==now);
 values["F22_AG_SILENT"].value=1;now+=.1;update(p);CHECK(!controls.active);
 values["F22_AG_ACTIVE"].value=1;now+=.1;update(p);CHECK(controls.active);
 values["F22_AG_MODE"].value=4;now+=.1;update(p);CHECK(controls.sea&&controls.search);
 values["F22_AG_MODE"].value=6;values["F22_AG_TRACK_REQUEST_ACTIVE"].value=0;now+=.1;update(p);CHECK(!controls.search&&!controls.active);
 la_table[40]=reinterpret_cast<void*>(&get_own);land_table[13]=reinterpret_cast<void*>(&ray);
 own_table[38]=reinterpret_cast<void*>(&velocity);
 api.aircraft=&with_aircraft;api.position=&basis;api.point=&point;api.land=&land_pointer;
 values["F22_AG_MODE"].value=7;values["F22_AG_RADAR_RANGE_NM"].value=5;
 now+=.1;update(p);sample_test();update(p);
 CHECK(values["F22_AG_AGR_VALID"].value==0);
 now+=.07;update(p);sample_test();update(p);
 CHECK(values["F22_AG_AGR_VALID"].value==1);
 const auto measured_stamp=values["F22_AG_AGR_TIME"].value;
 values["F22_AESA_SURFACE_SERVICE"].value=0;now+=.1;update(p);sample_test();update(p);
 CHECK(values["F22_AG_AGR_TIME"].value>=measured_stamp);
 const auto coast_stamp=values["F22_AG_AGR_TIME"].value;
 now+=.1;update(p);sample_test();update(p);
 CHECK(values["F22_AG_AGR_TIME"].value==coast_stamp);
 values["F22_AESA_SURFACE_SERVICE"].value=1;now+=.1;update(p);sample_test();update(p);
 CHECK(std::abs(values["F22_AG_AGR_RANGE_FT"].value-3333.3333*3.280839895)<10);
 // An actual surface look must survive the faster air-clock coast throttle.
 values["F22_AESA_SURFACE_SERVICE"].value=0;now+=.02;update(p);sample_test();
 const auto coast_query=last_query;now+=.004;
 ArrayService grant{true,0,1,true};
 grant.beam.direction={.953939201,-.3,0};grant.beam.half_angle=3*GroundMovingTargets::pi/180;
 grant.beam.range_m=5*1852;grant.beam.started=now-.02;grant.beam.completes=now;grant.beam.surface=true;
 sample(reinterpret_cast<void*>(1),grant);
 CHECK(last_query==now && now-coast_query<.015);
 bool sensed=false;for(const auto& report:range_pending)if(report.valid&&report.stamp==now)sensed=true;
 CHECK(sensed);
 AesaRadar::Pose aircraft_pose;aircraft_pose.position={0,1000,0};
 aircraft_pose.forward={.953939201,-.3,0};aircraft_pose.up={.3,.953939201,0};
 auto requested=pointing(now,aircraft_pose);
 CHECK(requested.valid&&requested.point&&!requested.routine);
 CHECK(std::abs(requested.direction.u+.3)<1e-9);
 CHECK(!pointing(now+.6,aircraft_pose).valid);
 const auto previous_controls=controls;
 controls.ranging=false;controls.request=true;controls.request_sequence=42;controls.request_point={5000,0,0};
 requested=pointing(now,aircraft_pose);
 CHECK(requested.point&&requested.direction.u<0&&requested.direction.n>0);
 controls.request=false;controls.search=true;
 output.contacts.clear();Contact retained{7,{10000,0,0},{10,0,0},now-2};retained.filter_valid=true;retained.velocity_valid=true;
 output.contacts.push(retained);
 requested=pointing(now,aircraft_pose);
 CHECK(requested.point&&requested.routine);
 CHECK(std::abs(requested.direction.n/requested.direction.u+10.02)<1e-8);
 retained.filter_valid=false;retained.velocity_valid=false;retained.stamp=now-.8;
 output.contacts.clear();output.contacts.push(retained);
 requested=pointing(now,aircraft_pose);
 CHECK(requested.point&&requested.routine); // Confirm the first hit before the full raster returns.
 controls=previous_controls;

 // A malformed/old/off-direction grant cannot manufacture a fresh range look.
 const auto saved_pending=range_pending;
 grant.resource=0;now+=.02;sample(reinterpret_cast<void*>(1),grant);
 for(const auto& report:range_pending)CHECK(!report.valid||report.stamp<now);
 grant.resource=1;grant.beam.direction={0,0,0};now+=.02;sample(reinterpret_cast<void*>(1),grant);
 for(const auto& report:range_pending)CHECK(!report.valid||report.stamp<now);
 grant.beam.direction={0,1,0};grant.beam.started=now-.02;grant.beam.completes=now;
 now+=.02;sample(reinterpret_cast<void*>(1),grant);
 for(const auto& report:range_pending)CHECK(!report.valid||report.stamp<now);
 range_pending=saved_pending;
 // LOS to a fixed point alone is insufficient: the completed cone must cover it.
 controls.ranging=false;controls.stamp=now;request_sequence=controls.request_sequence;
 fixed=true;selected={0,{5000,0,0},{},now-.1};
 const auto fixed_stamp=selected.stamp;
 grant.beam.direction={.953939201,-.3,0};grant.beam.started=now-.02;grant.beam.completes=now;
 sample(reinterpret_cast<void*>(1),grant);CHECK(selected.stamp==fixed_stamp);
 const double slant=std::hypot(5000.,1000.);
 grant.beam.direction={5000/slant,-1000/slant,0};
 now+=.02;controls.stamp=now;grant.beam.started=now-.02;grant.beam.completes=now;
 sample(reinterpret_cast<void*>(1),grant);CHECK(selected.stamp==now);
 fixed=false;selected={};controls=previous_controls;


 values["F22_AG_ACTIVE"].value=0;now+=.1;update(p);sample_test();update(p);
 CHECK(values["F22_AG_AGR_VALID"].value==0);
 values["MAIN_POWER"].value=0;now+=.1;update(p);CHECK(!controls.active);
 std::cout<<"Actual native ground controls: FRZ/preview do not pause sensing; MAP acquisition without GMT search; power gate PASS\n";
 return 0;
}

int main(){try{return scenarios();}catch(const std::exception& error){std::cerr<<error.what()<<"\n";return 1;}}

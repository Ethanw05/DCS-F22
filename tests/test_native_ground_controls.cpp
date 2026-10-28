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
void *la_table[41]{},*own_table[2]{},*land_table[14]{};
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
 CHECK(std::abs(controls.az-20*GroundMovingTargets::pi/180)<1e-10);
 sample(reinterpret_cast<void*>(1));CHECK(last_query==now);
 // Holding the pixels must not prevent the production sampler from running.
 now+=.1;update(p);sample(reinterpret_cast<void*>(1));CHECK(last_query==now);
 values["F22_AG_MODE"].value=1;now+=.1;update(p);
 CHECK(!controls.active&&!controls.search);
 values["F22_AG_TRACK_REQUEST_ACTIVE"].value=1;now+=.1;update(p);
 CHECK(controls.active&&!controls.search&&controls.request);
 sample(reinterpret_cast<void*>(1));CHECK(last_query==now);
 values["F22_AG_SILENT"].value=1;now+=.1;update(p);CHECK(!controls.active);
 values["F22_AG_ACTIVE"].value=1;now+=.1;update(p);CHECK(controls.active);
 values["F22_AG_MODE"].value=4;now+=.1;update(p);CHECK(controls.sea&&controls.search);
 values["F22_AG_MODE"].value=6;values["F22_AG_TRACK_REQUEST_ACTIVE"].value=0;now+=.1;update(p);CHECK(!controls.search&&!controls.active);
 la_table[40]=reinterpret_cast<void*>(&get_own);land_table[13]=reinterpret_cast<void*>(&ray);
 api.aircraft=&with_aircraft;api.position=&basis;api.point=&point;api.velocity=&velocity;api.land=&land_pointer;
 values["F22_AG_MODE"].value=7;values["F22_AG_RADAR_RANGE_NM"].value=5;
 now+=.1;update(p);sample(reinterpret_cast<void*>(1));update(p);
 CHECK(values["F22_AG_AGR_VALID"].value==0);
 now+=.07;update(p);sample(reinterpret_cast<void*>(1));update(p);
 CHECK(values["F22_AG_AGR_VALID"].value==1);
 const auto measured_stamp=values["F22_AG_AGR_TIME"].value;
 values["F22_AESA_SURFACE_SERVICE"].value=0;now+=.1;update(p);sample(reinterpret_cast<void*>(1));update(p);
 CHECK(values["F22_AG_AGR_TIME"].value>=measured_stamp);
 const auto coast_stamp=values["F22_AG_AGR_TIME"].value;
 now+=.1;update(p);sample(reinterpret_cast<void*>(1));update(p);
 CHECK(values["F22_AG_AGR_TIME"].value==coast_stamp);
 values["F22_AESA_SURFACE_SERVICE"].value=1;now+=.1;update(p);sample(reinterpret_cast<void*>(1));update(p);
 CHECK(std::abs(values["F22_AG_AGR_RANGE_FT"].value-3333.3333*3.280839895)<10);
 // An actual surface look must survive the faster air-clock coast throttle.
 values["F22_AESA_SURFACE_SERVICE"].value=0;now+=.02;update(p);sample(reinterpret_cast<void*>(1));
 const auto coast_query=last_query;now+=.004;
 const ArrayService grant{true,0,1,true};sample(reinterpret_cast<void*>(1),&grant);
 CHECK(last_query==now && now-coast_query<.015);
 bool sensed=false;for(const auto& report:range_pending)if(report.valid&&report.stamp==now)sensed=true;
 CHECK(sensed);
 values["F22_AG_ACTIVE"].value=0;now+=.1;update(p);sample(reinterpret_cast<void*>(1));update(p);
 CHECK(values["F22_AG_AGR_VALID"].value==0);
 values["MAIN_POWER"].value=0;now+=.1;update(p);CHECK(!controls.active);
 std::cout<<"Actual native ground controls: FRZ/preview do not pause sensing; MAP acquisition without GMT search; power gate PASS\n";
 return 0;
}

int main(){try{return scenarios();}catch(const std::exception& error){std::cerr<<error.what()<<"\n";return 1;}}

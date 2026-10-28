// GPL-3.0-or-later. Actual surface coordinator, independent of sensor memory.
#include "../EFM/source/NativeGroundRadar.cpp"
#include <array>
#include <map>
#include <string>
#include <iostream>
#include <stdexcept>
#define CHECK(x)do{if(!(x))throw std::runtime_error(#x);}while(0)
namespace NativeGroundVideo { unsigned updates{}, resets{};void update(EDPARAM&) {++updates;}void reset(){++resets;} }
namespace NativeGroundSensor { unsigned updates{}, resets{};void update(EDPARAM&) {++updates;}void reset(){++resets;} }
namespace {
std::map<std::string,double> values;
void* parameter(const char* n){return &values[n];}
void write(void* p,double v){*static_cast<double*>(p)=v;}
bool read(const void* p,double& v,bool){v=*static_cast<const double*>(p);return true;}
}
int main(){try{
 EDPARAM p;p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=parameter;
 p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=write;
 p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=read;
 for(const auto& status:std::array<std::array<double,2>,4>{{{0,0},{1,0},{0,1},{1,1}}}){
   const bool ready=status[0]==1&&status[1]==1;
   values["F22_AESA_DRIVER_READY"]=status[0];values["F22_AG_GMT_READY"]=status[1];
   values["F22_AG_GMT_REASON"]=3;values["F22_AG_RETURN_COUNT"]=100;
   NativeGroundRadar::update(p);
   CHECK(values["F22_AG_RADAR_NATIVE_READY"]==(ready?1:0));
   CHECK(values["F22_AG_RADAR_NATIVE_REASON"]==(ready?0:status[0]==1?3:4));
   CHECK(values["F22_AG_RETURN_COUNT"]==0);
 }
 CHECK(NativeGroundSensor::updates==4&&NativeGroundVideo::updates==4);
 NativeGroundRadar::reset();CHECK(NativeGroundSensor::resets==1&&NativeGroundVideo::resets==1);
 std::cout<<"Surface coordinator: owned AESA and ground-provider readiness, independent renderer/provider, retired mechanical return cache PASS\n";
 return 0;
}catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}}

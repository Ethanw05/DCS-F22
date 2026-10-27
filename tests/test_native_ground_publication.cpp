// GPL-3.0-or-later. Execute the actual adapter with owned fake host memory.
#include "../EFM/source/NativeGroundRadar.cpp"
#include <array>
#include <iostream>
#include <stdexcept>
#define CHECK(x)do{if(!(x))throw std::runtime_error(#x);}while(0)
namespace NativeGroundVideo { void update(EDPARAM&) {} void reset() {} }
namespace NativeGroundSensor { void update(EDPARAM&) {} void reset() {} }
namespace {
struct Entry { std::string name; double value{}; };
std::map<std::string,Entry> values;
std::vector<std::pair<std::string,double>> writes;
double time_now=100;bool has_context=true;
std::byte* sensor{};std::array<std::uintptr_t,42> table{};
void* parameter(const char* n) {auto& e=values[n];e.name=n;return &e;}
void write(void* h,double v) {auto& e=*static_cast<Entry*>(h);e.value=v;writes.emplace_back(e.name,v);}
bool read(const void* h,double& v,bool) {v=static_cast<const Entry*>(h)->value;return true;}
double clock_now() {return time_now;}
void* context() {return has_context?reinterpret_cast<void*>(0x1000):nullptr;}
void* device(void*,unsigned id) {return id==13?sensor:nullptr;}
template<class T>void field(std::size_t offset,T value) {std::memcpy(sensor+offset,&value,sizeof(value));}
double value(const char* n) {return values[n].value;}
void no_false_unavailable() {
 for(const auto& w:writes) {
  CHECK(w.first!="F22_AG_RADAR_NATIVE_READY" || w.second==1);
  CHECK(w.first!="F22_AG_RADAR_NATIVE_REASON" || w.second==0);
 }
}
}
int main() {
 using namespace NativeGroundRadar;
 sensor=static_cast<std::byte*>(VirtualAlloc(nullptr,4096,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE));CHECK(sensor);
 const auto original=reinterpret_cast<std::uintptr_t>(table.data()+1);field(0,original);
 api.ready=true;api.reason=0;api.table=original;api.context=&context;api.device=&device;api.clock=&clock_now;
 EDPARAM p;p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=&parameter;
 p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=&write;
 p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=&read;
 for(auto item:{std::pair{"F22_RADAR_DEVICE_ID",13.}, {"HUD_MODE",7.}, {"MAIN_POWER",1.}, {"RADAR_PWR",1.}, {"F22_AG_RADAR_RANGE_NM",20.}})
  static_cast<Entry*>(parameter(item.first))->value=item.second;
 std::array<std::byte,144> record{};
 const auto put_record=[&](std::size_t offset,const auto& v){std::memcpy(record.data()+offset,&v,sizeof(v));};
 put_record(0,1000.);put_record(8,20.);put_record(16,2000.);put_record(72,4.f);
 put_record(124,std::uint8_t{1});put_record(128,std::uint32_t{0});
 field(2168,reinterpret_cast<std::uintptr_t>(record.data()));field(2176,reinterpret_cast<std::uintptr_t>(record.data()+144));
 static_cast<Entry*>(parameter("F22_AG_RADAR_NATIVE_READY"))->value=1;
 for(int i=0;i<20;++i) {
  time_now=100+i*.2;put_record(112,time_now);writes.clear();update(p);no_false_unavailable();
  CHECK(value("F22_AG_RADAR_NATIVE_READY")==1 && value("F22_AG_RETURN_COUNT")==1);
  for(const auto& w:writes)CHECK(w.first!="F22_AG_RETURN_COUNT" || w.second==1);
 }
 // A bad/empty observation buffer must clear selection data without cycling
 // availability of an otherwise valid adapter/video source.
 field(2176,reinterpret_cast<std::uintptr_t>(record.data())-1);time_now+=.2;writes.clear();update(p);no_false_unavailable();
 CHECK(value("F22_AG_RADAR_NATIVE_READY")==1 && value("F22_AG_RETURN_COUNT")==0);
 field(2176,reinterpret_cast<std::uintptr_t>(record.data()+144));time_now+=.2;put_record(112,time_now);update(p);
 CHECK(value("F22_AG_RETURN_COUNT")==1);
 static_cast<Entry*>(parameter("HUD_MODE"))->value=0;time_now+=.2;writes.clear();update(p);no_false_unavailable();
 CHECK(value("F22_AG_RETURN_COUNT")==0);
 float clutter{};std::memcpy(&clutter,sensor+2532,sizeof(clutter));CHECK(clutter==0);
 static_cast<Entry*>(parameter("HUD_MODE"))->value=7;time_now+=.2;put_record(112,time_now);update(p);
 CHECK(value("F22_AG_RETURN_COUNT")==1);
 has_context=false;time_now+=.2;update(p);CHECK(value("F22_AG_RADAR_NATIVE_READY")==0 && value("F22_AG_RETURN_COUNT")==0);
 has_context=true;time_now+=.2;put_record(112,time_now);update(p);CHECK(value("F22_AG_RADAR_NATIVE_READY")==1);
 field(0,std::uintptr_t{0});time_now+=.2;update(p);CHECK(value("F22_AG_RADAR_NATIVE_READY")==0 && value("F22_AG_RADAR_NATIVE_REASON")==4);
 field(0,original);time_now+=.2;put_record(112,time_now);update(p);CHECK(value("F22_AG_RADAR_NATIVE_READY")==1);
 DWORD old{};CHECK(VirtualProtect(sensor,4096,PAGE_READONLY,&old));time_now+=.2;update(p);
 CHECK(value("F22_AG_RADAR_NATIVE_READY")==0);CHECK(VirtualProtect(sensor,4096,PAGE_READWRITE,&old));
 time_now+=.2;put_record(112,time_now);update(p);CHECK(value("F22_AG_RADAR_NATIVE_READY")==1);
 time_now=NAN;update(p);CHECK(value("F22_AG_RADAR_NATIVE_READY")==0 && value("F22_AG_RETURN_COUNT")==0);
 reset();VirtualFree(sensor,0,MEM_RELEASE);
 std::cout<<"Actual ground adapter: healthy READY/count never pulse unavailable, real context/ownership/write/clock failures inhibit, recovery PASS\n";
}

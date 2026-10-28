// GPL-3.0-or-later. BombSight ABI checked in the user's installed CockpitBase.
#include "NativeAGWeapons.h"
#include "WeaponFlightFrame.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <map>
#include <limits>
#include <string>

namespace NativeAGWeapons { namespace {
struct Vec { double n,u,e; };
struct FloatVec { float n,u,e; };
struct Type {std::uint8_t one,two,three,pad;std::uint32_t four;};
struct Wind {void** table;FloatVec value;};
void destroy_wind(void*) {}
FloatVec* wind_at(Wind* w,FloatVec* out,const float*) {*out=w->value;return out;}
void* wind_methods[]={reinterpret_cast<void*>(&destroy_wind),reinterpret_cast<void*>(&wind_at)};
std::map<std::string,void*> handles;
void* handle(EDPARAM& p,const char* n) {auto& h=handles[n];if(!h)h=p.getParamHandle(n);return h;}
bool get(EDPARAM& p,const char* n,double& value) {return p.getParamNumber(handle(p,n),value);}
void put(EDPARAM& p,const char* n,double v) {p.setParamNumber(handle(p,n),v);}
struct Request {
 enum Field : std::size_t { Sequence,Valid,Schema,Time,Station,Type3,Type4,N,U,E,VN,VU,VE,WN,WU,WE,Ground,Trajectory,Count };
 static constexpr std::array<const char*,Count> names{{
  "F22_AG_BOMB_REQUEST_SEQUENCE","F22_AG_BOMB_REQUEST_VALID","F22_AG_BOMB_REQUEST_SCHEMA",
  "F22_AG_BOMB_REQUEST_TIME","F22_AG_BOMB_REQUEST_STATION","F22_AG_BOMB_REQUEST_TYPE3",
  "F22_AG_BOMB_REQUEST_TYPE4","F22_AG_BOMB_REQUEST_N","F22_AG_BOMB_REQUEST_U","F22_AG_BOMB_REQUEST_E",
  "F22_AG_BOMB_REQUEST_VN","F22_AG_BOMB_REQUEST_VU","F22_AG_BOMB_REQUEST_VE",
  "F22_AG_BOMB_REQUEST_WN","F22_AG_BOMB_REQUEST_WU","F22_AG_BOMB_REQUEST_WE",
  "F22_AG_BOMB_REQUEST_GROUND_LEVEL","F22_AG_BOMB_REQUEST_TRAJECTORY"}};
 std::array<double,Count> value{};
 std::uint64_t epoch=0;
 bool current(EDPARAM& p) const {
  double sequence=0,valid=0;
  return epoch==p.epoch() && get(p,names[Sequence],sequence) && sequence==value[Sequence]
   && get(p,names[Valid],valid) && valid==1 && epoch==p.epoch();
 }
 bool load(EDPARAM& p,double sequence) {
  epoch=p.epoch();
  for(std::size_t i=0;i<Count;++i)if(!get(p,names[i],value[i]))return false;
  return value[Sequence]==sequence && sequence>=1 && sequence<=16777215 && sequence==std::floor(sequence)
   && value[Valid]==1 && value[Schema]==2 && (value[Trajectory]==0 || value[Trajectory]==1) && current(p);
 }
};
bool failed=false;
struct Api {
 using Ctor=void*(__fastcall*)(void*,const void*);
 using Dtor=void(__fastcall*)(void*);
 using Set=void(__fastcall*)(void*,const Type*);
 using Aim=bool(__fastcall*)(void*,const FloatVec*,const FloatVec*,double,double*,Vec*);
 using Clock=double(__cdecl*)();
 Ctor ctor{};Dtor dtor{};Set type{};Aim aim{};Clock clock{};bool ready{};
 bool resolve() {
  if(ready)return true;
  auto m=GetModuleHandleW(L"CockpitBase.dll");if(!m)return false;
  auto b=reinterpret_cast<const std::byte*>(m);
  auto dos=reinterpret_cast<const IMAGE_DOS_HEADER*>(b);
  if(dos->e_magic!=IMAGE_DOS_SIGNATURE)return false;
  auto pe=reinterpret_cast<const IMAGE_NT_HEADERS64*>(b+dos->e_lfanew);
  if(pe->Signature!=IMAGE_NT_SIGNATURE || pe->FileHeader.TimeDateStamp!=0x6ac12468 || pe->OptionalHeader.SizeOfImage!=0x59a000)return false;
  ctor=reinterpret_cast<Ctor>(GetProcAddress(m,"??0BombSight@cockpit@@QEAA@PEBV?$WindTableProxy_@M@weapon_base@@@Z"));
  dtor=reinterpret_cast<Dtor>(GetProcAddress(m,"??1BombSight@cockpit@@UEAA@XZ"));
  type=reinterpret_cast<Set>(GetProcAddress(m,"?setBombType@BombSight@cockpit@@QEAAXAEBVwsType@@@Z"));
  aim=reinterpret_cast<Aim>(GetProcAddress(m,"?calculate_aim_point@BombSight@cockpit@@UEAA_NAEBVVec3f@osg@@0NAEANAEAVVec3d@4@@Z"));
  auto world=GetModuleHandleW(L"World.dll");
  clock=world?reinterpret_cast<Clock>(GetProcAddress(world,"?GetModelTime@wTime@@SANXZ")):nullptr;
  return ready=ctor&&dtor&&type&&aim&&clock;
 }
} api;
void solve(EDPARAM& p,double request_sequence) {
 put(p,"F22_AG_BOMB_ASYNC_SUPPORTED",2);put(p,"F22_AG_BOMB_RESPONSE_SCHEMA",0);
 put(p,"F22_AG_BOMB_NATIVE_VALID",0);put(p,"F22_AG_BOMB_NATIVE_REASON",1);
 put(p,"F22_AG_BOMB_TRAJECTORY_SUPPORTED",1);put(p,"F22_AG_BOMB_TRAJECTORY_READY",0);put(p,"F22_AG_BOMB_POINT_COUNT",0);
 Request request;
 if(failed || !request.load(p,request_sequence))return;
 const auto& input=request.value;
 WeaponFlightFrame::Snapshot<6> flight;
 if(!flight.load(p,WeaponFlightFrame::motion_names))return;
 if(!api.resolve()){put(p,"F22_AG_BOMB_NATIVE_REASON",2);return;}
 const double now=api.clock(),stamp=input[Request::Time];
 if(!std::isfinite(now)||now<0||stamp<0||now-stamp<-.01||now-stamp>.2)return;
 const double station=input[Request::Station];
 if(station<0||station>10||station!=std::floor(station))return;
 const double third=input[Request::Type3],fourth=input[Request::Type4];
 if(!std::isfinite(third)||!std::isfinite(fourth)||third<0||third>255||third!=std::floor(third)||fourth<=0||fourth>4294967295.0||fourth!=std::floor(fourth))return;
 Type type{4,5,static_cast<std::uint8_t>(third),0,static_cast<std::uint32_t>(fourth)};
 if((type.three!=9&&type.three!=36)||type.four==0)return;
 for(std::size_t i=Request::N;i<=Request::E;++i)
  if(std::abs(input[i])>std::numeric_limits<float>::max())return;
 if(std::hypot(input[Request::VN],input[Request::VU],input[Request::VE])>1200
    || std::hypot(input[Request::WN],input[Request::WU],input[Request::WE])>300)return;
 const FloatVec pos{static_cast<float>(input[Request::N]),static_cast<float>(input[Request::U]),static_cast<float>(input[Request::E])};
 const FloatVec velocity{static_cast<float>(input[Request::VN]),static_cast<float>(input[Request::VU]),static_cast<float>(input[Request::VE])};
 const double level=input[Request::Ground];
 if(!std::isfinite(pos.n)||!std::isfinite(pos.u)||!std::isfinite(pos.e)||!std::isfinite(level)||pos.u-level<5 || pos.u-level>18000)return;
 if(!std::isfinite(std::hypot(velocity.n,velocity.u,velocity.e))||std::hypot(velocity.n,velocity.u,velocity.e)>1200)return;
 Wind wind{wind_methods,{static_cast<float>(input[Request::WN]),static_cast<float>(input[Request::WU]),static_cast<float>(input[Request::WE])}};
 if(!std::isfinite(std::hypot(wind.value.n,wind.value.u,wind.value.e))||std::hypot(wind.value.n,wind.value.u,wind.value.e)>300)return;
 Wind* proxy=&wind;
 const bool path_requested=input[Request::Trajectory]==1;
 alignas(16) std::array<std::byte,512> sight{};
 api.ctor(sight.data(),&proxy);api.type(sight.data(),&type);
 double fall=0;Vec point{};
 bool valid=api.aim(sight.data(),&pos,&velocity,level,&fall,&point);
 // Recover actual descending native trajectory vertices by solving for
 // horizontal planes. Each solve uses the selected native store and wind.
 // Quadratic plane spacing approximates equal free-fall time increments.
 std::array<Vec,17> trajectory{};std::array<double,17> times{};
 const bool solution_valid=valid&&std::isfinite(fall)&&fall>0&&fall<=120&&std::isfinite(point.n)&&std::isfinite(point.u)&&std::isfinite(point.e);
 bool path=path_requested && solution_valid && velocity.u<=5;
 trajectory[0]={pos.n,pos.u,pos.e};trajectory[16]=point;times[16]=fall;
 if(path)for(unsigned i=1;i<16;++i){
  const double fraction=static_cast<double>(i)/16;
  const double plane=pos.u-(pos.u-level)*fraction*fraction;
  if(!api.aim(sight.data(),&pos,&velocity,plane,&times[i],&trajectory[i]) ||
     !std::isfinite(times[i]) || times[i]<=times[i-1] || times[i]>=fall ||
     !std::isfinite(trajectory[i].n)||!std::isfinite(trajectory[i].u)||!std::isfinite(trajectory[i].e)) {path=false;break;}
 }
 api.dtor(sight.data());
 if(!flight.current(p))return;
 // Lua publishes VALID last and clears it before changing frozen inputs.
 // A cancellation/replacement during solver work cannot validate mixed input.
 if(!request.current(p))return;
 if(path){
  char key[64];
  for(unsigned i=0;i<17;++i){
   const char* axes[]={"N","U","E","T"};const double values[]={trajectory[i].n,trajectory[i].u,trajectory[i].e,times[i]};
   for(unsigned j=0;j<4;++j){std::snprintf(key,sizeof(key),"F22_AG_BOMB_%02u_%s",i,axes[j]);put(p,key,values[j]);}
  }
  put(p,"F22_AG_BOMB_POINT_COUNT",17);put(p,"F22_AG_BOMB_TRAJECTORY_READY",1);
 }
 if(!solution_valid){put(p,"F22_AG_BOMB_NATIVE_REASON",3);return;}
 put(p,"F22_AG_BOMB_IMPACT_N",point.n);put(p,"F22_AG_BOMB_IMPACT_U",point.u);put(p,"F22_AG_BOMB_IMPACT_E",point.e);
 put(p,"F22_AG_BOMB_FALL_TIME",fall);put(p,"F22_AG_BOMB_RESULT_TIME",now);
 put(p,"F22_AG_BOMB_NATIVE_REASON",0);put(p,"F22_AG_BOMB_NATIVE_VALID",1);
 {
  put(p,"F22_AG_BOMB_RESPONSE_SCHEMA",2);put(p,"F22_AG_BOMB_RESPONSE_REQUEST_TIME",stamp);
  put(p,"F22_AG_BOMB_RESPONSE_STATION",station);
  put(p,"F22_AG_BOMB_RESPONSE_TYPE3",third);put(p,"F22_AG_BOMB_RESPONSE_TYPE4",fourth);
 }
}
} // namespace
void reset(){handles.clear();failed=false;}
void update(EDPARAM& p){
 double sequence=0;
 __try {
  if(!get(p,"F22_AG_BOMB_REQUEST_SEQUENCE",sequence)) {
   put(p,"F22_AG_BOMB_NATIVE_VALID",0);put(p,"F22_AG_BOMB_TRAJECTORY_READY",0);
   put(p,"F22_AG_BOMB_POINT_COUNT",0);return;
  }
  solve(p,sequence);
 }
 __except(EXCEPTION_EXECUTE_HANDLER){failed=true;put(p,"F22_AG_BOMB_NATIVE_VALID",0);put(p,"F22_AG_BOMB_NATIVE_REASON",4);}
 put(p,"F22_AG_BOMB_RESPONSE_SEQUENCE",sequence);
}
}

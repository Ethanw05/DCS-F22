// GPL-3.0-or-later. BombSight ABI checked in the user's installed CockpitBase.
#include "NativeAGWeapons.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <map>
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
double get(EDPARAM& p,const char* n) {return p.getParamNumber(handle(p,n));}
void put(EDPARAM& p,const char* n,double v) {p.setParamNumber(handle(p,n),v);}
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
 if(failed || get(p,"F22_AG_BOMB_REQUEST_VALID")<.5)return;
 if(!api.resolve()){put(p,"F22_AG_BOMB_NATIVE_REASON",2);return;}
 double now=api.clock(),stamp=get(p,"F22_AG_BOMB_REQUEST_TIME");
 if(!std::isfinite(now)||!std::isfinite(stamp)||now-stamp<-.01||now-stamp>.2)return;
 const bool frozen=get(p,"F22_AG_BOMB_REQUEST_SCHEMA")==2;
 const double station=frozen?get(p,"F22_AG_BOMB_REQUEST_STATION"):-1;
 if(frozen && (!std::isfinite(station)||station<0||station>10||station!=std::floor(station)))return;
 const double third=get(p,frozen?"F22_AG_BOMB_REQUEST_TYPE3":"F22_AG_WEAPON_TYPE3"),fourth=get(p,frozen?"F22_AG_BOMB_REQUEST_TYPE4":"F22_AG_WEAPON_TYPE4");
 if(!std::isfinite(third)||!std::isfinite(fourth)||third<0||third>255||third!=std::floor(third)||fourth<=0||fourth>4294967295.0||fourth!=std::floor(fourth))return;
 Type type{4,5,static_cast<std::uint8_t>(third),0,static_cast<std::uint32_t>(fourth)};
 if((type.three!=9&&type.three!=36)||type.four==0)return;
 FloatVec pos{static_cast<float>(get(p,frozen?"F22_AG_BOMB_REQUEST_N":"F22_AG_OWN_N")),static_cast<float>(get(p,frozen?"F22_AG_BOMB_REQUEST_U":"F22_AG_OWN_U")),static_cast<float>(get(p,frozen?"F22_AG_BOMB_REQUEST_E":"F22_AG_OWN_E"))};
 FloatVec velocity{static_cast<float>(get(p,"EFM_HUD_VN")),static_cast<float>(get(p,"EFM_HUD_VU")),static_cast<float>(get(p,"EFM_HUD_VE"))};
 if(get(p,"F22_AG_RELEASE_VELOCITY_VALID")>.5)velocity={static_cast<float>(get(p,"F22_AG_RELEASE_VN")),static_cast<float>(get(p,"F22_AG_RELEASE_VU")),static_cast<float>(get(p,"F22_AG_RELEASE_VE"))};
 if(frozen)velocity={static_cast<float>(get(p,"F22_AG_BOMB_REQUEST_VN")),static_cast<float>(get(p,"F22_AG_BOMB_REQUEST_VU")),static_cast<float>(get(p,"F22_AG_BOMB_REQUEST_VE"))};
 double level=get(p,frozen?"F22_AG_BOMB_REQUEST_GROUND_LEVEL":"F22_AG_BOMB_GROUND_LEVEL");
 if(!std::isfinite(pos.n)||!std::isfinite(pos.u)||!std::isfinite(pos.e)||!std::isfinite(level)||pos.u-level<5 || pos.u-level>18000)return;
 if(!std::isfinite(std::hypot(velocity.n,velocity.u,velocity.e))||std::hypot(velocity.n,velocity.u,velocity.e)>1200)return;
 Wind wind{wind_methods,{static_cast<float>(get(p,"EFM_HUD_WN")),static_cast<float>(get(p,"EFM_HUD_WU")),static_cast<float>(get(p,"EFM_HUD_WE"))}};
 if(frozen)wind.value={static_cast<float>(get(p,"F22_AG_BOMB_REQUEST_WN")),static_cast<float>(get(p,"F22_AG_BOMB_REQUEST_WU")),static_cast<float>(get(p,"F22_AG_BOMB_REQUEST_WE"))};
 if(!std::isfinite(std::hypot(wind.value.n,wind.value.u,wind.value.e))||std::hypot(wind.value.n,wind.value.u,wind.value.e)>300)return;
 Wind* proxy=&wind;
 const bool path_requested=get(p,frozen?"F22_AG_BOMB_REQUEST_TRAJECTORY":"F22_AG_BOMB_TRAJECTORY_REQUEST")>.5;
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
 // Lua publishes VALID last and clears it before changing frozen inputs.
 // A cancellation/replacement during solver work cannot validate mixed input.
 if(get(p,"F22_AG_BOMB_REQUEST_VALID")<.5 || get(p,"F22_AG_BOMB_REQUEST_SEQUENCE")!=request_sequence)return;
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
 if(frozen){
  put(p,"F22_AG_BOMB_RESPONSE_SCHEMA",2);put(p,"F22_AG_BOMB_RESPONSE_REQUEST_TIME",stamp);
  put(p,"F22_AG_BOMB_RESPONSE_STATION",station);
  put(p,"F22_AG_BOMB_RESPONSE_TYPE3",third);put(p,"F22_AG_BOMB_RESPONSE_TYPE4",fourth);
 }
}
} // namespace
void reset(){handles.clear();failed=false;}
void update(EDPARAM& p){
 double sequence=0;
 __try {sequence=get(p,"F22_AG_BOMB_REQUEST_SEQUENCE");solve(p,sequence);}
 __except(EXCEPTION_EXECUTE_HANDLER){failed=true;put(p,"F22_AG_BOMB_NATIVE_VALID",0);put(p,"F22_AG_BOMB_NATIVE_REASON",4);}
 put(p,"F22_AG_BOMB_RESPONSE_SEQUENCE",sequence);
}
}

// Fake-host contract tests; actual DCS exports/physics still need runtime validation.
#include "../EFM/source/NativeGunSight.cpp"
#include <iostream>
#include <stdexcept>
using namespace NativeGunSight;
namespace { NativeAesaRadar::GunMotion native_motion{}; bool native_available = true; }
namespace NativeAesaRadar {
bool gun_motion(unsigned track, std::uint64_t generation, GunMotion& out) noexcept {
 if (!native_available || track != 42 || generation != 7) return false;
 out = native_motion; out.generation = generation; out.time = NativeGunSight::api.clock(); return true;
}
}
#define CHECK(x) do{if(!(x))throw std::runtime_error(#x);}while(0)
namespace {
std::map<std::string,double> values;
void* param(const char* name){return &values[name];}
void set(void* p,double v){*static_cast<double*>(p)=v;}
bool read(const void* p,double& v,bool){v=*static_cast<const double*>(p);return true;}
alignas(16) std::array<std::byte,32> weapon{};
void* human_table[41]{};void** human=human_table;
void* aircraft_table[52]{};void** aircraft=aircraft_table;
void* context_data[3]{};
alignas(16) std::array<std::byte,184> descriptor{};
double queue_delay=0;
double fake_now=-1,muzzle_n=1,muzzle_e=0,gun_yaw=0;
double clock(){return fake_now>=0 ? fake_now : values["F22_GUN_REQUEST_TIME"]+queue_delay;}
void* context(){return context_data;}
void* device(void*,unsigned id){CHECK(id==15);return weapon.data();}
const void* shell(void*){return descriptor.data();}
void* construct(void* p,const void* d){CHECK(d==descriptor.data());return p;}
void destroy(void*){}
void* aircraft_get(void*){return &aircraft;}
void pose(void*,float* m,unsigned char index,unsigned zero,unsigned other){CHECK(index==255&&zero==0&&other==0);
 for(int i=0;i<16;++i)m[i]=0;m[0]=static_cast<float>(std::cos(gun_yaw));m[2]=static_cast<float>(std::sin(gun_yaw));
 m[5]=m[10]=m[15]=1;m[12]=static_cast<float>(muzzle_n);m[13]=5000.5f;m[14]=static_cast<float>(muzzle_e);}
int flight(void*,double altitude,double t,const V* v,Wind* w,V* out,double max_time){
 CHECK(max_time==4&&std::abs(altitude-5000.5)<1e-5);
 WindVector actual{};auto getwind=reinterpret_cast<WindVector*(*)(Wind*,WindVector*,const float*)>(w->table[1]);float h=static_cast<float>(altitude);getwind(w,&actual,&h);
 CHECK(actual.z==12);
 *out=(*v)*t+V{0,altitude-4.9*t*t,0};return 1;
}
}
int main(){
 EDPARAM p;p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=param;p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=set;p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=read;
 api.ready=true;api.context=context;api.device=device;api.shell=shell;api.ctor=construct;api.dtor=destroy;api.time=flight;api.clock=clock;
 api.vtable=reinterpret_cast<void*>(0x12345);std::memcpy(weapon.data(),&api.vtable,8);
 void* ctx=context_data;std::memcpy(weapon.data()+24,&ctx,8);context_data[2]=&human;
 human_table[40]=reinterpret_cast<void*>(&aircraft_get);aircraft_table[51]=reinterpret_cast<void*>(&pose);
 double speed=1030;std::memcpy(descriptor.data()+176,&speed,8);
 values["F22_GUN_REQUEST_VALID"]=1;values["F22_GUN_DEVICE_ID"]=15;values["F22_GUN_REQUEST_SEQUENCE"]=17;values["F22_GUN_TRACK_ID"]=42;
 values["F22_GUN_INPUT_SOURCE"]=2;values["F22_GUN_REQUEST_GENERATION"]=7;
 native_motion.position={801,5000.5,30};native_motion.velocity={220,0,0};native_motion.acceleration={30,0,0};
 values["F22_GUN_OWN_U"]=5000;values["F22_GUN_TARGET_N"]=801;values["F22_GUN_TARGET_U"]=5000.5;values["F22_GUN_TARGET_E"]=30;
 values["F22_GUN_VN"]=220;values["F22_GUN_VE"]=0;values["F22_GUN_AN"]=30;values["EFM_HUD_VN"]=220;values["EFM_HUD_WE"]=12;
 update(p);CHECK(values["F22_GUN_SOLUTION_VALID"]==1);CHECK(values["F22_GUN_SOLUTION_SEQUENCE"]==17);
 CHECK(values["F22_GUN_RESULT_SCHEMA"]==2);
 CHECK(values["F22_GUN_CURRENT_N"]==801&&values["F22_GUN_CURRENT_VN"]==220&&values["F22_GUN_CURRENT_AN"]==30);

 CHECK(values["F22_GUN_MNV_VALID"]==1&&values["F22_GUN_MNV_ID"]==42);
 CHECK(std::isfinite(values["F22_GUN_MNV_LOW_N"])&&std::isfinite(values["F22_GUN_MNV_LEFT_E"]));
 double t=values["F22_GUN_TOF"];CHECK(t>.5&&t<1.5);CHECK(values["F22_GUN_MUZZLE_U"]==5000.5);
 V dir{values["F22_GUN_AIM_N"],values["F22_GUN_AIM_U"],values["F22_GUN_AIM_E"]};
 V bullet=V{1,5000.5,0}+(dir*1030+V{220,0,0})*t+V{0,-4.9*t*t,0};
 V target=V{801,5000.5,30}+V{220,0,0}*t+V{15*t*t,0,0};CHECK((bullet-target).norm()<.25);
 values["F22_GUN_MEASUREMENT_AGE"]=.12;values["F22_GUN_REQUEST_TIME"]=.02;values["F22_GUN_TRACK_ID"]=42;
 update(p);CHECK(values["F22_GUN_SOLUTION_VALID"]==1);
 t=values["F22_GUN_TOF"];dir={values["F22_GUN_AIM_N"],values["F22_GUN_AIM_U"],values["F22_GUN_AIM_E"]};
 bullet=V{1,5000.5,0}+(dir*1030+V{220,0,0})*t+V{0,-4.9*t*t,0};
 double horizon=t;target=V{801,5000.5,30}+V{220,0,0}*horizon+V{15*horizon*horizon,0,0};
 CHECK((bullet-target).norm()<.25);CHECK(values["F22_GUN_CURRENT_N"]==801);
 CHECK(values["F22_GUN_RESULT_TIME"]==.02&&values["F22_GUN_RESULT_TRACK_ID"]==42);
 CHECK(values["F22_GUN_CURRENT_VN"]==220&&values["F22_GUN_CURRENT_AN"]==30);

 CHECK(values["F22_GUN_ACTUAL_ENDPOINT_VALID"]==1);
 CHECK(values["F22_GUN_RESPONSE_SEQUENCE"]==17);
 queue_delay=.02;values["F22_GUN_MEASUREMENT_AGE"]=.03;values["F22_GUN_REQUEST_TIME"]=.1;
 values["F22_GUN_REQUEST_SEQUENCE"]=18;update(p);CHECK(values["F22_GUN_SOLUTION_VALID"]==1);
 CHECK(values["F22_GUN_RESPONSE_SEQUENCE"]==18);CHECK(std::abs(values["F22_GUN_RESULT_TIME"]-.12)<1e-9);
 CHECK(values["F22_GUN_CURRENT_N"]==801);
 // Old noisy AESA P/V/A are never reused as the native weapon state. Queue
 // freshness remains independently bounded even when the native input is current.
 values["F22_GUN_MEASUREMENT_AGE"]=.306;values["F22_GUN_REQUEST_SEQUENCE"]=20;
 update(p);CHECK(values["F22_GUN_SOLUTION_VALID"]==1);
 CHECK(values["F22_GUN_CURRENT_N"]==801);
 values["F22_GUN_MEASUREMENT_AGE"]=.49;update(p);
 CHECK(values["F22_GUN_SOLUTION_VALID"]==1); // Native state is sampled now, independently of old radar epoch.
 CHECK(values["F22_GUN_RESULT_SOURCE"]==2 && values["F22_GUN_RESULT_GENERATION"]==7);
 values["F22_GUN_TARGET_N"]=NAN;values["F22_GUN_VE"]=NAN;values["F22_GUN_AU"]=NAN;
 update(p);CHECK(values["F22_GUN_SOLUTION_VALID"]==1 && values["F22_GUN_CURRENT_N"]==801);
 native_available=false;update(p);CHECK(values["F22_GUN_SOLUTION_VALID"]==0 && values["F22_GUN_SOLVER_REASON"]==9);
 native_available=true;values["F22_GUN_REQUEST_GENERATION"]=8;update(p);CHECK(values["F22_GUN_SOLUTION_VALID"]==0);
 values["F22_GUN_REQUEST_GENERATION"]=7;values["F22_GUN_MEASUREMENT_AGE"]=.03;
 queue_delay=.3;values["F22_GUN_REQUEST_SEQUENCE"]=19;update(p);
 CHECK(values["F22_GUN_SOLUTION_VALID"]==0&&values["F22_GUN_RESPONSE_SEQUENCE"]==19&&values["F22_GUN_SOLVER_REASON"]==8);
 queue_delay=0;
 values["F22_GUN_REQUEST_VALID"]=0;update(p);CHECK(values["F22_GUN_SOLUTION_VALID"]==0&&values["F22_GUN_RESULT_SCHEMA"]==0);
 values["F22_GUN_REQUEST_VALID"]=1;double bad=NAN;std::memcpy(descriptor.data()+176,&bad,8);update(p);CHECK(values["F22_GUN_SOLUTION_VALID"]==0&&values["F22_GUN_SOLVER_REASON"]==4);CHECK(values["F22_GUN_RESPONSE_SEQUENCE"]==19);
 failed=true;NativeGunSight::reset();CHECK(!failed&&handles.empty()&&!previous.valid);
 // No-lock funnel uses actual shell service, historical muzzle/velocity/wind.
 values["F22_GUN_REQUEST_VALID"]=0;values["F22_FUNNEL_REQUEST_VALID"]=1;
 values["F22_FUNNEL_OWN_U"]=5000;std::memcpy(descriptor.data()+176,&speed,8);
 for(int i=0;i<=70;++i) {
  fake_now=i*.02;muzzle_n=1+220*fake_now;values["F22_FUNNEL_OWN_N"]=220*fake_now;
  values["F22_FUNNEL_REQUEST_TIME"]=fake_now;update(p);
 }
 CHECK(values["F22_FUNNEL_NATIVE_VALID"]==1 && values["F22_GUN_SOLUTION_VALID"]==0);
 CHECK(values["F22_FUNNEL_07_VALID"]==1);
 CHECK(std::abs(values["F22_FUNNEL_07_N"]-(1+220*fake_now+1030*1.2))<.01);
 CHECK(std::abs(values["F22_FUNNEL_07_U"]-(5000.5-4.9*1.2*1.2))<1e-6);
 // Keep gathering real history during STT, suppress the funnel, restore on loss.
 values["F22_RADAR_STT_VALID"]=1;fake_now+=.02;muzzle_n+=4.4;
 values["F22_FUNNEL_OWN_N"]+=4.4;values["F22_FUNNEL_REQUEST_TIME"]=fake_now;update(p);
 CHECK(values["F22_FUNNEL_NATIVE_VALID"]==0 && !funnel_history.empty());
 values["F22_RADAR_STT_VALID"]=0;update(p);CHECK(values["F22_FUNNEL_NATIVE_VALID"]==1);
 // Turn-dependent native launch directions must bend the virtual stream.
 funnel_history.clear();
 for(int i=0;i<=70;++i) {
  fake_now=3+i*.02;gun_yaw=.1*i*.02;
  muzzle_n=1+2200*std::sin(gun_yaw);muzzle_e=2200*(1-std::cos(gun_yaw));
  values["F22_FUNNEL_OWN_N"]=muzzle_n-1;values["F22_FUNNEL_OWN_E"]=muzzle_e;
  values["EFM_HUD_VN"]=220*std::cos(gun_yaw);values["EFM_HUD_VE"]=220*std::sin(gun_yaw);
  values["F22_FUNNEL_REQUEST_TIME"]=fake_now;update(p);
 }
 CHECK(values["F22_FUNNEL_NATIVE_VALID"]==1);
 V relative{values["F22_FUNNEL_07_N"]-muzzle_n,values["F22_FUNNEL_07_U"]-5000.5,values["F22_FUNNEL_07_E"]-muzzle_e};
 CHECK(relative.z*std::cos(gun_yaw)-relative.x*std::sin(gun_yaw)<-50);
 fake_now+=2;values["F22_FUNNEL_REQUEST_TIME"]=fake_now;update(p);
 CHECK(values["F22_FUNNEL_NATIVE_VALID"]==0 && funnel_history.size()==1);
 values["F22_FUNNEL_REQUEST_VALID"]=0;update(p);CHECK(funnel_history.empty());
 values["F22_AG_OWN_N"]=muzzle_n;values["F22_AG_OWN_U"]=5000;values["F22_AG_OWN_E"]=muzzle_e;
 values["F22_AG_GUN_REQUEST_VALID"]=1;values["F22_AG_GUN_REQUEST_TIME"]=fake_now;
 update(p);CHECK(values["F22_AG_GUN_NATIVE_VALID"]==1&&values["F22_AG_GUN_POINT_COUNT"]==81);
 CHECK(std::abs(values["F22_AG_GUN_00_U"]-5000.5)<.01&&values["F22_AG_GUN_80_U"]<4990);
 values["F22_AG_GUN_REQUEST_TIME"]=fake_now-1;update(p);CHECK(values["F22_AG_GUN_NATIVE_VALID"]==0);
 std::cout<<"Gun adapter: shell input, world muzzle/bore, wind callback, intercept, ground trajectory, response token and invalidation OK\n";
}

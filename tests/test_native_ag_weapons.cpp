// Adapter contract only; actual host ballistics require an in-game drop.
#include "../EFM/source/NativeAGWeapons.cpp"
#include <iostream>
#include <stdexcept>
#define CHECK(x) do{if(!(x))throw std::runtime_error(#x);}while(0)
using namespace NativeAGWeapons;
namespace {
std::map<std::string,double> values;int constructors=0,destructors=0,solves=0;bool trajectory=false;int mutate_request=0;
void* parameter(const char* n){return &values[n];}
void write(void* p,double v){*static_cast<double*>(p)=v;}
bool read(const void* p,double& v,bool){v=*static_cast<const double*>(p);return true;}
double now(){return 100;}
void* construct(void* p,const void* proxy){
 ++constructors;auto w=*static_cast<Wind*const*>(proxy);
 FloatVec out{};wind_at(w,&out,nullptr);CHECK(out.e==12);return p;
}
void destroy(void*){++destructors;}
void type(void*,const Type* t){CHECK(t->one==4&&t->two==5&&t->three==9&&t->four==32);}
bool aim(void*,const FloatVec* p,const FloatVec* v,double level,double* fall,Vec* out){
 ++solves;CHECK(p->u==2000&&v->n==200);
 if(mutate_request==1)values["F22_AG_BOMB_REQUEST_STATION"]=6;
 if(mutate_request==2)values["F22_AG_BOMB_REQUEST_SEQUENCE"]+=1;
 if(trajectory){*fall=std::sqrt(2*(p->u-level)/9.81);*out={p->n+v->n**fall,level,p->e+12**fall};}
 else {CHECK(level==300);*fall=17;*out={p->n+3200,level,p->e+25};}
 return true;
}
}
int main(){
 EDPARAM p;p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=&parameter;p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=&write;p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=&read;
 api.ready=true;api.ctor=&construct;api.dtor=&destroy;api.type=&type;api.aim=&aim;api.clock=&now;
 values={{"F22_AG_BOMB_REQUEST_VALID",1},{"F22_AG_BOMB_REQUEST_TIME",100},{"F22_AG_BOMB_REQUEST_SEQUENCE",7},
 {"F22_AG_WEAPON_TYPE3",9},{"F22_AG_WEAPON_TYPE4",32},{"F22_AG_OWN_U",2000},{"EFM_HUD_VN",200},{"EFM_HUD_WE",12},{"F22_AG_BOMB_GROUND_LEVEL",300}};
 update(p);CHECK(values["F22_AG_BOMB_NATIVE_VALID"]==1&&values["F22_AG_BOMB_FALL_TIME"]==17);
 CHECK(values["F22_AG_BOMB_IMPACT_N"]==3200&&values["F22_AG_BOMB_IMPACT_U"]==300&&values["F22_AG_BOMB_IMPACT_E"]==25);
 CHECK(values["F22_AG_BOMB_RESPONSE_SEQUENCE"]==7&&constructors==1&&destructors==1);
 values["F22_AG_BOMB_REQUEST_TIME"]=99;update(p);CHECK(values["F22_AG_BOMB_NATIVE_VALID"]==0&&solves==1);
 values["F22_AG_BOMB_REQUEST_TIME"]=100;values["F22_AG_WEAPON_TYPE3"]=7;update(p);CHECK(solves==1);
 values["F22_AG_WEAPON_TYPE3"]=9;values["F22_AG_BOMB_GROUND_LEVEL"]=2000;update(p);CHECK(solves==1);
 trajectory=true;values["F22_AG_BOMB_GROUND_LEVEL"]=300;values["F22_AG_BOMB_TRAJECTORY_REQUEST"]=1;update(p);
 CHECK(values["F22_AG_BOMB_TRAJECTORY_SUPPORTED"]==1&&values["F22_AG_BOMB_TRAJECTORY_READY"]==1&&values["F22_AG_BOMB_POINT_COUNT"]==17);
 CHECK(constructors==2&&destructors==2&&solves==17);
 double previous=0;
 for(unsigned i=1;i<17;++i){char key[64];std::snprintf(key,sizeof(key),"F22_AG_BOMB_%02u_T",i);CHECK(values[key]>previous);previous=values[key];}
 CHECK(values["F22_AG_BOMB_16_U"]==300&&values["F22_AG_BOMB_00_U"]==2000);
 values["EFM_HUD_VU"]=10;update(p);CHECK(values["F22_AG_BOMB_NATIVE_VALID"]==1&&values["F22_AG_BOMB_TRAJECTORY_READY"]==0);
 // Version-two request inputs stay independent of current display/live state.
 values["F22_AG_BOMB_REQUEST_SCHEMA"]=2;values["F22_AG_BOMB_REQUEST_STATION"]=4;
 values["F22_AG_BOMB_REQUEST_TYPE3"]=9;values["F22_AG_BOMB_REQUEST_TYPE4"]=32;
 values["F22_AG_BOMB_REQUEST_N"]=100;values["F22_AG_BOMB_REQUEST_U"]=2000;values["F22_AG_BOMB_REQUEST_E"]=200;
 values["F22_AG_BOMB_REQUEST_VN"]=200;values["F22_AG_BOMB_REQUEST_VU"]=0;values["F22_AG_BOMB_REQUEST_WE"]=12;
 values["F22_AG_BOMB_REQUEST_GROUND_LEVEL"]=300;values["F22_AG_BOMB_REQUEST_TRAJECTORY"]=1;
 values["F22_AG_WEAPON_TYPE3"]=7;values["F22_AG_WEAPON_TYPE4"]=999;values["F22_AG_OWN_U"]=-1;
 values["EFM_HUD_VN"]=999;values["EFM_HUD_WE"]=-99;
 update(p);CHECK(values["F22_AG_BOMB_ASYNC_SUPPORTED"]==2&&values["F22_AG_BOMB_RESPONSE_SCHEMA"]==2);
 CHECK(values["F22_AG_BOMB_NATIVE_VALID"]==1&&values["F22_AG_BOMB_TRAJECTORY_READY"]==1&&values["F22_AG_BOMB_00_N"]==100);
 CHECK(values["F22_AG_BOMB_RESPONSE_STATION"]==4&&values["F22_AG_BOMB_RESPONSE_TYPE3"]==9&&values["F22_AG_BOMB_RESPONSE_TYPE4"]==32&&values["F22_AG_BOMB_RESPONSE_REQUEST_TIME"]==100);
 mutate_request=1;update(p);CHECK(values["F22_AG_BOMB_RESPONSE_STATION"]==4);
 values["F22_AG_BOMB_REQUEST_STATION"]=4;mutate_request=2;update(p);CHECK(values["F22_AG_BOMB_NATIVE_VALID"]==0&&values["F22_AG_BOMB_RESPONSE_SCHEMA"]==0);
 mutate_request=0;values["F22_AG_BOMB_REQUEST_STATION"]=-1;update(p);CHECK(values["F22_AG_BOMB_NATIVE_VALID"]==0);
 CHECK(constructors==destructors);
 std::cout<<"Native bomb adapter: selected-store type, terrain level, world axes, wind, timestamp, response and balanced lifetime PASS\n";
}

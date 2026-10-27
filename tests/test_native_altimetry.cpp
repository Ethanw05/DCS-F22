// GPL-3.0-or-later. Public-EFM static pressure to indicated altitude and freshness contract.
#include "../EFM/source/NativeAltimetry.cpp"
#include <iostream>
#include <stdexcept>
#define CHECK(x)do{if(!(x))throw std::runtime_error(#x);}while(0)
using namespace NativeAltimetry;
namespace {std::map<std::string,double> values;double time_now=100;
void* parameter(const char*n){return &values[n];}void write(void*p,double v){*static_cast<double*>(p)=v;}
bool read(const void*p,double&v,bool){v=*static_cast<const double*>(p);return true;}double clock(){return time_now;}}
int main(){EDPARAM p;p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=&parameter;
p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=&write;p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=&read;clock_fn=&clock;
update(p,101325,true);double h=0;CHECK(altitude(h)&&std::abs(h)<1e-8);
update(p,89874.5629,true);CHECK(altitude(h)&&std::abs(h-1000)<.01);
update(p,22632.0401,true);CHECK(altitude(h)&&std::abs(h-11000)<.01);
update(p,5474.8774,true);CHECK(altitude(h)&&std::abs(h-20000)<.02);
values["F22_ALT_PRESSURE_REQUEST_VALID"]=1;values["F22_ALT_PRESSURE_REQUEST_TIME"]=100;values["F22_ALT_PRESSURE_MMHG"]=750;
update(p,89874.5629,true);CHECK(altitude(h)&&h<900&&values["F22_ALT_ACTUAL_PRESSURE_MMHG"]==750);
values["F22_ALT_PRESSURE_MMHG"]=760;update(p,89874.5629,true);CHECK(altitude(h)&&std::abs(h-1000)<.01);
time_now=101;update(p,89874.5629,true);CHECK(!altitude(h)&&values["F22_ALTIMETER_NATIVE_REASON"]==5);
values["F22_ALT_PRESSURE_REQUEST_TIME"]=102;update(p,89874.5629,true);CHECK(!altitude(h));
values["F22_ALT_PRESSURE_REQUEST_TIME"]=101;values["F22_ALT_PRESSURE_MMHG"]=NAN;update(p,89874.5629,true);CHECK(!altitude(h));
values["F22_ALT_PRESSURE_MMHG"]=760;update(p,NAN,true);CHECK(!altitude(h));update(p,89874.5629,false);CHECK(!altitude(h));
reset();CHECK(!altitude(h));std::cout<<"Standalone altimetry: ISA reference points, QNH datum, stale/future/invalid input and reset PASS\n";}

// GPL-3.0-or-later. Standalone pressure altimeter driven by the public EFM atmosphere callback.
#include "NativeAltimetry.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <cmath>
#include <map>
#include <string>
namespace NativeAltimetry { namespace {
using Clock=double(__cdecl*)();
Clock clock_fn{};
std::map<std::string,void*> handles;
double stamp=-100,value=0,selected=760;bool valid=false;
void* handle(EDPARAM&p,const char*n){auto&h=handles[n];if(!h)h=p.getParamHandle(n);return h;}
double get(EDPARAM&p,const char*n){return p.getParamNumber(handle(p,n));}
void put(EDPARAM&p,const char*n,double v){p.setParamNumber(handle(p,n),v);}
// ICAO standard-atmosphere pressure height: troposphere, then isothermal 11-20 km layer.
// Altimeter setting shifts the datum, rather than changing the atmosphere's temperature.
double pressure_height(double pa){
 constexpr double g=9.80665,R=287.05287,T0=288.15,L=.0065,H=11000,T11=216.65;
 const double p11=101325*std::pow(T11/T0,g/(R*L));
 return pa>=p11 ? T0/L*(1-std::pow(pa/101325,R*L/g)) : H-R*T11/g*std::log(pa/p11);
}
}
void reset(){handles.clear();valid=false;stamp=-100;value=0;selected=760;clock_fn=nullptr;}
void update(EDPARAM&p,double static_pressure_pa,bool sample_valid){
 const auto unavailable=[&](int reason){valid=false;put(p,"F22_ALTIMETER_NATIVE_VALID",0);put(p,"F22_ALTIMETER_NATIVE_READY",0);put(p,"F22_ALTIMETER_NATIVE_REASON",reason);};
 // Preserve the last fresh healthy publication while solving the next sample.
 // Concurrent cockpit readers must not see a manufactured invalid pulse each frame.
 if(!clock_fn){auto world=GetModuleHandleW(L"World.dll");if(world)clock_fn=reinterpret_cast<Clock>(GetProcAddress(world,"?GetModelTime@wTime@@SANXZ"));}
 if(!clock_fn){unavailable(1);return;}
 const double now=clock_fn();
 if(!sample_valid||!std::isfinite(now)||!std::isfinite(static_pressure_pa)||static_pressure_pa<1000||static_pressure_pa>120000){unavailable(6);return;}
 if(get(p,"F22_ALT_PRESSURE_REQUEST_VALID")>.5){
  const double request=get(p,"F22_ALT_PRESSURE_MMHG"),time=get(p,"F22_ALT_PRESSURE_REQUEST_TIME");
  if(!std::isfinite(request)||request<650||request>820||!std::isfinite(time)||now<time-.01||now-time>.2){unavailable(5);return;}
  selected=request;
 }
 value=pressure_height(static_pressure_pa)-pressure_height(selected*101325/760);
 if(!std::isfinite(value)||value< -3000||value>32000){unavailable(6);return;}
 stamp=now;valid=true;
 put(p,"F22_ALT_ACTUAL_PRESSURE_MMHG",selected);put(p,"F22_ALT_NATIVE_BARO_M",value);
 put(p,"F22_ALTIMETER_RESULT_TIME",now);put(p,"F22_ALTIMETER_NATIVE_REASON",0);
 put(p,"F22_ALTIMETER_NATIVE_READY",1);put(p,"F22_ALTIMETER_NATIVE_VALID",1);
}
bool altitude(double& metres){if(!valid||!clock_fn)return false;double now=clock_fn();
 if(!std::isfinite(now)||now<stamp||now-stamp>.2)return false;metres=value;return true;}
}

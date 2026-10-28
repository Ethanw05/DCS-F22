// I-FLT-001 / P-INT-008 scoped caller: actual cached TOF publication owner.
#include "weapon_parameter_port.h"
#include <array>
#include <cmath>
#include <iostream>
#include <limits>
#include "../../EFM/source/NativeSidewinder.cpp"

namespace NativeAesaRadar {
unsigned track_for_host(unsigned) noexcept {return 0;}
void reset() noexcept {}
void update(EDPARAM&) noexcept {}
}
namespace {
using namespace WeaponParameterPort;
double now=20;
unsigned calls=0;
bool invalidate_during_call=false;
double __cdecl clock() {return now;}
double __fastcall estimate(void*,double,double,double,double,double,double,double,double,double,
                           double* activation,int,bool) {
    ++calls;*activation=1;
    if(invalidate_during_call){cells["EFM_HUD_VALID"].value=0;invalidate_during_call=false;}
    return 2;
}
void input() {
    physical();now=20;calls=0;invalidate_during_call=false;
    NativeSidewinder::time_estimate={};NativeSidewinder::last_tof_attempt=-1e9;
    NativeSidewinder::last_tof_target=NativeSidewinder::last_tof_type=0;
    cells["F22_WEAPON_TYPE4"].value=24;
    cells["F22_FC_TARGET_INPUT_ID"].value=cells["F22_RADAR_WEAPON_TARGET_ID"].value=11;
    cells["HUD_MODE"].value=2;cells["MAIN_POWER"].value=1;
    cells["F22_MISSILE_DATA_VALID"].value=cells["F22_FC_TARGET_INPUT_VALID"].value=1;
    cells["F22_MISSILE_LIFETIME"].value=120;
    cells["F22_FC_TARGET_DN"].value=1000;cells["F22_FC_TARGET_VN"].value=100;
    cells["F22_FC_OWN_ALTITUDE"].value=1000;
}
bool require(bool value,const char* message) {
    if(!value)std::cerr<<message<<'\n';
    return value;
}
}
int main() {
    EDPARAM parameters;bind(parameters);
    NativeSidewinder::api.clock=&clock;NativeSidewinder::api.aam_tof=&estimate;
    NativeSidewinder::api.tof_constructed=true;
    unsigned failures=0,cases=0;
    input();NativeSidewinder::publish_time_estimate(parameters);++cases;
    failures+=!require(cells["F22_TOF_NATIVE_VALID"].value==1 && calls==1,"Normal actual TOF port failed");
    now+=.05;NativeSidewinder::publish_time_estimate(parameters);++cases;
    failures+=!require(calls==1,"Healthy TOF cache unexpectedly recomputed");
    cells["EFM_HUD_VALID"].value=0;NativeSidewinder::publish_time_estimate(parameters);++cases;
    failures+=!require(cells["F22_TOF_NATIVE_VALID"].value==0 && !NativeSidewinder::time_estimate.valid,
                       "Atmosphere loss retained eligible TOF cache");
    cells["EFM_HUD_VALID"].value=1;now+=.01;NativeSidewinder::publish_time_estimate(parameters);++cases;
    failures+=!require(cells["F22_TOF_NATIVE_VALID"].value==1 && calls==2,"Recovery reused pre-loss TOF cache");
    struct Bad {const char* name;double value;bool success;};
    const std::array<Bad,7> invalid{{{"EFM_HUD_VALID",1,false},{"EFM_PHYSICAL_VALID",1,false},
        {"EFM_PHYSICAL_GENERATION",0,true},{"EFM_PHYSICAL_STAMP",9,true},
        {"EFM_HUD_TAS",200,false},{"MAIN_POWER",1,false},{"F22_WEAPON_TYPE4",24.5,true}}};
    for(const auto& bad:invalid) {
        input();cells[bad.name]={bad.value,bad.success};NativeSidewinder::publish_time_estimate(parameters);++cases;
        failures+=!require(cells["F22_TOF_NATIVE_VALID"].value==0 && calls==0,"Failed read/source reached TOF estimator");
    }
    input();invalidate_during_call=true;NativeSidewinder::publish_time_estimate(parameters);++cases;
    failures+=!require(cells["F22_TOF_NATIVE_VALID"].value==0 && !NativeSidewinder::time_estimate.valid,
                       "TOF result survived mid-call atmosphere loss");
    input();NativeSidewinder::publish_time_estimate(parameters);
    cells["EFM_PHYSICAL_GENERATION"].value=4;now+=.01;
    NativeSidewinder::publish_time_estimate(parameters);++cases;
    failures+=!require(calls==2,"Physical generation reused an old TOF estimate");
    input();NativeSidewinder::publish_time_estimate(parameters);
    parameters.invalidate();bind(parameters);now+=.01;
    NativeSidewinder::publish_time_estimate(parameters);++cases;
    failures+=!require(calls==2,"Parameter context reused an old TOF estimate");
    for(double bad_clock:{std::numeric_limits<double>::quiet_NaN(),
                         std::numeric_limits<double>::infinity(),-1.0}) {
        input();now=bad_clock;NativeSidewinder::publish_time_estimate(parameters);++cases;
        failures+=!require(cells["F22_TOF_NATIVE_VALID"].value==0 && calls==0,
                           "Invalid World clock reached native TOF estimator");
    }
    input();now=0;NativeSidewinder::publish_time_estimate(parameters);++cases;
    failures+=!require(cells["F22_TOF_NATIVE_VALID"].value==1 && calls==1,
                       "Valid zero World clock was rejected");
    std::cout<<"{\"tof_flight_cases\":"<<cases<<",\"failures\":"<<failures<<",\"DCS_qualified\":false}\n";
    return failures?1:0;
}

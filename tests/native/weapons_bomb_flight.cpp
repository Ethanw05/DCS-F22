// I-FLT-001: actual BombSight owner; vacuum planes are an independent software oracle.
#include "weapon_parameter_port.h"
#include <array>
#include <cmath>
#include <iostream>
#include "../../EFM/source/NativeAGWeapons.cpp"

namespace {
using namespace WeaponParameterPort;
unsigned aim_calls=0;
bool invalidate_during_aim=false,cancel_during_aim=false;
unsigned last_class=0,last_type=0;
double now=20;
void* __fastcall construct(void* object,const void*) {return object;}
void __fastcall destruct(void*) {}
void __fastcall type(void*,const NativeAGWeapons::Type* value) {
    last_class=value->one*10000+value->two*100+value->three;
    last_type=value->four;
}
double __cdecl clock() {return now;}
bool __fastcall aim(void*,const NativeAGWeapons::FloatVec* position,
                    const NativeAGWeapons::FloatVec* velocity,double plane,
                    double* time,NativeAGWeapons::Vec* point) {
    ++aim_calls;
    if(invalidate_during_aim) {cells["EFM_HUD_VALID"].value=0;invalidate_during_aim=false;}
    if(cancel_during_aim) {cells["F22_AG_BOMB_REQUEST_SEQUENCE"].value=8;cancel_during_aim=false;}
    *time=std::sqrt(2*(position->u-plane)/9.81);
    *point={position->n+velocity->n*(*time),plane,position->e+velocity->e*(*time)};
    return true;
}
void input() {
    physical();aim_calls=0;now=20;invalidate_during_aim=cancel_during_aim=false;
    cells["F22_AG_BOMB_REQUEST_VALID"].value=1;
    cells["F22_AG_BOMB_REQUEST_SEQUENCE"].value=7;
    cells["F22_AG_BOMB_REQUEST_TIME"].value=20;
    cells["F22_AG_BOMB_REQUEST_SCHEMA"].value=2;
    cells["F22_AG_BOMB_REQUEST_STATION"].value=2;
    cells["F22_AG_BOMB_REQUEST_TYPE3"].value=9;
    cells["F22_AG_BOMB_REQUEST_TYPE4"].value=777;
    cells["F22_AG_BOMB_REQUEST_U"].value=1000;
    cells["F22_AG_BOMB_REQUEST_VN"].value=100;
    cells["F22_AG_BOMB_REQUEST_TRAJECTORY"].value=1;
}
bool require(bool condition,const char* message) {
    if(!condition)std::cerr<<message<<'\n';
    return condition;
}
}
int main() {
    EDPARAM parameters;bind(parameters);
    NativeAGWeapons::api.ready=true;
    NativeAGWeapons::api.ctor=&construct;NativeAGWeapons::api.dtor=&destruct;
    NativeAGWeapons::api.type=&type;NativeAGWeapons::api.aim=&aim;NativeAGWeapons::api.clock=&clock;
    unsigned failures=0,cases=0;
    input();NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==1 &&
        cells["F22_AG_BOMB_POINT_COUNT"].value==17 && aim_calls==16,"Normal native bomb port failed");
    failures+=!require(last_class==40509 && last_type==777,"Native store type was not preserved");
    input();cells["F22_AG_BOMB_REQUEST_TYPE3"].value=36;NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(last_class==40536 && cells["F22_AG_BOMB_NATIVE_VALID"].value==1,"Guided native store class lost");
    input();cells["F22_AG_BOMB_REQUEST_TYPE3"].value=7;NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==0 && aim_calls==0,"A/A class entered bomb solver");
    input();cells["F22_AG_BOMB_REQUEST_TYPE4"].value=0;NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==0 && aim_calls==0,"Missing native store type entered bomb solver");
    struct Bad {const char* field;double value;bool success;};
    const std::array<Bad,6> invalid{{{"EFM_HUD_VALID",0,true},{"EFM_HUD_VALID",1,false},
        {"EFM_PHYSICAL_GENERATION",0,true},{"EFM_PHYSICAL_CLOCK_KIND",2,true},
        {"EFM_PHYSICAL_STAMP",9,true},{"EFM_HUD_WN",0,false}}};
    for(const auto& bad:invalid) {
        input();cells[bad.field]={bad.value,bad.success};NativeAGWeapons::solve(parameters,7);++cases;
        failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==0 &&
            cells["F22_AG_BOMB_POINT_COUNT"].value==0 && aim_calls==0,"Invalid full group reached bomb solver");
    }
    input();tear_motion=true;NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==0 && aim_calls==0,"Torn motion admitted by bomb solver");
    input();invalidate_during_aim=true;NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==0 &&
        cells["F22_AG_BOMB_TRAJECTORY_READY"].value==0,"Delayed bomb result survived source loss");
    input();cancel_during_aim=true;NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==0,"Cancelled bomb request survived solve");
    input();NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==1 &&
        std::abs(cells["F22_AG_BOMB_FALL_TIME"].value-std::sqrt(2000/9.81))<1e-6,"Fresh bomb recovery/oracle failed");
    for(const char* name:NativeAGWeapons::Request::names) {
        input();cells[name].success=false;NativeAGWeapons::solve(parameters,7);++cases;
        failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==0 && aim_calls==0,
                           "Failed request conversion reached native bomb solver");
    }
    input();cells["F22_AG_BOMB_REQUEST_SCHEMA"].value=0;NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(aim_calls==0,"Unversioned request fell through to legacy live values");
    input();NativeAGWeapons::api.ready=false;NativeAGWeapons::solve(parameters,7);++cases;
    failures+=!require(cells["F22_AG_BOMB_NATIVE_VALID"].value==0 && aim_calls==0,
                       "Absent actual CockpitBase module was reported as a working bomb backend");
    std::cout<<"{\"bomb_flight_cases\":"<<cases<<",\"failures\":"<<failures<<",\"DCS_qualified\":false}\n";
    return failures?1:0;
}

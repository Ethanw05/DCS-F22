// D-R-WPN-002: actual native ground solver, explicit owned host ports.
// The vacuum trajectory below is a software oracle, not aircraft calibration.
#include <Windows.h>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstring>
#include <iostream>
#include <limits>
#include <map>
#include <string>
#include "../../EFM/source/NativeGunSight.cpp"

namespace NativeAesaRadar {
bool gun_motion(unsigned, std::uint64_t, GunMotion&) noexcept { return false; }
}

namespace {
struct Parameter { double value{}; bool success=true; };
std::map<std::string, Parameter> values;
double clock_value{};
unsigned context_calls{}, trajectory_calls{};
bool tear_on_velocity=false, invalidate_during_trajectory=false;
bool context_on_velocity=false, context_during_trajectory=false;
EDPARAM* current_parameters=nullptr;
void replace_parameter_context();
alignas(16) std::array<std::byte, 32> weapon_object{}, context_object{};
alignas(16) std::array<std::byte, 184> shell_object{};
std::array<void*, 41> human_vtable{};
std::array<void*, 52> aircraft_vtable{};
void* human_object{};
void* aircraft_object{};

void* parameter_handle(const char* name) { return &values[name]; }
bool parameter_read(const void* handle, double& value, bool) {
    const auto* parameter=static_cast<const Parameter*>(handle);
    value=parameter->value; // A failed conversion may still modify this output.
    if (tear_on_velocity && handle==&values["EFM_HUD_VN"]) {
        values["EFM_PHYSICAL_GENERATION"].value+=1;
        tear_on_velocity=false;
    }
    if (context_on_velocity && handle==&values["EFM_HUD_VN"]) {
        context_on_velocity=false;replace_parameter_context();
    }
    return parameter->success;
}
void parameter_write(void* handle, double value) {
    static_cast<Parameter*>(handle)->value=value;
}
void replace_parameter_context() {
    current_parameters->invalidate();
    current_parameters->ed_param_api.pfn_ed_cockpit_get_parameter_handle=&parameter_handle;
    current_parameters->ed_param_api.pfn_ed_cockpit_parameter_value_to_number=&parameter_read;
    current_parameters->ed_param_api.pfn_ed_cockpit_update_parameter_with_number=&parameter_write;
}
double __cdecl model_clock() { return clock_value; }
void* __cdecl context() { ++context_calls; return context_object.data(); }
void* __fastcall device(void*, unsigned) { return weapon_object.data(); }
const void* __fastcall shell(void*) { return shell_object.data(); }
void* __fastcall construct(void* instance, const void*) { return instance; }
void __fastcall destruct(void*) {}
void* __fastcall aircraft(void*) { return &aircraft_object; }
void __fastcall pose(void*, float* matrix, unsigned char, unsigned, unsigned) {
    for (unsigned i=0;i<16;++i) matrix[i]=0;
    matrix[0]=matrix[5]=matrix[10]=matrix[15]=1;
    matrix[13]=1000;
}
int __fastcall trajectory(void*, double altitude, double time,
                         const GunIntercept::V* launch, NativeGunSight::Wind*,
                         GunIntercept::V* result, double) {
    ++trajectory_calls;
    if (invalidate_during_trajectory) {
        values["EFM_HUD_VALID"].value=0;
        invalidate_during_trajectory=false;
    }
    if (context_during_trajectory) {
        context_during_trajectory=false;replace_parameter_context();
    }
    *result=(*launch)*time;
    result->y=altitude+launch->y*time-4.905*time*time;
    return 1;
}
template<class T> void store(void* base, std::size_t offset, const T& value) {
    std::memcpy(static_cast<std::byte*>(base)+offset, &value, sizeof(value));
}
void configure(EDPARAM& p) {
    current_parameters=&p;
    p.ed_param_api={};
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=&parameter_handle;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=&parameter_read;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=&parameter_write;
    auto& api=NativeGunSight::api;
    api.ready=true;
    api.clock=&model_clock;
    api.context=&context;
    api.device=&device;
    api.shell=&shell;
    api.ctor=&construct;
    api.dtor=&destruct;
    api.time=&trajectory;
    api.vtable=aircraft_vtable.data();
    human_vtable[40]=reinterpret_cast<void*>(&aircraft);
    aircraft_vtable[51]=reinterpret_cast<void*>(&pose);
    human_object=human_vtable.data();
    aircraft_object=aircraft_vtable.data();
    store(weapon_object.data(), 0, api.vtable);
    void* current_context=context_object.data();
    store(weapon_object.data(), 24, current_context);
    void* human=&human_object;
    store(context_object.data(), 16, human);
    const double muzzle_speed=1000;
    store(shell_object.data(), 176, muzzle_speed);
    NativeGunSight::failed=false;
}
void input(double now, double stamp) {
    for (auto& [name,parameter]:values) parameter.success=true;
    clock_value=now;
    context_calls=trajectory_calls=0;
    tear_on_velocity=invalidate_during_trajectory=false;
    context_on_velocity=context_during_trajectory=false;
    values["EFM_POWER_OWNER"].value=1;
    values["EFM_PHYSICAL_VALID"].value=1;
    values["EFM_PHYSICAL_GENERATION"].value=3;
    values["EFM_PHYSICAL_STAMP"].value=10;
    values["EFM_PHYSICAL_CLOCK_KIND"].value=1;
    values["F22_AP_CLOCK"].value=10;
    values["EFM_HUD_VALID"].value=1;
    values["EFM_HUD_KINEMATICS_VALID"].value=1;
    values["F22_AG_GUN_REQUEST_VALID"].value=1;
    values["F22_AG_GUN_REQUEST_TIME"].value=stamp;
    values["F22_AG_OWN_U"].value=1000;
}
bool expect(bool condition, const char* reason) {
    if (!condition) std::cerr << reason << '\n';
    return condition;
}
}

int main() {
    EDPARAM parameters;
    configure(parameters);
    unsigned failures=0, cases=0;
    const double nan=std::numeric_limits<double>::quiet_NaN();
    const double inf=std::numeric_limits<double>::infinity();
    struct Case { double now,stamp; bool valid; };
    const std::array<Case,13> clocks{{
        {0,0,true}, {10,10,true}, {10,9.9,true}, {10,10.005,true},
        {nan,10,false}, {inf,10,false}, {-inf,10,false}, {-1,-1,false},
        {10,nan,false}, {10,inf,false}, {10,-1,false},
        {10,9.79,false}, {10,10.02,false}
    }};
    for (const auto& sample:clocks) {
        ++cases;
        input(sample.now,sample.stamp);
        // Deliberately retain old publication payload across fault/recovery.
        NativeGunSight::calculate_ground(parameters);
        const auto valid=values["F22_AG_GUN_NATIVE_VALID"].value;
        const auto points=values["F22_AG_GUN_POINT_COUNT"].value;
        std::cout << "{\"case\":" << cases << ",\"clock_finite\":"
                  << (std::isfinite(sample.now)?"true":"false")
                  << ",\"expected_valid\":" << (sample.valid?1:0)
                  << ",\"native_valid\":" << valid << ",\"points\":" << points
                  << ",\"host_context_calls\":" << context_calls
                  << ",\"trajectory_calls\":" << trajectory_calls << "}\n";
        if (sample.valid) {
            failures+=!expect(valid==1 && points==81 && trajectory_calls==80,
                               "Fresh finite clock failed actual ground solver");
            failures+=!expect(std::isfinite(values["F22_AG_GUN_RESULT_TIME"].value),
                               "VALID result timestamp must be finite");
            failures+=!expect(std::abs(values["F22_AG_GUN_80_N"].value-4000)<1e-6,
                               "Independent vacuum forward endpoint mismatch");
        } else {
            failures+=!expect(valid==0 && points==0 && context_calls==0 && trajectory_calls==0,
                               "Invalid clock reached host/solve or retained current point count");
        }
    }
    input(20,20);
    NativeGunSight::calculate_ground(parameters);
    failures+=!expect(values["F22_AG_GUN_NATIVE_VALID"].value==1 &&
                      values["F22_AG_GUN_RESULT_TIME"].value==20,
                      "Clock recovery did not produce a fresh native result");
    unsigned flight_cases=0;
    struct FieldCase { const char* name; double value; bool conversion; };
    const std::array<FieldCase,9> fields{{
        {"EFM_HUD_VALID",0,true}, {"EFM_HUD_VALID",1,false},
        {"EFM_PHYSICAL_VALID",1,false}, {"EFM_PHYSICAL_GENERATION",0,true},
        {"EFM_PHYSICAL_GENERATION",3.5,true}, {"EFM_PHYSICAL_CLOCK_KIND",2,true},
        {"EFM_PHYSICAL_STAMP",9,true}, {"EFM_PHYSICAL_STAMP",10.1,true},
        {"EFM_HUD_WN",0,false}
    }};
    for (const auto& field:fields) {
        ++flight_cases;
        input(20,20);
        values[field.name]={field.value,field.conversion};
        NativeGunSight::calculate_ground(parameters);
        failures+=!expect(values["F22_AG_GUN_NATIVE_VALID"].value==0 && context_calls==0,
                           "Unavailable full flight group reached ground gun host solver");
    }
    input(20,20);tear_on_velocity=true;
    NativeGunSight::calculate_ground(parameters);
    failures+=!expect(values["F22_AG_GUN_NATIVE_VALID"].value==0 && context_calls==0,
                       "Torn flight tuple reached ground gun host solver");
    input(20,20);invalidate_during_trajectory=true;
    NativeGunSight::calculate_ground(parameters);
    failures+=!expect(values["F22_AG_GUN_NATIVE_VALID"].value==0 &&
                      values["F22_AG_GUN_POINT_COUNT"].value==0,
                       "Source loss during native solve published a current trajectory");
    input(20,20);
    values["EFM_HUD_VALID"].value=0;
    values["F22_FUNNEL_REQUEST_VALID"].value=1;
    values["F22_FUNNEL_REQUEST_TIME"].value=20;
    values["F22_FUNNEL_OWN_U"].value=1000;
    values["F22_GUN_DEVICE_ID"].value=15;
    NativeGunSight::funnel_history.push_back({19,{}, {}, {}, {}});
    NativeGunSight::calculate_funnel(parameters);
    failures+=!expect(NativeGunSight::funnel_history.empty() && context_calls==0,
                       "Invalid atmosphere retained or extended funnel history");
    input(20,20);values["EFM_HUD_VALID"].value=0;
    values["F22_GUN_REQUEST_VALID"].value=1;
    NativeGunSight::calculate(parameters);
    failures+=!expect(context_calls==0 && values["F22_GUN_SOLUTION_VALID"].value==0,
                       "Invalid atmosphere reached source2 gun native context");
    input(20,20);context_on_velocity=true;
    NativeGunSight::calculate_ground(parameters);
    failures+=!expect(values["F22_AG_GUN_NATIVE_VALID"].value==0 && context_calls==0,
                       "Changed parameter context authenticated mixed flight inputs");
    input(20,20);context_during_trajectory=true;
    NativeGunSight::calculate_ground(parameters);
    failures+=!expect(values["F22_AG_GUN_NATIVE_VALID"].value==0,
                       "Changed parameter context authenticated a delayed result");
    input(22,22);
    values["F22_FUNNEL_REQUEST_VALID"].value=1;
    values["F22_FUNNEL_REQUEST_TIME"].value=22;
    NativeGunSight::calculate_funnel(parameters);
    replace_parameter_context();
    input(22.01,22.01);values["F22_FUNNEL_REQUEST_TIME"].value=22.01;
    NativeGunSight::calculate_funnel(parameters);
    failures+=!expect(NativeGunSight::funnel_history.size()==1,
                       "New parameter context reused old funnel history");
    input(21,21);
    NativeGunSight::calculate_ground(parameters);
    failures+=!expect(values["F22_AG_GUN_NATIVE_VALID"].value==1 &&
                      values["F22_AG_GUN_RESULT_TIME"].value==21,
                       "Fresh full group did not restore native ground result");
    std::cout << "{\"clock_cases\":" << cases << ",\"recovery_cases\":1,\"failures\":"
              << failures << ",\"flight_cases\":" << flight_cases+8
              << ",\"actual_DCS_effect\":false}\n";
    return failures?1:0;
}

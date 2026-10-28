// GPL-3.0-or-later. Actual coordinator with explicit status/context ports.
#include <map>
#include <string>
#include <iostream>
#include "../../EFM/source/NativeGroundRadar.cpp"
namespace NativeGroundVideo { void reset() {} void update(EDPARAM&) {} }
namespace NativeGroundSensor { void reset() {} void update(EDPARAM&) {} }
namespace {
struct Value { double number{}; bool status{true}; };
std::map<std::string,Value> bus;
EDPARAM* context{};
unsigned reads{},boundary{},checks{},failures{};
bool replace{},invalidate{};
void seed(bool newer=false) {
    bus["F22_AESA_DRIVER_READY"]={1};bus["F22_AG_NATIVE_SCHEMA"]={1};
    bus["F22_AG_NATIVE_SEQUENCE"]={newer?4.0:2.0};
    bus["F22_AG_NATIVE_SOURCE_EPOCH"]={newer?2.0:1.0};
    bus["F22_AG_GMT_READY"]={newer?0.0:1.0};
    bus["F22_AG_GMT_REASON"]={newer?3.0:0.0};
}
void* handle(const char* name) { return &bus[name]; }
bool number(const void* handle,double& output,bool) {
    const auto value=*static_cast<const Value*>(handle);
    output=value.number; // A failed host conversion may still overwrite its buffer.
    if (++reads==boundary) {
        if (replace) seed(true);
        if (invalidate) context->invalidate();
    }
    return value.status;
}
void put(void* handle,double value) { *static_cast<Value*>(handle)={value}; }
void bind(EDPARAM& p) {
    p.invalidate();context=&p;
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=handle;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=put;
}
void require(bool condition,const char* message) {
    ++checks;if (!condition) {++failures;std::cerr<<message<<'\n';}
}
void capture() {
    double driver{},sensor{},reason{};
    const bool valid=NativeGroundRadar::sensor_state(*context,driver,sensor,reason);
    require(!valid || (driver==1 && ((sensor==1 && reason==0) || (sensor==0 && reason==3))),
        "coordinator combined source groups");
}
}
int main() {
    EDPARAM p;bind(p);seed();capture();const auto count=reads;
    for (unsigned i=1;i<=count;++i) {
        bind(p);seed();reads=0;boundary=i;replace=true;capture();
        replace=false;bind(p);seed();reads=0;invalidate=true;
        double driver{},sensor{},reason{};
        require(!NativeGroundRadar::sensor_state(p,driver,sensor,reason),"context replacement admitted");
        invalidate=false;
    }
    boundary=0;
    for (const auto* name : {"F22_AESA_DRIVER_READY","F22_AG_NATIVE_SEQUENCE","F22_AG_NATIVE_SCHEMA",
        "F22_AG_NATIVE_SOURCE_EPOCH","F22_AG_GMT_READY","F22_AG_GMT_REASON"}) {
        bind(p);seed();bus[name].status=false;
        NativeGroundRadar::update(p);
        require(bus["F22_AG_RADAR_NATIVE_READY"].number==0,"failed conversion preserved readiness");
    }
    for (const auto value : {0.0,1.0,3.0,16777216.0}) {
        bind(p);seed();bus["F22_AG_NATIVE_SEQUENCE"]={value};NativeGroundRadar::update(p);
        require(bus["F22_AG_RADAR_NATIVE_READY"].number==0,"invalid commit admitted");
    }
    bind(p);seed();NativeGroundRadar::update(p);
    require(bus["F22_AG_RADAR_NATIVE_READY"].number==1,"valid source failed recovery");
    require(bus["F22_AG_RADAR_NATIVE_REASON"].number==0,"legitimate zero reason rejected");
    std::cout<<"ground coordination checks="<<checks<<" failures="<<failures<<'\n';
    return failures?1:0;
}

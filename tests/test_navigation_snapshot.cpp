// Public parameter API fixture: coherent reads, bounded retry and no invalid zero.
#include "../EFM/source/NavigationSnapshot.h"
#include <array>
#include <cstdlib>
#include <iostream>
#include <map>
#include <string>
namespace {
std::map<std::string,double> values;
bool failed_read=false,tear_once=false,tear_always=false;
void* handle(const char* name) { return &values[name]; }
bool read(const void* pointer,double& result,bool) {
    if (failed_read) return false;
    result=*static_cast<const double*>(pointer);
    if ((tear_once || tear_always) &&
        (pointer==handle("F22_NAV_SNAPSHOT_0_TRACK") || pointer==handle("F22_NAV_SNAPSHOT_1_TRACK"))) {
        values["F22_NAV_SNAPSHOT_SEQUENCE"]+=1;
        tear_once=false;
    }
    return true;
}
void check(bool condition) { if (!condition) std::abort(); }
void slot(unsigned index,double track,bool valid,bool terminal) {
    const std::string prefix="F22_NAV_SNAPSHOT_"+std::to_string(index)+"_";
    values[prefix+"VALID"]=valid?1:0;
    values[prefix+"TRACK"]=track;
    values[prefix+"TIME"]=10;
    values[prefix+"TERMINAL"]=terminal?1:0;
}
}
int main() {
    EDPARAM api;
    api.ed_param_api.pfn_ed_cockpit_get_parameter_handle=handle;
    api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=read;
    RaptorNavigation::Snapshot snapshot;
    snapshot.initialize(api);
    check(!snapshot.read(api).present); // Compatibility before a schema owner appears.
    values["F22_NAV_SNAPSHOT_SCHEMA"]=1;
    check(snapshot.read(api).present && !snapshot.read(api).valid);
    slot(1,0,true,false);slot(0,.5,true,true);
    values["F22_NAV_SNAPSHOT_SEQUENCE"]=1;
    auto frame=snapshot.read(api);
    check(frame.valid && frame.track==0 && !frame.terminal && frame.time==10);
    tear_once=true;
    frame=snapshot.read(api);
    check(frame.valid && frame.track==.5 && frame.terminal); // One bounded retry.
    tear_always=true;check(!snapshot.read(api).valid);tear_always=false;
    values["F22_NAV_SNAPSHOT_SEQUENCE"]=2;slot(0,.5,false,false);
    check(!snapshot.read(api).valid);
    failed_read=true;check(!snapshot.read(api).valid);failed_read=false;
    values["F22_NAV_SNAPSHOT_SCHEMA"]=0;
    check(snapshot.read(api).present && !snapshot.read(api).valid); // Never revive legacy after ownership.
    values["F22_NAV_SNAPSHOT_SCHEMA"]=1;values["F22_NAV_SNAPSHOT_SEQUENCE"]=NAN;
    check(!snapshot.read(api).valid);
    std::cout << "NAV snapshot: zero, complete, torn, bounded retry, invalid API, schema latch and nonfinite PASS\n";
}

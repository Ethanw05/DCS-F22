// Actual typed target reader and callback binding; no weapon/native effect call.
#include "../../EFM/source/GroundTargetPacket.h"
#include <iostream>
#include <map>
#include <string>
#include <vector>

namespace {
struct Field {double value{};bool available=true;};
std::map<std::string,Field> bus;
unsigned checks{},failures{},reads{},lookups{};
int switch_at=-1,context_at=-1;
EDPARAM* active_port{};
void require(bool value,const char* why) {
    ++checks;if (!value) {++failures;std::cout<<"FAIL "<<why<<'\n';}
}
void* resolve(const char* name) {++lookups;return &bus[name];}
void packet(bool newer=false) {
    const std::pair<const char*,double> values[]={
        {"F22_AG_DELIVERY_TARGET_PACKET_SEQUENCE",newer?4.0:2.0},
        {"F22_AG_DELIVERY_TARGET_PACKET_SCHEMA",1},{"F22_AG_DELIVERY_TARGET_PACKET_EPOCH",3},
        {"F22_AG_DELIVERY_TARGET_PACKET_TIME",100},{"F22_AG_DELIVERY_TARGET_VALID",1},
        {"F22_AG_DELIVERY_TARGET_SEQUENCE",newer?5.0:4.0},
        {"F22_AG_DELIVERY_TARGET_SOURCE",2},{"F22_AG_DELIVERY_TARGET_ORIGIN_SOURCE",2},
        {"F22_AG_DELIVERY_TARGET_N",newer?2400.0:1200.0},{"F22_AG_DELIVERY_TARGET_U",100},
        {"F22_AG_DELIVERY_TARGET_E",300},{"F22_AG_DELIVERY_TARGET_OBSERVATION_KNOWN",1},
        {"F22_AG_DELIVERY_TARGET_OBSERVATION_TIME",99.9},{"F22_AG_DELIVERY_TARGET_OBSERVATION_SEQUENCE",6},
        {"F22_AG_DELIVERY_TARGET_SOURCE_EPOCH",7},{"F22_AG_DELIVERY_TARGET_SOURCE_REQUEST",4},
        {"F22_AG_DELIVERY_TARGET_SOURCE_TYPE",1},{"F22_AG_DELIVERY_TARGET_SOURCE_LIVE",1},
        {"F22_AG_NATIVE_SEQUENCE",4},{"F22_AG_NATIVE_SCHEMA",1},{"F22_AG_NATIVE_SOURCE_EPOCH",7},
        {"F22_AG_NATIVE_CONTROL_SEQUENCE",8},{"F22_AG_NATIVE_CONTROL_SCHEMA",1},
        {"F22_AG_NATIVE_CONTROL_EPOCH",7},{"F22_AG_NATIVE_CONTROL_TIME",100},
        {"F22_AG_DESIGNATION_VALID",1},{"F22_AG_DESIGNATION_SCHEMA",1},
        {"F22_AG_DESIGNATION_EPOCH",7},{"F22_AG_DESIGNATION_SEQUENCE",6},
        {"F22_AG_DESIGNATION_NORTH",1205},{"F22_AG_DESIGNATION_ALTITUDE",100},
        {"F22_AG_DESIGNATION_EAST",300},{"F22_AG_DESIGNATION_TIME",100},
        {"F22_AG_DESIGNATION_REQUEST",4},{"F22_AG_DESIGNATION_TYPE",1},{"F22_AG_DESIGNATION_LIVE",1}};
    for (const auto& value : values) bus[value.first]={value.second,true};
}
bool number(const void* pointer,double& value,bool) {
    const auto boundary=static_cast<int>(reads++);
    if (boundary==switch_at) packet(true);
    if (boundary==context_at) active_port->invalidate();
    const auto& field=*static_cast<const Field*>(pointer);value=field.value;return field.available;
}
void activate(EDPARAM& p) {
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=resolve;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
}
bool complete(const GroundTargetPacket::Target& value) {
    if (!value.valid) return true;
    const bool old=value.identity.sequence==4 && value.identity.point==std::array<double,3>{1200,100,300};
    const bool newer=value.identity.sequence==5 && value.identity.point==std::array<double,3>{2400,100,300};
    return old || newer;
}
void schedules(GroundTargetPacket::Reader& reader,EDPARAM& p) {
    GroundTargetPacket::Target target;
    packet();reads=0;require(reader.capture(p,100,target),"normal live target");
    const auto count=reads;
    for (unsigned boundary=0;boundary<=count;++boundary) {
        packet();reads=0;switch_at=static_cast<int>(boundary);
        reader.capture(p,100,target);
        require(complete(target),"complete old/new/unavailable at every checked read boundary");
    }
    switch_at=-1;
    for (unsigned boundary=0;boundary<count;++boundary) {
        activate(p);packet();reads=0;context_at=static_cast<int>(boundary);
        require(!reader.capture(p,100,target),"parameter context changes withdraw the complete target");
    }
    context_at=-1;activate(p);
}
void invalid_data(GroundTargetPacket::Reader& reader,EDPARAM& p) {
    GroundTargetPacket::Target target;
    packet();std::vector<std::string> names;
    for (const auto& field : bus) names.push_back(field.first);
    for (const auto& name : names) {
        for (const double payload : {0.0,7.0}) {
            packet();bus[name]={payload,false};
            require(!reader.capture(p,100,target),"failed conversion is never a valid zero/seven");
        }
        packet();bus[name].value=NAN;
        require(!reader.capture(p,100,target),"nonfinite target/source evidence is rejected");
    }
    for (const auto name : {"F22_AG_DELIVERY_TARGET_PACKET_SEQUENCE","F22_AG_NATIVE_SEQUENCE",
        "F22_AG_NATIVE_CONTROL_SEQUENCE"}) {
        packet();bus[name].value=3;
        require(!reader.capture(p,100,target),"an in-progress participating group cannot qualify a target");
    }
    packet();bus["F22_AG_DELIVERY_TARGET_OBSERVATION_TIME"].value=94.75;
    require(reader.capture(p,100,target),"original live sample at5.25second boundary");
    require(!reader.capture(p,100.000001,target),"old target cannot be renewed by fresher native evidence");
    packet();bus["F22_AG_DELIVERY_TARGET_PACKET_TIME"].value=99.49;
    require(!reader.capture(p,100,target),"delivery producer lease expires independently");
    packet();bus["F22_AG_NATIVE_CONTROL_TIME"].value=99.49;
    require(!reader.capture(p,100,target),"source control lease expires independently");
    packet();require(reader.capture(p,100,target),"fresh current restoration");
}
void fixed_policy(GroundTargetPacket::Reader& reader,EDPARAM& p) {
    GroundTargetPacket::Target target;
    packet();bus["F22_AG_DELIVERY_TARGET_SOURCE_TYPE"].value=3;
    bus["F22_AG_DELIVERY_TARGET_SOURCE_LIVE"].value=0;
    bus["F22_AG_DELIVERY_TARGET_OBSERVATION_TIME"].value=10;
    bus["F22_AG_NATIVE_CONTROL_TIME"].value=0;bus["F22_AG_DESIGNATION_VALID"].value=0;
    require(reader.capture(p,100,target) && target.identity.observation_time==10,
        "fixedkind3 retains original sample with inactive radar control");
    bus["F22_AG_NATIVE_SOURCE_EPOCH"].value=8;
    require(!reader.capture(p,100,target),"fixed coordinate retires on known source epoch change");
    bus["F22_AG_NATIVE_SOURCE_EPOCH"].value=0;
    require(!reader.capture(p,100,target),"fixed coordinate cannot authenticate unknown source context");
    for (const double origin : {1.0,3.0}) {
        packet();bus["F22_AG_DELIVERY_TARGET_ORIGIN_SOURCE"].value=origin;
        bus["F22_AG_DELIVERY_TARGET_SOURCE"].value=origin;
        bus["F22_AG_DELIVERY_TARGET_OBSERVATION_KNOWN"].value=0;
        bus["F22_AG_DELIVERY_TARGET_OBSERVATION_TIME"].value=-100;
        for (const auto key : {"SOURCE_EPOCH","SOURCE_REQUEST","SOURCE_TYPE","SOURCE_LIVE","OBSERVATION_SEQUENCE"})
            bus[std::string("F22_AG_DELIVERY_TARGET_")+key].value=0;
        bus["F22_AG_NATIVE_SCHEMA"].available=false;bus["F22_AG_NATIVE_CONTROL_TIME"].available=false;
        require(reader.capture(p,100,target),"explicit HUD/NAV fixed coordinates need no radar evidence");
        bus["F22_AG_DELIVERY_TARGET_OBSERVATION_KNOWN"].value=1;
        require(!reader.capture(p,100,target),"unmeasured fixed source cannot claim observed sensor truth");
    }
}
void callback_frame(GroundTargetPacket::Reader& reader,EDPARAM& p) {
    packet();GroundTargetPacket::Target cached,current;
    require(reader.capture(p,100,cached),"prepare authentic target cache");
    const auto binding=reader.binding();const auto lookups_before=lookups;
    require(GroundTargetPacket::read(binding,100.1,current)
        && GroundTargetPacket::current(binding,cached,current,100.1),"actual callback-style typed revalidation");
    require(lookups==lookups_before,"callback performs no handle lookup or mutable map traversal");
    bus["F22_AG_DELIVERY_TARGET_OBSERVATION_TIME"].value=99.95;
    require(GroundTargetPacket::read(binding,100.1,current)
        && !GroundTargetPacket::current(binding,cached,current,100.1),"changed observation metadata cannot reuse cached frame");
    packet();bus["F22_AG_DELIVERY_TARGET_PACKET_TIME"].value=99.51;
    require(reader.capture(p,100,cached),"prepare near-expiry producer packet");
    bus["F22_AG_DELIVERY_TARGET_PACKET_TIME"].value=100.1;
    require(reader.capture(p,100.1,current) && !GroundTargetPacket::current(binding,cached,current,100.1),
        "copy timestamp cannot renew cached target producer lease");
    reader.invalidate();packet();
    require(reader.capture(p,100,current) && lookups>lookups_before,"owner reset reacquires all fixed callback handles");
}
void release_policy() {
    std::array<double,5> flags{1,1,1,0,1};
    const auto accepted=[](const std::array<double,5>& v){return GroundTargetPacket::release_flags(v[0],v[1],v[2],v[3],v[4]);};
    require(accepted(flags),"exact typed release permission");
    for (std::size_t i=0;i<flags.size();++i) for (const double value : {-1.0,.5,2.0}) {
        auto invalid=flags;invalid[i]=value;
        require(!accepted(invalid),"fractional/negative/two flags cannot widen preparation or callback permission");
    }
}
}
int main() {
    EDPARAM p;active_port=&p;activate(p);packet();
    GroundTargetPacket::Reader reader;
    schedules(reader,p);invalid_data(reader,p);fixed_policy(reader,p);callback_frame(reader,p);
    release_policy();
    std::cout<<"ground target checks="<<checks<<" failures="<<failures<<'\n';
    return failures?1:0;
}

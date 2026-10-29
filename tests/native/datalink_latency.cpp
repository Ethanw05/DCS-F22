// Actual owned transport scheduling and membership storage, with explicit host ports.
#include "weapon_parameter_port.h"
#include "../../EFM/source/NativeDatalink.cpp"
#include <iostream>

namespace {
unsigned sends{};
bool bounded_payload=true;
std::array<float,3> own_velocity{200,0,0};
NativeDatalink::Vec* own_position(void*,NativeDatalink::Vec* point) {
    *point={1000,3000,500};return point;
}
const float* velocity(const void*) { return own_velocity.data(); }
void send(void*,const void* message) {
    NativeDatalink::StringView view{};
    std::memcpy(&view,static_cast<const char*>(message)+120,sizeof(view));
    bounded_payload=bounded_payload && view.size<=16384 && view.size>=9;
    ++sends;
}
bool scheduling(EDPARAM& port) {
    using namespace NativeDatalink;
    api.point=own_position;api.velocity=velocity;api.send=send;own_id=100;
    last_send=last_transmitted=-1;sent=sends=0;
    for(unsigned tick=0;tick<100;++tick)transmit(port,static_cast<double>(tick)/100.);
    if(sends!=5 || sent!=5 || !bounded_payload)return false;
    transmit(port,20);transmit(port,20); // Resume produces one packet, no catch-up burst.
    if(sends!=6)return false;
    transmit(port,-1);
    publish_latency(port,20.1);
    return sends==6 && std::abs(WeaponParameterPort::cells["F22_IFDL_LAST_TRANSMIT_AGE"].value-.1)<1e-8;
}
bool membership(EDPARAM& port) {
    using namespace NativeDatalink;
    reports.clear();participants.clear();
    Report ppli;ppli.link=1;ppli.reporter=ppli.source=200;ppli.time=10;
    ppli.ppli=ppli.flight=true;ppli.affiliation=1;ppli.position={10000,3000,0};
    accept(ppli,10);
    Report surveillance=ppli;surveillance.time=12;surveillance.ppli=surveillance.flight=false;
    surveillance.affiliation=-1;surveillance.position.n=10400;
    accept(surveillance,12);
    if(reports.size()!=2)return false;
    const auto& member=reports.at({1,200,200,true});
    const auto& target=reports.at({1,200,200,false});
    if(!member.flight || member.time!=10 || member.received!=10 || target.ppli || target.time!=12)return false;
    publish_latency(port,14);
    return WeaponParameterPort::cells["F22_DATALINK_NEWEST_RECEIVE_AGE"].value==2
        && WeaponParameterPort::cells["F22_DATALINK_OLDEST_RECEIVE_AGE"].value==4;
}
bool capacity() {
    using namespace NativeDatalink;
    reports.clear();participants.clear();
    for(unsigned index=0;index<65;++index) {
        Report row;row.source=1000+index;row.reporter=200;row.time=10;accept(row,10);
    }
    return reports.size()==64;
}
}
int main() {
    EDPARAM port;WeaponParameterPort::bind(port);
    if(!scheduling(port) || !membership(port) || !capacity())return 1;
    std::cout<<"Datalink: bounded 5 Hz scheduling, independent PPLI clocks, receipt ages and capacity pass\n";
}

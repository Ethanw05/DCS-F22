// Independent admitted-IR and parameter ports. Does not load DCS libraries.
#include "weapon_parameter_port.h"
#include "../../EFM/source/NativeIRST.cpp"
#include <cstdlib>
#include <iostream>
namespace {
using namespace NativeIRST;
using namespace WeaponParameterPort;
double now=100;
unsigned searches{},destroyed{},admitted=1;
bool power_state{};
Pose pose{};
std::array<void*,65> aircraft_table{};
std::array<void*,31> original_table{};
void** aircraft_pointer=aircraft_table.data();
std::array<std::byte,512> own_object{};
std::array<std::array<std::byte,512>,20> objects{};
std::array<std::byte,20*24> links{};
void require(bool ok,const char* message) {
    if (!ok) { std::cerr<<message<<'\n';std::exit(1); }
}
double __cdecl clock_port() { return now; }
void* __cdecl aircraft_port() { return &aircraft_pointer; }
void* __fastcall own_port(void*) { return own_object.data(); }
void __fastcall launcher_port(void*,float* out,unsigned char station,unsigned char sub) {
    require(station==5 && sub==0,"wrong pod mount");
    std::fill_n(out,16,0.f);out[0]=out[5]=out[10]=out[15]=1;out[12]=-2.81f;out[13]=.349f;out[14]=4.95f;
}
void __fastcall carrier_port(void* self,void* moving) {
    require(self==sensor.data() && moving==own_object.data(),"carrier ABI/ownership");
}
void __fastcall mount_port(void*,const Pose& input) { pose=input; }
void __fastcall power_port(void* self,bool value) {
    require(self==sensor.data()+560,"electric secondary base ABI");power_state=value;
}
void __fastcall aperture_port(void*,float value) { require(value>0 && value<1,"aperture units"); }
void __fastcall update_port(void*) {}
const Pose& __fastcall position_port(void*) { return pose; }
void __fastcall search_port(void*) {
    require(power_state,"search without electrical power");++searches;
    auto table=*reinterpret_cast<void***>(sensor.data());
    using Sensitivity=float(__fastcall*)(void*,void*);
    require(reinterpret_cast<Sensitivity>(table[19])(sensor.data(),objects[0].data())==50000,"abstract dispatch");
    for (std::size_t i=0;i<admitted;++i) {
        const auto address=reinterpret_cast<std::uintptr_t>(objects[i].data()+256);
        std::memcpy(links.data()+i*24+16,&address,sizeof(address));
        const unsigned id=100+static_cast<unsigned>(i);
        std::memcpy(objects[i].data()+28,&id,sizeof(id));
    }
    const auto begin=reinterpret_cast<std::uintptr_t>(links.data()),end=begin+admitted*24;
    std::memcpy(sensor.data()+984,&begin,sizeof(begin));std::memcpy(sensor.data()+992,&end,sizeof(end));
}
void __fastcall target_port(void*,void*) {
    const double zero=0;
    std::memcpy(sensor.data()+720,&zero,sizeof(zero));std::memcpy(sensor.data()+728,&zero,sizeof(zero));
    std::memcpy(sensor.data()+920,&now,sizeof(now));
}
void __fastcall destroy_port(void*) { ++destroyed; }
void configure(EDPARAM& p) {
    bind(p);ports.bind(p);
    api={};api.clock=&clock_port;api.aircraft=&aircraft_port;api.carrier=&carrier_port;
    api.mount=&mount_port;api.power=&power_port;api.aperture=&aperture_port;api.update=&update_port;
    api.position=&position_port;api.search=&search_port;api.target=&target_port;api.destroy=&destroy_port;api.ready=true;
    auto table=original_table.data();std::memcpy(sensor.data(),&table,sizeof(table));
    // The native fixture supplies a readable RTTI prefix as the real constructor does.
    static std::array<void*,32> prefixed{};
    table=prefixed.data()+1;std::memcpy(sensor.data(),&table,sizeof(table));
    require(install_sensitivity(),"sensitivity table installation");
    aircraft_table[40]=reinterpret_cast<void*>(&own_port);aircraft_table[64]=reinterpret_cast<void*>(&launcher_port);
    constructed=true;accepting=true;snapshot={};request={};last_sample=-100;previous_generation=-1;
    const std::array<double,11> values{2,100,7,1,1,5,0,15*IRSTCore::rad,60*IRSTCore::rad,0,1};
    for (std::size_t i=0;i<values.size();++i) cells[std::string("F22_IRST_CONTROL_")+input_names[i]].value=values[i];
}
double value(const char* name) { return cells[name].value; }
void cycle(EDPARAM& p) { update(p);sample();update(p); }
}
int main() {
    EDPARAM p;configure(p);
    update(p);require(searches==0,"native search escaped cockpit callback");
    sample();update(p);
    require(searches==1 && value("F22_IRST_NATIVE_READY")==1,"admitted IR sample not published");
    require(value("F22_IRST_NATIVE_01_ID")==1,"host ID escaped sensor namespace");
    require(std::abs(value("F22_IRST_NATIVE_01_AZ")+45*IRSTCore::rad)<1e-8,"beam/body conversion");
    require(value("F22_IRST_NATIVE_SEQ")>=2 && std::fmod(value("F22_IRST_NATIVE_SEQ"),2)==0,"packet marker");
    require(cells.find("F22_IRST_NATIVE_01_RANGE")==cells.end(),"fabricated passive range");
    // Failed conversion must withdraw a payload even if its previous number was1.
    cells["F22_IRST_CONTROL_POWER"].success=false;now=100.1;cycle(p);
    require(value("F22_IRST_NATIVE_READY")==0 && searches==1,"failed control conversion admitted");
    cells["F22_IRST_CONTROL_POWER"].success=true;cells["F22_IRST_CONTROL_TIME"].value=100.2;
    now=100.2;admitted=20;cycle(p);
    require(value("F22_IRST_NATIVE_OVERFLOW")==1,"overflow not visible");
    unsigned count=0;for (const auto& track:snapshot.memory.tracks) if (track.id)++count;
    require(count==16,"contact capacity exceeded");
    now=101;cycle(p);require(value("F22_IRST_NATIVE_READY")==0 && !power_state,"source lease renewed on copy");
    const auto old_epoch=snapshot.epoch;now=99;cells["F22_IRST_CONTROL_TIME"].value=99;
    cells["F22_IRST_CONTROL_GENERATION"].value=8;admitted=0;cycle(p);
    require(snapshot.epoch>old_epoch && value("F22_IRST_NATIVE_01_VALID")==0,"rewind retained old files");
    const auto calls=searches;retire();sample();require(destroyed==1 && searches==calls,"retired callback used native object");
    std::cout<<"IRST native owner: callback, abstract dispatch, ABI, bounds, lease, rewind and retirement passed\n";
}

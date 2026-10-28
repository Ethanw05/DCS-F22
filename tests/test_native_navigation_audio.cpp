// Actual navigation owner: audio setup cannot replace or disable observations.
#include "../EFM/source/NativeNavigation.cpp"
#include <array>
#include <iostream>
#include <stdexcept>
#define CHECK(x) do { if (!(x)) throw std::runtime_error(#x); } while (false)
using namespace NativeNavigation;
namespace {
std::map<std::string,double> values;
alignas(8) std::array<std::byte,2856> tacan{};
alignas(8) std::array<std::byte,3352> ils{};
alignas(8) std::array<std::byte,5800> electrical{};
int tacan_table{},ils_table{},electrical_table{},context{};
unsigned audio_calls{};
unsigned mute_calls{};
bool tacan_muted{}, ils_muted{}, mute_blocked{};
bool bad_readback{}, receiver_on=true;
void* parameter(const char* name) { return &values[name]; }
void write(void* p,double value) { *static_cast<double*>(p)=value; }
bool read(const void* p,double& value,bool) { value=*static_cast<const double*>(p);return true; }
void* current_context() { return &context; }
void* device(void*,unsigned id) { return id==24 ? ils.data() : id==26 ? electrical.data() : nullptr; }
void* bus(void* p,int) { return p; }
void connect(void*,void*,void*) {}
void generator(void*,bool,int) {}
void set(void*,int) {}
void power(void*,bool on) { receiver_on=on; }
bool powered(void*) { return receiver_on; }
bool valid(void*) { return true; }
double number(const void*) { return .25; }
void squelch(void* receiver,bool enabled) {
    CHECK(enabled);
    CHECK(receiver==tacan.data()+2064 || receiver==ils.data()+2048);
    ++audio_calls;
}
bool squelch_state(void*) { return !bad_readback; }
void mute(void* receiver, bool enabled) {
    CHECK(enabled);
    CHECK(receiver==tacan.data()+2064 || receiver==ils.data()+2048);
    ++mute_calls;
    if (!mute_blocked) {
        if (receiver==tacan.data()+2064) tacan_muted=enabled;
        else ils_muted=enabled;
    }
}
bool mute_state(void* receiver) {
    return receiver==tacan.data()+2064 ? tacan_muted : ils_muted;
}
void fixture(EDPARAM& p) {
    reset();values.clear();audio_calls=0;bad_readback=false;receiver_on=true;
    mute_calls=0;tacan_muted=ils_muted=mute_blocked=false;
    *reinterpret_cast<void**>(tacan.data())=&tacan_table;
    *reinterpret_cast<void**>(ils.data())=&ils_table;
    *reinterpret_cast<void**>(electrical.data())=&electrical_table;
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=parameter;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=write;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=read;
    api.ready=true;api.reason=0;api.component=tacan.data();api.component_context=&context;
    api.context=current_context;api.device=device;
    api.tacan_table=&tacan_table;api.ils_table=&ils_table;api.electrical_table=&electrical_table;
    api.ac_bus=bus;api.dc_bus=bus;api.connect_ils=connect;api.generator=generator;
    api.channel=set;api.xy=set;api.mode=set;api.mhz=set;api.khz=set;api.ils_power=power;
    api.tacan_power=powered;api.ils_power_state=powered;
    api.bv=valid;api.rv=valid;api.lv=valid;api.gv=valid;
    api.bearing=number;api.range=number;api.loc=number;api.gs=number;
    api.receiver_squelch=squelch;api.receiver_squelch_state=squelch_state;
    api.receiver_mute=mute;api.receiver_mute_state=mute_state;
    for (const auto* name: {"EFM_POWER_OWNER","EFM_PHYSICAL_VALID","EFM_PHYSICAL_GENERATION",
         "EFM_PHYSICAL_CLOCK_KIND","F22_ELECTRICAL_VALID","F22_ESSENTIAL_POWER",
         "EFM_ENVIRONMENT_VALID","L_GEN_POWER"}) values[name]=1;
    values["EFM_PHYSICAL_STAMP"]=values["F22_AP_CLOCK"]=10;
}
void normal_and_failure() {
    EDPARAM p;fixture(p);update(p);
    CHECK(audio_calls==2 && values["F22_NAV_SQUELCH_VALID"]==1);
    CHECK(mute_calls==2 && tacan_muted && ils_muted && values["F22_NAV_IDENT_MUTED"]==1);
    CHECK(values["F22_TCN_BRG_VALID"]==1 && values["F22_TCN_RANGE_VALID"]==1);
    CHECK(values["F22_ILS_LOC_VALID"]==1 && values["F22_ILS_GS_VALID"]==1);
    CHECK(values["F22_TCN_RANGE_M"]==.25*1852);
    bad_readback=true;update(p);
    CHECK(values["F22_NAV_SQUELCH_VALID"]==0 && values["F22_TCN_RANGE_VALID"]==1);
    CHECK(values["F22_NAV_IDENT_MUTED"]==1);
    bad_readback=false;api.receiver_squelch=nullptr;const auto calls=audio_calls;update(p);
    CHECK(audio_calls==calls && values["F22_NAV_SQUELCH_VALID"]==0);
    CHECK(values["F22_ILS_LOC_VALID"]==1);
    // A receiver reset or retune can reopen the audio path; reapply only the
    // mute policy, without disturbing reception or replacing measurements.
    tacan_muted=ils_muted=false;
    values["F22_TCN_CHANNEL"]=12;values["F22_ILS_FREQ_KHZ"]=111100;
    update(p);CHECK(tacan_muted && ils_muted && values["F22_NAV_IDENT_MUTED"]==1);
    CHECK(values["F22_TCN_RANGE_VALID"]==1 && values["F22_ILS_LOC_VALID"]==1);
    mute_blocked=true;tacan_muted=false;update(p);
    CHECK(values["F22_NAV_IDENT_MUTED"]==0 && values["F22_TCN_RANGE_VALID"]==1);
    mute_blocked=false;api.receiver_mute=nullptr;update(p);
    CHECK(values["F22_NAV_IDENT_MUTED"]==0 && values["F22_ILS_GS_VALID"]==1);
    api.receiver_mute=mute;api.receiver_mute_state=nullptr;update(p);
    CHECK(values["F22_NAV_IDENT_MUTED"]==0 && values["F22_ILS_LOC_VALID"]==1);
    api.receiver_mute_state=mute_state;
    api.receiver_squelch=squelch;values["F22_AP_CLOCK"]=11;update(p);
    CHECK(values["F22_TCN_RANGE_VALID"]==0 && values["F22_ILS_LOC_VALID"]==0);
}
void ownership_guards() {
    EDPARAM p;fixture(p);
    *reinterpret_cast<void**>(ils.data())=&tacan_table;update(p);
    CHECK(audio_calls==0 && values["F22_NAV_SQUELCH_VALID"]==0);
    CHECK(mute_calls==0 && values["F22_NAV_IDENT_MUTED"]==0);
    *reinterpret_cast<void**>(ils.data())=&ils_table;update(p);
    CHECK(audio_calls==2 && values["F22_NAV_SQUELCH_VALID"]==1);
    CHECK(mute_calls==2 && values["F22_NAV_IDENT_MUTED"]==1);
    api.ready=false;api.reason=2;update(p);
    CHECK(audio_calls==2 && values["F22_NAV_SQUELCH_VALID"]==0);
    CHECK(values["F22_RADIONAV_AVAILABLE"]==0);
    CHECK(values["F22_NAV_IDENT_MUTED"]==0);
    reset();
}
}
int main() {
    try { normal_and_failure();ownership_guards();std::cout<<"Native NAV squelch: owned receivers, readback, ABI withdrawal and independent navigation data PASS\n";return 0; }
    catch (const std::exception& e) { std::cerr<<e.what()<<'\n';return 1; }
}

// Actual magnetic reference publisher; private receiver/declination ABI excluded.
#include "../../EFM/source/NativeNavigation.cpp"
#include "../../EFM/source/NativeAltimetry.cpp"
#include <iostream>

namespace {
struct Cell { double value=0;bool available=true; };
std::map<std::string,Cell> fields;
EDPARAM* current=nullptr;
bool change_epoch=false;
int context_a=0, context_b=0;
void* bound_context=&context_a;
bool change_context=false;
bool loc_valid=false, gs_valid=false;
double loc_value=0, gs_value=0;
int channel_calls=0, band_calls=0, mode_calls=0, mhz_calls=0, khz_calls=0, power_calls=0;
void* context() {return bound_context;}
void __fastcall set_channel(void*,int) {++channel_calls;}
void __fastcall set_band(void*,int) {++band_calls;}
void __fastcall set_mode(void*,int) {++mode_calls;}
void __fastcall set_mhz(void*,int) {++mhz_calls;}
void __fastcall set_khz(void*,int) {++khz_calls;}
void __fastcall set_power(void*,bool) {++power_calls;}
bool __fastcall loc_ok(void*) {return loc_valid;}
bool __fastcall gs_ok(void*) {return gs_valid;}
double __fastcall localizer(const void*) {return loc_value;}
double __fastcall glideslope(const void*) {return gs_value;}
void* resolve(const char* name) {return &fields[name];}
bool read(const void* pointer,double& value,bool) {
    const auto& cell=*static_cast<const Cell*>(pointer);value=cell.value;return cell.available;
}
void write(void* pointer,double value) {
    static_cast<Cell*>(pointer)->value=value;
    if(change_epoch && pointer==&fields["F22_MAG_DECL"]) {
        change_epoch=false;current->invalidate();
        current->ed_param_api.pfn_ed_cockpit_get_parameter_handle=resolve;
        current->ed_param_api.pfn_ed_cockpit_parameter_value_to_number=read;
        current->ed_param_api.pfn_ed_cockpit_update_parameter_with_number=write;
    }
    if(change_context && pointer==&fields["F22_ILS_GS"]) {
        bound_context=&context_b;change_context=false;
    }
}
void prepare(EDPARAM& p) {
    for(auto& [key,cell]:fields)cell={};
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=resolve;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=read;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=write;
    fields["EFM_PHYSICAL_VALID"].value=1;fields["EFM_PHYSICAL_GENERATION"].value=3;
    current=&p;change_epoch=false;
    bound_context=&context_a;change_context=false;
    NativeNavigation::api.context=context;
}
NativeNavigation::Reception reception(EDPARAM& p) {
    NativeNavigation::Reception result;
    result.parameter_epoch=p.epoch();result.generation=3;result.context=&context_a;
    result.controls={1,0,2,110300,true,true};
    result.tacan_power=result.ils_power=true;
    result.bearing_valid=result.range_valid=result.localizer_valid=result.glideslope_valid=true;
    return result;
}
int check_reception(EDPARAM& p) {
    prepare(p);auto sample=reception(p);
    if(!NativeNavigation::publish_reception(p,sample,0)
        || fields["F22_RADIONAV_CLOCK_KIND"].value!=2
        || fields["F22_ILS_GS_VALID"].value!=1 || fields["F22_ILS_GS"].value!=0)return 10;
    prepare(p);sample=reception(p);change_context=true;
    if(NativeNavigation::publish_reception(p,sample,10)
        || std::fmod(fields["F22_RADIONAV_SEQUENCE"].value,2)!=1)return 11;
    prepare(p);sample=reception(p);fields["EFM_PHYSICAL_GENERATION"].value=4;
    if(NativeNavigation::publish_reception(p,sample,10))return 12;
    prepare(p);sample=reception(p);fields["EFM_PHYSICAL_VALID"].available=false;
    if(NativeNavigation::publish_reception(p,sample,10))return 13;
    prepare(p);sample=reception(p);p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=nullptr;
    if(NativeNavigation::publish_reception(p,sample,10))return 14;
    prepare(p);sample=reception(p);bound_context=nullptr;
    if(NativeNavigation::publish_reception(p,sample,10))return 15;
    prepare(p);sample=reception(p);p.invalidate();
    if(NativeNavigation::publish_reception(p,sample,10))return 16;
    prepare(p);sample=reception(p);NativeNavigation::reception_sequence=16777214;
    if(NativeNavigation::publish_reception(p,sample,10))return 17;
    fields["EFM_PHYSICAL_GENERATION"].value=4;sample.generation=4;
    if(!NativeNavigation::publish_reception(p,sample,11)
        || fields["F22_RADIONAV_SEQUENCE"].value!=2)return 18;
    return 0;
}
int check_signal_admission() {
    using namespace NativeNavigation;
    api.lv=loc_ok;api.gv=gs_ok;api.loc=localizer;api.gs=glideslope;
    loc_admission=gs_admission=SignalAdmission{};
    Reception sample;sample.controls.ils_valid=true;sample.ils_power=true;
    loc_valid=gs_valid=true;loc_value=gs_value=0;
    observe_ils(sample,&context_a);
    if(sample.localizer_valid || sample.glideslope_valid)return 20;
    loc_valid=false;observe_ils(sample,&context_a);
    loc_valid=true;observe_ils(sample,&context_a);
    if(!sample.localizer_valid || sample.glideslope_valid || sample.localizer!=0)return 21;
    gs_valid=false;observe_ils(sample,&context_a);gs_valid=true;observe_ils(sample,&context_a);
    if(!sample.localizer_valid || !sample.glideslope_valid)return 22;
    loc_value=NAN;observe_ils(sample,&context_a);
    if(sample.localizer_valid || !sample.glideslope_valid)return 23;
    loc_admission=gs_admission=SignalAdmission{};loc_value=0;observe_ils(sample,&context_a);
    if(sample.localizer_valid || sample.glideslope_valid)return 24;
    return 0;
}
int check_context_withdrawal(EDPARAM& p) {
    using namespace NativeNavigation;
    for(void* replacement:{static_cast<void*>(&context_b),static_cast<void*>(nullptr)}) {
        prepare(p);api.ready=true;receiver_context_retired=false;
        // Deliberately unreadable component: update must withdraw before any use.
        api.component=reinterpret_cast<void*>(1);api.component_context=&context_a;
        bound_context=replacement;update(p);
        if(fields["F22_RADIONAV_VALID"].value!=0 || fields["F22_RADIONAV_AVAILABLE"].value!=0
            || fields["F22_RADIONAV_REASON"].value!=8 || !receiver_context_retired)return 30;
        bound_context=&context_a;update(p); // Reused address cannot revive the old object.
        if(fields["F22_RADIONAV_AVAILABLE"].value!=0 || fields["F22_RADIONAV_REASON"].value!=8)return 31;
        api.component=nullptr; // Fixture owns no real host component or callback timer.
    }
    return 0;
}
int check_retune() {
    using namespace NativeNavigation;
    api.channel=set_channel;api.xy=set_band;api.mode=set_mode;
    api.mhz=set_mhz;api.khz=set_khz;api.ils_power=set_power;
    ch=band=mode=freq=power=-1;tlast=ilast=nullptr;
    Controls controls{1,0,2,110300,true,true};
    tune_tacan(&context_a,controls,true);tune_ils(&context_b,controls,true);
    if(channel_calls!=1 || band_calls!=1 || mode_calls!=1 || mhz_calls!=1 || khz_calls!=1 || power_calls!=1)return 40;
    bearing_admission.waiting_for_clear=range_admission.waiting_for_clear=false;
    loc_admission.waiting_for_clear=gs_admission.waiting_for_clear=false;
    tune_tacan(&context_a,controls,true);tune_ils(&context_b,controls,true);
    if(bearing_admission.waiting_for_clear || loc_admission.waiting_for_clear || channel_calls!=1 || mhz_calls!=1)return 41;
    controls.frequency_khz=110500;tune_ils(&context_b,controls,true);
    if(!loc_admission.waiting_for_clear || !gs_admission.waiting_for_clear || bearing_admission.waiting_for_clear)return 42;
    loc_admission.waiting_for_clear=gs_admission.waiting_for_clear=false;
    controls.channel=2;tune_tacan(&context_a,controls,true);
    if(!bearing_admission.waiting_for_clear || !range_admission.waiting_for_clear || loc_admission.waiting_for_clear)return 43;
    tune_tacan(&context_a,controls,false);tune_ils(&context_b,controls,false);
    if(mode!=0 || power!=0 || !loc_admission.waiting_for_clear)return 44;
    api.bv=loc_ok;api.rv=gs_ok;api.bearing=localizer;api.range=glideslope;
    Reception sample;sample.controls=controls;sample.tacan_power=true;
    loc_valid=gs_valid=false;observe_tacan(sample,&context_a);
    loc_valid=gs_valid=true;loc_value=0;gs_value=.5;observe_tacan(sample,&context_a);
    if(!sample.bearing_valid || !sample.range_valid || sample.bearing!=0 || sample.range_m!=926)return 45;
    loc_value=NAN;observe_tacan(sample,&context_a);
    if(sample.bearing_valid || !sample.range_valid)return 46;
    return 0;
}
}
int main() {
    EDPARAM p;prepare(p);
    if(!NativeNavigation::publish_magnetic(p,0,0) || fields["F22_MAG_VALID"].value!=1
        || fields["F22_MAG_STAMP"].value!=0 || fields["F22_MAG_CLOCK_KIND"].value!=2)return 1;
    for(const char* name:{"EFM_PHYSICAL_VALID","EFM_PHYSICAL_GENERATION"}) {
        prepare(p);fields[name].available=false;
        if(NativeNavigation::publish_magnetic(p,.1,20) || fields["F22_MAG_VALID"].value!=0)return 2;
    }
    prepare(p);p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=nullptr;
    if(NativeNavigation::publish_magnetic(p,.1,20))return 3;
    prepare(p);change_epoch=true;
    if(NativeNavigation::publish_magnetic(p,.1,20) || std::fmod(fields["F22_MAG_SEQUENCE"].value,2)!=1)return 4;
    prepare(p);
    if(NativeNavigation::publish_magnetic(p,NAN,20) || NativeNavigation::publish_magnetic(p,.1,-1))return 5;
    if(!NativeNavigation::publish_magnetic(p,.1,21) || fields["F22_MAG_GENERATION"].value!=3)return 6;
    if(const int result=check_reception(p))return result;
    if(const int result=check_signal_admission())return result;
    if(const int result=check_retune())return result;
    if(const int result=check_context_withdrawal(p))return result;
    std::cout<<"Magnetic and receiver publication: coherent zero, failure, context/epoch, exhaustion, retune and independent axes pass\n";
}

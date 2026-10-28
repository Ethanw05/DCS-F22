// Actual magnetic reference publisher; private receiver/declination ABI excluded.
#include "../../EFM/source/NativeNavigation.cpp"
#include "../../EFM/source/NativeAltimetry.cpp"
#include <iostream>

namespace {
struct Cell { double value=0;bool available=true; };
std::map<std::string,Cell> fields;
EDPARAM* current=nullptr;
bool change_epoch=false;
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
}
void prepare(EDPARAM& p) {
    for(auto& [key,cell]:fields)cell={};
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=resolve;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=read;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=write;
    fields["EFM_PHYSICAL_VALID"].value=1;fields["EFM_PHYSICAL_GENERATION"].value=3;
    current=&p;change_epoch=false;
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
    std::cout<<"Magnetic publication: zero, failed conversions/write, changed epoch and recovery pass\n";
}

// Actual datalink setting admission; no private host calls or RF authority.
#include "weapon_parameter_port.h"
#include "../../EFM/source/NativeDatalink.cpp"
#include <iostream>

int main() {
    using namespace WeaponParameterPort;
    EDPARAM parameters;bind(parameters);
    constexpr std::array<const char*,3> names{{"MAIN_POWER","F22_DATALINK_ENABLE","F22_IFDL_ENABLE"}};
    NativeDatalink::Controls controls;
    for(const char* name:names)cells[name]={1,true};
    controls.load(parameters);
    if(!controls.power || !controls.ifdl || !controls.complete)return 1;
    for(std::size_t i=0;i<names.size();++i) {
        cells[names[i]].success=false;controls.load(parameters);
        if(controls.complete || controls.ifdl)return 2;
        if(i<2 && controls.power)return 3;
        if(i==2 && !controls.power)return 4; // Independent surviving RX supply.
        cells[names[i]].success=true;
    }
    cells[names[2]].value=0;controls.load(parameters);
    if(!controls.complete || !controls.power || controls.ifdl)return 5;
    cells[names[0]].value=7;controls.load(parameters);
    if(controls.complete || controls.power)return 6;
    cells[names[0]].value=1;cells[names[2]].value=1;controls.load(parameters);
    if(!controls.complete || !controls.ifdl)return 7;
    std::cout<<"Datalink controls: failed conversions, exact flags, independent RX and recovery pass\n";
}

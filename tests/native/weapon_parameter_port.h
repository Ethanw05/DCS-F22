// Explicit software host ports for weapons source-admission tests only.
#pragma once
#include <Windows.h>
#include <Cockpit/CockpitAPI_Declare.h>
#include <map>
#include <string>

namespace WeaponParameterPort {
struct Cell { double value{}; bool success=true; };
inline std::map<std::string,Cell> cells;
inline bool tear_motion=false;
inline void* handle(const char* name) { return &cells[name]; }
inline bool read(const void* pointer, double& result, bool) {
    const auto& cell=*static_cast<const Cell*>(pointer);
    result=cell.value;
    if(tear_motion && pointer==&cells["EFM_HUD_VN"]) {
        cells["EFM_PHYSICAL_GENERATION"].value+=1;tear_motion=false;
    }
    return cell.success;
}
inline void write(void* pointer, double value) { static_cast<Cell*>(pointer)->value=value; }
inline void bind(EDPARAM& parameters) {
    parameters.ed_param_api={};
    parameters.ed_param_api.pfn_ed_cockpit_get_parameter_handle=&handle;
    parameters.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=&read;
    parameters.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=&write;
}
inline void physical() {
    for(auto& [name,cell]:cells)cell.success=true;
    tear_motion=false;
    cells["EFM_POWER_OWNER"].value=1;
    cells["EFM_PHYSICAL_VALID"].value=1;
    cells["EFM_PHYSICAL_GENERATION"].value=3;
    cells["EFM_PHYSICAL_STAMP"].value=10;
    cells["EFM_PHYSICAL_CLOCK_KIND"].value=1;
    cells["F22_AP_CLOCK"].value=10;
    cells["EFM_HUD_VALID"].value=1;
    cells["EFM_HUD_KINEMATICS_VALID"].value=1;
    cells["EFM_HUD_VN"].value=100;
    cells["EFM_HUD_VU"].value=cells["EFM_HUD_VE"].value=0;
    cells["EFM_HUD_WN"].value=cells["EFM_HUD_WU"].value=cells["EFM_HUD_WE"].value=0;
    cells["EFM_HUD_TAS"].value=200;
}
}

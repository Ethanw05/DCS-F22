#include "../EFM/source/CniPower.h"
#include <cstdlib>
#include <iostream>
#include <map>
#include <string>
namespace {
std::map<std::string, double> values;
bool fail = false, tear = false;
void* handle(const char* name) { return &values[name]; }
bool read(const void* pointer, double& result, bool) {
    if (fail) return false;
    result = *static_cast<const double*>(pointer);
    if (tear && pointer == handle("L_GEN_POWER")) values["EFM_PHYSICAL_GENERATION"] += 1;
    return true;
}
void check(bool condition) { if (!condition) std::abort(); }
}
int main() {
    EDPARAM api;
    api.ed_param_api.pfn_ed_cockpit_get_parameter_handle = handle;
    api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = read;
    RaptorCni::Supply supply;
    values["MAIN_POWER"] = 1;
    check(supply.sample(api).receiver); // Older DLL only before ownership.
    values["EFM_POWER_OWNER"] = values["EFM_PHYSICAL_VALID"] = 1;
    values["EFM_PHYSICAL_GENERATION"] = values["EFM_PHYSICAL_CLOCK_KIND"] = 1;
    values["EFM_PHYSICAL_STAMP"] = values["F22_AP_CLOCK"] = 10;
    values["F22_ESSENTIAL_POWER"] = values["F22_ELECTRICAL_VALID"] = 1;
    values["EFM_ENVIRONMENT_VALID"] = values["L_GEN_POWER"] = 1;
    auto frame = supply.sample(api);
    check(frame.valid && frame.receiver && frame.left && !frame.right);
    values["L_GEN_POWER"] = 0; values["R_GEN_POWER"] = 1;
    frame = supply.sample(api);
    check(frame.receiver && !frame.left && frame.right);
    values["R_GEN_POWER"] = 0;
    check(!supply.sample(api).receiver); // Battery/DC never manufactures AC.
    values["R_GEN_POWER"] = values["EFM_THERMAL_FAULT"] = 1;
    frame = supply.sample(api); check(frame.right && frame.thermal && !frame.receiver);
    values["EFM_THERMAL_FAULT"] = 0;
    tear = true; check(!supply.sample(api).valid); tear = false;
    fail = true; check(!supply.sample(api).receiver); fail = false;
    values["EFM_PHYSICAL_STAMP"] = 9;
    check(!supply.sample(api).receiver);
    values["EFM_PHYSICAL_STAMP"] = 10;
    values["EFM_POWER_OWNER"] = 0;
    check(!supply.sample(api).receiver); // No legacy revival after ownership.
    values["EFM_POWER_OWNER"] = 1;
    values["EFM_PHYSICAL_CLOCK_KIND"] = 2;
    check(!supply.sample(api).valid);
    values["EFM_PHYSICAL_CLOCK_KIND"] = 1;
    values["L_GEN_POWER"] = NAN;
    check(!supply.sample(api).receiver);
    values["L_GEN_POWER"] = 0;
    check(supply.sample(api).receiver);
    std::cout << "CNI supply: independent generators, AC gap, thermal inhibition, epochs, stale/API failures and recovery PASS\n";
}

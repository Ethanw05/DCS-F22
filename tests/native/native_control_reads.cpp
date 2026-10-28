// R-INT-008: actual CNI/MWS parameter admission; private host effects excluded.
#include "../../EFM/source/NativeNavigation.cpp"
#include "../../EFM/source/NativeMWS.cpp"
#include <iostream>

namespace {
constexpr std::array<const char*,6> names{{"F22_TCN_CHANNEL","F22_TCN_BAND","F22_TCN_MODE",
    "F22_ILS_FREQ_KHZ","F22_MWS_DEVICE_ID","F22_MWS_SUPPLY"}};
std::array<double,6> values{{126,0,0,110300,7,1}};
int unavailable = -1;
void* resolve(const char* name) {
    for (std::size_t i = 0; i < names.size(); ++i)
        if (std::strcmp(names[i],name) == 0) return &values[i];
    return nullptr;
}
bool convert(const void* handle, double& output, bool) {
    const auto* field = static_cast<const double*>(handle);
    output = *field;
    return field-values.data() != unavailable;
}
}
int main() {
    EDPARAM api;
    api.ed_param_api.pfn_ed_cockpit_get_parameter_handle = resolve;
    api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = convert;
    NativeNavigation::Controls controls;
    if (!NativeNavigation::requested_controls(api,controls) || controls.band != 0 || controls.mode != 0)
        return 1; // Zero-valued X-band/OFF settings are valid, not failed reads.
    for (int index = 0; index < 4; ++index) {
        unavailable = index;
        if (NativeNavigation::requested_controls(api,controls)) return 2;
        if (index < 3 && (!controls.ils_valid || controls.tacan_valid)) return 13;
        if (index == 3 && (!controls.tacan_valid || controls.ils_valid)) return 14;
    }
    unavailable = -1;
    values[0] = .5;
    if (NativeNavigation::requested_controls(api,controls)) return 3;
    values[0] = 1;
    values[3] = 110320;
    if (NativeNavigation::requested_controls(api,controls)) return 4;
    values[3] = 108100;
    if (!NativeNavigation::requested_controls(api,controls)) return 5;
    double id = 0; bool powered = false;
    if (!NativeMWS::read_inputs(api,id,powered) || id != 7 || !powered) return 6;
    for (int index : {4,5}) {
        unavailable = index;
        if (NativeMWS::read_inputs(api,id,powered)) return 7;
    }
    unavailable = -1; values[5] = 0;
    if (!NativeMWS::read_inputs(api,id,powered) || powered) return 8;
    values[5] = 2;
    if (NativeMWS::read_inputs(api,id,powered)) return 9;
    values[5] = 1; values[4] = NAN;
    if (NativeMWS::read_inputs(api,id,powered)) return 10;
    values[4] = 7;
    if (!NativeMWS::read_inputs(api,id,powered)) return 11;
    if (NativeMWS::count_value(0) != 0 || NativeMWS::count_value(64) != 64
        || NativeMWS::count_value(9007199254740992ULL) != -1) return 12;
    std::cout << "Actual CNI/MWS admission: status, zero, bounds, conversion failure and recovery pass\n";
}

// R-INT-008: actual altimeter admission; no expected answers from a legacy test.
#include "../../EFM/source/NativeAltimetry.cpp"
#include <array>
#include <cstring>
#include <iostream>

namespace {
struct Value { double number; bool convertible; };
std::array<Value,3> values{{{0,true},{760,true},{20,true}}};
void* resolve(const char* name) {
    constexpr std::array<const char*,3> names{{"F22_ALT_PRESSURE_REQUEST_VALID",
        "F22_ALT_PRESSURE_MMHG", "F22_ALT_PRESSURE_REQUEST_TIME"}};
    for (std::size_t i = 0; i < names.size(); ++i)
        if (std::strcmp(name, names[i]) == 0) return &values[i];
    return nullptr;
}
bool read(const void* ptr, double& output, bool) {
    const auto* item = static_cast<const Value*>(ptr);
    output = item->number;
    return item->convertible;
}
}
int main() {
    EDPARAM api;
    api.ed_param_api.pfn_ed_cockpit_get_parameter_handle = resolve;
    api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = read;
    NativeAltimetry::reset();
    if (!NativeAltimetry::pressure_request(api,20)) return 1; // Explicit no-request.
    values[0] = {0,false};
    if (NativeAltimetry::pressure_request(api,20)) return 2; // False is not valid zero.
    values[0] = {1,true};
    if (!NativeAltimetry::pressure_request(api,20)) return 3;
    for (std::size_t i = 0; i < values.size(); ++i) {
        values[i].convertible = false;
        if (NativeAltimetry::pressure_request(api,20)) return 4;
        values[i].convertible = true;
    }
    values[1].number = 649.99;
    if (NativeAltimetry::pressure_request(api,20)) return 5;
    values[1].number = 820;
    if (!NativeAltimetry::pressure_request(api,20)) return 6;
    values[2].number = 19.7999;
    if (NativeAltimetry::pressure_request(api,20)) return 7;
    values[2].number = 20.0101;
    if (NativeAltimetry::pressure_request(api,20)) return 8;
    values[2].number = 20;
    if (!NativeAltimetry::pressure_request(api,20)) return 9;
    values[0].number = 2;
    if (NativeAltimetry::pressure_request(api,20)) return 10;
    std::cout << "Altimeter requests: checked reads, bounds, age and fresh recovery pass\n";
}

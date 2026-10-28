// R-INT-008 / VS-001. An independent function-table port through actual EDPARAM.
// This executable never loads the aircraft DLL or invokes a simulator process.
#include "Cockpit/CockpitAPI_Declare.h"
#include <cmath>
#include <iostream>
#include <string_view>

namespace {
bool conversion_success = true;
double payload = 0.0;
unsigned conversions = 0;
bool convert(const void*, double& result, bool) {
    ++conversions;
    result = payload; // A false native return may still modify the output buffer.
    return conversion_success;
}
}

int main(int argc, char** argv) {
    EDPARAM actual;
    actual.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = convert;
    int borrowed = 0;
    if (argc == 2 && std::string_view(argv[1]) == "--failed-read") {
        conversion_success = false;
        payload = 7.0;
        const double exposed = actual.getParamNumber(&borrowed);
        std::cout << "{\"conversion_status\":false,\"exposed_value\":" << exposed << "}\n";
        return 0;
    }
    for (double sample : {0.0, -19.5, 23.75}) {
        payload = sample;
        if (actual.getParamNumber(&borrowed) != sample) return 1;
        double checked = 99;
        if (!actual.getParamNumber(&borrowed, checked) || checked != sample) return 2;
    }
    conversion_success = false;
    for (double sample : {0.0, 7.0}) {
        payload = sample;
        double checked = -123;
        if (actual.getParamNumber(&borrowed, checked) || checked != -123) return 3;
    }
    conversion_success = true;
    for (double sample : {INFINITY, NAN}) {
        payload = sample;
        double checked = -123;
        if (actual.getParamNumber(&borrowed, checked) || checked != -123) return 4;
    }
    double checked = -123;
    const auto calls = conversions;
    if (actual.getParamNumber(nullptr, checked) || conversions != calls) return 5;
    actual.invalidate();
    if (actual.epoch() != 1 || actual.numericReady()) return 6;
    if (actual.getParamHandle("missing") != nullptr) return 7;
    if (actual.getParamNumber(&borrowed, checked) || checked != -123) return 8;
    // This independent process has no CockpitBase module. Rediscovery is explicit.
    if (actual.initialize() || actual.epoch() != 2) return 9;
    actual.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = convert;
    payload = 0;
    if (!actual.getParamNumber(&borrowed, checked) || checked != 0) return 10;
    std::cout << "Actual native conversion transport: zero and signed finite samples pass\n";
    return 0;
}

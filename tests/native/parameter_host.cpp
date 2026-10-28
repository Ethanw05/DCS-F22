// R-INT-008 / VS-001. An independent function-table port through actual EDPARAM.
// This executable never loads the aircraft DLL or invokes a simulator process.
#include "Cockpit/CockpitAPI_Declare.h"
#include <cmath>
#include <iostream>
#include <string_view>

namespace {
bool conversion_success = true;
double payload = 0.0;
bool convert(const void*, double& result, bool) {
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
    }
    std::cout << "Actual native conversion transport: zero and signed finite samples pass\n";
    return 0;
}

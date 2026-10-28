// R-NAV-001 / R-INT-008: actual native reader, independent typed packet port.
#include "../../EFM/source/AltitudeSnapshot.h"
#include <array>
#include <cstring>
#include <iostream>

namespace {
constexpr std::array<const char*,8> names{{"F22_ALT_SNAPSHOT_SEQUENCE",
    "F22_ALT_SNAPSHOT_SCHEMA","F22_ALT_SNAPSHOT_GENERATION","F22_ALT_SNAPSHOT_CLOCK_KIND",
    "F22_ALT_SNAPSHOT_TIME","F22_ALT_RADAR_VALID","F22_ALT_RADAR_FT","F22_ALT_RADAR_STAMP"}};
std::array<double,8> fields{{2,1,3,2,10,1,3280.839895,10}};
int failed_field = -1;
bool tear = false;
void* resolve(const char* name) {
    for (std::size_t i = 0; i < names.size(); ++i)
        if (std::strcmp(name,names[i]) == 0) return &fields[i];
    return nullptr;
}
bool read(const void* handle, double& output, bool) {
    const auto* pointer = static_cast<const double*>(handle);
    const auto index = pointer - fields.data();
    output = *pointer;
    if (tear && index == 6) fields[0] += 2;
    return index != failed_field;
}
}
int main() {
    EDPARAM api;
    api.ed_param_api.pfn_ed_cockpit_get_parameter_handle = resolve;
    api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = read;
    RaptorAltitudes::Snapshot actual;
    actual.initialize(api);
    auto result = actual.read(api,3,10);
    if (!result.radar_valid || std::abs(result.radar_metres-1000) > 1e-6) return 1;
    if (!actual.read(api,3,10.199999).radar_valid || actual.read(api,3,10.200001).radar_valid) return 2;
    for (int i = 0; i < 8; ++i) {
        actual.initialize(api); failed_field = i;
        if (actual.read(api,3,10).radar_valid) return 3;
    }
    failed_field = -1; actual.initialize(api); fields[6] = 0;
    if (!actual.read(api,3,10).radar_valid) return 4; // Real zero is healthy.
    tear = true;
    if (actual.read(api,3,10).radar_valid) return 5;
    tear = false; fields[0] = 4;
    if (actual.read(api,3,9).radar_valid || actual.read(api,3,10).radar_valid) return 6;
    fields[2] = 4;
    if (!actual.read(api,4,10).radar_valid) return 7;
    fields[3] = 1;
    if (actual.read(api,4,10).radar_valid) return 8;
    fields[3] = 2; fields[7] = 10.010001;
    if (actual.read(api,4,10).radar_valid) return 9;
    fields[7] = 10; fields[6] = NAN;
    if (actual.read(api,4,10).radar_valid) return 10;
    std::cout << "Native altitude: coherent checked fields, zero, age, torn/reset and source recovery pass\n";
}

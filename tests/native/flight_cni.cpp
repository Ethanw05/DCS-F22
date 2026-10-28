// Independent actual CniPower source admission; no host/native lifetime claim.
#include "flight_assert.h"
#include "CniPower.h"
#include <array>
#include <cstring>
#include <iostream>

namespace {
struct Cell { const char* name; double value; bool success = true; };
std::array<Cell, 12> cells = {{
    {"EFM_POWER_OWNER", 1}, {"EFM_PHYSICAL_VALID", 1}, {"EFM_PHYSICAL_GENERATION", 2},
    {"EFM_PHYSICAL_STAMP", 4}, {"EFM_PHYSICAL_CLOCK_KIND", 1}, {"F22_AP_CLOCK", 4},
    {"L_GEN_POWER", 1}, {"R_GEN_POWER", 0}, {"F22_ESSENTIAL_POWER", 1},
    {"F22_ELECTRICAL_VALID", 1}, {"EFM_ENVIRONMENT_VALID", 1}, {"EFM_THERMAL_FAULT", 0}}};
void* handle(const char* name) {
    for (auto& cell : cells) if (std::strcmp(name, cell.name) == 0) return &cell;
    return nullptr;
}
bool read(const void* pointer, double& value, bool) {
    if (!pointer) return false;
    const auto& cell = *static_cast<const Cell*>(pointer);
    value = cell.value;
    return cell.success;
}
}
int main() {
    try {
        EDPARAM api;
        api.ed_param_api.pfn_ed_cockpit_get_parameter_handle = handle;
        api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = read;
        RaptorCni::Supply supply;
        flight_require(supply.sample(api).receiver, "Healthy surviving generator did not supply receiver");
        for (auto& cell : cells) {
            cell.success = false;
            flight_require(!supply.sample(api).receiver, "Failed native conversion authenticated receiver");
            cell.success = true;
            flight_require(supply.sample(api).receiver, "Fresh native conversion did not recover receiver");
        }
        cells[6].value = 0;
        flight_require(!supply.sample(api).receiver, "Battery/ground-service storage fabricated receiver AC supply");
        cells[7].value = 1;
        flight_require(supply.sample(api).receiver, "Independent right generator failed receiver recovery");
        cells[10].value = 0;
        flight_require(!supply.sample(api).receiver, "Unknown thermal source retained receiver consent");
        std::cout << "CNI actual source groups,12conversion failures, validzero and independent-source recovery passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}

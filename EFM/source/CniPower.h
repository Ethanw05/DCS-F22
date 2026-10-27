// GPL-3.0-or-later. Estimated CNI receiver feed mapping, not an AC inverter model.
#pragma once
#include <array>
#include <cmath>
#include <Cockpit/CockpitAPI_Declare.h>

namespace RaptorCni {
struct Power {
    bool owned = false, valid = false, left = false, right = false;
    bool receiver = false, thermal = false;
};
class Supply {
    std::array<void*, 13> handles_{};
    bool initialized_ = false, owned_ = false;
    bool read(EDPARAM& api, std::size_t index, double& value) const noexcept {
        const auto get = api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number;
        return handles_[index] && get && get(handles_[index], value, false) && std::isfinite(value);
    }
    void initialize(EDPARAM& api) noexcept {
        constexpr std::array<const char*, 13> names = {
            "EFM_POWER_OWNER", "EFM_PHYSICAL_VALID", "EFM_PHYSICAL_GENERATION",
            "EFM_PHYSICAL_STAMP", "EFM_PHYSICAL_CLOCK_KIND", "F22_AP_CLOCK",
            "L_GEN_POWER", "R_GEN_POWER", "F22_ESSENTIAL_POWER", "F22_ELECTRICAL_VALID",
            "EFM_ENVIRONMENT_VALID", "EFM_THERMAL_FAULT", "MAIN_POWER"};
        const auto get = api.ed_param_api.pfn_ed_cockpit_get_parameter_handle;
        for (std::size_t index = 0; index < names.size(); ++index)
            handles_[index] = get ? get(names[index]) : nullptr;
        initialized_ = get != nullptr;
    }
    static bool flag(double value) noexcept { return value == 0 || value == 1; }
    bool frame_values(EDPARAM& api, std::array<double, 13>& values) const noexcept {
        for (std::size_t index = 0; index < values.size(); ++index)
            if (!read(api, index, values[index])) return false;
        for (std::size_t index = 0; index < 5; ++index) {
            double after = 0;
            if (!read(api, index, after) || after != values[index]) return false;
        }
        return true;
    }
    static bool epoch(const std::array<double, 13>& values) noexcept {
        if (values[0] != 1 || values[1] != 1 || values[4] != 1 || values[2] < 1 ||
            values[2] > 4294967295.0 || values[2] != std::floor(values[2]) || values[3] < 0)
            return false;
        const double age = values[5] - values[3];
        return age >= -.05 && age <= .25; // Adapter policy, same spawn-relative epoch.
    }
    static bool payload(const std::array<double, 13>& values) noexcept {
        for (std::size_t index = 6; index < values.size(); ++index)
            if (!flag(values[index])) return false;
        return true;
    }
    Power legacy(EDPARAM& api) const noexcept {
        Power result;
        double main = 0;
        result.valid = read(api, 12, main) && flag(main);
        result.left = result.right = result.receiver = result.valid && main == 1;
        return result;
    }
    static Power decode(const std::array<double, 13>& values) noexcept {
        Power result;
        result.owned = true;
        result.valid = values[9] == 1;
        result.left = result.valid && values[6] == 1;
        result.right = result.valid && values[7] == 1;
        result.thermal = values[10] != 1 || values[11] == 1;
        // No qualified battery-to-AC bridge. One surviving generator supports
        // both low-load receivers; cooling loss withdraws receiver consent.
        result.receiver = result.valid && values[8] == 1 && (result.left || result.right) && !result.thermal;
        return result;
    }
public:
    Power sample(EDPARAM& api) noexcept {
        if (!initialized_) initialize(api);
        Power result;
        double owner = 0;
        if (read(api, 0, owner) && owner == 1) owned_ = true;
        result.owned = owned_;
        if (!owned_) return legacy(api);
        std::array<double, 13> values{};
        if (!frame_values(api, values) || !epoch(values) || !payload(values)) return result;
        return decode(values);
    }
};
} // namespace RaptorCni

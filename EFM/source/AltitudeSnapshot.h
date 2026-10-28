// GPL-3.0-or-later. I-NAV-001 schema 1 radar altitude in World seconds.
#pragma once
#include <array>
#include <cmath>
#include <Cockpit/CockpitAPI_Declare.h>

namespace RaptorAltitudes {
struct Frame { bool radar_valid = false; double radar_metres = 0; };
class Snapshot {
    std::array<void*,8> handles_{};
    double generation_ = 0, clock_ = -1, blocked_generation_ = -1;
    static bool integer(double value, double minimum, double maximum) noexcept {
        return std::isfinite(value) && value >= minimum && value <= maximum
            && value == std::floor(value);
    }
    static bool fresh(double stamp, double now) noexcept {
        return std::isfinite(stamp) && stamp >= 0 && now - stamp >= -.01 && now - stamp <= .2;
    }
    bool current(double generation, double now) noexcept {
        if (!integer(generation,1,4294967295.) || generation < generation_
            || !std::isfinite(now) || now < 0) return false;
        if (generation == generation_ && now < clock_) blocked_generation_ = generation;
        generation_ = generation; clock_ = now;
        return blocked_generation_ != generation;
    }
    static bool marker(double value) noexcept {
        return integer(value,2,16777214) && std::fmod(value,2) == 0;
    }
    static bool admitted(const std::array<double,8>& values, double generation, double now) noexcept {
        return values[1] == 1 && values[2] == generation && values[3] == 2
            && fresh(values[4],now) && values[5] == 1 && fresh(values[7],now)
            && values[6] >= 0 && values[6] < 20000 * 3.280839895;
    }
public:
    void initialize(EDPARAM& api) noexcept {
        constexpr std::array<const char*,8> names{{"F22_ALT_SNAPSHOT_SEQUENCE",
            "F22_ALT_SNAPSHOT_SCHEMA","F22_ALT_SNAPSHOT_GENERATION",
            "F22_ALT_SNAPSHOT_CLOCK_KIND","F22_ALT_SNAPSHOT_TIME",
            "F22_ALT_RADAR_VALID","F22_ALT_RADAR_FT","F22_ALT_RADAR_STAMP"}};
        for (std::size_t i = 0; i < names.size(); ++i) handles_[i] = api.getParamHandle(names[i]);
        generation_ = 0; clock_ = -1; blocked_generation_ = -1;
    }
    Frame read(EDPARAM& api, double generation, double now) noexcept {
        Frame result;
        if (!current(generation,now)) return result;
        std::array<double,8> values{};
        if (!api.getParamNumber(handles_[0],values[0]) || !marker(values[0])) return result;
        for (std::size_t i = 1; i < values.size(); ++i)
            if (!api.getParamNumber(handles_[i],values[i])) return result;
        double after = 0;
        if (!api.getParamNumber(handles_[0],after) || values[0] != after) return result;
        if (!admitted(values,generation,now)) return result;
        result.radar_valid = true;
        result.radar_metres = values[6] / 3.280839895;
        return result;
    }
};
}

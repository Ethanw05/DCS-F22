#pragma once

#include "VehicleSystems.h"

namespace RaptorVehicle {
// Weapon device -> EFM, spawn-relative seconds and current physical generation.
// Sequence is sampled around the payload; validity is cleared while writing.
struct UtilityDemand {
    double left = 0.0, right = 0.0;
    bool left_tank = false, right_tank = false, inventory_valid = false;
    double inventory_stamp_s = -1.0;
    static bool epoch_valid(double schema, double generation, double expected,
                            double stamp_s, double now_s) {
        return schema == 1.0 && generation == expected && expected >= 1.0 &&
            within(stamp_s, 0.0, 1e9) && within(now_s - stamp_s, -0.05, 0.25);
    }
    static bool sequence_valid(double before, double after) {
        return within(before, 1.0, 4294967295.0) &&
            std::floor(before) == before && before == after;
    }
};
} // namespace RaptorVehicle

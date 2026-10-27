// GPL-3.0-or-later. Global lights and cockpit AFCS have separate namespaces.
#pragma once
#include <cmath>

namespace RaptorCommands {
constexpr int afcs_first = 11600;
constexpr int afcs_last = 11625;
constexpr bool legacy_light(int command) noexcept {
    return command >= 10505 && command <= 10512;
}
inline int afcs(int command) noexcept {
    if (command >= afcs_first && command <= afcs_last) return command;
    // Only unambiguous legacy AFCS bindings are compatible. The eight light
    // IDs must never acquire flight-control authority, even in saved profiles.
    if (command >= 10500 && command <= 10525 && !legacy_light(command))
        return command + 1100;
    switch (command) {
    case 62: case 389: case 408: case 538: case 427: case 428: case 429:
        return command;
    default: return 0;
    }
}
inline bool target_valid(int command, double value) noexcept {
    if (!std::isfinite(value)) return false;
    switch (command) {
    case 11010: return value >= 0 && value < 360;
    case 11011: return value >= 0 && value <= 65000;
    case 11012: return std::abs(value) <= 6000;
    case 11013: return value >= 160 && value <= 700;
    case 11014: return value >= .2 && value <= 2;
    case 11015: return value >= 200 && value <= 5000;
    default: return false;
    }
}
}

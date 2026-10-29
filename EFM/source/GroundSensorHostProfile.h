// GPL-3.0-or-later. Coherent ground-scene plus GraphicsVista image selection.
#pragma once
#include "AesaHostProfile.h"

namespace GroundSensorHostProfile {
struct Modules {
    AesaHostProfile::Modules scene{};
    AesaHostProfile::Image graphics{};
};
struct Profile { Modules modules{}; };
inline constexpr std::array<Profile,2> profiles{{
    {{AesaHostProfile::profiles[0].modules,{0x6aae1df2,0x62000}}},
    {{AesaHostProfile::profiles[1].modules,{0x6acb8063,0x62000}}},
}};
inline constexpr const Profile* select(const Modules& modules) noexcept {
    if (!AesaHostProfile::select(modules.scene)) return nullptr;
    for (const auto& profile : profiles) {
        if (AesaHostProfile::matches(modules.scene,profile.modules.scene)
            && AesaHostProfile::matches(modules.graphics,profile.modules.graphics)) return &profile;
    }
    return nullptr;
}
} // namespace GroundSensorHostProfile

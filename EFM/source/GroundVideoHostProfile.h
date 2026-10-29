// GPL-3.0-or-later. Exact renderer image bundles, independent of sensor readiness.
#pragma once
#include "AesaHostProfile.h"

namespace GroundVideoHostProfile {
using Image = AesaHostProfile::Image;
struct Modules {
    Image cockpit{}, visualizer{}, renderer{}, enlight{}, graphics{};
};
enum class Build { prior, current };
struct Profile {
    Modules modules{};
    Build build{};
};
inline constexpr std::array<Profile, 2> profiles{{
    {{{0x6ac12468, 0x59a000}, {0x6ac12454, 0x312000},
      {0x6aae1e3e, 0x70000}, {0x6aae1e38, 0xa9000}, {0x6aae1df2, 0x62000}}, Build::prior},
    {{{0x6adbad09, 0x68e000}, {0x6ad87745, 0x340000},
      {0x6acb811a, 0x70000}, {0x6acb8107, 0xa9000}, {0x6acb8063, 0x62000}}, Build::current},
}};
inline constexpr bool matches(const Modules& actual, const Modules& expected) noexcept {
    return AesaHostProfile::matches(actual.cockpit, expected.cockpit)
        && AesaHostProfile::matches(actual.visualizer, expected.visualizer)
        && AesaHostProfile::matches(actual.renderer, expected.renderer)
        && AesaHostProfile::matches(actual.enlight, expected.enlight)
        && AesaHostProfile::matches(actual.graphics, expected.graphics);
}
inline constexpr const Profile* select(const Modules& modules) noexcept {
    for (const auto& profile : profiles) {
        if (matches(modules, profile.modules)) return &profile;
    }
    return nullptr;
}
}

// GPL-3.0-or-later. Exact coherent host image bundles; no capability grant.
#pragma once
#include <array>
#include <cstdint>

namespace AesaHostProfile {
struct Image {
    std::uint32_t stamp{}, size{};
};
struct Modules {
    Image cockpit{}, objects{}, world{}, general{};
};
struct Profile {
    Modules modules{};
    std::uint32_t ecm_table{}, ecm_active{}, ecm_strength{};
};
inline constexpr std::array<Profile, 2> profiles{{
    {{{0x6ac12468, 0x59a000}, {0x6aae1e0e, 0x46000},
      {0x6aae1d9b, 0x14000}, {0x6ac122f4, 0x125b000}},
     0x1d0778, 0x65bd0, 0x65bc0},
    {{{0x6adbad09, 0x68e000}, {0x6ad87426, 0x46000},
      {0x6acb804e, 0x14000}, {0x6adbace0, 0x127b000}},
     0x1ef6a8, 0x80c70, 0x80c60},
}};

inline constexpr bool matches(const Image& actual, const Image& expected) noexcept {
    return actual.stamp == expected.stamp && actual.size == expected.size;
}
inline constexpr bool matches(const Modules& actual, const Modules& expected) noexcept {
    return matches(actual.cockpit, expected.cockpit) && matches(actual.objects, expected.objects)
        && matches(actual.world, expected.world) && matches(actual.general, expected.general);
}
inline constexpr const Profile* select(const Modules& modules) noexcept {
    for (const auto& profile : profiles) {
        if (matches(modules, profile.modules)) return &profile;
    }
    return nullptr; // Unknown or mixed images cannot borrow another bundle's offsets.
}
}

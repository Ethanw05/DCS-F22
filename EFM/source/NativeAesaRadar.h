// GPL-3.0-or-later. Version-checked scene provider; independent of avSimpleRadar sensing.
#pragma once
#include <array>
#include <cstdint>
class EDPARAM;
namespace NativeAesaRadar {
void update(EDPARAM& parameters) noexcept;
void attach(void* owned_radar) noexcept;
void reset() noexcept;
void damage(int cell, double integrity) noexcept;
void repair() noexcept;
void sample(void* owned_radar) noexcept;
// Host IDs stay private to the native weapon boundary; zero means unqualified.
unsigned host_for_track(unsigned track) noexcept;
unsigned track_for_host(unsigned host) noexcept;
// Simulator-assisted weapon input, never a radar observation. Valid only for
// the selected, uniquely associated, fresh owned AESA gun track/generation.
struct GunMotion {
    std::array<double, 3> position{}, velocity{}, acceleration{};
    double time{};
    std::uint64_t generation{};
};
bool gun_motion(unsigned track, std::uint64_t generation, GunMotion& output) noexcept;
}

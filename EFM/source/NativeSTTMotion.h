// GPL-3.0-or-later. Exact-build avSimpleRadar STT cache decoder.
#pragma once
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
namespace NativeSTTMotion {
struct Sample {
    std::uint32_t id{};
    double time{}, position[3]{}, velocity[3]{}, acceleration[3]{};
    bool valid{}, acceleration_valid{};
};
template <class T> T field(const std::byte *p, std::size_t at) {
    T value;
    std::memcpy(&value, p + at, sizeof(value));
    return value;
}
inline Sample decode(const std::byte *p, std::size_t size, double now) {
    Sample s;
    if (!p || size < 2136 || !std::isfinite(now))
        return s;
    s.id = field<std::uint32_t>(p, 2024);
    s.time = field<double>(p, 2128);
    if (!s.id || !std::isfinite(s.time) || now - s.time < -.01 || now - s.time > .15)
        return s;
    double speed2 = 0, acc2 = 0;
    for (int i = 0; i < 3; ++i) {
        s.position[i] = field<float>(p, 2076 + i * 4);
        s.velocity[i] = field<float>(p, 2092 + i * 4);
        s.acceleration[i] = field<float>(p, 2104 + i * 4);
        if (!std::isfinite(s.position[i]) || !std::isfinite(s.velocity[i]) ||
            std::abs(s.position[i]) > 1e8)
            return s;
        speed2 += s.velocity[i] * s.velocity[i];
        acc2 += s.acceleration[i] * s.acceleration[i];
    }
    s.valid = speed2 < 1500. * 1500.;
    s.acceleration_valid = std::isfinite(acc2) && acc2 < 150. * 150.;
    return s;
}
} // namespace NativeSTTMotion

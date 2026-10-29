// GPL-3.0-or-later. Bounded bearing-only memory; no target range or identity.
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
namespace IRSTCore {
constexpr std::size_t capacity = 16;
constexpr double pi = 3.14159265358979323846;
constexpr double rad = pi / 180.;
struct Vector {
    double x{}, y{}, z{};
};
struct Frame {
    Vector forward{1, 0, 0}, up{0, 1, 0}, right{0, 0, 1};
};
inline Vector ray(double az, double el) noexcept {
    return {std::cos(el) * std::cos(az), std::sin(el), std::cos(el) * std::sin(az)};
}
inline double dot(Vector a, Vector b) noexcept {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}
inline Vector world(const Frame &f, Vector v) noexcept {
    return {f.forward.x * v.x + f.up.x * v.y + f.right.x * v.z,
            f.forward.y * v.x + f.up.y * v.y + f.right.y * v.z,
            f.forward.z * v.x + f.up.z * v.y + f.right.z * v.z};
}
inline Vector local(const Frame &f, Vector v) noexcept {
    return {dot(f.forward, v), dot(f.up, v), dot(f.right, v)};
}
inline Frame pointing(double az, double el) noexcept {
    return {ray(az, el),
            {-std::sin(el) * std::cos(az), std::cos(el), -std::sin(el) * std::sin(az)},
            {-std::sin(az), 0, std::cos(az)}};
}
struct Track {
    unsigned key{}, id{};
    double time{}, az{}, el{};
    Vector bearing{};
};
inline bool valid_observation(unsigned key, double now, double az, double el) noexcept {
    return key && std::isfinite(now) && std::isfinite(az) && std::isfinite(el) && std::abs(az) <= 90 * rad &&
           el >= -15 * rad && el <= 60 * rad;
}
struct Memory {
    std::array<Track, capacity> tracks{};
    unsigned next_id{1};
    bool overflow{};
    void clear() noexcept {
        tracks = {};
        overflow = false;
    }
    void project(double now, const Frame &body) noexcept {
        overflow = false;
        for (auto &t : tracks) {
            if (!t.id)
                continue;
            if (now < t.time || now - t.time > 2.5) {
                t = {};
                continue;
            }
            const auto v = local(body, t.bearing);
            t.az = std::atan2(v.z, v.x);
            t.el = std::atan2(v.y, std::hypot(v.x, v.z));
        }
    }
    const Track *find(unsigned id) const noexcept {
        for (const auto &t : tracks)
            if (t.id && t.id == id)
                return &t;
        return nullptr;
    }
    void observe(unsigned key, double now, Vector bearing, const Frame &body) noexcept {
        Track *slot = nullptr;
        for (auto &t : tracks) {
            if (t.key == key && t.id) {
                slot = &t;
                break;
            }
            if (!slot && !t.id)
                slot = &t;
        }
        if (!slot) {
            overflow = true;
            return;
        } // Never evict a pilot-selected file.
        const auto v = local(body, bearing);
        const double az = std::atan2(v.z, v.x), el = std::atan2(v.y, std::hypot(v.x, v.z));
        if (!valid_observation(key, now, az, el))
            return;
        if (!slot->id) {
            if (next_id == 0) {
                overflow = true;
                return;
            }
            slot->id = next_id++;
        }
        slot->key = key;
        slot->time = now;
        slot->bearing = bearing;
        slot->az = az;
        slot->el = el;
    }
};
// Estimated mod search pattern: 15 dwells / 1.5s for +/-60 x +/-20 degrees.
inline Vector scan(unsigned dwell, double az, double el, double half_width) noexcept {
    const unsigned columns = half_width > 80 * rad ? 7 : half_width > 40 * rad ? 5 : 3;
    const double column = static_cast<double>(dwell % columns) / (columns - 1);
    const double row = static_cast<double>((dwell / columns) % 3) - 1;
    return {std::clamp(az + (2 * column - 1) * std::max(0., half_width - 15 * rad), -75 * rad, 75 * rad),
            std::clamp(el + row * 15 * rad, 0. * rad, 45 * rad), 0};
}
} // namespace IRSTCore

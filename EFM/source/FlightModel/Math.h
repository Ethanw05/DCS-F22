// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>

namespace f22 {
constexpr double pi = 3.14159265358979323846;
constexpr double gravity = 9.80665;
constexpr double radians(double degrees) { return degrees * pi / 180.0; }
constexpr double degrees(double angle) { return angle * 180.0 / pi; }
inline double clamp(double x, double lo, double hi) { return std::clamp(x, lo, hi); }
inline double smoothStep(double lo, double hi, double x) {
    const double t = clamp((x - lo) / (hi - lo), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}
inline double approach(double current, double target, double rate, double dt) {
    return current + clamp(target - current, -rate * dt, rate * dt);
}
inline double lag(double current, double target, double tau, double dt) {
    return target + (current - target) * std::exp(-dt / tau);
}
struct Vec3 {
    double x = 0, y = 0, z = 0;
    constexpr Vec3() = default;
    constexpr Vec3(double a, double b, double c) : x(a), y(b), z(c) {}
    Vec3 operator+(Vec3 b) const { return {x+b.x, y+b.y, z+b.z}; }
    Vec3 operator-(Vec3 b) const { return {x-b.x, y-b.y, z-b.z}; }
    Vec3 operator*(double s) const { return {x*s, y*s, z*s}; }
    Vec3 operator/(double s) const { return *this * (1.0/s); }
    Vec3& operator+=(Vec3 b) { x+=b.x; y+=b.y; z+=b.z; return *this; }
};
inline double dot(Vec3 a, Vec3 b) { return a.x*b.x + a.y*b.y + a.z*b.z; }
inline Vec3 cross(Vec3 a, Vec3 b) {
    return {a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x};
}
inline double length(Vec3 a) { return std::sqrt(dot(a,a)); }
inline Vec3 unit(Vec3 a) { const double n=length(a); return n>1e-9 ? a/n : Vec3{}; }
inline bool finite(Vec3 v) { return std::isfinite(v.x)&&std::isfinite(v.y)&&std::isfinite(v.z); }
template<std::size_t N>
double interpolate(const std::array<double,N>& x, const std::array<double,N>& y, double value) {
    if(value<=x.front()) return y.front();
    for(std::size_t i=1;i<N;++i) if(value<=x[i]) {
        const double t=(value-x[i-1])/(x[i]-x[i-1]);
        return y[i-1]+t*(y[i]-y[i-1]);
    }
    return y.back();
}
struct Wrench {
    Vec3 force, moment;
    void add(Vec3 f, Vec3 position, Vec3 cg) { force+=f; moment+=cross(position-cg,f); }
    Wrench& operator+=(const Wrench& b) { force+=b.force; moment+=b.moment; return *this; }
};
} // namespace f22

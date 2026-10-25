// GPL-3.0-or-later. Original 3D constant-turn / tangential-acceleration model.
#pragma once
#include "GunIntercept.h"
namespace GunTargetMotion {
using GunIntercept::V;
inline double dot(V a, V b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}
struct Model {
    V p, v, a, normal;
    double q{}, rate{};
    Model(V position, V velocity, V acceleration) : p(position), v(velocity), a(acceleration) {
        double speed2 = dot(v, v);
        if (speed2 > 1e-8) {
            q = dot(a, v) / speed2;
            normal = a - v * q;
            rate = normal.norm() / std::sqrt(speed2);
        }
    }
    V at(double t) const {
        if (dot(v, v) <= 1e-8)
            return p + v * t + a * (.5 * t * t);
        double x = rate * t, x2 = x * x;
        double sinc, cosc, tangent, ramp;
        if (std::abs(x) < .01) {
            double x4 = x2 * x2;
            sinc = 1 - x2 / 6 + x4 / 120;
            cosc = .5 - x2 / 24 + x4 / 720;
            tangent = .5 - x2 / 8 + x4 / 144;
            ramp = 1. / 3 - x2 / 30 + x4 / 840;
        } else {
            sinc = std::sin(x) / x;
            cosc = (1 - std::cos(x)) / x2;
            tangent = sinc - cosc;
            ramp = (std::sin(x) - x * std::cos(x)) / (x2 * x);
        }
        return p + v * (t * sinc + q * t * t * tangent) +
               normal * (t * t * cosc + q * t * t * t * ramp);
    }
    V acceleration(double t) const {
        if (dot(v, v) <= 1e-8) return a;
        const double x = rate * t;
        const double sinc = std::abs(x) < 1e-5 ? 1 - x * x / 6 : std::sin(x) / x;
        const V rotated = v * std::cos(x) + normal * (t * sinc);
        const V derivative = v * (-rate * std::sin(x)) + normal * std::cos(x);
        return derivative * (1 + q * t) + rotated * q;
    }
    V velocity(double t) const {
        if (dot(v, v) <= 1e-8)
            return v + a * t;
        double x = rate * t, sinc = std::abs(x) < 1e-5 ? 1 - x * x / 6 : std::sin(x) / x;
        return (v * std::cos(x) + normal * (t * sinc)) * (1 + q * t);
    }
};
} // namespace GunTargetMotion

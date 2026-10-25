// GPL-3.0-or-later. Original numerical shooting solver; no aircraft-specific tables.
#pragma once
#include <algorithm>
#include <cmath>
namespace GunIntercept {
struct V {
    double x{}, y{}, z{};
    V operator+(V b) const {
        return {x + b.x, y + b.y, z + b.z};
    }
    V operator-(V b) const {
        return {x - b.x, y - b.y, z - b.z};
    }
    V operator*(double s) const {
        return {x * s, y * s, z * s};
    }
    double norm() const {
        return std::hypot(x, y, z);
    }
};
struct Result {
    V direction{};
    double time{}, miss{};
    bool valid{};
};
inline V direction(double az, double el) {
    return {std::cos(el) * std::cos(az), std::sin(el), std::cos(el) * std::sin(az)};
}
// trajectory(direction,time,out): projectile displacement from muzzle, world X/Y/Z.
template <class Trajectory, class Prediction>
Result solve(V position, V velocity, V acceleration, V own_velocity, double speed,
             Trajectory trajectory, Prediction predict, const Result *seed = nullptr) {
    Result out;
    if (!std::isfinite(position.norm()) || !std::isfinite(velocity.norm()) ||
        !std::isfinite(acceleration.norm()) || !std::isfinite(own_velocity.norm()))
        return out;
    if (!std::isfinite(speed) || speed < 100 || speed > 2000 || position.norm() < 40 ||
        position.norm() > 2500 || velocity.norm() > 1800 || acceleration.norm() > 150)
        return out;
    double t = std::clamp(position.norm() / speed, .02, 4.0);
    V d = predict(t) - own_velocity * t + V{0, 4.9 * t * t, 0};
    if (!std::isfinite(d.norm()))
        return out;
    double az = std::atan2(d.z, d.x), el = std::atan2(d.y, std::hypot(d.x, d.z));
    if (seed && seed->valid && seed->time > .01 && seed->time < 4 &&
        std::isfinite(seed->direction.norm())) {
        t = seed->time;
        az = std::atan2(seed->direction.z, seed->direction.x);
        el = std::atan2(seed->direction.y, std::hypot(seed->direction.x, seed->direction.z));
    }
    auto error = [&](double a, double e, double time, V &r) {
        V predicted = predict(time);
        if (!std::isfinite(predicted.norm()))
            return false;
        V bullet;
        if (!trajectory(direction(a, e), time, bullet))
            return false;
        r = bullet - predicted;
        return std::isfinite(r.norm());
    };
    for (int iteration = 0; iteration < 12; ++iteration) {
        V r;
        if (!error(az, el, t, r))
            return out;
        if (r.norm() < .25) {
            out = {direction(az, el), t, r.norm(), true};
            return out;
        }
        double m[3][4]{};
        const double eps[] = {.0001, .0001, .001};
        for (int j = 0; j < 3; ++j) {
            V q;
            if (!error(az + (j == 0 ? eps[j] : 0), el + (j == 1 ? eps[j] : 0),
                       t + (j == 2 ? eps[j] : 0), q))
                return out;
            V c = (q - r) * (1 / eps[j]);
            m[0][j] = c.x;
            m[1][j] = c.y;
            m[2][j] = c.z;
        }
        m[0][3] = -r.x;
        m[1][3] = -r.y;
        m[2][3] = -r.z;
        for (int j = 0; j < 3; ++j) {
            int pivot = j;
            for (int i = j + 1; i < 3; ++i)
                if (std::abs(m[i][j]) > std::abs(m[pivot][j]))
                    pivot = i;
            if (std::abs(m[pivot][j]) < 1e-8)
                return out;
            for (int k = j; k < 4; ++k)
                std::swap(m[j][k], m[pivot][k]);
            double v = m[j][j];
            for (int k = j; k < 4; ++k)
                m[j][k] /= v;
            for (int i = 0; i < 3; ++i)
                if (i != j) {
                    double f = m[i][j];
                    for (int k = j; k < 4; ++k)
                        m[i][k] -= f * m[j][k];
                }
        }
        double scale = std::max(
            {1., std::abs(m[0][3]) / .15, std::abs(m[1][3]) / .15, std::abs(m[2][3]) / .4});
        bool accepted = false;
        for (int attempt = 0; attempt < 5; ++attempt) {
            double f = 1 / (scale * std::pow(2., attempt));
            double next_az = az + m[0][3] * f, next_el = el + m[1][3] * f,
                   next_time = t + m[2][3] * f;
            if (next_time <= .01 || next_time > 4 || std::abs(next_el) > 1.55)
                continue;
            V next;
            if (error(next_az, next_el, next_time, next) && next.norm() < r.norm()) {
                az = next_az;
                el = next_el;
                t = next_time;
                accepted = true;
                break;
            }
        }
        if (!accepted)
            return out;
    }
    return out;
}
} // namespace GunIntercept

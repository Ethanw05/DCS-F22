// GPL-3.0-or-later. Measured-only radar EKF: range, angles and Doppler rate.
// CV process variance and authority thresholds are declared game estimates.
#pragma once
#include <array>
#include <algorithm>
#include <cmath>
#include <cstdint>
namespace AesaTrackFilter {
using Vector = std::array<double, 3>;
using Jacobian = std::array<double, 6>;
using Matrix = std::array<std::array<double, 6>, 6>;
// Continuous white acceleration intensity, m^2/s^3. Unlike per-sample noise,
// this process model has the same uncertainty growth at different revisits.
inline constexpr double acceleration_spectral_density = 100; // Game estimate.
inline constexpr double pi = 3.14159265358979323846;
inline double dot(Vector a, Vector b) noexcept {
    double result = 0;
    for (std::size_t i = 0; i < 3; ++i) result += a[i] * b[i];
    return result;
}
inline Vector difference(Vector a, Vector b) noexcept {
    for (std::size_t i = 0; i < 3; ++i) a[i] -= b[i];
    return a;
}
inline bool finite(Vector value) noexcept {
    for (double axis : value) if (!std::isfinite(axis) || std::abs(axis) > 1e9) return false;
    return true;
}
struct Sample {
    Vector origin{}, own_velocity{};
    Vector forward{1,0,0}, up{0,1,0}, right{0,0,1};
    double time{}, range{}, azimuth{}, elevation{}, range_rate{};
    double range_sigma = 30, angle_sigma = .001, rate_sigma = 1;
    bool rate_valid = true;
};
inline Vector measured_direction(const Sample& s) noexcept {
    Vector result{};
    for (std::size_t i = 0; i < 3; ++i)
        result[i] = s.forward[i] * std::cos(s.elevation) * std::cos(s.azimuth)
            + s.right[i] * std::cos(s.elevation) * std::sin(s.azimuth) + s.up[i] * std::sin(s.elevation);
    return result;
}
struct Estimate {
    Vector position{}, velocity{};
    Matrix covariance{};
    double time{};
    std::uint32_t hits{};
    bool valid{}, velocity_valid{};
};
inline bool valid_sample(const Sample& s) noexcept {
    if (!finite(s.origin) || !finite(s.own_velocity) || !finite(s.forward) || !finite(s.up) || !finite(s.right)) return false;
    const std::array values{s.time,s.range,s.azimuth,s.elevation,s.range_rate,s.range_sigma,s.angle_sigma,s.rate_sigma};
    for (double v : values) if (!std::isfinite(v)) return false;
    if (std::abs(dot(s.forward,s.forward)-1) > .002 || std::abs(dot(s.up,s.up)-1) > .002
        || std::abs(dot(s.right,s.right)-1) > .002 || std::abs(dot(s.forward,s.up)) > .002
        || std::abs(dot(s.forward,s.right)) > .002 || std::abs(dot(s.up,s.right)) > .002) return false;
    return s.range >= 40 && s.range <= 600000 && std::abs(s.azimuth) <= pi && std::abs(s.elevation) < pi / 2
        && s.range_sigma >= .01 && s.range_sigma <= 10000 && s.angle_sigma >= 1e-7 && s.angle_sigma <= .1
        && s.rate_sigma >= .01 && s.rate_sigma <= 1000 && (!s.rate_valid || std::abs(s.range_rate) <= 4000);
}
class Filter {
    enum class Kind { range, azimuth, elevation, rate };
    struct Linearization { Jacobian h{};double residual{}, variance{};bool valid{}; };
    Estimate state_{};
    void initialize(const Sample& s) noexcept {
        const auto u = measured_direction(s);
        state_ = {};state_.time = s.time;state_.hits = 1;state_.valid = true;
        const double transverse = s.range * s.angle_sigma;
        for (std::size_t i = 0; i < 3; ++i) {
            state_.position[i] = s.origin[i] + u[i] * s.range;
            state_.velocity[i] = s.own_velocity[i] + (s.rate_valid ? u[i] * s.range_rate : 0);
            for (std::size_t j = 0; j < 3; ++j) {
                const double radial = u[i] * u[j], tangent = (i == j ? 1.0 : 0.0) - radial;
                state_.covariance[i][j] = s.range_sigma * s.range_sigma * radial + transverse * transverse * tangent;
                state_.covariance[i+3][j+3] = s.rate_valid
                    ? s.rate_sigma * s.rate_sigma * radial + 250000 * tangent : (i == j ? 250000 : 0);
            }
        }
    }
    Estimate predict(double dt) const noexcept {
        auto p = state_;
        const double dt2 = dt * dt, dt3 = dt2 * dt;
        for (std::size_t i = 0; i < 3; ++i) {
            p.position[i] += p.velocity[i] * dt;
            for (std::size_t j = 0; j < 3; ++j) {
                const auto& c = state_.covariance;
                const double q = i == j ? acceleration_spectral_density : 0;
                p.covariance[i][j] = c[i][j] + dt*(c[i][j+3]+c[i+3][j]) + dt2*c[i+3][j+3] + q*dt3/3;
                p.covariance[i][j+3] = c[i][j+3] + dt*c[i+3][j+3] + q*dt2/2;
                p.covariance[i+3][j] = c[i+3][j] + dt*c[i+3][j+3] + q*dt2/2;
                p.covariance[i+3][j+3] = c[i+3][j+3] + q*dt;
            }
        }
        return p;
    }
    static Linearization geometry(const Estimate& p, const Sample& s, Kind kind) noexcept {
        const auto d = difference(p.position,s.origin);
        const double f = dot(d,s.forward), u = dot(d,s.up), r = dot(d,s.right);
        const double horizontal2 = f*f+r*r, range2 = horizontal2+u*u;
        if (horizontal2 < 1 || range2 < 1) return {};
        const double range = std::sqrt(range2), horizontal = std::sqrt(horizontal2);
        Linearization m{};m.valid = true;
        if (kind == Kind::range) {
            m.residual = s.range-range;m.variance = s.range_sigma*s.range_sigma;
            for (std::size_t i=0;i<3;++i) m.h[i]=d[i]/range;
        } else if (kind == Kind::azimuth) {
            m.residual = std::remainder(s.azimuth-std::atan2(r,f),2*pi);m.variance=s.angle_sigma*s.angle_sigma;
            for (std::size_t i=0;i<3;++i) m.h[i]=(f*s.right[i]-r*s.forward[i])/horizontal2;
        } else {
            m.residual=s.elevation-std::atan2(u,horizontal);m.variance=s.angle_sigma*s.angle_sigma;
            for (std::size_t i=0;i<3;++i)
                m.h[i]=(horizontal*s.up[i]-u*(f*s.forward[i]+r*s.right[i])/horizontal)/range2;
        }
        return m;
    }
    static Linearization doppler(const Estimate& p,const Sample& s) noexcept {
        const auto d=difference(p.position,s.origin), v=difference(p.velocity,s.own_velocity);
        const double range=std::sqrt(dot(d,d));
        if (range<1) return {};
        const double rate=dot(v,d)/range;
        Linearization m{};m.valid=true;m.residual=s.range_rate-rate;m.variance=s.rate_sigma*s.rate_sigma;
        for(std::size_t i=0;i<3;++i){m.h[i]=(v[i]-d[i]*rate/range)/range;m.h[i+3]=d[i]/range;}
        return m;
    }
    static bool correct(Estimate& p,const Linearization& m,double& score) noexcept {
        if (!m.valid) return false;
        Jacobian ph{};
        for(std::size_t i=0;i<6;++i) for(std::size_t j=0;j<6;++j) ph[i]+=p.covariance[i][j]*m.h[j];
        double variance=m.variance;
        for(std::size_t i=0;i<6;++i) variance+=m.h[i]*ph[i];
        if (!std::isfinite(variance) || variance<=0) return false;
        score+=m.residual*m.residual/variance;
        Jacobian gain{};
        for(std::size_t i=0;i<6;++i) gain[i]=ph[i]/variance;
        for(std::size_t i=0;i<3;++i){p.position[i]+=gain[i]*m.residual;p.velocity[i]+=gain[i+3]*m.residual;}
        // Scalar Joseph update; full cross-axis/position-velocity covariance.
        Matrix next{};
        for(std::size_t i=0;i<6;++i) for(std::size_t j=0;j<6;++j)
            next[i][j]=p.covariance[i][j]-gain[i]*ph[j]-ph[i]*gain[j]+gain[i]*variance*gain[j];
        for(std::size_t i=0;i<6;++i) for(std::size_t j=0;j<6;++j)
            p.covariance[i][j]=.5*(next[i][j]+next[j][i]);
        return true;
    }
    bool update(Estimate& p,const Sample& s,double& score) noexcept {
        for(const auto kind:{Kind::range,Kind::azimuth,Kind::elevation})
            if (!correct(p,geometry(p,s,kind),score)) return false;
        return !s.rate_valid || correct(p,doppler(p,s),score);
    }
    static bool usable(const Estimate& p) noexcept {
        if (!finite(p.position) || !finite(p.velocity)) return false;
        for(const auto& row : p.covariance) for(double v : row) if (!std::isfinite(v)) return false;
        for(std::size_t i=0;i<6;++i) if (p.covariance[i][i]<0) return false;
        return true;
    }
public:
    void reset() noexcept {state_={};}
    const Estimate& state() const noexcept {return state_;}
    bool observe(const Sample& s) noexcept {
        if (!valid_sample(s)) return false;
        const double dt=s.time-state_.time;
        if (!state_.valid || dt>6 || dt<0) {initialize(s);return true;}
        if (dt<=0) return false;
        auto p=predict(dt);double score=0;
        if (!update(p,s,score) || !usable(p)) return false;
        // Reject inconsistent reports without replacing the established track.
        // A gap exceeding the declared six-second association memory starts
        // a tentative track; arbitrary outlier counts never grant authority.
        if (!std::isfinite(score) || score>36) return false;
        p.hits=std::min(255u,p.hits+1);p.time=s.time;
        double worst=0;
        for(std::size_t i=3;i<6;++i) worst=std::max(worst,p.covariance[i][i]);
        p.velocity_valid=p.hits>=2 && worst<=10000 && dot(p.velocity,p.velocity)<=1500*1500;
        state_=p;return true;
    }
};
}

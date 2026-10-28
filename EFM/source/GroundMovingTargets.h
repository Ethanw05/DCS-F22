// GPL-3.0-or-later. Independent ground-contact geometry and scan history.
#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <array>
#include <cstddef>
#include "AesaTrackFilter.h"
namespace GroundMovingTargets {
inline constexpr double memory_s=30; // Coasting SA covers a finite wide surface scan; never refreshes an observation.
constexpr double pi=3.14159265358979323846, knot=1.943844492440605;
struct Vec {double n{},u{},e{};};
inline double length(Vec v){return std::hypot(v.n,v.u,v.e);}
inline Vec operator-(Vec a,Vec b){return {a.n-b.n,a.u-b.u,a.e-b.e};}
inline double bearing(Vec v){return std::atan2(v.e,v.n);}
inline double difference(double a,double b){return std::remainder(a-b,2*pi);}
struct Contact {
  unsigned id{};Vec point{},velocity{};double stamp{};unsigned hits{};
  double observed_az{},horizontal_range{};
  bool velocity_valid{};
  bool filter_valid{};
  double position_sigma_m{},velocity_sigma_mps{},range_rate{},rate_sigma_mps{};
};
// Recovered APG-73 simulation predicate (FA18C 0x1804A0210), not an APG-77
// specification: ordinary GMT uses 8..55kt movers; an acquired track may stop.
inline bool moving(Vec v){const double k=length(v)*knot;return std::isfinite(k)&&k>=8&&k<=55;}
inline bool illuminated(Vec relative,double heading,double az,double half,double range) {
  const double r=length(relative);
  return std::isfinite(r)&&r>=100&&r<=range&&relative.u<0&&
      std::abs(difference(bearing(relative),heading+az))<=half;
}
class Contacts {
    std::array<Contact, 64> values_{};
    std::size_t size_{};
public:
    void clear() noexcept { size_ = 0; }
    bool empty() const noexcept { return size_ == 0; }
    std::size_t size() const noexcept { return size_; }
    auto begin() noexcept { return values_.begin(); }
    auto end() noexcept { return values_.begin() + size_; }
    auto begin() const noexcept { return values_.begin(); }
    auto end() const noexcept { return values_.begin() + size_; }
    const Contact& operator[](std::size_t i) const noexcept { return values_[i]; }
    void push(Contact c) noexcept { if (size_ < values_.size()) values_[size_++] = c; }
};
class Tracks {
    std::array<Contact, 64> tracks_{};
    double clock_ = -1;
public:
    void clear() noexcept { tracks_ = {}; clock_ = -1; }
    void advance(double now) noexcept {
        if (now < clock_ || now - clock_ > 10) clear();
        clock_ = now;
        for (auto& t : tracks_) if (t.id && now - t.stamp > memory_s) t = {};
    }
    void observe(Contact c) noexcept {
        if (!c.id || !std::isfinite(c.stamp) || !std::isfinite(length(c.point))
            || !std::isfinite(length(c.velocity))) return;
        Contact* slot = nullptr;
        for (auto& t : tracks_) {
            if (t.id == c.id) { slot = &t; break; }
            if (!t.id && !slot) slot = &t;
        }
        if (slot && (!slot->id || c.stamp > slot->stamp)) *slot = c;
    }
    const Contact* find(unsigned id) const noexcept {
        for (const auto& t : tracks_) if (t.id == id) return &t;
        return nullptr;
    }
    Contacts contacts() const noexcept {
        Contacts out;
        for (const auto& t : tracks_) if (t.id) out.push(t);
        std::sort(out.begin(), out.end(), [](const auto& a, const auto& b) { return a.stamp > b.stamp; });
        return out;
    }
};
// Owned surface measurement pipeline. Dwell permission comes from the shared
// AESA scheduler. All noise, delay and velocity-fit values are game estimates.
class Measurements {
public:
    struct Report { Contact value{}; double release{}; bool tracking{}, occupied{}; };
private:
    std::array<Report, 32> pending_{};
    struct TrackFilter { unsigned id{}; double time=-100; AesaTrackFilter::Filter value; };
    std::array<TrackFilter,64> filters_{};
    std::uint32_t random_ = 0x768fbcda;
    double jitter(double scale) noexcept {
        random_ ^= random_ << 13; random_ ^= random_ >> 17; random_ ^= random_ << 5;
        return (static_cast<double>(random_) / 4294967296.0 - .5) * 2 * scale;
    }
    double error(double sigma) noexcept { return jitter(sigma)+jitter(sigma)+jitter(sigma); }
    TrackFilter* filter(unsigned id,double now) noexcept {
        TrackFilter* available=nullptr;
        for(auto& f:filters_) {
            if(f.id && (now<f.time || now-f.time>6)) {f.id=0;f.value.reset();}
            if(f.id==id)return &f;
            if(!f.id && !available)available=&f;
        }
        if(available)available->id=id;
        return available;
    }
    AesaTrackFilter::Sample sample(const Contact& truth,Vec origin,Vec own_velocity,double heading) noexcept {
        const Vec d=truth.point-origin, relative_velocity=truth.velocity-own_velocity;
        const double range=length(d);
        AesaTrackFilter::Sample s{};
        s.origin={origin.n,origin.u,origin.e};s.own_velocity={own_velocity.n,own_velocity.u,own_velocity.e};
        s.forward={std::cos(heading),0,std::sin(heading)};s.right={-std::sin(heading),0,std::cos(heading)};
        s.time=truth.stamp;s.range_sigma=2+range*.0001;s.angle_sigma=.005*pi/180;s.rate_sigma=.5;
        s.range=std::max(40.0,range+error(s.range_sigma));
        s.azimuth=difference(bearing(d),heading)+error(s.angle_sigma);
        s.elevation=std::atan2(d.u,std::hypot(d.n,d.e))+error(s.angle_sigma);
        s.range_rate=(relative_velocity.n*d.n+relative_velocity.u*d.u+relative_velocity.e*d.e)/std::max(1.0,range)
            +error(s.rate_sigma);
        return s;
    }
public:
    void clear() noexcept {
        pending_ = {};
        for(auto& f:filters_){f.id=0;f.time=-100;f.value.reset();}
        random_ = 0x768fbcda;
    }
    bool queue(Contact truth, Vec origin, double heading, double resource, bool tracking, Vec own_velocity={}) noexcept {
        if (!std::isfinite(resource) || resource < .1 || resource > 1 || !truth.id) return false;
        if (!std::isfinite(length(truth.point)) || !std::isfinite(length(origin))
            || !std::isfinite(truth.stamp) || !std::isfinite(heading)) return false;
        Report* slot = nullptr;
        for (auto& p : pending_) {
            if (p.occupied && p.value.id == truth.id) return false;
            if (!p.occupied && !slot) slot = &p;
        }
        if (!slot) return false;
        auto* track=filter(truth.id,truth.stamp);
        if(!track)return false;
        const auto measurement=sample(truth,origin,own_velocity,heading);
        if(!track->value.observe(measurement))return false;
        track->time=truth.stamp;
        const auto& state=track->value.state();
        Contact measured = truth;
        measured.point={state.position[0],state.position[1],state.position[2]};
        measured.velocity={state.velocity[0],state.velocity[1],state.velocity[2]};
        measured.velocity_valid=state.velocity_valid;measured.filter_valid=state.valid;measured.hits=state.hits;
        measured.observed_az=measurement.azimuth;
        measured.horizontal_range=std::hypot(measured.point.n-origin.n,measured.point.e-origin.e);
        double p=0,v=0;
        for(std::size_t i=0;i<3;++i){p=std::max(p,state.covariance[i][i]);v=std::max(v,state.covariance[i+3][i+3]);}
        measured.position_sigma_m=std::sqrt(p);measured.velocity_sigma_mps=std::sqrt(v);
        measured.range_rate=measurement.range_rate;measured.rate_sigma_mps=measurement.rate_sigma;
        *slot = {measured, truth.stamp + .06 / resource, tracking, true};
        return true;
    }
    template<class Consumer> void release(double now, Consumer consume) noexcept {
        for (auto& p : pending_) if (p.occupied && now >= p.release) {
            consume(p.value, p.tracking); p.occupied = false;
        }
    }
};
}

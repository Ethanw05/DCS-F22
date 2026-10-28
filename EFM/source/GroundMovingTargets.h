// GPL-3.0-or-later. Bounded measured ground tracks; no scene-ID association.
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include "AesaAssociation.h"
#include "AesaTrackFilter.h"

namespace GroundMovingTargets {
inline constexpr double memory_s = 30; // Retained SA, not association authority.
inline constexpr double pi = 3.14159265358979323846;
inline constexpr double knot = 1.943844492440605;
inline constexpr std::size_t maximum_tracks = 64;
inline constexpr std::size_t maximum_pending = 32;
inline constexpr std::size_t maximum_returns = 8;
inline constexpr unsigned maximum_token = 16000000;
struct Vec { double n{}, u{}, e{}; };
inline double length(Vec v) { return std::hypot(v.n, v.u, v.e); }
inline Vec operator-(Vec a, Vec b) { return {a.n-b.n, a.u-b.u, a.e-b.e}; }
inline double bearing(Vec v) { return std::atan2(v.e, v.n); }
inline double difference(double a, double b) { return std::remainder(a-b, 2*pi); }
struct RequestIdentity {
    std::uint64_t epoch{};
    double sequence = -1;
    bool operator==(const RequestIdentity&) const = default;
};
struct RawReturn {
    // Used only to suppress duplicate raw scene callbacks, never for matching.
    unsigned private_source{};
    Vec point{}, velocity{};
    double stamp{};
};
struct Contact {
    unsigned id{}; // Owned token; no simulator object ID is published.
    Vec point{}, velocity{};
    double stamp{};
    unsigned hits{};
    double observed_az{}, horizontal_range{};
    bool velocity_valid{}, filter_valid{};
    double position_sigma_m{}, velocity_sigma_mps{}, range_rate{}, rate_sigma_mps{};
    bool association_valid{};
};
// Adopted APG-73 game predicate, not an APG-77 specification.
inline bool moving(Vec v) {
    const double speed = length(v)*knot;
    return std::isfinite(speed) && speed >= 8 && speed <= 55;
}
inline bool illuminated(Vec relative, double heading, double az, double half, double range) {
    const double distance = length(relative);
    return std::isfinite(distance) && distance >= 100 && distance <= range && relative.u < 0
        && std::abs(difference(bearing(relative), heading+az)) <= half;
}
class Contacts {
    std::array<Contact, maximum_tracks> values_{};
    std::size_t size_{};
public:
    void clear() noexcept { size_ = 0; }
    bool empty() const noexcept { return size_ == 0; }
    std::size_t size() const noexcept { return size_; }
    auto begin() noexcept { return values_.begin(); }
    auto end() noexcept { return values_.begin()+size_; }
    auto begin() const noexcept { return values_.begin(); }
    auto end() const noexcept { return values_.begin()+size_; }
    const Contact& operator[](std::size_t i) const noexcept { return values_[i]; }
    void push(Contact value) noexcept { if (size_ < values_.size()) values_[size_++] = value; }
};
enum class ClockState { current, discontinuity, unavailable };
struct Statistics {
    unsigned pending{}, tracks{}, dropped{}, ambiguous{}, token_exhausted{};
};
// The single owner of ground EKFs, tokens and latest measured contacts.
// NativeGroundSensor coordinates an entire source-epoch retirement whenever
// advance() reports a discontinuity; this class never invents a source epoch.
class Measurements {
    struct Report {
        AesaTrackFilter::Sample sample{};
        unsigned private_source{};
        double release{};
        RequestIdentity request{};
        bool tracking{}, occupied{};
    };
    struct Track {
        Contact value{};
        AesaTrackFilter::Filter filter;
        RequestIdentity request{};
        bool tracking{};
    };
    std::array<Report, maximum_pending> pending_{};
    std::array<Track, maximum_tracks> tracks_{};
    unsigned next_token_ = 1;
    std::uint64_t epoch_{};
    std::uint32_t random_ = 0x768fbcda;
    double clock_ = -1;
    Statistics stats_{};

    double jitter(double scale) noexcept {
        random_ ^= random_ << 13;
        random_ ^= random_ >> 17;
        random_ ^= random_ << 5;
        return (static_cast<double>(random_)/4294967296.0-.5)*2*scale;
    }
    double error(double sigma) noexcept { return jitter(sigma)+jitter(sigma)+jitter(sigma); }
    AesaTrackFilter::Sample sample(const RawReturn& raw, Vec origin, Vec velocity, double heading) noexcept {
        const Vec delta = raw.point-origin, relative = raw.velocity-velocity;
        const double distance = length(delta);
        AesaTrackFilter::Sample value{};
        value.origin = {origin.n, origin.u, origin.e};
        value.own_velocity = {velocity.n, velocity.u, velocity.e};
        value.forward = {std::cos(heading), 0, std::sin(heading)};
        value.right = {-std::sin(heading), 0, std::cos(heading)};
        value.time = raw.stamp;
        value.range_sigma = 2+distance*.0001;
        value.angle_sigma = .005*pi/180;
        value.rate_sigma = .5;
        value.range = std::max(40.0, distance+error(value.range_sigma));
        value.azimuth = difference(bearing(delta), heading)+error(value.angle_sigma);
        value.elevation = std::atan2(delta.u, std::hypot(delta.n, delta.e))+error(value.angle_sigma);
        value.range_rate = (relative.n*delta.n+relative.u*delta.u+relative.e*delta.e)
            / std::max(1.0, distance)+error(value.rate_sigma);
        return value;
    }
    void refresh_statistics() noexcept {
        stats_.pending = 0;
        stats_.tracks = 0;
        for (const auto& report : pending_) if (report.occupied) ++stats_.pending;
        for (const auto& track : tracks_) if (track.value.id) ++stats_.tracks;
    }
    bool commit(const Report& report, std::size_t index) noexcept {
        auto& track = tracks_[index];
        const bool born = !track.value.id;
        if (born && next_token_ >= maximum_token) { ++stats_.token_exhausted; return false; }
        if (!track.filter.observe(report.sample)) { track.value.association_valid = false; return false; }
        const auto& state = track.filter.state();
        Contact value{};
        value.id = born ? next_token_++ : track.value.id;
        value.point = {state.position[0], state.position[1], state.position[2]};
        value.velocity = {state.velocity[0], state.velocity[1], state.velocity[2]};
        value.stamp = state.time;
        value.hits = state.hits;
        value.observed_az = report.sample.azimuth;
        value.horizontal_range = std::hypot(value.point.n-report.sample.origin[0], value.point.e-report.sample.origin[2]);
        value.velocity_valid = state.velocity_valid;
        value.filter_valid = state.valid;
        double position = 0, velocity = 0;
        for (std::size_t i = 0; i < 3; ++i) {
            position = std::max(position, state.covariance[i][i]);
            velocity = std::max(velocity, state.covariance[i+3][i+3]);
        }
        value.position_sigma_m = std::sqrt(position);
        value.velocity_sigma_mps = std::sqrt(velocity);
        value.range_rate = report.sample.range_rate;
        value.rate_sigma_mps = report.sample.rate_sigma;
        value.association_valid = true;
        track.value = value;
        track.tracking = report.tracking;
        track.request = report.request;
        return true;
    }
    void birth(const Report& report) noexcept {
        bool overlap = false;
        for (auto& track : tracks_) {
            if (!track.value.id || track.value.stamp != report.sample.time) continue;
            if (track.filter.association_score(report.sample) > AesaAssociation::gate) continue;
            track.value.association_valid = false;
            overlap = true;
        }
        if (overlap) { ++stats_.ambiguous; return; }
        for (std::size_t i = 0; i < tracks_.size(); ++i) {
            if (tracks_[i].value.id) continue;
            if (!commit(report, i)) ++stats_.dropped;
            return;
        }
        ++stats_.dropped;
    }
    void associate(const std::array<Report*, maximum_returns>& reports, std::size_t count) noexcept {
        AesaAssociation::Assignment match{};
        std::array<bool, maximum_tracks> assigned{};
        for (std::size_t row = 0; row < count; ++row)
            for (std::size_t column = 0; column < tracks_.size(); ++column)
                if (tracks_[column].value.id)
                    match.offer(row, column, tracks_[column].filter.association_score(reports[row]->sample));
        for (std::size_t row = 0; row < count; ++row) {
            const auto selected = match.selected(row);
            if (selected == AesaAssociation::none) continue;
            assigned[selected] = commit(*reports[row], selected);
        }
        for (std::size_t column = 0; column < tracks_.size(); ++column)
            if (!assigned[column] && match.tracks[column].index != AesaAssociation::none)
                tracks_[column].value.association_valid = false;
        for (std::size_t row = 0; row < count; ++row) {
            if (match.selected(row) != AesaAssociation::none) continue;
            if (match.reports[row].index != AesaAssociation::none) { ++stats_.ambiguous; continue; }
            birth(*reports[row]);
        }
    }
    Report* next_report(double now) noexcept {
        Report* first = nullptr;
        for (auto& report : pending_)
            if (report.occupied && report.release <= now && (!first || report.sample.time < first->sample.time))
                first = &report;
        return first;
    }
    std::size_t batch(Report& first, double now, std::array<Report*, maximum_returns>& reports) noexcept {
        std::size_t count = 0;
        for (auto& report : pending_)
            if (report.occupied && report.sample.time == first.sample.time && report.release <= now && count < reports.size())
                reports[count++] = &report;
        return count;
    }
public:
    void clear() noexcept {
        pending_ = {};
        for(auto& track:tracks_) {
            track.value={};track.filter.reset();track.request={};track.tracking=false;
        }
        random_ = 0x768fbcda;
        refresh_statistics();
    }
    void reset(std::uint64_t generation) noexcept {
        clear();
        if (generation != epoch_) { next_token_ = 1; stats_ = {}; }
        epoch_ = generation;
        clock_ = -1;
    }
    ClockState advance(double now) noexcept {
        if (!std::isfinite(now) || now < 0) { clear(); clock_ = -1; return ClockState::unavailable; }
        const bool changed = clock_ >= 0 && (now < clock_ || now-clock_ > 10);
        if (changed) clear();
        clock_ = now;
        for (auto& track : tracks_)
            if (track.value.id && now-track.value.stamp > memory_s) track = {};
        refresh_statistics();
        return changed ? ClockState::discontinuity : ClockState::current;
    }
    void discard_search() noexcept {
        for (auto& report : pending_) if (!report.tracking) report = {};
        for (auto& track : tracks_) if (!track.tracking) track = {};
        refresh_statistics();
    }
    bool queue(RawReturn raw, Vec origin, double heading, double resource, bool tracking,
               Vec own_velocity = {}, RequestIdentity request = {}) noexcept {
        if (!std::isfinite(resource) || resource < .1 || resource > 1 || !raw.private_source) return false;
        if (tracking && (request.epoch != epoch_ || !std::isfinite(request.sequence)
            || request.sequence < 0 || request.sequence > 16777215
            || std::floor(request.sequence) != request.sequence)) return false;
        if (!std::isfinite(length(raw.point)) || !std::isfinite(length(raw.velocity))
            || !std::isfinite(length(origin)) || !std::isfinite(length(own_velocity))
            || !std::isfinite(raw.stamp) || raw.stamp < 0 || !std::isfinite(heading)) return false;
        if (clock_ < 0 || raw.stamp != clock_) return false;
        Report* available = nullptr;
        std::size_t same_dwell = 0;
        for (auto& report : pending_) {
            if (report.occupied && report.sample.time == raw.stamp) {
                ++same_dwell;
                if (report.private_source == raw.private_source) return false;
            }
            if (!report.occupied && !available) available = &report;
        }
        if (!available || same_dwell >= maximum_returns) { ++stats_.dropped; return false; }
        const auto measured = sample(raw, origin, own_velocity, heading);
        if (!AesaTrackFilter::valid_sample(measured)) return false;
        *available = {measured, raw.private_source, raw.stamp+.06/resource, request, tracking, true};
        refresh_statistics();
        return true;
    }
    void release(double now) noexcept {
        if (advance(now) != ClockState::current) return;
        for (std::size_t i = 0; i < maximum_pending; ++i) {
            auto* first = next_report(now);
            if (!first) break;
            std::array<Report*, maximum_returns> reports{};
            const auto count = batch(*first, now, reports);
            associate(reports, count);
            for (std::size_t row = 0; row < count; ++row) reports[row]->occupied = false;
        }
        refresh_statistics();
    }
    const Contact* find(unsigned token) const noexcept {
        for (const auto& track : tracks_) if (track.value.id == token && token) return &track.value;
        return nullptr;
    }
    bool belongs_to(unsigned token, RequestIdentity request) const noexcept {
        for (const auto& track : tracks_)
            if (track.value.id == token && token) return track.tracking && track.request == request;
        return false;
    }
    Contacts contacts(bool include_tracking = false) const noexcept {
        Contacts values;
        for (const auto& track : tracks_)
            if (track.value.id && (include_tracking || !track.tracking)) values.push(track.value);
        std::sort(values.begin(), values.end(), [](const auto& a, const auto& b) { return a.stamp > b.stamp; });
        return values;
    }
    const Statistics& statistics() const noexcept { return stats_; }
};
}

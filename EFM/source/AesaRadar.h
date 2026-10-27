// GPL-3.0-or-later. Owned game AESA; no cockpit, DCS ABI, or native radar dependency.
#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include "AesaTrackFilter.h"

namespace AesaRadar {
inline constexpr double pi = 3.14159265358979323846;
inline constexpr double degree = pi / 180.0;
inline constexpr std::size_t maximum_tracks = 64;
inline constexpr std::size_t maximum_candidates = 128;
inline constexpr std::size_t maximum_returns_per_dwell = 8;
inline constexpr std::size_t maximum_pending = 32;
inline constexpr std::size_t maximum_visibility_queries = 16;
struct Vector { double n{}, u{}, e{}; };
Vector operator+(Vector a, Vector b) noexcept;
Vector operator-(Vector a, Vector b) noexcept;
Vector operator*(Vector a, double scale) noexcept;
double dot(Vector a, Vector b) noexcept;
double length(Vector a) noexcept;
bool finite(Vector a) noexcept;
struct Pose {
    Vector position{}, velocity{};
    Vector forward{1, 0, 0}, up{0, 1, 0}, right{0, 0, 1};
};
struct Beam {
    Vector direction{1, 0, 0};
    double half_angle = 3 * degree, range_m = 160 * 1852.0;
    double started{}, completes{}, azimuth{}, elevation{};
    std::uint32_t task_source{};
    bool priority{}, surface{};
};
// Environment truth is private input. It is never a published measurement.
struct Truth {
    std::uint32_t id{};
    Vector position{}, velocity{};
    double cross_section_m2 = 1; // Explicit game estimate if provider has none.
};
struct QueryStats {
    std::uint32_t visited{}, terrain_blocked{}, object_blocked{}, visibility_queries{};
    bool truncated{};
};
class Environment {
public:
    virtual ~Environment() = default;
    virtual bool query(const Pose&, const Beam&, std::span<Truth>, std::size_t&, QueryStats&) noexcept = 0;
    virtual bool visible(const Pose&, const Truth&, QueryStats&) noexcept = 0;
};
struct Controls {
    bool enabled{}, surface{}, emit = true;
    bool cue_valid{};
    double cue_azimuth{}, cue_elevation{};
    double surface_half_azimuth = 45 * degree;
    double resource = 1, azimuth{}, elevation{}, half_azimuth = 60 * degree;
    double half_elevation = 10 * degree, range_m = 160 * 1852.0;
    std::array<std::uint32_t, 10> priority_ids{};
    std::uint32_t selected_id{};
    std::uint64_t generation = 1;
};
// All numeric performance choices are bounded GAME ESTIMATES, not APG-77 data.
struct Policy {
    double dwell_s = .02, processing_s = .06, beam_half_angle = 3 * degree;
    double reference_range_m = 80000, track_revisit_s = .25, track_memory_s = 12;
    double range_error_m = 30, angular_error_rad = .08 * degree;
};
struct Measurement {
    std::uint32_t id{}, hits{};
    Vector position{}, velocity{};
    double time = -100, range_sigma_m{}, angle_sigma_rad{};
    bool valid{}, velocity_valid{};
    Vector raw_position{};
    double position_sigma_m{}, velocity_sigma_mps{}, covariance_pv{};
    bool filter_valid{};
    double measured_range{}, measured_azimuth{}, measured_elevation{}, measured_range_rate{}, rate_sigma_mps{};
    std::array<double, 21> covariance{};
    Vector sensor_origin{},sensor_velocity{},sensor_forward{},sensor_up{},sensor_right{};
};
struct Status {
    bool ready{}, emitting{}, dwelling{}, truncated{};
    Beam beam{};
    std::uint32_t dwells{}, search_dwells{}, track_dwells{}, detections{}, misses{}, invalid{};
    std::uint32_t queue_drops{}, pending{}, tracks{}, terrain_blocked{}, object_blocked{};
    double time{}, resource{}, processing_s{};
    bool surface_service{};
    double surface_azimuth{};
    std::uint32_t surface_sequence{};
};
class Model {
public:
    explicit Model(Policy policy = {}) noexcept;
    void reset(std::uint64_t generation = 1) noexcept;
    bool update(double now, const Controls&, const Pose&, Environment&) noexcept;
    const auto& measurements() const noexcept { return tracks_; }
    const Status& status() const noexcept { return status_; }
private:
    struct Pending { Measurement value{}; AesaTrackFilter::Sample sample{}; double release{}; bool occupied{}; };
    Policy policy_;
    Controls previous_{};
    std::array<Measurement, maximum_tracks> tracks_{};
    std::array<Pending, maximum_pending> pending_{};
    std::array<AesaTrackFilter::Filter, maximum_tracks> filters_{};
    std::array<double, maximum_tracks> last_priority_look_{};
    std::array<Truth, maximum_candidates> candidates_{};
    Status status_{};
    double clock_ = -1, next_start_{};
    std::uint64_t generation_{};
    std::uint32_t random_ = 0x1a2b3c4d, cell_{}, turn_{}, surface_cell_{}, array_turn_{}, candidate_cursor_{};
    double uniform() noexcept;
    double error(double sigma) noexcept;
    bool configuration_changed(const Controls&) const noexcept;
    void age(double now) noexcept;
    void release(double now) noexcept;
    bool assimilate(Pending&, Measurement&) noexcept;
    void start_surface(double, const Controls&, const Pose&) noexcept;
    void start(double now, const Controls&, const Pose&) noexcept;
    void observe(double now, const Controls&, const Pose&, Environment&) noexcept;
    void detect(double now, const Controls&, const Pose&, const Truth&, QueryStats&, Environment&) noexcept;
    void queue(double now, const Pose&, const Truth&, double signal) noexcept;
    Measurement* find(std::uint32_t id) noexcept;
};
}

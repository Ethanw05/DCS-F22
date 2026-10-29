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
    double deadline{}, integration_s{};
    bool cued{};
    std::uint32_t cue_request{};
    bool surface_search{};
    std::uint32_t surface_cells{};
};
// Kinematic truth is private input. Type and coalition are DCS metadata,
// published only on a detected report under the user's presentation policy.
struct Truth {
    std::uint32_t id{};
    Vector position{}, velocity{};
    double cross_section_m2 = 1; // Explicit game estimate if provider has none.
    std::array<char,64> type_name{};
    int coalition_affiliation = -1; // Simulator metadata: 1 friendly, 0 hostile.
};
struct QueryStats {
    std::uint32_t visited{}, terrain_blocked{}, object_blocked{}, visibility_queries{};
    bool truncated{};
};
// Receiver environment at a completed air dwell, not a detected emitter track.
struct Interference {
    bool valid{};
    double noise_ratio{}, time = -100; // J/N (linear), absolute model seconds.
    std::uint32_t sources{};
};
class Environment {
public:
    virtual ~Environment() = default;
    virtual bool interference(double, const Pose&, const Beam&, Interference&, QueryStats&) noexcept = 0;
    virtual bool query(const Pose&, const Beam&, std::span<Truth>, std::size_t&, QueryStats&) noexcept = 0;
    virtual bool visible(const Pose&, const Truth&, QueryStats&) noexcept = 0;
};
struct SurfaceRequest {
    bool valid{}, point{}, routine{};
    Vector direction{};
    double range_m{}, center_elevation{}, half_elevation{};
};
struct Controls {
    bool enabled{}, surface{}, emit = true;
    bool cue_valid{};
    double cue_azimuth{}, cue_elevation{}, cue_half_azimuth{}, cue_half_elevation{}, cue_range_m{};
    std::uint32_t cue_request{};
    double surface_half_azimuth = 45 * degree;
    SurfaceRequest surface_request{};
    double resource = 1, azimuth{}, elevation{}, half_azimuth = 60 * degree;
    double half_elevation = 10 * degree, range_m = 160 * 1852.0;
    std::array<std::uint32_t, 10> priority_ids{};
    std::uint32_t selected_id{}, fire_control_id{};
    bool gun_tracking{};
    std::uint64_t generation = 1;
};
// All numeric performance choices are bounded GAME ESTIMATES, not APG-77 data.
struct Policy {
    double dwell_s = .02, processing_s = .012, beam_half_angle = 3 * degree;
    double reference_range_m = 80000, track_revisit_s = .1, track_memory_s = 12;
    double range_error_m = 30, angular_error_rad = .08 * degree;
    double minimum_track_dwell_s = .004, fire_control_revisit_s = .05;
    double gun_revisit_s = .025, support_revisit_s = .05;
    double maintenance_revisit_s = .5; // Unselected confirmed files; game estimate.
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
    bool association_valid{};
    std::array<char,64> type_name{};
    int coalition_affiliation = -1; // Unknown includes neutral/unavailable sides.
};
// Private simulator bridge. Never published as sensor identity or used for association.
struct Binding {
    std::uint32_t track{}, host{}, hits{};
    bool qualified{};
};
struct Status {
    bool ready{}, emitting{}, dwelling{}, truncated{};
    Beam beam{};
    std::uint32_t dwells{}, search_dwells{}, track_dwells{}, detections{}, misses{}, invalid{};
    std::uint32_t queue_drops{}, pending{}, tracks{}, terrain_blocked{}, object_blocked{};
    double time{}, resource{}, processing_s{};
    bool surface_service{};
    double surface_azimuth{};
    Beam surface_beam{};
    std::uint32_t surface_sequence{}, fire_control_id{}, deadline_misses{};
    double fire_control_revisit_s{}, fire_control_last_look = -100;
    std::uint32_t cue_request{}, cue_dwells{};
    double cue_time = -100;
    std::uint32_t association_ambiguous{}, association_dropped{};
    Interference interference{};
    std::uint32_t surface_discovery_sequence{};
    double surface_discovery_work{};
};
class Model {
public:
    explicit Model(Policy policy = {}) noexcept;
    void reset(std::uint64_t generation = 1) noexcept;
    bool update(double now, const Controls&, const Pose&, Environment&) noexcept;
    const auto& measurements() const noexcept { return tracks_; }
    const Status& status() const noexcept { return status_; }
    const auto& bindings() const noexcept { return bindings_; }
private:
    struct Pending { Measurement value{}; AesaTrackFilter::Sample sample{}; double release{}; bool occupied{}; std::uint32_t host{}; };
    struct Task {
        Measurement* track{};
        double dwell{}, deadline{};
    };
    Policy policy_;
    Controls previous_{};
    std::array<Measurement, maximum_tracks> tracks_{};
    std::array<Pending, maximum_pending> pending_{};
    std::array<AesaTrackFilter::Filter, maximum_tracks> filters_{};
    std::array<Binding, maximum_tracks> bindings_{};
    std::array<double, maximum_tracks> last_priority_look_{};
    std::array<Truth, maximum_candidates> candidates_{};
    Status status_{};
    double clock_ = -1, next_start_{}, priority_run_s_{};
    std::uint64_t generation_{};
    std::uint32_t random_ = 0x1a2b3c4d, cell_{}, turn_{}, surface_cell_{}, array_turn_{}, candidate_cursor_{}, cue_cell_{}, cue_turn_{};
    std::uint32_t next_track_ = 1, surface_turn_{};
    double uniform() noexcept;
    double error(double sigma) noexcept;
    bool configuration_changed(const Controls&) const noexcept;
    void age(double now) noexcept;
    void release(double now) noexcept;
    void associate(std::span<Pending*>) noexcept;
    void birth(Pending&) noexcept;
    Pending* next_report(double now) noexcept;
    std::size_t batch_reports(Pending&, double, std::span<Pending*>) noexcept;
    void commit(Pending&, std::size_t) noexcept;
    void withdraw(std::size_t) noexcept;
    bool assimilate(Pending&, Measurement&) noexcept;
    void start_surface(double, const Controls&, const Pose&) noexcept;
    double revisit(std::uint32_t id, std::size_t priority, const Controls&) const noexcept;
    double track_dwell(const Measurement&, const Pose&) const noexcept;
    Task maintenance_task(double, const Controls&, const Pose&) noexcept;
    Task priority_task(double now, const Controls&, const Pose&) noexcept;
    bool search_angles(const Controls&, double& azimuth, double& elevation) noexcept;
    void start(double now, const Controls&, const Pose&) noexcept;
    void completed_look(double now, const Controls&) noexcept;
    void observe(double now, const Controls&, const Pose&, Environment&) noexcept;
    void reduce_resource(double now, const Controls&) noexcept;
    bool prepare(double now, const Controls&) noexcept;
    void detect(double now, const Controls&, const Pose&, const Truth&, QueryStats&, Environment&) noexcept;
    void queue(double now, const Pose&, const Truth&, double signal) noexcept;
    Measurement* find(std::uint32_t id) noexcept;
};
}

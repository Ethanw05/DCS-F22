// GPL-3.0-or-later. Bounded coherent collection; no host/native API ownership.
#pragma once
#include <array>
#include <complex>
#include <cstddef>
#include <cstdint>
#include <span>

namespace Sar {
using Point = std::array<double, 3>; // World N/U/E metres.
using Complex = std::complex<double>;
inline constexpr double light_speed = 299792458.0;
inline constexpr std::size_t max_pulses = 512, max_frequencies = 256;
inline constexpr std::size_t max_bins = 1024, max_scatterers = 256;
inline constexpr std::size_t max_pending = 8, max_pixels = 256 * 256;
inline constexpr unsigned max_work = 4096;

struct Identity {
    std::uint32_t collection{}, source{}, navigation{}, clock{}, environment{};
    bool operator==(const Identity&) const = default;
};
enum class SceneKind : std::uint32_t { dynamic_snapshot = 1, static_terrain = 2 };
struct Config {
    std::uint32_t schema = 1;
    Identity identity{};
    double start_time{}, duration = 30, maximum_gap = .25;
    Point origin{}, step_x{1, 0, 0}, step_y{0, 0, 1}, reference{};
    std::uint32_t width{}, height{}, pulses{}, frequencies{}, bins{};
    double reference_range{}, first_frequency{}, frequency_step{};
    SceneKind scene_kind = SceneKind::dynamic_snapshot;
    bool operator==(const Config&) const = default;
};
struct Context {
    Identity identity{};
    double time{};
    bool powered{}, navigation_valid{};
};
enum class Service : std::uint32_t { coherent_sar = 1 };
struct Grant {
    Identity identity{};
    std::uint32_t token{};
    Service service = Service::coherent_sar;
    bool illumination_completed{};
    double start_time{}, end_time{}, sample_time{};
    Point actual_position{}, navigation_position{};
};
struct Scatterer { Point position{}; Complex amplitude{}; };
struct Scene {
    bool available{};
    std::uint32_t environment_epoch{};
    double geometry_time{};
    std::span<const Scatterer> scatterers{};
    SceneKind kind = SceneKind::dynamic_snapshot;
    double lease_time{}; // Original provider AND illumination-visibility time.
};
struct SceneRecord {
    SceneKind kind = SceneKind::dynamic_snapshot;
    double geometry_time{}, lease_time{};
};
struct SceneSummary { double oldest_geometry{}, newest_geometry{}, oldest_lease{}, newest_lease{}; };
enum class State { idle, collecting, sealed, complete, cancelled };
enum class Reason {
    none, invalid_config, invalid_context, power, navigation, epoch, clock,
    duration, gap, invalid_grant, replay, capacity, unavailable_scene,
    invalid_scene, range_gate, numeric, incomplete, cancelled
};
struct Progress {
    State state{};
    Reason reason{};
    std::uint32_t submitted{}, completed{}, pending{};
    std::uint64_t work_units{};
};
struct ImageView {
    bool valid{};
    Config config{};
    double first_observation{}, last_observation{};
    std::span<const Complex> pixels{};
    SceneSummary scene{};
};

// Allocate/initialize once outside recurring callbacks. Calls are serialized by
// the owner. A complete view is immutable until the next complete publication.
class Core {
    enum class Stage { clear, waiting, synthesize, seed, reverse, transform, profile, focus, normalize };
    struct Pending {
        Grant grant{};
        SceneRecord scene{};
        std::size_t count{};
        std::array<Scatterer, max_scatterers> scatterers{};
    };
    struct Image {
        bool valid{};
        Config config{};
        double first{}, last{};
        SceneSummary scene{};
        std::array<Complex, max_pixels> pixels{};
    };
    Config config_{};
    Progress progress_{};
    Stage stage_ = Stage::waiting;
    double context_time_{}, first_time_{}, last_time_{};
    std::uint32_t last_token_{};
    SceneSummary scene_summary_{};
    std::size_t head_{}, cursor_{}, frequency_{}, scatterer_{}, transform_length_ = 2;
    unsigned working_{}, complete_ = 1;
    std::array<Pending, max_pending> pending_{};
    std::array<Grant, max_pulses> pulses_{};
    std::array<SceneRecord, max_pulses> scenes_{};
    std::array<Complex, max_pulses * max_frequencies> histories_{};
    std::array<Complex, max_pulses * max_bins> profiles_{};
    std::array<Complex, max_bins> transform_{};
    std::array<Image, 2> images_{};

    bool reject(Reason reason) noexcept;
    bool grant_valid(const Grant& grant) noexcept;
    bool scene_valid(const Grant& grant, const Scene& scene) noexcept;
    void record_scene(const Scene& scene) noexcept;
    bool prepare_work() noexcept;
    void synthesize_one() noexcept;
    void seed_one() noexcept;
    void reverse_one() noexcept;
    void transform_one() noexcept;
    void profile_one() noexcept;
    void focus_one() noexcept;
    void normalize_one() noexcept;
    void work_one() noexcept;
    std::size_t pixels() const noexcept;
public:
    Core() = default;
    Core(const Core&) = delete;
    Core& operator=(const Core&) = delete;
    bool begin(const Config& config, const Context& context) noexcept;
    bool synchronize(const Context& context) noexcept;
    bool submit(const Grant& grant, const Scene& scene, const Context& context) noexcept;
    bool seal() noexcept;
    unsigned step(const Context& context, unsigned budget) noexcept;
    void cancel(Reason reason = Reason::cancelled) noexcept;
    void forget_completed() noexcept;
    Progress progress() const noexcept { return progress_; }
    ImageView last_complete() const noexcept;
    std::span<const Complex> history(std::size_t pulse) const noexcept;
    std::span<const Complex> profile(std::size_t pulse) const noexcept;
    const Grant* pulse(std::size_t index) const noexcept;
    const SceneRecord* scene_record(std::size_t index) const noexcept;
};
} // namespace Sar

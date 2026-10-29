// GPL-3.0-or-later. Ports established SAR research math into fixed owned work.
#include "SarCore.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <numbers>

namespace Sar {
namespace {
constexpr double pi = std::numbers::pi_v<double>;
bool epoch(std::uint32_t value) noexcept { return value >= 1 && value <= 16777215; }
bool finite(Complex value) noexcept { return std::isfinite(value.real()) && std::isfinite(value.imag()); }
bool point(const Point& value) noexcept {
    for (double v : value) if (!std::isfinite(v)) return false;
    return std::abs(value[0]) <= 3e7 && std::abs(value[2]) <= 3e7 && value[1] >= -500 && value[1] <= 100000;
}
Point subtract(const Point& a, const Point& b) noexcept {
    return {a[0] - b[0], a[1] - b[1], a[2] - b[2]};
}
double dot(const Point& a, const Point& b) noexcept { return a[0]*b[0] + a[1]*b[1] + a[2]*b[2]; }
double norm(const Point& a) noexcept { return std::hypot(a[0], a[1], a[2]); }
Complex phase(double radians) noexcept { return {std::cos(radians), std::sin(radians)}; }
bool identity(const Identity& value) noexcept {
    return epoch(value.collection) && epoch(value.source) && epoch(value.navigation) && epoch(value.clock) && epoch(value.environment);
}
bool grid(const Config& value) noexcept {
    if (!value.width || value.width > 256 || !value.height || value.height > 256) return false;
    if (!point(value.origin) || !point(value.reference)) return false;
    const double x = norm(value.step_x), y = norm(value.step_y);
    if (!std::isfinite(x) || !std::isfinite(y) || x < 1e-6 || y < 1e-6 || x > 10000 || y > 10000) return false;
    return std::abs(dot(value.step_x, value.step_y)) <= 1e-9*x*y;
}
bool waveform(const Config& value) noexcept {
    if (!value.frequencies || value.frequencies < 2 || value.frequencies > max_frequencies) return false;
    if (value.bins < 2*value.frequencies || value.bins > max_bins || (value.bins & (value.bins - 1))) return false;
    if (!std::isfinite(value.first_frequency) || value.first_frequency < 1e6 || value.first_frequency > 1e11) return false;
    if (!std::isfinite(value.frequency_step) || value.frequency_step < 1 || value.frequency_step > 1e9) return false;
    return value.first_frequency + (value.frequencies - 1)*value.frequency_step <= 1e11;
}
bool collection_clock(const Config& value) noexcept {
    if (!std::isfinite(value.start_time) || value.start_time < 0) return false;
    if (!std::isfinite(value.duration) || value.duration <= 0 || value.duration > 60) return false;
    return std::isfinite(value.maximum_gap) && value.maximum_gap > 0 && value.maximum_gap <= value.duration;
}
bool valid_config(const Config& value) noexcept {
    if (value.schema != 1 || !identity(value.identity) || !grid(value) || !waveform(value)) return false;
    if (value.scene_kind != SceneKind::dynamic_snapshot && value.scene_kind != SceneKind::static_terrain) return false;
    if (!value.pulses || value.pulses > max_pulses || !collection_clock(value)) return false;
    return std::isfinite(value.reference_range) && value.reference_range >= 1 && value.reference_range <= 3e7;
}
double spacing(const Config& config) noexcept { return light_speed / (2*config.bins*config.frequency_step); }
bool in_gate(const Config& config, double difference) noexcept {
    const double index = difference/spacing(config) + config.bins/2.0;
    return std::isfinite(index) && index >= 0 && index < config.bins - 1;
}
Point pixel(const Config& config, std::size_t index) noexcept {
    Point result{};
    for (std::size_t i = 0; i < result.size(); ++i)
        result[i] = config.origin[i] + (index % config.width)*config.step_x[i] + (index/config.width)*config.step_y[i];
    return result;
}
// Same rationalized local range difference as Backproject.hlsl::evaluate.
double difference(const Config& config, const Grant& grant, const Point& at) noexcept {
    const auto ray = subtract(config.reference, grant.navigation_position);
    const auto q = subtract(at, config.reference);
    const double reference = norm(ray), delta = 2*dot(ray, q) + dot(q, q);
    const double range_squared = reference*reference + delta;
    if (reference <= 0 || range_squared <= 0) return std::numeric_limits<double>::quiet_NaN();
    return delta/(std::sqrt(range_squared) + reference) + reference - config.reference_range;
}
bool grant_times(const Grant& grant, const Config& config, double now) noexcept {
    if (!std::isfinite(grant.start_time) || !std::isfinite(grant.end_time) || !std::isfinite(grant.sample_time)) return false;
    if (grant.start_time < config.start_time || grant.end_time <= grant.start_time || grant.end_time - grant.start_time > .05) return false;
    return grant.sample_time >= grant.start_time && grant.sample_time <= grant.end_time &&
        grant.end_time <= now && now - grant.end_time <= .25;
}
bool scene_clock(const Scene& scene, const Grant& grant) noexcept {
    if (!std::isfinite(scene.geometry_time) || scene.geometry_time < 0 || scene.geometry_time > grant.sample_time) return false;
    if (scene.kind == SceneKind::dynamic_snapshot && grant.sample_time - scene.geometry_time > .05) return false;
    return std::isfinite(scene.lease_time) && scene.lease_time >= 0 && scene.lease_time <= grant.sample_time
        && grant.sample_time - scene.lease_time <= .05;
}
} // namespace

std::size_t Core::pixels() const noexcept { return static_cast<std::size_t>(config_.width)*config_.height; }
bool Core::reject(Reason reason) noexcept { progress_.reason = reason; return false; }
void Core::cancel(Reason reason) noexcept {
    progress_.state = State::cancelled; progress_.reason = reason; progress_.pending = 0;
    stage_ = Stage::waiting;
}
bool Core::begin(const Config& config, const Context& context) noexcept {
    cancel();
    if (!valid_config(config)) return reject(Reason::invalid_config);
    config_ = config; progress_ = {}; progress_.state = State::collecting;
    context_time_ = config.start_time; first_time_ = last_time_ = config.start_time;
    head_ = cursor_ = frequency_ = scatterer_ = 0; last_token_ = 0;
    working_ = 1 - complete_; stage_ = Stage::clear;
    return synchronize(context);
}
bool Core::synchronize(const Context& context) noexcept {
    Reason reason = Reason::none;
    if (!identity(context.identity) || !std::isfinite(context.time)) reason = Reason::invalid_context;
    else if (!context.powered) reason = Reason::power;
    else if (!context.navigation_valid) reason = Reason::navigation;
    else if (context.identity != config_.identity) reason = Reason::epoch;
    else if (context.time < context_time_) reason = Reason::clock;
    else if (context.time - config_.start_time > config_.duration) reason = Reason::duration;
    if (reason != Reason::none) { cancel(reason); return false; }
    context_time_ = context.time;
    return true;
}
bool Core::grant_valid(const Grant& grant) noexcept {
    if (grant.identity != config_.identity || !epoch(grant.token) || !grant.illumination_completed || grant.service != Service::coherent_sar)
        return reject(Reason::invalid_grant);
    if (grant.token <= last_token_ || (progress_.submitted && grant.sample_time <= last_time_)) return reject(Reason::replay);
    if (!grant_times(grant, config_, context_time_) || !point(grant.actual_position) || !point(grant.navigation_position))
        return reject(Reason::invalid_grant);
    if (progress_.submitted && grant.sample_time - last_time_ > config_.maximum_gap) { cancel(Reason::gap); return false; }
    return true;
}
bool Core::scene_valid(const Grant& grant, const Scene& scene) noexcept {
    if (!scene.available) return reject(Reason::unavailable_scene);
    if (scene.environment_epoch != config_.identity.environment) { cancel(Reason::epoch); return false; }
    if (scene.scatterers.size() > max_scatterers || scene.kind != config_.scene_kind || !scene_clock(scene, grant))
        return reject(Reason::invalid_scene);
    for (const auto& scatterer : scene.scatterers) {
        if (!point(scatterer.position) || !finite(scatterer.amplitude) || std::abs(scatterer.amplitude) > 1e6)
            return reject(Reason::invalid_scene);
        const double range = norm(subtract(scatterer.position, grant.actual_position));
        if (range <= 0 || !in_gate(config_, range - config_.reference_range)) return reject(Reason::range_gate);
    }
    return true;
}
void Core::record_scene(const Scene& scene) noexcept {
    if (!progress_.submitted) scene_summary_ = {scene.geometry_time, scene.geometry_time, scene.lease_time, scene.lease_time};
    else {
        scene_summary_.oldest_geometry = std::min(scene_summary_.oldest_geometry, scene.geometry_time);
        scene_summary_.newest_geometry = std::max(scene_summary_.newest_geometry, scene.geometry_time);
        scene_summary_.oldest_lease = std::min(scene_summary_.oldest_lease, scene.lease_time);
        scene_summary_.newest_lease = std::max(scene_summary_.newest_lease, scene.lease_time);
    }
}
bool Core::submit(const Grant& grant, const Scene& scene, const Context& context) noexcept {
    if (!synchronize(context)) return false;
    if (progress_.state != State::collecting) return reject(Reason::incomplete);
    if (progress_.pending == max_pending || progress_.submitted >= config_.pulses) return reject(Reason::capacity);
    if (!grant_valid(grant) || !scene_valid(grant, scene)) return false;
    auto& slot = pending_[(head_ + progress_.pending) % max_pending];
    slot.grant = grant; slot.scene = {scene.kind, scene.geometry_time, scene.lease_time}; slot.count = scene.scatterers.size();
    std::copy(scene.scatterers.begin(), scene.scatterers.end(), slot.scatterers.begin());
    if (!progress_.submitted) first_time_ = grant.sample_time;
    record_scene(scene);
    last_time_ = grant.sample_time; last_token_ = grant.token;
    ++progress_.pending; ++progress_.submitted; progress_.reason = Reason::none;
    return true;
}
bool Core::seal() noexcept {
    if (progress_.state != State::collecting || progress_.submitted != config_.pulses) return reject(Reason::incomplete);
    progress_.state = State::sealed;
    return true;
}
bool Core::prepare_work() noexcept {
    if (progress_.state != State::collecting && progress_.state != State::sealed) return false;
    if (stage_ != Stage::waiting) return true;
    cursor_ = frequency_ = scatterer_ = 0;
    if (progress_.pending) stage_ = Stage::synthesize;
    else if (progress_.state == State::sealed && progress_.completed == config_.pulses) stage_ = Stage::normalize;
    else return false;
    return true;
}
void Core::synthesize_one() noexcept {
    const auto& slot = pending_[head_];
    auto& value = histories_[progress_.completed*max_frequencies + frequency_];
    if (!scatterer_) value = {};
    if (slot.count) {
        const auto& item = slot.scatterers[scatterer_];
        const double range = norm(subtract(item.position, slot.grant.actual_position)) - config_.reference_range;
        const double hz = config_.first_frequency + frequency_*config_.frequency_step;
        value += item.amplitude*phase(-4*pi*hz*range/light_speed);
    }
    if (!finite(value)) { cancel(Reason::numeric); return; }
    if (++scatterer_ >= slot.count) { scatterer_ = 0; ++frequency_; }
    if (frequency_ == config_.frequencies) { stage_ = Stage::seed; cursor_ = 0; }
}
void Core::seed_one() noexcept {
    transform_[cursor_] = cursor_ < config_.frequencies ? histories_[progress_.completed*max_frequencies + cursor_] : Complex{};
    if (++cursor_ == config_.bins) { stage_ = Stage::reverse; cursor_ = 0; }
}
void Core::reverse_one() noexcept {
    std::size_t reversed = 0, value = cursor_;
    for (std::size_t bit = config_.bins/2; bit; bit /= 2) { reversed += (value & 1)*bit; value >>= 1; }
    if (reversed > cursor_) std::swap(transform_[cursor_], transform_[reversed]);
    if (++cursor_ == config_.bins) { stage_ = Stage::transform; cursor_ = 0; transform_length_ = 2; }
}
void Core::transform_one() noexcept {
    const std::size_t half = transform_length_/2, offset = cursor_%half;
    const std::size_t a = (cursor_/half)*transform_length_ + offset, b = a + half;
    const auto value = transform_[b]*phase(2*pi*offset/transform_length_);
    const auto first = transform_[a]; transform_[a] = first + value; transform_[b] = first - value;
    if (++cursor_ == config_.bins/2) {
        cursor_ = 0;
        if (transform_length_ == config_.bins) stage_ = Stage::profile;
        else transform_length_ *= 2;
    }
}
void Core::profile_one() noexcept {
    const auto value = transform_[(cursor_ + config_.bins/2) % config_.bins]/static_cast<double>(config_.frequencies);
    if (!finite(value)) { cancel(Reason::numeric); return; }
    profiles_[progress_.completed*max_bins + cursor_] = value;
    if (++cursor_ == config_.bins) { cursor_ = 0; stage_ = Stage::focus; }
}
void Core::focus_one() noexcept {
    const auto at = pixel(config_, cursor_);
    const double distance = difference(config_, pending_[head_].grant, at);
    if (!point(at) || !in_gate(config_, distance)) { cancel(Reason::range_gate); return; }
    const double index = distance/spacing(config_) + config_.bins/2.0;
    const auto lower = static_cast<std::size_t>(std::floor(index));
    const double fraction = index - static_cast<double>(lower);
    const auto* row = profiles_.data() + progress_.completed*max_bins;
    const auto value = (row[lower]*(1 - fraction) + row[lower + 1]*fraction)*phase(4*pi*config_.first_frequency*distance/light_speed);
    auto& sum = images_[working_].pixels[cursor_]; sum += value;
    if (!finite(sum)) { cancel(Reason::numeric); return; }
    if (++cursor_ == pixels()) {
        pulses_[progress_.completed] = pending_[head_].grant; scenes_[progress_.completed] = pending_[head_].scene;
        ++progress_.completed;
        head_ = (head_ + 1) % max_pending; --progress_.pending; stage_ = Stage::waiting;
    }
}
void Core::normalize_one() noexcept {
    auto& image = images_[working_];
    image.pixels[cursor_] /= static_cast<double>(progress_.completed);
    if (++cursor_ == pixels()) {
        image.config = config_; image.first = first_time_; image.last = last_time_; image.scene = scene_summary_; image.valid = true;
        complete_ = working_; progress_.state = State::complete; stage_ = Stage::waiting;
    }
}
void Core::work_one() noexcept {
    switch (stage_) {
    case Stage::clear:
        images_[working_].pixels[cursor_] = {};
        if (++cursor_ == pixels()) stage_ = Stage::waiting;
        break;
    case Stage::synthesize: synthesize_one(); break;
    case Stage::seed: seed_one(); break;
    case Stage::reverse: reverse_one(); break;
    case Stage::transform: transform_one(); break;
    case Stage::profile: profile_one(); break;
    case Stage::focus: focus_one(); break;
    case Stage::normalize: normalize_one(); break;
    case Stage::waiting: break;
    }
}
unsigned Core::step(const Context& context, unsigned budget) noexcept {
    if (!synchronize(context)) return 0;
    const unsigned limit = std::min(budget, max_work);
    unsigned used = 0;
    while (used < limit && prepare_work()) { work_one(); ++used; }
    progress_.work_units += used;
    return used;
}
void Core::forget_completed() noexcept { images_[complete_].valid = false; }
ImageView Core::last_complete() const noexcept {
    const auto& image = images_[complete_];
    if (!image.valid) return {};
    return {true, image.config, image.first, image.last,
        {image.pixels.data(), static_cast<std::size_t>(image.config.width)*image.config.height}, image.scene};
}
std::span<const Complex> Core::history(std::size_t pulse_index) const noexcept {
    if (progress_.state == State::cancelled || pulse_index >= progress_.completed) return {};
    return {histories_.data() + pulse_index*max_frequencies, config_.frequencies};
}
std::span<const Complex> Core::profile(std::size_t pulse_index) const noexcept {
    if (progress_.state == State::cancelled || pulse_index >= progress_.completed) return {};
    return {profiles_.data() + pulse_index*max_bins, config_.bins};
}
const Grant* Core::pulse(std::size_t index) const noexcept {
    return progress_.state != State::cancelled && index < progress_.completed ? &pulses_[index] : nullptr;
}
const SceneRecord* Core::scene_record(std::size_t index) const noexcept {
    return progress_.state != State::cancelled && index < progress_.completed ? &scenes_[index] : nullptr;
}
} // namespace Sar

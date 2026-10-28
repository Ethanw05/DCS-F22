// GPL-3.0-or-later. Finite electronic beam service and measured radar reports.
#include "AesaRadar.h"
#include "AesaAssociation.h"
#include <algorithm>
#include <cmath>

namespace AesaRadar {
Vector operator+(Vector a, Vector b) noexcept { return {a.n + b.n, a.u + b.u, a.e + b.e}; }
Vector operator-(Vector a, Vector b) noexcept { return {a.n - b.n, a.u - b.u, a.e - b.e}; }
Vector operator*(Vector a, double s) noexcept { return {a.n * s, a.u * s, a.e * s}; }
double dot(Vector a, Vector b) noexcept { return a.n * b.n + a.u * b.u + a.e * b.e; }
double length(Vector a) noexcept { return std::sqrt(dot(a, a)); }
bool finite(Vector a) noexcept { return std::isfinite(a.n) && std::isfinite(a.u) && std::isfinite(a.e); }
namespace {
bool valid_pose(const Pose& p) noexcept {
    return finite(p.position) && finite(p.velocity) && finite(p.forward) && finite(p.up) && finite(p.right)
        && std::abs(length(p.forward) - 1) < .002 && std::abs(length(p.up) - 1) < .002
        && std::abs(length(p.right) - 1) < .002 && std::abs(dot(p.forward, p.up)) < .002
        && std::abs(dot(p.forward, p.right)) < .002 && std::abs(dot(p.up, p.right)) < .002;
}
bool valid_controls(const Controls& c) noexcept {
    if(c.surface&&(!std::isfinite(c.surface_half_azimuth)||c.surface_half_azimuth<degree
        ||c.surface_half_azimuth>60*degree))return false;
    const std::array ranges{
        std::array{c.resource, .1, 1.0}, std::array{c.range_m, 40.0, 160 * 1852.0},
        std::array{c.azimuth, -60 * degree, 60 * degree},
        std::array{c.elevation, -60 * degree, 60 * degree},
        std::array{c.half_azimuth, .001 * degree, 60 * degree},
        std::array{c.half_elevation, .001 * degree, 60 * degree}};
    for (const auto& r : ranges)
        if (!std::isfinite(r[0]) || r[0] < r[1] || r[0] > r[2]) return false;
    return true;
}
double bounded(double value, double low, double high, double fallback) noexcept {
    return std::isfinite(value) && value >= low && value <= high ? value : fallback;
}
Policy checked(Policy p) noexcept {
    const Policy defaults{};
    p.dwell_s = bounded(p.dwell_s, .005, 1, defaults.dwell_s);
    p.processing_s = bounded(p.processing_s, .001, 2, defaults.processing_s);
    p.beam_half_angle = bounded(p.beam_half_angle, degree, 10 * degree, defaults.beam_half_angle);
    p.reference_range_m = bounded(p.reference_range_m, 1000, 300000, defaults.reference_range_m);
    p.track_revisit_s = bounded(p.track_revisit_s, .02, 6, defaults.track_revisit_s);
    p.track_memory_s = bounded(p.track_memory_s, 1, 30, defaults.track_memory_s);
    p.range_error_m = bounded(p.range_error_m, 1, 1000, defaults.range_error_m);
    p.angular_error_rad = bounded(p.angular_error_rad, .001 * degree, degree, defaults.angular_error_rad);
    p.minimum_track_dwell_s = bounded(p.minimum_track_dwell_s, .001, p.dwell_s, defaults.minimum_track_dwell_s);
    p.fire_control_revisit_s = bounded(p.fire_control_revisit_s, .008, 6, defaults.fire_control_revisit_s);
    p.gun_revisit_s = bounded(p.gun_revisit_s, .008, 6, defaults.gun_revisit_s);
    p.support_revisit_s = bounded(p.support_revisit_s, .008, 6, defaults.support_revisit_s);
    return p;
}
Vector direction(const Pose& p, double azimuth, double elevation) noexcept {
    const double horizontal = std::cos(elevation);
    return p.forward * (horizontal * std::cos(azimuth)) + p.right * (horizontal * std::sin(azimuth))
        + p.up * std::sin(elevation);
}
void body_angles(Vector delta, const Pose& pose, double& azimuth, double& elevation) noexcept {
    const double forward = dot(delta, pose.forward), right = dot(delta, pose.right);
    azimuth = std::atan2(right, forward);
    elevation = std::atan2(dot(delta, pose.up), std::hypot(forward, right));
}
bool valid_cue(const Controls& c) noexcept {
    const std::array values{c.cue_azimuth,c.cue_elevation,c.cue_half_azimuth,c.cue_half_elevation,c.cue_range_m};
    for (double value : values) if (!std::isfinite(value)) return false;
    return std::abs(c.cue_azimuth) <= 60*degree && std::abs(c.cue_elevation) <= 60*degree
        && c.cue_half_azimuth >= .001*degree && c.cue_half_azimuth <= 60*degree
        && c.cue_half_elevation >= .001*degree && c.cue_half_elevation <= 60*degree
        && c.cue_range_m >= 40 && c.cue_range_m <= 160*1852;
}
std::uint32_t central_cell(std::uint32_t index, std::uint32_t count) noexcept {
    const auto middle = (count-1)/2;
    return index%2 == 1 ? middle+(index+1)/2 : middle-index/2;
}
std::uint32_t grid_angles(double center_azimuth, double center_elevation, double half_azimuth,
                 double half_elevation, double beam, std::uint32_t& cell, double& azimuth, double& elevation, bool central = false) noexcept {
    const auto columns = static_cast<std::uint32_t>(std::ceil(half_azimuth / (beam*.7)));
    const auto rows = static_cast<std::uint32_t>(std::ceil(half_elevation / (beam*.7)));
    const auto count = std::clamp(columns*rows, 1u, 8192u);
    const auto index = cell % count;
    const auto tile = index % 2 == 0 ? index/2 : count - 1 - index/2;
    const auto column = central ? central_cell(index%columns,columns) : tile%columns;
    const auto row = central ? central_cell(index/columns,rows) : tile/columns;
    azimuth = center_azimuth - half_azimuth + (column + .5)*2*half_azimuth/columns;
    elevation = center_elevation - half_elevation + (row + .5)*2*half_elevation/rows;
    cell = (cell+1)%count;
    return count;
}
bool active_inputs(double now, const Controls& c, const Pose& pose) noexcept {
    return std::isfinite(now) && c.enabled && c.emit && valid_controls(c) && valid_pose(pose);
}
bool valid_truth(const Truth& truth) noexcept {
    return truth.id && finite(truth.position) && finite(truth.velocity)
        && std::isfinite(truth.cross_section_m2) && truth.cross_section_m2 > 0;
}
bool priority_angles(const Measurement& track, const Pose& pose, double now,
                     double& azimuth, double& elevation) noexcept {
    const auto predicted = track.position + track.velocity * (track.velocity_valid ? now - track.time : 0);
    body_angles(predicted - pose.position, pose, azimuth, elevation);
    return std::abs(azimuth) <= 60 * degree && std::abs(elevation) <= 60 * degree;
}
}
Model::Model(Policy policy) noexcept : policy_(checked(policy)) { reset(); }
void Model::reset(std::uint64_t generation) noexcept {
    for(auto& track:tracks_) track={};
    for(auto& pending:pending_) pending={};
    for(auto& filter:filters_) filter.reset();
    bindings_.fill({});
    // Track numbers never reuse a retired number during this model lifetime.
    // A generation reset retires all public consumers separately.
    last_priority_look_.fill(-100);
    cue_cell_ = 0; cue_turn_ = 0; surface_turn_=0;
    status_ = {}; previous_ = {};
    clock_ = -1; next_start_ = 0; priority_run_s_ = 0; cell_ = 0; turn_ = 0; surface_cell_ = 0; array_turn_ = 0; candidate_cursor_ = 0; generation_ = generation;
    random_ = 0x1a2b3c4d ^ static_cast<std::uint32_t>(generation);
    if (!random_) random_ = 1;
}
double Model::uniform() noexcept {
    random_ ^= random_ << 13; random_ ^= random_ >> 17; random_ ^= random_ << 5;
    return (static_cast<double>(random_) + .5) / 4294967296.0;
}
double Model::error(double sigma) noexcept { return (uniform() + uniform() + uniform() - 1.5) * 2 * sigma; }
bool Model::configuration_changed(const Controls& c) const noexcept {
    return c.azimuth != previous_.azimuth || c.elevation != previous_.elevation
        || c.half_azimuth != previous_.half_azimuth || c.half_elevation != previous_.half_elevation
        || c.range_m != previous_.range_m || c.surface != previous_.surface;
}
Measurement* Model::find(std::uint32_t id) noexcept {
    for (auto& t : tracks_) if (t.valid && t.id == id) return &t;
    return nullptr;
}
void Model::age(double now) noexcept {
    status_.tracks = 0;
    for (auto& t : tracks_) {
        if (t.valid && now - t.time > policy_.track_memory_s) {
            bindings_[static_cast<std::size_t>(&t-tracks_.data())] = {};
            t = {};
        }
        if (t.valid) ++status_.tracks;
    }
}
bool Model::assimilate(Pending& pending, Measurement& target) noexcept {
    auto& filter = filters_[static_cast<std::size_t>(&target - tracks_.data())];
    if (!target.valid) {
        filter.reset();
        last_priority_look_[static_cast<std::size_t>(&target-tracks_.data())]=-100;
    }
    if (!filter.observe(pending.sample)) return false;
    auto& value = pending.value;
    const auto& state = filter.state();
    value.raw_position = value.position;
    value.position = {state.position[0],state.position[1],state.position[2]};
    value.velocity = {state.velocity[0],state.velocity[1],state.velocity[2]};
    value.hits = state.hits; value.velocity_valid = state.velocity_valid;
    double pos=0,vel=0;
    for(std::size_t i=0;i<3;++i){pos=std::max(pos,state.covariance[i][i]);vel=std::max(vel,state.covariance[i+3][i+3]);}
    value.position_sigma_m=std::sqrt(pos);value.velocity_sigma_mps=std::sqrt(vel);
    value.filter_valid=state.valid;
    std::size_t index=0;
    for(std::size_t i=0;i<6;++i)for(std::size_t j=i;j<6;++j)value.covariance[index++]=state.covariance[i][j];
    target = value;
    return true;
}
void Model::withdraw(std::size_t index) noexcept {
    tracks_[index].association_valid = false;
    bindings_[index].qualified = false;
    bindings_[index].hits = 0;
}
void Model::commit(Pending& report, std::size_t index) noexcept {
    auto& track = tracks_[index];
    const auto id = track.valid ? track.id : next_track_;
    if (!track.valid) {
        if (next_track_ >= 16000000) { ++status_.association_dropped; return; }
        ++next_track_;
    }
    report.value.id = id;
    report.value.association_valid = true;
    if (!assimilate(report,track)) { withdraw(index); ++status_.association_dropped; return; }
    auto& binding = bindings_[index];
    if (binding.track != id || binding.host != report.host) binding = {id,report.host,0,false};
    binding.hits = std::min(255u,binding.hits+1);
    binding.qualified = binding.host != 0 && binding.hits >= 3 && track.velocity_valid;
}
void Model::associate(std::span<Pending*> reports) noexcept {
    AesaAssociation::Assignment match{};
    std::array<bool,maximum_tracks> assigned{};
    for (std::size_t row=0;row<reports.size();++row)
        for (std::size_t column=0;column<tracks_.size();++column)
            if (tracks_[column].valid)
                match.offer(row,column,filters_[column].association_score(reports[row]->sample));
    for (std::size_t row=0;row<reports.size();++row) {
        const auto selected = match.selected(row);
        if (selected == AesaAssociation::none) continue;
        assigned[selected] = true;
        commit(*reports[row],selected);
    }
    for (std::size_t column=0;column<tracks_.size();++column)
        if (!assigned[column] && match.tracks[column].index != AesaAssociation::none) withdraw(column);
    for (std::size_t row=0;row<reports.size();++row) {
        if (match.selected(row) != AesaAssociation::none) continue;
        if (match.reports[row].index != AesaAssociation::none) { ++status_.association_ambiguous; continue; }
        birth(*reports[row]);
    }
}
void Model::birth(Pending& report) noexcept {
    bool overlap = false;
    for (std::size_t column=0;column<tracks_.size();++column)
        if (tracks_[column].valid && tracks_[column].time == report.sample.time
            && filters_[column].association_score(report.sample) <= AesaAssociation::gate) {
            overlap = true;
            withdraw(column);
        }
    if (overlap) { ++status_.association_ambiguous; return; }
    std::size_t free = 0;
    while (free<tracks_.size() && tracks_[free].valid) ++free;
    if (free<tracks_.size()) commit(report,free);
    else ++status_.queue_drops;
}
Model::Pending* Model::next_report(double now) noexcept {
    Pending* first = nullptr;
    for (auto& p : pending_)
        if (p.occupied && p.release <= now && (!first || p.value.time < first->value.time)) first = &p;
    return first;
}
std::size_t Model::batch_reports(Pending& first, double now, std::span<Pending*> reports) noexcept {
    std::size_t count = 0;
    for (auto& p : pending_)
        if (p.occupied && p.value.time == first.value.time && p.release <= now && count<reports.size())
            reports[count++] = &p;
    return count;
}
void Model::release(double now) noexcept {
    for (std::size_t batch=0;batch<maximum_pending;++batch) {
        auto* first = next_report(now);
        if (!first) break;
        std::array<Pending*,maximum_returns_per_dwell> reports{};
        const auto count = batch_reports(*first,now,reports);
        associate(std::span<Pending*>(reports.data(),count));
        for (std::size_t row=0;row<count;++row) reports[row]->occupied = false;
    }
    status_.pending = 0;
    for (const auto& p : pending_) if (p.occupied) ++status_.pending;
}

namespace {
bool valid_surface_request(const SurfaceRequest& request) noexcept {
    return request.valid && finite(request.direction) && std::isfinite(request.range_m)
        && request.range_m >= 40 && request.range_m <= 160*1852
        && std::isfinite(request.center_elevation) && std::isfinite(request.half_elevation)
        && std::abs(request.center_elevation) <= 60*degree
        && request.half_elevation >= .001*degree && request.half_elevation <= 30*degree;
}
Vector level_direction(const Pose& pose,double azimuth,double elevation) noexcept {
    const double heading=std::atan2(pose.forward.e,pose.forward.n)+azimuth;
    return {std::cos(heading)*std::cos(elevation),std::sin(elevation),std::sin(heading)*std::cos(elevation)};
}
}
void Model::start_surface(double now, const Controls& c, const Pose& pose) noexcept {
    const auto& requested=c.surface_request;
    const bool qualified=valid_surface_request(requested);
    const double half=std::clamp(c.surface_half_azimuth,degree,60*degree);
    double azimuth=0,elevation=0;
    const double center=qualified ? requested.center_elevation : -30*degree;
    const double vertical=qualified ? requested.half_elevation : 29*degree;
    const bool pointed=qualified&&requested.point&&(!requested.routine||surface_turn_%4==1)
        &&std::abs(length(requested.direction)-1)<.002;
    surface_turn_=(surface_turn_+1)%4;
    Vector ray{};
    std::uint32_t cells=0;
    if(pointed)ray=requested.direction;
    else {
        cells=grid_angles(0,center,half,vertical,policy_.beam_half_angle,surface_cell_,azimuth,elevation);
        ray=level_direction(pose,azimuth,elevation);
    }
    body_angles(ray,pose,azimuth,elevation);
    if (std::abs(azimuth)>60*degree || std::abs(elevation)>60*degree) {
        // An unreachable request consumes no off-aircraft observation.
        ray=direction(pose,std::clamp(azimuth,-60*degree,60*degree),std::clamp(elevation,-60*degree,60*degree));
        body_angles(ray,pose,azimuth,elevation);
    }
    const double range=qualified ? requested.range_m : c.range_m;
    status_.beam={ray,policy_.beam_half_angle,range,now,now+policy_.dwell_s/c.resource,azimuth,elevation,0,false,true};
    status_.beam.surface_search=!pointed;status_.beam.surface_cells=cells;
    status_.dwelling=true;
}

double Model::revisit(std::uint32_t id, std::size_t priority, const Controls& c) const noexcept {
    if (id == c.fire_control_id) return c.gun_tracking ? policy_.gun_revisit_s : policy_.fire_control_revisit_s;
    return priority >= 2 ? policy_.support_revisit_s : policy_.track_revisit_s;
}
double Model::track_dwell(const Measurement& target, const Pose& pose) const noexcept {
    const auto delta = target.position - pose.position;
    double azimuth = 0, elevation = 0;
    body_angles(delta, pose, azimuth, elevation);
    const double gain = std::max(.1, std::cos(azimuth) * std::cos(elevation));
    const double ratio = length(delta) / policy_.reference_range_m;
    // Schedule from measured geometry and a declared 1m2 scheduling estimate.
    // Short close-range looks buy agility with less integrated signal energy.
    const double effort = 4 * ratio * ratio * ratio * ratio / (gain * gain);
    return std::clamp(policy_.dwell_s * effort, policy_.minimum_track_dwell_s, policy_.dwell_s);
}
Model::Task Model::priority_task(double now, const Controls& c, const Pose& pose) noexcept {
    Task next{};
    const double search_duration = policy_.dwell_s / c.resource;
    if (priority_run_s_ >= 3 * search_duration) return next;
    for (std::size_t priority = 0; priority < c.priority_ids.size(); ++priority) {
        auto* target = c.priority_ids[priority] ? find(c.priority_ids[priority]) : nullptr;
        if (!target) continue;
        const auto index = static_cast<std::size_t>(target - tracks_.data());
        const double last = std::max(target->time, last_priority_look_[index]);
        const double deadline = last + revisit(target->id, priority, c);
        const double dwell = track_dwell(*target, pose) / c.resource;
        if (priority_run_s_ + dwell > 3 * search_duration) continue;
        // Do not start a long search dwell that would cross a track's latest
        // start. Service slightly early instead of inserting a second wait.
        if (now + search_duration < deadline - dwell) continue;
        if (!next.track || deadline < next.deadline) next = {target, dwell, deadline};
    }
    return next;
}
bool Model::search_angles(const Controls& c, double& azimuth, double& elevation) noexcept {
    const bool cued = c.cue_valid && valid_cue(c) && cue_turn_ == 1;
    cue_turn_ = (cue_turn_+1)%4;
    if (cued) {
        const double az = std::clamp(c.cue_azimuth, -60*degree+c.cue_half_azimuth, 60*degree-c.cue_half_azimuth);
        const double el = std::clamp(c.cue_elevation, -60*degree+c.cue_half_elevation, 60*degree-c.cue_half_elevation);
        grid_angles(az, el, c.cue_half_azimuth, c.cue_half_elevation,
            policy_.beam_half_angle, cue_cell_, azimuth, elevation, true);
    } else grid_angles(c.azimuth, c.elevation, c.half_azimuth, c.half_elevation,
        policy_.beam_half_angle, cell_, azimuth, elevation);
    return cued;
}
void Model::start(double now, const Controls& c, const Pose& pose) noexcept {
    const bool surface_job = c.surface && array_turn_ % 3 != 0;
    array_turn_ = (array_turn_ + 1) % 3;
    if (surface_job) { start_surface(now, c, pose); return; }
    auto task = priority_task(now, c, pose);
    double azimuth = 0, elevation = 0;
    if (task.track && !priority_angles(*task.track, pose, now, azimuth, elevation)) task = {};
    const bool cued = !task.track && search_angles(c, azimuth, elevation);
    azimuth = std::clamp(azimuth, -60 * degree, 60 * degree);
    elevation = std::clamp(elevation, -60 * degree, 60 * degree);
    const double duration = task.track ? task.dwell : policy_.dwell_s / c.resource;
    const double search_range = cued ? std::max(c.range_m,c.cue_range_m) : c.range_m;
    const double range = task.track ? std::min(160 * 1852.0,
        std::max(c.range_m, length(task.track->position - pose.position) * 1.15)) : search_range;
    status_.beam = {direction(pose, azimuth, elevation), policy_.beam_half_angle, range, now,
        now + duration, azimuth, elevation, task.track ? task.track->id : 0, task.track != nullptr,
        false, task.deadline, duration * c.resource, cued, cued ? c.cue_request : 0};
    status_.dwelling = true;
    turn_ = (turn_ + 1) % 4;
}
void Model::queue(double now, const Pose& pose, const Truth& truth, double signal) noexcept {
    Pending* slot = nullptr;
    for (auto& p : pending_) if (!p.occupied) { slot = &p; break; }
    if (!slot) { ++status_.queue_drops; return; }
    const auto delta = truth.position - pose.position;
    const double range = length(delta), quality = std::sqrt(std::clamp(signal, .25, 16.0));
    double azimuth = 0, elevation = 0;
    body_angles(delta, pose, azimuth, elevation);
    const double sigma_r = (policy_.range_error_m + range * .0002) / quality;
    const double sigma_a = policy_.angular_error_rad / quality;
    const double measured_az=azimuth+error(sigma_a), measured_el=elevation+error(sigma_a);
    const double measured_range=std::max(40.0,range+error(sigma_r));
    const auto measured=pose.position+direction(pose,measured_az,measured_el)*measured_range;
    // Doppler is a scalar LOS observation. Cartesian target velocity remains
    // private environmental truth and never enters a weapon/track report.
    // Less coherent observation time also reduces Doppler precision, even
    // when close-range signal strength has reached the noise model's cap.
    const double coherence_ratio = policy_.dwell_s / status_.beam.integration_s;
    const double sigma_rate = std::max(.25, coherence_ratio / quality);
    const double range_rate=dot(truth.velocity-pose.velocity,delta)/range+error(sigma_rate);
    slot->value={0,1,measured,{},now,sigma_r,sigma_a,true,false};
    slot->host = truth.id;
    slot->value.measured_range=measured_range;slot->value.measured_azimuth=measured_az;
    slot->value.measured_elevation=measured_el;slot->value.measured_range_rate=range_rate;
    slot->value.rate_sigma_mps=sigma_rate;
    slot->value.sensor_origin=pose.position;slot->value.sensor_velocity=pose.velocity;
    slot->value.sensor_forward=pose.forward;slot->value.sensor_up=pose.up;slot->value.sensor_right=pose.right;
    slot->sample={{pose.position.n,pose.position.u,pose.position.e},{pose.velocity.n,pose.velocity.u,pose.velocity.e},
        {pose.forward.n,pose.forward.u,pose.forward.e},{pose.up.n,pose.up.u,pose.up.e},
        {pose.right.n,pose.right.u,pose.right.e},now,measured_range,measured_az,measured_el,
        range_rate,sigma_r,sigma_a,sigma_rate,true};
    slot->release = now + policy_.processing_s / status_.resource;
    slot->occupied = true;
    ++status_.detections;
    ++status_.pending;
}
void Model::detect(double now, const Controls& c, const Pose& pose, const Truth& truth,
                  QueryStats& stats, Environment& environment) noexcept {
    const auto delta = truth.position - pose.position;
    const double range = length(delta);
    if (!valid_truth(truth)) { ++status_.invalid; return; }
    if (range < 40 || range > status_.beam.range_m || dot(delta, status_.beam.direction) < range * std::cos(status_.beam.half_angle)) return;
    double azimuth = 0, elevation = 0;
    body_angles(delta, pose, azimuth, elevation);
    if (std::abs(azimuth) > 60 * degree || std::abs(elevation) > 60 * degree) return;
    const double gain = std::max(.1, std::cos(azimuth) * std::cos(elevation));
    const double ratio = policy_.reference_range_m / range;
    double signal = ratio * ratio * ratio * ratio * std::clamp(truth.cross_section_m2, .01, 100.0)
        * gain * gain * c.resource * status_.beam.integration_s / policy_.dwell_s;
    // Ground clutter shares the platform's Doppler shift. Compare the target
    // with the stationary surface centroid, not with zero relative velocity.
    // Width35m/s and attenuation0.15 remain declared game estimates.
    const double target_rate = dot(truth.velocity - pose.velocity, delta) / range;
    const double clutter_rate = -dot(pose.velocity, delta) / range;
    if (delta.u < 0 && std::abs(target_rate-clutter_rate) < 35) signal *= .15;
    if (signal < .2) { ++status_.misses; return; }
    if (stats.visibility_queries >= maximum_visibility_queries) { stats.truncated = true; return; }
    ++stats.visibility_queries;
    if (!environment.visible(pose, truth, stats)) { ++status_.misses; return; }
    const double probability = std::min(.99, signal / (1 + signal));
    if (uniform() > probability) { ++status_.misses; return; }
    queue(now, pose, truth, signal);
}
void Model::completed_look(double now, const Controls& c) noexcept {
    if (status_.beam.cued) {
        status_.cue_request = status_.beam.cue_request; status_.cue_time = now; ++status_.cue_dwells;
    }
    if (status_.beam.priority) {
        priority_run_s_ += now - status_.beam.started;
        if (const auto* track = find(status_.beam.task_source))
            last_priority_look_[static_cast<std::size_t>(track - tracks_.data())] = now;
        if (now > status_.beam.deadline + 1e-9) ++status_.deadline_misses;
        if (status_.beam.task_source == c.fire_control_id) status_.fire_control_last_look = now;
    } else priority_run_s_ = 0;
}
void Model::observe(double now, const Controls& c, const Pose& pose, Environment& environment) noexcept {
    if (status_.beam.surface) {
        status_.surface_service = true;
        status_.surface_beam = status_.beam;
        status_.surface_beam.completes=now;
        const double heading=std::atan2(pose.forward.e,pose.forward.n);
        status_.surface_azimuth=std::remainder(std::atan2(status_.beam.direction.e,status_.beam.direction.n)-heading,2*pi);
        ++status_.surface_sequence; ++status_.dwells; status_.dwelling = false;
        return;
    }
    std::size_t count = 0;
    QueryStats stats{};
    if (!environment.query(pose, status_.beam, candidates_, count, stats) || count > candidates_.size()) {
        status_.ready = false; status_.dwelling = false; return;
    }
    const auto before = status_.detections;
    completed_look(now, c);
    for (std::size_t i = 0; i < count; ++i) {
        if (status_.detections - before >= maximum_returns_per_dwell) { stats.truncated = true; break; }
        const auto index = (candidate_cursor_ + i) % count;
        detect(now, c, pose, candidates_[index], stats, environment);
    }
    if (count) candidate_cursor_ = (candidate_cursor_ + maximum_returns_per_dwell) % static_cast<std::uint32_t>(count);
    status_.truncated = stats.truncated;
    status_.terrain_blocked += stats.terrain_blocked;
    status_.object_blocked += stats.object_blocked;
    ++status_.dwells;
    if (status_.beam.priority) ++status_.track_dwells; else ++status_.search_dwells;
    status_.dwelling = false;
    next_start_ = now;
}
void Model::reduce_resource(double now, const Controls& c) noexcept {
    if (clock_ < 0 || c.resource >= previous_.resource) return;
    const double ratio = previous_.resource / c.resource;
    if (status_.dwelling)
        status_.beam.completes = now + std::max(0.0, status_.beam.completes - now) * ratio;
    for (auto& pending : pending_) if (pending.occupied && pending.release > now)
        pending.release = now + (pending.release - now) * ratio;
}
bool Model::prepare(double now, const Controls& c) noexcept {
    if (generation_ != c.generation || (clock_ >= 0 && (now < clock_ || now - clock_ > .5))) reset(c.generation);
    if (clock_ == now) { status_.surface_service = false; return false; }
    if (configuration_changed(c)) { status_.dwelling = false; cell_ = 0; next_start_ = now; }
    reduce_resource(now, c);
    if (c.cue_request != previous_.cue_request) cue_cell_ = 0;
    clock_ = now; previous_ = c;
    status_.ready = true; status_.emitting = true; status_.time = now; status_.resource = c.resource;
    status_.processing_s = policy_.processing_s / c.resource;
    status_.surface_service = false;
    if (status_.fire_control_id != c.fire_control_id) status_.fire_control_last_look = -100;
    status_.fire_control_id = c.fire_control_id;
    status_.fire_control_revisit_s = c.fire_control_id ? revisit(c.fire_control_id, 0, c) : 0;
    return true;
}
bool Model::update(double now, const Controls& c, const Pose& pose, Environment& environment) noexcept {
    if (!active_inputs(now, c, pose)) { reset(c.generation); return false; }
    if (!prepare(now, c)) return status_.ready;
    age(now); release(now);
    if (status_.dwelling && now >= status_.beam.completes) observe(now, c, pose, environment);
    if (!status_.ready) return false;
    if (!status_.dwelling && now >= next_start_) start(now, c, pose);
    return true;
}
}

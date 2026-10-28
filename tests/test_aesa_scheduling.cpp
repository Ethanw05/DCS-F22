// Finite RF service under close engagement, scan load and host-clock quantization.
#include "../EFM/source/AesaRadar.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <iostream>
#include <stdexcept>
#define CHECK(x) do { if (!(x)) throw std::runtime_error(#x); } while (false)
using namespace AesaRadar;
namespace {
struct Scene final : Environment {
    std::array<Truth, 10> objects{};
    std::size_t count = 1;
    bool blocked{};
    Scene() {
        for (std::size_t i = 0; i < objects.size(); ++i) {
            const double angle = (-45 + 10 * static_cast<double>(i)) * degree;
            objects[i] = {static_cast<unsigned>(42 + i), {800 * std::cos(angle), 3000,
                800 * std::sin(angle)}, {}, 1};
        }
    }
    bool query(const Pose&, const Beam&, std::span<Truth> out, std::size_t& n, QueryStats&) noexcept override {
        n = count;
        std::copy_n(objects.begin(), count, out.begin());
        return true;
    }
    bool visible(const Pose&, const Truth&, QueryStats&) noexcept override { return !blocked; }
};
struct Observations {
    double previous = -100, total_gap{}, maximum_gap{}, maximum_age{};
    unsigned reports{};
    void sample(const Measurement& m, double now) {
        if (!m.valid || !m.velocity_valid || now < 1) return;
        maximum_age = std::max(maximum_age, now - m.time);
        if (m.time <= previous) return;
        if (previous >= 0) {
            const double gap = m.time - previous;
            total_gap += gap;
            maximum_gap = std::max(maximum_gap, gap);
        }
        previous = m.time;
        ++reports;
    }
};
void engagement(double callback, bool gun, bool jitter = false) {
    static Model radar;
    radar.reset();
    Scene world;
    world.objects[0].position = {800, 3000, 0};
    Pose pose{}; pose.position.u = 3000;
    Controls c{}; c.enabled = true; c.half_azimuth = degree; c.half_elevation = degree;
    Observations seen{};
    double search_time = 0, track_time = 0, now = 0;
    bool short_report = false;
    for (unsigned i = 0; i < static_cast<unsigned>(6 / callback); ++i,
         now += callback * (jitter ? 1 + .25 * std::sin(i * .7) : 1)) {
        if (jitter) {
            world.objects[0].position.e = 80 * std::sin(now * .5);
            world.objects[0].velocity.e = 40 * std::cos(now * .5);
        }
        if (now >= .3) {
            c.priority_ids[0] = radar.measurements()[0].id; c.fire_control_id = c.priority_ids[0]; c.gun_tracking = gun;
            c.half_azimuth = 60 * degree; c.half_elevation = 10 * degree;
        }
        const auto beam = radar.status().beam;
        const auto dwells = radar.status().dwells;
        CHECK(radar.update(now, c, pose, world));
        if (now > 1 && radar.status().dwells != dwells) {
            if (beam.priority) track_time += now - beam.started;
            else search_time += now - beam.started;
        }
        seen.sample(radar.measurements()[0], now);
        if (radar.measurements()[0].rate_sigma_mps > 1) short_report = true;
        CHECK(radar.status().pending <= maximum_pending);
    }
    const double mean = seen.total_gap / (seen.reports - 1);
    CHECK(seen.reports > 40 && mean < .1 && seen.maximum_age < .15);
    CHECK(search_time > 0 && track_time > 0 && short_report);
    CHECK(radar.status().fire_control_revisit_s == (gun ? .025 : .05));
    std::cout << (gun ? "Gun" : "STT") << " callback=" << callback << " reports=" << seen.reports
        << " mean_gap=" << mean << " max_gap=" << seen.maximum_gap
        << " max_age=" << seen.maximum_age << " jitter=" << jitter << " search_fraction=" << search_time / (search_time + track_time) << '\n';
}
void saturated() {
    static Model radar;
    radar.reset();
    Scene world; world.count = 10;
    Pose pose{}; pose.position.u = 3000;
    Controls c{}; c.enabled = true; c.half_azimuth = degree; c.half_elevation = degree;
    double now = 0;
    constexpr double step = 1.0 / 240;
    for (std::size_t target = 0; target < world.count; ++target) {
        c.azimuth = (-45 + 10 * static_cast<double>(target)) * degree;
        for (unsigned i = 0; i < 48; ++i) { radar.update(now, c, pose, world); now += step; }
    }
    for (const auto& t : radar.measurements()) if (t.valid) CHECK(t.velocity_valid);
    c.azimuth = 0; c.half_azimuth = 60 * degree; c.half_elevation = 10 * degree;
    c.fire_control_id = radar.measurements()[0].id; c.gun_tracking = true;
    for (std::size_t i=0;i<10;++i) c.priority_ids[i] = radar.measurements()[i].id;
    std::array<double, 10> last{}, gap{};
    std::array<unsigned, 10> count{};
    double search_time = 0, track_time = 0;
    for (unsigned i = 0; i < 2400; ++i, now += step) {
        const auto beam = radar.status().beam;
        const auto dwells = radar.status().dwells;
        CHECK(radar.update(now, c, pose, world));
        if (i < 240 || radar.status().dwells == dwells) continue;
        if (!beam.priority) { search_time += now - beam.started; continue; }
        track_time += now - beam.started;
        const auto index = beam.task_source - radar.measurements()[0].id;
        CHECK(index < count.size());
        if (count[index]++) gap[index] = std::max(gap[index], now - last[index]);
        last[index] = now;
    }
    for (std::size_t i = 0; i < count.size(); ++i) { CHECK(count[i] > 20); CHECK(gap[i] < .4); }
    CHECK(search_time / (search_time + track_time) > .23);
    CHECK(radar.status().deadline_misses > 0); // Overload is visible, never a fabricated on-time report.
    std::cout << "Ten targets: gun looks=" << count[0] << " worst gap=" << *std::max_element(gap.begin(), gap.end())
        << " search_fraction=" << search_time / (search_time + track_time)
        << " deadline_misses=" << radar.status().deadline_misses << '\n';
}
void degraded() {
    static Model radar;
    radar.reset();
    Scene world; world.objects[0].position = {800, 3000, 0};
    Pose pose{}; pose.position.u = 3000;
    Controls c{}; c.enabled = true; c.half_azimuth = degree; c.half_elevation = degree;
    c.fire_control_id = 1; c.gun_tracking = true; c.priority_ids[0] = 1;
    for (unsigned i = 0; i < 480; ++i) radar.update(i / 240.0, c, pose, world);
    world.blocked = true;
    // Previously sensed returns may finish processing after visibility is lost.
    for (unsigned i = 480; i < 490; ++i) radar.update(i / 240.0, c, pose, world);
    const auto stamp = radar.measurements()[0].time;
    CHECK(stamp < 2);
    for (unsigned i = 490; i < 600; ++i) radar.update(i / 240.0, c, pose, world);
    CHECK(radar.measurements()[0].time == stamp);
    const auto looks = radar.status().track_dwells;
    radar.update(599 / 240.0, c, pose, world); CHECK(radar.status().track_dwells == looks);
    c.resource = .25;
    radar.update(2.5, c, pose, world);
    CHECK(radar.status().processing_s == .048);
    radar.update(4, c, pose, world); CHECK(!radar.measurements()[0].valid);
    CHECK(radar.status().dwells == 0); // No historical catch-up after a stalled host.
    c.resource = 1; c.surface = true;
    bool granted = false;
    for (unsigned i = 0; i < 100; ++i) {
        const double time = 4.01 + i / 240.0;
        radar.update(time, c, pose, world);
        if (!radar.status().surface_service) continue;
        granted = true;
        const auto sequence = radar.status().surface_sequence;
        radar.update(time, c, pose, world);
        CHECK(!radar.status().surface_service && radar.status().surface_sequence == sequence);
        break;
    }
    CHECK(granted);
}
void cued_search() {
    static Model radar;
    radar.reset();
    Scene world;
    Pose pose{}; pose.position.u = 3000;
    const double az = 40*degree, el = 25*degree;
    world.objects[0].position = {800*std::cos(el)*std::cos(az),
        3000+800*std::sin(el),800*std::cos(el)*std::sin(az)};
    Controls c{}; c.enabled = true;
    c.cue_valid = true; c.cue_azimuth = az; c.cue_elevation = el;
    c.cue_half_azimuth = 6*degree; c.cue_half_elevation = 6*degree; c.cue_request = 22; c.range_m = 500; c.cue_range_m = 1000;
    double left = 1, right = -1, low = 1, high = -1;
    unsigned cued = 0, background = 0;
    for (unsigned i = 0; i < 480; ++i) {
        const auto beam = radar.status().beam;
        const auto dwells = radar.status().dwells;
        CHECK(radar.update(i/240.0,c,pose,world));
        if (radar.status().dwells == dwells) continue;
        if (!beam.cued) { ++background; continue; }
        ++cued;
        left = std::min(left,beam.azimuth); right = std::max(right,beam.azimuth);
        low = std::min(low,beam.elevation); high = std::max(high,beam.elevation);
    }
    CHECK(cued > 10 && background >= 3*cued-1);
    CHECK(right-left > 5*degree && high-low > 5*degree);
    CHECK(radar.measurements()[0].valid && radar.measurements()[0].id > 0 && radar.measurements()[0].id != 42);
    CHECK(radar.status().cue_request == 22 && radar.status().cue_time > 0);
    // A malformed cue cannot replace or disable ordinary search.
    c.cue_half_azimuth = std::numeric_limits<double>::quiet_NaN();
    const auto previous = radar.status().cue_dwells;
    for (unsigned i = 480; i < 600; ++i) CHECK(radar.update(i/240.0,c,pose,world));
    CHECK(radar.status().cue_dwells <= previous+1); // Only an already-started valid look may finish.
}
}
int main() {
    try {
        engagement(1.0 / 240, true); engagement(1.0 / 60, true); engagement(1.0 / 240, false);
        engagement(1.0 / 240, true, true); saturated(); degraded(); cued_search();
        return 0;
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}

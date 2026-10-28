#include "../EFM/source/AesaRadar.h"
#include <cmath>
#include <iostream>
#include <stdexcept>
#define CHECK(x) do { if (!(x)) throw std::runtime_error(#x); } while (false)
using namespace AesaRadar;
struct World final : Environment {
    std::array<Truth, 128> objects{};
    std::size_t count = 1;
    bool blocked{}, fail{};
    unsigned queries{}, visibility{};
    World() { objects[0] = {42, {20000, 3000, 0}, {0, 0, 0}, 1}; }
    bool query(const Pose&, const Beam&, std::span<Truth> out, std::size_t& size, QueryStats&) noexcept override {
        ++queries; size = count;
        for (std::size_t i = 0; i < count && i < out.size(); ++i) out[i] = objects[i];
        return !fail;
    }
    bool visible(const Pose&, const Truth&, QueryStats& stats) noexcept override {
        ++visibility;
        if (blocked) ++stats.terrain_blocked;
        return !blocked;
    }
};
int scenarios() {
    Pose pose{}; pose.position.u = 3000; pose.velocity.n = 0;
    Controls c{}; c.enabled = true; c.half_azimuth = degree; c.half_elevation = degree;
    static World world; Policy delayed{}; delayed.processing_s = .06; static Model radar(delayed);
    CHECK(radar.update(0, c, pose, world));
    CHECK(world.queries == 0 && radar.status().dwelling);
    CHECK(radar.update(.02, c, pose, world)); CHECK(world.queries == 1);
    CHECK(!radar.measurements()[0].valid);
    CHECK(radar.update(.079, c, pose, world)); CHECK(!radar.measurements()[0].valid);
    CHECK(radar.update(.08, c, pose, world));
    const auto first = radar.measurements()[0];
    CHECK(first.valid && first.id != 42 && first.id > 0 && first.time == .02);
    CHECK(length(first.position - world.objects[0].position) > .001);
    CHECK(first.range_sigma_m > 0 && first.angle_sigma_rad > 0 && !first.velocity_valid);
    const auto queries = world.queries;
    radar.update(.08, c, pose, world); CHECK(world.queries == queries);
    // Pointing is an electronic command step; sensing remains timed.
    c.azimuth = 55 * degree; radar.update(.081, c, pose, world);
    CHECK(std::abs(radar.status().beam.azimuth - 55 * degree) < 1e-9);
    CHECK(radar.measurements()[0].time <= .081);
    for (int i = 1; i <= 30; ++i) radar.update(.081 + i * .02, c, pose, world);
    CHECK(radar.measurements()[0].time <= .081);
    // No off-beam observation is created even though the provider contains it.
    CHECK(radar.status().detections < radar.status().dwells);
    c.azimuth = 0; world.blocked = true;
    for (int i = 1; i <= 30; ++i) radar.update(.7 + i * .02, c, pose, world);
    CHECK(radar.status().terrain_blocked > 0);
    CHECK(radar.measurements()[0].time <= .081);
    c.resource = 0; CHECK(!radar.update(1.4, c, pose, world));
    CHECK(!radar.measurements()[0].valid);
    c.resource = .25; world.blocked = false;
    radar.update(1.41, c, pose, world);
    CHECK(std::abs(radar.status().beam.completes - 1.49) < 1e-9);
    CHECK(!radar.measurements()[0].valid);
    // Stalls, rewinds and provider failures cannot replay old measurements.
    radar.update(3, c, pose, world); CHECK(!radar.measurements()[0].valid);
    radar.update(1, c, pose, world); CHECK(!radar.measurements()[0].valid);
    world.fail = true; CHECK(!radar.update(1.1, c, pose, world));
    c.resource = 1; world.fail = false; c.generation = 2;
    c.half_azimuth = 60 * degree; c.half_elevation = 10 * degree;
    static Model coverage; static World empty; empty.count = 0;
    double lo = 1, hi = -1;
    for (int i = 0; i < 300; ++i) {
        coverage.update(i * .021, c, pose, empty);
        lo = std::min(lo, coverage.status().beam.azimuth);
        hi = std::max(hi, coverage.status().beam.azimuth);
    }
    CHECK(lo < -50 * degree && hi > 50 * degree);
    CHECK(coverage.status().search_dwells >= 290);
    // A selected track gets finite revisits while discovery continues.
    c.half_azimuth = degree; c.half_elevation = degree; c.priority_ids[0] = 1;
    static Model tracking;
    for (int i = 0; i < 150; ++i) {
        if (i == 10) c.half_azimuth = 60 * degree;
        tracking.update(i * .021, c, pose, world);
    }
    CHECK(tracking.status().track_dwells > 0 && tracking.status().search_dwells > 0);
    CHECK(tracking.status().track_dwells>=20 && tracking.status().track_dwells<100);
    CHECK(tracking.measurements()[0].hits >= 2 && tracking.measurements()[0].velocity_valid);
    // Surface work consumes complete array dwells and leaves finite air service.
    static Model mixed;static World scene;scene.count=0;c.surface=true;
    unsigned grants=0;
    for(int i=0;i<100;++i){mixed.update(i*.021,c,pose,scene);if(mixed.status().surface_service)++grants;}
    CHECK(grants>=60&&grants<=67&&mixed.status().search_dwells>=30);
    CHECK(mixed.status().surface_sequence==grants);
    c.resource=.25;static Model limited;unsigned limited_grants=0;
    for(int i=0;i<100;++i){limited.update(i*.021,c,pose,scene);if(limited.status().surface_service)++limited_grants;}
    CHECK(limited_grants<grants/2&&limited_grants>0);
    c.resource=1;c.surface=false;
    // LOS work is bounded independently from successful detections.
    c.half_azimuth = degree; world.count = 128;
    for (std::size_t i = 0; i < world.count; ++i) world.objects[i] = {static_cast<unsigned>(i+1), {20000,3000,0}, {}, 1};
    world.blocked = true; static Model dense;
    dense.update(0,c,pose,world); const auto before = world.visibility;
    dense.update(.021,c,pose,world);
    CHECK(world.visibility-before <= maximum_visibility_queries && dense.status().truncated);
    world.blocked=false;static Model capacity(Policy{.005,2});
    for(int i=0;i<1000;++i)capacity.update(i*.006,c,pose,world);
    CHECK(capacity.status().queue_drops>0&&capacity.status().pending<=maximum_pending);
    unsigned count=0;for(const auto& t:capacity.measurements())if(t.valid)++count;
    CHECK(count>0&&count<=maximum_tracks);
    static Model store(Policy{.005,.001});
    for(int i=0;i<100;++i)store.update(i*.006,c,pose,world);
    count=0;for(const auto& t:store.measurements())if(t.valid)++count;
    CHECK(count>0 && count<maximum_tracks);
    CHECK(store.status().association_ambiguous>0); // Identical reports cannot produce64 perfectly separate targets.
    // Invalid policy values cannot create division-by-zero or an unbounded grid.
    static Model bad_policy(Policy{0,0,0});
    CHECK(bad_policy.update(0,c,pose,world)&&bad_policy.status().beam.completes>0);
    std::cout << "Owned AESA: scene truth gates, electronic point steps, dwell/processing, noisy reports, LOS, "
        "resource loss, search/track service, generations, pause and bounded work PASS\n";
    return 0;
}
void clutter_reference() {
    static std::array<Model,3> radars;
    World world;
    Pose pose{};pose.position.u=3000;pose.velocity.n=300;
    Controls controls{};controls.enabled=true;
    controls.half_azimuth=degree;controls.half_elevation=degree;
    std::array<unsigned,3> detections{};
    for (unsigned seed=1;seed<=512;++seed) {
        controls.generation=seed*0x9e3779b9ull;
        for (std::size_t scenario=0;scenario<radars.size();++scenario) {
            // Same range and seed: co-speed lookdown, ground-notched lookdown,
            // and clear-sky stationary target. Hidden identity is immaterial.
            world.objects[0].position={60000,scenario==2 ? 5000.0 : 1000.0,0};
            world.objects[0].velocity={scenario==0 ? 300.0 : 0,0,0};
            controls.elevation=std::atan2(world.objects[0].position.u-pose.position.u,60000);
            auto& radar=radars[scenario];radar.reset(controls.generation);
            CHECK(radar.update(0,controls,pose,world));
            CHECK(radar.update(.021,controls,pose,world));
            detections[scenario]+=radar.status().detections;
        }
    }
    std::cout<<"Clutter frame: co-speed="<<detections[0]<<" ground-notch="<<detections[1]
        <<" lookup="<<detections[2]<<" /512 seeded dwells\n";
    CHECK(detections[0]==detections[2]);
    CHECK(detections[0]>2*detections[1] && detections[1]>0);
}
int main() {
    try { const auto result=scenarios();clutter_reference();return result; }
    catch (const std::exception& error) { std::cerr << error.what() << "\n"; return 1; }
}

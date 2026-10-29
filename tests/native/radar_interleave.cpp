// Actual model plus native checked control/publication adapters. Test-owned
// environment and parameter storage do not qualify the private DCS callback ABI.
#include "../../EFM/source/NativeAesaRadar.cpp"
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <map>
#include <memory>
#include <sstream>
#include <string>

namespace NativeGroundSensor {
AesaRadar::SurfaceRequest pointing(double, const AesaRadar::Pose&) noexcept { return {}; }
void sample(void*, const ArrayService&) {}
}
namespace NativeGroundVideo {
void set_aircraft(const AesaRadar::Pose*, double) noexcept {}
}
namespace NativeIRST {
void sample() noexcept { std::abort(); }
void retire() noexcept { std::abort(); }
}
namespace {
using namespace AesaRadar;
void require(bool condition, const char* message) {
    if (!condition) { std::cerr << "FAIL: " << message << '\n'; std::exit(1); }
}
struct Scene final : Environment {
    double now{}, late_entry = 2;
    bool late = true, edge_initial{};
    unsigned air_queries{}, looks{};
    bool interference(double stamp, const Pose&, const Beam&, Interference& value, QueryStats&) noexcept override {
        now = stamp; value = {true, 0, stamp, 0}; ++looks; return true;
    }
    bool query(const Pose&, const Beam&, std::span<Truth> out, std::size_t& count, QueryStats&) noexcept override {
        ++air_queries; count = 1;
        out[0] = {701, {10000, 5000, 0}, {}, 1};
        if (edge_initial) out[0].position = {10000 * std::cos(55 * degree) * std::cos(8 * degree),
            5000 - 10000 * std::sin(8 * degree), -10000 * std::sin(55 * degree) * std::cos(8 * degree)};
        if (late && now >= late_entry) {
            out[1] = {902, {10000 * std::cos(20 * degree), 5000, 10000 * std::sin(20 * degree)}, {}, 1};
            count = 2;
        }
        return true;
    }
    bool visible(const Pose&, const Truth&, QueryStats&) noexcept override { return true; }
};
const Measurement* first(const Model& radar) {
    for (const auto& value : radar.measurements()) if (value.valid) return &value;
    return nullptr;
}
void priority_before_surface() {
    auto radar = std::make_unique<Model>();
    Scene scene; scene.late = false;
    Pose pose; pose.position.u = 5000;
    Controls controls; controls.enabled = true;
    controls.half_azimuth = controls.half_elevation = .001 * degree;
    controls.range_m = 20000;
    double latest_look = -100;
    bool tested = false;
    for (unsigned tick = 0; tick < 4000; ++tick) {
        const double now = tick * .001;
        const auto* report = first(*radar);
        if (report && report->hits >= 3) {
            controls.priority_ids[2] = report->id;
            latest_look = std::max(latest_look, report->time);
            const auto& before = radar->status();
            if (before.beam.priority) latest_look = std::max(latest_look, before.beam.completes);
            // Force a role transition when a measured support task is due and
            // the old job-count policy would otherwise choose a surface job.
            const double deadline = latest_look + .05;
            const bool due = now + .02 >= deadline - .004;
            if (now > .5 && due && (before.dwells + 1) % 3 != 0) {
                controls.surface = true;
                (void)radar->update(now, controls, pose, scene);
                require(radar->status().beam.priority && !radar->status().beam.surface,
                        "A/G discovery job preempted an already due measured air-support look");
                tested = true; break;
            }
        }
        const auto old = radar->status().beam;
        (void)radar->update(now, controls, pose, scene);
        if (old.priority && now >= old.completes) latest_look = now;
    }
    require(tested, "priority transition scenario never reached its independent due boundary");
    std::cout << "PASS measured due air support precedes routine surface discovery\n";
}
void finite_discovery_under_support() {
    for (double resource : {1.0, .25}) {
        auto radar = std::make_unique<Model>();
        Scene scene;
        Pose pose; pose.position.u = 5000;
        Controls controls; controls.enabled = controls.surface = true; controls.resource = resource;
        controls.half_azimuth = 30 * degree; controls.half_elevation = .001 * degree;
        controls.range_m = 20000;
        double allocated = 0, previous_search = 0, largest_search_gap = 0;
        bool late_measured = false;
        for (unsigned tick = 0; tick <= 5000; ++tick) {
            const double now = tick * .005;
            if (const auto* track = first(*radar)) controls.priority_ids[2] = track->id;
            const auto before = radar->status();
            (void)radar->update(now, controls, pose, scene);
            const auto& after = radar->status();
            if (after.dwelling && (!before.dwelling || after.beam.started != before.beam.started))
                allocated += after.beam.completes - after.beam.started;
            require(allocated <= now + .02 / resource + 1e-8, "air and surface jobs exceeded one shared elapsed RF budget");
            if (after.search_dwells != before.search_dwells) {
                largest_search_gap = std::max(largest_search_gap, now - previous_search); previous_search = now;
            }
            for (const auto& report : radar->measurements()) if (report.valid && report.position.e > 3000) {
                require(report.time >= scene.late_entry && report.time <= now,
                        "late air target publication preceded its actual entry/observation");
                late_measured = true;
            }
        }
        const auto& status = radar->status();
        require(status.surface_sequence > 0 && status.search_dwells > 0 && status.track_dwells > 0,
                "a shared RF service class was starved under measured support");
        require(late_measured && largest_search_gap < .5 / resource,
                "bounded priority work starved late-target air discovery");
    }
    std::cout << "PASS resource1/.25: finite shared RF work, support plus surface/search, and late-target discovery\n";
}
struct Field { std::string name; double value{}; bool written{}; };
std::map<std::string, Field> bus;
EDPARAM port;
void* resolve(const char* name) { auto& value = bus[name]; value.name = name; return &value; }
bool number(const void* handle, double& value, bool) {
    if (!handle) return false;
    value = static_cast<const Field*>(handle)->value; return true;
}
void store(void* handle, double value) {
    auto& field = *static_cast<Field*>(handle); field.value = value; field.written = true;
}
void text(void*, const char*) {} // No type-text claim is part of this campaign.
void original_publication_times(const NativeAesaRadar::Snapshot& packet) {
    for (std::size_t i = 0; i < packet.measurements.size(); ++i) {
        if (!packet.measurements[i].valid) continue;
        char prefix[32]{};
        std::snprintf(prefix, sizeof(prefix), "F22A_%02u_", static_cast<unsigned>(i + 1));
        const std::string name = prefix;
        if (bus.at(name + "VALID").value != 1) continue;
        require(bus.at(name + "TIME").value == packet.measurements[i].time,
                "native publication replaced original model observation time with receipt time");
    }
}
void bridge() {
    using NativeAesaRadar::parameters;
    port.ed_param_api.pfn_ed_cockpit_get_parameter_handle = resolve;
    port.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = number;
    port.ed_param_api.pfn_ed_cockpit_update_parameter_with_number = store;
    port.ed_param_api.pfn_ed_cockpit_update_parameter_with_string = text;
    require(parameters.bind(port), "actual native parameter adapter did not bind explicit ports");
    Model& radar = NativeAesaRadar::model;
    Scene scene; scene.edge_initial = true;
    Pose pose; pose.position.u = 5000;
    std::string line;
    double allocated_seconds = 0;
    std::cout << "READY\n" << std::flush;
    unsigned frames = 0;
    while (frames++ < 4096 && std::getline(std::cin, line)) {
        if (line == "STOP") break;
        if (line == "EPOCH") {
            NativeAesaRadar::epoch.fetch_add(1);
            std::cout << "EPOCH\n" << std::flush;
            continue;
        }
        std::istringstream input(line);
        double now{}; unsigned count{};
        require(static_cast<bool>(input >> now >> count) && count <= 64, "invalid bounded test command line");
        for (unsigned i = 0; i < count; ++i) {
            std::string name; double value{};
            require(static_cast<bool>(input >> name >> value), "missing command field");
            const auto found = bus.find(name);
            require(found != bus.end(), "test command attempted an undeclared host parameter");
            found->second.value = value;
        }
        auto request = parameters.controls(port, now);
        const auto previous = radar.status();
        (void)radar.update(now, request.controls, pose, scene);
        const auto& status = radar.status();
        if (status.dwelling && (!previous.dwelling || status.beam.started != previous.beam.started))
            allocated_seconds += status.beam.completes - status.beam.started;
        auto& packet = NativeAesaRadar::sensor_scratch;
        packet.epoch = NativeAesaRadar::epoch.load();
        packet.status = radar.status(); packet.measurements = radar.measurements();
        for (auto& [name, field] : bus) { (void)name; field.written = false; }
        parameters.publish(port, packet, now, request.controls.enabled);
        original_publication_times(packet);
        unsigned published = 0;
        for (const auto& [name, field] : bus) { (void)name; if (field.written) ++published; }
        std::cout << published + 1 << std::setprecision(17);
        for (const auto& [name, field] : bus) if (field.written) std::cout << ' ' << name << ' ' << field.value;
        std::cout << " TEST_ALLOCATED_SECONDS " << allocated_seconds;
        std::cout << '\n' << std::flush;
    }
}
}
int main(int argc, char**) {
    if (argc > 1) bridge();
    else { priority_before_surface(); finite_discovery_under_support(); }
}

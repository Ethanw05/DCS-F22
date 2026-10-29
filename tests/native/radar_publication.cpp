// R-RAD-001/003/017: actual AESA publication owner, independent finite DTO/port faults.
// Include search selects either primary EFM/source or one exact review artifact.
#include "NativeAesaRadar.cpp"
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <string>
#include <vector>
namespace NativeGroundSensor {
AesaRadar::SurfaceRequest pointing(double, const AesaRadar::Pose &) noexcept {
    std::abort();
}
void sample(void *, const ArrayService &) {
    std::abort();
}
} // namespace NativeGroundSensor
namespace NativeGroundVideo {
void set_aircraft(const AesaRadar::Pose *, double) noexcept {
    std::abort();
}
} // namespace NativeGroundVideo
namespace {
struct Field {
    std::string name, text;
    double value{};
    bool is_text{};
};
std::map<std::string, Field> bus;
std::vector<std::string> writes;
EDPARAM port;
NativeAesaRadar::Parameters publisher;
NativeAesaRadar::Snapshot packet;
unsigned checks{}, failures{}, text_writes{};
bool captures = false;
int hook_at = -1;
enum class Fault { none, writer_loss, context_reset, source_reset, final_handle };
Fault fault = Fault::none;
void require(bool value, const char *message) {
    ++checks;
    if (!value) {
        ++failures;
        std::cout << "FAIL " << message << '\n';
    }
}
void *resolve(const char *name) {
    auto &f = bus[name];
    f.name = name;
    return &f;
}
bool number(const void *handle, double &value, bool) {
    if (!handle)
        return false;
    const auto &f = *static_cast<const Field *>(handle);
    if (f.is_text)
        return false;
    value = f.value;
    return true;
}
void store(void *, double);
void text(void *handle, const char *value) {
    auto &f = *static_cast<Field *>(handle);
    f.text = value;
    f.is_text = true;
    ++text_writes;
}
void ports() {
    port.ed_param_api.pfn_ed_cockpit_get_parameter_handle = resolve;
    port.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = number;
    port.ed_param_api.pfn_ed_cockpit_update_parameter_with_number = store;
    port.ed_param_api.pfn_ed_cockpit_update_parameter_with_string = text;
}
void store(void *handle, double value) {
    auto &f = *static_cast<Field *>(handle);
    f.value = value;
    f.is_text = false;
    writes.push_back(f.name);
    if (static_cast<int>(writes.size()) != hook_at)
        return;
    if (fault == Fault::writer_loss)
        port.ed_param_api.pfn_ed_cockpit_update_parameter_with_number = nullptr;
    if (fault == Fault::context_reset) {
        port.invalidate();
        ports();
    }
    if (fault == Fault::source_reset)
        NativeAesaRadar::epoch.fetch_add(1);
    if (fault == Fault::final_handle)
        publisher.outputs[3] = nullptr;
}
void sample(double time, double north) {
    static const NativeAesaRadar::Snapshot empty{};
    packet = empty;
    packet.epoch = NativeAesaRadar::epoch.load();
    packet.status.ready = true;
    packet.status.time = time;
    packet.status.interference.valid = true;
    packet.status.interference.time = time;
    auto &m = packet.measurements[0];
    m.id = 84;
    m.hits = 3;
    m.valid = true;
    m.time = time;
    m.position = {north, 2000, 3000};
    m.raw_position = m.position;
    m.velocity = {10, 0, -20};
    m.association_valid = true;
    m.velocity_valid = true;
    m.filter_valid = true;
    m.range_sigma_m = 10;
    m.angle_sigma_rad = .001;
    m.position_sigma_m = 20;
    m.velocity_sigma_mps = 3;
    m.covariance[0] = 400;
    strcpy_s(m.type_name.data(), m.type_name.size(), "F-15C");
}
double value(const char *name) {
    return bus[name].value;
}
bool even() {
    return std::fmod(value("F22_AESA_SEQUENCE"), 2) == 0;
}
void publish(double now) {
    publisher.publish(port, packet, now, true);
}
void baseline() {
    hook_at = -1;
    fault = Fault::none;
    bus.clear();
    writes.clear();
    text_writes = 0;
    port.invalidate();
    ports();
    publisher.bound = false;
    NativeAesaRadar::publication = 0;
    NativeAesaRadar::epoch.store(1);
    require(publisher.bind(port), "explicit complete native binding");
    sample(10, 1200);
    publish(10);
    writes.clear();
}
void dump(const char *filename) {
    if (!captures)
        return;
    std::ofstream out(filename);
    out << '{';
    bool first = true;
    for (const auto &item : bus) {
        if (!first)
            out << ',';
        first = false;
        out << std::quoted(item.first) << ':';
        if (item.second.is_text)
            out << std::quoted(item.second.text);
        else
            out << item.second.value;
    }
    out << "}\n";
}
void rejected(const char *message) {
    require(!even() && value("F22_AESA_READY") == 0 && value("F22A_01_VALID") == 0, message);
    require(publisher.published_id[0] == 0 && publisher.published_time[0] == -100 &&
                !publisher.published_type_valid[0],
            "failed transaction invalidates all payload/type caches");
}
void normal_and_repeated() {
    baseline();
    require(even() && value("F22A_01_TIME") == 10 && value("F22A_01_N") == 1200,
            "normal finite sample commits together");
    require(bus["F22A_01_TYPE_NAME"].is_text && bus["F22A_01_TYPE_NAME"].text == "F-15C",
            "known optional type uses successful string dispatch");
    packet.status.time = 10.1;
    publish(10.1);
    require(value("F22A_01_TIME") == 10 && value("F22_AESA_TIME") == 10.1,
            "heartbeat cannot renew original sample time");
    bool payload = false;
    for (const auto &name : writes)
        if (name == "F22A_01_N")
            payload = true;
    require(!payload, "same completed sample reuses immutable numeric payload");
    baseline();
    sample(0, 1200);
    publish(0);
    require(even() && value("F22A_01_TIME") == 0, "zero World sample time commits");
}
void malformed_dto() {
    baseline();
    sample(10.1, 1250);
    packet.measurements[0].position.n = NAN;
    publish(10.1);
    rejected("nonfinite coordinate cannot commit old N with new TIME");
    dump("malformed-position.json");
    packet.measurements[0].position.n = 1250;
    publish(10.1);
    require(even() && value("F22A_01_N") == 1250 && value("F22A_01_TIME") == 10.1,
            "corrected same id/sample retries coordinate payload");
    dump("recovered-position.json");
    baseline();
    sample(10.1, 1250);
    packet.measurements[0].covariance[0] = INFINITY;
    publish(10.1);
    rejected("nonfinite covariance cannot commit retained covariance with new TIME");
    packet.measurements[0].covariance[0] = 900;
    publish(10.1);
    require(even() && value("F22A_01_COV_00") == 900,
            "corrected same id/sample retries covariance");
    baseline();
    packet.measurements[0].covariance[20] = NAN;
    publish(10);
    rejected("cached id/time still validates entire numeric DTO");
    baseline();
    sample(10.1, 1250);
    packet.status.beam.azimuth = NAN;
    publish(10.1);
    rejected("failed protected status setter prevents even commit");
}
void handle_failures() {
    baseline();
    sample(10.1, 1250);
    const auto marker = publisher.outputs[3];
    const auto types = text_writes;
    publisher.outputs[3] = nullptr;
    publish(10.1);
    require(writes.empty() && text_writes == types && value("F22A_01_TIME") == 10,
            "failed initial marker invokes no payload/type writers");
    require(publisher.published_id[0] == 0, "failed initial marker invalidates payload cache");
    publisher.outputs[3] = marker;
    publish(10.1);
    require(even() && value("F22A_01_N") == 1250, "same sample retries after marker recovery");
    baseline();
    sample(10.1, 1250);
    const auto north = publisher.contacts[0][3];
    publisher.contacts[0][3] = nullptr;
    publish(10.1);
    rejected("failed required payload handle cannot even-commit partial tuple");
    publisher.contacts[0][3] = north;
    publish(10.1);
    require(even() && value("F22A_01_N") == 1250,
            "same sample retries after payload handle recovery");
    baseline();
    sample(10.1, 1250);
    publish(10.1);
    const auto complete = static_cast<int>(writes.size());
    baseline();
    sample(10.1, 1250);
    fault = Fault::final_handle;
    hook_at = complete - 1;
    publish(10.1);
    rejected("failed final marker invalidates early row cache and leaves writing marker");
    dump("failed-final-commit.json");
    publisher.outputs[3] = resolve("F22_AESA_SEQUENCE");
    hook_at = -1;
    publish(10.1);
    require(even() && value("F22A_01_N") == 1250,
            "failed final commit does not suppress same-sample retry");
}
void writer_and_epoch_schedules() {
    baseline();
    sample(10.1, 1250);
    publish(10.1);
    const auto complete = static_cast<int>(writes.size());
    for (const auto kind : {Fault::writer_loss, Fault::context_reset, Fault::source_reset}) {
        for (int boundary = 1; boundary < complete; ++boundary) {
            baseline();
            sample(10.1, 1250);
            fault = kind;
            hook_at = boundary;
            publish(10.1);
            require(!even(), "pre-commit writer/context/source loss cannot publish even marker");
            require(publisher.published_id[0] == 0 && !publisher.published_type_valid[0],
                    "pre-commit loss invalidates caches");
            hook_at = -1;
            fault = Fault::none;
            ports();
            require(publisher.bind(port), "explicit recovery rebinds current context");
            packet.epoch = NativeAesaRadar::epoch.load();
            publish(10.1);
            require(even() && value("F22A_01_N") == 1250 && value("F22A_01_TIME") == 10.1,
                    "same sample recovers after every pre-commit writer boundary");
        }
    }
    std::cout << "pre_commit_numeric_boundaries=" << complete - 1 << '\n';
    // Loss after the final native void setter has stored is beyond the commit
    // linearization point: a complete old packet may remain, caches must retire.
    for (const auto kind : {Fault::writer_loss, Fault::context_reset}) {
        baseline();
        sample(10.1, 1250);
        fault = kind;
        hook_at = complete;
        publish(10.1);
        require(value("F22A_01_N") == 1250 && value("F22A_01_TIME") == 10.1,
                "post-store terminal loss retains a complete prior-context tuple");
        require(publisher.published_id[0] == 0,
                "post-store terminal loss cannot retain success cache");
    }
}
void optional_type_admission() {
    baseline();
    sample(10.1, 1250);
    packet.measurements[0].id = 85;
    strcpy_s(packet.measurements[0].type_name.data(), packet.measurements[0].type_name.size(),
             "MiG-29A");
    port.ed_param_api.pfn_ed_cockpit_update_parameter_with_string = nullptr;
    publish(10.1);
    require(even() && value("F22A_01_ID") == 85 && value("F22A_01_VALID") == 1,
            "optional string absence preserves complete numeric sensing");
    require(!bus["F22A_01_TYPE_NAME"].is_text && value("F22A_01_TYPE_NAME") == 0 &&
                !publisher.published_type_valid[0],
            "new id cannot authenticate stale prior type; typed zero is explicit unknown");
    dump("unknown-label.json");
    port.ed_param_api.pfn_ed_cockpit_update_parameter_with_string = text;
    publish(10.1);
    require(bus["F22A_01_TYPE_NAME"].is_text && bus["F22A_01_TYPE_NAME"].text == "MiG-29A",
            "optional label retries same sample after string recovery");
    dump("recovered-label.json");
    packet.measurements[0].time = 10.2;
    packet.status.time = 10.2;
    packet.status.interference.time = 10.2;
    publish(10.2);
    dump("next-sample-recovered-label.json");
    baseline();
    sample(10.1, 1250);
    port.ed_param_api.pfn_ed_cockpit_update_parameter_with_string = nullptr;
    fault = Fault::writer_loss;
    hook_at = 2; // Odd marker, then the first typed unknown-label write.
    publish(10.1);
    require(!even() && publisher.published_id[0] == 0,
            "writer loss during optional-label clearing cannot commit stale text with a new row");
    baseline();
    sample(10.1, 1250);
    publisher.type_names[0] = nullptr;
    publish(10.1);
    rejected("missing label handle cannot commit a new id with unverifiable stale type");
}
int __fastcall fixture_coalition(const void* object) {
    return *static_cast<const int*>(object);
}
class CoalitionEnvironment final : public AesaRadar::Environment {
public:
    int affiliation = -1;
    bool interference(double stamp, const AesaRadar::Pose&, const AesaRadar::Beam&,
                      AesaRadar::Interference& value, AesaRadar::QueryStats&) noexcept override {
        value = {true, 0, stamp, 0}; // Explicit supplied environment with no interfering emitter.
        return true;
    }
    bool visible(const AesaRadar::Pose&, const AesaRadar::Truth&, AesaRadar::QueryStats&) noexcept override {
        return true;
    }
    bool query(const AesaRadar::Pose&, const AesaRadar::Beam&, std::span<AesaRadar::Truth> output,
               std::size_t& count, AesaRadar::QueryStats&) noexcept override {
        output[0] = {};
        output[0].id = 314;
        output[0].position = {1000, 0, 0};
        output[0].cross_section_m2 = 1000000;
        output[0].coalition_affiliation = affiliation;
        count = 1;
        return true;
    }
};
void coalition_getter_cases() {
    NativeAesaRadar::api.coalition = fixture_coalition;
    for (int own = -1; own <= 3; ++own) {
        for (int other = -1; other <= 3; ++other) {
            const int expected = (own == 1 || own == 2) && (other == 1 || other == 2)
                ? (own == other ? 1 : 0) : -1;
            require(NativeAesaRadar::coalition_affiliation(&own, &other) == expected,
                    "same combat side friendly, opposite hostile, neutral/unavailable unknown");
        }
    }
    require(NativeAesaRadar::coalition_affiliation(nullptr, nullptr) == -1, "absent owner cannot identify");
    int known_side = 1;
    require(NativeAesaRadar::coalition_affiliation(&known_side, nullptr) == -1, "absent target cannot identify");
    NativeAesaRadar::api.coalition = nullptr;
    int side = 1;
    require(NativeAesaRadar::coalition_affiliation(&side, &side) == -1, "optional export absence stays unknown");
}
void coalition_sensor_cases() {
    for (int affiliation : {-1, 0, 1}) {
        static AesaRadar::Model sensor;
        sensor.reset();
        CoalitionEnvironment environment;
        environment.affiliation = affiliation;
        AesaRadar::Controls controls;
        controls.enabled = true;
        controls.half_azimuth = controls.half_elevation = AesaRadar::degree;
        controls.emit = false;
        sensor.update(0, controls, {}, environment);
        for (const auto& measurement : sensor.measurements())
            require(!measurement.valid, "coalition metadata cannot create a detection with RF off");
        controls.emit = true;
        for (int step = 0; step <= 100; ++step)
            sensor.update(step * .01, controls, {}, environment);
        bool found = false;
        for (const auto& measurement : sensor.measurements()) {
            if (!measurement.valid) continue;
            found = true;
            require(measurement.coalition_affiliation == affiliation, "detected report preserves source coalition");
            require(measurement.time >= 0 && measurement.time <= 1, "coalition retains measured report time");
        }
        require(found, "non-emitter scene target produces an actual owned sensor report");
    }
}
void coalition_publication_cases() {
    for (int affiliation : {-1, 0, 1, 2}) {
        baseline();
        packet.measurements[0].coalition_affiliation = affiliation;
        publish(10);
        const bool known = affiliation == 0 || affiliation == 1;
        require(value("F22A_01_COALITION_KNOWN") == (known ? 1 : 0), "explicit coalition known flag");
        require(value("F22A_01_COALITION_AFFILIATION") == (known ? affiliation : -1), "coherent coalition code");
        packet.measurements[0].association_valid = false;
        publish(10.1);
        require(value("F22A_01_COALITION_KNOWN") == 0, "association loss withdraws identity without a new sample");
        require(value("F22A_01_COALITION_AFFILIATION") == -1, "association loss clears prior coalition");
    }
}
} // namespace
int main(int argc, char **argv) {
    captures = argc == 2 && std::string(argv[1]) == "--capture";
    normal_and_repeated();
    malformed_dto();
    handle_failures();
    writer_and_epoch_schedules();
    optional_type_admission();
    coalition_getter_cases();
    coalition_sensor_cases();
    coalition_publication_cases();
    std::cout << "publication checks=" << checks << " failures=" << failures << '\n';
    return failures ? 1 : 0;
}

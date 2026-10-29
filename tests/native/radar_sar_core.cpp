// GPL-3.0-or-later. New analytic and lifecycle tests; no host or old oracle.
#include "../../EFM/source/SarCore.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <limits>
#include <memory>
#include <numbers>
#include <vector>

namespace {
unsigned checks{}, failures{};
void check(bool value, const char* why) {
    ++checks;
    if (!value) { ++failures; std::printf("FAIL %s\n", why); }
}
constexpr long double pi = std::numbers::pi_v<long double>;
Sar::Identity identity() { return {1, 2, 3, 4, 5}; }
Sar::Config configuration(unsigned count = 80) {
    Sar::Config c;
    c.identity = identity(); c.start_time = 100; c.maximum_gap = .1;
    c.width = 129; c.height = 1; c.pulses = count; c.frequencies = 128; c.bins = 1024;
    c.reference = {0, 0, 9000}; c.origin = {-8, 0, 9000};
    c.step_x = {.125, 0, 0}; c.step_y = {0, 0, .125};
    c.reference_range = std::hypot(1800., 9000.);
    c.first_frequency = 8e9 - 48e6; c.frequency_step = 96e6/127;
    return c;
}
Sar::Context context(const Sar::Config& c, double time) { return {c.identity, time, true, true}; }
Sar::Grant grant(const Sar::Config& c, unsigned index, double aperture = 180, bool motion = false, bool compensate = true) {
    Sar::Grant g;
    g.identity = c.identity; g.token = index + 1; g.illumination_completed = true;
    g.start_time = c.start_time + index*.01; g.end_time = g.start_time + .001; g.sample_time = g.start_time + .0005;
    const double fraction = c.pulses > 1 ? static_cast<double>(index)/(c.pulses - 1) : .5;
    g.actual_position = {-aperture/2 + aperture*fraction, 1800, 0};
    g.navigation_position = g.actual_position;
    if (motion) {
        g.actual_position[1] += .18*std::sin(6*static_cast<double>(pi)*fraction);
        if (compensate) g.navigation_position = g.actual_position;
    }
    return g;
}
bool add(Sar::Core& core, const Sar::Config& c, const Sar::Grant& g, std::span<const Sar::Scatterer> items) {
    const Sar::Scene scene{true, c.identity.environment, g.sample_time, items, c.scene_kind, g.sample_time};
    return core.submit(g, scene, context(c, g.end_time));
}
void drain(Sar::Core& core, const Sar::Context& current, unsigned budget = Sar::max_work) {
    for (unsigned i = 0; i < 100000 && core.progress().pending; ++i) {
        const auto used = core.step(current, budget);
        check(used > 0 && used <= std::min(budget, Sar::max_work), "bounded pending processing");
        if (!used) break;
    }
}
void finish(Sar::Core& core, const Sar::Config& c) {
    check(core.seal(), "configured collection seals");
    for (unsigned i = 0; i < 100000 && core.progress().state == Sar::State::sealed; ++i)
        check(core.step(context(c, grant(c,c.pulses-1).end_time),Sar::max_work) <= Sar::max_work, "bounded final work");
    check(core.progress().state == Sar::State::complete, "only complete pipeline publishes");
}
std::unique_ptr<Sar::Core> collect(const Sar::Config& c, std::span<const Sar::Scatterer> scene,
                                 double aperture = 180, bool motion = false, bool compensate = true, unsigned budget = Sar::max_work) {
    auto core = std::make_unique<Sar::Core>();
    check(core->begin(c, context(c, c.start_time)), "valid frozen collection begins");
    for (unsigned i = 0; i < c.pulses; ++i) {
        check(add(*core, c, grant(c, i, aperture, motion, compensate), scene), "completed RF illumination accepted");
        drain(*core, context(c,grant(c,i).end_time), budget);
    }
    finish(*core,c);
    return core;
}
long double distance(const Sar::Point& a, const Sar::Point& b) {
    const long double n = static_cast<long double>(a[0]) - b[0];
    const long double u = static_cast<long double>(a[1]) - b[1];
    const long double e = static_cast<long double>(a[2]) - b[2];
    return std::sqrt(n*n + u*u + e*e);
}
Sar::Complex analytic_sample(const Sar::Config& c, const Sar::Grant& g,
                             std::span<const Sar::Scatterer> scatterers, unsigned k) {
    std::complex<long double> sum{};
    const long double frequency = c.first_frequency + k*static_cast<long double>(c.frequency_step);
    for (const auto& s : scatterers) {
        const long double angle = -4*pi*frequency*(distance(s.position, g.actual_position) - c.reference_range)/Sar::light_speed;
        sum += std::complex<long double>(s.amplitude.real(), s.amplitude.imag())*
            std::complex<long double>(std::cos(angle), std::sin(angle));
    }
    return {static_cast<double>(sum.real()), static_cast<double>(sum.imag())};
}
Sar::Complex direct_bin(std::span<const Sar::Complex> history, unsigned bin, unsigned bins) {
    std::complex<long double> sum{};
    const auto unshifted = (bin + bins/2) % bins;
    for (std::size_t k = 0; k < history.size(); ++k) {
        const long double angle = 2*pi*k*unshifted/bins;
        sum += std::complex<long double>(history[k].real(), history[k].imag())*
            std::complex<long double>(std::cos(angle), std::sin(angle));
    }
    sum /= static_cast<long double>(history.size());
    return {static_cast<double>(sum.real()), static_cast<double>(sum.imag())};
}
Sar::Complex independent_pixel(const Sar::Config& c, const Sar::Core& core, const Sar::Point& at) {
    Sar::Complex sum{};
    const double step = Sar::light_speed/(2*c.bins*c.frequency_step);
    for (unsigned p = 0; p < c.pulses; ++p) {
        const long double dr = distance(at, core.pulse(p)->navigation_position) - c.reference_range;
        const auto index = static_cast<double>(dr)/step + c.bins/2.;
        const auto lower = static_cast<unsigned>(std::floor(index));
        const auto f = index - lower;
        const auto sample = direct_bin(core.history(p), lower, c.bins)*(1-f) + direct_bin(core.history(p), lower+1, c.bins)*f;
        const long double a = 4*pi*c.first_frequency*dr/Sar::light_speed;
        sum += sample*Sar::Complex(static_cast<double>(std::cos(a)), static_cast<double>(std::sin(a)));
    }
    return sum/static_cast<double>(c.pulses);
}
double peak(const Sar::ImageView& image) {
    double value = 0;
    for (const auto sample : image.pixels) value = std::max(value, std::norm(sample));
    return value;
}
void analytic_reference() {
    auto c = configuration(13);
    c.width = 17; c.height = 3; c.origin = {-1, 0, 8999.875};
    const std::array targets{Sar::Scatterer{{.37, 0, 9000.31}, {.7, -.2}}, Sar::Scatterer{{-1.3, 0, 8999.5}, {-.15, .3}}};
    auto core = collect(c, targets, 91);
    for (unsigned p = 0; p < c.pulses; ++p) {
        for (unsigned k = 0; k < c.frequencies; ++k)
            check(std::abs(core->history(p)[k] - analytic_sample(c, *core->pulse(p), targets, k)) < 3e-8, "analytic monostatic phase history");
        for (unsigned bin : {0u, 77u, 500u, 512u, 999u})
            check(std::abs(core->profile(p)[bin] - direct_bin(core->history(p), bin, c.bins)) < 3e-12, "inverse transform agrees with independent DFT");
    }
    long double signal = 0, error = 0;
    const auto image = core->last_complete();
    for (std::size_t x = 0; x < image.pixels.size(); ++x) {
        const Sar::Point at{c.origin[0] + (x%c.width)*c.step_x[0], 0, c.origin[2] + (x/c.width)*c.step_y[2]};
        const auto expected = independent_pixel(c, *core, at);
        signal += std::norm(expected); error += std::norm(image.pixels[x] - expected);
    }
    const double ser = 10*std::log10(static_cast<double>(signal/error));
    std::printf("independent_reference_ser_db=%.6f\n", ser);
    check(ser >= 100, "reference complex SER exceeds declared40dB criterion");
    check(image.config == c && image.first_observation == core->pulse(0)->sample_time &&
          image.last_observation == core->pulse(c.pulses-1)->sample_time, "complete image retains original frozen metadata");
}
void resolution_and_motion() {
    auto c = configuration();
    const std::array pair{Sar::Scatterer{{-2, 0, 9000}, {1, 0}}, Sar::Scatterer{{2, 0, 9000}, {1, 0}}};
    auto wide = collect(c, pair, 180), short_aperture = collect(c, pair, 12);
    const auto wi = wide->last_complete(), si = short_aperture->last_complete();
    const double valley = std::norm(wi.pixels[64])/std::min(std::norm(wi.pixels[48]), std::norm(wi.pixels[80]));
    check(valley < .1, "long collected aperture resolves independent4m pair");
    check(std::norm(si.pixels[64]) > .8*peak(si), "short aperture leaves pair unresolved");
    const std::array one{Sar::Scatterer{{0, 0, 9000}, {1, 0}}};
    auto range = c; range.origin = {0, 0, 8992}; range.step_x = {0, 0, .125}; range.step_y = {.125, 0, 0};
    auto high = collect(range, one);
    auto low_config = range;
    low_config.first_frequency = 8e9 - 4.8e6; low_config.frequency_step /= 10;
    auto low = collect(low_config, one);
    // Rectangular spectrum first slant-range null c/(2B), projected onto ground.
    const double null_ground = Sar::light_speed/(2*96e6)*c.reference_range/9000;
    const auto near_null = 64 + static_cast<unsigned>(std::lround(null_ground/.125));
    check(std::norm(high->last_complete().pixels[near_null]) < .03, "bandwidth-predicted range null");
    check(std::norm(low->last_complete().pixels[near_null]) > .85, "tenfold lower bandwidth broadens range response");
    auto compensated = collect(c, one, 180, true, true), wrong_navigation = collect(c, one, 180, true, false);
    const double gain = 10*std::log10(peak(compensated->last_complete())/peak(wrong_navigation->last_complete()));
    std::printf("cross_pair_valley_db=%.6f motion_compensation_gain_db=%.6f\n", 10*std::log10(valley), gain);
    check(peak(compensated->last_complete()) > .97 && gain > 5, "per-pulse navigation restores coherent motion focus");
}
void forward_ambiguity_and_blank() {
    auto c = configuration(27); c.reference = {9000, 0, 0}; c.origin = {9000, 0, -8};
    c.step_x = {0, 0, .125}; c.step_y = {.125, 0, 0};
    const std::array left{Sar::Scatterer{{9000, 0, -3.75}, {.4, -.6}}};
    const std::array right{Sar::Scatterer{{9000, 0, 3.75}, {.4, -.6}}};
    auto a = collect(c, left), b = collect(c, right);
    for (unsigned p = 0; p < c.pulses; ++p)
        check(std::equal(a->history(p).begin(), a->history(p).end(), b->history(p).begin()), "single-channel forward symmetry has identical histories");
    const auto image = a->last_complete();
    check(std::abs(image.pixels[34] - image.pixels[94]) < 1e-12, "backprojection preserves unavoidable forward ambiguity");
    auto blank = collect(c, {});
    check(peak(blank->last_complete()) == 0, "explicitly available empty scene forms healthy zero returns");
}
void lifecycle_and_admission() {
    auto c = configuration(9);
    auto core = std::make_unique<Sar::Core>();
    check(core->begin(c, context(c,100)), "lifecycle begins");
    const std::array scene{Sar::Scatterer{{0, 0, 9000}, {1, 0}}};
    auto first = grant(c,0);
    auto refused = first; refused.illumination_completed = false;
    check(!add(*core,c,refused,scene) && core->progress().submitted == 0, "requested illumination earns no history");
    refused = first; refused.service = static_cast<Sar::Service>(2);
    check(!add(*core,c,refused,scene), "AA or GMT grant earns no coherent pulse");
    auto unavailable = Sar::Scene{false,c.identity.environment,first.sample_time,{}};
    check(!core->submit(first,unavailable,context(c,first.end_time)), "unavailable scene is not blank evidence");
    check(!core->seal(), "short collection cannot seal or publish");
    for (unsigned i=0;i<8;++i) check(add(*core,c,grant(c,i),scene), "bounded queue admits eight grants");
    check(!add(*core,c,grant(c,8),scene) && core->progress().submitted==8, "full queue backpressure consumes no grant");
    drain(*core,context(c,grant(c,8).end_time),31);
    const auto replay=grant(c,7);
    const Sar::Scene replay_scene{true,c.identity.environment,replay.sample_time,scene,c.scene_kind,replay.sample_time};
    check(!core->submit(replay,replay_scene,context(c,grant(c,8).end_time)) && core->progress().reason==Sar::Reason::replay, "duplicate token rejected without credit");
    check(add(*core,c,grant(c,8),scene), "same unconsumed ninth grant succeeds after drain");
    drain(*core,context(c,grant(c,8).end_time));finish(*core,c);
    const auto complete = core->last_complete();
    const std::vector<Sar::Complex> saved(complete.pixels.begin(),complete.pixels.end());
    auto next = c; ++next.identity.collection; next.start_time=102;
    check(core->begin(next,context(next,102)), "new collection has different frozen identity");
    check(add(*core,next,grant(next,0),scene), "new work starts without changing lastcomplete");
    check(core->step(context(next,grant(next,0).end_time),100000)==Sar::max_work, "oversized work request clamps to declared bound");
    check(core->last_complete().config==c && std::equal(saved.begin(),saved.end(),complete.pixels.begin()), "partial work retains immutable complete image and original time");
    auto bad = context(next,102.1); bad.navigation_valid=false;
    check(!core->step(bad,1) && core->progress().state==Sar::State::cancelled, "processing itself requires current navigation evidence");
    check(core->history(0).empty() && core->profile(0).empty() && !core->pulse(0), "cancellation withdraws incomplete collection outputs");
    check(core->last_complete().config==c && std::equal(saved.begin(),saved.end(),complete.pixels.begin()), "cancel retains separate completed image");
    for (unsigned field=0;field<7;++field) {
        check(core->begin(next,context(next,102)), "fresh cancellation case begins");
        bad=context(next,102.01);
        if(field==0)bad.powered=false;
        if(field==1)++bad.identity.source;
        if(field==2)++bad.identity.navigation;
        if(field==3)++bad.identity.clock;
        if(field==4)++bad.identity.environment;
        if(field==5)bad.time=101.9;
        if(field==6)bad.time=std::numeric_limits<double>::infinity();
        check(!core->synchronize(bad) && !core->progress().pending, "power epoch rollback/nonfinite cancels all pending work");
    }
    core->forget_completed(); check(!core->last_complete().valid, "explicit teardown retires completed publication");
}
void independent_chunking_and_invalid() {
    const std::array scene{Sar::Scatterer{{.5,0,9000.25},{.8,.2}}};
    auto c=configuration(4);c.width=19;c.height=3;c.origin={-1,0,8999.875};
    auto full=collect(c,scene,17,false,true,4096), chunked=collect(c,scene,17,false,true,17);
    check(std::equal(full->last_complete().pixels.begin(),full->last_complete().pixels.end(),chunked->last_complete().pixels.begin()), "different bounded chunks preserve every output bit");
    auto core=std::make_unique<Sar::Core>();
    for(unsigned field=0;field<15;++field) {
        auto bad=c;
        if(field==0)bad.schema=2;
        if(field==1)bad.identity.navigation=0;
        if(field==2)bad.pulses=513;
        if(field==3)bad.frequencies=257;
        if(field==4)bad.bins=777;
        if(field==5)bad.width=257;
        if(field==6)bad.frequency_step=0;
        if(field==7)bad.first_frequency=std::numeric_limits<double>::quiet_NaN();
        if(field==8)bad.reference_range=0;
        if(field==9)bad.step_x[0]=std::numeric_limits<double>::infinity();
        if(field==10)bad.duration=-1;
        if(field==11)bad.origin[2]=3e7+1;
        if(field==12)bad.frequency_step=std::numeric_limits<double>::denorm_min();
        if(field==13)bad.step_x={std::numeric_limits<double>::denorm_min(),0,0};
        if(field==14)bad.scene_kind=static_cast<Sar::SceneKind>(3);
        check(!core->begin(bad,context(bad,100)), "malformed frozen field rejected before work");
    }
    const auto g=grant(c,0);
    for(double value : {std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::infinity()}) {
        for(unsigned field=0;field<7;++field) {
            check(core->begin(c,context(c,100)), "finite boundary case begins");
            auto altered=g;auto objects=scene;
            if(field<3)altered.actual_position[field]=value;
            else if(field<6)altered.navigation_position[field-3]=value;
            else objects[0].amplitude={value,0};
            check(!add(*core,c,altered,objects) && core->progress().submitted==0, "nonfinite phase/nav/amplitude creates no pulse");
        }
    }
    check(core->begin(c,context(c,100)), "scene geometry guard begins");
    auto outside=scene;outside[0].position[2]+=10000;
    check(!add(*core,c,g,outside) && core->progress().reason==Sar::Reason::range_gate, "out of unambiguous gate does not alias into scene");
}
void grant_scene_and_capacity_boundaries() {
    auto c=configuration(2);c.width=1;
    auto core=std::make_unique<Sar::Core>();
    const std::array target{Sar::Scatterer{{0,0,9000},{1,0}}};
    for(unsigned field=0;field<23;++field) {
        check(core->begin(c,context(c,100)), "grant field case begins");
        auto g=grant(c,0);auto now=context(c,g.end_time);auto objects=target;
        Sar::Scene scene{true,c.identity.environment,g.sample_time,objects,c.scene_kind,g.sample_time};
        if(field==0)g.start_time=std::numeric_limits<double>::quiet_NaN();
        if(field==1)g.end_time=std::numeric_limits<double>::infinity();
        if(field==2)g.sample_time=std::numeric_limits<double>::quiet_NaN();
        if(field==3)g.token=0;
        if(field==4)g.token=16777216;
        if(field==5)++g.identity.source;
        if(field==6)++g.identity.navigation;
        if(field==7)++g.identity.clock;
        if(field==8)++g.identity.environment;
        if(field==9)++g.identity.collection;
        if(field==10)g.end_time=g.start_time;
        if(field==11)g.sample_time=g.start_time-.001;
        if(field==12)g.sample_time=g.end_time+.001;
        if(field==13)g.end_time+=.001;
        if(field==14)now.time+=.3;
        if(field==15)scene.geometry_time=g.sample_time+.0001;
        if(field==16)scene.geometry_time=g.sample_time-.051;
        if(field==17)objects[0].position[1]=std::numeric_limits<double>::quiet_NaN();
        if(field==18)objects[0].amplitude={0,std::numeric_limits<double>::infinity()};
        if(field==19)scene.available=false;
        if(field==20)++scene.environment_epoch;
        if(field==21)scene.lease_time=std::numeric_limits<double>::quiet_NaN();
        if(field==22)scene.lease_time=std::numeric_limits<double>::infinity();
        check(!core->submit(g,scene,now) && core->progress().submitted==0, "malformed lease epoch scene or phase creates no pulse");
    }
    check(core->begin(c,context(c,100)), "gap case begins");
    check(add(*core,c,grant(c,0),target), "first coherent time accepted");
    drain(*core,context(c,grant(c,0).end_time));
    auto gap=grant(c,1);gap.start_time+=.11;gap.sample_time+=.11;gap.end_time+=.11;
    check(!add(*core,c,gap,target) && core->progress().reason==Sar::Reason::gap, "excessive illumination gap cancels collection");
    check(core->begin(c,context(c,100)), "maximum duration case begins");
    check(core->step(context(c,131),1)==0 && core->progress().reason==Sar::Reason::duration, "processing checks original collection duration");
    auto maximum=configuration(512);maximum.width=1;maximum.frequencies=2;maximum.bins=4;
    auto complete=collect(maximum,target);
    check(complete->progress().completed==Sar::max_pulses && complete->history(511).size()==2 && complete->history(512).empty(), "exact pulse bound completes without exposing out of range storage");
    auto wide=configuration(1);wide.width=256;wide.height=256;wide.frequencies=2;wide.bins=4;
    wide.origin={0,0,9000};wide.step_x={.01,0,0};wide.step_y={0,0,.01};
    std::array<Sar::Scatterer,257> many{};
    for(auto& s:many)s.position={0,0,9000};
    check(core->begin(wide,context(wide,100)), "maximum grid begins");
    check(!add(*core,wide,grant(wide,0),many), "scatterer overflow has no partial admission");
    const auto bounded=std::span<const Sar::Scatterer>(many.data(),256);
    check(add(*core,wide,grant(wide,0),bounded), "exact scatterer cap admits healthy zero-amplitude scene");
    drain(*core,context(wide,grant(wide,0).end_time));finish(*core,wide);
    check(core->last_complete().pixels.size()==Sar::max_pixels && peak(core->last_complete())==0, "maximum pixel cap completes in bounded batches");
}
void static_geometry_requires_current_visibility() {
    auto c=configuration(2);c.width=1;c.origin=c.reference;c.scene_kind=Sar::SceneKind::static_terrain;
    auto core=std::make_unique<Sar::Core>();
    const std::array target{Sar::Scatterer{{0,0,9000},{1,0}}};
    check(core->begin(c,context(c,100)), "static terrain collection begins");
    auto first=grant(c,0);
    Sar::Scene scene{true,c.identity.environment,40,target,c.scene_kind,first.sample_time};
    auto invalid=scene;invalid.lease_time=first.sample_time-.051;
    check(!core->submit(first,invalid,context(c,first.end_time)), "old DEM does not excuse stale visibility/provider lease");
    invalid=scene;invalid.lease_time=first.sample_time+.0001;
    check(!core->submit(first,invalid,context(c,first.end_time)), "future provider time rejected");
    invalid=scene;invalid.kind=Sar::SceneKind::dynamic_snapshot;
    check(!core->submit(first,invalid,context(c,first.end_time)), "scene kind cannot change within frozen collection");
    check(core->submit(first,scene,context(c,first.end_time)), "same-epoch old static geometry with current real lease accepted");
    drain(*core,context(c,first.end_time));
    auto second=grant(c,1);scene.geometry_time=41;scene.lease_time=second.sample_time;
    check(core->submit(second,scene,context(c,second.end_time)), "second completed pulse retains original DEM time");
    drain(*core,context(c,second.end_time));finish(*core,c);
    const auto image=core->last_complete();
    check(core->scene_record(0)->geometry_time==40 && core->scene_record(1)->geometry_time==41, "per-pulse geometry age is not receipt age");
    check(image.scene.oldest_geometry==40 && image.scene.newest_geometry==41 &&
          image.scene.oldest_lease==first.sample_time && image.scene.newest_lease==second.sample_time, "completed image preserves independent original geometry and visibility clocks");
    auto next=c;++next.identity.collection;next.start_time=102;next.origin[2]+=10000;
    check(core->begin(next,context(next,102)), "range-invalid next image begins without overwriting completed slot");
    check(add(*core,next,grant(next,0),target), "valid illumination may precede image-range guard");
    drain(*core,context(next,grant(next,0).end_time));
    check(core->progress().reason==Sar::Reason::range_gate && core->last_complete().config==c, "incompatible output geometry cancels and retains last complete");
    auto dynamic=configuration(1);dynamic.width=1;dynamic.origin=dynamic.reference;
    check(core->begin(dynamic,context(dynamic,100)), "dynamic scene comparison begins");
    const auto g=grant(dynamic,0);
    scene={true,dynamic.identity.environment,40,target,dynamic.scene_kind,g.sample_time};
    check(!core->submit(g,scene,context(dynamic,g.end_time)), "old dynamic geometry remains invalid despite fresh provider lease");
}
} // namespace
int main() {
    analytic_reference(); resolution_and_motion(); forward_ambiguity_and_blank(); lifecycle_and_admission(); independent_chunking_and_invalid();
    grant_scene_and_capacity_boundaries();
    static_geometry_requires_current_visibility();
    std::printf("sar core checks=%u failures=%u core_bytes=%zu\n",checks,failures,sizeof(Sar::Core));
    return failures ? 1 : 0;
}

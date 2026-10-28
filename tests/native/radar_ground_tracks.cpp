// R-RAD-003 / D-R-RAD-003. Independent measured-track and lifecycle cases.
#include "../../EFM/source/GroundMovingTargets.h"
#include <cstdlib>
#include <iostream>
#include <string_view>

using namespace GroundMovingTargets;
namespace {
void require(bool condition, std::string_view message) {
    if (!condition) { std::cerr << "FAIL: " << message << '\n'; std::exit(1); }
}
RawReturn raw(unsigned host, Vec point, Vec velocity, double stamp) {
    return {host, point, velocity, stamp};
}
void permutation() {
    static Measurements ordinary, permuted;
    ordinary.reset(1); permuted.reset(1);
    for (unsigned step = 0; step < 20; ++step) {
        const double now = step*.2;
        require(ordinary.advance(now) == ClockState::current, "ordinary clock");
        require(permuted.advance(now) == ClockState::current, "permuted clock");
        const auto a = raw(11, {10000+8*now, -1000, -1000+2*now}, {8,0,2}, now);
        const auto b = raw(99, {15000+6*now, -1000, 1000-now}, {6,0,-1}, now);
        auto pa = a, pb = b;
        pa.private_source = (step%2) ? 7001 : 8001;
        pb.private_source = (step%2) ? 8001 : 7001;
        require(ordinary.queue(a, {}, 0, 1, false), "ordinary A queued");
        require(ordinary.queue(b, {}, 0, 1, false), "ordinary B queued");
        require(permuted.queue(pa, {}, 0, 1, false), "permuted A queued");
        require(permuted.queue(pb, {}, 0, 1, false), "permuted B queued");
        ordinary.release(now+.061); permuted.release(now+.061);
        static Contacts original, changed;
        original=ordinary.contacts();changed=permuted.contacts();
        require(original.size() == 2 && changed.size() == 2, "separated measured tracks survive");
        for (std::size_t i = 0; i < original.size(); ++i) {
            const auto& x = original[i]; const auto& y = changed[i];
            require(x.id == y.id && x.stamp == y.stamp && x.association_valid == y.association_valid,
                    "private ID permutation cannot alter token/time/authority");
            require(x.point.n == y.point.n && x.point.u == y.point.u && x.point.e == y.point.e,
                    "identical measured input has identical published geometry");
            require(x.id == 1 || x.id == 2, "token does not expose either scene namespace");
        }
    }
    std::cout << "PASS host-ID permutations: 40 delayed measured reports, 20 epochs\n";
}
void ambiguity() {
    static Measurements tracks;
    tracks.reset(1);
    bool coasted = false;
    for (unsigned step = 0; step <= 20; ++step) {
        const double now = step*.1;
        require(tracks.advance(now) == ClockState::current, "crossing clock");
        const double east = 60-30*now;
        require(tracks.queue(raw(100, {10000,-1000,-east}, {0,0,30}, now), {}, 0, 1, false), "crossing A queue");
        require(tracks.queue(raw(200, {10000,-1000,east}, {0,0,-30}, now), {}, 0, 1, false), "crossing B queue");
        tracks.release(now+.061);
        const auto contacts = tracks.contacts();
        require(contacts.size() <= 2, "ambiguity cannot create perfectly split duplicate tracks");
        for (const auto& value : contacts)
            if (!value.association_valid && value.stamp < now) coasted = true;
    }
    require(tracks.statistics().ambiguous > 0 && coasted, "ambiguous crossing coasts without sample renewal");
    std::cout << "PASS crossing ambiguity: coasted original observation; ambiguous="
              << tracks.statistics().ambiguous << '\n';
}
void rollback() {
    static Measurements tracks;
    tracks.reset(1);
    require(tracks.advance(100) == ClockState::current, "rollback starting clock");
    require(tracks.queue(raw(7, {10000,-1000,0}, {10,0,0}, 100), {}, 0, 1, true, {}, {1,2}), "old queued report");
    tracks.release(100.03);
    require(tracks.statistics().pending == 1 && tracks.contacts(true).empty(), "processing delay cannot be bypassed");
    require(tracks.advance(10) == ClockState::discontinuity, "rollback explicitly reported to native owner");
    require(tracks.statistics().pending == 0 && tracks.contacts(true).empty(), "rollback retires pending and filtered states");
    tracks.reset(2); // Native source owner must retire selection/range/consent with this same epoch.
    require(tracks.advance(10) == ClockState::current, "new epoch current");
    tracks.release(100.1);
    require(tracks.statistics().pending == 0 && tracks.contacts(true).empty(), "numerical catchup cannot replay old queue");
    tracks.reset(3);
    require(tracks.advance(100.2) == ClockState::current, "fresh epoch clock");
    require(tracks.queue(raw(8, {12000,-1000,0}, {10,0,0}, 100.2), {}, 0, 1, true, {}, {3,3}), "fresh current request");
    tracks.release(100.261);
    const auto current = tracks.contacts(true);
    require(current.size() == 1 && current[0].stamp == 100.2, "fresh observation restores without relabelled old time");
    require(tracks.belongs_to(current[0].id, {3,3}) && !tracks.belongs_to(current[0].id, {1,2}), "request epoch preserved");
    const auto hits = current[0].hits;
    tracks.release(100.27);
    require(tracks.contacts(true)[0].hits == hits, "released report cannot run twice");
    std::cout << "PASS queue rollback, old-time catchup, current-request recovery and single release\n";
}
void limits() {
    static Measurements tracks;
    tracks.reset(1);
    require(tracks.advance(0) == ClockState::current, "legitimate zero source time");
    require(!tracks.queue(raw(99, {10000,-1000,0}, {}, 1), {}, 0, .5, false), "future raw sample rejected");
    require(!tracks.queue(raw(99, {10000,-1000,0}, {}, 0), {}, 0, .5, true, {}, {2,1}), "foreign request epoch rejected");
    for (unsigned i = 0; i < maximum_returns; ++i)
        require(tracks.queue(raw(i+1, {10000,-1000,1000.0*i}, {}, 0), {}, 0, .5, false), "bounded batch queued");
    require(!tracks.queue(raw(99, {20000,-1000,0}, {}, 0), {}, 0, .5, false), "ninth dwell return rejected before row indexing");
    tracks.release(.119);
    require(tracks.contacts().empty(), "original .06/resource delay preserved");
    tracks.release(.12);
    require(tracks.statistics().pending == 0 && !tracks.contacts().empty(), "finite zero-time reports released");
    std::cout << "PASS zero time, finite eight-return batch and original processing delay\n";
}
void jump_and_capacity() {
    static Measurements tracks;
    tracks.reset(1);
    for(unsigned step=0;step<10;++step) {
        const double now=step*.2;
        require(tracks.advance(now)==ClockState::current,"mature track source clock");
        require(tracks.queue(raw(19,{10000+10*now,-1000,0},{10,0,0},now),{},0,1,false),"mature track queue");
        tracks.release(now+.061);
    }
    const auto prior=*tracks.find(1);
    require(tracks.advance(2)==ClockState::current,"jump source clock");
    require(tracks.queue(raw(19,{40000,-1000,0},{10,0,0},2),{},0,1,false),"jump report queue");
    tracks.release(2.061);
    const auto* retained=tracks.find(1);
    require(retained&&retained->stamp==prior.stamp&&retained->point.n==prior.point.n,
            "same host identity dragged established measured token through impossible jump");
    tracks.reset(2);
    for(unsigned i=0;i<maximum_pending;++i) {
        const double now=10+i*.001;
        require(tracks.advance(now)==ClockState::current,"pending capacity clock");
        require(tracks.queue(raw(i+1,{10000,-1000,0},{},now),{},0,.1,false),"pending capacity queue");
    }
    require(tracks.advance(10.04)==ClockState::current,"full pending clock");
    require(!tracks.queue(raw(99,{20000,-1000,0},{},10.04),{},0,.1,false)&&
        tracks.statistics().pending==maximum_pending,"full processing queue overwrote pending report");
    tracks.release(10.7);
    require(tracks.statistics().pending==0,"bounded pending work did not drain");
    std::cout<<"PASS impossible same-host jump and full 32-report processing capacity\n";
}
}
int main() {
    permutation(); ambiguity(); rollback(); limits(); jump_and_capacity();
    std::cout << "Measured ground owner cases pass; native/DCS qualification remains separate.\n";
}

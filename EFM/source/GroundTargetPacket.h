// GPL-3.0-or-later. Typed delivery target and original radar provenance.
#pragma once
#include <Cockpit/CockpitAPI_Declare.h>
#include <array>
#include <cmath>
#include <cstdint>

namespace GroundTargetPacket {
struct Identity {
    std::array<double,3> point{}; // World N/U/E metres.
    std::uint32_t sequence{},delivery_source{},origin_source{},packet_epoch{};
    bool observation_known{},live{};
    double observation_time=-100;
    std::uint32_t observation_sequence{},source_epoch{},request{},kind{};
    std::uint64_t parameter_epoch{};
    bool operator==(const Identity&) const=default;
};
struct Target {
    bool valid{};
    Identity identity{};
    double producer_time{};
    std::uint32_t packet_sequence{},output_sequence{},control_sequence{};
};
inline bool integer(double v,double lo,double hi) noexcept {
    return std::isfinite(v) && v>=lo && v<=hi && v==std::floor(v);
}
inline bool committed(double v) noexcept { return integer(v,2,16777214) && std::fmod(v,2)==0; }
inline bool flag(double v) noexcept { return v==0 || v==1; }
inline bool release_flags(double consent,double power,double armed,double wow,double guided) noexcept {
    // These declared flags are exact0/1, never analogue permission estimates.
    return consent==1 && power==1 && armed==1 && wow==0 && guided==1;
}
inline bool fresh(double now,double stamp,double lease) noexcept {
    return std::isfinite(now) && now>=0 && std::isfinite(stamp) && stamp>=0
        && now>=stamp && now-stamp<=lease;
}
inline bool position(const std::array<double,3>& p) noexcept {
    for (const auto v : p) if (!std::isfinite(v)) return false;
    return std::abs(p[0])<=3e7 && std::abs(p[2])<=3e7 && p[1]>=-500 && p[1]<=100000;
}
struct Binding {
    EDPARAM* port{}; // Borrowed. Owning reset drains callbacks before destruction.
    std::uint64_t context{};
    std::array<void*,18> target{};
    std::array<void*,3> output{};
    std::array<void*,15> control{};
};
inline bool number(const Binding& b,void* handle,double& value) noexcept {
    return b.port && b.port->epoch()==b.context && b.port->getParamNumber(handle,value);
}
inline bool metadata(const std::array<double,18>& v,Identity& id) noexcept {
    if (!flag(v[11]) || !flag(v[17]) || !integer(v[5],1,16777215)
        || !integer(v[6],1,3) || !integer(v[7],1,3)) return false;
    id.sequence=static_cast<std::uint32_t>(v[5]);
    id.delivery_source=static_cast<std::uint32_t>(v[6]);
    id.origin_source=static_cast<std::uint32_t>(v[7]);
    id.point={v[8],v[9],v[10]};id.observation_known=v[11]==1;id.observation_time=v[12];
    if (!position(id.point) || !integer(v[13],0,16777215) || !integer(v[14],0,16777215)
        || !integer(v[15],0,16777215) || !integer(v[16],0,3)) return false;
    id.observation_sequence=static_cast<std::uint32_t>(v[13]);
    id.source_epoch=static_cast<std::uint32_t>(v[14]);id.request=static_cast<std::uint32_t>(v[15]);
    id.kind=static_cast<std::uint32_t>(v[16]);id.live=v[17]==1;
    return true;
}
inline bool unmeasured(const Identity& id) noexcept {
    return !id.observation_known && id.observation_time==-100 && id.source_epoch==0
        && id.request==0 && id.kind==0 && id.observation_sequence==0 && !id.live;
}
inline bool observed_clock(const Identity& id,double now) noexcept {
    return id.observation_known && id.source_epoch>=1 && id.kind>=1 && id.kind<=3
        && std::isfinite(id.observation_time) && id.observation_time>=0
        && std::isfinite(now) && now>=id.observation_time;
}
inline bool provenance(const Identity& id,double now) noexcept {
    if (id.origin_source!=2) return unmeasured(id);
    if (!observed_clock(id,now)) return false;
    if (id.kind==3) return !id.live;
    return id.live && now-id.observation_time<=5.25;
}
inline bool delivery_header(const Binding& b,double now,std::array<double,18>& v) noexcept {
    if (!number(b,b.target[0],v[0]) || !committed(v[0])) return false;
    for (std::size_t i=1;i<v.size();++i) if (!number(b,b.target[i],v[i])) return false;
    return v[1]==1 && integer(v[2],1,16777215) && fresh(now,v[3],.5) && v[4]==1;
}
inline bool current_epoch(const Binding& b,Target& target) noexcept {
    double sequence{},schema{},epoch{},after{},last_epoch{};
    if (!number(b,b.output[0],sequence) || !committed(sequence)
        || !number(b,b.output[1],schema) || schema!=1
        || !number(b,b.output[2],epoch) || !integer(epoch,1,16777215)) return false;
    if (!number(b,b.output[2],last_epoch) || epoch!=last_epoch
        || !number(b,b.output[0],after) || sequence!=after) return false;
    target.output_sequence=static_cast<std::uint32_t>(sequence);
    return epoch==target.identity.source_epoch;
}
inline bool live_fields(const std::array<double,15>& v,const Identity& id,double now) noexcept {
    if (v[4]!=1 || v[5]!=1 || v[6]!=id.source_epoch || !integer(v[7],0,16777215)) return false;
    if (!position({v[8],v[9],v[10]}) || !fresh(now,v[11],5.25) || v[11]<id.observation_time) return false;
    return v[12]==id.request && v[13]==id.kind && v[14]==1;
}
inline bool live_evidence(const Binding& b,Target& target,double now) noexcept {
    std::array<double,15> v{};
    if (!number(b,b.control[0],v[0]) || !committed(v[0])) return false;
    for (std::size_t i=1;i<v.size();++i) if (!number(b,b.control[i],v[i])) return false;
    if (v[1]!=1 || v[2]!=target.identity.source_epoch || !fresh(now,v[3],.5)
        || !live_fields(v,target.identity,now)) return false;
    double epoch{},sequence{};
    if (!number(b,b.control[2],epoch) || epoch!=v[2]
        || !number(b,b.control[0],sequence) || sequence!=v[0]) return false;
    target.control_sequence=static_cast<std::uint32_t>(sequence);
    return true;
}
inline bool source_current(const Binding& b,Target& target,double now) noexcept {
    if (target.identity.origin_source!=2) return true;
    if (!current_epoch(b,target)) return false;
    return target.identity.kind==3 || live_evidence(b,target,now);
}
template<std::size_t N>
inline bool markers(const Binding& b,const std::array<void*,N>& handles,
                    std::uint32_t expected_sequence,std::uint32_t expected_epoch) noexcept {
    double sequence{},epoch{};
    return number(b,handles[0],sequence) && sequence==expected_sequence
        && number(b,handles[2],epoch) && epoch==expected_epoch;
}
inline bool same_markers(const Binding& b,const Target& target) noexcept {
    if (!markers(b,b.target,target.packet_sequence,target.identity.packet_epoch)) return false;
    if (target.identity.origin_source!=2) return true;
    if (!markers(b,b.output,target.output_sequence,target.identity.source_epoch)) return false;
    return target.identity.kind==3 || markers(b,b.control,target.control_sequence,target.identity.source_epoch);
}
inline bool read(const Binding& b,double now,Target& result) noexcept {
    result={};
    if (!b.port || b.port->epoch()!=b.context) return false;
    Target next;std::array<double,18> values{};
    if (!delivery_header(b,now,values) || !metadata(values,next.identity) || !provenance(next.identity,now)) return false;
    next.packet_sequence=static_cast<std::uint32_t>(values[0]);next.identity.packet_epoch=static_cast<std::uint32_t>(values[2]);
    next.producer_time=values[3];next.identity.parameter_epoch=b.context;
    if (!source_current(b,next,now) || !same_markers(b,next)) return false;
    if (b.port->epoch()!=b.context) return false;
    next.valid=true;result=next;
    return true;
}
inline bool current(const Binding& b,const Target& cached,const Target& observed,double now) noexcept {
    return cached.valid && observed.valid && cached.identity==observed.identity
        && provenance(cached.identity,now) && fresh(now,cached.producer_time,.5)
        && fresh(now,observed.producer_time,.5) && same_markers(b,observed)
        && b.port && b.port->epoch()==b.context;
}
template<std::size_t N>
inline bool bind_handles(EDPARAM& port,std::array<void*,N>& handles,
                         const std::array<const char*,N>& names) noexcept {
    for (std::size_t i=0;i<N;++i) if (!(handles[i]=port.getParamHandle(names[i]))) return false;
    return true;
}
class Reader {
    Binding binding_{};
public:
    void invalidate() noexcept { binding_={}; }
    const Binding& binding() const noexcept { return binding_; }
    bool bind(EDPARAM& port) noexcept {
        if (binding_.port==&port && binding_.context==port.epoch() && port.numericReady()) return true;
        invalidate();if (!port.numericReady()) return false;
        constexpr std::array target_names{"F22_AG_DELIVERY_TARGET_PACKET_SEQUENCE","F22_AG_DELIVERY_TARGET_PACKET_SCHEMA",
            "F22_AG_DELIVERY_TARGET_PACKET_EPOCH","F22_AG_DELIVERY_TARGET_PACKET_TIME","F22_AG_DELIVERY_TARGET_VALID",
            "F22_AG_DELIVERY_TARGET_SEQUENCE","F22_AG_DELIVERY_TARGET_SOURCE","F22_AG_DELIVERY_TARGET_ORIGIN_SOURCE",
            "F22_AG_DELIVERY_TARGET_N","F22_AG_DELIVERY_TARGET_U","F22_AG_DELIVERY_TARGET_E",
            "F22_AG_DELIVERY_TARGET_OBSERVATION_KNOWN","F22_AG_DELIVERY_TARGET_OBSERVATION_TIME",
            "F22_AG_DELIVERY_TARGET_OBSERVATION_SEQUENCE","F22_AG_DELIVERY_TARGET_SOURCE_EPOCH",
            "F22_AG_DELIVERY_TARGET_SOURCE_REQUEST","F22_AG_DELIVERY_TARGET_SOURCE_TYPE","F22_AG_DELIVERY_TARGET_SOURCE_LIVE"};
        constexpr std::array output_names{"F22_AG_NATIVE_SEQUENCE","F22_AG_NATIVE_SCHEMA","F22_AG_NATIVE_SOURCE_EPOCH"};
        constexpr std::array control_names{"F22_AG_NATIVE_CONTROL_SEQUENCE","F22_AG_NATIVE_CONTROL_SCHEMA",
            "F22_AG_NATIVE_CONTROL_EPOCH","F22_AG_NATIVE_CONTROL_TIME","F22_AG_DESIGNATION_VALID",
            "F22_AG_DESIGNATION_SCHEMA","F22_AG_DESIGNATION_EPOCH","F22_AG_DESIGNATION_SEQUENCE",
            "F22_AG_DESIGNATION_NORTH","F22_AG_DESIGNATION_ALTITUDE","F22_AG_DESIGNATION_EAST",
            "F22_AG_DESIGNATION_TIME","F22_AG_DESIGNATION_REQUEST","F22_AG_DESIGNATION_TYPE","F22_AG_DESIGNATION_LIVE"};
        Binding next;next.port=&port;next.context=port.epoch();
        if (!bind_handles(port,next.target,target_names) || !bind_handles(port,next.output,output_names)
            || !bind_handles(port,next.control,control_names)) return false;
        if (next.context!=port.epoch()) return false;
        binding_=next;return true;
    }
    bool capture(EDPARAM& port,double now,Target& target) noexcept {
        if (!bind(port)) {target={};return false;}
        return read(binding_,now,target);
    }
};
} // namespace GroundTargetPacket

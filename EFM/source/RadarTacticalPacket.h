// GPL-3.0-or-later. Owned tactical parameter snapshot, not a radio wire schema.
#pragma once
#include <Cockpit/CockpitAPI_Declare.h>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>

namespace RadarTacticalPacket {
inline constexpr std::size_t maximum_slots=64, maximum_reports=32;
struct Report {
    std::uint32_t source{};
    std::array<double,3> position{},velocity{}; // World N/U/E: metres, m/s.
    double observation_time{}; // Original World time; capture never renews it.
    bool association_valid{},velocity_valid{};
    bool identity_known{},friendly{},hostile{};
    double identity_time=-100; // Independent original World identity time.
    bool operator==(const Report&) const=default;
};
struct Packet {
    bool valid{},truncated{};
    std::uint32_t sequence{};
    double source_epoch{},producer_time{};
    std::uint64_t parameter_epoch{};
    std::size_t count{};
    std::array<Report,maximum_reports> reports{};
};
inline bool flag(double value) noexcept { return value==0 || value==1; }
inline bool integer(double value,double minimum,double maximum) noexcept {
    return std::isfinite(value) && value>=minimum && value<=maximum && value==std::floor(value);
}
inline bool epoch_valid(double value) noexcept { return integer(value,1,16777215); }
inline bool clock_valid(double now,double stamp) noexcept {
    return std::isfinite(now) && now>=0 && std::isfinite(stamp) && stamp>=0
        && now-stamp>=-.05 && now-stamp<=.25;
}
inline bool vector_valid(const std::array<double,3>& value) noexcept {
    for (const double x : value) if (!std::isfinite(x)) return false;
    return true;
}
inline bool position_valid(const std::array<double,3>& value) noexcept {
    return vector_valid(value) && std::abs(value[0])<=3e7 && std::abs(value[2])<=3e7
        && value[1]>=-500 && value[1]<=100000;
}
class Reader {
    static constexpr std::array names{"VALID","SOURCE","POSITION_VALID","ASSOCIATION_VALID",
        "VELOCITY_VALID","MEASUREMENT_SOURCE","AGE","N","U","E","VN","VU","VE",
        "IDENTITY_KNOWN","IDENTITY_TIME","FRIENDLY","HOSTILE"};
    static constexpr std::array group_names{"F22_RADAR_TACTICAL_SEQUENCE","F22_RADAR_TACTICAL_SCHEMA",
        "F22_RADAR_TACTICAL_SOURCE_EPOCH","F22_RADAR_TACTICAL_TIME"};
    std::array<void*,group_names.size()> group_{};
    std::array<std::array<void*,names.size()>,maximum_slots> slots_{};
    const EDPARAM* owner_{};
    std::uint64_t context_{};
    bool bound_{};
    Packet scratch_{};
    enum class Slot { empty,report,malformed };
    struct Header { double sequence{},epoch{},stamp{}; };
    bool bind(EDPARAM& port) noexcept {
        if (bound_ && owner_==&port && context_==port.epoch() && port.numericReady()) return true;
        bound_=false;
        if (!port.numericReady()) return false;
        const auto context=port.epoch();
        for (std::size_t i=0;i<group_.size();++i)
            if (!(group_[i]=port.getParamHandle(group_names[i]))) return false;
        char name[96]{};
        for (std::size_t i=0;i<slots_.size();++i) for (std::size_t j=0;j<names.size();++j) {
            const int size=std::snprintf(name,sizeof(name),"F22_RADAR_TACTICAL_%02u_%s",
                static_cast<unsigned>(i+1),names[j]);
            if (size<0 || static_cast<std::size_t>(size)>=sizeof(name)) return false;
            if (!(slots_[i][j]=port.getParamHandle(name))) return false;
        }
        if (context!=port.epoch() || !port.numericReady()) return false;
        owner_=&port;context_=context;bound_=true;
        return true;
    }
    static bool fields_valid(const std::array<double,names.size()>& v,double stamp) noexcept {
        for (const auto index : {0u,2u,3u,4u,13u,15u,16u}) if (!flag(v[index])) return false;
        if (!integer(v[1],1,4294967295.0) || !integer(v[5],0,2)) return false;
        if (v[6]<0 || v[6]>20 || stamp-v[6]<0) return false;
        return v[13]==0 || (v[14]>=0 && v[14]<=stamp);
    }
    Slot slot(EDPARAM& port,std::size_t index,double stamp,Report& result) noexcept {
        std::array<double,names.size()> values{};
        if (!port.getParamNumber(slots_[index][0],values[0]) || !flag(values[0])) return Slot::malformed;
        if (values[0]==0) return Slot::empty;
        for (std::size_t field=1;field<values.size();++field)
            if (!port.getParamNumber(slots_[index][field],values[field])) return Slot::malformed;
        if (!fields_valid(values,stamp)) return Slot::malformed;
        result.source=static_cast<std::uint32_t>(values[1]);
        result.position={values[7],values[8],values[9]};
        result.velocity={values[10],values[11],values[12]};
        if (!position_valid(result.position) || !vector_valid(result.velocity)) return Slot::malformed;
        result.observation_time=stamp-values[6];
        result.association_valid=values[3]==1;result.velocity_valid=values[4]==1;
        if (result.velocity_valid && std::hypot(values[10],values[11],values[12])>1500) return Slot::malformed;
        result.identity_known=values[13]==1;result.identity_time=values[14];
        result.friendly=values[15]==1;result.hostile=values[16]==1;
        return values[2]==1 && values[5]==2 && values[6]<=6 ? Slot::report : Slot::empty;
    }
    bool header(EDPARAM& port,double now,Header& result) const noexcept {
        if (!port.getParamNumber(group_[0],result.sequence) || !integer(result.sequence,2,16777214)
            || std::fmod(result.sequence,2)!=0) return false;
        double schema{};
        return port.getParamNumber(group_[1],schema) && schema==1
            && port.getParamNumber(group_[2],result.epoch) && epoch_valid(result.epoch)
            && port.getParamNumber(group_[3],result.stamp) && clock_valid(now,result.stamp);
    }
    bool same_header(EDPARAM& port,const Header& group,std::uint64_t context) const noexcept {
        double epoch{},sequence{};
        return port.getParamNumber(group_[2],epoch) && epoch==group.epoch
            && port.getParamNumber(group_[0],sequence) && sequence==group.sequence
            && port.epoch()==context;
    }
public:
    void invalidate() noexcept {
        bound_=false;owner_=nullptr;context_=0;
        group_.fill(nullptr);
        for (auto& slot : slots_) slot.fill(nullptr);
        scratch_={};
    }
    bool capture(EDPARAM& port,double now,Packet& output) noexcept {
        output={};scratch_={};
        if (!bind(port)) return false;
        const auto context=port.epoch();
        Header group;
        if (!header(port,now,group)) return false;
        for (std::size_t i=0;i<maximum_slots;++i) {
            Report report;
            const auto status=slot(port,i,group.stamp,report);
            if (status==Slot::malformed) return false;
            if (status!=Slot::report) continue;
            if (scratch_.count==maximum_reports) { scratch_.truncated=true;continue; }
            scratch_.reports[scratch_.count++]=report;
        }
        if (!same_header(port,group,context)) return false;
        scratch_.valid=true;scratch_.sequence=static_cast<std::uint32_t>(group.sequence);
        scratch_.source_epoch=group.epoch;scratch_.producer_time=group.stamp;scratch_.parameter_epoch=context;
        output=scratch_;
        return true;
    }
};
} // namespace RadarTacticalPacket

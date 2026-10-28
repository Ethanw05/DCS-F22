// GPL-3.0-or-later. Read-only I-FLT-001 admission; never integrates aircraft state.
// Clock-kind1 is RAPTOR spawn time, not the native World clock. The .25/.05s
// bounds match the declared physical consumer policy, not aircraft calibration.
#pragma once
#include <Cockpit/CockpitAPI_Declare.h>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>

namespace WeaponFlightFrame {
enum Field : std::size_t { Owner, Valid, Generation, Stamp, ClockKind, FullFlight, Clock, Count };
using Header=std::array<double,Count>;
inline constexpr std::array<const char*,Count> header_names{
    "EFM_POWER_OWNER", "EFM_PHYSICAL_VALID", "EFM_PHYSICAL_GENERATION",
    "EFM_PHYSICAL_STAMP", "EFM_PHYSICAL_CLOCK_KIND", "EFM_HUD_VALID", "F22_AP_CLOCK"};
inline constexpr std::array<const char*,6> motion_names{
    "EFM_HUD_VN", "EFM_HUD_VU", "EFM_HUD_VE", "EFM_HUD_WN", "EFM_HUD_WU", "EFM_HUD_WE"};
inline constexpr std::array<const char*,1> speed_names{"EFM_HUD_TAS"};

inline bool read_header(EDPARAM& parameters, Header& header) {
    for (std::size_t i=0;i<Count;++i) {
        if (!parameters.getParamNumber(parameters.getParamHandle(header_names[i]),header[i])) return false;
    }
    return true;
}
inline bool flags(const Header& header) {
    return header[Owner]==1 && header[Valid]==1 && header[ClockKind]==1 && header[FullFlight]==1;
}
inline bool epoch(const Header& header) {
    const double generation=header[Generation];
    return generation>=1 && generation<=4294967295.0 && generation==std::floor(generation);
}
inline bool fresh(const Header& header) {
    const double age=header[Clock]-header[Stamp];
    return header[Clock]>=0 && header[Stamp]>=0 && age>=-.05 && age<=.25;
}
inline bool qualified(const Header& header) { return flags(header) && epoch(header) && fresh(header); }
inline bool same_epoch(const Header& before, const Header& after) {
    return before[Generation]==after[Generation] && before[Stamp]==after[Stamp]
        && before[ClockKind]==after[ClockKind] && after[Clock]>=before[Clock];
}

template<std::size_t Size> struct Snapshot {
    static_assert(Size>0 && Size<=16);
    Header header{};
    std::array<double,Size> values{};
    const EDPARAM* owner{};
    std::uint64_t parameter_epoch{};
    bool load(EDPARAM& parameters, const std::array<const char*,Size>& names) {
        const auto context=parameters.epoch();
        Header before{},after{};
        if (!read_header(parameters,before) || !qualified(before)) return false;
        for (std::size_t i=0;i<Size;++i) {
            if (!parameters.getParamNumber(parameters.getParamHandle(names[i]),values[i])) return false;
        }
        if (!read_header(parameters,after) || !qualified(after) || !same_epoch(before,after)
            || parameters.epoch()!=context) return false;
        header=after;owner=&parameters;parameter_epoch=context;
        return true;
    }
    bool current(EDPARAM& parameters) const {
        Header after{};
        return owner==&parameters && parameters.epoch()==parameter_epoch
            && read_header(parameters,after) && qualified(after) && same_epoch(header,after)
            && parameters.epoch()==parameter_epoch;
    }
    double generation() const { return header[Generation]; }
};
}

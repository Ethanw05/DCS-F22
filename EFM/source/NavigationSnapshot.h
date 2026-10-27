// GPL-3.0-or-later. Borrowed parameter handles; no recurring allocation.
#pragma once
#include <array>
#include <cmath>
#include <Cockpit/CockpitAPI_Declare.h>

namespace RaptorNavigation {
struct Frame {
    bool present = true, valid = false, terminal = false;
    double track = 0, time = 0;
};
class Snapshot {
    std::array<void*,10> handles_{};
    bool observed_schema_ = false;
    static bool number(EDPARAM& api, void* handle, double& value) noexcept {
        const auto read = api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number;
        return handle && read && read(handle,value,false) && std::isfinite(value);
    }
    static bool sequence(double value) noexcept {
        return value>=1 && value<=16777215 && value==std::floor(value);
    }
    static bool flags(const std::array<double,4>& values) noexcept {
        return (values[0]==0 || values[0]==1) && (values[3]==0 || values[3]==1);
    }
    bool fields(EDPARAM& api, unsigned slot, std::array<double,4>& values) const noexcept {
        bool complete=true;
        for (std::size_t field=0;field<values.size();++field)
            complete=number(api,handles_[2+slot*4+field],values[field]) && complete;
        return complete && flags(values);
    }
public:
    void initialize(EDPARAM& api) noexcept {
        constexpr std::array<const char*,10> names = {
            "F22_NAV_SNAPSHOT_SCHEMA", "F22_NAV_SNAPSHOT_SEQUENCE",
            "F22_NAV_SNAPSHOT_0_VALID", "F22_NAV_SNAPSHOT_0_TRACK",
            "F22_NAV_SNAPSHOT_0_TIME", "F22_NAV_SNAPSHOT_0_TERMINAL",
            "F22_NAV_SNAPSHOT_1_VALID", "F22_NAV_SNAPSHOT_1_TRACK",
            "F22_NAV_SNAPSHOT_1_TIME", "F22_NAV_SNAPSHOT_1_TERMINAL"};
        const auto get = api.ed_param_api.pfn_ed_cockpit_get_parameter_handle;
        for (std::size_t index=0;index<names.size();++index) handles_[index]=get ? get(names[index]) : nullptr;
        observed_schema_=false;
    }
    Frame read(EDPARAM& api) noexcept {
        Frame result;
        double schema=0;
        if (!number(api,handles_[0],schema)) return result;
        if (schema==0 && !observed_schema_) { result.present=false;return result; }
        observed_schema_=true;
        if (schema!=1) return result;
        for (unsigned attempt=0;attempt<2;++attempt) {
            double before=0,after=0;
            if (!number(api,handles_[1],before) || !sequence(before)) return result;
            const auto slot=static_cast<unsigned>(before)%2;
            std::array<double,4> values{};
            const bool complete=fields(api,slot,values);
            if (!number(api,handles_[1],after) || before!=after) continue;
            if (!complete) return result;
            result.valid=values[0]==1;
            result.track=values[1];result.time=values[2];result.terminal=values[3]==1;
            return result;
        }
        return result;
    }
};
}

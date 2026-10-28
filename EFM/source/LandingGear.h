#pragma once
#include "VehicleSystems.h"
#include <array>

namespace RaptorVehicle {
// Single achieved owner, fixed nose/left/right order. Travel/lock thresholds
// and damage-jam response are simulation estimates; native damage mapping and
// door/cable effects remain separately unqualified.
struct GearLeg {
    double position = 0.0;
    double integrity = 1.0;
    bool valid = false;
    bool down_locked() const { return valid && integrity > .5 && position >= .999; }
    bool up_locked() const { return valid && integrity > .5 && position <= .001; }
};
struct LandingGear {
    std::array<GearLeg, 3> legs{};
    void reset(bool down) {
        for (auto& leg : legs) leg = {down ? 1.0 : 0.0, 1.0, true};
    }
    void update(double dt, bool down, double authority, const std::array<double, 3>& health) {
        if (!within(dt, 0.0, 1.0) || dt == 0 || !within(authority, 0.0, 1.0)) return;
        for (std::size_t index = 0; index < legs.size(); ++index) {
            auto& leg = legs[index];
            leg.valid = within(leg.position, 0.0, 1.0) && within(health[index], 0.0, 1.0);
            leg.integrity = leg.valid ? health[index] : 0.0;
            if (leg.valid && leg.integrity > .5)
                leg.position = slew(leg.position, down ? 1.0 : 0.0, .25 * authority, dt);
        }
    }
    std::array<double, 3> positions() const {
        return {legs[0].position, legs[1].position, legs[2].position};
    }
    double aerodynamic_fraction() const {
        return (legs[0].position + legs[1].position + legs[2].position) / 3.0;
    }
    bool down_locked() const {
        return legs[0].down_locked() && legs[1].down_locked() && legs[2].down_locked();
    }
    bool up_locked() const {
        return legs[0].up_locked() && legs[1].up_locked() && legs[2].up_locked();
    }
    bool unsafe() const { return !down_locked() && !up_locked(); }
    double demand(bool down) const {
        double result = 0;
        for (const auto& leg : legs)
            if (leg.valid && leg.integrity > .5 && std::abs(leg.position - (down ? 1.0 : 0.0)) > .01)
                result += .2 / 3.0;
        return result;
    }
};
}

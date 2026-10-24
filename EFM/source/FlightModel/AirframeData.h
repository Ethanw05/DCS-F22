// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Math.h"

// Source/assumption ledger: docs/FLIGHT_MODEL.md. These are simulation parameters,
// not a recovered F-22 aerodynamic database or F119 installed engine deck.
namespace f22::data {
constexpr double area = 78.04;       // m², public aircraft geometry (R27)
constexpr double span = 13.56;       // m, public geometry
constexpr double chord = 5.8;       // m, assumed aerodynamic reference chord
constexpr double internalCapacity = 8200.0; // kg, approximate public capacity (R153)
constexpr double reserveFuel = 25.0; // kg, retained unusable-fuel approximation
constexpr double dryThrust = 103000.0; // N/engine: ASSUMED, not a manufacturer rating
constexpr double wetThrust = 35000.0 * 4.4482216152605; // N; R25 thrust-class anchor
constexpr double militaryLever = 0.85; // assumed physical throttle detent fraction
constexpr double fanMaxRpm = 12000.0; // assumed shaft scale, not F119 measured RPM
constexpr double coreMaxRpm = 18000.0; // assumed shaft scale
constexpr double nozzleLimit = radians(20.0); // R25; historical rate R65/R126
constexpr double nozzleRate = radians(40.0);
constexpr std::array<double,8> mach = {0,.6,.9,1.2,1.5,1.8,2.0,2.4};
// Continuous surrogate net-thrust factors, including inlet/ram effects. Assumed.
constexpr std::array<double,8> dryFactor = {1,.90,.87,.93,1.12,1.35,1.45,1.35};
constexpr std::array<double,8> wetFactor = {1,1,1.05,1.15,1.35,1.60,1.70,1.65};
constexpr std::array<double,8> parasiteDrag = {.018,.018,.024,.032,.027,.026,.028,.038};
constexpr std::array<double,8> liftSlope = {3.6,3.6,3.5,3.1,2.9,2.7,2.6,2.4};

enum Surface : std::size_t { TailLeft, TailRight, AileronLeft, AileronRight,
    FlaperonLeft, FlaperonRight, RudderLeft, RudderRight, NozzleLeft, NozzleRight, Count };
// Historical travel/no-load rates from R126; signs are trailing-edge down positive.
constexpr std::array<double,Count> lowerDegrees = {-25,-25,-25,-25,-20,-20,-30,-30,-20,-20};
constexpr std::array<double,Count> upperDegrees = {30,30,25,25,35,35,30,30,20,20};
constexpr std::array<double,Count> rateDegrees = {60,60,70,70,70,70,80,80,40,40};
// Effective areas, force derivatives and application points are openly assumed.
// All positions use one fixed model origin; CG movement is handled by r x F.
constexpr std::array<Vec3,Count> position = {{{-5.5,0,-2.5},{-5.5,0,2.5},
    {-.5,0,-4.8},{-.5,0,4.8},{-.8,0,-3.5},{-.8,0,3.5},
    {-5.8,1.5,-1.8},{-5.8,1.5,1.8},{-3.793,0,-.716},{-3.793,0,.716}}};
constexpr std::array<double,8> forceAreaSlope = {27,27,8,8,12,12,15,15}; // m²/rad
} // namespace f22::data

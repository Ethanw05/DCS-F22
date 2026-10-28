// GPL-3.0-or-later. Estimated noise-jammer propagation; independent of native ECM state.
#pragma once
#include "AesaRadar.h"
#include <algorithm>
#include <cmath>

namespace AesaReceiver {
// Native ECM strength has no supplied RF units or spectrum. These are explicit
// game assumptions: co-channel equivalent noise, 4 J/N at 80 km and strength 1,
// Gaussian receive mainbeam, -40 dB sidelobe floor, -60 dB rear element gain.
inline constexpr double survey_range_m = 300000;
inline constexpr unsigned maximum_sources = 8;
inline constexpr unsigned maximum_visits = 256;
inline bool noise_ratio(const AesaRadar::Pose& pose, const AesaRadar::Beam& beam,
                        AesaRadar::Vector position, double strength, double& result) noexcept {
    result = 0;
    const auto delta = position - pose.position;
    const double range = AesaRadar::length(delta);
    if (!AesaRadar::finite(delta) || !std::isfinite(strength) || strength < 0 || strength > 100
        || !AesaRadar::finite(beam.direction) || !std::isfinite(beam.half_angle)
        || beam.half_angle <= 0 || range <= 0) return false;
    if (range > survey_range_m) return true;
    const auto direction = delta * (1 / range);
    const double angle = std::acos(std::clamp(AesaRadar::dot(direction, beam.direction), -1.0, 1.0));
    const double widths = angle / beam.half_angle;
    const double mainbeam = std::max(.0001, std::exp(-std::log(2.0) * widths * widths));
    const double element = std::max(.000001, AesaRadar::dot(direction, pose.forward));
    const double distance = 80000 / std::max(40.0, range);
    result = 4 * strength * distance * distance * mainbeam * element;
    return std::isfinite(result);
}
}

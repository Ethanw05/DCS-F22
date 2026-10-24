#pragma once
#include <algorithm>
#include <cmath>

// Numerical regularization ONLY. This is not a CFD or wind-tunnel-derived
// F-22 production coefficient model. See resources/research/HIGH_ALPHA_CONTINUITY.md.
namespace RaptorAero
{
    inline double SmoothUnit(double t)
    {
        t = std::clamp(t, 0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
    }

    inline double VortexLiftCorrection(double alpha_degrees)
    {
        if (!std::isfinite(alpha_degrees)) return 0.0;
        const double absolute_alpha = std::fabs(alpha_degrees);
        const double fade_in = SmoothUnit((absolute_alpha - 15.0) / 5.0);
        const double fade_out = SmoothUnit((65.0 - absolute_alpha) / 5.0);
        const double delta = absolute_alpha - 35.0;
        const double gaussian = 0.72 * std::exp(-(delta * delta) / 1200.0);
        return gaussian * fade_in * fade_out;
    }
}

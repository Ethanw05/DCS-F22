#include "HighAlpha.h"
#include <stdexcept>
#include <cmath>
#include <iostream>

static void require(bool condition, const char* error)
{
    if (!condition) throw std::runtime_error(error);
}
int main()
{
    using RaptorAero::VortexLiftCorrection;
    for (double alpha = -180.0; alpha <= 180.0; alpha += 0.01) {
        const double boost = VortexLiftCorrection(alpha);
        require(std::isfinite(boost), "Nonfinite vortex proxy");
        require(boost >= 0.0 && boost <= 0.72 + 1e-12, "Proxy out of bounds");
        require(std::fabs(boost - VortexLiftCorrection(-alpha)) < 1e-12, "AoA symmetry broken");
    }
    require(VortexLiftCorrection(10.0) == 0.0, "10-degree residual");
    require(VortexLiftCorrection(15.0) == 0.0, "15-degree residual");
    require(VortexLiftCorrection(65.0) == 0.0, "65-degree residual");
    require(VortexLiftCorrection(75.0) == 0.0, "75-degree residual");
    require(std::fabs(VortexLiftCorrection(35.0)-0.72) < 1e-12, "Peak boost changed");
    for (const double boundary : {15.0, 20.0, 60.0, 65.0}) {
        const double lo = VortexLiftCorrection(boundary - 1e-5);
        const double hi = VortexLiftCorrection(boundary + 1e-5);
        require(std::fabs(lo-hi) < 1e-5, "Discontinuous boundary");
    }
    require(VortexLiftCorrection(std::nan("")) == 0.0, "NaN handling");
    std::cout << "F-22 high-alpha proxy numerical continuity: OK\n";
}

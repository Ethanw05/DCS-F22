#include "HighAlpha.h"
#include <cassert>
#include <cmath>
#include <iostream>

int main()
{
    using RaptorAero::VortexLiftCorrection;
    for (double alpha = -180.0; alpha <= 180.0; alpha += 0.01) {
        const double boost = VortexLiftCorrection(alpha);
        assert(std::isfinite(boost));
        assert(boost >= 0.0 && boost <= 0.72 + 1e-12);
        assert(std::fabs(boost - VortexLiftCorrection(-alpha)) < 1e-12);
    }
    assert(VortexLiftCorrection(10.0) == 0.0);
    assert(VortexLiftCorrection(15.0) == 0.0);
    assert(VortexLiftCorrection(65.0) == 0.0);
    assert(VortexLiftCorrection(75.0) == 0.0);
    assert(std::fabs(VortexLiftCorrection(35.0)-0.72) < 1e-12);
    for (const double boundary : {15.0, 20.0, 60.0, 65.0}) {
        const double lo = VortexLiftCorrection(boundary - 1e-5);
        const double hi = VortexLiftCorrection(boundary + 1e-5);
        assert(std::fabs(lo-hi) < 1e-5);
    }
    assert(VortexLiftCorrection(std::nan("")) == 0.0);
    std::cout << "F-22 high-alpha proxy numerical continuity: OK\n";
}

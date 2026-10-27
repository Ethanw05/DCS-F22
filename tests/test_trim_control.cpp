#include "../EFM/source/TrimControl.h"
#include <cassert>
#include <cmath>
#include <limits>

int main() {
    using RaptorTrim::Controller;
    for(int fps:{30,60,120,240}) for(int repeats:{20,60,120}) {
        Controller c;
        c.command(95);
        int next=1;
        for(int i=0;i<fps;++i) {
            if(double(i)/fps>=double(next)/repeats) {c.command(95);++next;}
            c.update(1./fps);
        }
        assert(std::abs(c.pitch-.04)<1e-12);
        c.command(215);const double released=c.pitch;
        assert(c.pitch_busy());
        c.update(.1);assert(c.pitch_busy());
        c.update(.15);assert(!c.pitch_busy());
        c.update(10);assert(c.pitch==released); // release really stops motion
    }
    Controller c;
    c.command(95);for(int i=0;i<1000;++i)c.command(95);
    assert(c.pitch==0); // callback count alone cannot move a control
    c.update(.1);assert(std::abs(c.pitch-.004)<1e-12);
    c.command(96);c.update(.1);assert(std::abs(c.pitch)<1e-12);
    c.update(100);assert(c.pitch==-.25);
    c.command(94);c.command(98);c.update(100);
    assert(c.roll==.2 && c.yaw==.2);
    c.command(97);assert(c.pitch==0 && c.roll==0 && c.yaw==0 && !c.pitch_busy());
    c.command(95);c.update(1,false);assert(c.pitch==0);
    c.update(std::numeric_limits<double>::quiet_NaN());c.update(-1);
    assert(c.pitch==0);
}

#pragma once
#include <algorithm>
#include <cmath>

namespace RaptorTrim {
// Mod tuning in normalized control-command units per second, not real F-22 data.
struct Controller {
    static constexpr double pitch_rate = .04, lateral_rate = .02;
    static constexpr double release_settle = .25;
    double pitch=0, roll=0, yaw=0;
    int pitch_direction=0, roll_direction=0, yaw_direction=0;
    double pitch_settle=0;

    void command(int code) {
        switch(code) {
        case 95: pitch_direction=1; break;
        case 96: pitch_direction=-1; break;
        case 93: roll_direction=-1; break;
        case 94: roll_direction=1; break;
        case 98: yaw_direction=1; break;
        case 99: yaw_direction=-1; break;
        case 215:
            if(pitch_direction) pitch_settle=release_settle;
            pitch_direction=roll_direction=yaw_direction=0;
            break;
        case 97: *this={}; break;
        }
    }
    void update(double dt, bool powered=true) {
        if(!std::isfinite(dt) || dt<=0) return;
        pitch_settle=std::max(0.,pitch_settle-dt);
        if(!powered) return;
        pitch=std::clamp(pitch+pitch_direction*pitch_rate*dt,-.25,.25);
        roll=std::clamp(roll+roll_direction*lateral_rate*dt,-.2,.2);
        yaw=std::clamp(yaw+yaw_direction*lateral_rate*dt,-.2,.2);
    }
    bool pitch_busy() const { return pitch_direction!=0 || pitch_settle>1e-9; }
};
}

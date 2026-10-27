// GPL-3.0-or-later. Conventional fighter relief controller, not production F-22
// laws.
#pragma once
#include <algorithm>
#include <cmath>
namespace RaptorAP {
constexpr double pi = 3.14159265358979323846, rad = pi / 180.;
inline double wrap(double a) { return std::remainder(a, 2 * pi); }
inline double clamp(double x, double lo, double hi) {
  return std::clamp(x, lo, hi);
}
// Calibrated airspeed from the same perfect-gas pitot relation used by the HUD.
inline double pitot(double m) {
  return m <= 1 ? std::pow(1 + .2 * m * m, 3.5)
                : std::pow(1.2 * m * m, 3.5) *
                      std::pow(2.4 / (2.8 * m * m - .4), 2.5);
}
inline double cas(double tas, double sound, double pressure) {
  if (!std::isfinite(tas) || !std::isfinite(sound) ||
      !std::isfinite(pressure) || tas < 0 || sound < 100 || pressure <= 0)
    return NAN;
  double impact = pressure * (pitot(tas / sound) - 1), lo = 0, hi = 10;
  for (int i = 0; i < 45; ++i) {
    double m = (lo + hi) * .5;
    if (101325 * (pitot(m) - 1) < impact)
      lo = m;
    else
      hi = m;
  }
  return (lo + hi) * .5 * 340.293988;
}
enum Roll { Manual = 0, Attitude = 1, Heading = 2, Navigation = 3 };
enum Pitch {
  Off = 0,
  Att = 1,
  Altitude = 2,
  RadarAltitude = 3,
  VerticalSpeed = 4
};
struct Frame {
  double pitch{}, roll{}, heading{}, alt{}, agl{}, vs{}, tas{}, ias{}, mach{},
      aoa{}, track{}, gs{};
  double pilot_pitch{}, pilot_roll{}, left_throttle{}, right_throttle{},
      nav_track{}, nav_time{};
  double time{};
  bool powered{}, ground{true}, gear{true}, healthy{}, nav_valid{};
  bool valid() const {
    return std::isfinite(pitch) && std::isfinite(roll) &&
           std::isfinite(heading) && std::isfinite(alt) && std::isfinite(agl) &&
           std::isfinite(vs) && std::isfinite(tas) && std::isfinite(ias) &&
           std::isfinite(mach) && std::isfinite(aoa) && std::isfinite(gs) &&
           std::isfinite(track) && std::isfinite(time) &&
           std::isfinite(pilot_pitch) && std::isfinite(pilot_roll) &&
           std::isfinite(left_throttle) && std::isfinite(right_throttle);
  }
  bool eligible() const {
    return valid() && powered && !ground && !gear && healthy && ias > 82.31 &&
           std::abs(pitch) < 45 * rad && std::abs(roll) < 70 * rad &&
           std::abs(aoa) < 20 * rad;
  }
  bool navigation() const {
    return nav_valid && std::isfinite(nav_track) && std::isfinite(nav_time) &&
           nav_time <= time + .1 && time - nav_time < .35 && gs > 15;
  }
};
struct Output {
  double elevator{}, aileron{}, throttle{};
  bool throttle_active{};
};
class Controller {
public:
  Roll lateral = Manual;
  Pitch vertical = Off;
  bool at = false, mach_hold = false, override_held = false;
  bool heading_preset=false, altitude_preset=false, vs_preset=false,
       speed_preset=false, mach_preset=false, radar_preset=false;
  double selected_heading = 0, selected_alt = 0, selected_vs = 0,
         selected_speed = 0, selected_mach = 0;
  double captured_pitch = 0, captured_roll = 0, captured_agl = 0, integral = 0,
         throttle_integral = 0;
  double throttle = 0, last_left_throttle = 0, last_right_throttle = 0;
  double last_speed = 0, speed_rate = 0;
  int reason = 0;
  bool active() const { return vertical != Off; }
  void disconnect(int why = 0) {
    lateral = Manual;
    vertical = Off;
    integral = 0;
    reason = why;
  }
  void reset() { *this = Controller{}; }
  bool engage(Pitch p, Roll r, const Frame &f) {
    if (!f.eligible() || (r == Navigation && !f.navigation()) ||
        (p == RadarAltitude && (f.agl < 60 || f.agl > 1524))) {
      reason = 1;
      return false;
    }
    captured_pitch = f.pitch;
    captured_roll = f.roll;
    if(!altitude_preset) selected_alt = f.alt;
    if(!radar_preset) captured_agl = f.agl;
    if(!vs_preset) selected_vs = f.vs;
    vertical = p;
    lateral = r;
    integral = 0;
    reason = 0;
    return true;
  }
  void command(int c, const Frame &f, double value=1) {
    // Editing a selected target never engages a flight mode.
    if(c>=11620&&c<=11625){
      if(!std::isfinite(value))return;
      if(c==11620&&value>=0&&value<360){selected_heading=value*rad;heading_preset=true;}
      else if(c==11621&&value>=0&&value<=65000){selected_alt=value/3.280839895;altitude_preset=true;}
      else if(c==11622&&std::abs(value)<=6000){selected_vs=value/196.850394;vs_preset=true;}
      else if(c==11623&&value>=160&&value<=700){selected_speed=value/1.943844492;speed_preset=true;}
      else if(c==11624&&value>=.2&&value<=2){selected_mach=value;mach_preset=true;}
      else if(c==11625&&value>=200&&value<=5000){captured_agl=value/3.280839895;radar_preset=true;}
      return;
    }
    // IDs retained from the original EFM, plus dedicated selections.
    if (c == 408 || c == 538 || c == 11603) {
      disconnect();
      at = false;
      override_held = false;
      return;
    }
    if (c == 427 || c == 11611) {
      override_held = true;
      integral = 0;
      return;
    }
    if (c == 428 || c == 11612) {
      override_held = false;
      if (active()) {
        captured_pitch = f.pitch;
        captured_roll = f.roll;
        if (vertical == Altitude) {
          selected_alt = f.alt;
          altitude_preset=false;
        }
        if (vertical == RadarAltitude) {
          captured_agl = f.agl;
          radar_preset=false;
        }
      }
      return;
    }
    if (c == 11606) {
      if(!heading_preset)selected_heading=f.heading;
      selected_heading = wrap(selected_heading - rad);
      heading_preset=true;
      return;
    }
    if (c == 11607) {
      if(!heading_preset)selected_heading=f.heading;
      selected_heading = wrap(selected_heading + rad);
      heading_preset=true;
      return;
    }
    if (c == 11608) {
      if(!altitude_preset)selected_alt=f.alt;
      selected_alt = clamp(selected_alt - 30.48, 0, 19812);
      altitude_preset=true;
      return;
    }
    if (c == 11609) {
      if(!altitude_preset)selected_alt=f.alt;
      selected_alt = clamp(selected_alt + 30.48, 0, 19812);
      altitude_preset=true;
      return;
    }
    if (c == 11613) {
      if(!vs_preset)selected_vs=f.vs;
      selected_vs = clamp(selected_vs - .508, -30.48, 30.48);
      vs_preset=true;
      return;
    }
    if (c == 11614) {
      if(!vs_preset)selected_vs=f.vs;
      selected_vs = clamp(selected_vs + .508, -30.48, 30.48);
      vs_preset=true;
      return;
    }
    if (c == 11615) {
      if(!speed_preset)selected_speed=f.ias;
      if(!mach_preset)selected_mach=f.mach;
      selected_speed = clamp(selected_speed - 2.57222, 82.31, 360);
      selected_mach = clamp(selected_mach - .01, .2, 2);
      speed_preset=mach_preset=true;
      return;
    }
    if (c == 11616) {
      if(!speed_preset)selected_speed=f.ias;
      if(!mach_preset)selected_mach=f.mach;
      selected_speed = clamp(selected_speed + 2.57222, 82.31, 360);
      selected_mach = clamp(selected_mach + .01, .2, 2);
      speed_preset=mach_preset=true;
      return;
    }
    if (c == 11617) {
      if (std::isfinite(f.heading)) {
        selected_heading = f.heading;
        heading_preset=true;
      }
      return;
    }
    if (c == 11602 || c == 11618) {
      if (at && mach_hold==(c==11618)) {
        at = false;
        return;
      }
      if (!f.eligible()) {
        reason = 1;
        return;
      }
      at = true;
      mach_hold = c == 11618;
      if(!speed_preset)selected_speed = f.ias;
      if(!mach_preset)selected_mach = f.mach;
      throttle = (f.left_throttle + f.right_throttle) * .5;
      last_left_throttle = f.left_throttle;
      last_right_throttle = f.right_throttle;
      throttle_integral = throttle;
      last_speed = mach_hold ? f.mach * 180. : f.ias;
      speed_rate = 0;
      return;
    }
    if (c == 11600 || c == 389) {
      engage(Altitude, active() ? lateral : Attitude, f);
      return;
    }
    if (c == 11601 || c == 62) {
      if (active() && vertical == Att && lateral == Attitude)
        disconnect();
      else
        engage(Att, Attitude, f);
      return;
    }
    if (c == 11604) {
      if (!f.eligible()) {
        reason = 1;
        return;
      }
      if(!heading_preset)selected_heading=f.heading;
      if (active()) {
        lateral = Heading;
        reason = 0;
      } else
        engage(Altitude, Heading, f);
      return;
    }
    if (c == 11605 || c == 429) {
      if (!f.eligible() || !f.navigation()) {
        reason = 1;
        return;
      }
      if (active()) {
        lateral = Navigation;
        reason = 0;
      } else
        engage(Altitude, Navigation, f);
      return;
    }
    if (c == 11610) {
      engage(RadarAltitude, active() ? lateral : Attitude, f);
      return;
    }
    if (c == 11619) {
      engage(VerticalSpeed, active() ? lateral : Attitude, f);
      return;
    }
  }
  Output update(const Frame &f, double dt) {
    Output o{};
    if (!(std::isfinite(dt) && dt > 0 && dt <= .1)) {
      disconnect(2);
      at = false;
      return o;
    }
    if (!std::isfinite(selected_heading) || !std::isfinite(selected_alt) ||
        !std::isfinite(selected_vs) || !std::isfinite(selected_speed) ||
        !std::isfinite(selected_mach) || !std::isfinite(integral)) {
      disconnect(2);
      at = false;
      return o;
    }
    if (!f.eligible()) {
      if (active() || at)
        reason = 2;
      disconnect(reason);
      at = false;
      return o;
    }
    if (active() &&
        (std::abs(f.pilot_pitch) > .18 || std::abs(f.pilot_roll) > .18) &&
        !override_held)
      disconnect(3);
    if (lateral == Navigation && !f.navigation()) {
      disconnect(4);
    }
    if (vertical == RadarAltitude &&
        (f.agl < 60 || f.agl > 1524 || std::abs(f.roll) > 45 * rad)) {
      disconnect(5);
    }
    if (active() && !override_held) {
      double roll_target = captured_roll, pitch_target = captured_pitch;
      if (lateral == Heading || lateral == Navigation) {
        const double error =
            wrap((lateral == Heading ? selected_heading : f.nav_track) -
                 (lateral == Heading ? f.heading : f.track));
        roll_target = clamp(error * 1.2, -30 * rad, 30 * rad);
      }
      if (vertical != Att) {
        double target_vs = selected_vs;
        if (vertical == Altitude)
          target_vs = clamp((selected_alt - f.alt) * .12, -15.24, 15.24);
        if (vertical == RadarAltitude)
          target_vs = clamp((captured_agl - f.agl) * .10, -10.16, 10.16);
        pitch_target = clamp(
            f.aoa + std::asin(clamp(target_vs / std::max(f.tas, 80.), -.3, .3)),
            -15 * rad, 25 * rad);
      }
      const double error = pitch_target - f.pitch;
      const double raw = error * 2.4 + integral;
      if (std::abs(raw) < .40 || raw * error < 0)
        integral = clamp(integral + error * .30 * dt, -.30, .30);
      o.elevator = clamp(error * 2.4 + integral, -.40, .40);
      o.aileron = clamp((roll_target - f.roll) * 1.6, -.40, .40);
    }
    if (at) {
      if (std::abs(f.left_throttle - last_left_throttle) > .08 ||
          std::abs(f.right_throttle - last_right_throttle) > .08) {
        at = false;
        return o;
      }
      const double error = mach_hold ? (selected_mach - f.mach) * 180.
                                     : (selected_speed - f.ias);
      const double measured = mach_hold ? f.mach * 180. : f.ias;
      speed_rate +=
          ((measured - last_speed) / dt - speed_rate) * std::min(dt, 1.);
      last_speed = measured;
      // Dampen the speed trend during engine spool changes and vertical-mode
      // transitions.
      const double raw = throttle_integral + error * .030 - speed_rate * .080;
      if ((raw > .02 && raw < .80) || raw < .02 && error > 0 ||
          raw > .80 && error < 0)
        throttle_integral =
            clamp(throttle_integral + error * .0015 * dt, .02, .80);
      const double target =
          clamp(throttle_integral + error * .030 - speed_rate * .080, .02, .80);
      throttle += clamp(target - throttle, -.12 * dt, .12 * dt);
      o.throttle = throttle;
      o.throttle_active = true;
    }
    return o;
  }
};
} // namespace RaptorAP

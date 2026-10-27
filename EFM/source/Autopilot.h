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
  bool nav_arrived{false};
  bool baro_valid{true}, radar_valid{true}, heading_valid{true}, airspeed_valid{true};
  bool valid() const {
    return std::isfinite(pitch) && std::isfinite(roll) && std::isfinite(time) &&
           std::isfinite(pilot_pitch) && std::isfinite(pilot_roll) &&
           std::isfinite(left_throttle) && std::isfinite(right_throttle);
  }
  bool pitch_source(Pitch mode) const {
    if (mode == Off || mode == Att) return true;
    if (!std::isfinite(vs) || !std::isfinite(tas) || tas < 1) return false;
    if (mode == Altitude) return baro_valid && std::isfinite(alt);
    if (mode == RadarAltitude) return radar_valid && std::isfinite(agl) && agl >= 60 && agl <= 1524;
    return mode == VerticalSpeed;
  }
  bool eligible() const {
    return valid() && powered && !ground && !gear && healthy && airspeed_valid &&
           std::isfinite(ias) && std::isfinite(aoa) && ias > 82.31 &&
           std::abs(pitch) < 45 * rad && std::abs(roll) < 70 * rad &&
           std::abs(aoa) < 20 * rad;
  }
  bool navigation() const {
    return nav_valid && std::isfinite(nav_track) && std::isfinite(nav_time) &&
           nav_time <= time + .1 && time - nav_time < .35 &&
           std::isfinite(track) && std::isfinite(gs) && gs > 15;
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
  int reason = 0, at_reason = 0;
  double at_feedback_until = 0;
  bool nav_override = false, pitch_limited = false, roll_limited = false, at_limited = false;
  bool active() const { return vertical != Off || lateral != Manual; }
  void disconnect(int why = 0) {
    lateral = Manual;
    vertical = Off;
    integral = 0;
    reason = why;
    nav_override = false;
  }
  void reset() { *this = Controller{}; }
  bool engage(Pitch p, Roll r, const Frame &f) {
    if (!f.eligible() || !f.pitch_source(p) || (r == Navigation && !f.navigation()) ||
        (r == Heading && (!f.heading_valid || !std::isfinite(f.heading)))) {
      reason = 1;
      return false;
    }
    captured_pitch = f.pitch;
    captured_roll = f.roll;
    if(p == Altitude && !altitude_preset) selected_alt = f.alt;
    if(p == RadarAltitude && !radar_preset) captured_agl = f.agl;
    if(p == VerticalSpeed && !vs_preset) selected_vs = f.vs;
    vertical = p;
    lateral = r;
    integral = 0;
    reason = 0;
    return true;
  }
  void end_throttle(int why, double now) {
    at = false;
    throttle_integral = 0;
    at_reason = why;
    at_feedback_until = why ? now + 10 : 0;
  }
  void target_command(int c, double value) {
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
  }
  void override_command(int c, const Frame &f) {
    // IDs retained from the original EFM, plus dedicated selections.
    if (c == 408 || c == 538 || c == 11603) {
      disconnect();
      end_throttle(0, f.time);
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
  }
  void step_heading(int command, const Frame &f) {
    if (!heading_preset) {
      if (!f.heading_valid || !std::isfinite(f.heading)) return;
      selected_heading = f.heading;
    }
    selected_heading = wrap(selected_heading + (command == 11606 ? -rad : rad));
    heading_preset = true;
  }
  void step_vertical(int command, const Frame &f) {
    if (command == 11608 || command == 11609) {
      if (!altitude_preset) {
        if (!f.baro_valid || !std::isfinite(f.alt)) return;
        selected_alt = f.alt;
      }
      selected_alt = clamp(selected_alt + (command == 11608 ? -30.48 : 30.48), 0, 19812);
      altitude_preset = true;
    } else {
      if (!vs_preset) {
        if (!std::isfinite(f.vs)) return;
        selected_vs = f.vs;
      }
      selected_vs = clamp(selected_vs + (command == 11613 ? -.508 : .508), -30.48, 30.48);
      vs_preset = true;
    }
  }
  void step_speed(int command, const Frame &f) {
    const double direction = command == 11615 ? -1. : 1.;
    if (mach_hold) {
      if (!mach_preset) {
        if (!std::isfinite(f.mach)) return;
        selected_mach = f.mach;
      }
      selected_mach = clamp(selected_mach + direction * .01, .2, 2);
      mach_preset = true;
    } else {
      if (!speed_preset) {
        if (!f.airspeed_valid || !std::isfinite(f.ias)) return;
        selected_speed = f.ias;
      }
      selected_speed = clamp(selected_speed + direction * 2.57222, 82.31, 360);
      speed_preset = true;
    }
  }
  void throttle_command(int c, const Frame &f) {
    if (c == 11602 || c == 11618) {
      if (at && mach_hold==(c==11618)) {
        end_throttle(0, f.time);
        return;
      }
      if (!f.eligible() || (c == 11618 && !std::isfinite(f.mach))) {
        end_throttle(1, f.time);
        return;
      }
      at = true;
      at_reason = 0;
      at_feedback_until = 0;
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
  }
  void mode_command(int c, const Frame &f) {
    if (c == 11600 || c == 389) {
      engage(Altitude, lateral, f);
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
      engage(vertical, Heading, f);
      return;
    }
    if (c == 11605 || c == 429) {
      if (!f.eligible() || !f.navigation()) {
        reason = 1;
        return;
      }
      engage(vertical, Navigation, f);
      return;
    }
    if (c == 11610) {
      engage(RadarAltitude, lateral, f);
      return;
    }
    if (c == 11619) {
      engage(VerticalSpeed, lateral, f);
      return;
    }
  }
  void command(int c, const Frame &f, double value=1) {
    if (c == 11626) { reason = 0; at_reason = 0; at_feedback_until = 0; return; }
    if (c >= 11620 && c <= 11625) { target_command(c, value); return; }
    if (c == 408 || c == 538 || c == 11603 || c == 427 || c == 428 || c == 11611 || c == 11612) {
      override_command(c, f); return;
    }
    if (c == 11606 || c == 11607) { step_heading(c, f); return; }
    if (c == 11608 || c == 11609 || c == 11613 || c == 11614) { step_vertical(c, f); return; }
    if (c == 11615 || c == 11616) { step_speed(c, f); return; }
    if (c == 11617) {
      if (f.heading_valid && std::isfinite(f.heading)) { selected_heading = f.heading; heading_preset = true; }
      return;
    }
    if (c == 11602 || c == 11618) { throttle_command(c, f); return; }
    mode_command(c, f);
  }
  double roll_output(const Frame &f) {
    if (lateral == Manual || override_held || nav_override) return 0;
    double target = captured_roll;
    if (lateral == Heading || lateral == Navigation) {
      const double error = wrap((lateral == Heading ? selected_heading : f.nav_track) -
                                (lateral == Heading ? f.heading : f.track));
      const double requested = error * 1.2;
      target = clamp(requested, -30 * rad, 30 * rad);
      roll_limited = std::abs(requested) > 30 * rad;
    }
    return clamp((target - f.roll) * 1.6, -.40, .40);
  }
  double pitch_output(const Frame &f, double dt) {
    if (vertical == Off || override_held) return 0;
    double target = captured_pitch;
    if (vertical != Att) {
      double target_vs = selected_vs;
      if (vertical == Altitude) target_vs = clamp((selected_alt - f.alt) * .12, -15.24, 15.24);
      if (vertical == RadarAltitude) target_vs = clamp((captured_agl - f.agl) * .10, -10.16, 10.16);
      target = clamp(f.aoa + std::asin(clamp(target_vs / std::max(f.tas, 80.), -.3, .3)), -15 * rad, 25 * rad);
    }
    const double error = target - f.pitch;
    const double raw = error * 2.4 + integral;
    pitch_limited = std::abs(raw) >= .40;
    if (std::abs(raw) < .40 || raw * error < 0) integral = clamp(integral + error * .30 * dt, -.30, .30);
    return clamp(error * 2.4 + integral, -.40, .40);
  }
  void throttle_output(const Frame &f, double dt, Output &o) {
    if (at) {
      if (std::abs(f.left_throttle - last_left_throttle) > .08 ||
          std::abs(f.right_throttle - last_right_throttle) > .08) {
        end_throttle(3, f.time);
        return;
      }
      if (mach_hold && !std::isfinite(f.mach)) { end_throttle(2, f.time); return; }
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
      at_limited = raw <= .02 || raw >= .80;
      const double target =
          clamp(throttle_integral + error * .030 - speed_rate * .080, .02, .80);
      throttle += clamp(target - throttle, -.12 * dt, .12 * dt);
      o.throttle = throttle;
      o.throttle_active = true;
    }
  }
  Output update(const Frame &f, double dt) {
    Output o{};
    pitch_limited = roll_limited = at_limited = false;
    if (!(std::isfinite(dt) && dt > 0 && dt <= .1) || !f.eligible()) {
      if (active()) disconnect(2);
      if (at) end_throttle(2, f.time);
      return o;
    }
    if (!std::isfinite(selected_heading) || !std::isfinite(selected_alt) ||
        !std::isfinite(selected_vs) || !std::isfinite(selected_speed) ||
        !std::isfinite(selected_mach) || !std::isfinite(integral)) {
      disconnect(2); end_throttle(2, f.time); return o;
    }
    if (!override_held && std::abs(f.pilot_pitch) > .18 && vertical != Off) {
      vertical = Off; integral = 0; reason = 3;
    }
    if (lateral == Navigation && f.nav_arrived && f.navigation() &&
        f.heading_valid && std::isfinite(f.heading)) {
      selected_heading=f.heading;heading_preset=true;lateral=Heading;nav_override=false;
    }
    if (lateral == Navigation) {
      if (std::abs(f.pilot_roll) > .18) nav_override = true;
      else if (std::abs(f.pilot_roll) < .12) nav_override = false;
      if (!f.navigation()) { lateral = Manual; nav_override = false; reason = 4; }
    } else if (!override_held && std::abs(f.pilot_roll) > .18 && lateral != Manual) {
      lateral = Manual; reason = 3;
    }
    if (lateral == Heading && (!f.heading_valid || !std::isfinite(f.heading))) {
      lateral = Manual; reason = 6;
    }
    if (!f.pitch_source(vertical) || (vertical == RadarAltitude && std::abs(f.roll) > 45 * rad)) {
      vertical = Off; integral = 0; reason = 5;
    }
    o.elevator = pitch_output(f, dt);
    o.aileron = roll_output(f);
    if (at) throttle_output(f, dt, o);
    return o;
  }
};
} // namespace RaptorAP

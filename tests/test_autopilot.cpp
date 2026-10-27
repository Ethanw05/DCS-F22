// GPL-3.0-or-later. Controller state, feedback, freshness and takeover checks.
#include "../EFM/source/Autopilot.h"
#include "../EFM/source/CommandRouting.h"
#include <cstdlib>
#include <iostream>
#define CHECK(c)                                                               \
  do {                                                                         \
    if (!(c)) {                                                                \
      std::cerr << "FAIL " << __LINE__ << ": " << #c << '\n';                  \
      std::exit(1);                                                            \
    }                                                                          \
  } while (0)
int main() {
  using namespace RaptorAP;
  Frame f;
  f.powered = f.healthy = true;
  f.ground = f.gear = false;
  f.tas = 220;
  f.ias = 180;
  f.alt = 3000;
  f.agl = 1000;
  f.mach = .65;
  f.time = 100;
  f.nav_time = 100;
  f.nav_valid = true;
  f.gs = 220;
  f.left_throttle = f.right_throttle = .6;
  CHECK(std::abs(cas(170.146994, 340.293988, 101325) - 170.146994) < 1e-6);
  CHECK(cas(220, 320, 50000) < 220);
  for (int light = 10505; light <= 10512; ++light) CHECK(RaptorCommands::afcs(light) == 0);
  for (int light = 11905; light <= 11912; ++light) CHECK(RaptorCommands::afcs(light) == 0);
  CHECK(RaptorCommands::afcs(10500) == 11600);
  CHECK(RaptorCommands::afcs(11605) == 11605);
  CHECK(RaptorCommands::target_valid(11010, 0));
  CHECK(!RaptorCommands::target_valid(11010, 360));
  CHECK(!RaptorCommands::target_valid(11010, NAN));
  Controller c;
  c.command(11600, f);
  CHECK(c.active() && c.vertical == Altitude && c.selected_alt == 3000);
  f.alt = 2900;
  auto o = c.update(f, .01);
  CHECK(o.elevator > 0);
  f.alt = 3100;
  o = c.update(f, .01);
  CHECK(o.elevator < 0);
  f.alt = 3000;
  c.command(11620,f,359);
  c.command(11604, f);
  f.heading = rad;
  o = c.update(f, .01);
  CHECK(o.aileron < 0 && o.aileron > -.1);
  c.command(11620,f,1);
  f.heading = 359 * rad;
  o = c.update(f, .01);
  CHECK(o.aileron > 0 && o.aileron < .1);
  c.command(11605, f);
  CHECK(c.lateral == Navigation);
  f.nav_track = 30 * rad;
  f.track = 0;
  o = c.update(f, .01);
  CHECK(o.aileron > 0);
  f.time = 101;
  o = c.update(f, .01);
  CHECK(!c.active() && c.reason == 4 && o.aileron == 0);
  f.nav_time = f.time;
  c.command(11600, f);
  f.pilot_pitch = .3;
  o = c.update(f, .01);
  CHECK(!c.active() && o.elevator == 0);
  f.pilot_pitch = 0;
  c.command(11600, f);
  c.command(11611, f);
  f.pilot_pitch = .5;
  o = c.update(f, .01);
  CHECK(c.active() && o.elevator == 0);
  f.alt = 3400;
  f.pilot_pitch = 0;
  c.command(11612, f);
  CHECK(c.selected_alt == 3400);
  c.command(11610, f);
  CHECK(c.vertical == RadarAltitude);
  f.agl = 50;
  o = c.update(f, .01);
  CHECK(!c.active());
  f.agl = 1000;
  c.command(11602, f);
  CHECK(c.at);
  f.ias = 160;
  o = c.update(f, .01);
  CHECK(o.throttle_active && o.throttle > .6 && o.throttle <= .8);
  f.left_throttle = .9;
  f.right_throttle = .9;
  o = c.update(f, .01);
  CHECK(!c.at);
  f.left_throttle = f.right_throttle = .6;
  c.command(11618, f);
  CHECK(c.at && c.mach_hold);
  c.command(408, f);
  CHECK(!c.active() && !c.at);
  // Same speed error, increasing measured speed must produce less throttle than
  // steady speed.
  Controller steady, accelerating;
  Frame slower = f;
  slower.ias -= .1;
  steady.command(11602, f);
  accelerating.command(11602, slower);
  accelerating.selected_speed = steady.selected_speed;
  auto damped = accelerating.update(f, .1);
  auto stable = steady.update(f, .1);
  CHECK(damped.throttle < stable.throttle);
  c.reset();
  f.gear = true;
  c.command(11600, f);
  CHECK(!c.active() && c.reason == 1);
  f.gear = false;
  c.command(11601, f);
  f.powered = false;
  o = c.update(f, .01);
  CHECK(!c.active() && !o.throttle_active);
  f.powered = true;
  c.command(11600, f);
  f.alt = NAN;
  o = c.update(f, .01);
  CHECK(!c.active() && std::isfinite(o.elevator));
  f.alt=3000;f.powered=f.healthy=true;f.gear=f.ground=false;
  Controller targets;
  targets.command(11621,f,15000);
  CHECK(!targets.active()&&std::abs(targets.selected_alt*3.280839895-15000)<1e-6);
  targets.command(11600,f);
  CHECK(std::abs(targets.selected_alt*3.280839895-15000)<1e-6);
  targets.command(11620,f,0);targets.command(11604,f);
  CHECK(targets.lateral==Heading&&targets.selected_heading==0);
  targets.command(11621,f,NAN);targets.command(11621,f,-100);
  CHECK(std::abs(targets.selected_alt*3.280839895-15000)<1e-6);
  targets.command(11622,f,-1500);targets.command(11619,f);
  CHECK(targets.vertical==VerticalSpeed&&std::abs(targets.selected_vs*196.850394+1500)<1e-6);
  targets.command(11625,f,1200);targets.command(11610,f);
  CHECK(targets.vertical==RadarAltitude&&std::abs(targets.captured_agl*3.280839895-1200)<1e-6);
  targets.command(11623,f,300);targets.command(11602,f);
  CHECK(targets.at&&!targets.mach_hold&&std::abs(targets.selected_speed*1.943844492-300)<1e-6);
  targets.command(11624,f,.8);targets.command(11618,f);
  CHECK(targets.at&&targets.mach_hold&&targets.selected_mach==.8);
  targets.command(11618,f);CHECK(!targets.at);
  std::cout << "AFCS holds, wrap, navigation age, pilot takeover, paddle, "
               "limits, A/T and fault gates PASS\n";
}

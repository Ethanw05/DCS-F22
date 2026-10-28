// GPL-3.0-or-later. Exercise the production GMT scene query and measurement
// pipeline with substituted DCS services, not an injected display contact.
#include "../EFM/source/NativeGroundSensor.cpp"
#include <iostream>
#include <stdexcept>
#define CHECK(x)                                                                                             \
  do {                                                                                                       \
    if (!(x))                                                                                                \
      throw std::runtime_error(#x);                                                                          \
  } while (0)
namespace {
using namespace NativeGroundSensor;
double now = 10;
bool terrain_clear = true, present = true;
Vec target{6000, 0, 0};
VecF speed{10, 0, 0};
std::array<void *, 64> own_methods{}, target_methods{};
std::array<void *, 41> la_methods{};
std::array<void *, 25> manager_methods{};
std::array<void *, 14> land_methods{};
std::array<void *, 8> scene_methods{}, registered_methods{}, response_methods{};
struct Object {
  void **table{};
};
struct Unit {
  void **table{};
  std::array<std::byte, 112> pad{};
  void **scene_table{};
};
Unit own_unit{own_methods.data(), {}, scene_methods.data()};
Object target_unit{target_methods.data()}, la{la_methods.data()}, manager{manager_methods.data()},
    land{land_methods.data()}, scene{scene_methods.data()}, registered{registered_methods.data()},
    response{response_methods.data()};
void *manager_pointer = &manager;
void *land_pointer = &land;
double time_now() {
  return now;
}
void *aircraft_object() {
  return &la;
}
void *own_object(void *) {
  return &own_unit;
}
unsigned object_id(void *object) {
  return object == &scene ? 42u : 1u;
}
void *registration(void *) {
  return &registered;
}
void *unit(void *) {
  return &target_unit;
}
void *get_response(void *) {
  return &response;
}
float rcs(void *, float, const VecF &) {
  return 10;
}
const float *basis(void *) {
  static float p[16]{1, 0, 0};
  return p;
}
Vec *position(void *object, Vec *out) {
  *out = object == &own_unit ? Vec{0, 1000, 0} : target;
  return out;
}
const VecF *velocity(const void *object) {
  static VecF own_speed{200, 0, 0};
  return object == &own_unit ? &own_speed : &speed;
}
const unsigned char *kind(const void *) {
  static unsigned char value[]{2, 1, 1, 1};
  return value;
}
bool dead(const void *) {
  return false;
}
bool flag(const void *, int) {
  return present;
}
void *camera_construct(void *destination, int) {
  std::memset(destination, 0, 784);
  return destination;
}
const void *clip(const void *object) {
  return object;
}
bool ray(void *, const VecF &from, const VecF &direction, float maximum, VecF *out) {
  if (!terrain_clear || direction.u >= 0)
    return false;
  const auto distance = -from.u / direction.u;
  if (distance > maximum)
    return false;
  *out = {from.n + distance * direction.n, 0, from.e + distance * direction.e};
  return true;
}
const char *intersection(const Scene &, const Vec &, const Vec &, Vec &, double &, Vec &) {
  return nullptr;
}
void query(void *, const void *, unsigned, const Query &visit) {
  (void)visit(*reinterpret_cast<Scene *>(&scene));
}
void segment(void *, const Vec &, const Vec &, unsigned, const Query &) {
}
void setup() {
  reset();
  now = 10;
  terrain_clear = true;
  present = true;
  target = {6000, 0, 0};
  speed = {10, 0, 0};
  la_methods[40] = reinterpret_cast<void *>(&own_object);
  scene_methods[1] = reinterpret_cast<void *>(&object_id);
  scene_methods[6] = reinterpret_cast<void *>(&registration);
  registered_methods[7] = reinterpret_cast<void *>(&unit);
  manager_methods[19] = reinterpret_cast<void *>(&query);
  manager_methods[24] = reinterpret_cast<void *>(&segment);
  land_methods[13] = reinterpret_cast<void *>(&ray);
  target_methods[59] = reinterpret_cast<void *>(&get_response);
  response_methods[6] = reinterpret_cast<void *>(&rcs);
  api.clock = time_now;
  api.aircraft = aircraft_object;
  api.point = position;
  api.velocity = velocity;
  api.type = kind;
  api.dead = dead;
  api.flag = flag;
  api.position = basis;
  api.camera = camera_construct;
  api.clip = clip;
  api.manager = &manager_pointer;
  api.land = &land_pointer;
  api.intersect = intersection;
  api.ready = true;
  api.reason = 0;
  controls = {};
  controls.active = true;
  controls.search = true;
  controls.resource = 1;
  controls.range = 20 * 1852;
}
void step(bool grant = true, bool on_target = true) {
  now += .1;
  target.n += speed.n * .1;
  controls.stamp = now;
  ArrayService service{};
  service.active = true;
  service.granted = grant;
  service.resource = 1;
  const double range = length(target - Vec{0, 1000, 0});
  service.beam.direction =
      on_target ? AesaRadar::Vector{target.n / range, -1000 / range, 0} : AesaRadar::Vector{0, -1, 0};
  service.beam.range_m = 20 * 1852;
  service.beam.half_angle = 3 * pi / 180;
  service.beam.started = now - .02;
  service.beam.completes = now;
  service.beam.surface = true;
  sample(&la, service);
}
void detection_and_memory() {
  setup();
  step();
  CHECK(output.contacts.empty()); // finite processing delay
  for (unsigned i = 0; i < 8; ++i)
    step();
  CHECK(output.contacts.size() == 1);
  const auto moving = output.contacts[0];
  CHECK(moving.id == 42 && moving.velocity_valid && moving.filter_valid && moving.hits >= 2);
  CHECK(std::abs(moving.velocity.n - 10) < 5);
  CHECK(moving.point.n != target.n && moving.position_sigma_m > 0);
  const auto queries = output.queries;
  for (unsigned i = 0; i < 3; ++i)
    step(false); // release last real pending return
  const auto stamp = output.contacts[0].stamp;
  for (unsigned i = 0; i < 8; ++i)
    step(false);
  CHECK(output.queries == queries && output.contacts[0].stamp == stamp);
  for (unsigned i = 0; i < 310; ++i)
    step(false);
  CHECK(output.contacts.empty());
}
void rejection_and_track() {
  setup();
  terrain_clear = false;
  for (unsigned i = 0; i < 5; ++i)
    step();
  CHECK(output.contacts.empty() && output.terrain_rejects > 0);
  terrain_clear = true;
  speed = {0, 0, 0};
  for (unsigned i = 0; i < 5; ++i)
    step();
  CHECK(output.contacts.empty() && output.speed_rejects > 0);
  speed = {10, 0, 0};
  for (unsigned i = 0; i < 5; ++i)
    step(true, false);
  CHECK(output.contacts.empty());
  present = false;
  for (unsigned i = 0; i < 5; ++i)
    step();
  CHECK(output.contacts.empty());
  present = true;
  controls.request = true;
  controls.request_sequence = 1;
  controls.request_point = target;
  for (unsigned i = 0; i < 10; ++i)
    step();
  CHECK(output.selected.id == 42 && output.selected.velocity_valid && output.selected_type == 2);
  controls.search = false; // MAP keeps the same acquisition request and sensor owner.
  for (unsigned i = 0; i < 5; ++i)
    step();
  CHECK(output.selected.id == 42 && now - output.selected.stamp < .3);
  controls.search = true;
  speed = {0, 0, 0};
  for (unsigned i = 0; i < 10; ++i)
    step();
  CHECK(output.selected.id == 42 && now - output.selected.stamp < .3);
  controls.active = false;
  step();
  CHECK(output.contacts.empty() && !output.selected.id);
}
} // namespace
int main() {
  try {
    detection_and_memory();
    rejection_and_track();
    std::cout << "Actual GMT: scene detection, finite processing, measured motion, completed-grant gating, "
                 "coast/expiry, terrain/speed/cone/presence rejection, MAP handoff and acquired stopping target PASS\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}

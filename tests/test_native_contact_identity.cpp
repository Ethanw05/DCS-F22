// GPL-3.0-or-later. Actual bounded metadata bridge with substituted host calls.
#include "../EFM/source/NativeContactIdentity.cpp"
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#define CHECK(x)                                                                                             \
  do {                                                                                                       \
    if (!(x))                                                                                                \
      throw std::runtime_error(#x);                                                                          \
  } while (0)
namespace {
using namespace NativeContactIdentity;
double now = 10;
unsigned lookups{};
int target_side = 2;
bool present = true, destroyed = false, read_success = true, identity_matches = true;
std::map<std::string, double> values;
std::array<void *, 41> la_methods{};
std::array<void *, 2> identity_methods{};
struct Unit {
  std::array<std::byte, 120> pad{};
  void **table{};
  std::array<std::byte, 512> rest{};
};
Unit owner{}, target{{}, identity_methods.data(), {}};
struct Aircraft {
  void **table = la_methods.data();
} la;
void *handle(const char *name) {
  return &values[name];
}
void write(void *h, double v) {
  *static_cast<double *>(h) = v;
}
bool read_value(const void *h, double &v, bool) {
  v = *static_cast<const double *>(h);
  return read_success;
}
double time_now() {
  return now;
}
void *aircraft() {
  return &la;
}
void *own(void *) {
  return &owner;
}
void *find(unsigned source) {
  ++lookups;
  return source == 42 ? &target : nullptr;
}
unsigned identity(void *) {
  return identity_matches ? 42u : 43u;
}
int coalition(const void *object) {
  return object == &owner ? 2 : target_side;
}
bool flag(const void *, int) {
  return present;
}
bool dead(const void *) {
  return destroyed;
}
EDPARAM parameters() {
  EDPARAM p;
  p.ed_param_api.pfn_ed_cockpit_get_parameter_handle = handle;
  p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number = write;
  p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number = read_value;
  return p;
}
void setup() {
  reset();
  values.clear();
  now = 10;
  lookups = 0;
  target_side = 2;
  present = true;
  destroyed = false;
  read_success = true;
  identity_matches = true;
  api.ready = true;
  api.reason = 0;
  api.clock = time_now;
  api.aircraft = aircraft;
  api.find = find;
  api.coalition = coalition;
  api.flag = flag;
  api.dead = dead;
  la_methods[40] = reinterpret_cast<void *>(&own);
  identity_methods[1] = reinterpret_cast<void *>(&identity);
  values["F22_RWR_READY"] = 1;
  values["F22_RWR_POWER"] = 1;
  values["RWR_CONTACT_01_SOURCE"] = 42;
  values["RWR_CONTACT_01_TIME"] = .2;
}
void scenarios() {
  setup();
  auto p = parameters();
  update(p);
  CHECK(lookups == 1 && values["F22_RWR_META_READY"] == 1);
  CHECK(values["F22_RWR_META_01_SOURCE"] == 42 && values["F22_RWR_META_01_AFFILIATION"] == 1);
  CHECK(values["F22_RWR_META_01_SAMPLE_TIME"] == 9.8);
  now += .06;
  target_side = 1;
  update(p);
  CHECK(values["F22_RWR_META_01_AFFILIATION"] == 0);
  now += .06;
  target_side = 0;
  update(p);
  CHECK(values["F22_RWR_META_01_AFFILIATION"] == -1);
  now += .06;
  target_side = 2;
  identity_matches = false;
  update(p);
  CHECK(values["F22_RWR_META_01_AFFILIATION"] == -1);
  now += .06;
  identity_matches = true;
  present = false;
  update(p);
  CHECK(values["F22_RWR_META_01_AFFILIATION"] == -1);
  now += .06;
  present = true;
  destroyed = true;
  update(p);
  CHECK(values["F22_RWR_META_01_AFFILIATION"] == -1);
  const auto queried = lookups;
  for (const auto invalid : {-1., 0., 42.5, 4294967296., std::numeric_limits<double>::infinity()}) {
    now += .06;
    values["RWR_CONTACT_01_SOURCE"] = invalid;
    update(p);
    CHECK(values["F22_RWR_META_01_SOURCE"] == 0 && lookups == queried);
  }
  values["RWR_CONTACT_01_SOURCE"] = 42;
  destroyed = false;
  now += .06;
  values["RWR_CONTACT_01_TIME"] = 13;
  update(p);
  CHECK(lookups == queried);
  now += .06;
  values["RWR_CONTACT_01_TIME"] = 0;
  values["F22_RWR_POWER"] = 0;
  update(p);
  CHECK(values["F22_RWR_META_READY"] == 0 && lookups == queried);
  now += .06;
  values["F22_RWR_POWER"] = 1;
  read_success = false;
  update(p);
  CHECK(lookups == queried);
  read_success = true;
  now = 1;
  update(p);
  CHECK(values["F22_RWR_META_TIME"] == 1);
  CHECK(values["F22_RWR_META_01_AFFILIATION"] == 1);
  reset();
  now += .06;
  api.ready = false;
  api.reason = 2;
  update(p);
  CHECK(values["F22_RWR_META_READY"] == 0 && values["F22_RWR_META_REASON"] == 2);
}
} // namespace
int main() {
  try {
    scenarios();
    std::cout << "Received RF metadata: friendly/hostile, neutral unknown, source/presence/lifetime checks, "
                 "bounded lookup, stale/power/read withdrawal PASS\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}

// GPL-3.0-or-later. Actual provider callbacks against the recovered RBM cache
// contract. This fixture is not a GPU or in-game texture qualification.
#include "../EFM/source/NativeGroundVideo.cpp"
#include <iostream>
#include <stdexcept>
#define CHECK(x)                                                                                             \
  do {                                                                                                       \
    if (!(x))                                                                                                \
      throw std::runtime_error(#x);                                                                          \
  } while (0)
namespace {
using namespace NativeGroundVideo;
double now = 10;
unsigned constructors{};
std::array<std::byte, 1536> indicator{};
double clock_now() {
  return now;
}
void *construct(void *destination, int) {
  ++constructors;
  std::memset(destination, 0, 784);
  return destination;
}
using Parameters = decltype(GroundVideoView::parameters(View{}, false, false));
struct Buffer {
  Parameters *data{};
  int count = 18;
};
// AGRadar::update restarts collection on a direction transition. draw passes
// state1 -> state2 -> state3. buildDBS does not invalidate MAP (preset mode0).
struct RbmCache {
  int direction{}, stage{};
  double collecting{}, complete{};
  unsigned captures{}, completed{};
  void draw(const Parameters &params, double north) {
    const auto next = static_cast<int>(params[0].number);
    if (direction != next) {
      direction = next;
      stage = 0;
    }
    if (stage == 0) {
      collecting = north;
      ++captures;
      stage = 1;
    }
    if (stage < 3) {
      ++stage;
      return;
    }
    if (complete != collecting) {
      complete = collecting;
      ++completed;
    }
  }
};
void start() {
  reset();
  now = 10;
  api.clock = clock_now;
  api.camera = construct;
  owned = indicator.data();
  guard.verify(true);
  view = {};
  view.enabled = true;
  view.fan = true;
  view.mode = 1;
  view.stamp = now;
  view.collection = .01;
  aircraft = {};
  aircraft.valid = true;
  aircraft.stamp = now;
  aircraft.altitude = 3000;
  aircraft.fn = 1;
  aircraft.vn = 200;
}
Parameters submit(bool credit = true) {
  now += .02;
  view.stamp = now;
  aircraft.stamp = now;
  aircraft.north += 4;
  if (credit)
    view.collection += .01;
  // Flight evidence: multiple getCamera calls precede each getParameters.
  for (unsigned i = 0; i < 3; ++i)
    camera(indicator.data());
  Parameters result{};
  Buffer buffer{&result};
  parameters(indicator.data(), &buffer);
  std::array<double, 3> position{};
  point(indicator.data(), position.data());
  CHECK(position[0] == render.current.north);
  return result;
}
void moving_map() {
  start();
  RbmCache cache;
  for (unsigned i = 0; i < 40; ++i) {
    const auto params = submit();
    CHECK(params[5].bits == 0); // DBS is not MAP refresh.
    cache.draw(params, render.current.north);
    CHECK(map_reference.north == render.current.north);
  }
  CHECK(cache.completed >= 9 && cache.complete > 100);
  CHECK(cache.captures == 10 && rbm_restarts == 10);
  // Drain already completed work coalesced behind the last image.
  for (unsigned i = 0; i < 4; ++i)
    (void)submit(false);
  const auto captured = image_captures.load();
  for (unsigned i = 0; i < 8; ++i)
    (void)submit(false);
  CHECK(image_captures == captured);
  const auto frozen = map_reference;
  view.frozen = true;
  for (unsigned i = 0; i < 8; ++i)
    (void)submit();
  CHECK(map_reference.north == frozen.north && map_reference.stamp == frozen.stamp);
  view.frozen = false;
  (void)submit();
  CHECK(map_reference.north > frozen.north && image_captures > captured);
}
void expansion_and_lifetime() {
  start();
  view.mode = 1;
  view.expansion = 1;
  view.patch_distance = 15000;
  view.center_m = 15000;
  view.span_m = 12000;
  CHECK(GroundVideoView::valid(view, now));
  unsigned requests = 0;
  for (unsigned i = 0; i < 12; ++i)
    requests += submit()[5].bits ? 1u : 0u;
  if (requests != 3 || dbs_requests != 3 || rbm_restarts != 0)
    std::cerr << "DBS requests=" << requests << " native=" << dbs_requests << " RBM=" << rbm_restarts
              << " captures=" << image_captures << " rejected=" << parameter_rejected << '\n';
  CHECK(requests == 3 && dbs_requests == 3 && rbm_restarts == 0);
  const auto made = constructors;
  const auto captured = image_captures.load();
  epoch.fetch_add(1);
  (void)submit();
  CHECK(image_captures == captured + 1 && constructors == made);
  Parameters result{};
  Buffer buffer{&result};
  std::array<std::byte, 1536> foreign{};
  parameters(foreign.data(), &buffer);
  CHECK(result[7].text == nullptr);
  now += 1;
  CHECK(condition(indicator.data()) == 0);
  camera(indicator.data());
  parameters(indicator.data(), &buffer);
  CHECK(!render.valid && result[7].text == nullptr);
  view.stamp = now;
  view.enabled = false;
  CHECK(condition(indicator.data()) == 0);
}
void bad_buffer() {
  start();
  (void)submit();
  Parameters values{};
  Buffer undersized{&values, 17};
  parameters(indicator.data(), &undersized);
  CHECK(guard.reason() == 7 && condition(indicator.data()) == 0);
  view.enabled = false;
  view.enabled = true;
  guard.verify(true);
  CHECK(condition(indicator.data()) == 0);
  start();
  CHECK(condition(indicator.data()) == 3);
}
} // namespace
int main() {
  try {
    moving_map();
    expansion_and_lifetime();
    bad_buffer();
    std::cout << "Owned ground image: repeated terrain collections, coherent multi-pass pose, RF-only "
                 "refresh, FRZ, DBS, epoch, stale/foreign/buffer withdrawal PASS\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}

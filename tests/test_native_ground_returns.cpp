// GPL-3.0-or-later. Checked native record transport; never infer unit
// identities.
#ifdef NDEBUG
#undef NDEBUG
#endif
#include "../EFM/source/NativeGroundReturns.h"
#include <array>
#include <cassert>
#include <limits>
using namespace NativeGroundReturns;
template <class T> void write(std::byte *record, std::size_t offset, T value) {
  std::memcpy(record + offset, &value, sizeof(value));
}
int main() {
  std::array<std::byte, 144> record{};
  Return decoded;
  write(record.data(), 0, 1000.0);
  write(record.data(), 8, 50.0);
  write(record.data(), 16, 2000.0);
  write(record.data(), 112, 100.0);
  write(record.data(), 72, 4.0f);
  write(record.data(), 124, std::uint8_t{1});
  assert(decode(record.data(), 144, 101, decoded));
  assert(decoded.north == 1000 && decoded.altitude == 50 &&
         decoded.east == 2000 && decoded.stamp == 100);
  assert(!decode(record.data(), 143, 101, decoded));
  assert(!decode(nullptr, 144, 101, decoded));
  assert(!decode(record.data(), 144, 109, decoded));
  assert(!decode(record.data(), 144, 99, decoded));
  write(record.data(), 128, std::uint32_t{1001});
  assert(!decode(record.data(), 144, 101, decoded));
  write(record.data(), 128, std::uint32_t{0});
  write(record.data(), 124, std::uint8_t{0});
  assert(!decode(record.data(), 144, 101, decoded));
  write(record.data(), 124, std::uint8_t{1});
  write(record.data(), 8, std::numeric_limits<double>::quiet_NaN());
  assert(!decode(record.data(), 144, 101, decoded));
}

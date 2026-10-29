// GPL-3.0-or-later. Temporal warning policy for native-admitted optical tracks.
// Public MAWS principles inform the states; all numeric tuning is a mod
// estimate.
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>

namespace MawsThreat {
struct Polar {
  double az{}, el{}, range{};
};
enum class Decision : unsigned {
  None,
  Measuring,
  Receding,
  OutsideHorizon,
  Incoming,
  ManeuverHold,
  Passed,
  Diverging,
  Uncertain
};
inline constexpr std::size_t capacity =
    512; // Same bound as native contact admission.
inline constexpr double hold_seconds = 5;
inline constexpr double lost_seconds = 1;
struct Track {
  unsigned id{};
  std::uintptr_t incarnation{};
  double time{}, n{}, u{}, e{}, last_seen{};
  bool threat{};
  double closing{}, closest_time{-1}, miss{};
  Decision decision{Decision::None};
  double evidence_time{-100}, minimum_range{150000};
  double approach_n{}, approach_u{}, approach_e{};
  double opening_since{-1};
  bool cleared{};
};
struct Motion {
  double range{}, n{}, u{}, e{}, closing{}, closest_time{-1}, miss{};
};
inline bool valid(unsigned id, double time, const Polar &p) noexcept {
  if (!id || !std::isfinite(time) || time < 0)
    return false;
  if (!std::isfinite(p.az) || !std::isfinite(p.el) || !std::isfinite(p.range))
    return false;
  return std::abs(p.az) <= 3.141593 && std::abs(p.el) <= 1.570797 &&
         p.range >= 1 && p.range <= 150000;
}
inline Motion measure(double time, const Polar &p, const Track &old) noexcept {
  const double ce = std::cos(p.el), dt = time - old.time;
  const double n = p.range * ce * std::cos(p.az), u = p.range * std::sin(p.el);
  const double e = p.range * ce * std::sin(p.az);
  const double vn = (n - old.n) / dt, vu = (u - old.u) / dt,
               ve = (e - old.e) / dt;
  const double dot = n * vn + u * vu + e * ve,
               speed2 = vn * vn + vu * vu + ve * ve;
  const double closest = speed2 > 1 ? -dot / speed2 : -1;
  return {p.range,
          n,
          u,
          e,
          -dot / p.range,
          closest,
          std::hypot(n + vn * closest, u + vu * closest, e + ve * closest)};
}
inline bool incoming(const Motion &m) noexcept {
  // The existing60s declaration horizon is an estimate, not real MAWS ranging.
  return m.closing > 25 && m.closest_time > 0 && m.closest_time <= 60;
}
inline void declare(Track &t, const Motion &m, double time) noexcept {
  // Start a new approach episode after clearance/expired confidence.
  if (t.cleared || time - t.evidence_time > hold_seconds) {
    t.approach_n = m.n / m.range;
    t.approach_u = m.u / m.range;
    t.approach_e = m.e / m.range;
    t.minimum_range = m.range;
  }
  t.threat = true;
  t.cleared = false;
  t.evidence_time = time;
  t.opening_since = -1;
  t.decision = Decision::Incoming;
}
inline Decision divergence(Track &t, const Motion &m, double time) noexcept {
  if (m.closing >= -25) {
    t.opening_since = -1;
    return Decision::None;
  }
  if (t.opening_since < 0)
    t.opening_since = time;
  const double duration = time - t.opening_since;
  const double growth = m.range - t.minimum_range;
  const double alignment =
      (t.approach_n * m.n + t.approach_u * m.u + t.approach_e * m.e) / m.range;
  const bool passed =
      t.minimum_range <= 2000 && growth >= 300 && alignment <= 0;
  if (passed && duration >= .6)
    return Decision::Passed;
  const bool separating = growth >= std::max(500., t.minimum_range * .1) &&
                          alignment <= .8660254038;
  if (separating && duration >= 2)
    return Decision::Diverging;
  return Decision::None;
}
inline void classify(Track &t, const Motion &m, double time) noexcept {
  t.minimum_range = std::min(t.minimum_range, m.range);
  if (incoming(m)) {
    declare(t, m, time);
    return;
  }
  t.threat = false;
  if (t.evidence_time < 0) {
    t.decision =
        m.closing <= 25 ? Decision::Receding : Decision::OutsideHorizon;
    return;
  }
  if (t.cleared)
    return; // Keep clearance until a measured new approach.
  const auto clear = divergence(t, m, time);
  if (clear != Decision::None) {
    t.cleared = true;
    t.decision = clear;
    return;
  }
  if (time - t.evidence_time <= hold_seconds) {
    t.threat = true;
    t.decision = Decision::ManeuverHold;
  } else
    t.decision = Decision::Uncertain; // Never claims seeker unlock/safety.
}
class Core {
public:
  using Decision = MawsThreat::Decision;
  using Track = MawsThreat::Track;
  bool overflow{};
  void reset() noexcept {
    for (auto &track : slots_)
      track = {};
    overflow = false;
    clock_ = -1;
  }
  bool observe(unsigned id, double time, const Polar &p,
               std::uintptr_t incarnation = 0) noexcept {
    auto *slot = locate(id);
    if (!valid(id, time, p)) {
      if (slot)
        *slot = {};
      return false;
    }
    if (!slot)
      slot = empty();
    if (!slot) {
      overflow = true;
      return false;
    }
    if (restart(*slot, id, time, incarnation)) {
      initialize(*slot, id, time, p, incarnation);
      return false;
    }
    if (time == slot->last_seen)
      return current(*slot, time);
    slot->last_seen = time;
    if (time - slot->time < .1)
      return current(*slot, time);
    const auto m = measure(time, p, *slot);
    classify(*slot, m, time);
    slot->time = time;
    slot->n = m.n;
    slot->u = m.u;
    slot->e = m.e;
    slot->closing = m.closing;
    slot->closest_time = m.closest_time;
    slot->miss = m.miss;
    return slot->threat;
  }
  Track diagnostic(unsigned id) const noexcept {
    for (const auto &t : slots_)
      if (t.id == id && id)
        return t;
    return {};
  }
  void expire(double now) noexcept {
    if (!std::isfinite(now) || now < 0) {
      reset();
      return;
    }
    if (now < clock_)
      reset();
    clock_ = now;
    overflow = false;
    for (auto &t : slots_) {
      if (t.id && (now + .05 < t.last_seen || now - t.last_seen > lost_seconds))
        t = {};
    }
  }

private:
  std::array<Track, capacity> slots_{};
  double clock_{-1};
  Track *locate(unsigned id) noexcept {
    if (!id)
      return nullptr;
    for (auto &t : slots_)
      if (t.id == id)
        return &t;
    return nullptr;
  }
  Track *empty() noexcept {
    for (auto &t : slots_)
      if (!t.id)
        return &t;
    return nullptr;
  }
  static bool restart(const Track &t, unsigned id, double time,
                      std::uintptr_t incarnation) noexcept {
    if (t.id != id || t.incarnation != incarnation)
      return true;
    return time < t.last_seen || time - t.last_seen > lost_seconds;
  }
  static bool current(Track &t, double time) noexcept {
    if (t.decision == Decision::ManeuverHold &&
        time - t.evidence_time > hold_seconds) {
      t.threat = false;
      t.decision = Decision::Uncertain;
    }
    return t.threat;
  }
  static void initialize(Track &t, unsigned id, double time, const Polar &p,
                         std::uintptr_t incarnation) noexcept {
    t = {};
    t.id = id;
    t.incarnation = incarnation;
    t.time = t.last_seen = time;
    t.n = p.range * std::cos(p.el) * std::cos(p.az);
    t.u = p.range * std::sin(p.el);
    t.e = p.range * std::cos(p.el) * std::sin(p.az);
    t.minimum_range = p.range;
    t.decision = Decision::Measuring;
  }
};
} // namespace MawsThreat

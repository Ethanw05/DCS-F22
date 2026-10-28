# Remaining flight execution acceptance

The early source-admission provider and common harness are available. Native
weapon consumers remain a separate caller handoff; they do not supply fuel,
engine or hydraulic owner inputs. Independent physical work continues while
shared native adapters migrate. Actual host qualification remains separate.

Before the following changes, acceptance is derived from R-FLT-002..015 and
D-R-FLT-001..004, the current SDK declarations and I-FLT-001..003:

- Finite resources: rejected nonfinite/negative/over-capacity requests leave
  both reserves unchanged. Normalized SES inventories remain dimensionless;
  no kg/J conversion or separate physical bottle mass is invented. Every fuel
  transaction reconciles independently summed kg and three first moments.
  A full 64-entry ledger refuses a burn or either half of a transfer atomically;
  draining capacity permits a new explicit transaction.
- Engines: source loss cuts fuel/thrust; restoring feed/control/starter/fault
  producers cannot replay old start consent. Normal/degraded/unavailable control
  and manual starter/fuel/ignition paths retain the declared estimated profile.
  Purge/reset is distinct from repair/service. Obsolete start timers have no
  consumers or exports before retirement.
- Gear: one configuration owner holds each leg's achieved travel/lock/integrity.
  Structural and suspension damage are recorded independently. Each lamp and
  SDK per-leg lock output consumes its leg. Unknown native door/arrestment
  effects remain explicitly unavailable; no invented measured door source.
- FCS: one achieved-surface/vector owner; pitch-priority saturation, finite
  schedule bounds, declared approach/refuel/single-engine eligibility and
  generation reset hold through invalid source, fault and restoration.
- Environment: oxygen publications describe the instantaneous end of a step.
  Exact reserve exhaustion clears backup-active at that endpoint; the elapsed
  interval consumes only available reserve. Zero/invalid dt changes nothing.
  Independent backup survives environmental invalidity. The SDK physiology and
  canopy/escape effect capabilities are explicitly unavailable until qualified.
  Thermal fuel inlet/massflow treatment stays a declared approximation; no
  complete energy-closure claim follows from timestep convergence.
- Damage/repair: all registered faults have explicit source/feedback outcomes.
  Repair cannot refill fuel/SES/oxygen, cool a disc or start an engine. Resource
  service and controller reset remain separate admitted actions.
- Physics: force/moment and fuel mass/first-moment identities, continuity and
  matched timestep comparisons establish numerical behavior only. Native
  gravity/specific-force, store drag, ground effect and inertia ownership are
  unqualified; no duplicate contribution or coefficient tuning is introduced.
  Public performance validation without independent matched flight data is
  explicitly not assessable.

Finite/resource identities use 1e-8 kg or kg m in standalone double arithmetic;
actual transported callback values use max(1e-6, 1e-9*abs(expected)) SI. Normal,
limit, source/fault loss, restoration and generation/repair/service sequences
exercise actual owners. New test sources replace the remaining thirteen owned
legacy artifacts; no old expected-answer suite is used as an oracle.

# Physical profile decisions and qualification boundaries

Profile: public_f22_manual_recovery@1. These decisions complete software scope
without presenting estimates or unavailable host effects as aircraft validation.

## Supply, fuel and hydraulics

The sole EFM source owner supplies essential DC, mission power, limited ground
APU services and utilities. Mission power excludes APU-only ground service; CNI
receiver AC remains unavailable on battery alone. The existing estimated battery
budget is 12 Ah, 18 A baseline, 80 A starting increment and 8 A charging. These
are declared aggregate loads, not measured per-device wattage or generator torque.
No electrical/engine mechanical energy-closure claim is made.

SES air/start-fuel reserves are normalized quantities, with no inferred kg/J
conversion or new bottle mass. Variable requests are now finite-checked and
atomic. Recharging requires the existing qualified compressor/fuel predicates.
Fuel alone is accounted in kg and body-frame first moments through the 64-slot
host ledger. Cell splits/locations/transfer rates remain estimated. Empty tank
contents cannot authenticate carriage; a current observation newer than the
absolute host callback is required for external refill.

[Eaton's April 2014 brochure, printed pp2,5–7](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf)
was reread for independent hydraulic systems, four pumps, utility maintenance
switching, gear sequencing and the described EW emergency generator. Its ratings
do not define this mod's load schedules or current equipment applicability.
The separate emergency EW source has an explicit **unavailable/no-go** disposition
until its load, hydraulic energy and consumer path are defined. APU or battery
power must not be relabeled as that generator. Current normal EW power remains
the independently qualified mission feed; no new hidden power source is added.

## Engines and flight controls

[Pratt & Whitney's F119 description](https://www.rtx.com/prattwhitney/products/military-engines/f119)
was reread for twin-spool augmentation and integrated pitch-vector nozzle/FADEC
function. It supplies no usable start, relight, fuel-consumption or control-gain
deck. Existing start/protection/degraded-control estimates are retained and now
verified independently for source loss, explicit restart, purge and reset.
Obsolete duplicate timers/rates were retired after the source/export gate.

The current per-engine hydraulic nozzle eligibility mapping remains a declared
mod approximation. It is not identified as a recovered F119 fuel-actuation
schematic. Fire isolation removes the modeled fuel/generator/bleed paths;
discharge inventory/attempt does not prove native fire extinction.

Cruise, approach and refueling configurations use achieved gear/receptacle state.
The retained normal approach reference is 12 degrees. Single-engine approach is
an eligibility flag with the same baseline law, not adoption of an unsourced
historical selectable law. Pitch-priority saturation and one surface/vector
owner remain. AFCS eligibility now additionally requires valid force/mass state
and available physical actuators; native axis/mode policy remains Chat 2's.
Trim bounds remain the current estimated normalized pitch +/-0.25 and lateral
+/-0.2. Numerical callback mass/CG bounds are computational guards, not flight
envelope limits. Write-only g_assist and unused FCS locals were removed precisely.

## Gear, contact and brakes

Configuration::gear is the one achieved owner for nose/left/right travel and
locks. RAPTOR gear_pos is a derived aerodynamic mean, not a second integrator.
Damage isolates its leg's movement/locks and lamp. Structural cells8/15/16 and
suspension cells83/84/85 are handled independently; their actual DCS relationship
remains unqualified. Per-leg SDK post/lock outputs, draw arguments and mainpanel
lamps consume the same state. Native door measurement, cable arrestment and host
effect qualification are explicitly unavailable; door-valid remains0.

Native suspension/anti-skid remains the contact/brake authority. The existing
thermal model uses reaction magnitude as an upper work envelope; raw wheel units
and actual slip/deceleration are unqualified. Stale/unloaded/resting samples add
no work. Tire damage persists until replacement; replacement preserves disc heat.

## Environment and native effects

The modern automatic backup profile remains the default; the existing historical
manual selection is retained. Source/capacity/time constants remain estimates.
Oxygen availability is the instantaneous end-of-step state: exact exhaustion
clears backup-active, without an extra grace interval. Environmental invalidity
does not consume an unrelated source or refill independent backup.

EFM_CABIN_VALID requires qualified canopy source data; no position-only lock is
invented. EFM_OXYGEN_EFFECT_QUALIFIED and EFM_CANOPY_EFFECT_QUALIFIED remain0.
The SDK pressure baseline is retained while physiology/escape/seal effects have
an explicit unavailable/no-go disposition. This is tested software unavailability,
not a claim that the simulator has no native capability.

The thermal fuel sink is a reduced-order lumped estimate with no refuel inlet
temperature or advective enthalpy model. Depletion/refill changes its effective
capacity; there is no complete energy-closure claim. Rebuilt600s timestep and
cooling-loss/empty-sink sensitivity cases characterize this approximation.

## Performance and final qualification

Air-data identities, fuel/moment conservation, pitch saturation, continuity,
matched airborne relative-wind invariance and timestep sensitivity are numerical
verification. No duplicate gravity, inertia, ground-effect or store-drag term is
introduced before host ownership characterization. Signed normal acceleration
retains its explicitly unqualified legacy convention.

Aircraft supercruise/climb/range/high-alpha validation is **not assessable** from
the available independent matched flight data. Numerical grids cannot supply
that evidence. Installed/loaded DLL and hooks, DCS sorties, 2D/VR presentation,
native contact/arrestment/physiology and multiplayer remain separate qualification
results; only actual observations may change those dispositions.

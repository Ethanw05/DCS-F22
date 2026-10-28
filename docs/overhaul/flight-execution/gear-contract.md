# P-FLT-005 proposed achieved gear contract

Requirements R-FLT-002/R-FLT-011; finding F-FLT-002; verification VS-002.
Prepared before provider/consumer edits. Implementation awaits P-FLT-002 and
the integrator's shared-region lease.

The sole EFM configuration owner must hold three legs in fixed order
NOSE/LEFT/RIGHT. Each leg publishes travel and door position (normalized 0..1),
down-lock, up-lock, damage/integrity, and field validity. A request is separate
from achieved position and lock. A missing/uncharacterized door source has
door-valid=0; neither full travel nor a command proves door closure.

All flags are numeric 0/1; integrity is 0..1. Publish inside the physical frame,
using its current generation and spawn-relative stamp. Clear on release/new
generation. Never accept an old lock after generation change. Native suspension
callbacks and EDM draw arguments consume the same achieved owner; no Lua gear
actuator or inferred healthy fallback is added.

Green lamp = qualified electrical supply AND current valid leg AND achieved
down-lock AND healthy leg. Aggregate DOWN_LOCKED is the conjunction of all three
qualified down-locks. Aggregate UNSAFE is true for an invalid/damaged/transiting
leg; aggregate UP_LOCKED likewise requires all three qualified up-locks.
Thresholds and travel rates remain explicitly estimated and must be declared
before tests. A locked-down leg remains locked with source loss; source loss
must not invent retraction. Alternate extension consumes finite SES once and
retains the existing anti-retraction latch until its declared reset/service.

| Consumer | Nose | Left | Right |
| --- | --- | --- | --- |
| Existing lamp parameter | N_GEAR_LIGHT | L_GEAR_LIGHT | R_GEAR_LIGHT |
| Mainpanel argument | 723 | 724 | 725 |
| External leg argument | 0 | 5 | 3 |
| Suspension index | 0 | 1 | 2 |
| Registered structural damage cell | 8 | 15 | 16 |
| FM suspension damage cell | 83 | 84 | 85 |

The two damage-cell families are present in current registration. Their native
relationship must be measured rather than silently choosing one family. The
SDK header declares per-suspension UP_LOCK/DOWN_LOCK outputs; the present source
only returns a common GEAR_POST_STATE and leaves individual lock outputs at the
default zero. Actual host consumption/damage/arrestment remains unqualified.

`mainpanel_init.lua` currently binds all three lamps to N_GEAR_LIGHT. The cutover
must change both right/left bindings and the producer. Independently damage each
leg, then verify only its lamp is withheld while the others retain achieved
locks; separately exercise each suspension damage cell and record the host result.

Acceptance scenarios: gear-up cold/hot/air start; powered extension/retraction;
stopped travel after supply loss; alternate extension depletion/repetition;
per-leg damage at full travel and during transit; invalid position/lock source;
power loss/restoration; repair without implicit motion/refuel/cooling; fresh
generation; mainpanel write-only gauge declarations. Native cable arrestment,
wheel-speed units, slip/deceleration and actual visible locks require the
exclusive qualification slot and cannot be established by this table.

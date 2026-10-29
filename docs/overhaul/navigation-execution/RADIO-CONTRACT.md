# Received navigation and manual approach

P-NAV-003 / P-NAV-008 source slice, R-NAV-004/013/015. Source implementation
and offline verification are separate from native receiver qualification.

NativeNavigation publishes `F22_RADIONAV_SCHEMA=1`. `SEQUENCE` is odd while
writing and even after commit, bounded 2..16777214 without reuse in one physical
generation. `VALID=1` means a complete observation of receiver state. It does
not mean every signal is available. `GENERATION` matches the current physical
generation. `CLOCK_KIND=2`, `STAMP` are World seconds sampled after the getters.
The native API does not expose original RF measurement time or station identity;
the stamp must not be described as either. Host validity/retained-state behavior
still requires actual reception qualification.

Protected payload consists of commanded TCN channel/band/mode and ILS frequency,
achieved native receiver power, and independent bearing, range, LOC and GS
validity/value pairs. Bearing is magnetic radians; range is metres converted
from the native nautical-mile getter. LOC/GS are the native 0.6-times-angular-error
quantities documented in the retained research observations. A tuning command
does not establish station identity or acquisition.

Every required publication write and final parameter epoch/context/physical
generation check must succeed before the final even marker. Scalar zero remains
valid. Nonfinite/out-of-bound components withdraw independently. After tuning,
power cycling, receiver replacement or physical generation change, each component
must first report native invalid before a subsequent valid state is admitted.
This prevents retained pre-retune flags from being relabelled with new tuning.
If the host never clears validity, that component remains unavailable; no timer
or fabricated reception substitutes for the missing observation.

Radio_Snapshot reads the marker before all payload, rereads metadata and requested
tuning afterwards, and checks an independently current physical envelope.
World leases are 0.25s with 0.01s future tolerance, adapter policies rather than
aircraft specifications. Clock rollback retires the generation. A stopped source,
unsupported schema, torn packet or tuning mismatch cannot renew guidance.
TACAN mode selection preserves separate bearing/range availability; ILS does not
depend on an INS position solution or a healthy TACAN component.

Manual_Approach retains explicit ILS selection in NAV and landing-configuration
acquisition. Each LOC/GS output has its own validity. It maps conventional
full-scale LOC +/-2.5deg, GS +/-0.7deg to +/-1, with positive GS inverted for a
fly-down cue. These are existing display adaptations, not F-22/facility
calibrations. The ADI consumes these current outputs and hides a failed axis.
Existing geometry, material, placement and clipping are retained. Data-page
reception flags use the qualified reader even when approach display is deselected.
Automatic approach coupling, autoland and carrier recovery remain unselected.

Selected magnetic TACAN/heading/course displays use the coherent magnetic
reference. A missing declination never silently changes the selected reference
to true. DME and manual ILS remain independent of magnetic-reference loss.

## Open qualification

- A changed/lost cockpit context withdraws access before touching the retained
  TACAN object and latches retirement across a reused address. No replacement
  object is allocated on this path. This is not callback cancellation proof.
- `reset()` still needs actual matched callback-drain/release/destructor/allocator
  ordering with the host. Healthy context addresses alone cannot prove lifetime.
  The adapter remains P-NAV-003 open; fixtures do not execute a real native timer.
- Native magnetic conversion still consumes the navigation own-position scalar
  publication. Its original position timestamp/coherence needs a separate source
  migration; this change does not qualify that input by observing declination.
- Ident remains muted/unavailable under the current selected policy. Actual
  ident, retune/acquisition, surviving electrical paths and RF measurement age
  need separate host evidence.
- No DCS memory-ordering, callback-concurrency, 2D/VR optics, audio or multiplayer
  qualification is inferred. Native getters/setters in fixtures are explicit
  ports; dispatch/counter observations do not establish real receiver effects.
- Installation requires one attributable DLL/assets bundle. The current primary
  checkout has other owners' uncommitted native changes, so this source slice
  has not been copied into the normal installation. The simulator was not operated.

# MAP quality and persistent surface views

The Oct28 flight confirms the previous cache repair is producing changing
images:400 GPU changes over514 samples. It also records a512x512 texture and
approximately32 parameter submissions/second, giving about8 image captures/s
with the previous four-submission gate. DCS Options defines avionics1 as512,
avionics3 as1024, and avionicsMFDEveryFrame as the every-frame MFD option.
Those two profile settings are part of this installation; no screen/fullscreen
or other graphics preferences are changed.

The rendered-position diagnostic remained at its first camera pose while
capture counters advanced. Camera-only readers had their own thread-local image
cycles, which could retain that first image forever without a parameter callback.
The image transaction is now shared under view_mutex; each reader keeps only its
own native Camera buffer and captured view. Parameter publication consumes the
shared transaction and updates submitted-pose telemetry. Foreign/stale-generation
and superseded transactions remain rejected. An actual two-thread owner test
exercises a reader that never supplies parameters alongside the normal submitter.

The owned AESA scene sampler now supplies the renderer's ownship value snapshot
from its already qualified DCS scene pose. The extra EFM/quaternion camera feed
is removed. The render callback still reads only copied values, never scene
objects. This avoids an independent pose owner and preserves observation epochs.

The recovered AGRadar draw sequence completes its image in three submissions;
MAP now uses that minimum rather than four. Expanded detail uses six and FAST
three, an explicit mod presentation policy that coalesces real completed RF
work. It does not fabricate dwells or increase RF credit. The common bezel
selection box now shows FAST and the selected EXP level. Routine GPU staging
readback and timing probes are disabled; they remain available for explicit
qualification runs without imposing a recurring readback stall during play.

The old shared Hornet MAP preset has3.3-degree renderer blur; GM_F16 uses1.0.
Hornet EXP1/2/3 prescribe a five-degree boresight blank, which can look like a
central occluder. The corresponding shared EXP_F16/DBS1_F16/DBS2_F16 presets
use the same19/67/120 resolution choices with zero blank angle. These are adopted
DCS rendering settings, not authenticated APG-77 parameters. MAP/EXP consume the
full texture through a local green mfd8 material; TA retains its inset viewport.
Only one of those two viewports is visible at a time. Renderer camera clearance
now follows the actual look direction in every EXP level, not only EXP3.

Surface mode changes and magnification changes no longer cancel a compatible
track request. EXP1 -> EXP2 -> EXP1 -> EXP3 -> MAP recalls the same designation
without a new TDC selection. A prior corral patch can also be recalled; the
first undesignated expansion still uses its deliberate corral selection.
The MAP bezel is a direct return while expanded. New measurements can move a
tracked target; view changes do not change its measured coordinates or epoch.
A moving track remains moving in MAP, rather than acquiring the FTT caption.
Explicit clear, power/lifecycle invalidation and actual track loss keep their
existing authority-withdrawal behavior.

Verification exercises the actual ground owner and bezel action contract,
static designation recall, GMT request/identity continuity through MAP and EXP,
real track loss, explicit clear, shared camera readers, scene pose feed, finite
RF-only image cadence, FAST's2:1 cadence policy and EXP1-3 camera clearance over
pitch/heading/look/range/speed/timing cases. Native image tests use /W4 /WX
/analyze. Existing native entry-point and Lua update/command complexity
exceptions remain; this change does not claim whole-file compliance.

In-game sharpness, frame rate, boresight imagery and color still require the next
flight. Offline checks establish state/geometry and native transport, not a
measured aircraft SAR resolution or a visual/performance acceptance.

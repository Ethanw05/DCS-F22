# SEN-02: incoming airborne ECM noise

The owned A/A receiver now uses a qualified common-engine ECM effect source.
No stock radar instance, detection, observation cache or lock gate is invoked.
This is an estimated noise-interference layer; it does not establish complete
APG-77 electronic protection or change the defensive-EW transmitter owner.

## Native evidence

Hex-Rays through the existing local IDA MCP supplied the reference call chain in
the installed `CockpitBase.dll` (SHA256
`163d55167503da8dd0ea9eb459e17206fc3dc8d6b4805b5b13bbe58341beb794`).
The stock ECM reference at RVA `0x3406e0` obtains a moving object's ECM through
virtual slot57, checks effect-active slot1, then reads receiver-related strength
through slot4. This is evidence for the common interface, not a production call
to that radar or adoption of its hard range/angle lock gates.

The matched `WorldGeneral.dll` profile is timestamp `0x6ac122f4`, size `0x125b000`.
Separate local analysis of its loaded code sections establishes the base-ECM
table at RVA `0x1d0778`, active method `0x65bd0`, strength method `0x65bc0`,
request method `0x65d20` and scheduled transition `0x65ac0`.
The request records pending state/time; a scheduled update sets common object
flag8 after its configured delay. Active reads flag8. The qualified base
strength is a dimensionless native scalar, not RF watts, bandwidth or spectrum.
The cockpit interface's enabled/request byte is not substituted for this state.

The adapter guards the existing module profile, base table/method entries,
borrowed instance owner and finite scalar. It reads the native active effect;
it does not request it, create a second ECM owner, or retain borrowed pointers.
Inactive common flag8 establishes no active common effect even for an unknown
ECM subclass. An active unsupported subclass or invalid instance is unknown,
not a healthy zero. Local code images, databases and pseudocode are untracked.

## Receiver behavior and estimates

- Each completed air dwell performs a separate bounded scene survey. Jammers
  can affect another target and can enter through receive sidelobes outside the
  search beam. No jammer identity, perfect position or affiliation reaches the
  tactical picture through this environment query.
- Contributions require terrain/object LOS and sum as linear J/N. The echo
  retains inverse-fourth-power range scaling; jammer noise has inverse-square
  scaling. The resulting `S/(N+J)` drives the existing detection probability and
  range/angle/Doppler uncertainty before association and filtering. Close-range
  echo advantage emerges from those different laws; no burn-through switch or
  unconditional lock break is added. Misses/coasts retain observation age.
- Declared game estimates: airborne common-ECM sources within300km; equivalent
  co-channel noise of J/N4 at80km and native strength1; Gaussian mainbeam using
  the existing half-angle, -40dB sidelobe floor, cosine front-element response,
  -60dB rear-element floor and40m propagation-distance floor. Native strength
  multiplies equivalent noise power. These numbers are not authenticated F-22
  or jammer parameters; no spectrum is supplied by this native interface.
- Fixed limits:256 survey visits,8 active sources requiring LOS, and the existing
 16 total visibility calls shared with echo detection per air dwell. Survey or
  source exhaustion, unsupported active ECM, malformed values or missing scene
  capabilities withdraw receiver validity. They do not silently omit noise.
  The synchronous receiver sample uses this completed dwell's model time.
- `F22_AESA_INTERFERENCE_VALID/JNR/TIME/SOURCES` publish coherent receiver
  environment metadata. JNR is linear J/N; time is absolute model seconds.
  These are diagnostic estimates, not passive emitter tracks or measured RF
  power. Receiver validity also gates contact publication and native weapon
  authority until a qualified completed air dwell recovers.
  Losing receiver qualification does not falsely mark a commanded transmitter
  silent; hardware/resource and emission commands remain its physical owners.

The [USAF Academy ECE315 EW lesson](https://usafa-ece.github.io/ece315-book/block3/L36/ECE315_B3_L34_EW_Reading_23Su.html)
develops jamming with Friis/radar/SNR equations and explains the closing-range
advantage of radar echoes. The [MathWorks frequency-agility example](https://www.mathworks.com/help/radar/ug/interference-mitigation-using-frequency-agility-techniques.html)
separates return/interference propagation, received bands and processing. Its
deception/agility model is further capability, not behavior claimed here.

## Verification and remaining work

Release build and31 native tests pass, including actual detector/provider
fixtures with strong warnings and MSVC analysis. A512-seed paired detector test
finds266/88 clean/jammed detections at80km and508/410 at20km, with increased
reported uncertainty for received jammed reports. This verifies these game
equations, not aircraft calibration. Fault cases cover unknown/stale noise,
invalid scalar/owner/table, absent ECM, terrain blockage, traversal/source limits,
no invented jammer target, unchanged coast timestamps and qualified recovery.
The existing native callback allocation probe still passes.

New production helpers are at most CCN14 and19 statement/declaration lines.
The inherited scene-query CCN16 remains a recorded provider exception; its
128-candidate and16-visibility bounds remain. Lua telemetry has zero new lint
findings and passes DCS Lua syntax. No new DCS flight qualification is claimed.

Still open: ground/shipborne interference, ground receiver/imagery effects,
module-specific ECM subclasses, waveform/band coverage, deceptive techniques,
adaptive nulls and frequency agility, passive jammer-bearing observations and
RF calibration. Actual DCS ECM missions and performance under dense scene load
need qualification on the combined installed build.

# Wheel contact and landing E-bracket correction

27 October 2026. The actual `trim-20261027-200828-58.csv` and matching
`dcs.log` show weight-on-wheels changing to 1 at model time 289.689 s,
2,230.36 m MSL and 267.62 KCAS. All 168 subsequent `F22_LANDING` records
report contact=1/bracket=false/FPM=1 while descending toward the runway at
about 241 m MSL. The old installed DLL reproduces false contact when positive
strut travel is supplied aloft. Those logs do not record the raw strut values;
unloaded travel versus retained feedback cannot be distinguished retrospectively.

Positive suspension travel is no longer sufficient for wheel contact. The EFM
uses finite native reaction-force samples, with a 0.1 s age limit and an estimated
100 N noise threshold. A conservative 12 m clearance rejection bound contains
all configured gear coordinates, strokes and tire radii. It prevents any strut
sample from declaring wheel loading far above the surface. Gear-up state is
unloaded; unknown near-surface feedback withdraws `EFM_GROUND_VALID` while
retaining the previous internal gear interlock. No height-only loaded fallback
is retained. These bounds are mod policies, not recovered F-22 squat-switch data.

The installed ED SDK defines both `ed_fm_set_surface` height arguments as
surface elevations. Clearance now subtracts `max(h, h_obj)` rather than adding
half the second elevation to the first. This removes terrain double-counting.

Existing HUD gear/AoA/FPM gates and 12-degree reference remain intact. Correct
airborne contact allows the existing bracket gate to pass. The passive trim
recorder now includes clearance, ground validity, gear locks and each wheel's
raw compression, reaction magnitude and sample age for actual playtest diagnosis.

Asserted native callbacks cover the recorded elevated approach, unloaded strut
travel near the runway, real wheel load, unload/bounce, expired feedback and
erroneous loaded samples aloft. Existing landing HUD tests cover on-speed cue
visibility and touchdown suppression. Post-install DCS landing visibility remains
a separate user playtest; no simulator was launched or terminated for these checks.

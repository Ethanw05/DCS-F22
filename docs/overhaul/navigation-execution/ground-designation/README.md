# HUD ground designation visibility

The pilot reported an acknowledged NAV/ground-radar designation without a HUD
diamond or edge square. The existing owner could publish EDGE_VALID=1 while
placing square vertices below -0.139 m or beyond +0.086 m horizontally; the
declared indicator viewport is only +/-0.06 m vertically and +/-0.07 m laterally.
Targets inside the physical-glass polygon could also be outside that viewport
while still selecting the conformal diamond. These are reproduced declaration
defects; exact native optics/head-position behavior still needs DCS observation.

The six Lua changes share the existing viewport dimensions with a designation-only
projection adapter. It fits the retained glyph and stroke within both the glass
and viewport, keeping direction and the existing top heading clearance. An
offscreen square stays steady; an in-view designation uses the existing diamond.
The owner now receives a completed ground-radar point in NAV HUD mode as well as
A/G mode. An invalid radar point clears a radar-owned designation without erasing
an independent NAV point. Target provenance, acknowledgement, power/reset and
source-age checks remain with their existing owners. This repair changes no
weapon or native radar implementation, controls, font, color, glyph size or audio.

The .14 m by .12 m viewport and .55 m focal reference are retained mod values,
not authenticated F-22 aircraft specifications. `HUD/geometry.lua` supplies the
same dimensions to actual indicator registration and ground-cue projection.
Generic air-target projection is unchanged.

Independent replacement cases exercise actual command 10841, ground-owner
acknowledgement, NAV feedback, actual native HUD element declarations, signed
direction, side/rear/up/banked cases, exclusive diamond/square, steady display,
10842 clear, power loss, clock rewind and invalid projection angles. Five of six
initial pilot-requirement cases fail against pinned source 5e19590; all twelve
new cases pass after the fix. The normal-install candidate package passes 75
navigation/presentation/ground-owner cases through 95 actual Lua dependencies.
Luacheck 1.2.0 under Lua 5.1 reports zero new findings and 96 retained findings.

An early pre-install handoff run additionally had four failures in unchanged installed
weapon store/program/delivery dependencies (three failures and one error).
They reproduce identically with the pre-fix NAV/ground-owner modules. Those
dependencies were left to the complete package already prepared in 837c41b.
The user's subsequent instruction to install all updates authorizes deployment
of that checked package alongside the HUD fix. The full installation receipt
records its post-copy checks. This makes no all-systems flight qualification
claim. Raw results and the exact NAV case selection are recorded externally.

The old synthetic `tests/test_nav_designation.py` was hash-checked and deleted;
its assertions were not reused as acceptance. Its retirement entry identifies
this replacement. No original measurements or user recordings were deleted.

Bounded-work review: the adapter adds no recurring loops or tables, and reuses
the existing projection result. Existing projection retains its fixed 24-step
glass search. In an isolated Lua 5.1 host, 1,000 owner updates take approximately
0.186 s, retain 38 parameters and return to 146.27 KiB after collection. These are
offline measurements, not simulator frame-time evidence. New functions have
Lizard complexity <=7 and <=10 non-comment lines. Retained large callbacks
`AG_Mark_System.update_body/update` and `Navigation_System.update` remain explicit
coding exceptions: existing bounded dispatch/publication paths are kept intact
to avoid changing their protocols in a presentation fix. Their full refactoring
is open; Lua-managed allocations and actual native/thread lifetime are not
certified by these checks.

See RESULTS.json for hashes/reports and INSTALLATION.json for the normal-mod
receipt. DCS was running during preparation; the user closed it before installing
and requested the complete update. No simulator/process operation or in-game
visibility verification was performed. Start DCS and check the installed cue in
a fresh flight. 2D/VR and multiplayer qualification remain open.

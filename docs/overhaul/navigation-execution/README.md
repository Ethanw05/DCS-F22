# Navigation and cockpit execution

This work follows the user's instruction to keep this chat on navigation,
cockpit, CNI and alerts. Radar and weapon implementation is outside this work.

## Current indication/reference change

R-NAV-013 and the reference part of R-NAV-001/R-NAV-007 now have independent
tests through the actual Avionics, HUD, GINS and indicator modules. Each numeric
side readout has its own validity gate and static `---` indication. The right
standby heading uses the selected SFG resource; primary and HUD headings use
their own selected resources. The duplicate smaller right G graph is removed.
Fonts, materials, positions, dimensions and clipping of the retained readouts
are checked against the previous declaration source.

The new contract is in [REFERENCE-CONTRACT.md](REFERENCE-CONTRACT.md). Independent
World age prevents a stopped physical publisher from renewing itself through
its own stopped clock. GINS schema2 carries the physical generation and retires
alignment when that generation changes. Checked native magnetic publication
preserves conversion/write/context status, including legitimate zero.

The tests cover nominal units, absent/nonfinite fields, independent ADC and
reference failures, stopped publishers, combined source/copy age, clock rewind,
generation replacement, valid zero and recovery. The native tests exercise the
actual built DLL's World timestamp, missing-host startup/reacquisition and
release. They do not qualify private CNI instances, DCS concurrency, aircraft
calibration or optics.

Installation and actual DCS checks are still pending. These scripts require the
matching DLL and schema2 GINS producer; copying the Lua alone over an older DLL
would deliberately withdraw unavailable indications. Shared DLL/package
coherence must be established before installation. No weapon or radar source
is changed by this indication/reference work.

## Remaining navigation work

- P-NAV-001: selected AFCS reference policy and actual host verification.
- P-NAV-002: remaining obsolete PMFD paths and loader/control cleanup.
- P-NAV-003: receiver context/allocator lifetime, source freshness and real ident.
- P-NAV-004: tested selected-off clear-voice disposition and menu behavior.
- P-NAV-005: qualified native bingo cause, warning/audio delivery and terrain checks.
- P-NAV-006: navigation depth/applicability and independent alignment/coast evaluation.
- P-NAV-007: matching installation and received manual approach/failure/recovery in DCS;
  2D, VR and multiplayer require actual observations.
- P-NAV-008: remaining control lifecycle checks and current independent LOC/GS axes.

Four hash-matching legacy GINS/fixture artifacts were deleted and replaced by
`tests/navigation_ports.py`, `test_gins_admission.py` and `test_side_indications.py`.
The replacement declaration tests use the previous aircraft declarations only
to check retained appearance, never old test assertions as a behavior oracle.
Full test retirement remains open under P-INT-006.

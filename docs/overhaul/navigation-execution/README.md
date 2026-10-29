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

The navigation receiver/reference package is now installed with its matching DLL
for the inspected DCS2.9.31.29434 host. The installed Lua set passes48 focused
fixture cases. Actual DCS reception and loaded identity remain unqualified.
The migration, decompilation evidence and exact installed hashes are recorded in
[host-update/README.md](host-update/README.md). No weapon or radar source is
changed by this navigation work.

The independent ICP event/handle-cache fix is installed in the normal mod. Its
eight script/configuration dependencies matched the existing installation, and
seven fixture cases passed through the actual installed ICP owner. Only that
one Lua file was copied; no DLL, binding or hook was changed. See
`CNI-MENU-RESULTS.json`; actual DCS menu/audio operation remains unqualified.

## Remaining navigation work

The subsequent received-navigation slice is described in [RADIO-CONTRACT.md](RADIO-CONTRACT.md)
and `RECEIVER-RESULTS.json`. It adds coherent receiver observations, independent
current LOC/GS ADI inputs, retune admission, and context-loss withdrawal.
Forty-one focused Python/Lua tests and two rebuilt native suites pass. The
hash-matching legacy TACAN-component test was deleted and independently remade.
Native callback drain and real reception remain open; the matching installation
is recorded under `host-update/INSTALLATION.json`.

- P-NAV-001: selected AFCS reference policy and actual host verification.
- P-NAV-002: remaining obsolete PMFD paths and loader/control cleanup.
- P-NAV-003: receiver callback drain/allocator lifetime, RF age/identity and real ident;
  getter-observation freshness and context-loss withdrawal now have source tests.
- P-NAV-004: selected-off clear-voice disposition and retained menu behavior are
  recorded in [CNI-VOICE-DISPOSITION.md](CNI-VOICE-DISPOSITION.md) and covered by
  seven actual-module tests. Real DCS menu/audio and any future optional backend
  require host qualification.
- P-NAV-005: qualified native bingo cause, warning/audio delivery and terrain checks.
- P-NAV-006: navigation depth/applicability and independent alignment/coast evaluation.
- P-NAV-007: installed file identity is verified; received manual approach/failure/recovery in DCS,
  2D, VR and multiplayer require actual observations.
- P-NAV-008: remaining control lifecycle/optical checks; independent current LOC/GS
  ADI inputs and retained appearance now have source tests.

Four hash-matching legacy GINS/fixture artifacts were deleted and replaced by
`tests/navigation_ports.py`, `test_gins_admission.py` and `test_side_indications.py`.
The replacement declaration tests use the previous aircraft declarations only
to check retained appearance, never old test assertions as a behavior oracle.
Full test retirement remains open under P-INT-006.

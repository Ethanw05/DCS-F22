# Navigation host migration: DCS2.9.31.29434

The user requested examination of the updated DLLs and a navigation fix in the
primary DCS-F22 checkout. This change owns navigation and its clock/parameter
dependencies. It does not edit radar or weapon implementation.

The actual installed `D:/DCS/bin` and `bin-mt` DLLs match by SHA256. Current
CockpitBase's IDA input hash matches that installed file. The prior CockpitBase
database/input is separately identified, so old addresses cannot be mistaken
for current results. Raw decompilations remain outside the repository in
`F22-Build/chat2-navigation-host-2.9.31.29434/verified`; proprietary DLLs, databases
and decompiled implementations are not committed.

| Navigation boundary | Previous profile | Inspected current profile |
|---|---:|---:|
| CockpitBase PE timestamp | 0x6ac12468 | 0x6adbad09 |
| Mapped image bytes | 0x59a000 | 0x68e000 |
| Native malloc import RVA | 0x449470 | 0x538478 |
| Native free import RVA | 0x449460 | 0x538468 |
| Owned common TACAN bytes | 2856 | 2856 |
| ILS object probe bytes | 3352 | 3352 |
| Context member offset | 24 | 24 |
| TACAN/ILS receiver offsets | 2064 / 2048 | 2064 / 2048 |

The stale import slots are a real relocation issue, not just a rejected version
number. NativeNavigation now accepts the inspected x64 PE profile and checks
both imported pointers against the loaded ucrtbase malloc/free exports before
using either. Failure clears both allocator candidates and withdraws receiver
availability. Old profiles, wrong architecture/header kind, malformed offsets,
wrong/unreadable import slots and missing CRT are rejected. String layout is
asserted at compile time. The electrical5800-byte readability probe is retained;
it is not presented as a proven allocation size or lifetime check.

All33 navigation function bindings and three required vtables are present. The
six parameter-bridge exports are also present. IDA comparisons cover these33
functions, six additional receiver/activity/constructor functions and six bridge
functions. Forty-three of45 normalized pseudocode bodies match; `start` has a
different logging arrangement, and TACAN update has different flag/volume control
flow. Their inspected measurement interfaces, offsets and units are retained.
Pseudocode normalization is supporting comparison, not equivalence proof.

ILS update still stores0.6 times angular deviation with independent LOC/GS
validity. TACAN update still converts metres to nautical miles before its range
getter; the adapter converts back to metres. This confirms the existing display
adaptations against the inspected implementation without authenticating F-22
calibration, facility accuracy or acquisition behavior.

World.dll still exports the no-argument double World clock; its current body
reads a double into XMM0 and returns. The six bridge routines compare unchanged.
Those callers need no address edits. WorldGeneral's magnetic/map exports remain
at the inspected RVAs. Their on-disk code is packed; the local restored analysis
snapshot was inspected separately, with its own hash. That snapshot is an offline
emulation artifact, not evidence of a loaded DCS module or complete initialization.
The export signatures remain float(float,float) and coordinate-output references;
inferred decompiler prototypes are not used to redefine the ABI.

## Verification and installation

The actual navigation admission helper accepts the updated installed CockpitBase
image mapped with `SEC_IMAGE_NO_EXECUTE`, and rejects the prior real image. This
does not run DllMain or execute DCS code. Synthetic mapped-image tests also cover
the malformed profiles/imports and a real matched CRT allocation/free round trip.
The external full DLL build, four native navigation suites and the existing CNI
power suite pass, with the adapter fixture targets using /W4 /WX /analyze.
Retained initializer/test-driver complexity exceptions
remain recorded; host callback-drain/concurrency coverage is not claimed.

The intended Lua package was checked through its real file dependency set before
copying. Initially, older UFC-altitude/warning consumers retained stale values;
including the matching navigation consumers makes all48 focused cases pass.
Unchanged dependencies continue to come from the existing normal installation.
The exact source/installed hashes, recognized prior script revisions, binary
identity, package receipt and actual checks are in RESULTS.json and INSTALLATION.json.
The normal installation contains the matching26-script navigation/dependency set
and rebuilt DLL; all48 cases pass through the actual installed Lua files. Bindings,
recorded audio, fonts, textures and installed hooks are preserved.

Remaining runtime qualification is received TACAN/ILS, retune/acquisition,
callback drain and reset ordering, original RF age/identity, 2D/VR optics, audio
and multiplayer in DCS. Actual loaded DLL identity is distinct from matching
installed files. This migration does not close all P-NAV packages or select the
optional voice backend, ident monitor or automatic approach coupling.

Reproduce the static audit with `tools/audit_navigation_host.py`, the dependencies
in `tools/requirements-navigation-host.txt`, and the existing local IDA plugin.
`tools/verify_navigation_install.py` can check the intended package before copying
or the actual installed Lua afterwards; it is explicitly a fixture runner.

# REL-01 — combined playtest envelope

This is a completed-so-far local playtest snapshot, not completion of the overhaul
backlog. The navigation integration branch combines the owned AESA sensor and
scene/weapon adapters, weapons/defensive avionics, navigation/GINS/altimetry/AFCS,
and the physical engine/power/fuel/FCS systems. Per-system evidence, estimates and
unqualified behavior remain in their implementation notes.

The frozen snapshot includes the held-roll fix, cursor focus ownership, momentary
trigger ownership (including malformed input), expired radar-support authority,
IR sample freshness/teardown, START engine feedback and angular TACAN CDI. Saved
command IDs and controls are retained; input profiles evaluate independently of
cockpit-only Lua globals. Native version guards remain enabled.

Combined checks: MSVC19.51 / VS18 x64 Release build; 29/29 CTests; 158/158 Python
checks; installed DCS Lua5.1 compile of runtime Lua files; pinned navigation/radar
Luacheck with zero new findings. Three superseded UI tests were replaced by the
current owner coverage documented in tests/README.md. Native model/callback tests,
Lua fixtures and offline font previews are distinct from actual DCS qualification.

The radar owner's isolated native runs establish owned sensing, acquisition and
target-specific DLZ/TOF handoff on that earlier DLL. The combined snapshot has not
yet been flown. Missile-in-flight/multi-target support, surface/imagery and physical
failure scenarios still need integrated runtime qualification. Clear-voice radio
backend, station datum/ident audio and native optical/recovery scenarios remain
open. Optional autoland/ACLS/automatic GCAS are not selected.

Deployment uses a cloned staging folder, exact source/DLL SHA256 manifests and a
complete previous-installation backup outside the aircraft directory. Recorded
WAV, shipped font/texture/model assets and saved user binding files are checked
for preservation. Qualification Export.lua, alternate profiles, build tools and
research artifacts are excluded. A restore script retains the playtest folder
while moving the previous installation back. DCS is not launched by deployment.

The package's build.json and installed F22-PLAYTEST.json record exact revisions,
DLL hash, checks, installation path and backup. Completed follow-up fixes are
installed into the same normal mod after their combined checks; the current
receipt identifies the latest source and DLL rather than implying the frozen
base is still the complete installed state.

Follow-up integration preserves the wing-datum turn correction, strict IR/AIM-9
preparation, measured-cadence gun adapter and deadline-based AESA scheduling.
Current power/engine indications use coherent physical data and show unavailable
fields explicitly. The next combined integration also contains strict CNI/radar
resource ownership, mandatory native NAV snapshots, selected GINS-only
HUD/ADI/NAV consumers and removal of the optional perfect-position INS path.
Independent standby/coasting and radio reception remain. The DEF page uses
routine controls plus explicit SETUP; blank keys retain no action authority.

That combined source passes 29/29 native tests (unused STT decoder test retired),
161/161 script checks, 269 Cockpit/Input/Weapons/root Lua compiles and zero new
navigation/radar lint findings. The current integration receipt, full previous
installation backup and file hashes distinguish this source qualification from
in-game flight/gun/AESA/failure/optical qualification. Other retained callback
and pre-provider cleanup work is not declared complete by this package.

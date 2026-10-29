# Podded IRST implementation

User-selected optional pod, independent of MAWS and embedded IRDS. Equip the
existing **IRST Sensor Pod on station6**, open **MENU → IRST** on any main MFD,
and provide mission electrical power. Search starts automatically. NEXT selects
a contact, TRACK follows it, DROP clears selection. SCAN cycles +/-30/60/90°;
AZ/EL and CNTR position the search. RAD CUE directs an operating air-search
radar toward the selected fresh bearing for five seconds. It preserves an
existing radar lock and does not turn on a silent radar. Radar detection and
pilot designation still establish radar tracking/weapon support.

Joystick and keyboard profiles append eleven `F-22 IRST` actions,11300–11310,
device30, without default combos. Existing command/device IDs remain stable.
Command11311 is the internal radar cue recipient. Page14 is appended; original
page IDs/order remain. The HUD shows a small circle marked IR for a selected
fresh contact inside its field. Existing HUD styling and audio are retained.

## Sensing and ownership

`NativeIRST` owns a separate1008-byte common `cockpit::avIRSensor`. It uses
CockpitBase/World/WorldGeneral only; no aircraft-module DLL is loaded or called.
It runs on the existing dedicated cockpit sensor callback, including when RF
emission is off. FM updates exchange controls/snapshots only. Init prebinds all
parameter handles and constructs the native sensor. A common SRW lock drains
the callback before power-off/destruction and serializes parameter retirement.
No native search timer is started. Native constructor/destructor own their
LinkBase-vector allocation; no cross-CRT free.

MCP/IDA review of DCS2.9.31.29434 verifies constructor41E8F0, destructor41EB20,
search41F460, admission callback41EBD0 and TrackData update43C3D0. The native
search applies own-object, aperture, sun and terrain checks. Its abstract
getLockonDistance slot19 is implemented by the mod, with the31-slot primary
table/RTTI prefix copied for this instance only. Electric methods receive the
secondary base at560. TrackData starts712; bearing/time offsets8/16/208.
Native-admitted LinkBase entries are read from984/992, stride24, link offset16.
Native host IDs stay private; publications use independent IRST file IDs.

Host guards: CockpitBase timestamp6ADBAD09/image68E000 plus constructor64-byte
FNV64 E2450E42520E7477; WorldGeneral6ADBACE0/127B000;
World6ACB804E/14000. Thirteen named common exports are required. Unsupported
profiles withdraw this new sensor without disabling existing weapons or MAWS.
Raw third-party decompilations remain in the external F22-Build analysis folder.

## Explicit estimates and limitations

This is an optional mod implementation, not a validated F-22 IRST21 model.
Detection sensitivity is a fixed estimated50km threshold; there is currently
no calibrated aspect/engine-heat/cloud/atmospheric attenuation model. Native
terrain, airframe and sun admission still apply. The estimated aperture is
1.5m forward/.5m below the native station mounting pivot. Carriage graphics,
mass/drag and the original AI sensor declaration are inherited unchanged.

Search uses16° half-cones at10Hz; +/-60° default search has15 dwells/1.5s,
wide21 dwells/2.1s. Vertical search positioning0..45° and the -15..60° accepted
field are mod policies. Track mode uses5° half-cones. Sixteen retained contacts
have a2.5s maximum age; a missed track exits follow after1s. Stored world-unit
bearings are reprojected for ownship rotation; their observation time is never
renewed by that projection. Overflow rejects additional files and is indicated.

The native engine performs its own scene traversal and can grow its internal
vector beyond its initial20 entries. That external implementation is an explicit
exception to the project-owned no-recurring-allocation/work bound: our call rate
is10Hz, extraction16 contacts, pointer/extent admission4096 entries. Engine
traversal/allocation cost and real host callback scheduling remain unmeasured.

The player page is an angular contact display, without video, laser ranging,
fabricated range, target type, coalition, hostile identity or release authority.
IRST contributes source bit16 to the awareness picture using measured angular
association. It supplies neither radar track IDs nor missile launch consent.

## Packet and cancellation contract

`F22_IRST_CONTROL_*`: Lua producer, schema fixed by declared field names,
World-clock physical source TIME, physical GENERATION, power/presence/station,
body-radian AZ/EL/WIDTH, optional selected sensor file ID. PHYSICAL_VALID requires
a coherent physical envelope and original World-stamp age<=.25s. Native input
lease is.35s; copying never changes the source stamp. Carriage is checked every
.2s through the actual shared weapon station API, station5 zero-based.

`F22_IRST_NATIVE_*`: native producer, independent EPOCH, World TIME, READY/REASON,
scan angles, overflow and16 rows VALID/ID/TIME/AZ/EL. The Lua owner publishes
`F22_IRST_*` for displays/fusion and gates it by current carriage/power. Both
groups use odd/even SEQ; readers capture marker before payload and recheck it,
epoch and stamp after used fields. Batch lease.35s; original row age<=2.5s.
Selected HUD/radar cue age<=.5s. Physical epoch change or World rewind retires
memory; retirement drains native use before parameter/context invalidation.

## Verification and remaining host check

Ten focused actual-owner Lua/profile cases and one native-owner executable
exercise controls, power/pod/frozen-source loss, packet tearing/staleness,
body bearing conversion, abstract sensitivity dispatch/electric-base ABI,
capacity, source IDs, rewind and callback retirement. The real page declarations
run through write-only element ports. The native port supplies admitted engine
observations; it does not emulate or prove native DCS detection. Release DLL
linking, Lua5.1 compilation, pinned luacheck1.2.0 and MSVC/analyze results are in
IRST-INSTALLATION.json. Native functions stay within complexity15; conditional
admission/publication paths11–15 retain explicit checks and fixed bounds.
Lua `IRST_System.update` retains the explicit clock/power/status/publication
branches as a reviewed complexity exception: fixed work and16 output rows,
no release authority, with off, missing pod, failed/frozen power, unavailable
source, search and track exercised through its actual owner. Lua-managed
parameter-name concatenation remains a bounded allocation exception.

Four existing MFD supply cases also pass. The six IRST cases additionally run
against the actual packaged Lua variants and their installed dependencies.
Five pre-existing installed store/radar/fusion variants receive only the IRST
additions; their other behavior is preserved. The package manifest records both
primary and installed-variant identities. Pending IFF changes in the shared
working Radar_System are excluded from this IRST-only deployment.

In-game detection, aperture clearance, loaded identity, performance and2D/VR/MP
effects remain to be observed in the user's next flight. No simulator is launched
or controlled for installation. Software checks are not a host effects pass.

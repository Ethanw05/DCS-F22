# SEN-01–04 radar: native-constrained service slice

Baseline: `f22-overhaul-start-2026-10-27` (`c5ebbcc`); branch `codex/radar-aesa-overhaul`.
This implements a bounded processing/resource slice and two pilot-workflow fixes.
It does **not** complete the independent AESA sensing replacement or close SEN-01–04.

## Architecture and evidence

| Candidate | Demonstrated capability / remaining cost | Decision |
| --- | --- | --- |
| Retain native detector and responder; own observation service | Existing detected-world samples, sample times, acquisition and missile responder remain usable. Native stepping and exclusive STT remain. | First integrated slice, named `native-constrained-service-v3`; scope explicitly says NATIVE. |
| Lower-level scan/scene adapter | IDA exposes scan-phase advancement and shared spatial query. Electronic point response, instance teardown, detection cadence and warning/support behavior need a controlled native test. | Investigate next; no unqualified hook installed. |
| Independent air detector behind a scene provider | Existing ground provider demonstrates the spatial-query approach. Air measurement error, LOS/clutter, scene lifetime and native acquisition/support need their own complete contract. | Replacement path remains open; no scene truth promoted to a radar contact. |

Read the actual `Radar_Native/System/Computer/Sensor_Tasking`, `NativeSidewinder` and
`NativeGroundSensor` owners and the cited audit cases AE01–10, AS03–04, AX11 and SG03.
Public evidence consulted:

- [Brower, *The Avionics Handbook*, 2001, chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf), §32.3.2 printed p8: interleaved search/track, electronic beam switching and graceful array degradation. This development-era description does not supply production performance or timing.
- [NOAA phased-array research](https://www.nssl.noaa.gov/tools/radar/par/), Electronic Steering/Rapid Scanning, and [RTX APG-79](https://www.rtx.com/raytheon/what-we-do/air/apg79aesa): pointing agility and adaptive coverage context; neither authenticates APG-77 parameters.
- Eagle Dynamics F-16C manual, early edition with change log through 31 March 2020, [publisher-supplied Steam PDF](https://shared.steamstatic.com/store_item_assets/steam/apps/1090850/manuals/DCS_F-16C_Early_Access_Guide_EN.pdf), pp121–124: distinct SAM/STT/TWS and track promotion. Its two consecutive scans are an analogue, not evidence that two arbitrary cache reads constitute a scan.
- Installed ED F/A-18C guide, `D:/DCS/Mods/aircraft/FA-18C/Doc/DCS FA-18C Early Access Guide EN.pdf`, pp171–176: ACM geometry, TWS centering and RAID. This is APG-73 behavior. Existing mod VACQ/WIDE dimensions and 10 NM VACQ remain explicit estimates, with no claim of Hornet preset parity.

Bounded read-only IDA research used the installed MCP plugin on a **copy** of
`CockpitBase.i64`. Database and installed `bin-mt/CockpitBase.dll` SHA-256 agree:
`163d55167503da8dd0ea9eb459e17206fc3dc8d6b4805b5b13bbe58341beb794`;
existing profile timestamp `0x6ac12468`, image size `0x59a000`.

| Address | Interface observation |
| --- | --- |
| `0x180340DF0` | Current pattern chooses distinct search/acquisition storage. A pattern request is not a measured beam. |
| `0x180343B20`, `0x180343A90` | Scan step/line advance angular phase. |
| `0x180343EA0` | Native scan uses that phase before spatial query; retained records have native sample timestamps. |
| `0x1803451E0` | Search, acquisition and STT are distinct native dispatch paths. |
| `0x180340E10`, `0x1803413D0`, `0x1803446B0` | Detection already includes terrain LOS, velocity/clutter, target response/range and acquisition gates. |

`tools/probe_radar_backend.py` independently checks PE identity and archived telemetry.
The 26 October `radar-acm-focus-20261026/native-dcs.log` contains 45 valid native beam
samples, 42 phase/beam changes at fixed command, scan-reference azimuth −57 to +55.5°.
This demonstrates native scanning in that recording; it does not measure a new
point-command step response or prove that a future adapter cannot change it.
Proprietary decompilation stays in the ignored local research directory, outside commits.

## Implemented behavior and interfaces

- `Radar_Service_State` owns 64 preallocated source slots and one active job, accepts at most 64 inputs per activity, and completes at most one result per activity. Newer pending samples replace older pending data; full capacity drops new sources. Support requests rank ahead of selected/designated files, then discovery; every fourth start reserves pending discovery. No task creates a detection.
- Estimated processing work is 25 ms × bounded requested-area factor [1,8] × off-axis factor [1,2] / resource; subsequent processing delay is 50 ms / resource. These are **game processing costs**, not measured antenna dwell, native revisit, detection probability or APG-77 waveform values. Native scanning still limits arrivals. A mode change, outage, time rewind or >0.5 s callback gap cancels backlog and requires newer evidence. Pause cannot advance work.
- Native sample time remains unchanged through processing. Public `AGE`, scope/HUD and responder extension use admitted samples. `MEASUREMENT_SOURCE=1` means native detection in `F22_RADAR_TACTICAL_%02d_` and selected status; existing `SOURCE` remains target ID. No source-2 owned scene observations, donor fire-control authority or calibrated covariance are published. Native STT keeps its checked low-latency sample contract; native acquisition still must confirm a lock. The original native responder remains native authority.
- Track storage is capped at 64, hit count at 255. A new sample after a gap greater than the existing freshness policy (6 s search, 1 s ACM) starts tentative again; two new timely observations restore maturity. This is a freshness-gap approximation, **not** proof of a missed eligible native sweep. Support lists and selected TWS target ID now use `supportable`, so retained display memory cannot restore that extension's authority.
- `Radar_Focus` uses `Sensor_Control.is_radar` for PMFD/LMFD/RMFD/CMFD. Both roles release held axes on focus/page/power/master-role loss; reopening requires new input. Startup compatibility remains until common layout publication. Global GUN/SRM ACM dispatch is unchanged. Navigation owner accepted this interface and separately owns held bezel release.
- Surface native types 1/2 mean acquired object; type 3 with ID 0 means fixed terrain fallback. MAP/GMT/SEA retain FTT instead of inventing GMTT/SSTT on empty terrain. Unknown type, invalid geometry or expired native data withdraws selection. Existing HOLD/SIL/ACTIVE, source-reference, EXP and renderer behavior remain with their existing owners.

Optional physical-resource contract: producer commits `F22_RADAR_RESOURCE_` fields
`SCHEMA=1`, `VALID=1`, positive integer `SEQUENCE` last, `TIME` model seconds, and
achieved `SUPPLY`, `COOLING`, `ARRAY` fractions [0,1]. A coherent publication must be
at most 0.5 s old. Resource is their minimum; below 0.1 withdraws native requested
power/readiness; partial loss lengthens processing. The physical owner must publish
actual achieved states. Navigation integration has the flight owner's proposed
`EFM_PHYSICAL_VALID/GENERATION/STAMP`, conditioned-air and equipment-temperature
fields; it must agree the mapping with freshness/generation checks before enabling
schema 1. In schema 0, legacy MAIN_POWER gating remains and
`F22_RADAR_SERVICE_HEALTH_KNOWN=0`; this slice does not invent healthy cooling/damage.
Vehicle integration is pending. New telemetry `v1,service_schema/service` exposes the
resource, queue, work/delay, source and capability state under the existing log cap.

Mode limits: RWS/TWS use the one native scan; acquisition is dedicated; STT provides
no background search; A/G owns surface sensing exclusively. Surface INTL means
surface image/GMT service, not A/A+A/G concurrency. Readbacks
`F22_RADAR_NATIVE_RESTRICTED=1`, `BACKGROUND_AVAILABLE`, and
`AIR_SURFACE_CONCURRENT=0` disclose that boundary. `NATIVE`, `PROC Qn`, and `SENS DEG`
indications expose backend, backlog and partial-resource state. Donor search-cue
ingestion is unavailable; weapons owner was asked to gate its proposed action until
`F22_RADAR_DONOR_CUE_READY=1` is actually supplied.

## Verification and remaining qualification

MSVC 19.51 / Visual Studio 18 2026 Release build succeeded; **20/20 CTests pass**.
No C++ source/ABI changes were made; existing D9025 `/UNDEBUG` override warnings remain.
Actual Lua 5.1 execution uses Lupa 2.6. New service, relocated-focus and surface-type
tests pass, as do affected observation/STT/support/cooperative and ground interaction
checks. Full Python suite: **108/133 pass**, versus **105/130** at the clean baseline;
the same 25 failures remain, with no additional failures. Full-suite output requires
`PYTHONUTF8=1` on this Windows host. This is not a green full-suite claim.

Luacheck **1.2.0**, standard `lua51`, explicit DCS globals in
`tools/lint_radar_lua.py`: zero new findings, 68 retained baseline findings (including the changed format).
Download the [tagged Luacheck source](https://github.com/lunarmodules/luacheck/tree/v1.2.0)
and pass its `src` directory with `--luacheck-src`; default is
`build-radar/luacheck-1.2.0/src`. Python versions are pinned in `tests/requirements-radar.txt`.
Actual Lua 5.1 parsing also verifies all radar modules and changed formats.

Consequential decision cases exercised: normal/partial/absent resources; invalid,
stale, future, unknown-schema and torn resource publications; unchanged/new native
time; processing deadline/pause; rewind/stall/outage; overflow/priority/fairness;
tentative/mature/coast/reacquisition/support withdrawal; all four focused displays
in both roles; FTT/object/unknown-type source boundaries. No native-lifetime logic
was added. A native branch-coverage percentage is not claimed. Legacy large
`Radar_System.update`, `Radar_Computer.update` and surface callback functions retain
their existing size/complexity and Lua-managed temporary allocations; this change
does not claim whole-file NASA compliance. The isolated service core's 10,000-update
test took about 0.02 s with 0 KiB stopped-GC heap growth on this machine; this is
offline cost, not DCS frame-time qualification. The new service validates source/time,
geometry and callback arguments in separate bounded helpers.

Actual Lua/native-font previews render the new NATIVE indication without clipping;
these are synthetic-input layout checks. This source has **not** been installed or
flown. New electronic pointing, independent sensing/measurement uncertainty,
concurrent air/surface service, physical cooling/damage integration and finite SAR
collection remain open. Existing native LOS/clutter and surface imagery are retained,
not newly certified. Integration must combine these commits with the cockpit and
weapons changes, then schedule controlled DCS normal/load/fault/recovery flights.

Local evidence: `build-radar/{backend-probe.json,regression-final.log,
baseline-regression.log,native-build.log,native-tests.log,preview/}`. The primary
checkout, installed mod, saved bindings, HUD styling and recorded audio were not edited.

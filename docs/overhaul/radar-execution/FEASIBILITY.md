# Radar feasibility preparation — 28 October 2026

Preparation for Chat 3 only. No package is complete, no production code/test was
changed, no build or simulator was run, and no selection or native qualification
was granted. Source hashes and requirement/finding/test IDs are in
`package-evidence-manifest.json`. Current constants and an independent validation
design are in `proposed-parameter-ledger.json`.

## Selection and SAR disposition proposed for integration

The actual `Equipment_Profile.lua` selects `radar=true` in
`public_f22_manual_recovery@1`. It contains no `coherent_sar` capability;
`supports` returns false for every absent capability. This does not authorize
an operational coherent-SAR mode or imply that the selected radar lacks useful
ground imagery. Current imagery remains the shared engine MAP/DBS renderer.

Proposed current decision: **NO-GO for enabling coherent SAR**, retaining current
MAP/EXP/DBS and RF-only collection credit. This is a precise feasibility limit,
not a decision to delete the original research or abandon later integration.
The historical research note recommends developing an owned pipeline and reports
standalone point-target/CPU/GPU results; it explicitly does not qualify DCS
environment collection, output publication, VR contention or a full footprint.
No new runtime experiment was performed here. P-RAD-005 must review/adopt the
decision after its actual P-RAD-004 and common-contract prerequisites.

The following missing contracts independently prevent operational selection:

1. A terrain/depth/object/visibility adapter with proved actual ABI, full output
   layout and allocation/destruction, units/frame, thread/phase and bounds.
   Existing terrain assembly establishes consumed height offsets, not complete
   PointOnSurface size. `querySurfaceMesh[Ex]` export names are candidate routes,
   not a qualified callable interface.
2. Actual render-pass/context ownership and an owned image publication point.
   Native parameter callbacks precede RadarMainPass, which can overwrite an image
   copied there. A texture-copy proof on a standalone context grants no DCS
   publication contract. Restore all borrowed context state and avoid blocking
   staging readback.
3. A fixed collection schema: generation, navigation/reference frame, grid,
   waveform/phase origin, bounded scene/scatterer policy, illumination lease,
   and processing state. Only completed granted illumination creates a history.
   Existing pointed GMT jobs do not count as search/SAR collection.
4. Integrated full-footprint CPU/GPU/allocation budgets and VR presentation
   evidence. Existing 24m synthetic patches, standalone batch medians and maxima
   are research measurements, not a DCS frame budget.

P-RAD-006 therefore remains dependent/selected-unavailable. Its safe current
disposition preserves the existing imagery owner. Do not introduce a second
image owner, draw known targets into pixels, or relabel DBS zoom as coherent SAR.
If a later qualified decision selects SAR, implement one generation with fixed
grid/waveform/reference, bounded pulse/processing queues, streamed GPU batches,
the last complete image shared between VR eyes, explicit incompatibility/reset
cancellation, and separate image quality/progress from target authority. The
declared complex-reference SER>=40dB criterion is numerical only.

## P-RAD-004 qualification plan and blockers

Prerequisites are P-INT-001/002/003/008, P-RAD-001/002/003 and D-P-RAD-001.
The integration STATUS observed during preparation still records common gates
pending. No runtime slot is claimed. Do not start/install/control DCS until the
integrator schedules an exclusive authorized slot.

Before the first run freeze current main commit, all source and built DLL/assets,
compiler/config/dependencies, exact installed default controls and saved-binding
diffs, host module hashes/PE profiles/exports/vtables, and all installed hooks
including activation filenames/control paths. An old loaded DLL or old log does
not qualify the current package. Retain the passive recorder and recordings.

Bounded actual-host campaigns must establish:

- Callback thread/phase/order and drain-before-destruction for driver, responder,
  scene provider, ground sampler and renderer; source lease/epoch withdrawal.
- Airborne exported `VectorVelocity` against ground/gun virtual slot38 under
  matched states, units and frames. Their difference is currently a question,
  not a proved ABI defect or permission to switch virtual calls.
- One target then concurrent missile targets with target-specific native effects
  and actual hit/effect records, plus A/A–A/G contention and donor behavior.
  A dispatch, ready flag or inventory decrement cannot prove the specific hit.
- SIL/ACTIVE/FRZ, moving MAP/EXP, pause/active pause, rewind, repair/re-slot and
  context destruction/recreation with original sample epoch retained for held
  pixels. Predeclare <=1pixel registration tolerance or a geometry-based reason.
- Foreign-indicator rejection before typed getters, malformed-buffer latch,
  coherent camera/point/parameter tuple, and finite source/derived geometry.
- Dense scene/jammer cases at declared caps:64tracks,32pending,128candidates,
  8returns/dwell and16LOS/dwell. Record overflow, p50/p95/p99/max CPU/GPU,
  recurring allocations and opt-in/default logging costs.
- Separate power/cooling/array failures and recovery, then actual 2D, VR and
  multiplayer/replication participants. Do not infer any missing layer passed.

## P-RAD-007 achieved IFF consumer disposition

P-WPN-004 belongs to Chat4 and must deliver **IFF_PROVIDER_READY** as a qualified
reply backend or an explicit tested unavailable/no-go. Chat3 consumes that seam;
P-RAD-007 is never a reverse prerequisite for the provider decision.

Current `AESA_Control.read` sets each measured observation's `iff=-1`.
`Radar_IFF.reply` exists but has no called reply path in the inspected radar
modules. `Radar_System` currently publishes requested/interrogator-enabled state;
it cannot establish an achieved reply. The proposed consumer schema must carry
provider readiness/unavailable reason, source track, request ID, epoch/clock,
source reply time and result independently of geometry time. No response remains
unknown. Unsupported/rejected/expired requests must be visible while preserving
saved controls and automatic/request intent. Scene coalition is never an IFF
reply. Chat4 owns identity/fusion semantics and the achieved backend decision.

## P-RAD-008 evidence and model-depth disposition

The proposed ledger separates historical F22 architecture, named general
engineering/host references, current code, software bounds and game estimates.
It supplies 37 reviewed constants and paired independent validation conditions.
It does not calibrate an aircraft. Current echo is inverse-fourth range with
bounded RCS/gain/resource/integration; noise is inverse-square equivalent J/N.
Current signal threshold/probability/clutter and uncertainty are simplified
game choices. The native ECM scalar supplies no RF watts or spectrum.

Proposed selected depth remains the existing bounded measured A/A estimator and
airborne co-channel noise abstraction. No complete CFAR/false-alarm population,
ambiguity resolution, deceptive jamming, ground/ship jammer reception, waveform
agility/adaptive nulling or quantitatively validated LPI/intercept model is
established by these files. Record those as unsupported/unqualified capability
depth until a complete feasible chain is selected; do not infer their selection
from `radar=true`. Active unsupported ECM must remain unavailable, not healthy
zero. Preserve selected simulator-assisted source2 gun provenance separately from
measured radar observation truth.

## Original reference passages checked

- [Brower, The Avionics Handbook ch32 (2001)](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf),
  PDF pp1–3 and8: historical sensor/fusion architecture, interleaved search/track,
  electronic steering and reduced power after module losses. No production
  schedule, waveform, range, RCS, current fit or SAR resolution was authenticated.
- [MIT Lincoln Laboratory abstract (2013)](https://www.ll.mit.edu/r-d/publications/dwell-scheduling-algorithms-phased-array-antenna):
  finite multifunction dwell scheduling. Full article was not retrieved; this
  establishes no validation of the project's scheduler or coefficient choices.
- [NASA SAR overview](https://science.nasa.gov/mission/nisar/get-to-know-sar/),
  phase-history and range/azimuth discussion: coherent motion compensation is
  distinct from image magnification. Satellite examples are not fighter data.
- [Microsoft D3D11 threading](https://learn.microsoft.com/en-us/windows/win32/direct3d11/overviews-direct3d-11-render-multi-thread-intro),
  context/DXGI section: context access requires serialization and appropriate
  ownership. This says nothing about private DCS callback/layout/lifetime ABI.

The SAR research and optimization note was read as historical original
measurement evidence; its local logs, binaries, IDA databases and GPU recordings
were not replayed. No old test expected result was used as an acceptance oracle.

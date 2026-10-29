# Radar additions requested on 28 October 2026

These are delivery requirements requested by the user during execution, not
completed features or permission to enable an unqualified runtime backend.
They extend the current radar assignment and must remain open until delivered.

- [ ] **R-RAD-021 — A/A surveillance during A/G operation.** Maintain measured
  airborne search, discovery and track maintenance while A/G MAP/GMT/ranging/SAR
  receives its finite share of the same AESA. Publish fresh A/A reports to the
  tactical picture while the pilot uses A/G; do not depend on opening an A/A
  page. Exercise new targets entering after the A/G transition, retained targets,
  priority obligations, surface collection, degraded resource, SIL/power loss,
  pause, reset and return to A/A. Preserve original observation times and bounded
  work; no invented detections or independent second array owner.
- [ ] **R-RAD-022 — Coherent SAR.** Deliver an actual selected coherent
  pulse/phase-history collection and image-formation chain with radar controls,
  collection/processing state, georeferenced image, designation and pilot
  feedback. Current MAP/EXP/DBS imagery is not SAR completion. Establish the
  terrain/scatterer/visibility and native render/owned-texture contracts, source
  navigation and generation, RF illumination leases, bounded pulse/processing
  work, cancellation/recovery and measured CPU/GPU/2D/VR budgets. Select the
  documented applicable radar variant and label unsupported performance values
  as estimates. Installation and actual native qualification remain explicit.
- [ ] **R-RAD-023 — Consistent identity policy across RWR and radar.** The last
  flight logged a hostile RWR emitter while its RF-correlated selected radar
  track remained unknown/yellow. The RWR accepts DCS coalition metadata; the
  radar correlation carries label/signal only and scope color uses separate IFF.
  Resolve the policy with Weapons-EW's identity/fusion owner and implement the
  radar consumer with original evidence age, provenance, clock/epoch and friendly
  protection. Keep achieved IFF distinct from passive/simulator identification;
  an alert color or missing reply cannot establish hostile identity. Diagnosis:
  [last-flight evidence](host-update/RWR-RADAR-IDENTITY-DIAGNOSIS.md).
  The user subsequently selected coalition metadata for radar. The radar adapter
  now carries coalition on detected reports, including non-emitting aircraft;
  scope color and the selected-friendly flag consume it independently of IFF.
  [Implementation and verification](coalition-identity/README.md). Flight
  confirmation remains pending; no further identity-policy approval is required.

## Starting code and evidence

The source already has a background A/A path: `AesaRadar::Model::start` schedules
air jobs between surface jobs, and the A/G branch of `Radar_System.update` reads
the owned A/A reports and publishes them tactically. This is evidence of intended
source behavior, not proof of fresh airborne detection, pilot presentation or
the installed/loaded binary. R-RAD-021 therefore requires an end-to-end continuity
probe and correction of whichever layer fails, rather than assuming those
existing calls establish successful operation. The current three-job cycle is a
game scheduling policy; it is not a recovered F-22 timing specification.

Northrop Grumman's [14 February 2008 SAR demonstration announcement](https://investor.northropgrumman.com/news-releases/news-release-details/northrop-grumman-completes-successful-demonstration-new)
documents airborne high-resolution SAR maps and identifies SAR with the
AN/APG-77(V)1 air-to-ground additions. It describes test-bed demonstrations and
planned fleet integration, not exact current-fleet software, radar timing,
resolution or this mod's host integration. Its [APG-77 product page](https://www.northropgrumman.com/what-we-do/mission-solutions/radars/an-apg-77-aesa)
supports the general A/A and A/G roles; it does not by itself establish exact
simultaneous scheduling. Capture variant and source limits in P-RAD-005/008.

## Plan integration

R-RAD-021 extends P-RAD-004's A/A–A/G contention/qualification chain. R-RAD-022
changes P-RAD-005/006 from a possible selected-off disposition into a requested
implementation goal with explicit feasibility blockers. An unavailable backend
must still report unavailable while engineering proceeds. P-RAD-008 carries the
evidence and calibration ledger. The integrator should adopt these additions in
the canonical backlog/profile decision without marking them complete or enabling
unsupported private interfaces. The existing MAP/DBS image owner remains active
until a proven SAR cutover.

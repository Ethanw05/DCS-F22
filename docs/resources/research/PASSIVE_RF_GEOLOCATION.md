# Radar/EW functionality — 26 October 2026

This change connects conditional ground-emitter geolocation to the receiver,
common tactical store, defensive overview/detail and tactical display.
No native DLL, device registration, air-to-ground radar or weapon code changes
are needed for this feature.

## Functional boundary

The public F-22 avionics description supports integrated sensor tasking, and
BAE describes passive awareness and targeting support for ALR-94:

- Ronald W. Brower, historical F-22 avionics chapter:
  https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf
- BAE Systems, AN/ALR-94:
  https://www.baesystems.com/en-us/product/an-alr-94

These are functional goals, not specifications for the model's coefficients.
The algorithm here is an original, conditional bearing-only estimator using
the supported DCS common receiver. It is not an operational ALR-94 algorithm,
calibrated RF accuracy model, APG-77 RF simulation or precision weapon target.
It adds no IFDL/Link 16 transport and no automatic countermeasure dispensing.

Airborne RF cues continue to steer actual native radar search through
`Radar_Sensor_Tasking.lua`. That separate feature is documented in
`COOPERATIVE_SENSOR_TASKING.md`. RF alone creates neither a radar detection nor
a lock, range measurement or missile-support solution. Existing radar files
and missile-support obligations take priority; manual scan edits inhibit RF
steering for eight seconds.

## Receiver and estimator

Only measured, attitude-qualified ground RF bearings enter geolocation. The
checked common receiver's general-type taxonomy is 1 aircraft, 2 ground,
3 ship, 4 weapon. No mission object, target position, coalition truth, terrain
query, received power or radar range is used to locate the emitter.

`RWR_Bearings` first reconstructs the world direction from reception-time
attitude. `EW_Geolocation` interpolates ownship position at that same reception
time. Pairing a remembered bearing with current ownship position would create
false geometry during motion; the delayed-reception tests exercise this path.

The isolated prototype could never qualify a continuous receiver stream:
its newest twelve samples spanned at most 1.65 seconds in the 45-second probe,
while the fit required eight seconds. The integrated implementation samples at
1.5-second intervals, retaining at most 32 rays within a 45-second window.
Ownship position history remains at receiver update frequency.

Three-dimensional least squares minimizes perpendicular distance to the rays.
The following are explicit mod qualification limits, not published F-22 limits:

| Requirement | Value |
| --- | --- |
| Samples / reception span | At least 5 / 8 seconds |
| Ownship end-to-end baseline | At least 1,000 m |
| Departure from the horizontal baseline chord | At least 100 m |
| Measured LOS parallax | At least 5 degrees |
| Angular fit residual RMS / maximum | At most 0.6 / 1.5 degrees |
| Estimate range | 500 m to 300 km |
| Model error radius | At most 10 km and half the current estimated range |
| Estimate lifetime | 6 seconds from the newest fit sample |

The radius uses a one-degree assumed angular error, geometry conditioning,
a systematic angular floor and a 30 m/s ground-motion allowance over the fit
span. It grows by another 30 m per second of estimate age. It is a model error
envelope, **not a statistical confidence level or guarantee of true position**.
Changing these numbers changes the community model, not the real aircraft.

The stationary-ground assumption is conditional: some moving-emitter cases
can remain ambiguous. Straight flight, attitude motion without translation,
weak parallax and inconsistent rays do not qualify a fix. A fresh bearing that
contradicts a retained fix withdraws it before the next decimated fit is due.
Power loss, invalid ownship data, a receiver activity gap, mission-time rewind,
teleport or loss of the eligible emitter clears its fitting history.

## Indications and use

The air-to-air radar page retains its preceding SCAN MAN/AUTO and AZ/HT/EL
readouts. Task-specific SCAN RF / SCAN SUPPORT labels were removed on user
review: they were invented mod diagnostics, with no verified F-22 reference.
Internal task parameters and logs remain available for debugging. SCAN MAN/AUTO
is also an existing mod indication, not a newly verified real-aircraft format.

On RMFD DEFENSIVE, select **DETAIL** and inspect an emitter with **NEXT/PREV**:

- **BRG ONLY / COLLECT**: insufficient independent bearing history.
- **BRG ONLY / MANEUVER**: insufficient ownship translation/curved baseline.
- **BRG ONLY / GEOMETRY**: parallax, fit or error limits do not qualify a fix.
- **RF EST NM**: estimated slant distance, with **ERR** model radius in NM and
  the fit's own **AGE** in seconds.

The defensive overview uses an open diamond marked **E** for estimated
locations. Unlocated threats remain on the outer bearing ring. Valid radar
range retains its existing symbol and has precedence for that contact.

The tactical overlay shows **RF EST** diamonds and two clipped error-radius
cross arms in the map's distance scale. These are separate from radar symbols.
An on-map estimate suppresses its duplicate bearing-ring symbol; an off-map or
withdrawn estimate falls back to a bearing cue. The existing passive-layer
toggle controls both. Estimates preserve explicit affiliation; the ground
emitter category never implies hostility.

The independent MFD freshness gate hides estimated tactical marks, overview
symbols and detail if their shared RWR producer stops publishing. Continuous
RF traffic cannot renew the age of an expired fit. `RANGE_VALID`, measured radar
range and fire-control inputs never receive this estimated location.

## Validation and limits

`test_ew_geolocation.py` exercises observability, continuous 20-Hz input,
delayed reception, singular/invalid geometry, bounds, expiry, contradiction,
taxonomy, power, rewind, teleport and activity gaps.

`test_ew_geolocation_transport.py` executes the actual RWR/radar owners and
common store during a synthetic turning flight, then checks the actual native
element graphs. It verifies all consumers, heading-up reprojection, independent
fit expiry, no fabricated radar range/lock/fire commands, startup parameter
bindings and stale-owner withdrawal.

The complete shared regression suite passed **99/99 scripts** for this source
checkpoint. These are source tests with synthetic inputs, not a DCS flight.
Native reception timing, intermittent real-world emitter behavior, visual
readability and location accuracy still require flight validation. The SHA-256
release manifest records the tested/deployed file hashes; no live flight
acceptance or operational F-22 fidelity is implied.

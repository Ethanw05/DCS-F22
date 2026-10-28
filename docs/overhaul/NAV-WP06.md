# NAV-WP06 — route passage, marks and arrival

The independent nine-slot mark bank is a mod adaptation of the Hornet mark
workflow; nine is the selected provisional capacity, not authenticated F-22 fit.
Ownship capture requires valid estimated position; target capture requires an
accepted ground designation. Capture/inspection never selects a route point,
creates direct-to or grants weapon authority. Explicit M-TO freezes a selected
mark snapshot. Overwriting that bank slot cannot retarget steering; HOLD identifies
the retained snapshot. WYPT or explicit waypoint step returns to the retained route.
Mission reset clears marks; ordinary page changes do not. Power loss cancels
transient mark steering and pending commands while preserving the accepted bank.

NAV MARK/TIME DATA has capture-own, capture-target, slot inspection and explicit
M-TO controls. UFC provides correlated slot selection and the independent arrival
editor. The original MARK binding uses the same bank and no longer appends a route
point or creates direct-to as a capture side effect. Signed MSL waypoint entry
uses the separate elevation-sign modifier.

Arrival uses a deliberately **manual UTC reference**; it never relabels an
unverified DCS local mission clock as Zulu. Enter six-digit UTC, arrival, timing
destination ID and an explicit same/next-day selection. Timing destination is
independent of steering/mark selection. Required ground speed uses distance to
the active route point plus intervening route legs; a destination behind the
active point is explicitly DIRECT. Direct TTG remains separately labelled.
Past arrival, missing reference/distance and required speed above the provisional
600 m/s planning bound have distinct states. That bound is a game planning policy,
not a flight-envelope guarantee. Timing never commands the throttle or autopilot.
Changing/losing the clock reference invalidates its deadline; there is no silent
next-day interpretation or resume after restoration.

Route sequencing now recomputes once without recursion and retains one passage
per update. Direct/final arrival publishes a terminal event. CPL transfers to
current-heading hold while retaining healthy pitch selection; selected course
continues outbound. Source restoration never engages a mode. The navigation frame
uses the coherent publication described in ARC-02.

Actual owner tests cover bank wrap, invalid capture, frozen direct snapshot,
route/weapon isolation, explicit UTC/arrival commits, midnight, past/limited RGS,
remaining-route distance and outage cancellation. Existing geometry, designation,
source and UFC regressions pass. Native path capture/dynamics, fly-by anticipation
and F-22 procedural fidelity remain outside these tests.
# NAV source and sequence display interaction

Chuck's F/A-18C guide, Part 15, pp. 669, 671, 681-682, distinguishes
the selected steering source, SEQ route-line visibility, and AUTO sequencing.
The F-22 mod adopts that workflow as an interface analogue, without claiming
the original aircraft's controls. Pressing the selected WYPT, TCN or ILS key
now clears the selected source; selecting another key switches directly.
The selected point and target designation survive source deselection, while
waypoint steering and automatic sequencing withdraw. SEQ1 independently
shows or hides route points and legs, retaining the selected waypoint.
The source-off state does not claim loss of the independent ILS receiver.
Only the mission's one route is implemented; the Hornet's multiple sequences,
moving-map background and other unsupported HSI functions are not implied.

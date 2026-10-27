# Held roll input and GitHub comparison

The reported symptom is roll stopping after roughly half a second at a held
joystick position, then resuming only when the axis moves. Pitch remains usable.

GitHub `origin` was fetched on 27 October 2026. Comparisons used the original
2025 `fbefc20`, the pre-checkpoint `4fdd5fc`, and current remote main `c5ebbcc`
(also the overhaul start tag), against the flight implementation branch.

| Path | Comparison |
| --- | --- |
| Joystick roll command 2002 and retained axis value | Same basic ownership in all three earlier revisions and the overhaul |
| Roll damping and squared-stick command | Retained; trim and AFCS contributions were added before the overhaul start tag |
| Achieved aileron movement / drawing | Time-based achieved surfaces were introduced before the start tag; current physical work adds configuration mixing and damage weighting |
| Differential stabilator allocation | Current overhaul uses pitch priority and residual roll authority instead of independent clipping |
| Hydraulic/electrical supply | Current overhaul replaces the Lua power availability dependency with one EFM physical owner |
| Keyboard roll release 198/200 | All earlier revisions unconditionally selected zero keyboard input, even while a joystick owned the axis |

The last row is a reproduced defect. A single full-axis command followed by an
otherwise unrelated keyboard release changed `roll_analog` to false. The stored
axis remained nonzero, but the control law read the zero keyboard request. A
new axis event reclaimed ownership, matching the reported stop/resume pattern.
This mechanism does not establish which events the user's host actually sent.

The correction releases only a matching active keyboard direction. It preserves
a held joystick, ignores an opposite key's late release, and retains real axis
centering and keyboard press/release. It does not change roll gains or invent
repeated joystick events.

`held_roll_input_ownership` in `test_vehicle_overhaul.cpp` failed against the
unfixed DLL, then passed with the correction. Both roll directions, each orphan
release, ten seconds without a repeated axis event, genuine axis centering and
opposite-key release ordering are checked through force/moment callbacks. All
25 combined native tests pass. A separate 36-case scalar roll-axis feedback
probe with steady inputs remained continuous; it does not reproduce a full
six-degree-of-freedom DCS flight. No installed mod or simulator was changed.

Default `Saved Games/DCS` DLL inspected during diagnosis was a 04:18 build
(SHA256 `a1224b2bb6825ed3d657a8bf93346d8cd1da0e75b6e93243943afef967524caa`),
not the new physical implementation. The radar chat's isolated profile points
to its older branch; neither runtime can be assumed to contain today's source
changes. Runtime qualification and the actual input-event cause remain open.

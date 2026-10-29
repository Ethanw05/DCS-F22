# Radar coalition identification

The user selected DCS coalition metadata for radar identification after the
28 October flight showed a red defensive contact and a yellow radar track.
This supersedes the previous scope policy that excluded simulator coalition.

The qualified scene adapter reads the same named `MovingObject::Coalition`
export already used by received-emitter metadata. Same combat coalition is
friendly/green, opposing combat coalition hostile/red; neutral, invalid or
unavailable sides remain unknown/yellow. This optional metadata export does
not gate radar sensing. The target need not emit or appear on the RWR.

Metadata travels from the candidate through an actual completed detection,
processing queue and geometric association to the owned radar report. The
existing coherent packet adds `COALITION_KNOWN` and `COALITION_AFFILIATION`;
its original measurement `TIME` and generation remain authoritative. Failed
association withdraws identity. There is no host-ID join, additional world
search, invented detection, or renewal of observation time by copying data.

The radar retains these fields and uses current associated metadata for scope
color, including the synthetic presentation row for a priority lock. Selected
friendlies publish the existing friendly flag consumed by engagement inhibition.
Missing flags default to unknown, so an older DLL cannot create hostile identity
from parameter storage initialized to zero. Coalition presentation accepts the
existing twelve-second radar memory limit; invalid/future/stale clocks cannot
promote it. Actual IFF reply values and request/provider state remain separate.

Verification exercises the actual source modules and the planned installed
controllers. The controller installation applies focused changes to the normal
mod's `Radar_Computer.lua` and `Radar_System.lua`, preserving the unrelated
source/install control and held IFF differences. Display and metadata modules
match their main source. Native source/build identity, tests and installation
hashes are recorded beside this document. No simulator operation is performed.

Software and installation verification do not establish post-change flight or
VR behavior. R-RAD-023's radar policy correction is implemented; the next flight
must confirm the actual displayed colors. Weapons-EW retains IFF/provider and
general tactical-fusion ownership.

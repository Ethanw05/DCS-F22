# MIS-01 — transactional preplanned data

`Mission_Data.lua` schema 1 owns independent route (256 points), planned-zone
(32) and radio-preset (40 data records) partitions. Each envelope has source/date
provenance and items. Dense array shape, capacity, finite coordinates, altitude,
datum and scalar domains are checked before replacement. Failed validation leaves
the previous partition and generation unchanged; caller tables are not retained.
No partition can create a live contact, identity observation or tuning command.
Preset data validation does not prove radio band/spacing/backend support.

The existing host route importer now stages the complete route. Reload failure
retains the accepted route. Host date is `UNSPECIFIED` because this callback does
not establish a source date. The existing first mission point as origin policy
is retained. Explicit successful reload supersedes cockpit route edits, withdraws
pending NAV entry authority and invalidates an old waypoint draft by generation.
Signed waypoint elevation has an explicit UFC sign modifier and accepted-value
readback; it does not edit QNH or the physical terrain.

Only the route partition is connected to the host loader in this slice. Other
partitions are bounded data contracts awaiting selected producers/consumers;
map imagery, file import, network/ROE defaults and an alleged F-22 DTC replica are
not enabled. Cartography is optional and is not substituted with enemy truth.
Actual Lua tests cover corruption, sparse/over-capacity shape, out-of-domain
coordinates, aliasing, independent partition failure and live-authority exclusion.

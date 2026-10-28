# Received-emitter game affiliation

Search/lock RF contacts previously defaulted to unknown unless geometry-qualified
radar/donor evidence identified them. A launch warning could establish hostile-act
evidence. That policy explains the player's persistently unknown RWR pings.

NativeContactIdentity now supplies DCS coalition metadata only for the16 source
IDs already present in the passive receiver. The same qualified object resolver
used for datalink senders resolves those IDs. The borrowed object's viObject ID,
active-presence flag, live state and coalition are checked synchronously. The
adapter never enumerates objects or reads target position/velocity, never joins
RF IDs to owned radar track numbers, and owns no native scene objects.

WorldGeneral's exported MovingObject::Coalition and IsFlag/IsDead calls are bound
only under the matched CockpitBase6ac12468/59a000, WorldGeneral6ac122f4/125b000
and World6aae1d9b/14000 profiles. DCS Scripts/Database/db_countries.lua defines
neutral0/red1/blue2. Same combat coalition maps to friendly1, opposing combat
coalition to hostile0; neutral, missing and invalid records remain unknown.
This is an explicit game identification policy, not a modeled IFF exchange.

At most16 lookups occur per50ms update. A coherent even sequence includes the
publication clock, received source ID and original emission epoch (now minus
native receiver age). The Lua reader rejects torn/future/stale packets and
expired emissions. RWR_System passes the affiliation through the existing
tactical picture and DEF/SA palette: green friendly, red hostile, yellow unknown.
Warning severity retains its separate indication. Friendly protection remains
active; no source position or range is invented. Attack radar power is irrelevant.

The actual native bridge test covers same/opposite/neutral coalition, absent,
dead, dormant, reused-ID, malformed-source and expired records, power/read/API
failure and clock reset. The actual RWR owner test covers receiver-to-DEF colors,
friendly protection, independent attack radar power, torn/stale/foreign metadata
and unknown handling. Native metadata and image fixtures pass /W4 /WX /analyze;
all new metadata functions are below the15-decision project limit. Flight logs
now include the provider's ready/reason/time/sequence. Real DCS affiliation calls
and displayed colors still need a flight check; substituted-host tests do not
qualify those effects.

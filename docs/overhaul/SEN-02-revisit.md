# AESA service deadlines and latency correction

The player log had a median 306ms selected-track measurement interval. The model
used a single 250ms priority wait, 60ms processing and a requested 60Hz callback.
Those were mod policies, not measured APG-77 limits. The gun consumer's separate
150ms gate rejected this stream before issuing any native solver request.

The scheduler now uses earliest deadlines with lookahead before starting a long
search dwell. Acquisition/STT and missile support request 50ms revisits, GUN
requests 25ms, and routine designations request 100ms. These are game estimates.
They are requests under contention; missed deadlines are counted. Discovery
reserves a quarter of air RF time under load, rather than a quarter of jobs with
unequal durations. Surface jobs retain their two-in-three array allocation.

Search dwell remains 20ms. Tracking chooses 4..20ms from measured range/off-axis
geometry, using an explicit 1m² scheduling estimate and target signal budget4.
Actual sensing still uses the environment's RCS, visibility and beam gates.
Shorter looks scale integrated signal energy and Doppler uncertainty; they do
not grant unchanged long-dwell performance for less array time. Processing is
12ms before resource scaling. The existing 32-report queue bounds the pipeline.

The avLua clock requests 240Hz. Actual host timestamps govern all work; one
callback can finish at most one dwell. Pauses cannot renew reports or repeat a
surface grant, and a host stall cannot manufacture historical measurements.
The ground consumer accepts completed surface grants despite its coast-refresh
throttle. Native owner/version/lifetime and coherent snapshot guards remain.

The C++ replay records fresh filtered measurement timestamps after warmup:

| Scenario | Mean measurement interval | Maximum report age |
| --- | ---: | ---: |
| One close GUN target, 240Hz callbacks | 25.0ms | 58.3ms |
| Same target, 60Hz callbacks | 51.0ms | 100.0ms |
| One STT target, 240Hz callbacks | 46.5ms | 100.0ms |

Ten angularly separated targets retain service with a maximum completed-look gap
154.2ms and discovery fraction26.4%; overload is reported. Tests also exercise
blocked LOS, queued pre-block returns, reduced resources, paused/stalled clocks,
surface-grant delivery and actual native publication/role controls. Release
build, 30/30 CTests, 160/160 Python/Lua checks and zero new radar lint findings
pass. Changed scheduler helpers stay within CCN15/NLOC60. Pre-existing native
API resolver/query/registration complexity exceptions remain outside this fix.

These are offline results, not an in-game rate guarantee. New role inputs,
`AESA_Control`, `Radar_Native`, telemetry and the native DLL must be packaged
together with the flight and gun fixes. Gun prediction/quality policy remains
the weapons owner's responsibility; faster sensing cannot replace proper
handling of asynchronous measurements or establish a gun solution by itself.

Scheduling references: [MIT Lincoln Laboratory, 2013](https://www.ll.mit.edu/r-d/publications/dwell-scheduling-algorithms-phased-array-antenna)
and [Johns Hopkins APL, 2020](https://www.jhuapl.edu/technical-digest/issues/vol-35-no-2-2020/integrated-air-and-missile-defense-resource-management).
They support managing finite search/track dwells and deadlines, not these
estimated timings or authenticated F-22 performance.

# I-INT-003 checked native parameter cutover

Owner/integrator: Chat 2. Tested migration port for all four owners; no second
unchecked acceptance contract may remain after caller migration.

`EDPARAM` must be inert during static construction. An explicit `initialize`
resolves the current CockpitBase exports at a declared callback boundary. It
returns readiness independently of field conversion. `invalidate` clears exports
and borrowed handles at release, changes epoch, and prevents calls until a new
initialization. No assumption that a readable address proves native lifetime.

Numeric port: `bool getParamNumber(void* handle, double& value) const noexcept`.
It returns false for a null handle, missing export, false conversion or nonfinite
payload, leaves the caller's output unchanged on failure, and preserves valid
zero. String reads return bool and bound buffers; writes/resolve operations check
their own export/handle preconditions. No exceptions cross a host callback.

Each caller must explicitly withdraw dependent validity/requests on failure.
It may retain a previously finite payload under an invalid gate; it cannot
convert failed read into a healthy zero or refresh observation time. Already
direct bool-checked readers remain intact. Native API readiness is independent
of supported private profiles, group coherence, units, clock/age and generation.

Cutover regions: the two shared API headers, RAPTOR initialization/parameter
cache/read/entry/lighting/refuel adapters, and the small get/read adapters in
NativeNavigation, NativeAltimetry, NativeGunSight, NativeSidewinder,
NativeAGWeapons, NativeGroundSensor/Video, NativeDatalink and NativeMWS.
The owner must migrate each actual use, including comparisons and conversions;
returning NaN from an old getter alone is not a complete migration. Header-only
API breakage is not permitted while another domain builds against the old port.

Actual-wrapper replacement fixtures are in `tests/native/parameter_host.cpp`;
the current pre-fix failure is logged separately. Required cutover cases: absent
module/each export, failed conversion with retained/modified 0 or 7, valid zero,
nonfinite/string/null, initial missing module then explicit rediscovery,
invalidation/reacquisition and reused context addresses. Real DCS callback
ordering, handle lifetime and concurrent use remain a separate native gate.

The checked numeric port, guarded resolve/writes and bounded bool string read
are implemented. The constructor is inert and the value-only getter is removed;
the entire native DLL compiles against checked reads. NativeAltimetry retains
its safe direct standby reader. Gun/bomb/IR/datalink adapters capture required
fields with conversion status, then reject incomplete requests before their
dependent native work. Bomb requests require the actual schema2 producer;
the obsolete live-field fallback is retired.

Explicit startup discovers exports; release withdraws cockpit production,
resets native owners and invalidates its parameter port. Actual-DLL fixtures
exercise initial host absence, startup rediscovery, release, late callbacks and
new startup. Existing domain packet readers retain original source leases and
context epochs. P-INT-008 still requires supported DCS context/allocator lifetime
and producer-drain qualification; sequential software fixtures do not establish
native concurrency or safety after a host module disappears.

# Independent replacement test ports

P-INT-002 replaces the shared runner and host layer. Only `cases/` and `native/`
are acceptance sources. The remaining old files are quarantined from this runner
and CTest while their assigned owners delete/remake them; they are not a second
acceptance suite. See `docs/overhaul/integration/TEST-RETIREMENT.json`.

Use the pinned environment in `tools/requirements-navigation.txt` (Lupa 2.6,
Lua 5.1). Configure with BUILD_TESTING=ON in an external build directory, build,
then run `python tests/run_all.py --build-dir <external> --output <external>`.
The default `--scope common` measures HARNESS_READY independently of domain
work. `--scope all` also runs rebuilt domain cases and all registered native
cases, returning failure for unmet domain requirements without revoking a
successful common gate.
No build, test or probe installs a DLL, runs a hook, launches DCS or sends inputs
to a user's simulator. The new Lua port requires explicit sensor exports and
physical samples; zero-initialized native parameter storage is not a healthy
source. Nil, wrong types, nonfinite values and sample mutation remain injectable.
Elements enforce write-only properties and numeric-string coercion.

`probes/known_failures.py` calls actual owners and records unmet independent
requirements separately. HARNESS_READY requires successful self-checks and the
declared pre-fix observations; it grants no aircraft, hook, loaded-DLL, optics,
audio or multiplayer qualification. When a defect is fixed, migrate its probe
to normal/limit/failure/recovery acceptance and update the stage gate deliberately.

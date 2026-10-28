# F-22 Lua and C++ coding standard

Applies to all new and modified project-owned Lua and C++ during the overhaul. Existing code is migrated in reviewed changes rather than reformatted wholesale. This is a NASA/JPL-inspired project standard, tailored to a DCS mod; adopting it does not establish NASA certification or current code compliance.

## Core rules

The foundation is Gerard Holzmann's [Power of Ten](https://spinroot.com/gerard/pdf/P10.pdf), pp2â€“5. Its original language target is C; the project adaptations follow below.

| Rule | Project requirement |
| --- | --- |
| 1 | Keep control flow explicit; avoid recursion and unstructured jumps. |
| 2 | Bound loops, queues, retries, contact lists and per-update work. |
| 3 | Allocate resources at initialization; keep recurring simulation work within declared memory limits. |
| 4 | Use small functions with one responsibility; target roughly 60 statement/declaration lines. |
| 5 | Check meaningful preconditions, postconditions and invariants without side effects. |
| 6 | Keep mutable data in the narrowest practical scope. |
| 7 | Validate inputs and handle returned status; make deliberate ignored results explicit. |
| 8 | Keep macros and conditional compilation simple; prefer typed constants and functions. |
| 9 | Limit indirection; isolate unavoidable native function pointers and casts. |
| 10 | Use compiler diagnostics and static analysis; resolve findings or record justified exceptions. |

The length target means approximately 60 normally formatted source lines containing statements or declarations. Splitting statements onto fewer lines does not satisfy it. Prefer cyclomatic complexity 10 or lower; above 15 requires a documented, reviewed exception. NASA [SWE-220](https://swehb.nasa.gov/spaces/SWEHBVD/pages/105709643/SWE-220%2B-%2BCyclomatic%2BComplexity%2Bfor%2BSafety-Critical%2BSoftware) specifies 15 or lower for its identified safety-critical components. The tighter target 10 is our project choice.

## C++ adaptations

- Preserve the declared toolchain, C++ version and DCS ABI until an explicit migration changes them. Use typed constants, scoped enums, initialized values and unit-bearing names or types.
- Use scoped ownership and RAII for owned resources. Borrowed DCS pointers remain non-owning. Private native objects require the matched native allocator/destructor; a generic smart-pointer deleter is not sufficient.
- Preallocate recurring contact, job and publication buffers. No unbounded container growth, allocation, file I/O, waits or initialization in physics/render/sensor callbacks. Bound substeps, ray queries and work per callback; define overflow behavior.
- No exception may escape an exported or host/native callback. Use explicit status and a controlled failure state for ordinary errors. A catch-all is not a substitute for valid lifetimes, correct ABI or bounds checking.
- Put private offsets, layouts, casts and function pointers in narrowly scoped, version-checked adapters. Validate instance ownership and lifetime as well as readable memory. Withdraw affected capabilities when a profile or guard fails.
- Publish coherent snapshots across threads. Identify producer, generation, units and sample time. Stop callback producers and outstanding uses before freeing resources; keep complex work out of `DllMain`.

These ownership choices follow the [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines), particularly R.1, R.3 and I.2, with callback and allocator constraints specific to this mod.

## Lua adaptations

- Use the simulator's Lua 5.1-compatible language subset. Default to locals and explicit module state. Keep only host-required entry points/configuration globals in the host environment.
- Lua allocates and collects tables, strings and closures automatically. Therefore a literal whole-runtime allocation ban is not claimed. Reuse update buffers, cap retained tables/history, avoid per-frame closures and string formatting, and measure allocation/GC cost. Do not change the host-wide collector without a demonstrated need.
- Check missing values, types, finite numbers, units and valid flags before calculations. Lua treats numeric 0 as true; normalize boolean/numeric native statuses explicitly.
- Handle both the status and result of `pcall`. Report a bounded diagnostic and invalidate the affected result on failure. An absent reading is not a healthy zero; a successful call is not proof of a completed physical action.
- Keep state changes, command routing and publication separate from rendering. A page refresh must not integrate physics, generate sensor measurements or repeat a release.
- Match native indicator formats to host parameter storage. Numeric-looking Lua strings can become native numbers: use floating-point formats for numeric readouts and separate static unavailable labels gated by validity. Treat `CreateElement` properties as write-only; keep Lua declaration data when constructing related elements.

Language behavior is documented in the [Lua 5.1 Reference Manual](https://www.lua.org/manual/5.1/manual.html), Â§Â§2.2, 2.7, 2.10 and `pcall`.

## Applying and checking the standard

The expanded 28 October 2026 execution baseline also requires these focused
controls. They do not claim aircraft or standards certification.

- Preserve native resolve/conversion status independently of data; successful
  numeric zero is valid. Missing exports, stale contexts and failed conversions
  withdraw the affected authority. Retain already bool-checked readers.
- Declare source schema, units/frame, observation clock, sample time, generation,
  validity, bounds and reset/teardown for each coherent group. Receipt or copy
  cannot renew source age or consent; sanitized defaults are not measurements.
- Read the commit marker before the protected payload and validate marker/epoch
  after every used field. Retire pending requests, filters and delayed reports
  together across source-clock/generation changes.
- Delete/remake tests in accountable batches from independent requirements and
  actual host contracts. Historical diagnostic assertions are not acceptance.
  Keep original research measurements and user recordings as evidence.
- Keep explicit build outputs separate from installation. Capture source/dirty
  state, tools, dependencies, DLL/assets/default controls and installed hooks.
  Loaded identity requires actual host evidence.
- Trace dynamic loaders, exports, saved controls and callbacks before cleanup.
  Migrate the callers, then remove obsolete owners without a default wrapper.
- Preserve identity-known, source observation time and clock/epoch independently
  through transport, fusion and pilot qualifiers. Modeled schedules do not prove
  observed DCS concurrency, memory ordering or native lifetime.

NASA [SWE-061](https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695445/SWE-061%2B-%2BCoding%2BStandards) calls for defined and followed coding standards; [SWE-135](https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695494/SWE-135%2B-%2BStatic%2BAnalysis) calls for analysis during development and testing. For this project:

- Use readable, normally spaced formatting. Explain units, assumptions and unusual failure handling; avoid dense one-line control code.
- Enable strong warnings for project-owned code. Establish a recorded legacy-warning baseline; introduce no new unexplained warnings. Keep suppressions narrow and justified.
- Use C++ static analysis with the actual compilation configuration and Lua linting with an explicit DCS-global allowlist. Pin tool versions/configuration. Record unavailable checks rather than reporting them passed.
- Review function complexity, recurring allocation and worst-case work in changed update paths. Exercise invalid data, exhausted capacity, stale generations and teardown alongside normal operation.
- Test behavior and failure boundaries with the actual owning module. Measure branch/decision coverage for consequential control, release and native-lifetime logic; explain uncovered paths. Do not add assertions or tests merely to meet a count.
- An exception records the rule, file/function, reason, bounded alternative and verification. Native callbacks/virtual methods and Lua-managed memory are tailored cases, not blanket permission to ignore the rules.

All implementation chats follow this standard. A code change reports the checks actually performed and remaining exceptions. Host/runtime fidelity remains a separate question from coding quality.

Native text regression (DCS2.9.30,27October2026): crash archive dcs.log-20261028-005039.zip reaches CockpitBase text_using_parameter/set_strcat_by_predefined_format with numeric70.0 supplied to %s. The dump contains the argument bits4051800000000000, format%s and element name rad Alt in the PFD font. The engine-indication producer previously published numeric-only text. Engine/UFD/fuel/stores readouts now consume typed numeric fields, with static--- under independent invalid flags; the mixed-type engine text publications are removed. test_native_text_formats.py reproduces the original70/%s pair with host-style coercion and verifies36actual native declarations using the system CRT formatter, write-only element proxies, unchanged font/geometry and separate metric/supply failure. Fuel snapshots gain only the four unavailable labels per display. This reproduces the failing contract offline; a post-fix DCS startup is still a separate host check.

# Focused coding checks

Five replacement native suites compile with MSVC19.51 C++23 /W4 /WX /analyze.
The full actual aircraft DLL builds under /W4 /analyze. Existing C4100 callback
parameters, C4244 host-float conversions and C4456/C6246 legacy shadowing remain;
no new suppression was added. The unused C4189 candidates were removed. Baseline
and final logs are in the external chat1-20261028 build directory.

Lizard records123 functions across the seven physical production headers, none
above15. GroundContact::update and Configuration::update are12 due to finite
input guards and independent contact/configuration decisions; both are under25
statement lines with loops bounded to3. The remaining11–13 functions predate
this change and retain fixed signal/record bounds. Long legacy simulate/export
callbacks are retained as a narrow existing exception; no mass rewrite or
certification claim is made. Lua syntax uses actual Lua5.1 loadstring. Service
handles and native gear fields are cached in fixed sets; no new per-step queue,
file I/O, waits, unbounded history or recurring native allocation is introduced.

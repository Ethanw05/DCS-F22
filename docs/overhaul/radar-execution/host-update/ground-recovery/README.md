# Installed ground radar recovery

The user's new flight confirmed working A/A radar and unavailable ground radar.
All93 ground samples reported video reason2 with zero render/query activity.
The sensor's previous diagnostic priority masked its API failure as reason4.

Commit `d6780d5` adds coherent current sensor and renderer image bundles after
validating the terrain, RCS, Camera784, indicator and parameter-copy interfaces.
Video capture now brackets the whole ground-control transaction, retires old
images on source/context changes and rechecks ownership before submission.
Renderer callbacks retain their value snapshots and original frozen image time.
Warm parameter lookup uses transparent string views without temporary strings.

Actual primary checks pass:96 renderer-selector,516 video-API,230 sensor-API,
602 camera/control/lifecycle and29 coordinator assertions, plus both ground
owner executables. All use MSVC `/W4 /WX /analyze`. The23 Lua cases, Lua5.1
syntax and pinned lint pass. The installed29-module Lua chain also passes its
controlled host scenario, including the existing radar and IFF controllers.
These results do not establish live pixels or acquisition.

`INSTALLATION.json` records the normal mod installation: rebuilt DLL SHA
`71ef5ee0bbd542bfceacadfa624592dc642a9a5da08c214961fab2062c8b16f8`,
eight changed Lua files and twelve verified dependencies.85 protected binding,
HUD/font, audio and hook files are unchanged. No backup, DCS launch, termination
or simulator input was performed. Actual MAP/GMT/DBS/AGR rendering, registration
and reload/VR behavior require the next in-game check.

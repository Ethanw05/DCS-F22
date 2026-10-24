-- SPDX-License-Identifier: GPL-3.0-or-later
assert(_VERSION=="Lua 5.1","Use Lua 5.1 to match the cockpit runtime")
for _,path in ipairs(arg) do local chunk,err=loadfile(path);assert(chunk,path..": "..tostring(err)) end
print("PASS Lua 5.1 syntax: "..#arg.." files")

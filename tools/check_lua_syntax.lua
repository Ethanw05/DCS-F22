-- Run with the installed DCS Lua interpreter; compile without executing devices.
local checked = 0
for index = 1, #arg do
    local chunk, reason = loadfile(arg[index])
    if not chunk then error(arg[index] .. ': ' .. tostring(reason)) end
    checked = checked + 1
end
assert(checked > 0, 'no Lua source supplied')
print('DCS Lua syntax: ' .. checked .. ' files PASS')

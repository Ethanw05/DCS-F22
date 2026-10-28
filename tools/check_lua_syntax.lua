-- Independent Lua5.1 compile-only CLI. Never run an aircraft or hook chunk.
local paths=arg
if type(paths)~='table' or #paths<1 or #paths>4096 then
    error('Supply 1..4096 explicit Lua source paths',0)
end
local failures,checked,diagnostics=0,0,{}
for index=1,#paths do
    local path=paths[index]
    local chunk,reason
    if type(path)=='string' and path~='' then
        chunk,reason=loadfile(path)
    else
        reason='invalid source path'
    end
    checked=checked+1
    if not chunk then
        failures=failures+1
        if #diagnostics<32 then diagnostics[#diagnostics+1]=tostring(path)..': '..tostring(reason)end
    end
end
if failures>0 then
    error(string.format('%d/%d Lua sources failed compilation\n%s',failures,checked,table.concat(diagnostics,'\n')),0)
end
print(string.format('Lua syntax checked: %d sources',checked))

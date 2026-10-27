-- A voice priority is a bounded playback lease, never a permanent mute.
local M = { maximum_lease = 4 }
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<1e9 end
function M.playing(sound)
    local ok,value=pcall(function()return sound:is_playing()end)
    -- Lua treats numeric zero as true. Normalize both native return forms.
    return ok and (value==true or value==1) or false
end
function M.priority(get, now)
    local priority, deadline = get('F22_PILOT_AUDIO_PRIORITY'), get('F22_PILOT_AUDIO_UNTIL')
    if not finite(now) or not finite(deadline) or deadline <= now
        or deadline-now > M.maximum_lease then return 0 end
    return (priority == 1 or priority == 3) and priority or 0
end
return M

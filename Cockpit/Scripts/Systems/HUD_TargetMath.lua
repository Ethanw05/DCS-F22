-- GPL-3.0-or-later. Nominal-eye HUD projection, using the actual glass outline.
-- A directional cue is presentation only; it never asserts a weapon lock.
local M={}
function M.new(glass)
    local polygon={}
    local eye={.247411,-.067882,0}
    -- glass.lua follows the perimeter through vertices 3..N; 1/2 triangulate it.
    for i=3,#glass.vertices do
        local v=glass.vertices[i];local distance=v[1]-eye[1]
        polygon[#polygon+1]={(v[3]-eye[3])/distance,(v[2]-eye[2])/distance}
    end
    local function inside(x,y)
        local result=false;local j=#polygon
        for i=1,#polygon do
            local a,b=polygon[i],polygon[j]
            if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then result=not result end
            j=i
        end
        return result
    end
    local function safe(x,y,margin)
        for _,dx in ipairs({-margin,margin}) do for _,dy in ipairs({-margin,margin}) do
            if not inside(x+dx,y+dy) then return false end
        end end
        return true
    end
    return function(az,el)
        local forward=math.cos(el)*math.cos(az)
        local right,up=math.cos(el)*math.sin(az),math.sin(el)
        local x,y=0,0
        if forward>1e-6 then x,y=right/forward,up/forward end
        local visible=forward>1e-6 and safe(x,y,.014)
        local magnitude=math.sqrt(right*right+up*up)
        if magnitude<1e-9 then right,up,magnitude=(az<0 and -1 or 1),0,1 end
        local dx,dy=right/magnitude,up/magnitude
        local low,high=0,2
        for i=1,24 do
            local mid=(low+high)/2
            if safe(dx*mid,dy*mid,.022) then low=mid else high=mid end
        end
        -- Reserve the heading readout/tape at the top of the combiner.
        if dy>0 then low=math.min(low,.045/dy) end
        return {x=x,y=y,visible=visible,arrow_x=dx*low,arrow_y=dy*low,
            rotation=-math.atan2(dx,dy),angle=math.deg(math.acos(math.max(-1,math.min(1,forward))))}
    end
end
return M

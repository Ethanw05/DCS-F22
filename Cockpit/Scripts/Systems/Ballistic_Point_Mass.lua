-- Gravity-only impact estimate, for training visualization ONLY.
-- Public NASA x=vt, y=v0*t - 1/2*g*t^2. No drag, wind, fuze, INS, JDAM,
-- release delay or production F-22 ordnance data is represented here.
local M={}
local g=9.80665
local function valid(x) return type(x)=="number" and x==x and math.abs(x)<1e8 end
function M.impact(north,east,alt,vn,ve,vu,heightAt)
    if type(heightAt)~="function" or not valid(north) or not valid(east)
       or not valid(alt) or not valid(vn) or not valid(ve) or not valid(vu) then return nil end
    if math.sqrt(vn*vn+ve*ve)>1200 or math.abs(vu)>500 then return nil end
    local function point(t)
        local n=north+vn*t
        local e=east+ve*t
        local h=alt+vu*t-0.5*g*t*t
        return n,e,h
    end
    local function ground(t)
        local n,e,h=point(t)
        local ok,terrain=pcall(heightAt,n,e)
        if not ok or not valid(terrain) then return nil end
        return h-terrain,terrain
    end
    local above=ground(0)
    if not above or above<=0.5 then return nil end
    local previous=0
    for t=0.25,50.0,0.25 do
        local delta=ground(t)
        if delta==nil then return nil end
        if delta<=0 then
            local low,high=previous,t
            for _=1,12 do
                local middle=(low+high)/2
                local d=ground(middle)
                if d==nil then return nil end
                if d>0 then low=middle else high=middle end
            end
            local time=(low+high)/2
            local n,e,h=point(time)
            local _,terrain=ground(time)
            return {north=n,east=east+ve*time,alt=terrain,fall_time=time,
                    slant=math.sqrt((vn*time)^2+(ve*time)^2+(terrain-alt)^2)}
        end
        previous=t
    end
    return nil
end
return M

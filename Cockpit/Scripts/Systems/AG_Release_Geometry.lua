-- Gravity-only simulated release timing: not production CCRP.
-- No weapon drag, guidance, GPS handoff, fuze or actual release consent.
local M={}
local g=9.80665
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e8 end
function M.timeToRelease(n,e,h,vn,ve,vu,tn,te,th)
    for _,x in ipairs({n,e,h,vn,ve,vu,tn,te,th}) do
        if not finite(x) then return nil end
    end
    if h-th<=1 then return nil end
    local speed2=vn*vn+ve*ve
    if speed2<900 then return nil end
    local discriminant=vu*vu+2*g*(h-th)
    if discriminant<=0 then return nil end
    local fall=(vu+math.sqrt(discriminant))/g
    local rn=tn-n-vn*fall
    local re=te-e-ve*fall
    local wait=(rn*vn+re*ve)/speed2
    local cross=math.sqrt((rn-vn*wait)^2+(re-ve*wait)^2)
    if wait<0 or wait>90 or cross>1000 then return nil end
    return {seconds=wait,fall=fall,cross_track=cross}
end
return M

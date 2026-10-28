-- GPL-3.0-or-later. DCS type text and geometry-correlated RF presentation only.
local Labels=dofile(LockOn_Options.script_path..'Systems/RWR_Computer.lua')
local M={}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<1e9 end
function M.read(get,now)
    local result={}
    local sequence,stamp=get('F22_TACTICAL_SEQUENCE'),get('F22_TACTICAL_TIME')
    if not finite(sequence) or sequence<=0 or not finite(stamp) or now<stamp or now-stamp>.25 then return result end
    for index=1,64 do
        local p=string.format('F22_TACTICAL_%02d_',index)
        local source=get(p..'RADAR_SOURCE')
        if get(p..'VALID')==1 and finite(source) and source>0 then
            local signal,age=get(p..'RF_SIGNAL'),get(p..'RF_AGE')
            result[source]={label=get(p..'LABEL_CODE'),signal=age<=(signal>1 and 3.5 or 6) and signal or 0}
        end
    end
    if sequence~=get('F22_TACTICAL_SEQUENCE') then return {} end
    return result
end
function M.label(track,correlated)
    local label=Labels.label(track and track.type_name,1)
    if label=='U' and correlated then return correlated.label end
    return Labels.label_code(label)
end
return M

-- GPL-3.0-or-later. User-confirmed display palette; not an IFF classifier.
-- Cyan is reserved for explicit flight membership; no native producer yet
-- establishes that membership. A missing friendly reply stays unknown.
local M={unknown=-1,hostile=0,friendly=1,flight=3,
 styles={{-1,'yellow','UNKNOWN'},{0,'red','HOSTILE'},{1,'green','FRIENDLY'},{3,'cyan','FLIGHT'}}}
function M.normalize(code)
 if code==M.hostile or code==M.friendly or code==M.flight then return code end
 return M.unknown
end
function M.color(code)
 code=M.normalize(code)
 for _,style in ipairs(M.styles)do if style[1]==code then return style[2]end end
end
return M

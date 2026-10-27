-- GPL-3.0-or-later. NAV steering -> DATA -> selected-point/radio UFC entry.
-- Hornet workflow reference: installed HSI_MAIN / HSI_DATA_WYPT / TCN Lua.
-- F-22 bezel placement is an explicit adaptation, not recovered aircraft code.
local Controls=dofile(LockOn_Options.script_path..'Systems/Nav_Display_Controls.lua')
local M={}
local names={'LMFD_HSI_PAGE','RMFD_HSI_PAGE','CMFD_HSI_PAGE','PMFD_HSI_PAGE'}
function M.new(param,send,page)
 local s={views={0,0,0,0}}
 function s:set(panel,view)
  self.views[panel]=view
  param(names[panel]..'_DATA'):set(view)
 end
 function s:update(visible,power)
  for panel=1,#names do if not power or not visible[panel]then self:set(panel,0)end end
 end
 function s:handle(panel,button)
  local action=Controls.for_page(self.views[panel])[button]
  if not action or action.condition and param(action.condition):get()<.5 then return end
  if action.view~=nil then self:set(panel,action.view)
  elseif action.page~=nil then self:set(panel,0);page(panel,action.page)
  else send(action.device,action.command,1)end
 end
 for panel=1,#names do s:set(panel,0)end
 return s
end
return M

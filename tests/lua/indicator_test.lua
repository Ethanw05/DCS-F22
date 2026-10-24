-- SPDX-License-Identifier: GPL-3.0-or-later
-- Constructs real page Lua with a narrow host stub; not a renderer or screenshot test.
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local total,pages=0,0
for _,folder in ipairs({"HUD","ICP","UFD_LEFT","UFD_RIGHT","MFD_LEFT","MFD_RIGHT","MFD_CENTER","PMFD_CENTER"}) do
 local init=Host.New(root);init:load("Cockpit/Scripts/"..folder.."/init.lua")
 local names={}
 for _,path in pairs(init.env.page_subsets) do
  local h=Host.New(root);h.env.dofile(path);pages=pages+1
  for _,e in ipairs(h.elements) do
   total=total+1
   assert(e.name,path..": missing name")
   assert(not names[e.name],path..": duplicate element name: "..e.name);names[e.name]=true
   if e.class~="ceSimple" then assert(e.material,path..": missing material: "..e.name) end
   for _,c in ipairs(e.controllers or {}) do
    if c[1]:find("parameter",1,true) and type(c[2])=="number" then
     assert(e.element_params and c[2]>=0 and c[2]<#e.element_params,path..": invalid parameter index: "..e.name)
    end
   end
  end
  for _,e in ipairs(h.elements) do if e.parent_element then assert(names[e.parent_element],path..": missing parent: "..e.parent_element) end end
 end
end
print("PASS "..pages.." indicator pages, "..total.." constructed elements; DCS rendering not emulated")

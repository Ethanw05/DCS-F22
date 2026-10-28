-- GPL-3.0-or-later. Shared routing, independent display selections/subpages.
local R=dofile(LockOn_Options.script_path..'Systems/Display_Routing.lua')
local C=dofile(LockOn_Options.script_path..'Systems/MFD_Controls.lua')
local layout=dofile(LockOn_Options.script_path..'MFD_COMMON/display_layout.lua')
local M={}
function M.new(param,send,ground_override)
 local s={panels={},held={},forwarded={},powered=false}
 local function get(k)return param(k):get()end
 local function put(k,v)param(k):set(v)end
 local function control(panel,b)return C.for_page(s.panels[panel].page,s.panels[panel].view,get)[b]end
 for i,name in ipairs(R.panels)do
  local p=({R.pages.nav,R.pages.def,R.pages.stores,R.pages.tsd})[i]
  s.panels[i]={page=p,last=p,view=0}
  put('F22_SMS_UI_PAGE_'..name,0)
  for b=1,20 do
   put('F22_MFD_'..name..'_KEY_'..b,'');put('F22_MFD_'..name..'_SEL_'..b,0)
   put('F22_MFD_'..name..'_SPAN_'..b,layout.label_span(''))
  end
  for page in pairs(R.suffix)do put(R.flag(name,page),0)end
 end
 put('F22_MFD_LABEL_ONE',1);put('F22_MFD_LAYOUT_READY',1);put('F22_DEF_DISPLAY_RANGE_NM',40)
 put('F22_SMS_AA_CONTEXT',0);put('F22_SMS_PROGRAM_PAGE',0)
 function s:release_panel(panel)
  for button=1,20 do
   local key=panel..':'..button
   local owner=self.forwarded[key]
   if owner then send(owner.device,owner.command,0);self.forwarded[key]=nil end
  end
 end
 function s:select(panel,page)
  local p=self.panels[panel];if not R.suffix[page]then return end
  if p.page~=page or p.view~=0 then self:release_panel(panel)end
  if page==R.pages.menu and p.page~=R.pages.menu then p.last=p.page end
  p.page=page;p.view=0;self:publish()
  if log and log.write then log.write('F22_MFD_ROUTE',log.INFO,'panel='..R.panels[panel]..' format='..R.names[page])end
 end
 function s:cycle(panel)
  local current=self.panels[panel].page
  for i,page in ipairs(R.order)do if page==current then self:select(panel,R.order[i%#R.order+1]);return end end
  self:select(panel,R.order[1])
 end
 function s:button(panel,b,down)
  local key=panel..':'..b
  if not down then
   self.held[key]=nil
   local owner=self.forwarded[key];self.forwarded[key]=nil
   if owner then send(owner.device,owner.command,0)end
   return
  end
  if self.held[key]or not self.powered then return end
  self.held[key]=true
  local p=self.panels[panel];local a=control(panel,b)
  if not a or a.condition and get(a.condition)<.5 then return end
  send('COMBAT_SYSTEM',10742,({3,4,5,2})[panel])
  if log and log.write then
   log.write('F22_MFD_INPUT',log.INFO,'panel='..R.panels[panel]..' format='..R.names[p.page]..' view='..p.view..' button='..b..' label='..tostring(a.label or a.parameter or '')..' command='..tostring(a.command or a.action or a.page or a.view or ''))
  end
  if a.action=='menu'or a.page==0 then self:select(panel,R.pages.menu)
  elseif a.action=='return'then self:select(panel,p.last)
  elseif a.action=='page'then self:select(panel,a.value)
  elseif a.action=='view'or a.view~=nil then self:release_panel(panel);p.view=a.view or a.value;self:publish()
  elseif a.action=='ground_override'then ground_override()
  elseif a.action=='def_range'then
   local ranges={5,10,20,40,80,160};local v=get('F22_DEF_DISPLAY_RANGE_NM');local index=4
   for i,n in ipairs(ranges)do if n==v then index=i end end
   put('F22_DEF_DISPLAY_RANGE_NM',ranges[math.max(1,math.min(#ranges,index+a.value))])
  elseif a.device then
   self.forwarded[key]=a;send(a.device,a.command,a.value or 1)
   if a.home then p.view=0 end
  end
  self:publish()
 end
 function s:publish()
  local any_stores=false;local ground_data=false
  for i,name in ipairs(R.panels)do
   local p=self.panels[i]
   put('F22_'..name..'_FORMAT',p.page);put('F22_'..name..'_VIEW',p.view)
   put(name=='PMFD'and'F22_PMFD_PAGE'or name..'_PAGE',name=='PMFD'and p.page or R.legacy[p.page])
   put(name..'_HSI_PAGE_DATA',p.page==R.pages.nav and p.view or 0)
   put('F22_SMS_UI_PAGE_'..name,p.page==R.pages.stores and p.view or 0)
   put('F22_DEF_DETAIL_'..name,p.page==R.pages.def and p.view or 0)
   put(name..'_MASK',self.powered and p.page==R.pages.tsd and 1 or 0)
   for page in pairs(R.suffix)do put(R.flag(name,page),self.powered and p.page==page and 1 or 0)end
   if self.powered and p.page==R.pages.stores then any_stores=true end
   if self.powered and p.page==R.pages.tsd and get('HUD_MODE')==7 and p.view==2 then ground_data=true end
   local controls=C.for_page(p.page,p.view,get)
   for b=1,20 do
    local a=controls[b];local label=a and(a.label or(a.parameter and get(a.parameter)))or''
    if a and a.condition and get(a.condition)<.5 then label=''end
    label=type(label)=='string'and label or''
    put('F22_MFD_'..name..'_KEY_'..b,label)
    put('F22_MFD_'..name..'_SPAN_'..b,layout.label_span(label))
    local selected=a and a.selected or false
    if a and a.selected_parameter then
     local value=get(a.selected_parameter)
     selected=a.selected_value~=nil and value==a.selected_value or a.selected_value==nil and value>.5
    end
    put('F22_MFD_'..name..'_SEL_'..b,selected and 1 or 0)
   end
  end
  local aa=get('HUD_MODE')>=2 and get('HUD_MODE')<=6
  put('F22_SMS_PROGRAM_PAGE',any_stores and not aa and 1 or 0);put('F22_SMS_AA_CONTEXT',aa and 1 or 0)
  if get('F22_AG_GAIN_INDEX')>=1 then
   local actual=get('F22_AG_DATA')>.5
   if self.ag_data_request~=nil and actual==self.ag_data_request then self.ag_data_request=nil end
   if actual~=ground_data and self.ag_data_request==nil then
    self.ag_data_request=ground_data;send('RADAR_COMPUTER',10640,1)
   end
  end
  for _,k in ipairs({'LMFD_SMS_PAGE','PMFD_MAP_PAGE','PMFD_SYS_PAGE','PMFD_CONFIG_PAGE','PMFD_SFM_PAGE'})do put(k,0)end
 end
 function s:update(powered)
  if self.powered and not powered then
   for key,owner in pairs(self.forwarded)do send(owner.device,owner.command,0);self.forwarded[key]=nil end
   self.held={}
  end
  local focus=get('F22_SOI')
  if self.focus~=nil and focus~=self.focus then
   for panel=1,4 do self:release_panel(panel)end
  end
  self.focus=focus
  local role=get('HUD_MODE')==7 and'AG'or'AA'
  if self.role~=role then
   for panel=1,4 do self:release_panel(panel)end
   for _,p in ipairs(self.panels)do
    if p.page==R.pages.tsd then p.view=0
    elseif p.page==R.pages.stores and role=='AA'and p.view~=2 and p.view~=5 then p.view=0 end
   end
   self.role=role
  end
  self.powered=powered;self:publish()
 end
 return s
end
return M

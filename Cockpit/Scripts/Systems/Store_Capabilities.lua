-- GPL-3.0-or-later. Explicit payload capabilities; labels are a public display contract.
local M={}
local equipment=dofile(LockOn_Options.script_path..'Systems/Equipment_Profile.lua')
M.labels={'MK-83 TRAINING','GBU-32 JDAM','GBU-32 LEGACY','BOMB','AIM-9M','AIM-9X','AIM-120','AIM-120D','AIM-260','MAKO A/A','MAKO A/G','FUEL','IRST','OTHER','CATM-9M'}
M.short_labels={'MK83','GB32','GB32','BOMB','9M','9X','120','120D','260','MAKO','MAKO','TANK','IRST','OTHER','CATM'}
local definitions={}
local function add(ids,label,kind,delivery,supported,guided)
 for _,id in ipairs(ids)do definitions[id]={label=label,name=M.labels[label],kind=kind,delivery=delivery,supported=supported,guided=guided or false,bomb=delivery=='bomb'}end
end
add({'{F22-MK83-TRAINING}'},1,7,'bomb',true)
add({'{GBU_32_V_2B}'},2,7,'bomb',true,true)
add({'{GBU32_JDAM}'},3,7,'bomb',true,true)
add({'{6CEB49FC-DED8-4DED-B053-E1F033FF72D3}'},5,3,'ir',true)
add({'{5CE2FF2A-645A-4197-B48D-8720AC69394F}','{AIM9X-BLKII}','{LAU_115_2xAIM9X-II}','{LAU_115_2xAIM9X-II}}'},6,3,'ir',true)
add({'{40EF17B7-F508-45de-8566-6FFECC0C1AB8}','{C8E06185-7CD6-4C90-959F-044679E90751}','{AIM-120C-7}','{AIM-120C-8}','{LAU_115_2xAIM-120C-7}','{LAU_115_2xAIM-120C-8}'},7,2,'radar',true)
add({'{AIM-120D-3}','{LAU_115_2xAIM-120D-3}'},8,2,'radar',true)
add({'{AIM-260A}','{LAU_115_2xAIM-260A}'},9,2,'radar',true)
add({'{MAKO_A2A_C}'},10,2,'radar',true)
-- The offered A/G MAKO has no verified coordinate/missile launch adapter.
add({'{MAKO_A2G_C}'},11,7,'unsupported',false,true)
add({'{LDTP_FUEL_Tank}','{E1F29B21-F291-4589-9FD8-3272EEC69506}'},12,nil,'fuel',false)
add({'{F22_IRST}'},13,nil,'sensor',false)
add({'CATM-9M','{CATM-9M}'},15,nil,'training',false)
for _,id in ipairs({'{AIM-260A}','{LAU_115_2xAIM-260A}','{MAKO_A2A_C}','{MAKO_A2G_C}'})do
 definitions[id].optional_equipment='additional_weapons'
 definitions[id].evidence='experimental community equipment; production F-22 fit unestablished'
end
-- Keep existing stores-page label IDs stable. Weapon identity is independent
-- of carriage/rack identity, so single and paired racks share a HUD count.
local function identity(ids,name,hud)
 for _,id in ipairs(ids)do local d=definitions[id];d.identity=name;d.hud=hud or name end
end
identity({'{C8E06185-7CD6-4C90-959F-044679E90751}'},'AIM-120B')
identity({'{40EF17B7-F508-45de-8566-6FFECC0C1AB8}'},'AIM-120C')
identity({'{AIM-120C-7}','{LAU_115_2xAIM-120C-7}'},'AIM-120C7')
identity({'{AIM-120C-8}','{LAU_115_2xAIM-120C-8}'},'AIM-120C8')
identity({'{AIM-120D-3}','{LAU_115_2xAIM-120D-3}'},'AIM-120D3')
identity({'{AIM-260A}','{LAU_115_2xAIM-260A}'},'AIM-260A')
identity({'{MAKO_A2A_C}'},'MAKO A/A')
identity({'{AIM9X-BLKII}','{LAU_115_2xAIM9X-II}','{LAU_115_2xAIM9X-II}}'},'AIM-9X II')
function M.key(info)
 if type(info)~='table'then return ''end
 local w=type(info.weapon)=='table'and info.weapon or {}
 local id=info and (info.CLSID or info.clsid)
 return type(id)=='string'and id~=''and id or table.concat({w.level1 or 0,w.level2 or 0,w.level3 or 0,w.level4 or 0},':')
end
function M.describe(info)
 if type(info)~='table'or type(info.count)~='number'or info.count~=info.count
  or info.count<=0 or info.count>128 or info.count%1~=0 then return nil end
 local key=M.key(info);local original=definitions[key];local w=info.weapon or {}
 local cap={key=key,count=info.count,type4=w.level4 or 0}
 if original then for k,v in pairs(original)do cap[k]=v end
 elseif w.level1==4 and w.level2==5 and (w.level3==9 or w.level3==36)then
  cap.label=4;cap.name=info.displayName or info.name or 'BOMB';cap.kind=7;cap.delivery='bomb';cap.supported=true;cap.guided=w.level3==36;cap.bomb=true
 elseif w.level1==4 and w.level2==4 and w.level3==7 and (w.level4==24 or w.level4==106)then
  cap.label=7;cap.name=w.level4==24 and 'AIM-120B' or 'AIM-120C';cap.kind=2;cap.delivery='radar';cap.supported=true
 elseif w.level1==4 and w.level2==4 and w.level3==7 and (w.level4==22 or w.level4==136)then
  cap.label=w.level4==136 and 6 or 5;cap.name=w.level4==136 and 'AIM-9X' or 'AIM-9M';cap.kind=3;cap.delivery='ir';cap.supported=true
 else cap.label=14;cap.name=info.displayName or info.name or 'OTHER';cap.supported=false end
 if cap.optional_equipment and not equipment.supports(cap.optional_equipment)then
  cap.supported=false
 end
 cap.identity=cap.identity or cap.name;cap.hud=cap.hud or cap.identity
 return cap
end
function M.selected(infos,station,mode,gun)
 if mode==5 or mode==7 and gun then return {name='GUN',hud='GUN',count=0,kind=5,supported=true,category_count=0}end
 local cap=M.describe(infos[station]);local count,category=0,0
 for i=0,10 do local other=M.describe(infos[i])
  if other and other.kind==mode then
   category=category+other.count
   if cap and other.identity==cap.identity then count=count+other.count end
  end
 end
 if not cap then return {name=mode==2 and 'NO MRM' or mode==3 and 'NO SRM' or mode==7 and 'NO A/G WPN' or '',hud='',count=0,kind=0,supported=false,category_count=category}end
 cap.count=count;cap.category_count=category;return cap
end
function M.mode_available(cap,mode)
 return cap and cap.supported and cap.bomb and (mode==3 or mode==2) or false
end
return M

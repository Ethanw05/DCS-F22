-- GPL-3.0-or-later. Altimetry settings and transactional ICP data entry.
local M = {}
local function finite(v)
    return type(v)=='number' and v==v and math.abs(v)<1e9
end
function M.new()
    return setmetatable({qnh=760, saved_qnh=760, standard=false, units=0,
        baro_floor=0, radar_floor=0, field=1, buffer='', status=''}, {__index=M})
end
function M:pressure()
    return self.standard and 760 or self.qnh
end
function M:toggle_standard()
    if not self.standard then self.saved_qnh=self.qnh
    else self.qnh=self.saved_qnh end
    self.standard=not self.standard;self.buffer='';self.status=''
end
function M:commit()
    if self.buffer=='' then return true end
    local v=tonumber(self.buffer)
    if not finite(v) or v%1~=0 then self.status='ENTER DIGITS';return false end
    if self.field==1 then
        local mm=self.units==0 and v*.254 or v*.750061683
        if (self.units==0 and #self.buffer~=4) or mm<650 or mm>820 then
            self.status=self.units==0 and 'BARO: 2560-3228' or 'BARO: 867-1093 HPA';return false
        end
        self.qnh=mm;self.saved_qnh=mm;self.standard=false
    elseif self.field==2 then
        if v>25000 then self.status='MSL FLOOR: 0-25000';return false end
        self.baro_floor=v
    elseif self.field==3 then
        if v>5000 then self.status='AGL FLOOR: 0-5000';return false end
        self.radar_floor=v
    else return false end
    self.buffer='';self.status='ENTERED';return true
end
function M:select(field)
    if self:commit() then self.field=field;self.status='';return true end
    return false
end
function M:digit(v)
    if finite(v) and v%1==0 and v>=0 and v<=9 and #self.buffer<5 then
        self.buffer=self.buffer..v;self.status=''
    end
end
function M:adjust(direction)
    if direction~=1 and direction~=-1 then return end
    self.buffer='';self.status=''
    if self.field==1 then
        local step=self.units==0 and .254 or .750061683
        self.qnh=math.max(650,math.min(820,self:pressure()+step*direction))
        self.saved_qnh=self.qnh;self.standard=false
    elseif self.field==2 then self.baro_floor=math.max(0,math.min(25000,self.baro_floor+100*direction))
    elseif self.field==3 then self.radar_floor=math.max(0,math.min(5000,self.radar_floor+100*direction)) end
end
function M:pressure_text()
    local p=self:pressure()
    return self.units==0 and string.format('BARO %.2f INHG',p/25.4)
        or string.format('BARO %.0f HPA',p/.750061683)
end
return M

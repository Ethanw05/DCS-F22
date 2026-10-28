-- GPL-3.0-or-later. Completed own-radar reports, World seconds and source epoch.
local M = {}
local names = {"SOURCE", "AGE", "AZ", "EL", "RANGE", "MEASURED_RANGE", "QUALITY",
    "POSITION_VALID", "N", "U", "E", "VN", "VU", "VE", "MEASUREMENT_SOURCE",
    "VELOCITY_VALID", "ASSOCIATION_VALID", "POSITION_SIGMA_M", "VELOCITY_SIGMA_MPS",
    "SELECTED", "IDENTITY_KNOWN", "IDENTITY_TIME", "FRIENDLY", "HOSTILE"}
local flags = {"POSITION_VALID", "VELOCITY_VALID", "ASSOCIATION_VALID", "SELECTED",
    "IDENTITY_KNOWN", "FRIENDLY", "HOSTILE"}
local function finite(x)
    return type(x)=="number" and x==x and math.abs(x)<1e12
end
local function integer(x,lo,hi)
    return finite(x) and x>=lo and x<=hi and x%1==0
end
local function flags_valid(r)
    for i=1,#flags do local v=r[flags[i]];if v~=0 and v~=1 then return false end end
    return true
end
local function position_valid(r)
    return math.abs(r.N)<=3e7 and math.abs(r.E)<=3e7 and math.abs(r.U)<=1e5
end
local function report_valid(r,stamp)
    return integer(r.SOURCE,1,4294967295) and integer(r.MEASUREMENT_SOURCE,0,2)
        and r.AGE>=0 and r.AGE<=20 and stamp>=r.AGE
end
local function record_valid(r,stamp)
    if not report_valid(r,stamp)
        or math.abs(r.AZ)>2*math.pi+.001 or math.abs(r.EL)>math.pi/2+.001 then return false end
    if not flags_valid(r) then return false end
    if r.POSITION_VALID==1 and not position_valid(r) then return false end
    if r.VELOCITY_VALID==1 and (r.ASSOCIATION_VALID~=1 or r.VN*r.VN+r.VU*r.VU+r.VE*r.VE>1500^2) then return false end
    return r.IDENTITY_KNOWN~=1 or r.IDENTITY_TIME>=0 and r.IDENTITY_TIME<=stamp
end
function M.new(get)
    local s={get=get,slots={},accepted_slots={},contacts={},working_contacts={},epoch=0,batch={contacts={}}}
    for i=1,64 do
        local slot={prefix=string.format("F22_RADAR_TACTICAL_%02d_",i),values={},keys={}}
        s.accepted_slots[i]={}
        for j=1,#names do
            slot.keys[j]=slot.prefix..names[j]
            slot.values[names[j]],s.accepted_slots[i][names[j]]=0,0
        end
        s.slots[i]=slot
    end
    return setmetatable(s,{__index=M})
end
local function header(get,now)
    local before=get("F22_RADAR_TACTICAL_SEQUENCE")
    if not integer(before,2,16777214) or before%2~=0 or get("F22_RADAR_TACTICAL_SCHEMA")~=1 then return end
    local epoch,stamp=get("F22_RADAR_TACTICAL_SOURCE_EPOCH"),get("F22_RADAR_TACTICAL_TIME")
    if not integer(epoch,1,16777215) or not finite(stamp) or not finite(now)
        or stamp<0 or now-stamp<-.05 or now-stamp>.25 then return end
    return before,epoch,stamp
end
function M:slot(index,stamp)
    local get,slot=self.get,self.slots[index]
    local valid=get(slot.prefix.."VALID")
    if valid==0 then return false end
    if valid~=1 then return end
    local r=slot.values
    for j=1,#names do
        local value=get(slot.keys[j]);if not finite(value) then return end
        r[names[j]]=value
    end
    if not record_valid(r,stamp) then return end
    r.TYPE_NAME=get(slot.prefix.."TYPE_NAME")
    return r
end
function M:read(now)
    local get=self.get
    local before,epoch,stamp=header(get,now)
    if not before then return end
    local count=0
    for i=1,64 do
        local r=self:slot(i,stamp)
        if r==nil then return end
        if r then count=count+1;self.working_contacts[count]=r end
    end
    if before~=get("F22_RADAR_TACTICAL_SEQUENCE") or epoch~=get("F22_RADAR_TACTICAL_SOURCE_EPOCH") then return end
    for i=count+1,#self.working_contacts do self.working_contacts[i]=nil end
    self.contacts,self.working_contacts=self.working_contacts,self.contacts
    for i=1,64 do self.slots[i].values,self.accepted_slots[i]=self.accepted_slots[i],self.slots[i].values end
    self.epoch=epoch
    self.batch.sequence,self.batch.time,self.batch.epoch,self.batch.contacts=before,stamp,epoch,self.contacts
    return self.batch
end
return M

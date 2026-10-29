-- GPL-3.0-or-later. Coherent World-clock, body-radian, bearing-only packets.
local M = { capacity = 16, lifetime = 2.5 }
function M.finite(v)
    return type(v)=='number' and v==v and math.abs(v)<math.huge
end
local function integer(v,low,high)
    return M.finite(v) and v>=low and v<=high and v%1==0
end
local function fresh(now,stamp,maximum)
    return M.finite(now) and M.finite(stamp) and stamp>=0 and now-stamp>=-.01 and now-stamp<=maximum
end
local fields = {'VALID','ID','TIME','AZ','EL'}
function M.new(get,prefix)
    prefix=prefix or 'F22_IRST_NATIVE_'
    local s={get=get,prefix=prefix,contacts={},rows={},sequence=-1,epoch=0,time=0,ready=false}
    for _,suffix in ipairs({'SEQ','TIME','EPOCH','READY','REASON',
        'SCAN_AZ','SCAN_EL','OVERFLOW','AVAILABLE','SELECTED'})do
        get(prefix..suffix)
    end
    for i=1,M.capacity do
        local row={names={}}
        for j=1,#fields do row.names[j]=string.format('%s%02d_%s',prefix,i,fields[j]);get(row.names[j])end
        s.rows[i]=row
    end
    function s:read(now)
        self.ready=false
        for i=#self.contacts,1,-1 do self.contacts[i]=nil end
        local p,g=self.prefix,self.get
        local sequence=g(p..'SEQ') -- Commit marker MUST precede payload.
        if not integer(sequence,2,16000000) or sequence%2~=0 then return self end
        local stamp,epoch,ready=g(p..'TIME'),g(p..'EPOCH'),g(p..'READY')
        local reason,az,el=g(p..'REASON'),g(p..'SCAN_AZ'),g(p..'SCAN_EL')
        local overflow,available=g(p..'OVERFLOW'),g(p..'AVAILABLE')
        local selected=g(p..'SELECTED')
        if not fresh(now,stamp,.35) or not integer(epoch,1,4294967295)
            or ready~=1 or not M.finite(az) or not M.finite(el) then return self end
        for i=1,M.capacity do
            local row=self.rows[i]
            local valid=g(row.names[1])
            local id,time,baz,bel=g(row.names[2]),g(row.names[3]),g(row.names[4]),g(row.names[5])
            if valid==1 and integer(id,1,4294967295) and fresh(now,time,M.lifetime)
                and time<=stamp+.01 and M.finite(baz) and math.abs(baz)<=math.pi/2
                and M.finite(bel) and bel>=math.rad(-15) and bel<=math.rad(60) then
                row.id,row.time,row.az,row.el=id,time,baz,bel
                self.contacts[#self.contacts+1]=row
            end
        end
        if sequence~=g(p..'SEQ') or epoch~=g(p..'EPOCH') or stamp~=g(p..'TIME') then
            for i=#self.contacts,1,-1 do self.contacts[i]=nil end
            return self
        end
        self.ready,self.sequence,self.epoch,self.time=true,sequence,epoch,stamp
        self.reason,self.az,self.el,self.overflow,self.available=reason,az,el,overflow==1,available==1
        self.selected=selected
        return self
    end
    return s
end
return M

-- GPL-3.0-or-later. Range/format-independent snapshot for tactical consumers.
local M = { sequence = 0, metadata = {} }
local metadata = dofile(LockOn_Options.script_path.."Systems/Radar_Track_Metadata.lua")
local function source_epoch(generation)
	return type(generation)=="number" and generation==generation and generation>=1
		and generation<=16777215 and generation%1==0 and generation or 0
end
local function contains(tracks,source)
	for _,t in ipairs(tracks)do if t.native_id==source then return true end end
	return false
end
local function reports(computer,ready,stt)
	local tracks = {}
	if ready then
		for _, t in pairs(computer.tracks) do
			if t.native_id and computer:quality(t) > 0 then
				tracks[#tracks + 1] = t
			end
		end
		if stt and stt.native_id then
			if not contains(tracks,stt.native_id) then
				tracks[#tracks + 1] = stt
			end
		end
	end
	table.sort(tracks, function(a, b)
		local sa = a.id == computer.selected or a.stt
		local sb = b.id == computer.selected or b.stt
		if not not sa ~= not not sb then
			return not not sa
		end
		return a.native_id < b.native_id
	end)
	return tracks
end
local function begin_packet(put,epoch)
	M.sequence = M.sequence>=16777212 and 2 or M.sequence+2
	put("F22_RADAR_TACTICAL_SEQUENCE",M.sequence-1)
	put("F22_RADAR_TACTICAL_SCHEMA",1)
	put("F22_RADAR_TACTICAL_SOURCE_EPOCH",epoch)
	if M.source_epoch~=epoch then
		for i=1,64 do M.metadata[i]=nil end
		M.source_epoch=epoch
	end
end
local function publish_metadata(put,p,t,index)
	local cached=M.metadata[index]
	local source,time=t and t.native_id or 0,t and t.observed or 0
	if not cached or cached.source~=source or cached.time~=time then
		metadata.publish(put,p,t)
		M.metadata[index]={source=source,time=time}
	end
end
local function publish_motion(put,p,t)
	put(p.."ASSOCIATION_VALID",t and t.association_valid and 1 or 0)
	put(p.."VELOCITY_VALID",t and t.velocity_valid and t.association_valid and 1 or 0)
end
local function publish_polar(put,p,t,clock)
	put(p.."AGE",t and math.max(0,clock-(t.observed or clock)) or 999)
	put(p.."AZ",t and (t.current_az or t.az) or 0)
	put(p.."EL",t and (t.current_el or t.el) or 0)
	put(p.."RANGE",t and (t.current_range or t.range) or 0)
end
local world_fields={{"N","north"},{"U","altitude"},{"E","east"},{"VN","vn"},{"VU","vu"},{"VE","ve"}}
local function publish_world(put,p,t)
	local measured=t and (t.measurement_source==2 and t.measured_range or t.range)
	put(p.."MEASURED_RANGE",measured or 0)
	-- IFDL can share only the radar's own measured world observation.
	local world=t and type(t.north)=='number' and type(t.east)=='number' and type(t.altitude)=='number'
	put(p.."POSITION_VALID",world and 1 or 0)
	for i=1,#world_fields do
		local field=world_fields[i]
		put(p..field[1],world and t[field[2]] or 0)
	end
end
local function publish_identity(put,p,t,clock)
	local stamp=t and t.ident_time
	local known=type(stamp)=='number' and stamp==stamp and stamp>=0 and stamp<=clock
	put(p.."IDENTITY_KNOWN",known and 1 or 0)
	put(p.."IDENTITY_TIME",known and stamp or -100)
end
local function publish_selection(put,p,t,selected)
	put(p.."FRIENDLY",t and t.iff==1 and 1 or 0)
	put(p.."HOSTILE",t and t.iff==0 and 1 or 0)
	put(p.."SELECTED",t and (t.id==selected or t.stt) and 1 or 0)
end
local function publish_row(computer,put,t,index)
	local p=string.format("F22_RADAR_TACTICAL_%02d_",index)
	put(p.."VALID",t and 1 or 0)
	put(p.."SOURCE",t and t.native_id or 0)
	put(p.."MEASUREMENT_SOURCE",t and (t.measurement_source or 1) or 0)
	publish_metadata(put,p,t,index)
	publish_motion(put,p,t)
	publish_polar(put,p,t,computer.clock)
	publish_world(put,p,t)
	put(p.."QUALITY",t and (t.hits and computer:quality(t) or 2) or 0)
	publish_identity(put,p,t,computer.clock)
	publish_selection(put,p,t,computer.selected)
end
function M.publish(computer,put,ready,stt,generation)
	local epoch=source_epoch(generation)
	local tracks=reports(computer,ready and epoch>0,stt)
	begin_packet(put,epoch)
	for i=1,64 do publish_row(computer,put,tracks[i],i)end
	put("F22_RADAR_TACTICAL_TIME", computer.clock)
	put("F22_RADAR_TACTICAL_SEQUENCE", M.sequence)
end
return M

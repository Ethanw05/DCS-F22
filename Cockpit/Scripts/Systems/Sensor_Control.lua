-- GPL-3.0-or-later. SCS depress executes an existing focused-format function.
local M = {}
function M.page(context, focus)
	if context.common_formats then return context.common_formats[focus] or 0 end
	return ({
		[2] = context.primary_page or 1,
		[3] = context.left_page or 1,
		[4] = context.right_page or 3,
		[5] = context.center_page or 5,
	})[focus] or 0
end
function M.is_radar(context,focus)
	if context.common_formats then return M.page(context,focus)==1 end
	return focus==2 and M.page(context,focus)==1
end
function M.action(focus, page, mode, context)
	if focus == 1 then
		if mode == 7 then
			return "ag_mark"
		end
		if (mode == 2 or mode == 3 or mode == 5) and not context.locked then
			return "boresight"
		end
	elseif context.common_formats and focus>=2 then
		if page==1 then
			if mode==7 then return 'acquire' end
			if (mode==2 or mode==3 or mode==5)and not context.locked then return 'stt'end
		elseif page==7 then return 'nav_zoom'
		elseif page==13 then return 'ew_priority'end
	elseif focus == 2 and page == 1 then
		if mode == 7 then
			return "acquire"
		end
		if (mode == 2 or mode == 3 or mode == 5) and not context.locked then
			return "stt"
		end
	elseif focus == 2 and page == 7 then
		return "nav_zoom"
	elseif focus == 4 and page == 7 then
		return "ew_priority"
	elseif focus == 3 and page == 7 then
		if (mode == 2 or mode == 3 or mode == 5) and context.selected and not context.locked then return "stt" end
	elseif focus >= 3 and page == 8 then
		return "nav_zoom"
	end
	-- Passive system pages have no sensor command. Their bezel controls remain
	-- authoritative; never fall through to an unseen radar or weapon action.
end
return M

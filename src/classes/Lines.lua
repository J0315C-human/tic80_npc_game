
--------- Lines (speech) class ---
function Lines(parent)
	local s = {
		lines = {0,0,0,0,0,0,0,0},
		parent = parent
	}

	function s.getTime ()
		if s.parent then
			return s.parent.getTime()
		else
			return G.t
		end
	end

	function s.clearNpcLine(npc)
		for i = 1, #s.lines do
			if s.lines[i] ~= 0 and s.lines[i].npc == npc then
				s.lines[i] = 0
				return
			end
		end
	end

	function s.add(npc, str)
		s.clearNpcLine(npc)
		if str == '' or str == nil then
			return
		end

		for i = 1, #s.lines do
			if s.lines[i] == 0 then
				s.lines[i] = {npc=npc,str=str,start=s.getTime()}
				return
			end
		end
		error("too many lines!")
	end

	function s.isLineActive(line)
		if line == 0 then
			return false
		end
		local elapsed = s.getTime() - line.start
		local speakTime = C.T_LINE_MIN + C.T_PER_LETTER * string.len(line.str)
		return elapsed < speakTime
	end

	function s.drawLine(idx)
		if s.lines[idx] == 0 then return end

		local str = s.lines[idx].str
		local loc = s.lines[idx].npc.getCoords()
		local clr = s.lines[idx].npc.speechClr

		local w = string.len(str) * C.CHAR_WIDTH

		local x = getCenteredTextX(str) / 2 + loc.x / 2

		local y = C.TEXT_TOP + idx * 8
		local centerTxt = x + w / 2
		local centerSpr = loc.x + 8
		print(str, x, y, clr)
		local dx = centerTxt - centerSpr
		local yFrom = loc.y - 10
		local yTo = y + 10
		if yFrom > yTo then
			line(centerSpr + .2 * dx, yFrom, centerTxt - 0.3 * dx, yTo, clr)
		end
	end

	function s.reset()
		s.lines = {0,0,0,0,0,0,0,0}
	end

	function s.update()
		for i = 1, #s.lines do
			local line = s.lines[i]
			if line ~= 0 and not s.isLineActive(line) then
				-- clear line
				s.lines[i] = 0
			end
		end
	end

	function s.draw()
		for i = 1, #s.lines do
			if s.isLineActive(s.lines[i]) then
				s.drawLine(i)
			end
		end
	end

	return s
end

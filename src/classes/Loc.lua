
--location class: for npc locations or scene locations
function Loc()
	local s = {
		x = C.NPC_START_X,
		y = C.NPC_START_Y,
		dest = nil,
		spd = C.NPC_WALK_SPD,
		dir = "right"
	}

	function s.setDest(x, y)
		if x < s.x then
			s.dir = "left"
		else
			s.dir = "right"
		end
		s.dest = {x = x, y = y}
	end

	--move towards destination
	function s.update()
		if not s.dest then
			return
		end

		local dx = s.dest.x - s.x
		local dy = s.dest.y - s.y
		local dist = math.sqrt(dx * dx + dy * dy)

		if dist < s.spd then
			s.x = s.dest.x
			s.y = s.dest.y
			s.dest = nil
			return
		end
		local incr = s.spd / dist
		s.x = s.x + dx * incr
		s.y = s.y + dy * incr
	end

	return s
end

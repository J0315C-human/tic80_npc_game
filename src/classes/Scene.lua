
--------- Scene class ----
function Scene(name,
	npcs, -- object of npcs name:npc
	script, -- commands script
	mapOffset -- {x,y} of map tile offset
	)
	local s = {
		t = 0,
		name = name,
		npcs = npcs,
		tics = {},
		tags = {},
		lines = nil,
		loc = Loc(),
		map = nil,
	}

	s.lines = Lines(s)
	s.map = Map(s, mapOffset)

	s.loc.x = 0
	s.loc.y = 0
	s.loc.spd = C.STAGE_MOVE_SPD_MED

	for k, npc in pairs(s.npcs) do
		npc.parent = s
	end	

	function s.getTime() return s.t end

	function s.reset()
		s.lines.reset()
		for k, npc in pairs(s.npcs) do
			npc.reset()
		end
		s.loc.x = 0
		s.loc.y = 0
		s.loc.spd = C.STAGE_MOVE_SPD_MED
		s.loc.dest = nil
		s.t=0
	end

	function s.parseTic(t)
		if not tonumber(t) then
			if string.find(t, "+") then
				--relative to after tag
				local pts = split(t, "+")
				return tostring(tonumber(s.tags[pts[1]]) + tonumber(pts[2]))
			elseif string.find(t, "-") then
				--relative to before tag
				local pts = split(t, "-")
				return tostring(tonumber(s.tags[pts[1]]) - tonumber(pts[2]))
			else
				--just tag
				return s.tags[t]
			end
		else
			return t
		end
	end
	function s.placeCmdInTics(cmd)
		local t = s.parseTic(cmd.tic)
		if s.tics[t] then
			s.tics[t][#s.tics[t] + 1] = cmd
		else
			s.tics[t] = {cmd}
		end
	end

	function s.initScript()
		for cmdLine in script:gmatch("[^\n]+") do
			--build up lib of tic cmds
			local cmd = Command(cmdLine)
			if cmd.cmd == "tag" then
				--do definition
				s.handleTagCommand(cmd)
			else
				s.placeCmdInTics(cmd)
			end
		end
	end

	function s.handleTagCommand(cmd)
		--set time tag
		local t = cmd.params[1]
		s.tags[cmd.name] = s.parseTic(t)
	end

	function s.getNpcOrNpcs(name)
		if string.find(name, ',') then
			local npcs = {}
			local names = split(name, ',')
			for i=1, #names do
				npcs[#npcs+1] = s.getNpcOrNpcs(names[i])
			end
			return npcs
		else
			local npc = s.npcs[name]
			if not npc then
				error("missing NPC " .. name)
			end
			return npc
		end
	end

	function s.getNpcCoords(npcOrNpcs)
		if npcOrNpcs[1] == nil then
			return {x = npcOrNpcs.loc.x, y = npcOrNpcs.loc.y}
		else
			local totalX = 0
			local totalY = 0
			for i=1, #npcOrNpcs do
				totalX = totalX + npcOrNpcs[i].loc.x
				totalY = totalY + npcOrNpcs[i].loc.y
			end
			return {
				x = totalX / #npcOrNpcs,
				y = totalY / #npcOrNpcs
			}
		end
	end

	function s.isRelativeCoord(param)
		if param == nil then return false end
		if string.find(param, "+") or string.find(param, "-") then
			return true
		end
		return false
	end

	function s.getMoveXY(params, loc)
		local p = params
		local x = 0
		local y = 0
		if loc then 
			x = loc.x
			y = loc.y
		end
		if #p == 2 then
			-- use x/y params
			if s.isRelativeCoord(p[1]) then
				x = x + tonumber(p[1])
			else
				x = tonumber(p[1])
			end
			if s.isRelativeCoord(p[2]) then
				y = y + tonumber(p[2])
			else
				y = tonumber(p[2])
			end
		elseif #p == 1 or #p == 3 then
			-- use other NPC's loc
			local npc2 = s.getNpcOrNpcs(p[1])
			local npc2Loc = s.getNpcCoords(npc2)
			if #p == 1 then
				x = npc2Loc.x
				y = npc2Loc.y
			else
				local to = s.getMoveXY({p[2], p[3]}, npc2Loc)
				x = to.x
				y = to.y
			end
		end
		return {x = x, y = y}
	end

	function s.handleMoveCommand(npc, cmd)
		local to = s.getMoveXY(cmd.params, npc.loc)

		if cmd.cmd == "to" then
			npc.loc.x = tonumber(to.x)
			npc.loc.y = tonumber(to.y)
			npc.loc.dest = nil
		elseif cmd.cmd == "walk" then
			npc.loc.setDest(to.x, to.y)
			npc.walk()
		elseif cmd.cmd == "run" then
			npc.loc.setDest(to.x, to.y)
			npc.run()
		end
	end

	function s.handleFaceCommand(npc, cmd)
		local dir = cmd.params[1]
		if dir ~= "left" and dir ~= "right" then
			--face towards/away from other npc
			local npc2Loc
			local toLeft
			local toRight
			if string.find(dir, "-") then
				local npc2 = s.getNpcOrNpcs(split(dir, "-")[1])
				npc2Loc = s.getNpcCoords(npc2)
				toLeft = "right"
				toRight = "left"
			else
				local npc2 = s.getNpcOrNpcs(dir)
				npc2Loc = s.getNpcCoords(npc2)
				toLeft = "left"
				toRight = "right"
			end

			local dx = npc.loc.x - npc2Loc.x
			if dx > 0 then
				dir = toLeft
			else
				dir = toRight	
			end
		end
		npc.loc.dir = dir
	end

	function s.applyCommandToNpc(cmd,npc)
		if string.find("to walk run", cmd.cmd) then
			s.handleMoveCommand(npc, cmd)
		elseif cmd.cmd == "face" then
			s.handleFaceCommand(npc, cmd)
		elseif cmd.cmd == "wave" then
			npc.wave()
		elseif cmd.cmd == "say" then
			local str = ""
			for i = 1, #cmd.params do
				str = str .. " " .. cmd.params[i]
			end
			s.lines.add(npc, str)
		elseif cmd.cmd == "jump" then
			npc.startJump()
		elseif cmd.cmd == "gesture" then
			npc.gesture()
		elseif cmd.cmd == "point" then
			npc.point()
		elseif cmd.cmd == "stop" then
			npc.idle()
			s.lines.clearNpcLine(npc)
		end

	end

	function s.handleStageCommand(cmd)
		local to = s.getMoveXY(cmd.params, s.loc)
		if not s.isRelativeCoord(cmd.params[1]) then
			to.x = to.x - 110
		end
		if not s.isRelativeCoord(cmd.params[2]) then
			to.y = to.y - 60
		end

		--cut to destination
		if cmd.cmd == 'to' then
			s.loc.x = to.x
			s.loc.y = to.y
			s.loc.dest = nil
			return
		end
		--pan to destination
		s.loc.setDest(to.x, to.y)
		if cmd.cmd == 'slowpan' then
			s.loc.spd = C.STAGE_MOVE_SPD_SLOW
		elseif cmd.cmd == 'pan' then
			s.loc.spd = C.STAGE_MOVE_SPD_MED
		elseif cmd.cmd == 'fastpan' then
			s.loc.spd = C.STAGE_MOVE_SPD_FAST
		end
	end

	function s.handleCommand(cmd)
		if cmd.name == '-' then
			return s.handleStageCommand(cmd)
		end

		local npc = s.getNpcOrNpcs(cmd.name)
		if isArray(npc) then
			for i = 1, #npc do
				s.applyCommandToNpc(cmd, npc[i])
			end
		else
			s.applyCommandToNpc(cmd, npc)
		end
	end

	function s.update(doDraw)
		if doDraw == nil then doDraw = true end

		local cmds = s.tics[tostring(s.t)]
		if cmds then
			for i = 1, #cmds do
				local c = cmds[i]
				s.handleCommand(c)
				local x = "" .. s.t .. " " .. c.name .. " " .. c.cmd
				G.debug = x
			end
		end

		s.loc.update()
		invokeBackToFront(asList(s.npcs), "update")
		s.lines.update()

		s.t = s.t + 1
	end

	function s.draw()
		s.map.draw()
		invokeBackToFront(asList(s.npcs), "draw")
		s.lines.draw()
	end

	function s.tic()
		s.update()
		s.draw()
	end

	function s.seek(t)
		if t < s.t then
			s.reset()
		end

		while s.t < t do
			s.update()
		end
	end

	-- initialize and return obj
	s.initScript()
	return s
end

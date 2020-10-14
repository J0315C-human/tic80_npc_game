-- title:  omni
-- author: joel schuman
-- desc:   people walk around and do stuff
-- script: lua

local C = {
	--config
	DEF_ANIM_TICS = 5,
	BG_COL = 5,
	CLEAR_COL = 14,
	NPC_WALK_SPD = 0.5,
	NPC_RUN_SPD = 1.3,
	NPC_START_X = -30,
	NPC_START_Y = 0,
	STAGE_MOVE_SPD_SLOW = 0.3,
	STAGE_MOVE_SPD_MED = 1.5,
	STAGE_MOVE_SPD_FAST = 4,
	JUMP_SCALE = 0.3,
	TEXT_TOP = 8,
	T_LINE_MIN = 40,
	T_PER_LETTER = 3,
	CHAR_WIDTH = 6,
}

local G = {
	--global state
	t = 0,
	debug = "",
	--cur scene
	scene = nil
}

function clamp(val, min, max)
	if val < min then
		return min
	elseif val > max then
		return max
	else
		return val
	end
end

function isArray(table)
	if table[1] then
		return true
	else return false end
end

function asList(table)
	local all = {}
	for k, item in pairs(table) do
		all[#all + 1] = item
	end
	return all
end

function invokeBackToFront(
	objects, --objects with locations
	methodNm) -- method name
	function sortByY(a, b)
		return b.loc.y > a.loc.y
	end
	table.sort(objects, sortByY)

	for i = 1, #objects do
		local f = objects[i][methodNm]
		if f then
			f()
		end
	end
end

function getCenteredTextX(str)
	local w = string.len(str) * C.CHAR_WIDTH
	return 120 - w / 2
end

local function split(str, sep)
	local result = {}
	local regex = ("([^%s]+)"):format(sep)
	for each in str:gmatch(regex) do
		table.insert(result, each)
	end
	return result
end

-- auto-restarting animation class ---
function Anim(
	sprites, --spr indices
	tics, --tics per frame
	loop)
	local s = {
		idx = 1,
		sprites = sprites,
		tics = tics or C.DEF_ANIM_TICS,
		prevFrame = 0,
		prevUsed = 0,
		done = false,
		loop = loop or false,
		parent = nil,
	}

	function s.getTime()
		if s.parent then
			return s.parent.getTime()
		else
			return G.t
		end
	end

	function s.reset()
		s.idx = 1
		s.prevFrame = 0
		s.prevUsed = 0
		s.done = false
	end

	function s.restart()
		s.done = false
		s.idx = 1
	end

	function s.atEnd()
		return s.idx == #s.sprites
	end

	function s.goNext()
		if not s.loop and s.atEnd() then
			s.done = true
			return
		end

		s.idx = s.idx + 1
		--reset to start
		if s.idx > #s.sprites then
			s.restart()
		end
	end
	-- update anim state on each tic
	function s.update()
		local sinceF = s.getTime() - s.prevFrame
		local sinceU = s.getTime() - s.prevUsed
		-- restart animation after a break
		if sinceU > 1 then
			s.restart()
			s.prevFrame = s.getTime()
		elseif sinceF > s.tics then
			s.goNext()
			s.prevFrame = s.getTime()
		end
		s.prevUsed = s.getTime()
	end

	function s.get()
		s.prevUsed = s.getTime()
		return s.sprites[s.idx]
	end

	return s
end
----------------------
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

--npc class----
function Npc(
	anims, --animation table
	size, --x/y sprite size
	loc) --starting loc
	local s = {
		loc = Loc(),
		size = size,
		anim = nil,
		anims = anims,
		jumpVel = 0,
		jumpHgt = 0,
		running = false,
		speechClr = 4,
		parent = nil,
	}
	-- set parent on anims
	for k, anim in pairs(s.anims) do
		anim.parent = s
	end

	function s.getTime()
		if s.parent then
			return s.parent.getTime()
		else 
			return G.t
		end
	end

	function s.reset()
		s.loc = Loc()
		s.anim = nil
		s.jumpVel = 0
		s.jumpHgt = 0
		s.running = false
		for k, anim in pairs(s.anims) do
			anim.reset()
		end
	end

	function s.getAnim()
		return s.anims[s.anim]
	end

	function s.setAnim(name)
		if s.anims[name] then
			s.anim = name
		else
			s.anim = nil
		end
	end

	function s.isMoving()
		return s.loc.dest ~= nil
	end

	function s.run()
		if not s.running then
			s.running = true
		end
		s.loc.spd = C.NPC_RUN_SPD
	end

	function s.walk()
		if s.running then
			s.running = false
		end
		s.loc.spd = C.NPC_WALK_SPD
	end

	function s.wave()
		s.loc.dest = nil
		s.setAnim('wave')
	end

	function s.gesture()
		s.loc.dest = nil
		s.setAnim('gesture')
	end

	function s.point()
		s.loc.dest = nil
		s.setAnim('point')
	end

	function s.idle()
		s.loc.dest = nil
		s.setAnim('idle')
	end

	function s.isJumping()
		return s.jumpHgt > 0 or s.jumpVel > 0
	end

	function s.startJump()
		if s.isJumping() then
			return
		end
		s.jumpVel = 7
	end

	function s.updateJump()
		if s.isJumping() then
			s.jumpVel = s.jumpVel - 0.4
			s.jumpHgt = s.jumpHgt + s.jumpVel
			if s.jumpHgt < 0 then
				s.jumpHgt = 0
			end
		end
	end

	function s.pickAnim()
		if s.isJumping() then
			return s.setAnim("jump")
		end
		if s.isMoving() then
			if s.running then
				s.setAnim("run")
			else
				s.setAnim("walk")
			end
		elseif (s.anim == "walk" or s.anim == "run") and not s.isMoving() then
			s.setAnim("idle")
		end
		if s.anim == nil then
			s.anim = "idle"
		end
	end

	function s.update()
		--update location
		s.loc.update()
		--update jump state
		s.updateJump()
		--update which anim to use
		s.pickAnim()
		--update animation
		anim = s.getAnim()
		if anim then
			anim.update()
			if anim.done then
				s.setAnim("idle")
			end
		end
	end

	function s.getCoords()
		if s.parent and s.parent.loc then
			return {
				x = s.loc.x - s.parent.loc.x, 
				y = s.loc.y - s.parent.loc.y,
			}
		else
			return {x = s.loc.x, y = s.loc.y}
		end
	end
	function s.draw()
		local anim = s.getAnim()
		if anim then
			local flip = 0
			if s.loc.dir == "left" then
				flip = 1
			end
			local coords = s.getCoords()
			spr(anim.get(), 
				coords.x, 
				coords.y - C.JUMP_SCALE * s.jumpHgt,
				C.CLEAR_COL, 2, flip, 0, s.size.x, s.size.y)
		end
	end

	return s
end

---------------------------
function makeNpc(i, speechClr)
	i = i + 256
	local n =
		Npc(
		{
			idle = Anim({i}, 30, true),
			walk = Anim({2 + i, 1 + i}, 5, true),
			jump = Anim(
				{
					5 + i,
					4 + i,
					4 + i,
					3 + i,
					3 + i,
					5 + i
				},
				5
			),
			run = Anim({2 + i, 3 + i, 2 + i, 1 + i}, 3, true),
			wave = Anim({6 + i,7 + i, 6 + i, 7 + i, 6 + i, 7 + i}, 10),
			gesture = Anim({8 + i}, 100),
			point = Anim({9 + i}, 100),
		},
		{x = 1, y = 2},
		{x = C.NPC_START_X, y = C.NPC_START_Y}
	)
	if speechClr then
		n.speechClr = speechClr
	end
	return n
end

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

--------- Command "class" ----
function Command(cmdStr)
	local parts = split(cmdStr, " ")

	local s = {
		tic = parts[1],
		name = parts[2],
		cmd = parts[3],
		params = {}
	}
	for i = 4, #parts do
		s.params[#s.params + 1] = parts[i]
	end

	return s
end
--------- Stage class -----
function Map(parent, mapOffset)
	local s = {
		parent = parent,
		mapXOffset = 0,
		mapYOffset = 0,
	}
	if mapOffset then
		s.mapXOffset = mapOffset.x
		s.mapYOffset = mapOffset.y
	end
	function s.draw()
		local mapXRem = s.parent.loc.x % 8
		local mapYRem = s.parent.loc.y % 8
		local mapX = (s.parent.loc.x - mapXRem) / 8 + s.mapXOffset
		local mapY = (s.parent.loc.y - mapYRem) / 8 + s.mapYOffset

		map(mapX, mapY, 31, 18, -mapXRem, -mapYRem)
	end

	return s
end
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

local testScript =[[
- a tag 240
- b tag a+650
- c tag b+720
- d tag c+420
- e tag d+600
- f tag e+250 
- ef tag f-100

0 roy to -10 80
0 dot to 240 60
0 cat to 240 80
0 roy walk +50 80
0 dot walk 130 80

0 - to roy
50 - pan +30 +0
100 - slowpan roy,dot

a roy say Hey there Dot.
a roy wave
a+40 dot wave
a+60 dot say Oh hi, Roy.
a+150 dot say What's new?
a+140 roy walk +20 +0
a+280 roy say Oh, you know.
a+410 roy say My life is in an endless loop.
a+510 roy face -dot
a+510 roy stop
a+540 roy say ...or at least it feels that way.

b dot walk roy +30 +0
b+60 roy face dot
b+100 dot say Have you heard the good news
b+200 dot say about our Lord and Savior Xenon?
b+350 roy walk -10 +0
b+350 roy face dot
b+400 roy say ...what do you mean?
b+520 dot say Xenon!
b+521 dot jump
b+600 dot say "the true light of the future"
b+610 dot gesture

c-80 cat run dot +45 -5
c-50 cat say WAIT!
c roy walk +50 -20
c+150 dot face roy
c+140 cat say Don't listen to a word!
c+140 cat gesture
c+220 roy walk +10 +0
c+250 roy face dot
c+250 dot walk +5 +0
c+300 dot say Hey what's the big idea?
c+300 dot gesture

d - slowpan roy,dot,cat
d roy face cat
d+20 roy face dot
d+40 roy face cat
d+80 cat point
d+100 cat say You're a cult recruiter!
d+160 dot jump
d+200 dot face -cat
d+200 dot walk -120 +0
d+220 dot say You got me!
d+200 dot jump
d+240 dot jump
d+280 dot jump
d+300 dot say I'm outta here!
d+320 dot jump
d+400 roy say Phew, what a relief!
d+460 roy say Thanks, Cat
d+530 cat say No problem, good friend.

e dot run 70 70
e roy walk 102 70
e+20 cat walk 135 70
e+120 cat face left
e+120 dot walk roy -15 +0
e+140 roy face right
e+180 roy face left
e+170 cat walk roy +15 +0
e+155 roy face left

ef - slowpan cat,roy,dot
ef+150 cat,roy,dot gesture
ef+180 cat,roy,dot gesture
ef+210 cat,roy,dot gesture
ef+240 cat,roy,dot gesture
ef+270 cat,roy,dot gesture
ef+300 cat,roy,dot gesture
ef+330 cat,roy,dot gesture

f+20 cat say THE END
f+30 roy say the
f+10 dot say THE 
f+60 roy say the END
f+50 dot say THE END
f+80 cat say THE END
]]

local npcs={
	bob = makeNpc(0),
	ted = makeNpc(32,2),
	roy = makeNpc(64, 6),
	sam = makeNpc(96, 1),
	dot = makeNpc(128,4),
	dee = makeNpc(160, 10),
	cat = makeNpc(192, 12),
	pat = makeNpc(224, 11),
}

local s1 =
	Scene('A Very Special Episode',
	{roy=npcs.roy,cat=npcs.cat,dot=npcs.dot},
	testScript,
	{x=15, y=-3}
)

G.scene=s1

function UPDATE()
	cls(C.BG_COL)
	if btnp(1) then
		G.scene.seek(0)
	elseif btnp(2) then
		G.scene.seek(G.scene.t - 100);
		elseif btnp(3) then
		G.scene.seek(G.scene.t + 100);
	end
	if G.scene then
		G.scene.tic()
	end

	G.t = G.t + 1
end

function TIC()
	UPDATE()
	print(G.scene.name, 100,1,13)
end

-- <TILES>
-- 000:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 001:55ee55ee5555ee5555ee55eeee55555555ee55ee5555ee5555ee55eeee555555
-- 002:5e555555555555555555eee55555555555ee55ee55555555ee555ee555555555
-- 003:ee555555e5eeeeee5eeeeeee5eee55555ee5eeee5ee5eeee5ee5eee55ee5ee5e
-- 004:555555eeeeeeee5eeeeeeee55555eee5eeee5ee5eeee5ee55eee5ee5e5ee5ee5
-- 005:e555555e5eeeeee55eeeeee55eeeeee55eeeeee55eeeeee55eeeeee5e555555e
-- 006:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 007:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 016:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 017:e5eeee5eee5555ee5eeeeee5e5eeee5ee5eeee5e5eeeeee5ee5555eee5eeee5e
-- 018:eee555eeee5eee5ee5555eee5eeee5eeeeee555eeee5eee5ee5555eee5eeee5e
-- 019:5ee5ee5e5ee5eee55ee5eeee5ee5eeee5eee55555eeeeeeee5eeeeeeee555555
-- 020:e5ee5ee55eee5ee5eeee5ee5eeee5ee55555eee5eeeeeee5eeeeee5e555555ee
-- 021:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 022:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 023:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 032:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 033:5ee55ee5e55ee55e5ee55ee5e55ee55e5ee55ee5e55ee55e5ee55ee5e55ee55e
-- 034:ee55ee55ee55ee5555ee55ee55ee55eeee55ee55ee55ee5555ee55ee55ee55ee
-- 035:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 036:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 037:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 038:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 039:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 048:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 049:eeee5555eeee5555eeee5555eeee55555555eeee5555eeee5555eeee5555eeee
-- 050:eeeeeeeeeeeeee55eeeee5eeeeee5eeeeeee5eeeeee5eeee555eeeeeeeeeeeee
-- 051:eeeeeeee555eeeeeeee5eeeeeeee5eeeeeee5eeeeeeee5eeeeeeee55eeeeeeee
-- 052:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 053:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 054:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 055:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 064:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 065:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 066:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 067:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 068:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 069:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 070:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 071:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- </TILES>

-- <SPRITES>
-- 000:eeeeee2eee22222eeebbbbbeeebb1b1eeebbbbbeeee666eeeee666eeeee666ee
-- 001:eeeee2eee22222eeebbbbbeeebb1b1eeebbbbbeeee666eeeee666eeeee666eee
-- 002:eeeeee2eee22222eeebbbbbeeebb1b1eeebbbbbeeee666eeeee666eeeee666ee
-- 003:eeeeee2eee22222eeebbbbbeeebb1b1eeebbbbbeeee666eeee6666eeee6666ee
-- 004:eeeeee2eee22222eeebbbbbeeebb1b1eeebbbbbeeee666eeb666666beee666ee
-- 005:eeeeeeeeeeeeeeeeeeeee2eee22222eeebbbbbeeebb1b1eeebbbbbeee666eeee
-- 006:eeeeee2eee22222eeebbbbbeeebb1b1eeebbbbbebee666eee66666eeeee666ee
-- 007:eeeeee2eee22222eeebbbbbeeebb1b1eeebbbbbeebe666eee66666eeeee666ee
-- 008:eeeeee2eee22222eeebbbbbeeebb1b1eeebbbbbeeee666eeb666666beee666ee
-- 009:eeeeee2eee22222eeebbbbbeeebb1b1eeebbbbbeeee666eeeee6666beee666ee
-- 016:eeeb66eeeee666eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee8e8eeeee8e8ee
-- 017:eeb66eeeee666eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee8e8eeeee8e8eee
-- 018:eeeb66eeeee666eeeee888eeeee8e8eeeee8e8eeeee8e8eeee8ee8eeee8ee8ee
-- 019:eeb666beeee666eeeee888eeeee8ee8eee88ee8ee8eeee8ee8eeee8eeeeeeeee
-- 020:eee666eeeee666eeeee888eeeee8ee8eee88ee8ee8eeee8ee8eeee8eeeeeeeee
-- 021:6666eeee6666eeeeb666beee8888eeeee8ee8eeee8ee8eee8ee8eeee8ee88eee
-- 022:eee666eeeee666eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee8e8eeeee8e8ee
-- 023:eee666eeeee666eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee8e8eeeee8e8ee
-- 024:eee666eeeee666eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee8e8eeeee8e8ee
-- 025:eeeb66eeeee666eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee8e8eeeee8e8ee
-- 032:eeeeee0eee00000eee33333eee33838eee33333eeee444eeeee444eeeee466ee
-- 033:eeeee0eee00000eee33333eee33838eee33333eeee444eeeee444eeeee466eee
-- 034:eeeeee0eee00000eee33333eee33838eee33333eeee444eeeee444eeeee466ee
-- 035:eeeeee0eee00000eee33333eee33838eee33333eeee444eeee4444eeee4666ee
-- 036:eeeeee0eee00000eee33333eee33838eee33333eeee444ee34444443eee666ee
-- 037:eeeeeeeeeeeeeeeeeeeee0eee00000eee33333eee33838eee33333eee444eeee
-- 038:eeeeee0eee00000eee33333eee33838eee33333e3ee444eee44444eeeee666ee
-- 039:eeeeee0eee00000eee33333eee33838eee33333ee3e444eee44444eeeee666ee
-- 040:eeeeee0eee00000eee33333eee33838eee33333eeee444ee34444443eee666ee
-- 041:eeeeee0eee00000eee33333eee33838eee33333eeee444eeeee44443eee466ee
-- 048:eee344eeeee444eeeee999eeeee9e9eeeee9e9eeeee9e9eeeee9e9eeeee9e9ee
-- 049:ee344eeeee444eeeee999eeeee9e9eeeee9e9eeeee9e9eeeee9e9eeeee9e9eee
-- 050:eee344eeeee444eeeee999eeeee9e9eeeee9e9eeeee9e9eeee9ee9eeee9ee9ee
-- 051:ee34443eeee444eeeee999eeeee9ee9eee99ee9ee9eeee9ee9eeee9eeeeeeeee
-- 052:eee444eeeee444eeeee999eeeee9ee9eee99ee9ee9eeee9ee9eeee9eeeeeeeee
-- 053:4666eeee4444eeee34443eee9999eeeee9ee9eeee9ee9eee9ee9eeee9ee99eee
-- 054:eee444eeeee444eeeee999eeeee9e9eeeee9e9eeeee9e9eeeee9e9eeeee9e9ee
-- 055:eee444eeeee444eeeee999eeeee9e9eeeee9e9eeeee9e9eeeee9e9eeeee9e9ee
-- 056:eee444eeeee444eeeee999eeeee9e9eeeee9e9eeeee9e9eeeee9e9eeeee9e9ee
-- 057:eee344eeeee444eeeee999eeeee9e9eeeee9e9eeeee9e9eeeee9e9eeeee9e9ee
-- 064:eee888eeee88888eeefffffeeeff1f1eeefffffeeee222eeeee222eeeeef22ee
-- 065:ee888eeee88888eeefffffeeeff1f1eeefffffeeee222eeeee222eeeeef22eee
-- 066:eee888eeee88888eeefffffeeeff1f1eeefffffeeee222eeeee222eeeeef22ee
-- 067:eee888eeee88888eeefffffeeeff1f1eeefffffeeee222eeee2222eeee2222ee
-- 068:eee888eeee88888eeefffffeeeff1f1eeefffffeeee222eef222222feee222ee
-- 069:eeeeeeeeeeeeeeeeee888eeee88888eeefffffeeeff1f1eeefffffeee222eeee
-- 070:eee888eeee88888eeefffffeeeff1f1eeefffffefee222eee22222eeeee222ee
-- 071:eee888eeee88888eeefffffeeeff1f1eeefffffeefe222eee22222eeeee222ee
-- 072:eee888eeee88888eeefffffeeeff1f1eeefffffeeee222eeff22222feee222ee
-- 073:eee888eeee88888eeefffffeeeff1f1eeefffffeeee222eeeee2222feeef22ee
-- 080:eeef22eeeee222eeeee111eeeee1e1eeeee1e1eeeee1e1eeeee1e1eeeee1e1ee
-- 081:eef22eeeee222eeeee111eeeee1e1eeeee1e1eeeee1e1eeeee1e1eeeee1e1eee
-- 082:eeef22eeeee222eeeee111eeeee1e1eeeee1e1eeeee1e1eeee1ee1eeee1ee1ee
-- 083:eef222feeee222eeeee111eeeee1ee1eee11ee1ee1eeee1ee1eeee1eeeeeeeee
-- 084:eee222eeeee222eeeee111eeeee1ee1eee11ee1ee1eeee1ee1eeee1eeeeeeeee
-- 085:2222eeee2222eeeef222feee1111eeeee1ee1eeee1ee1eee1ee1eeee1ee11eee
-- 086:eee222eeeee222eeeee111eeeee1e1eeeee1e1eeeee1e1eeeee1e1eeeee1e1ee
-- 087:eee222eeeee222eeeee111eeeee1e1eeeee1e1eeeee1e1eeeee1e1eeeee1e1ee
-- 088:eee222eeeee222eeeee111eeeee1e1eeeee1e1eeeee1e1eeeee1e1eeeee1e1ee
-- 089:eeef22eeeee222eeeee111eeeee1e1eeeee1e1eeeee1e1eeeee1e1eeeee1e1ee
-- 096:eee111eeee11111eee3bbbbeeebb7b7eeebbbbbeeee000eeeee000eeeeeb00ee
-- 097:ee111eeee11111eee3bbbbeeebb7b7eeebbbbbeeee000eeeee000eeeeeb00eee
-- 098:eee111eeee11111eee3bbbbeeebb7b7eeebbbbbeeee000eeeee000eeeeeb00ee
-- 099:eee111eeee11111eee3bbbbeeebb7b7eeebbbbbeeee000eeee0000eeee0000ee
-- 100:eee111eeee11111eee3bbbbeeebb7b7eeebbbbbeeee000eeb000000beee000ee
-- 101:eeeeeeeeeeeeeeeeee111eeee11111eee3bbbbeeebb7b7eeebbbbbeee000eeee
-- 102:eee111eeee11111eee3bbbbeeebb7b7eeebbbbbebee000eee00000eeeee000ee
-- 103:eee111eeee11111eee3bbbbeeebb7b7eeebbbbbeebe000eee00000eeeee000ee
-- 104:eee111eeee11111eee3bbbbeeebb7b7eeebbbbbeeee000eeb000000beee000ee
-- 105:eee111eeee11111eee3bbbbeeebb7b7eeebbbbbeeee000eeeee0000beee000ee
-- 112:eeeb00eeeee000eeeeefffeeeeefefeeeeefefeeeeefefeeeeefefeeeee0e0ee
-- 113:eeb00eeeee000eeeeefffeeeeefefeeeeefefeeeeefefeeeeefefeeeee0e0eee
-- 114:eeeb00eeeee000eeeeefffeeeeefefeeeeefefeeeeefefeeeefeefeeee0ee0ee
-- 115:eeb000beeee000eeeeefffeeeeefeefeeeffeefeefeeeefee0eeee0eeeeeeeee
-- 116:eee000eeeee000eeeeefffeeeeefeefeeeffeefeefeeeefee0eeee0eeeeeeeee
-- 117:0000eeee0000eeeeb000beeeffffeeeeefeefeeeefeefeeefeefeeee0ee00eee
-- 118:eee000eeeee000eeeeefffeeeeefefeeeeefefeeeeefefeeeeefefeeeee0e0ee
-- 119:eee000eeeee000eeeeefffeeeeefefeeeeefefeeeeefefeeeeefefeeeee0e0ee
-- 120:eee000eeeee000eeeeefffeeeeefefeeeeefefeeeeefefeeeeefefeeeee0e0ee
-- 121:eeeb00eeeee000eeeeefffeeeeefefeeeeefefeeeeefefeeeeefefeeeee0e0ee
-- 128:eeeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbeeef999feeef999feeeeb99ee
-- 129:eeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbeeef999feeef999feeeeb99eee
-- 130:eeeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbeeef999feeef999feeeeb99ee
-- 131:eeeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbeeff999feee9999feeeb999ee
-- 132:eeeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbeeff999febb9999bbeee999ee
-- 133:eeeeeeeeeeeeeeeeeeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbeeef99feee
-- 134:eeeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbebef999feeb9999feeee999ee
-- 135:eeeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbeebf999feeb9999feeee999ee
-- 136:eeeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbeeef999febb99999beee999ee
-- 137:eeeeeeeeeeeffffeeefbbbbeeefb0b0eeefbbbbeeef999feeef9999beee999ee
-- 144:eeeb99eeeee999eeeee999eeee99999eeeebebeeeeebebeeeeebebeeeee8e8ee
-- 145:eeb99eeeee999eeeee999eeee99999eeeebebeeeeebebeeeeebebeeeee8e8eee
-- 146:eeeb99eeeee999eeeee999eeee99999eeeebebeeeeebebeeeebeebeeee8ee8ee
-- 147:eeb999beeee999eeee99999eeeebeebeeebbeebee8eeeebee8eeee8eeeeeeeee
-- 148:eee999eeeee999eeee99999eeeebeebeeebbeebee8eeeebee8eeee8eeeeeeeee
-- 149:9f99feee9999eeeeb999beee9999eeee99999eeeebeebeeebeebeeee8ee88eee
-- 150:eee999eeeee999eeeee999eeee99999eeeebebeeeeebebeeeeebebeeeee8e8ee
-- 151:eee999eeeee999eeeee999eeee99999eeeebebeeeeebebeeeeebebeeeee8e8ee
-- 152:eee999eeeee999eeeee999eeee99999eeeebebeeeeebebeeeeebebeeeee8e8ee
-- 153:eeeb99eeeeeb99eeeee999eeee99999eeeebebeeeeebebeeeeebebeeeee8e8ee
-- 160:eeeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbeeee4224eeee222eeeeeb22ee
-- 161:eeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbeeee4224eeee222eeeeeb22eee
-- 162:eeeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbeeee4224eeee222eeeeeb22ee
-- 163:eeeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbeeee4224eee2222eeeeb222ee
-- 164:eeeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbeeee4224ebb2222bbeee222ee
-- 165:eeeeeeeeeeeeeeeeeeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbeee4224eee
-- 166:eeeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbebee4224eeb2222eeeee222ee
-- 167:eeeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbeebe4224eeb2222eeeee222ee
-- 168:eeeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbeeee4224ebb22222beee222ee
-- 169:eeeeeeeeeee4444eee4bbbbeee4bfbfeee4bbbbeeee4224eeee2222beeeb22ee
-- 176:eeeb22eeeee222eeeee222eeee22222eeeededeeeeededeeeee0e0eeeee0e0ee
-- 177:eeb22eeeee222eeeee222eeee22222eeeededeeeeededeeeee0e0eeeee0e0eee
-- 178:eeeb22eeeee222eeeee222eeee22222eeeededeeeeededeeee0ee0eeee0ee0ee
-- 179:eeb222beeee222eeee22222eeeedeedeeeddeedee0eeee0ee0eeee0eeeeeeeee
-- 180:eee222eeeee222eeee22222eeeedeedeeeddeedee0eeee0ee0eeee0eeeeeeeee
-- 181:2222eeee2222eeeeb222beee2222eeee22222eeeedeedeee0ee0eeee0ee00eee
-- 182:eee222eeeee222eeeee222eeee22222eeeededeeeeededeeeee0e0eeeee0e0ee
-- 183:eee222eeeee222eeeee222eeee22222eeeededeeeeededeeeee0e0eeeee0e0ee
-- 184:eee222eeeee222eeeee222eeee22222eeeededeeeeededeeeee0e0eeeee0e0ee
-- 185:eeeb22eeeee222eeeee222eeee22222eeeededeeeeededeeeee0e0eeeee0e0ee
-- 192:eeeeeeeeeeeddddeeedd333deed3030eeed3333eeed777deeee777eeeee777ee
-- 193:eeeeeeeeeeddddeeedd333deed3030eeed3333eeed777deeee777eeeee777eee
-- 194:eeeeeeeeeeeddddeeedd333deed3030eeed3333eeed777deeee777eeeee777ee
-- 195:eeeeeeeeeeeddddeeedd333deed3030eeed3333eeed777deee7777eeee7777ee
-- 196:eeeeeeeeeeeddddeeedd333deed3030eeed3333eeed777de37777773eee777ee
-- 197:eeeeeeeeeeeeeeeeeeeeeeeeeeddddeeedd333deed3030eeed3333eeed77deee
-- 198:eeeeeeeeeeeddddeeedd333deed3030eeed3333e3ed777dee77777eeeee777ee
-- 199:eeeeeeeeeeeddddeeedd333deed3030eeed3333ee3d777dee77777eeeee777ee
-- 200:eeeeeeeeeeeddddeeedd333deed3030eeed3333eeed777de37777773eee777ee
-- 201:eeeeeeeeeeeddddeeedd333deed3030eeed3333eeed777deeee77773eee777ee
-- 208:eee377eeeee777eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee0e0eeeee0e0ee
-- 209:ee377eeeee777eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee0e0eeeee0e0eee
-- 210:eee377eeeee777eeeee888eeeee8e8eeeee8e8eeeee8e8eeee0ee0eeee0ee0ee
-- 211:ee37773eeee777eeeee888eeeee8ee8eee88ee8ee0eeee8ee0eeee0eeeeeeeee
-- 212:eee777eeeee777eeeee888eeeee8ee8eee88ee8ee0eeee8ee0eeee0eeeeeeeee
-- 213:7777eeee7777eeee37773eee8888eeeee8ee8eeee8ee8eee0ee0eeee0ee00eee
-- 214:eee777eeeee777eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee0e0eeeee0e0ee
-- 215:eee777eeeee777eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee0e0eeeee0e0ee
-- 216:eee777eeeee777eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee0e0eeeee0e0ee
-- 217:eee377eeeee777eeeee888eeeee8e8eeeee8e8eeeee8e8eeeee0e0eeeee0e0ee
-- 224:eeeeeeeeeee2222eee2222d2ee2d0d0eee2ddddeeee111eeeee111eeeee111ee
-- 225:eeeeeeeeee2222eee2222d2ee2d0d0eee2ddddeeee111eeeee111eeeee111eee
-- 226:eeeeeeeeeee2222eee2222d2ee2d0d0eee2ddddeeee111eeeee111eeeee111ee
-- 227:eeeeeeeeeee2222eee2222d2ee2d0d0eee2ddddeeee111eeee1111eeee1111ee
-- 228:eeeeeeeeeee2222eee2222d2ee2d0d0eee2ddddeeee111eed111111deee111ee
-- 229:eeeeeeeeeeeeeeeeeeeeeeeeee2222eee2222d2ee2d0d0eee2ddddeeee11eeee
-- 230:eeeeeeeeeee2222eee2222d2ee2d0d0eee2ddddedee111eee11111eeeee111ee
-- 231:eeeeeeeeeee2222eee2222d2ee2d0d0eee2ddddeede111eee11111eeeee111ee
-- 232:eeeeeeeeeee2222eee2222d2ee2d0d0eee2ddddeeee111eed111111deee111ee
-- 233:eeeeeeeeeee2222eee2222d2ee2d0d0eee2ddddeeee111eeeee1111deee111ee
-- 240:eeed11eeeee111eeeee777eeeee7e7eeeee7e7eeeee7e7eeeee7e7eeeee0e0ee
-- 241:eed11eeeee111eeeee777eeeee7e7eeeee7e7eeeee7e7eeeee7e7eeeee0e0eee
-- 242:eeed11eeeee111eeeee777eeeee7e7eeeee7e7eeeee7e7eeee7ee7eeee0ee0ee
-- 243:eed111deeee111eeeee777eeeee7ee7eee77ee7ee7eeee7ee0eeee0eeeeeeeee
-- 244:eee111eeeee111eeeee777eeeee7ee7eee77ee7ee7eeee7ee0eeee0eeeeeeeee
-- 245:1111eeee1111eeeed111deee7777eeeee7ee7eeee7ee7eee7ee7eeee0ee00eee
-- 246:eee111eeeee111eeeee777eeeee7e7eeeee7e7eeeee7e7eeeee7e7eeeee0e0ee
-- 247:eee111eeeee111eeeee777eeeee7e7eeeee7e7eeeee7e7eeeee7e7eeeee0e0ee
-- 248:eee111eeeee111eeeee777eeeee7e7eeeee7e7eeeee7e7eeeee7e7eeeee0e0ee
-- 249:eeed11eeeee111eeeee777eeeee7e7eeeee7e7eeeee7e7eeeee7e7eeeee0e0ee
-- </SPRITES>

-- <MAP>
-- 000:314100304031410030403141003040314100304031410030403141111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 001:003040314100304031410030403141003040314100304031411122131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 002:403141003040314100304031410030403141003040314122222222131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111130
-- 003:410030403141003040314100304031410030403141222222222222131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131
-- 004:304031410030403141003040314100304031412222222222222222131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 005:314100304031410030403141003040314111111111111111111122131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 006:003040314100304031410030403141111111111111111111111122131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 007:403141003040314100304031415011501150115011501150115022131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111130
-- 008:410030403141003040314122222222222222222222222222222222131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131
-- 009:304031410030403141222222222222222222222222222222222222131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 010:314100304031411111111111111111111111111111111111111122131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 011:003040314111111111111111111111111111111111111111111122131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 012:403141501150115011501150115011501150115011501150115022131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111130
-- 013:412222222222222222222222222222222222222222222222222222131111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111131
-- 014:233323332333233323332333233323332333233323332333233323631111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 015:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 016:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 017:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 018:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 019:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 020:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 021:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 022:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 023:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 024:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 025:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 026:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 027:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 028:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 029:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 030:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 031:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 032:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 033:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 034:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 035:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 036:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 037:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 038:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 039:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 040:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 041:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 042:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 043:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 044:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 045:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 046:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 047:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 048:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 049:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 050:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 051:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 052:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 053:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 054:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 055:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 056:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 057:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 058:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 059:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 060:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 061:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 062:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 063:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 064:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 065:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 066:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 067:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 068:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 069:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 070:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 071:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 072:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 073:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 074:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 075:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 076:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 077:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 078:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 079:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 080:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 081:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 082:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 083:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 084:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 085:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 086:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 087:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 088:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 089:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 090:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 091:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 092:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 093:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 094:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 095:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 096:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 097:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 098:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 099:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 100:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 101:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 102:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 103:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 104:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 105:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 106:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 107:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 108:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 109:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 110:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 111:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 112:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 113:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 114:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 115:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 116:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 117:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 118:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 119:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 120:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 121:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 122:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 123:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 124:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 125:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 126:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 127:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 128:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 129:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 130:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 131:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 132:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 133:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 134:111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- 135:304011111130401111113040111111304011111130401111113040111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000300000000000
-- </SFX>

-- <PALETTE>
-- 000:1a1c2c5d2c81b23865a16975ffcd755d717138b76425717929366f3b5dc9999999d6aeaef4f4f494b0c2485061795038
-- </PALETTE>


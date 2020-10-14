
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


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

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

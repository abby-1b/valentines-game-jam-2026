pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
--main

-- screen values
screen_title=0
screen_intro=1 -- not implemented
screen_game=2
game_over=3
victory=4

frame_count=0
delta=0

score=0
pwrs_score=0
pwr_every=30
function _init()
	screen=screen_title
	setup_boss()
	setup_clouds()
	
	enemy_setup()
	make_enemy()
	
end

function _update60()
	if(screen==screen_game)update_game()
	if player.health<=0 then
		screen=game_over
	end
	if score%30==0 and score>= pwrs_score then
		spawn_powers()
		pwrs_score+=pwr_every
	end
end

function _draw()
	frame_count+=1
	local t=time()
	if screen==screen_title then
		draw_title()
		if(btnp(❎)) then
			screen=screen_intro
			music(patt)
		end
	elseif screen==screen_intro then
		draw_intro()
		-- if(btnp(❎)) then
		-- 	screen=screen_game
		-- end
	elseif screen==screen_game then
		draw_game()
	elseif screen==game_over then
		game_over()
		if btn(❎) then
			restart()
		end
	elseif screen==victory then
		victory_screen()
		if btn(❎) then
			restart()
		end
	end
end

-- title
function draw_title()
	cls(0)
	print("cupid cupid!", 50, 64-8)
	if(frame_count%25<10) then
		print("[press ❎ to play]", 4, 64+8)
	end
end

-- intro
intro_frames=0
intro_pressed=0
intro_presses=0
dialogue_anim=0
intro_dialogue={
	"cupid: oh no! ❎",
	"too little love! ❎",
	"too much hate! ❎",
	"i should... ❎"
}
intro_good={
	"love!",
	"ily!",
	"happy!",
	"cute!",
	"pretty!",
	"xoxo",
}
intro_bad={
	"hate",
	"hate",
	"hate",
	"ugly",
	"stupid",
	"dumb",
}
good_stream=""
bad_stream=""
function draw_intro()
	local before = intro_frames
	intro_frames += 2/stat(7)
	if (before % 0.5) > 0.25 and (intro_frames % 0.5) < 0.25 and intro_frames<4 then
		sfx(6)
	end

	cls(12)

	s=stat(1)

	local pan=1-(1/(1+intro_frames))

	dcmp(64,0,30+pan*2)
	dcmp(67,0,0+pan*8)
	dcmp(79,0,43+pan*8)

	spr(50,90,44+pan*8)
	spr(51,29,21+pan*8)

	local wlen=7
	while #good_stream<wlen do
		good_stream=good_stream.." "..rnd(intro_good)
	end
	while #bad_stream<wlen do
		bad_stream=rnd(intro_bad).." "..bad_stream
	end
	print(sub(bad_stream,-7,-1),102,45+pan*8,2)
	if(frame_count%2==0)bad_stream=sub(bad_stream,1,-2)
	print(sub(good_stream,0,7),-1,22+pan*8,8)
	if(frame_count%2==0)good_stream=sub(good_stream,2,-1)

	local walk_frames=min(intro_frames*8, 32)
	spr(16,66,119+pan*8-walk_frames+sin(intro_frames>>1)*1,1,2)
	spr(1,56,118+pan*8-walk_frames,2,2)

	dcmp(85,0,73+pan*22)

	if intro_frames>3.5 then
		if btn(❎)and intro_pressed==0 then
			intro_presses+=1
			dialogue_anim=0
			intro_pressed=1
		else
			intro_pressed=0
		end
		if intro_presses==#intro_dialogue then
			intro_presses=0
			start_game()
		end
		t=intro_dialogue[intro_presses+1]
		if(dialogue_anim<(#t-2))sfx(7)
		dialogue_anim+=1
		print(sub(t,1,dialogue_anim),64-(#t)*2,84,0)
	end

end

function start_game()
	screen=screen_game
	music(1)
end

function victory_screen()
	cls(0)
	print("you saved valetine's!!!",50,50,7)
	print("wanna try again? ❎",50,50,7)
end

function restart()
	score=0
	player.health=3
	player.x=20
	player.y=64
	player.power=0
	player.clear=0
	powers={}
	_init()
	draw_game()
	start_game()
end

-- game
frames_without_shooting=0
has_shot_during_game=false

function draw_game()
	cls(12)
	
	print("score: "..score.."00",30,1,0)
	draw_main_cloud()
	foreach(clouds,draw_cloud)
	draw_particles()
	foreach(arrows,draw_arrow)
	
	foreach(enemies,draw_enemy)
	foreach(powers,draw_power)

	draw_boss()

	draw_player(player)

	frames_without_shooting+=1
	if frames_without_shooting>240 and not has_shot_during_game then
		print("press ❎ to shoot!", 32, 64-3, 8)
	end
end

function update_game()
	update_player(player)
	spawn_enemies()
	foreach(arrows,update_arrow)
	foreach(enemies,update_enemy)
	update_boss()
	foreach(powers,update_power)
end

--game over
function game_over()
	cls(0)
	print("game over!!!",37,35,7)
	print("save valentine's day!",20,45,7)
	print("try again? ❎",34,55,7)
end

-->8
--player

power_cherub=1
power_rose=2
power_choc=3
power_love=4
lives_sprite=28

player_reload_cooldown=15
player_reload_cooldown_love=8

player={
	x=20,
	y=64,
	w=9,
	h=11,
	health=3,
	power=0,
	clear=0,
	dx=0,
	dy=0,
	flap=0,
	cooldown=0,
	invincibility=0
}

friction=0.65
function update_player(p)
	
	if p.invincibility>0 then
		p.invincibility-=1
	end

	if p.health<=0 then
		
	end
	p.dx*=friction
	p.dy*=friction

	--move
	local speed=2
	if btn(⬆️) then p.dy=-speed end
	if btn(⬇️) then p.dy=speed end
	if btn(⬅️) then p.dx=-speed end
	if btn(➡️) then p.dx=speed end

	--normalize
	if p.dx*p.dy != 0 then
		p.dx*=0.707
		p.dy*=0.707
	end
	p.x+=p.dx
	p.y+=p.dy

	--collide
	if(p.x<=0)p.x=0
	if(p.x>=113)p.x=113
	if(p.y<=0)p.y=0
	if(p.y>=113)p.y=113
	
	p.cooldown-=1
	if (
		btnp(❎) and p.cooldown<=0 and (p.power==0 or p.power==power_cherub)
	) or (
		btn(❎) and p.cooldown<=0 and p.power==power_love
	) then
		sfx(0)
		frames_without_shooting=0
		has_shot_during_game=true
		if p.power==power_love then
			p.cooldown=player_reload_cooldown_love
		else
			p.cooldown=player_reload_cooldown
		end
		make_arrow(p.x,p.y) 

		if p.power==power_cherub then
			make_cherub_arrow(p.x,p.y-16)
			make_cherub_arrow(p.x,p.y+11)
		end
	end
	
	if btnp(❎) and p.cooldown<=0 and p.power==power_rose then
			sfx(2)
			p.cooldown=player_reload_cooldown
			make_thorns(p.x,p.y-9,-0.5)
			make_thorns(p.x,p.y,0)
			make_thorns(p.x,p.y+8,0.5)
	end
	
	if btnp(🅾️) and p.clear>0 then
		score+=#enemies
		sfx(4)
		clear()
	end
	
end

function harm_player()
	if player.invincibility>0 then return end
	player.health-=1
	player.invincibility=20
end

function draw_player(p)
	--health
	s=0
	for i=1,p.health do
		spr(lives_sprite,1+s,1)
		s+=7
	end
	
	c=0
	for i=1,p.clear do
		spr(25,1+c,11)
		c+=7
	end
	
	if p.invincibility%4<2 then
		--wings
		p.flap+=0.25
		if(p.flap>=4)p.flap=0
		local pf=flr(p.flap)
		spr(35+pf,p.x+1,p.y+4)

		--body
		local y_offs=0
		if(p.flap==2)y_offs=1
		local p_spr=3
		if(p.cooldown>0)p_spr=7
		if(p.cooldown>3)p_spr=5
		local x_offs=0
		if(p.cooldown==player_reload_cooldown)x_offs=1
		spr(p_spr,p.x-x_offs,p.y-y_offs,2,2)
	end
	
	--powerup management
	if p.power==power_cherub then
		spr(9,player.x+6,player.y-10)
		spr(9,player.x+6,player.y+17)
	end
end


--projectile logic
arrow_speed=3
arrows={}

function make_arrow(x,y)
	add(arrows,{
		x=x+8,
		y=y+8,
		w=8,
		h=5,
		dy=0,
		sprite=33,
	})
end

function make_cherub_arrow(x,y)
	add(arrows,{
		x=x+8,
		y=y+8,
		w=7,
		h=5,
		dy=0,
		sprite=10,
	})
end

function make_thorns(x,y,dy)
	add(arrows,{
		x=x+8,
		y=y+8,
		w=8,
		h=5,
		dy=dy,
		sprite=11,
	})
end

function update_arrow(arrow)
	arrow.x+=arrow_speed
	arrow.y+=arrow.dy
	if(arrow.x>130)del(arrows,arrow)
	
	for e in all(enemies) do
		if collision(e,arrow) then
			del(arrows,arrow)
			kill({e})
			score+=1
		end
	end
end


function draw_arrow(arrow)
	spr(arrow.sprite,arrow.x-4,arrow.y-3,1+flr(arrow.w/8),1)
	if frame_count%4==0 and arrow.sprite!=11 then
		local col=8
		if arrow.w<8 then
			col=10
		end
		add_particle(arrow.x,arrow.y,arrow_speed*0.5,20,col)
	end
end

--clear enemies
function clear()
	kill(enemies)
	if boss.active_time>0 then
		boss.health*=0.5
	end
	player.clear-=1
end



--powerup creation
powers={}
function make_power()
	
	p=flr(rnd(4))
	local power={}
	power.x=rnd(30)+70
	power.y=rnd(60)+30
	power.w=8
	power.h=6
	
	if(p==0)power.type=1
	if(p==1)power.type=2
	if(p==2)power.type=3
	if(p==3)power.type=4
	
	if(power.type==1)power.sprite=9
	if(power.type==2)power.sprite=26
	if(power.type==3)power.sprite=25
	if(power.type==4)power.sprite=27
	add(powers,power)
end

function update_power(power)
	
	power.x-=0.2
	if(power.x<=-8)del(powers,power)
	
	if collision(player,power) then
	
		if power.type==1 then
			player.power=power_cherub
		end
		if power.type==2 then
			player.power=power_rose
		end
		if power.type==3 then
			if player.clear<2 then
				player.clear+=1
			end
		end
		if power.type==4 then
			player.power=power_love
		end
		sfx(3)
		del(powers,power)
	end
	
end

function draw_power(power)
	-- local cx=0
	-- local cy=0
	-- local i=frame_count%4
	-- if(i==0)cx=1
	-- if(i==1)cy=1
	-- if(i==2)cx=-1
	-- if(i==3)cy=-1
	-- for p=1,10 do pal(1,10) end
	-- spr(power.sprite,power.x+cx,power.y+cy)
	-- pal()
	spr(power.sprite,power.x,power.y)
end

function spawn_powers()
	make_power()
end
-->8
--enemies

function enemy_setup()
	enemies={}
end

function make_enemy()
--this picks if the enemy comes
--from above,the middle or below
--i apoligize in advance ;-;
	pick=flr(rnd(3))
	a=rnd(10)-16  --up
	b=rnd(126)+1  --middle
	c=rnd(10)+130 --below
	if(pick==0)final=a
	if(pick==1)final=b
	if(pick==2)final=c
	
	local e={}
	e.type = flr(rnd(3))
	e.x=(rnd(10)+135)
	e.y=final
	e.w=9
	e.h=9
	e.atk_f=0
	e.path={}
	e.health=2
	if(e.type==0)e.sprite=39
	if(e.type==1)e.sprite=41
	if(e.type==2)e.sprite=43
	
	add(enemies,e)
end

function spawn_enemies()
	local dis=min(score/2,15)
	if frame_count%(35-dis)==0 and not boss.is_spawning then
		make_enemy()
	end
	
	local boss_ss=10
	if score==100 then
		boss.is_spawning=true
	end
end

frames=5000
function update_enemy(e)
	
	e.path = get_line_pts(e,player.x+5,player.y+5)
	t=e.atk_f/frames
	e.atk_f+=1
	pos = calc_line(e.path,t)
	e.x = pos.x
	e.y = pos.y
	
	if collision(e,player) and player.invincibility<=0 then
		sfx(1)
		harm_player()
		del(enemies,e)
	end
end

function kill(es)
	foreach(es,kill_individual)
end
function kill_individual(e)
	for i=0,10 do
		add_particle(e.x,e.y,0,20,14)
	end
	del(enemies,e)
end

function draw_enemy(e)

	if e.type==0 then
		spr(e.sprite,e.x,e.y)
		e.sprite+=0.07
		
		if(e.sprite>=41)e.sprite=39
	end
	
	if e.type==1 then
		spr(e.sprite,e.x,e.y)
		e.sprite+=0.06
		
		if(e.sprite>=43)e.sprite=41
	end
	if e.type==2 then
		spr(e.sprite,e.x,e.y)
		e.sprite+=0.25
		
		if(e.sprite>=46)e.sprite=43
	end
	
end


--bezier

--makes the enemy move in a
--direct line towards the player
function get_line_pts(e,x,y)
	return {
			p0={x=e.x,y=e.y},
			p1={x=x,y=y},
	}	
end

function calc_line(path,t)
	b=(1-t)

	x=b*path.p0.x + t*path.p1.x
	y=b*path.p0.y + t*path.p1.y
	return{x=x,y=y}
end
-->8

--background
function setup_clouds()
	clouds={}
	local cloud_types={
		{s=64,w=2,h=2},
		{s=66,w=3,h=1},
		{s=69,w=2,h=2}
	}
	local cloud_count=13
	for i=0,cloud_count do
		local t=cloud_types[flr(rnd(#cloud_types))+1]
		local dx=-(1+i/cloud_count)
		add(clouds,{
			x=rnd(128),
			y=rnd(1)*(128-t.h*8),
			s=t.s,w=t.w,h=t.h,
			o=i/cloud_count,dx=dx
		})
	end
end



function draw_cloud(c)
	if(c.o<0.3 and frame_count%2==0)return
	spr(c.s,c.x,c.y,c.w,c.h)
	--rectfill(c.x,c.y,10,10,8)
	c.x+=c.dx
	if(c.x<=-c.w*8)c.x=127
end


--crimes against god
cx=0
z=0
function draw_main_cloud()
	if frame_count%2==0 then
		cx-=1
		
		circfill((3+cx)%184-28,126,28,7)
		circ((3+cx)%184-28,126,28,6)
		
		circfill((-40+cx)%184-28,126,17,7)
		circ((-40+cx)%184-28,126,17,6)
		
		circfill((-15+cx)%184-28,128,19,7)
		circ((-15+cx)%184-28,128,19,6)
		
		circfill((24+cx)%184-28,115,10,7)
		circ((24+cx)%184-28,115,10,6)
		
		circfill((6+cx)%184-28,120,13,7)
		
		circfill((35+cx)%184-28,118,7,7)
		circ((35+cx)%184-28,118,7,6)
		
		circfill((45+cx)%184-28,125,8,7)
		circ((45+cx)%184-28,125,8,6)
		
		circfill((70+cx)%184-28,128,10,7)
		circ((70+cx)%184-28,128,10,6)
		
		circfill((58+cx)%184-28,126,10,7)
		circ((58+cx)%184-28,126,10,6)
		
		circfill((53+cx)%184-28,133,11,7)
		
		circfill((65+cx)%184-28,127,5,7)
		
		circfill((30+cx)%184-28,135,17,7)
		
		circfill((90+cx)%184-28,129,14,7)
		circ((90+cx)%184-28,129,14,6)
		
		circfill((76+cx)%184-28,129,7,7)
		circ((76+cx)%184-28,129,7,6)
		
		circfill((122+cx)%184-28,120,15,7)
		circ((122+cx)%184-28,120,15,6)
		
		circfill((108+cx)%184-28,120,7,7)
		circ((108+cx)%184-28,120,7,6)
		
		circfill((105+cx)%184-28,129,13,7)
		circ((105+cx)%184-28,129,13,6)
		
		circfill((113+cx)%184-28,130,10,7)
		circ((113+cx)%184-28,130,10,6)
		
		circfill((90+cx)%184-28,129,8,7)
		
		circfill((125+cx)%184-28,125,8,7)
		circ((125+cx)%184-28,125,8,6)
		
		circfill((70+cx)%184-28,127,2,7)
		circfill((112+cx)%184-28,120,4,7)
		circfill((116+cx)%184-28,123,4,7)
		
		circfill((-40+cx)%184-28,130,12,7)
	end
	
end

-->8
--particles
p_arr={}
function add_particle(x, y, dx, lifetime, col)
	add(p_arr, {
		x=x, y=y, col=col,
		lifetime=lifetime,
		dx=dx+rnd(1)-0.5,
		dy=rnd(1)-0.5,
	})
end

function draw_particles()
	for p in all(p_arr) do
		--apply velocity
		p.x+=p.dx
		p.y+=p.dy
		--add gravity (only y component)
		p.dy+=0.01

		--lifetime:
		--  [8, inf) => show
		--  [0, 8) => blink (50% opacity)
		p.lifetime-=1
		if p.lifetime>8 or (p.lifetime<8 and p.lifetime%2==0) do
			-- pset(p.x,p.y,p.col)
			line(p.x-1,p.y-1,p.x-1,p.y,p.col)
			line(p.x,p.y,p.x,p.y+1,p.col)
			line(p.x+1,p.y-1,p.x+1,p.y,p.col)
			if(p.lifetime<=0)del(p_arr,p)
		end
	end
end
-->8
--collision

function collision(a,b)
	return not (a.x>b.x+b.w or a.y>b.y+b.h or a.x+a.w<b.x or a.y+a.h<b.y)
end
-->8
--decompression
-- global bit reader state
local base_y  -- y offset in texture
-- cache common values
local _rectfill = rectfill

local function refill()
	buffer = @(addr)
	bits_left = 8
	addr += 1
end

local function read_bit()
	if bits_left == 0 then
		refill()
	end
	local bit = buffer & 1
	buffer >>= 1
	bits_left -= 1
	return bit
end

local function read_bits(n)
	local v = 0
	for i=1,n do
			v = (v << 1) | read_bit()
	end
	return v
end

local function read_vle()
		local result = 0
		local shift = 0
		for i=1,5 do
				local v = read_bits(8)
				result |= (v & 0x7f) << shift
				if (v & 0x80) == 0 then
						return result
				end
				shift += 7
		end
		return result
end

local function read_count()
		if read_bit() == 0 then
				return 0
		end
		if read_bit() == 0 then
				return 1 + read_bits(2)
		end
		if read_bit() == 0 then
				return 4 + read_bits(4)
		end
		return read_vle()
end

local function read_run()
		if(read_bit() == 0)return 1
		if(read_bit() == 0)return 2 + read_bits(2)
		if(read_bit() == 0)return 5 + read_bits(5)
		if(read_bit() == 0)return 33 + read_bits(8)
		return read_vle()
end

-- main decompressor - everything inlined!
function dcmp(data_start_y, draw_x, draw_y)
	addr = data_start_y * 64
	buffer = 0
	bits_left = 0
	base_y = data_start_y
	
	local w = read_bits(8)
	local h = read_bits(8)
	
	local layers = read_count()
	
	for l=1,layers do
		local color = read_bits(4)
		
		local blocks = read_count()
		
		local x = 0
		local y = 0
			
		for b=1,blocks do
			local val = read_bit()
			local len = read_run()
			
			if val == 1 then
				while len > 0 do
					local space = w - x
					local n = len < space and len or space
					_rectfill(
						draw_x + x,
						draw_y + y,
						draw_x + x + n - 1,
						draw_y + y,
						color
					)
					x += n
					len -= n
					if x >= w then
						x = 0
						y += 1
					end
				end
			else
				x += len
				while x >= w do
					x -= w
					y += 1
				end
			end
		end
	end
end

-->8
--boss

function setup_boss()
	boss={
		is_spawning=false,
		active_time=0,
		pos_change_frames=0,
		health=30,
		x=64,
		y=0,
		w=32,
		h=80,
		y_target=0
	}
	boss_projectiles={}
end

function draw_boss()
	if boss.health<=0 or not boss.is_spawning or #enemies>0 then return end

	foreach(boss_projectiles,draw_bprojectile)

	palt(0,false)
	palt(11,true)
	spr(56,boss.x,boss.y,4,5)
	spr(60,boss.x,boss.y+40,4,5)
	palt()
end

function update_boss()
	if boss.health<=0 or not boss.is_spawning or #enemies>0 then return end
	boss.active_time+=1/2048

	foreach(boss_projectiles,update_bprojectile)

	--movement algo
	boss.pos_change_frames-=1
	if boss.pos_change_frames<=0 then
		boss.pos_change_frames=60
		boss.y_target=rnd(48)
	end

	local x_peek=min(boss.active_time*512,31)
	boss.x=128-x_peek-(boss.pos_change_frames/60)
	boss.y=boss.y*0.875+boss.y_target*0.125

	if frame_count%30==0 then
		local flip_h=false
		if(rnd(1)<0.5)flip_h=true
		add(boss_projectiles,{
			x=128,
			y=boss.y+rnd(80),
			flip_h=flip_h,
			flap_state=0,
			flap_timer=4,
			w=15,
			h=8
		})
	end
	
	for a in all(arrows) do
		if collision(boss,a) then
			sfx(16)
			del(arrows,a)
			boss.health-=1
		end
	end
	
	if boss.health<=0 then
		for i=0,100 do
			local c=rnd({1,5,8,15})
			add_particle(boss.x+rnd(32),boss.y+rnd(80),rnd(4)-2,30+flr(rnd(80)),c)
		end
	end
end

function update_bprojectile(p)
	p.x-=2
	p.flap_timer-=1
	if p.flap_timer<=0 then
		p.flap_state=(p.flap_state+1)%2
		p.flap_timer=4
	end

	if collision(player,p) then
		harm_player()
		del(boss_projectiles,p)
	end
end

function draw_bprojectile(p)
	spr(52+p.flap_state*2,p.x,p.y,2,1,false,p.flip_h)
end

__gfx__
000000000000000000000000000000aaaaa00000000000aaaaa40000000000aaaaa000000000dd00000000000000000000000000000000000000000000000000
00000000000000aaaa00000000000aaaaa4a000000000aaaaaa7400000000aaaaa4a0000770dd100000000000000000000000000000000000000000000000000
0070070000000aaaaaa000000000aaaaa7a400000000aaaaaaa740000000aaaaaa744000067dff00000000000000000000000000000000000000000000000000
0007700000000aaaaaa000000000aaff7fff40000000aafffff740000000aaffff7f4000006ffff000000a000033b80000000000000000000000000000000000
0007700000000aaaaaa000000000aaf7ff1f40000000aaf1ff1704000000aaf1f71f040000066700aaaaaaaa0000000000000000000000000000000000000000
00700700006777aaaa7776000000af71ff1f04000000aff1ff1704000000aff1f71f04000775ff7799999a900000000000000000000000000000000000000000
00000000077777ffff7777700000097ffffe040000000feffff7040000000feff7fe040077775f700000a0000000000000000000000000000000000000000000
000000000777677ff77677700000fff4fff00400000009fffff70400000000ff97f0040000777700000000000000000000000000000000000000000000000000
0000000077776777777677770000fff4fffff5000000fff4fff7f50000000ffff4f7f50000444000008888000000000000000000000000000000000000000000
0040000076767767767767670000007ffffff5000000fff4fff7f50000000ffff4f7f500004444000088ee80000000000aa0aa00000000000000000000000000
00d400007676776776776767000000766600040000000066660704000000006667000400004444400028e880ffffffff0a8a8a00000000000000000000000000
00d400007607767dd76770670000006766004000000000666607040000000066670004000044444000028200aaa8f8aa0a888a00000000000000000000000000
00d04000700076f00f67000700000ff67f00400000000ff6ff07400000000ff6ff704000006666600000b000ffa888af00a8a000000000000000000000000000
00d0400000000ff00ff000000000fff0f70400000000fff0ff0740000000fff0ff744000068668800000b300ffff8fff000a0000000000000000000000000000
00d0400000000000000000000000ff0ff04000000000ff0ff00740000000ff0ff04000000668888000000b004444444400000000000000000000000000000000
0d00400000000000000000000000000000000000000000000004000000000000000000000088888000000b000000000000000000000000000000000000000000
0d005000000000000000000007700000077000000000000000000000088088000220220007777600066665000100100001001000010010000000000000000000
0d00500088e0000008e00000767700007677000000000000000000008888820022222e0077777760666666501000010010000100100001000000000000000000
0d040000888eeeeeee8e000077670000776700000007000000070000888820082222e00270070060688688500100110001001100010011010000000000000000
0d040000088888888888800077677000777670000077700000777000888820882222e022700700606e86e8501111100011111001111110000000000000000000
0d40000088822222228200007776700067767000077770000077700008820088022e002277707660666065508188101081881000818810020000000000000000
0d4000008820000008200000670770006007700007767000077670000020088000e0022007777600066665001111100011111002111110000000000000000000
04000000000000000000000060000000000000007667000077670000000088000000220007070600060605000111002001110000021100100000000000000000
00000000000000000000000000000000000000006770000066770000000080000000200000000000000000000022010000120010001100000000000000000000
0000000000000000002888000067770000000000000000050000000000550000bbbbbbbbbbbbbbbbbbbbbbbb55555555bbbbb505000051105000555555105501
0000000000000000028898800677777005555550055555500000000055115505bbbbbbbbbbbbbbbbbbbbbb5505111105bbbbb500555511010555110005011050
0000000000000000288919886788788751111115511115550000555511111550bbbbbbbbbbbbbbbbbbbb551051111111bbbbbb50011110511105105555501105
0000000000000000288919886728882751111111111111500055111111111155bbbbbbbbbbbbbbbbbbb5110511101111bbbbbbb5500005511105051110550005
0000000000000000288919886772827705511111115115550511111111155550bbbbbbbbbbbbbbbbb551110511050111bbbbbbbbb55550501110511111055551
0000000000000000288898886777277700055555550550000511111555500555bbbbbbbbbbbbbbb51051110510505111bbbbbbbbbb5111050110501111111111
0000000000000000028888800677777000000000000000000055555000000000bbbbbbbbbbb505050051110511105111bbbbbbbbbbb111105011050011111111
0000000000000000002222000066660000000000000000000000000000000000bbbbbbb5505555105051110501105111bbbbbbbbbbbb11010501105500111100
0000066666666000066666666000000000000000000000000000000000000000bbbbbb51111105110551111050051110bbbbb222522522511050111055000055
0000667777776600667777776666666600666600066600000000000000000000bbbbbb51111105010550111105511105bbb25221020021122005111105555551
0000677777777600677777776777777666677660677760000000000000000000bbbbb511111110510505001111111105bb221100555501120505111105111051
0666677777777660677777767777777777777760677760666000000000000000bbbbb511221110510510550111111051bb211055bbbb50111055111105111051
6677677777777766667777777777777777777770667766666600000000000000bbbb5110211110510511055011100511bb2205bb555bb5011105111050111051
677777777777777606667777777777777777776006660667766666000000000025bb5105111110510510510500055111bb5105bb522bbb501050011055011050
677777777777777600066677777777777777766000000667777776600000000020551122111105110505110555511110bb221055122bbbb50055500550511105
677777777777777600000666666666666666660066666677777666760000000051122050111051110551110511111105bbb21111105bbbbb5500055510511105
6677777777777776000000000000000000000000677777777766777600000000220222b5010511110511110511111051bbb5122022bbbbbb5555010510510005
0677777767777776000000000000000000000000677777777666677600000000b25bbbbb510501111111105111110511bbbb22252bbbbb551110500510505555
0666777666777766000000000000000000000000067777777767677600000000bbbbbbbb511050111011105111105111bbbbbbbbbbbbb5111011055110551111
0006666606666660000000000000000000000000066677777777667600000000bbbbbbbb501105000511051111051110bbbbbbbbbbbbb5110501111105111111
0000000000000000000000000000000000000000000667777776666000000000bbbbbbbbb50110555111051110511105bbbbbbbbbbbbb5111050000051111100
0000000000000000000000000000000000000000000066666660000000000000bbbbbbbbb55001111110511105111051bbbbbbbbbbbbb5011105555550000055
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbb550011005111105110511bbbbbbbbbbbbb5500011111055555511
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbb5555500555111051105111bbbbbbbbbbbbbbb55500001105111111
66676677cccccccc000000000000000000000000000000000000000000000000bbbbbbbb551111055105111051051111bbbbbbbbb55555510555551105111110
77766767cc677ccc000000000000000000000000000000000000000000000000bbbbbbb5110111105105111051050000bbbbbbbb511111111111111105111105
7777777666677776000000000000000000000000000000000000000000000000bbbbb551105111105105111050555555b555bbb5111001111000011105111051
7777767667777777000000000000000000000000000000000000000000000000bbbb5000051111105105010555111050b5105551112550000555510051110511
7776677667777777000000000000000000000000000000000000000000000000bbbb5555511000051110505111111105b2111111122b55555110505511105111
6766776c67777776000000000000000000000000000000000000000000000000bbbbbbbb110555501111051111000011b220111105bbb5051110555511051111
c66666cc66777666000000000000000000000000000000000000000000000000bbbbbb88821111050111051110555500bbb512022bbbb5051111105510501111
cccccccccc6666cc000000000000000000000000000000000000000000000000bbbbb889882111105011050005050055bbbb2252bbbbb5050111050511051110
00000000cccccccc000000000000000000000000000000000000000000000000bbbb8891988211110511055551055111bbbbbbbbbbbbb5005000510511051105
00000000cccccccc000000000000000000000000000000000000000000000000bbbb8891988211005111051111051110bbbbbbbbbbbbbb510555110511051105
00000000cccccccc000000000000000000000000000000000000000000000000bbbb8891988210551110511110511105bbbbbbbbbbbbbb501111105111051051
00000000cccccccc000000000000000000000000000000000000000000000000bbbb8889888205111005111110511051bbbbbbbbbbbbbbb50000051110511051
00000000cccccccc000000000000000000000000000000000000000000000000bbbbb888882105110555011105110511bbbbbbbbbbbbbbbb5555550005000051
00000000cccccccc000000000000000000000000000000000000000000000000bbbbbb22221105010555501105110510bbbbbbbbbbbbbbbbbbbbb55555555511
00000000cccccccc000000000000000000000000000000000000000000000000bbbbbbbbb11105501051051105105105bbbbbbbbbbbbbbbbbbbbbbbbbbbbb500
00000000cccccccc000000000000000000000000000000000000000000000000bbbbb550111051050111050055105011bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb55
102e1f7f17ab3c96d107a970d96e147a178c96c127ae78d9af167ae78d9af167ae78d1cd1274478d8c12be7cc6f123470c4e11387cc2f92b47a5e113c72c0c90
b8764c10317b4d9197accf5332f009372ec89db168e15999b960f1599ebdae1d89abdae1d8197062e1d035d3801f804d94e141f844c3d7e9e3f4f87af42f9698
9c3d4e00f43830c357efd29300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10e65e730fff4593dd1e4d7981e4de023c9ae1627a27cc9ac137a27cc9ac137aa74d0c10723744d12723785e1172e35e12e8931d39c137c3b4e577cd709b1e8b
e1803d6d123770d2f306e085b70a6af1cb597016cf12a5e70964f12b9d780278a78468e08187842e00f0d932cfd769cf830a3081e47f083de38e4be093de34e4
be093da3ce4be093da34e4bf093da34e4be0b3da3ce43f093de34e4bf0a3da3ce4be093da34e4bf093da34e4a691f3ce4c799a34e84f489d386af09c1e0be289
c386ee883ccb46cf0b9b34e03fa81d3a616a3ccb664f0b36ab66ce0a369b2626936bb46a683e8b06a783ea3d6e683ef3869783dd1e47783dd1e47783dd1e4778
3d95e4b793de5e4b793de5e4b793de56ee483ee56ae2836f562f2936b562ea836d56cfa936956cfa936e386cfa83693862e293693c62e2836d3c6ae4b3ec3861
e0a3eb38e4b693da38e43e0b35939e46f2a31db9e8ff10a3ed708e87e10b3edbde44fcb35a38eb791ae7f0ce2037af193dd81e4b6a81e436aa9e45222383c925
44687a39f88c8d072398446c7839a464627a31b45223d34d07c79a4466723c1f6602195c1e873309cc2c07cb9184661603d17460399581a6836bc05233f3c0e4
7c491e466e78191e8123c9accd0363c1d5683599b1626a3aac84a2373c4f0741919c0466789d9e8423a918cc4223f3c1152e488c4722b8346e0b79194e239138
c254e0b33191ac8f16b493cec466833e70d2d47853c4468683889e0bf08194e10353c2744e0bf2838c88c1ee9670311932a38e012198c9644237ae9845e4d219
ac9a522309359466027a29cc04e452991cc1fc03f9cc05e87689f466837cd3cc5a23c93ee16e2591ec17f0379ac84e8b689dc046427c53cc66023a93ec166217
244e83789e52332bc17c03591ac44e8d789cc076237c63c4e0349981e85799c30233270c1bf03d71c1bd013c4f967c9138c2c147cfbc96f27bdbc965a27a1381
c07a9bcdcd4bc3d90c453d8f453d1ff0303c0c2303c0c072a3d0c2303d92d14fdbc8000000000000000000000000000000000000000000000000000000000000
10aa16f63027a793dbc9e5e4f27ab3c9ec47a33d9ec47adbc96d107ae78d96e141935e3026881e49781889e4523870c96d1293c92f177ac72c92d9470a95cc12
f96bd9dcc1cf23478ca7e00370b3c8d12b23c10e07c13c10f074895c96b7a38c456e785c346ef093894c0b0bc2f113874c12d23093483ee03691c1e497a191e4
1781b1a27253d4c2721981e476a3de30e453178c9ad117a674d9ae157aa7cd07e4ae4a181c47cd919b4e8f23271c90668e2831ac0c527247dd90f5772473d90e
d47077cd6660f6b9cc6e96b134c302313caf95b1f0cc8d2b676d6e3033c78cac97b1f024d13b47ed6c343bc7edaf343b27edaf343b27edaf343ba76d6c343be7
2d6e3c03599c3ce00e16a98c1ad3c231930dc8d32036930f168e11b191e026ac74927a38c7cae02f1ba3887ce6d236f83d456c232f8bd466c69a7cf6c236f4a8
4d23af45d8c35734f4b4dfe582000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10ce1a7f07a5b85e49f4835c35e4efc839d3be46fca39937e46eca39d3fe4ae29398bce4cfa83e9560fa81838e8ee8aabc2e893aa392e217ac19f91e18932b78
9e84e16932978de88f16b32a78be80f1ea32c78be80f1e8830e057ac78dc1570f785c32370b74974ee0af1b838c7c6e0cf17830b7cd63f00f87caf311b6f44da
c313b2f44916e62f4ac4f35431f49d8f35136f45d0f0e9a9afd70300000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00020000296700000022650000001a6400000010620000000a6100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000114701147011460104600f4600d4500a4400443000440004200e7002e7000e7002f70027000307000f70007700317001070031700107002f70010700247001070023100281003530022600226003d700
000100003a1703b200301002b1003727024100251002b600341700f000010003427002000321701b200214001040022200193001730015300133000e3000e300296003f5003b500385001f7001b7001870030200
000300002050022250205002050023250205002050024250205002050026250205002050028250205002050029250205002050020500205002050020500225001e5001b5001b500195001b5001e5001e50020500
000200000000036200000000000000000000002a20000000000000000000000313001d20000000112500e260142601827017270122700d2700b2700a2700a2700927000000092700000000000000000000000000
000d00003173034730397303b7303a73037730327302e7302b7302b7302d7303173035730397303a7303a7303a73039730347303173030730307303373035730357303573034730317302c7302a7303273035730
00010000006100062000620006200061000610006103f600006000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002a55000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00180008180202f0002f0203002013020000002f0203002018000000002f0003000013000130002f0003000018000180000000000000000000000000000000000000000000000000000000000000000000000000
001800100000000000000100700000000000000101000010000001b00000010000000000000000050100001000000000000000000000000000000000000000000000000000000000000000000000000000000000
00180010110202e00034010350100c0100c0003401035010110100000034010350100c010380103701036010110000000034000350000c0000000034000350001100031000340003500000000000000000000000
000c0020110202e00034010350100c0100c0003401035010110100000034010350100c010380103701036010110000000034000350000c0000000034000350000c0000c000380103801037010370103601036010
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002c6102962028620286202a6102d6102d6103f6000060000600000000000000000000002a650246501c650176501765000000000000000000000000000000023650286502b6502d650000000000000000
__music__
03 05434344
03 08094344


print("step")

-- change this to toggle clock input:
midi_clock_in = true 

-- change these for different notes:
map = {0,1,2,3,36,37,38,39}

ch = 0
step = 1
mute = {0,0,0,1,1,1,1}
last = {0,0,0,0,0,0,0}
note = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}}


pattern_offset = 11 --x position for the trigger grid 
track = 5 -- will be updated by the track select buttons on left
er_n = 1
er_k = 1
er_w = 1

ticks = 0

tick = function()
	step = (step % 32) + 1
	for i=1,7 do
		if last[i] == 1 then midi_note_off(map[i+1]) end
		last[i] = note[i+1][step] 
		if last[i] == 1 and mute[i] == 1  then midi_note_on(map[i+1]) end
	end
	redraw()
end

grid = function(x,y,z)
	if z==0 then return end
	-- if y==1 then
	-- if button press, which area is it in? 
	if y < 5 and x > 8  then
		ps("x %d y %d z %d",x,y,z)
		i = (x-8)+((y-1)*8)
		if note[track][i] == 1 then 
			note[track][i] = 0
			--ps("note off %d %d",track,i)
		else 
			note[track][i] = 1 
			--ps("note on %d %d",track,i)
		end
		redraw()
	elseif x == 2 then 
		track = y
		ps("track %d %d",track)
	elseif x == 1 and y > 1 then
		if mute[y-1] == 1 then mute[y-1] = 0
		else mute[y-1] = 1
		end
	elseif x > 4 and y > 5 then
		if y == 6 then er_k = x - 4 end
		if y == 7 then er_n = x - 4 end
		if y == 8 then er_w = x - 4 end
		ps("k %d n %d w %d",er_k, er_n, er_w)
		-- call the grid fill function
		pattern_generate()
		redraw()
	else
		ps("do nothing")
	end
end

redraw = function()
	grid_led_all(0)
	j = ((step - 1) % 8) + 1
	k = math.floor((step - 1) / 8) + 1
	grid_led(j+8,k,5)
	-- mute
	for n=2,8 do
		grid_led(1,n,mute[n-1]==1 and 15 or 1)
	end
	-- edit select
	for n=2,8 do
		grid_led(2,n,track==n and 15 or 1)
	end
	-- euclidean controls
	for n=5,16 do
		grid_led(n,6,(er_k == (n-4)) and 15 or 1)
		grid_led(n,7,(er_n == (n-4)) and 15 or 1)
		grid_led(n,8,(er_w == (n-4)) and 15 or 1)
	end
	-- pattern grid
	for n=1,32 do
		x = ((n - 1) % 8) + 1
		y = math.floor((n -1) / 8) + 1
		if note[track][n] == 1 then
			--ps("track %d step %d i %d", track, n, i)
			grid_led(x+8,y,step==n and 15 or 5)
		else
			grid_led(x+8,y,step==n and 15 or 1)
		end
	end
	grid_refresh()
end

midi_rx = function(d1,d2,d3,d4)
	if d1==8 and d2==240 then
		ticks = ((ticks + 1) % 6)
		if ticks == 0 and midi_clock_in then tick() end
	else
		ps("midi_rx %d %d %d %d",d1,d2,d3,d4)
	end
end

er = function(n,k,w)
   w = w or 0
   -- results array, intially all zero
   local r = {}
   for i=1,n do r[i] = false end

   if k<1 then return r end

   -- using the "bucket method"
   -- for each step in the output, add K to the bucket.
   -- if the bucket overflows, this step contains a pulse.
   local b = n
   for i=1,n do
      if b >= n then
         b = b - n
         local j = i + w
         while (j > n) do j = j - n end
         while (j < 1) do j = j + n end
         r[j] = true
      end
      b = b + k
   end
   return r
end

pattern_generate = function()
   -- generate the er pattern
   p = {}
   p = er(er_n, er_k, er_w - 1)
   pt(p)
   -- step through the pattern grid
   -- copy the corresponding step in the er pattern 
   -- continue until the pattern is full
   -- to do: adjust for pattern length

   for i=1,32 do
	if p[((i - 1) % er_n) + 1] then note[track][i] = 1 
	else note[track][i] = 0
	end
   end
end

-- begin

if not midi_clock_in then
	-- 150ms per step
	metro.new(tick, 150)
end

redraw()

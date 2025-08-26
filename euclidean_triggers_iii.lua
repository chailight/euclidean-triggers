print("step")

-- todo : fix last step of a pattern not firing 

-- change this to toggle clock input:
midi_clock_in = true 

-- change these for different notes:
--map = {0,1,2,3,36,37,38,39}
map = {0,1,2,3,4,5,6,7}

ch = 0
steps = {1,1,1,1,1,1,1,1}
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
--todo: change er variables to be arrays - one for each track
er_n = {1,1,1,1,1,1,1,1}
er_k = {1,1,1,1,1,1,1,1}
er_w = {1,1,1,1,1,1,1,1}

--clock dividers
clock_divider = {6,6,6,6,6,6,6,6}
clock_counter = {0,0,0,0,0,0,0,0}
release_counter = {0,0,0,0,0,0,0,0}
clock_map = {3,4,6,8,9,36}

--todo: add a per track length
length = {32,32, 32, 32, 32, 32, 32, 32}

-- note tracking
playing = {}

for i = 1, 8 do
    playing[i] = false
end

-- grid key held
held = 0

-- time management
ticks = 0

tick_old = function()
	for i = 1, 7 do
	    clock_counter[i+1] = clock_counter[i+1] + 1
	    if clock_counter[i+1] >= clock_divider[i+1] then
		clock_counter[i+1] = 0  -- reset
	    	steps[i+1] = (steps[i+1] % length[i+1]) + 1
	    	if last[i] == 1 then midi_note_off(map[i+1]) end
	    	last[i] = note[i+1][steps[i+1]]
	    	if last[i] == 1 and mute[i] == 1 then midi_note_on(map[i+1]) end
	    end
	end
	redraw()
end

tick = function()
    for i = 1, 7 do
        clock_counter[i+1] = clock_counter[i+1] + 1

        -- handle active note releases
        if release_counter[i+1] > 0 then
            release_counter[i+1] = release_counter[i+1] - 1
            if release_counter[i+1] == 0 and playing[i+1] then
                midi_note_off(map[i+1])
                playing[i+1] = false
            end
        end

        if clock_counter[i+1] >= clock_divider[i+1] then
            clock_counter[i+1] = 0  -- reset divider counter

            -- advance step
            steps[i+1] = (steps[i+1] % length[i+1]) + 1

            if note[i+1][steps[i+1]] == 1 and mute[i] == 1 then
                local pitch = map[i+1]

                midi_note_on(pitch)
                playing[i+1] = true

                -- schedule note off
                release_counter[i+1] = clock_divider[i+1] - 1
            end
        end
    end
    redraw()
end



grid = function(x,y,z)
	if z==0 then 
		if y < 5 and x > 8 then
			held = held - 1
			ps("release %d %d, held %d", x, y, held)
		end
		return 
	end
	-- if y==1 then
	-- if button press, which area is it in? 
	if z==1 then
		ps("press %d %d, held %d", x, y, held)
		if y < 5 and x > 8  then
			held = held + 1 
			if held == 1 then
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
			elseif held == 2 then
				if note[track][i] == 1 then
					note[track][i] = 0
				else
					note[track][i] = 1
				end
				length[track] = (x-8)+((y-1)*8)
				ps("length %d", length[track])
			end
		elseif x == 2 then 
			track = y
			midi_cc(127,track - 1) -- set the current "track" indicator
			ps("track %d",track)
		elseif x == 1 and y > 1 then
			if mute[y-1] == 1 then mute[y-1] = 0
			else mute[y-1] = 1
			end
		elseif x > 10 and y == 8 then
			clock_divider[track] = clock_map[x - 10]
    			--ps("clock divider for track %d: %d", track, clock_divider[track])
			redraw()
		elseif x > 4 and y > 5 then
			if y == 6 then er_k[track] = x - 4 end
			if y == 7 then er_n[track] = x - 4 end
			if y == 8 and x < 11 then er_w[track] = x - 4 end
			--ps("k %d n %d w %d",er_k[track], er_n[track], er_w[track])
			-- call the grid fill function
			pattern_generate()
			redraw()
		else
			ps("do nothing")
		end
	end
end

redraw = function()
	grid_led_all(0)
	j = ((steps[track]%length[track] - 1) % 8) + 1
	k = math.floor((steps[track]%length[track] - 1) / 8) + 1
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
		grid_led(n,6,(er_k[track] == (n-4)) and 15 or 1)
		grid_led(n,7,(er_n[track] == (n-4)) and 15 or 1)
	end
	for n=5,10 do
		grid_led(n,8,(er_w[track] == (n-4)) and 15 or 1)
	end
	-- clock divider 
	for n=11,16 do
		grid_led(n,8,(clock_divider[track] == clock_map[n - 10]) and 15 or 1)
	end
	-- pattern grid
	for n=1,length[track] do
		x = ((n - 1) % 8) + 1
		y = math.floor((n -1) / 8) + 1
		if note[track][n] == 1 then
			--ps("track %d step %d i %d", track, n, i)
			grid_led(x+8,y,steps[track]%(length[track]+1)==n and 15 or 5)
		else
			grid_led(x+8,y,steps[track]%(length[track]+1)==n and 15 or 1)
		end
	end
	grid_refresh()
end

midi_rx = function(d1,d2,d3,d4)
	if d1==8 and d2==240 then
		ticks = ((ticks + 1) % 1)
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
   p = er(er_n[track], er_k[track], er_w[track] - 1)
   pt(p)
   -- step through the pattern grid
   -- copy the corresponding step in the er pattern 
   -- continue until the pattern is full
   -- to do: adjust for pattern length

   for i=1,length[track] do
	if p[((i - 1) % er_n[track]) + 1] then note[track][i] = 1 
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

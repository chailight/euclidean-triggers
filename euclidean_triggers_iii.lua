print("step")


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

-- CC mode and values
cc_mode = false  -- toggle between pattern and CC mode
cc_values = {}   -- 8 tracks x 8 CCs x 127 values
cc_channels = {} -- MIDI CC numbers for each track

-- Initialize CC data structures
for track = 1, 8 do
    cc_values[track] = {}
    cc_channels[track] = {1, 2, 3, 4, 5, 6, 7, 8} -- default CC numbers
    for cc = 1, 8 do
        cc_values[track][cc] = 64 -- default to middle value
    end
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
                -- Always send CC values to shape the sound for this track
                send_cc_for_track(i+1)
                
                -- Send MIDI note
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
		if x == 1 and y == 1 then
			cc_mode = not cc_mode
			held = 0  -- Reset held variable when switching modes
			ps("mode: %s", cc_mode and "CC" or "Pattern")
			redraw()
		elseif cc_mode and y <= 4 and x > 8 then
			-- CC mode: edit CC values (rows 1-4)
			local cc_index = x - 8
			local current_value = cc_values[track][cc_index]
			
			if y == 1 then
				-- Top row: increase CC value (fine control)
				cc_values[track][cc_index] = math.min(127, current_value + 1)
			elseif y == 2 then
				-- Second row: increment CC value by 10 (coarse control)
				cc_values[track][cc_index] = math.min(127, current_value + 10)
			elseif y == 3 then
				-- Third row: decrement CC value by 10 (coarse control)
				cc_values[track][cc_index] = math.max(0, current_value - 10)
			elseif y == 4 then
				-- Bottom row: decrease CC value (fine control)
				cc_values[track][cc_index] = math.max(0, current_value - 1)
			end
			
			ps("CC %d value %d for track %d", cc_index, cc_values[track][cc_index], track)
			redraw()
		elseif not cc_mode and y < 5 and x > 8  then
			-- Pattern editing mode (only when not in CC mode)
			ps("Pattern editing: x=%d y=%d cc_mode=%s", x, y, tostring(cc_mode))
			held = held + 1 
			if held == 1 then
				-- Single button press: toggle note on/off
				i = (x-8)+((y-1)*8)
				ps("Pattern edit: track=%d step=%d current_value=%d", track, i, note[track][i])
				if note[track][i] == 1 then 
					note[track][i] = 0
					ps("note off %d %d",track,i)
				else 
					note[track][i] = 1 
					ps("note on %d %d",track,i)
				end
				redraw()
			elseif held == 2 then
				-- Two buttons held: set pattern length
				i = (x-8)+((y-1)*8)
				length[track] = i
				ps("Set pattern length to %d for track %d", length[track], track)
				redraw()
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
	
	-- Show mode indicator
	grid_led(1,1,cc_mode and 15 or 1)
	
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
	-- pattern grid or CC values
	if cc_mode then
		-- Show CC values for current track as brightness levels
		for x = 1, 8 do
			local cc_value = cc_values[track][x]
			local cc_index = x
			
			-- Calculate brightness for each row (1-4)
			for row = 1, 4 do
				local brightness = 0
				
				-- Row 1 (top): values 96-127
				-- Row 2: values 64-95  
				-- Row 3: values 32-63
				-- Row 4 (bottom): values 0-31
				
				if row == 1 then
					-- Top row: values 96-127
					if cc_value >= 96 then
						brightness = math.floor(math.min(15, (cc_value - 96) * 15 / 31))
					end
				elseif row == 2 then
					-- Second row: values 64-95
					if cc_value >= 64 and cc_value < 96 then
						brightness = math.floor(math.min(15, (cc_value - 64) * 15 / 31))
					elseif cc_value >= 96 then
						brightness = 15  -- Full brightness if value is in higher range
					end
				elseif row == 3 then
					-- Third row: values 32-63
					if cc_value >= 32 and cc_value < 64 then
						brightness = math.floor(math.min(15, (cc_value - 32) * 15 / 31))
					elseif cc_value >= 64 then
						brightness = 15  -- Full brightness if value is in higher range
					end
				elseif row == 4 then
					-- Bottom row: values 0-31
					if cc_value >= 0 and cc_value < 32 then
						brightness = math.floor(math.min(15, cc_value * 15 / 31))
					elseif cc_value >= 32 then
						brightness = 15  -- Full brightness if value is in higher range
					end
				end
				
				-- Ensure brightness doesn't go negative
				brightness = math.max(0, brightness)
				grid_led(x+8, row, brightness)
				-- ps("led %d %d %d cc %d %d", x+8, row, brightness, x, cc_value)
			end
		end
	else
		-- Show pattern grid
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
	end
	grid_refresh()
end

midi_rx = function(d1,d2,d3,d4)
	if d1==8 and d2==240 then
		ticks = ((ticks + 1) % 1)
		if ticks == 0 and midi_clock_in then tick() end
	-- else
		-- ps("midi_rx %d %d %d %d",d1,d2,d3,d4)
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



send_cc_for_track = function(track_num)
    for cc = 1, 8 do
        local cc_number = cc_channels[track_num][cc]
        local cc_value = cc_values[track_num][cc]
        midi_cc(cc_number, cc_value,track_num)
		ps("cc %d %d %d", cc_number, cc_value, track_num)
    end
end

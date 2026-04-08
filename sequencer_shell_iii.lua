-- steps = 16
-- step = 1

map = {0,1,2,3,4,5,6,7}

ch = 0
steps = {1,1,1,1,1,1,1,1}
step = 1
mute = {0,0,0,0,0,0,0,0}
last = {0,0,0,0,0,0,0,0}

-- note = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
-- {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
-- {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
-- {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
-- {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
-- {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
-- {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
-- {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}}

note = {
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {}
}


pattern_offset = 11 -- x position for the trigger grid 
track = 2 -- will be updated by the track select buttons on left
-- todo: change er variables to be arrays - one for each track
er_n = {1,1,1,1,1,1,1,1}
er_k = {1,1,1,1,1,1,1,1}
er_w = {1,1,1,1,1,1,1,1}

-- clock dividers
clock_divider = {6,6,6,6,6,6,6,6}
clock_counter = {0,0,0,0,0,0,0,0}
release_counter = {0,0,0,0,0,0,0,0}
clock_map = {3,4,6,8,9,36}

-- todo: add a per track length
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
-- cc_mode = false  -- toggle between pattern and CC mode
page = 1 -- 1 for pattern mode, 2 for CC mode, 3 for probability, 4 for presets
cc_values = {}   -- 8 tracks x 8 CCs x 127 values
cc_channels = {} -- MIDI CC numbers for each track
last_sent_cc = {} -- Track last sent CC values to avoid redundant sends

-- Initialize CC data structures
for track = 1, 8 do
    cc_values[track] = {}
    cc_channels[track] = {1, 2, 3, 4, 5, 6, 7, 8} -- default CC numbers
    last_sent_cc[track] = {}
    for cc = 1, 8 do
        cc_values[track][cc] = 0 -- default to middle value
        last_sent_cc[track][cc] = 0 -- initialize last sent values
    end
end

-- Add a global variable to track which track last sent CCs
last_cc_track = 0

function basic_tick()
    if step == 16 then
        step = 1
    else
        step = step + 1
    end
    dirty = true
end

function tick ()
    for i = 1, 8 do
        clock_counter[i] = clock_counter[i] + 1

        -- handle active note releases
        if release_counter[i] > 0 then
            release_counter[i] = release_counter[i] - 1
            if release_counter[i] == 0 and playing[i] then
                midi_note_off(map[i], 0, 1)
                playing[i] = false
            end
        end

        if clock_counter[i] >= clock_divider[i] then
            clock_counter[i] = 0  -- reset divider counter

            -- advance step
            steps[i] = (steps[i] % length[i]) + 1

            note_data = note[i] and note[i][steps[i]] 
            if note_data and note_data.on and mute[i] == 1 then 
                -- Send CC values only if they've changed (for tracks 2-4)
                -- if i >= 2 and i <= 4 then
                --     send_cc_if_changed(i)
                -- end
                
                -- Send MIDI note
                local pitch = note_data.pitch or map[i]
                local velocity = note_data.velocity or 100
                local probability = note_data.probability or 1
                midi_note_on(pitch, velocity, 1)
                playing[i] = true
                -- schedule note off
                release_counter[i] = clock_divider[i] - 1
            end
        end
    end
    dirty = true
end

function basic_redraw()
    grid_led_all(0)
    for i = 1, steps do
        if i == step + 1 then
            grid_led(i, 1, 15)
        else
            grid_led(i, 1, 0)
        end
    end
    grid_refresh()
end

function redraw()
    grid_led_all(0)
    	-- Show mode indicator
	
	-- mute
	for n=1,8 do
		grid_led(1,n,mute[n]==1 and 15 or 1)
	end
	-- edit select
	for n=1,8 do
		grid_led(2,n,track==n and 15 or 1)
	end
	-- page selectors + sample pads
	for n = 4,7 do
		grid_led(n,1, n==(page + 3) and 15 or 1)
		grid_led(n,2, 1)
		grid_led(n,3, 1)
		grid_led(n,4, 1)
	end
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
    -- trigger editing
    if page == 1 then
        j = ((steps[track]%length[track] - 1) % 8) + 1
        k = math.floor((steps[track]%length[track] - 1) / 8) + 1
        grid_led(j+8,k,5)
        for n=1,length[track] do
            x = ((n - 1) % 8) + 1
            y = math.floor((n -1) / 8) + 1
            note_data = note[track] and note[track][n] 
            if note_data and note_data.on then
                --ps("track %d step %d i %d", track, n, i)
                grid_led(x+8,y,steps[track]%(length[track]+1)==n and 15 or 5)
            else
                grid_led(x+8,y,steps[track]%(length[track]+1)==n and 15 or 1)
            end
        end
    -- note velocity and probability editing
    elseif page == 2 then
    -- CC editing
    elseif page == 3 then
        -- Show CC values for current track as brightness levels
		for x = 1, 8 do
			local cc_value = cc_values[track][x]
			local cc_index = x
			
			-- Calculate brightness for each row (1-4)
			for row = 1, 4 do
				local brightness = 0
				
			-- 	-- Row 1 (top): values 96-127
			-- 	-- Row 2: values 64-95  
			-- 	-- Row 3: values 32-63
			-- 	-- Row 4 (bottom): values 0-31
				
				if row == 1 then
			-- 		-- Top row: values 96-127
                    if cc_value and type(cc_value) == "number" and cc_value >= 96 then
					-- if cc_value >= 96 then
						--brightness = math.floor(math.min(15, (cc_value - 96) * 15 / 31))
                        local raw = linlin(cc_value, 96, 127, 0, 15)
                        brightness = clamp(math.floor(raw), 0, 15) 
				        -- ps("led %d %d %d cc %d %d", x+8, row, brightness, x, cc_value)
					end
				elseif row == 2 then
					-- Second row: values 64-95
					if cc_value >= 64 and cc_value < 96 then
						-- brightness = math.floor(math.min(15, (cc_value - 64) * 15 / 31))
                        local raw = linlin(cc_value, 64, 95, 0, 15)
                        brightness = clamp(math.floor(raw), 0, 15) 
					elseif cc_value >= 96 then
						brightness = 15  -- Full brightness if value is in higher range
					end
				elseif row == 3 then
					-- Third row: values 32-63
					if cc_value >= 32 and cc_value < 64 then
						-- brightness = math.floor(math.min(15, (cc_value - 32) * 15 / 31))
                        local raw = linlin(cc_value, 32, 63, 0, 15)
                        brightness = clamp(math.floor(raw), 0, 15) 
					elseif cc_value >= 64 then
						brightness = 15  -- Full brightness if value is in higher range
					end
				elseif row == 4 then
					-- Bottom row: values 0-31
					if cc_value >= 0 and cc_value < 32 then
						-- brightness = math.floor(math.min(15, cc_value * 15 / 31))
                        local raw = linlin(cc_value, 0, 31, 0, 15)
                        brightness = clamp(math.floor(raw), 0, 15) 
					elseif cc_value >= 32 then
						brightness = 15  -- Full brightness if value is in higher range
					end
				end
				
			-- 	-- Ensure brightness doesn't go negative
				-- brightness = math.max(0, brightness)
				grid_led(x+8, row, brightness)
				-- ps("led %d %d %d cc %d %d", x+8, row, brightness, x, cc_value)
			end
		end
    -- preset management
    elseif page == 4 then
    end

	grid_refresh()
end

function event_grid(x,y,z)
    if z==0 then 
		if y < 5 and x > 8 then
			held = held - 1
			ps("release %d %d, held %d", x, y, held)
		end
		return 
	end
    if z == 1 then
        if x == 1 then
            if mute[y] == 1 then mute[y] = 0
                else mute[y] = 1
            end
        elseif x == 2 then
            track = y
        elseif (x > 3 and x < 8) and y == 1 then
			page = x - 3
			held = 0  -- Reset held variable when switching modes
			ps("page: %d", page)
        elseif x > 4 and y > 5 then
            if y == 6 then er_k[track] = x - 4 end
            if y == 7 then er_n[track] = x - 4 end
            if y == 8 and x < 11 then er_w[track] = x - 4 end
            --ps("k %d n %d w %d",er_k[track], er_n[track], er_w[track])
            -- call the grid fill function
            pattern_generate()
        elseif x > 10 and y == 8 then
            clock_divider[track] = clock_map[x - 10]
            --ps("clock divider for track %d: %d", track, clock_divider[track])
        elseif page == 1 and y < 5 and x > 8  then
			-- Pattern editing mode 
			--ps("Pattern editing: x=%d y=%d cc_mode=%s", x, y, tostring(cc_mode))
			held = held + 1 
			if held == 1 then
				-- Single button press: toggle note on/off
				i = (x-8)+((y-1)*8)
				--ps("Pattern edit: track=%d step=%d current_value=%d", track, i, note[track][i])
				note_data = note[track] and note[track][i] 
				if note_data and note_data.on then 
					note[track][i].on = false 
					ps("note off %d %d",track,i)
				else 
					note[track][i] = { on = true }
					ps("note on %d %d",track,i)
				end
            elseif held == 2 then
				-- Two buttons held: set pattern length
				i = (x-8)+((y-1)*8)
				length[track] = i
				ps("Set pattern length to %d for track %d", length[track], track)
            end
        elseif page == 3 and y < 5 and x > 8  then
			-- CC editing mode 
            local cc_index = x - 8
			local current_value = cc_values[track][cc_index]
			
			if y == 1 then
				-- Top row: increase CC value (coarse control)
				cc_values[track][cc_index] = math.min(127, current_value + 10)
			elseif y == 2 then
				-- Second row: increment CC value by 10 (fine control)
				cc_values[track][cc_index] = math.min(127, current_value + 1)
			elseif y == 3 then
				-- Third row: decrement CC value by 10 (fine control)
				cc_values[track][cc_index] = math.max(0, current_value - 1)
			elseif y == 4 then
				-- Bottom row: decrease CC value (coarse control)
				cc_values[track][cc_index] = math.max(0, current_value - 10)
			end
        elseif x > 3 and x < 8 and y > 1 and y < 5 then
			sample_trig = ((y-2)*4)+(x-3)+35
                	midi_note_on(sample_trig,100,5)
			ps("sample_trig, %d",sample_trig)
		else
			ps("do nothing")
        end
    end
    dirty = true
end

function er(n,k,w)
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

function pattern_generate()
   -- generate the er pattern
   p = {}
   p = er(er_n[track], er_k[track], er_w[track] - 1)
   pt(p)
   -- step through the pattern grid
   -- copy the corresponding step in the er pattern 
   -- continue until the pattern is full
   -- to do: adjust for pattern length

   for i=1,length[track] do
	if p[((i - 1) % er_n[track]) + 1] then note[track][i] = { on = true }
	else note[track][i] = { on = false }
	end
   end
end

function re()
  if dirty then
    dirty = false
    redraw()
  end
end

-- begin

-- if not midi_clock_in then
	-- 150ms per step
m = metro.init(tick, .05)
m:start()
r = metro.init(re, .015)
r:start()
print("test steps")
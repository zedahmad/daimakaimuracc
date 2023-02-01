exports = {}
exports.name = "daimakaimuracc"
exports.version = "0.0.1"
exports.description = "Ghouls 'n' Ghosts Crowd Control"
exports.license = "GNU General Public License v3.0"
exports.author = { name = "Zed Ahmad" }

local daimakaimuracc = exports

function daimakaimuracc.startplugin()
	local json = require "json"

    -- Frame counter
	local frames = 0

    -- Memory manager
	local mem

    -- Init memory manager
    emu.register_start(function()
        mem = manager.machine.devices[":maincpu"].spaces["program"]
    end)

    -- Table of functions to execute as soon as game is next available
    -- Value format: {functionReference, {table, of, func, args}, delayInFrames}
    -- The function will be repeated as long as it returns true
	local doNext = {} -- Runs at next moment game is in "ready" state
	local doNextForced = {} -- Always runs on next frame

    -- Labels for console use
	local armourLabels = {}
	armourLabels[1] = "naked"
	armourLabels[2] = "steel"
	armourLabels[3] = "gold"

	local weaponLabels = {}
	weaponLabels[0] = "lance"
	weaponLabels[1] = "dagger"
	weaponLabels[2] = "firewater"
	weaponLabels[3] = "sword"
	weaponLabels[4] = "axe"
	weaponLabels[5] = "discus"
	weaponLabels[6] = "psycho cannon"

	-- Arthur status values (address = 0xFF0954)
	-- 0xB5C2 = "normal"
	-- 0xBC14 = damage init
	-- 0xBCD2 = damage (boost animation)
	-- 0xBD16 = landing from damage boost
	-- 0xBD42 = post damage invuln
	-- 0xBD56 = invincibility with timer
	-- 0xBD70 = invincibility (indefinite?)
	-- 0xD2B6 = death init (received death blow)
	-- 0xD34A = dead
	-- 0xC31E = pick up key init
	-- 0xC316 = picked up key - standing
	-- 0xC34A = win pose
	-- 0xC364 = running into door

	-- Arthur status2 values (address = 0xFF0968)
	-- 0xC920 = gold armour pickup
	-- 0xCB76 = cast magic

	--local sock = emu.file("wr")
	--sock:open("socket." .. host .. ":" .. port)

    -- Memory manager proxy functions
    -- Making these available in the global namespace makes it simple to execute them from callFuncs
    function w8 (addr, val)     mem:write_direct_u8(addr, val)      end
    function w16(addr, val)     mem:write_direct_u16(addr, val)     end
    function w32(addr, val)     mem:write_direct_u32(addr, val)     end
    function r8 (addr)          return mem:read_direct_u8(addr)     end
    function r16(addr)          return mem:read_direct_u16(addr)    end
    function r32(addr)          return mem:read_direct_u32(addr)    end

    function callFuncs(funcs, decrementTimer)
        for k, v in pairs(funcs) do
            if (v[3] == nil or v[3] == 0) then
                local loop = v[1](table.unpack(v[2]))
                if (not loop) then
                    funcs[k] = nil
                end
            elseif (decrementTimer) then
                v[3] = v[3] - 1
            end
        end
    end

	function arthurAvailable(frameStart)
		if not mem then return false end

		callFuncs(doNextForced, frameStart)

        local arthurAction = r32(0xFF0952)
        local arthurAction2 = r32(0xFF0966)
        local arthurState = r16(0xFF0956)
        local gameState = r8(0xFFD87A)

        return
            arthurAction == 0xB5C2          -- Arthur in "normal" state
            and arthurAction2 == 0xB658     -- Arthur in "normal" state
            and arthurState ~= 0x1212       -- Not currently casting magic
            and gameState == 0              -- Game is in ready state
	end

    -- doesn't cover quicksand run speed?
	function setRunSpeed(s, t) -- speed, time (in seconds)
        if not mem then return end

        if (t > 0) then
            print(string.format("Adjusting run speed by %x for %d seconds", s, t))

            -- Queue effect disable with timer
            table.insert(doNextForced, {setRunSpeed, {0, 0}, t * 60})
        else
            print("Resetting run speed")
        end

        -- Arthur steel/naked values
        w16(0xC440, 0x01B3 + s) -- Right speed
        w16(0xC514, 0xFE4D - s) -- Left speed
        w16(0xC1D2, 0x01E6 + s) -- Jump speed

        -- Arthur gold values
        w16(0xC442, 0x01B3 + s) -- Right speed
        w16(0xC516, 0xFE4D - s) -- Left speed
        w16(0xC1DA, 0x01E6 + s) -- Jump speed

        -- Old man values
        w16(0xC43E, 0x00E6 + s) -- Right speed
        w16(0xC512, 0xFF1A - s) -- Left speed
        w16(0xC1CA, 0x0100 + s) -- Jump speed

        -- Duck values
        w16(0xC444, 0x01B3 + s) -- Right speed
        w16(0xC518, 0xFE4D - s) -- Left speed
        w16(0xC1E2, 0x01E6 + s) -- Jump speed

        -- Jump falloff speeds
        local falloffSpeed = math.floor(s * (256/468))
        w16(0xBBAC, 0x0100 + falloffSpeed) -- Falloff speed right
        w16(0xBBB4, 0xFF00 - falloffSpeed) -- Falloff speed right
	end

    -- r = 1-15
	function setRank(r)
	    if not mem then return end

        print("Setting rank to " .. r)
	    w8(0xFF092B, r * 8)
	end

	function increaseRank()
	    if not mem then return end

	    local current = r8(0xFF092B) / 8

	    if (current < 15) then
	        setRank(current + 1)
        end
	end

	function decreaseRank()
	    if not mem then return end

	    local current = r8(0xFF092B) / 8

        if (current > 0) then
            setRank(current - 1)
        end
	end

	function maxRank()
	    setRank(15)
	end

	function minRank()
	    setRank(0)
    end

    function setJumpHeight(h, t)
        if not mem then return end

        if (t > 0) then
            print(string.format("Adjusting jump height by %x for %d seconds", h, t))

            -- Queue effect disable with timer
            table.insert(doNextForced, {setJumpHeight, {0, 0}, t * 60})
        else
            print("Resetting jump height")
        end

        w16(0xC1D4, 0x0420 + h) -- steel/naked
        w16(0xC1DC, 0x0420 + h) -- gold armour
        w16(0xC1CC, 0x03C0 + h) -- old man
        w16(0xC1E4, 0x0420 + h) -- duck
        w16(0x3AFDA, 0x300 + math.floor(h * 0.727)) -- Quicksand
    end

	function death()
		if not mem then return end

		print("Death.")
		w8(0xFF07A2, 0x08)
	end

	function damage(noBoost, noIframes)
	    if not mem then return end

        local message = "Dealing damage"
        if (noBoost) then
            message = message .. " no boost"
            if (noIframes) then
                w32(0xB5CC, 0xBD5C) -- After damage, skip iframes
            else
                w8(0xFF0931, 0x01)
                w32(0xB5CC, 0xBD34) -- After damage, jump to iframes func
            end
            w32(0xB5D4, 0xBCA8) -- Skip boost portion of damage function

            w16(0xBD36, 0x99)
            table.insert(doNextForced, {w32, {0xFF07A2, r32(0xFF07A2)}}) -- Queue up status reset
            table.insert(doNext, {w32, {0xB5CC, 0xBC14}, 1}) -- Queue up boost reenable
            table.insert(doNext, {w32, {0xB5D4, 0xBC14}, 1}) -- Queue up boost reenable
        end

        if (noIframes) then
            message = message .. " no iframes"
            w16(0xBD36, 0) -- Set invincibility timer to start at 0

            table.insert(doNextForced, {w16, {0xBD36, 0x72}, 4}) -- Queue up iframes reenable
        end

        print(message)

        w8(0xFF07AA, 0) -- Health = 0
        w8(0xFF07A2, 0x05) -- Damage status
        if (r8(0xFF07A3) < 80) then
            w8(0xFF07A3, 84)
        else
            w8(0xFF07A3, 44)
        end
	end

	function setWeapon(id)
		if not mem then return end

		print("Give weapon: " .. weaponLabels[id])
		w8(0xFF07C6, id) -- Set weapon value
		w32(0xFF0966, 0x614E) -- Run HUD update code
		table.insert(doNextForced, {w32, {0xFF0966, 0xB658}}) -- Queue up return to normal state
	end

	function setArmour(id)
		if not mem then return end

		print("Set armour: " .. armourLabels[id])

        -- Get current armour state
        local current = r8(0xFF07AC)
        if (current == id) then
            print("Already have that armour.")
            return
        end

		if (id == 1) then
            damage(true) -- Damage without boost, but with iframes
		elseif (id == 2) then
		    -- Steel
		    if (current == 1) then
		        -- Currently naked
		        w32(0xFF0952, 0xD260) -- Run armour pickup func
            elseif (current == 3) then
                -- Currently gold - downgrade to naked first, then upgrade to steel
                damage(true, true) -- Damage without boost and without iframes
                table.insert(doNext, {w32, {0xFF0952, 0xD260}}) -- Queue up armour upgrade from naked to steel
            end
		elseif (id == 3) then
		    -- Gold
		    w8(0xFF07AA, 1) -- Set health to 1
		    w32(0xFF0966, 0x1B714) -- Run gold armour pickup code
		end
	end

	function invincibility(n)
		if not mem then return end

		print("Invincibility for " .. tostring(n) .. " seconds")
		w8(0xFF0931, 0x01)
		w32(0xFF0952, 0xBD34)
		w16(0xBD36, n * 60) -- Set invincibility timer

		table.insert(doNext, {w16, {0xBD36, n}}) -- Queue up invincibility timer reset
	end

	function transform(s)
	    if not mem then return end

        -- Check health value
	    if (r8(0xFF07AA) == 0) then
	        oldTransform(s)
        else
            duckTransform(s)
        end
	end

	function duckTransform(s)
	    if not mem then return end

	    local message = "Transforming into duck"

	    if (s ~= nil) then
	        message = message .. string.format(" for %d seconds", s)
	        w16(0xD594, s * 60) -- Override duck transform timer
	        table.insert(doNextForced, {w16, {0xD594, 0x105}, 4}) -- Queue up timer change undo
        end

	    print(message)
	    if (r8(0xFF07AA) == 0) then
	        w8(0xFF07AA, 1) -- Set health to 1
	        table.insert(doNext, {w8, {0xFF07AA, 0}}) -- Queue health reset
        end

        w32(0xFF0952, 0xD526) -- Do duck transform
	end

	function oldUntransform(armourStatus)
	    if not mem then return end

	    local arthurAction = r32(0xFF0952)

	    if (arthurAction == 0xD0B0) then
	        -- Still old man, call again later
	        return true -- repeat
        elseif (arthurAction == 0xB5C2) then
            -- Back to normal, do untransform
            print("Resetting armour")
            table.insert(doNext, {w8, {0xFF07AA, 1}})
            table.insert(doNext, {w16, {0xFF07AB, armourStatus}})
        else
           -- Something else happened, don't reset armour
           print("Cancelling old untransform")
        end
	end

	function oldTransform(s)
	    if not mem then return end

	    local message = "Transforming into old man"

        if (s ~= nil) then
            message = message .. string.format(" for %d seconds", s)
            w16(0xD126, s * 60) -- Override old transform timer
            table.insert(doNextForced, {w16, {0xD126, 0x17D}, 4}) -- Queue up timer change undo
        end

	    print(message)
        if (r8(0xFF07AA) == 1) then
            w8(0xFF07AA, 0) -- Set health to 0

            table.insert(doNextForced, {oldUntransform, {r16(0xFF07AB)}, 4})
        end

	    w32(0xFF0952, 0xD09E) -- Do old man transform
	end

	function setTimer(m, s)
		if not mem then return end

		if (s > 59) then
			print ("setTimer received invalid input: " .. tostring(s) .. " seconds")
			return
		end

		print("Setting time to: " .. tostring(m) .. ":" .. tostring(s))
		-- Timer values stored as their decimal representations in hex, hence the nonsense below
		w8(0xFF06D2, tonumber(tostring(m), 16))
		w8(0xFF06D3, tonumber(tostring(s), 16))
	end

	-- Subtract n seconds from timer
	function subtractTime(n)
		if not mem then return end

		print("Subtracting " .. tostring(n) .. " seconds from timer")
		-- Timer values stored as their decimal representations in hex, hence the nonsense below
		local m = tonumber(string.format("%x", r8(0xFF06D2)))
		local s = tonumber(string.format("%x", r8(0xFF06D3)))

		m = math.max(0, m - math.floor(n / 60))
		s = math.max(0, s - math.fmod(n, 60))

		setTimer(m, s)
	end

	function randomEffect()
        local action = math.random()
        local rtime = math.random(6) + 1

        -- 20% chance: random weapon
        if (action < 0.20) then
            local current = r8(0xFF07C6)
            local new = nil

            repeat
                new = math.random(7) - 1
            until(current ~= new)

            setWeapon(new)
        -- 10% chance: duck transform
        elseif (action < 0.30) then
            duckTransform()
        -- 10% chance: old transform
        elseif (action < 0.40) then
            oldTransform()
        -- 10% chance: fast speed
        elseif (action < 0.50) then
            setRunSpeed(0x200, rtime)
        -- 10% chance: high jump
        elseif (action < 0.60) then
            setJumpHeight(0x200, rtime)
        -- 10% chance: random rank
        elseif (action < 0.70) then
            setRank(math.random(16) - 1)
        -- 15% chance: random armour
        elseif (action < 0.85) then
            local current = r8(0xFF07AC)
            local new = nil

            repeat
                new = math.random(3)
            until(current ~= new)

            setArmour(new)
        -- 8% chance: invincibility
        elseif (action < 0.93) then
            invincibility(rtime)
        -- 4% chance: low timer
        elseif (action < 0.97) then
            setTimer(0, 15)
        -- 3% chance: death
        else
            death()
        end
	end

    -- Perform effects
	emu.register_frame(function()
	    -- Don't perform modifications when game/arthur are in certain states to avoid glitches
	    if arthurAvailable(true) then
            frames = frames + 1

            -- 5 second timer (roughly)
            if (frames % 300 == 0) then
                randomEffect()
            end
	    end
	end)

    -- Do effect cleanup & run execute followup functions
	emu.register_frame_done(function()
		-- Don't perform modifications when game/arthur are in certain states to avoid glitches
		if arthurAvailable(false) then
            -- Perform followup functions
            callFuncs(doNext, true)
        end
	end)
end

return exports
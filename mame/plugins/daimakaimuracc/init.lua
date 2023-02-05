exports = {}
exports.name = "daimakaimuracc"
exports.version = "0.0.1"
exports.description = "Ghouls 'n' Ghosts Crowd Control"
exports.license = "GNU General Public License v3.0"
exports.author = { name = "Zed Ahmad" }

local daimakaimuracc = exports

function daimakaimuracc.startplugin()
    -- Effects config
    local chaosMode = true
    local chaosTick = 5 -- How frequently to activate random effects, in seconds
    local timerRange = 7 -- Range from 1 to x in seconds to use for effect timers
    local timerOffset = 5 -- Offset in seconds to use for random timer range (1-7 + 5 = 6-12)

    -- Communication config
    local useRemote = true
    local host = "localhost"
    local port = "3000"
    local tick = 20 -- How frequently to process requests, in frames

    -- Init values
    local hud = require "daimakaimuracc/gnghud"
    local effectActive = false
    local statusText = ""
    local statusTimer = 0
    local showTimer = false

	-- Init socket
	local sock
	if (useRemote) then
        sock = emu.file("wr")
        sock:open("socket." .. host .. ":" .. port)
    end

    -- Frame counters
	local frames = 0
	local activeFrames = 0

    -- Init Memory manager, Screen device
	local mem
	local screen
    emu.register_start(function()
        mem = manager.machine.devices[":maincpu"].spaces["program"]
        screen = manager.machine.screens[":screen"]
    end)

    -- Table of functions to execute as soon as game is next available
    -- Value format: {functionReference, {table, of, func, args}, delayInFrames}
    -- The function will be repeated as long as it returns true
	local nextFuncs = {} -- Runs at next moment game is in "ready" state
	local nextFuncsForced = {} -- Always runs on next frame

	-- Effect queue
	local effectQueue = {}

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

	-- Effect constants
	local RANDOM_WEAPON = 1
	local DOWNGRADE_ARMOUR = 2
	local UPGRADE_ARMOUR = 3
	local FAST_RUN = 4
	local SLOW_RUN = 5
	local HIGH_JUMP = 6
	local LOW_JUMP = 7
	local TRANSFORM_DUCK = 8
	local TRANSFORM_OLD = 9
	local INVINCIBILITY = 10
	local SUBTRACT_TIME = 11
	local RANDOM_RANK = 12
	local INCREASE_RANK = 13
	local DECREASE_RANK = 14
	local MAX_RANK = 15
	local DEATH = 16
	local LOW_GRAVITY = 17

    -- Memory manager proxy functions
    -- Making these available in the global namespace makes it simple to execute them from callFuncs
    function w8 (addr, val)     mem:write_direct_u8(addr, val)      end
    function w16(addr, val)     mem:write_direct_u16(addr, val)     end
    function w32(addr, val)     mem:write_direct_u32(addr, val)     end
    function r8 (addr)          return mem:read_direct_u8(addr)     end
    function r16(addr)          return mem:read_direct_u16(addr)    end
    function r32(addr)          return mem:read_direct_u32(addr)    end

    function setStatus(text, timer, st)
        effectActive = true
        statusText = text
        statusTimer = frames + timer * 60
        showTimer = st
    end

	function resetStatus()
	    effectActive = false
	    statusText = ""
	    statusTimer = 0
	    showTimer = false
	end
	
	function doNext(params)
	    table.insert(nextFuncs, params)
	end

	function doNextForced(params)
	    table.insert(nextFuncsForced, params)
	end

    function callFuncs(funcs)
        for k, v in pairs(funcs) do
            if (v[3] == nil or v[3] == 0) then
                local shouldRepeat = v[1](table.unpack(v[2]))
                if (not shouldRepeat) then
                    funcs[k] = nil
                end
            else
                v[3] = v[3] - 1
            end
        end
    end

	function arthurAvailable()
		if not mem then return false end

		callFuncs(nextFuncsForced)

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
            doNextForced({setRunSpeed, {0, 0}, t * 60})
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

	    local current = math.floor(r8(0xFF092B) / 8)

	    if (current < 15) then
	        setStatus("Rank Up: " .. current + 1, 2, false)
	        setRank(current + 1)
        end
	end

	function decreaseRank()
	    if not mem then return end

	    local current = math.floor(r8(0xFF092B) / 8)

        if (current > 0) then
            setStatus("Rank Down: " .. current - 1, 2, false)
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
            doNextForced({setJumpHeight, {0, 0}, t * 60})
        else
            print("Resetting jump height")
        end

        w16(0xC1D4, 0x0420 + h) -- steel/naked
        w16(0xC1DC, 0x0420 + h) -- gold armour
        w16(0xC1CC, 0x03C0 + h) -- old man
        w16(0xC1E4, 0x0420 + h) -- duck
        w16(0x3AFDA, 0x300 + math.floor(h * 0.727)) -- Quicksand
    end

    function setGravity(g, t)
        if not mem then return end

        if (t > 0) then
            print(string.format("Adjusting gravity by %x for %d seconds", g, t))

            doNextForced({setGravity, {0, 0}, t * 60})
        else
            print("Resetting gravity")
        end

        setJumpHeight(-0x160, t)
        w16(0xC1D6, 0xFFC8 - g) -- steel/naked
        w16(0xC1DE, 0xFFC8 - g) -- gold armour
        w16(0xC1CE, 0xFFC8 - g) -- old man
        w16(0xC1E6, 0xFFC8 - g) -- duck
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
                w8(0xFF0931, 0x01) -- Enable invincibility
                w32(0xB5CC, 0xBD34) -- After damage, jump to iframes func (runs down iframes timer & makes arthur sprite flash)
            end
            w32(0xB5D4, 0xBCA8) -- Skip boost portion of damage function

            -- Set arthur status2 correctly so he maintains his left/right orientation
            if (r8(0xFF07A3) < 80) then
                w8(0xFF07A3, 84)
            else
                w8(0xFF07A3, 44)
            end

            doNextForced({w32, {0xFF07A2, r32(0xFF07A2)}}) -- Queue up arthur status reset
            doNext({w32, {0xB5CC, 0xBC14}, 4}) -- Reset damage func modifications
            doNext({w32, {0xB5D4, 0xBC14}, 4}) -- Reset damage func modifications
        end

        if (noIframes) then
            message = message .. " no iframes"
            w16(0xBD36, 0) -- Set invincibility timer to start at 0

            doNextForced({w16, {0xBD36, 0x78}, 4}) -- Queue up iframes reenable
        end

        print(message)

        w8(0xFF07AA, 0) -- Health = 0
        w8(0xFF07A2, 0x05) -- Damage status
	end

	function randomWeapon()
	    if not mem then return end

	    local current = r8(0xFF07C6)
        local new = nil

        repeat
            new = math.random(7) - 1
        until(current ~= new)

        setWeapon(new)
	end

	function setWeapon(id)
		if not mem then return end

		print("Give weapon: " .. weaponLabels[id])
		setStatus(weaponLabels[id], 2, false)
		w8(0xFF07C6, id) -- Set weapon value
		w32(0xFF0966, 0x614E) -- Run HUD update code
		doNextForced({w32, {0xFF0966, 0xB658}}) -- Queue up return to normal state
	end

	function downgradeArmour()
        local current = r8(0xFF07AC)
        if current > 1 then setArmour(current - 1) end
	end

	function upgradeArmour()
	    if not mem then return end

        local current = r8(0xFF07AC)
        if current < 3 then setArmour(current + 1) end
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
                doNext({w32, {0xFF0952, 0xD260}}) -- Queue up armour upgrade from naked to steel
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

		doNextForced({w16, {0xBD36, 0x78}, 4}) -- Queue up invincibility timer reset
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

	function duckUntransform()
	    if not mem then return end

	    local arthurAction = r32(0xFF0952)

	    if (arthurAction == 0xD548) then
	        -- Still duck
	        return true
        else
            resetStatus()
        end
	end

	function duckTransform(s)
	    if not mem then return end

	    local message = "Transforming into duck"

	    if (s ~= nil) then
	        message = message .. string.format(" for %d seconds", s)
	        w16(0xD594, (s - 1) * 60) -- Override duck transform timer
	        doNextForced({w16, {0xD594, 0x105}, 4}) -- Queue up timer change undo
        end

	    print(message)
	    if (r8(0xFF07AA) == 0) then
	        w8(0xFF07AA, 1) -- Set health to 1
	        doNext({w8, {0xFF07AA, 0}}) -- Queue health reset
        end

        w32(0xFF0952, 0xD526) -- Do duck transform
        doNextForced({duckUntransform, {}, 4})
	end

	function oldUntransform(armourStatus)
	    if not mem then return end

	    local arthurAction = r32(0xFF0952)

	    if (arthurAction == 0xD0B0) then
	        -- Still old man, call again later
	        return true -- repeat
        elseif (armourStatus ~= nil and arthurAction == 0xB5C2) then
            -- Back to normal, do untransform
            print("Resetting armour")
            doNext({w8, {0xFF07AA, 1}})
            doNext({w16, {0xFF07AB, armourStatus}})
        else
           -- Something else happened, don't reset armour
           print("Cancelling old untransform")
        end

        resetStatus()
	end

	function oldTransform(s)
	    if not mem then return end

	    local message = "Transforming into old man"

        if (s ~= nil) then
            message = message .. string.format(" for %d seconds", s)
            w16(0xD126, (s - 1) * 60) -- Override old transform timer
            doNextForced({w16, {0xD126, 0x17D}, 4}) -- Queue up timer change undo
        end

	    print(message)
        if (r8(0xFF07AA) == 1) then
            w8(0xFF07AA, 0) -- Set health to 0

            doNextForced({oldUntransform, {r16(0xFF07AB)}, 4})
        else
            doNextForced({oldUntransform, {}, 4})
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

	function getRemoteEffects()
	    if not sock then return end

	    local effect = nil
	    repeat
	        buffer = sock:read(1024)

	        if (buffer ~= nil) then
	            for str in string.gmatch(buffer, "([0-9]+)") do
	                table.insert(effectQueue, tonumber(str))
	            end
	        end
	    until (effect == nil)
	end

	function chaos()
	    activeFrames = activeFrames + 1
        if (activeFrames % (chaosTick * 60) == 0) then
            -- Logic below is to collapse all rank related effects into 1 chance
            local ef = math.random(14)
            if (ef == 12) then
                ef = math.random(4) + 11 -- from 12 - 15
            elseif (ef == 13) then
                ef = 16
            elseif (ef == 14) then
                ef = 17
            end
            table.insert(effectQueue, ef)
        end
	end

    -- Perform effects
	emu.register_frame(function()
	    frames = frames + 1

	    if (useRemote and (frames % tick == 0)) then
	        getRemoteEffects()
        end

	    -- Don't perform modifications when game/arthur are in certain states to avoid glitches
	    if arthurAvailable(true) then
	        callFuncs(nextFuncs)

            if (not effectActive) then
                if chaosMode then chaos() end

                for k,v in pairs(effectQueue) do
                    local rtime = math.random(timerRange) + timerOffset

                    if (v == RANDOM_WEAPON) then
                        randomWeapon()
                    elseif (v == DOWNGRADE_ARMOUR) then
                        setStatus("Armour Down", 2, false)
                        downgradeArmour()
                    elseif (v == UPGRADE_ARMOUR) then
                        setStatus("Armour Up", 2, false)
                        upgradeArmour()
                    elseif (v == FAST_RUN) then
                        setStatus("Fast Run", rtime, true)
                        setRunSpeed(0x400, rtime)
                    elseif (v == SLOW_RUN) then
                        setStatus("Slow Run", rtime, true)
                        setRunSpeed(-150, rtime)
                    elseif (v == HIGH_JUMP) then
                        setStatus("High Jump", rtime, true)
                        setJumpHeight(0x200, rtime)
                    elseif (v == LOW_JUMP) then
                        setStatus("Low Jump", rtime, true)
                        setJumpHeight(-0x200, rtime)
                    elseif (v == TRANSFORM_DUCK) then
                        setStatus("Duck", rtime, true)
                        duckTransform(rtime)
                    elseif (v == TRANSFORM_OLD) then
                        setStatus("Old Man", rtime, true)
                        oldTransform(rtime)
                    elseif (v == INVINCIBILITY) then
                        setStatus("Invincible", rtime, true)
                        invincibility(rtime)
                    elseif (v == SUBTRACT_TIME) then
                        setStatus("Time Down", 2, false)
                        subtractTime(30)
                    elseif (v == RANDOM_RANK) then
                        local newRank = math.random(16) - 1
                        setStatus("Rndm Rank: " .. newRank, 2, false)
                        setRank(math.random(16) - 1)
                    elseif (v == INCREASE_RANK) then
                        increaseRank()
                    elseif (v == DECREASE_RANK) then
                        decreaseRank()
                    elseif (v == MAX_RANK) then
                        setStatus("Max Rank", 2, false)
                        maxRank()
                    elseif (v == DEATH) then
                        setStatus("Death", 2, false)
                        death()
                    elseif (v == LOW_GRAVITY) then
                        setStatus("Low Gravity", rtime, true)
                        setGravity(-35, rtime)
                    else
                        print("Unknown effect ID: " .. v)
                    end

                    effectQueue[k] = nil
                    break
                end
            end
	    end
	end)

    -- Draw HUD
	emu.register_frame_done(function()
	    if not screen then return end
	    if not hud then return end

	    if (effectActive) then
	        if (statusTimer < frames) then
                resetStatus()
            end

            local timerInSeconds = 0
            if (showTimer) then
                -- statusTimer is actually a future moment measured in frames.
                -- Calculate seconds remaining until that moment.
                timerInSeconds = math.ceil((statusTimer - frames) / 60)
            end

            hud.drawText(screen, statusText, timerInSeconds)
	    end
	end)
end

return exports
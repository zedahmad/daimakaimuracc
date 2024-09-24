exports = {}

local effects = exports

-- Memory manager
local mem

-- Memory manager proxy functions, for convenience
function w8 (addr, val)     mem:write_direct_u8(addr, val)      end
function w16(addr, val)     mem:write_direct_u16(addr, val)     end
function w32(addr, val)     mem:write_direct_u32(addr, val)     end
function r8 (addr)          return mem:read_direct_u8(addr)     end
function r16(addr)          return mem:read_direct_u16(addr)    end
function r32(addr)          return mem:read_direct_u32(addr)    end

-- Init
emu.register_start(function()
    mem = manager.machine.devices[":maincpu"].spaces["program"]
end)

-- Checks if the game is in a suitable state to apply certain effects to arthur
-- without potentially crashing the game.
function arthurAvailable()
    if not mem then return false end

    if not gameReady() then return false end

    local arthurAction = r32(0xFF0952)
    local arthurAction2 = r32(0xFF0966)
    local arthurState = r16(0xFF0956)

    return
        arthurAction == 0xB5C2          -- Arthur in "normal" state
        and arthurAction2 == 0xB658     -- Arthur in "normal" state
        and arthurState ~= 0x1212       -- Not currently casting magic
end

function shouldPause()
    local arthurAction = r32(0xFF0952)

    return
        not gameReady()
        or arthurAction > 0xC000        -- Really just guessing that this is reasonable

end

function gameReady()
    return r8(0xFFD87A) == 0            -- Game is in ready state (not map, demo, high scores, etc)
end

function setRunSpeed(speedOffset)
    if not mem then return end

    -- Arthur steel/naked values
    w16(0xC440, 0x01B3 + speedOffset) -- Right speed
    w16(0xC514, 0xFE4D - speedOffset) -- Left speed
    w16(0xC1D2, 0x01E6 + speedOffset) -- Jump speed

    -- Arthur gold values
    w16(0xC442, 0x01B3 + speedOffset) -- Right speed
    w16(0xC516, 0xFE4D - speedOffset) -- Left speed
    w16(0xC1DA, 0x01E6 + speedOffset) -- Jump speed

    -- Old man values
    w16(0xC43E, 0x00E6 + speedOffset) -- Right speed
    w16(0xC512, 0xFF1A - speedOffset) -- Left speed
    w16(0xC1CA, 0x0100 + speedOffset) -- Jump speed

    -- Duck values
    w16(0xC444, 0x01B3 + speedOffset) -- Right speed
    w16(0xC518, 0xFE4D - speedOffset) -- Left speed
    w16(0xC1E2, 0x01E6 + speedOffset) -- Jump speed

    -- Jump falloff speeds
    local falloffSpeed = math.floor(speedOffset * (256/468))
    w16(0xBBAC, 0x0100 + falloffSpeed) -- Falloff speed right
    w16(0xBBB4, 0xFF00 - falloffSpeed) -- Falloff speed left

    return function(timer)
        if timer == 0 then setRunSpeed(0) end
    end
end

function setJumpHeight(heightOffset)
    if not mem then return end

    w16(0xC1D4, 0x0420 + heightOffset) -- steel/naked
    w16(0xC1DC, 0x0420 + heightOffset) -- gold armour
    w16(0xC1CC, 0x03C0 + heightOffset) -- old man
    w16(0xC1E4, 0x0420 + heightOffset) -- duck
    w16(0x3AFDA, 0x300 + math.floor(heightOffset * 0.727)) -- Quicksand

    return function(timer)
        if timer == 0 then setJumpHeight(0) end
    end
end

function setGravity(gravityOffset)
    if not mem then return end

    w16(0xC1D6, 0xFFC8 - gravityOffset) -- steel/naked
    w16(0xC1DE, 0xFFC8 - gravityOffset) -- gold armour
    w16(0xC1CE, 0xFFC8 - gravityOffset) -- old man
    w16(0xC1E6, 0xFFC8 - gravityOffset) -- duck

    return function(timer)
        if timer == 0 then setGravity(0) end
    end
end

-- rank is a number between 0 and 15
function setRank(rank)
    if not mem then return end

    if rank > 15 then rank = 15 end
    if rank < 0 then rank = 0 end

    w8(0xFF092B, rank * 8)
end

function getRank()
    if not mem then return end

    return math.floor(r8(0xFF092B) / 8)
end

function death()
    if not mem then return end

    w8(0xFF07A2, 0x08)
end

function damage(disableBoost, disableIframes)
    if not mem then return end

    local arthurStatus = nil

    if (disableBoost) then
        if (disableIframes) then
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

        arthurStatus = r32(0xFF07A2) -- Save arthur's status to reset it later
    end

    if (disableIframes) then
        w16(0xBD36, 0) -- Set invincibility timer to start at 0
    end

    w8(0xFF07AA, 0) -- Health = 0
    w8(0xFF07A2, 0x05) -- Damage status

    -- Cleanup/monitor function
    return function(elapsed, activeElapsed)
        -- Reset Arthur's status on next frame
        if elapsed == 1 and disableBoost and arthurStatus ~= nil then
            w32(0xFF07A2, arthurStatus)
        end

        -- Slight delay before resetting invincibility timer
        if elapsed == 4 and disableIframes then
            w16(0xBD36, 0x78)
        end

        -- Wait for Arthur to become available + slight delay before resetting damage functions modifications
        if activeElapsed == 4 and disableBoost then
            w32(0xB5CC, 0xBC14)
            w32(0xB5D4, 0xBC14)
        end
    end
end

function setWeapon(id)
    w8(0xFF07C6, id) -- Set weapon value
    w32(0xFF0966, 0x614E) -- Run HUD update code

    -- Cleanup / monitor function
    return function(elapsed, activeElapsed)
        -- Return to normal state on next frame
        if elapsed == 1 then w32(0xFF0966, 0xB658) end
    end
end

function getWeapon()
    return r8(0xFF07C6)
end

function randomWeapon()
    local current = getWeapon()
    local new = nil

    repeat
        new = math.random(7) - 1
    until(current ~= new)

    return setWeapon(new)
end

function setArmour(id)
    -- Get current armour state
    local current = getArmour()
    if current == id then return end

    local damageCleanupFunc = nil

    if (id == 1) then
        damageCleanupFunc = damage(true) -- Damage without boost, but with iframes.
    elseif (id == 2) then
        -- Steel
        if (current == 1) then
            -- Currently naked
            w32(0xFF0952, 0xD260) -- Run armour pickup func
        elseif (current == 3) then
            -- Currently gold - downgrade to naked first, then upgrade to steel in cleanup func
            damageCleanupFunc = damage(true, true) -- Damage without boost and without iframes
        end
    elseif (id == 3) then
        -- Gold
        w8(0xFF07AA, 1) -- Set health to 1
        w32(0xFF0966, 0x1B714) -- Run gold armour pickup code
    end

    -- Cleanup / monitor function
    return function(elapsed, activeElapsed)
        if damageCleanupFunc ~= nil and damageCleanupFunc(elapsed, activeElapsed) then
            damageCleanupFunc = nil -- Stop running once it has completed
        end

        -- If going from gold to steel
        if id == 2 and current == 3 and activeElapsed == 1 then
            -- Queue up armour upgrade from naked to steel
            -- (because setArmour first damages you to remove gold armour)
            w32(0xFF0952, 0xD260)
        end
    end
end

function getArmour()
    return r8(0xFF07AC)
end

function invincibility(duration)
    if not mem then return end

    w8(0xFF0931, 0x01)
    w32(0xFF0952, 0xBD34)
    w16(0xBD36, duration * 60) -- Set invincibility timer

    -- Cleanup / monitor function
    return function(timer, elapsed, activeElapsed)
        -- Reset invincibility timer modifications
        if elapsed == 4 then w16(0xBD36, 0x78) end

        -- If invincibility is lost or Arthur leaves normal state, cancel effect
        if r8(0xFF0931) ~= 0x01 or shouldPause() then return true end
    end
end

function duckTransform(duration)
    if not mem then return end

    if (duration ~= nil) then
        w16(0xD594, (duration - 1) * 60 - 7) -- Override duck transform timer, this is reset in monitor function
    end

    local health = r8(0xFF07AA)
    if (health == 0) then
        w8(0xFF07AA, 1) -- Set health to 1, this is reset to 0 in monitor function
    end

    w32(0xFF0952, 0xD526) -- Do duck transform

    -- Cleanup / monitor function
    local elapsed = 0
    return function(timer, elapsed, activeElapsed)
        if (duration ~= nil and elapsed == 4) then
            w16(0xD594, 0x105) -- Reset duck transform timer modifications, after a slight delay
        end

        if activeElapsed == 1 and health == 0 then w8(0xFF07AA, 0) end

        -- If Arthur is no longer a duck, cancel effect
        if elapsed >= 4 and r32(0xFF0952) ~= 0xD548 then return true end
    end
end

function oldTransform(duration)
    if not mem then return end

    if (duration ~= nil) then
        w16(0xD126, (duration - 1) * 60 - 7) -- Override old transform timer, this is reset in monitor function
    end

    local armourStatus = nil
    if (r8(0xFF07AA) == 1) then
        w8(0xFF07AA, 0) -- Set health to 0, this is restored in monitor function

        armourStatus = r16(0xFF07AB) -- Save armour status to restore later
    end

    w32(0xFF0952, 0xD09E) -- Do old man transform

    -- Cleanup / monitor function
    return function(timer, elapsed, activeElapsed)
        if (duration ~= nil and elapsed == 4) then
            w16(0xD126, 0x17D) -- Reset old transform timer modifications, after a slight delay
        end

        if activeElapsed == 1 and armourStatus ~= nil then
            w8(0xFF07AA, 1)
            w16(0xFF07AB, armourStatus)
        end

        -- If Arthur is no longer old, cancel effect
        if elapsed >= 4 and r32(0xFF0952) ~= 0xD0B0 then return true end
    end
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

-- Public functions
effects.gameReady = gameReady
effects.arthurAvailable = arthurAvailable
effects.shouldPause = shouldPause
print(RANDOM_WEAPON)
effects.effectMap = {
    [RANDOM_WEAPON] = {
        text = "Random Weapon",
        timed = false,
        pausable = false,
        doEffect = randomWeapon
    },
    [DOWNGRADE_ARMOUR] = {
        text = "Armour Down",
        timed = false,
        pausable = false,
        doEffect = function() return setArmour(math.max(getArmour() - 1, 1)) end
    },
    [UPGRADE_ARMOUR] = {
        text = "Armour Up",
        timed = false,
        pausable = false,
        doEffect = function() return setArmour(math.min(getArmour() + 1, 3)) end
    },
    [FAST_RUN] = {
        text = "Fast Run",
        timed = true,
        pausable = true,
        doEffect = function() return setRunSpeed(0x400) end
    },
    [SLOW_RUN] = {
        text = "Slow Run",
        timed = true,
        pausable = true,
        doEffect = function() return setRunSpeed(-150) end
    },
    [HIGH_JUMP] = {
        text = "High Jump",
        timed = true,
        pausable = true,
        doEffect = function() return setJumpHeight(0x200) end
    },
    [LOW_JUMP] = {
        text = "Low Jump",
        timed = true,
        pausable = true,
        doEffect = function() return setJumpHeight(-0x200) end
    },
    [LOW_GRAVITY] = {
       text = "Low Gravity",
       timed = true,
       pausable = true,
       doEffect = function() return setGravity(-35) end
    },
    [TRANSFORM_DUCK] = {
        text = "Duck",
        timed = true,
        pausable = false,
        doEffect = duckTransform
    },
    [TRANSFORM_OLD] = {
        text = "Old Man",
        timed = true,
        pausable = false,
        doEffect = oldTransform
    },
    [INVINCIBILITY] = {
        text = "Invincible",
        timed = true,
        pausable = false,
        doEffect = invincibility
    },
    [SUBTRACT_TIME] = {
        text = "Time Down",
        timed = false,
        pausable = false,
        doEffect = function() subtractTime(30) end
    },
    [RANDOM_RANK] = {
        text = "Rndm Rank",
        timed = false,
        pausable = false,
        doEffect = function() setRank(math.random(16) - 1) end
    },
    [INCREASE_RANK] = {
        text = "Rank Up",
        timed = false,
        pausable = false,
        doEffect = function() setRank(getRank() + 1) end
    },
    [DECREASE_RANK] = {
        text = "Rank Down",
        timed = false,
        pausable = false,
        doEffect = function() setRank(getRank() - 1) end
    },
    [MAX_RANK] = {
        text = "Max Rank",
        timed = false,
        pausable = false,
        doEffect = function() setRank(15) end
    },
    [MIN_RANK] = {
        text = "Min Rank",
        timed = false,
        pausable = false,
        doEffect = function() setRank(0) end
    },
    [DEATH] = {
        text = "Death.",
        timed = false,
        pausable = false,
        doEffect = death
    },
}

return exports
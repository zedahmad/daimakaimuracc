exports = {}
exports.name = "daimakaimuracc"
exports.version = "0.0.1"
exports.description = "Ghouls 'n' Ghosts Crowd Control"
exports.license = "GNU General Public License v3.0"
exports.author = { name = "Zed Ahmad" }

-- ##################################################################################################
-- ##                                          GLOBAL CONFIG                                       ##
-- ##################################################################################################

-- CHAOS MODE SETTINGS ------------------------------------------------------------------------------
local chaosMode = false          -- Enables / disables chaos mode
local chaosTick = 25            -- How frequently to activate random effects, in seconds

-- RANDOM EFFECT TIMER SETTINGS ---------------------------------------------------------------------
local timerMin = 6              -- Minimum effect duration, in seconds
local timerMax = 12             -- Maximum effect duration, in seconds

-- NETWORK SETTINGS ---------------------------------------------------------------------------------
local useNetwork = true         -- Enables / disables remote effect requests
local host = "localhost"        -- Remote server host
local port = "3000"             -- Remote server port
local tick = 20                 -- How frequently to process requests, in frames

-- HUD SETTINGS -------------------------------------------------------------------------------------
local useHud = true             -- Enables / disables in-game HUD

local defaultDisplayTime = 2    -- Minimum duration (in seconds) to display non-timer based effects

-- Colour palette keys:
-- 1 = Light Orange
-- 2 = Dark Orange
-- 3 = Purple
-- 4 = Grey
local statusColour = 3          -- Status text colour palette
local timerColour = 1           -- Timer digits colour palette
local pausedColour = 4          -- Timer digits (paused) colour palette
local hudOutline = 0            -- HUD outline colour (ARGB format)
local hudBgColour = 0xAA000000  -- HUD background colour (ARGB format)
local goofyHud = false          -- Enables / disables goofy ahh hud

-- Position / size information:
-- Game resolution is 384x224
-- HUD is 108x13
-- Origin is top left corner
local hudPositionX = 2          -- Hud horizontal position in pixels
local hudPositionY = 210        -- Hud vertical position in pixels

-- ##################################################################################################
-- ##                                        GLOBAL CONFIG END                                     ##
-- ##################################################################################################

-- Init global state
globalState = {}
globalState.frames = 0
globalState.activeFrames = 0
globalState.ready = false
globalState.activeEffect = nil
globalState.effectQueue = {}

-- Effect constants
RANDOM_WEAPON = 1
DOWNGRADE_ARMOUR = 2
UPGRADE_ARMOUR = 3
FAST_RUN = 4
SLOW_RUN = 5
HIGH_JUMP = 6
LOW_JUMP = 7
TRANSFORM_DUCK = 8
TRANSFORM_OLD = 9
INVINCIBILITY = 10
SUBTRACT_TIME = 11
RANDOM_RANK = 12
INCREASE_RANK = 13
DECREASE_RANK = 14
MAX_RANK = 15
DEATH = 16
LOW_GRAVITY = 17
MIN_RANK = 18

local daimakaimuracc = exports

function daimakaimuracc.startplugin()
    -- Init effects engine
    local effects = require "daimakaimuracc/effects"

    -- Init HUD
    local hud
    if (useHud) then
        hud = require "daimakaimuracc/gnghud"
        hud.statusColour = statusColour
        hud.timerColour = timerColour
        hud.pausedColour = pausedColour
        hud.hudPositionX = hudPositionX
        hud.hudPositionY = hudPositionY
        hud.hudOutline = hudOutline
        hud.hudBgColour = hudBgColour
        hud.goofyHud = goofyHud
    end

	-- Init network
	local network
	if (useNetwork) then
        network = require "daimakaimuracc/network"
        network.host = host
        network.port = port
        network.tick = tick
        network.init()
    end

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

    function chaos()
        if (globalState.activeFrames % (chaosTick * 60) == 0) then
            -- Logic below is to collapse all rank related effects into 1 chance
            local ef = math.random(14)
            if (ef == 12) then
                ef = math.random(4) + 11 -- from 12 - 15
            elseif (ef == 13) then
                ef = 16
            elseif (ef == 14) then
                ef = 17
            end
            table.insert(globalState.effectQueue, ef)
        end
	end

    -- Perform effects
	emu.register_frame(function()
	    local active = effects.arthurAvailable()
	    
	    globalState.frames = globalState.frames + 1

	    if (globalState.activeEffect) then
	        local effect = globalState.activeEffect

	        effect.paused = effect.pausable and effects.shouldPause()
	        effect.elapsed = effect.elapsed + 1
	        if active then effect.activeElapsed = effect.activeElapsed + 1 end

	        if not effect.paused then effect.timer = effect.timer - 1 end

	        if effect.monitor ~= nil then
	            if effect.timed then
	                if effect.monitor(effect.timer, effect.elapsed, effect.activeElapsed) then globalState.activeEffect = nil end
                else
                    if effect.monitor(effect.elapsed, effect.activeElapsed) then globalState.activeEffect = nil end
                end
            end

            if effect ~= nil and effect.timer == 0 then globalState.activeEffect = nil end
	    else
	        if active then
	            if active then globalState.activeFrames = globalState.activeFrames + 1 end
	            if chaosMode then chaos() end

	            for k,v in pairs(globalState.effectQueue) do
                    local rtime = math.random(timerMin, timerMax)

                    local effect = effects.effectMap[v]

                    if (effect ~= nil) then
                        globalState.activeEffect = {}
                        globalState.activeEffect.timed = effect.timed
                        globalState.activeEffect.pausable = effect.pausable
                        globalState.activeEffect.paused = false
                        globalState.activeEffect.text = effect.text
                        globalState.activeEffect.elapsed = 0
                        globalState.activeEffect.activeElapsed = 0

                        if (effect.timed) then
                            globalState.activeEffect.timer = rtime * 60
                        else
                            globalState.activeEffect.timer = defaultDisplayTime * 60
                        end

                        globalState.activeEffect.monitor = effect.doEffect(rtime)
                    end

	                globalState.effectQueue[k] = nil
	                break
	            end
	        end
	    end
	end)
end

return exports
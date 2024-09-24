exports = {}

local network = exports

-- Default settings
network.host = "localhost"
network.port = "3000"
network.tick = 20

-- Variables
local sock = nil
local timer = nil

-- Init
function network.init()
    sock = emu.file("wr")
    sock:open("socket." .. network.host .. ":" .. network.port)
end

emu.register_frame(function()
    if not sock then return end
    if not globalState then return end

    if (timer ~= nil and timer > 0) then
        -- Count down
        timer = timer - 1
    else
        -- Reset timer
        timer = network.tick

        -- Check for new requests
	    buffer = sock:read(1024)
        if (buffer ~= nil) then
            for str in string.gmatch(buffer, "([0-9]+)") do
                table.insert(globalState.effectQueue, tonumber(str))
            end
        end
    end
end)

return exports
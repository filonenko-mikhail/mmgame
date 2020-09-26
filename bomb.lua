local fiber = require('fiber')
local log = require('log')

local conf = require('conf')

local function bomb_loop()
    fiber.self():name("Bomb")

    while true do
        if type(box.cfg) ~= 'function' and box.space[conf.space_name] ~= nil then
            break
        end
        fiber.sleep(0.1)
    end

    while true do
        local rc, res = pcall(function()
                for _, tuple in box.space[conf.space_name].index['type']:pairs({conf.bomb_type}) do
                    tuple = tuple:tomap({names_only=true})
                    if tuple['health'] == 0 then
                        -- BOMB triggered
                        box.space[conf.space_name]:delete(tuple['id'])

                    else
                        tuple['health'] = tuple['health'] - 1
                        tuple = box.space[conf.space_name]:frommap(tuple)
                        box.space[conf.space_name]:put(tuple)
                    end
                end
        end)
        if not rc then
            log.info(res)
        end
        fiber.sleep(1)
    end
end

if rawget(_G, 'bomb_loop') == nil then
    _G.bomb_loop = fiber.new(bomb_loop)
end

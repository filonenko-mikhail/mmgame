local fiber = require('fiber')

local conf = require('conf')

--[[
    Цикл сдувания ветром
]]
local function wind_loop()
    fiber.self():name("Wind")

    -- Подождать игровое поле
    while true do
        if type(box.cfg) ~= 'function' and box.space[conf.space_name] ~= nil
            and not box.info.ro then
            break
        end
        fiber.sleep(0.2)
    end

    while true do
        for _, player in box.space[conf.space_name].index['type']:pairs(conf.player_type) do
            player = player:tomap({names_only=true})
            if player['x'] < conf.width then
                player['x'] = player['x'] + 1
            end
            if player['y'] < conf.width then
                player['y'] = player['y'] + 1
            end
            player = box.space[conf.space_name]:frommap(player)
            if not box.info.ro then
                box.space[conf.space_name]:put(player)
            end
        end
        fiber.sleep(3)
    end
end
fiber.new(wind_loop)

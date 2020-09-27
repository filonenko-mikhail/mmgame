local log = require('log')
local fiber = require('fiber')
local uuid = require('uuid')

local conf = require('conf')
local icons = require('icons')

-- Цикл создания продуктов
math.randomseed(fiber.time())
local function food_loop()
    fiber.self():name("Food")

    while true do
        if type(box.cfg) ~= 'function' and box.space[conf.space_name] ~= nil and not box.info.ro then
            break
        end
        fiber.sleep(0.1)
    end

    while true do
        if box.space[conf.space_name].index['type']:count(conf.food_type) < 10 then
            food = {['id'] = uuid.str(),
                ['icon'] = icons.food[math.random(#icons.food)],
                ['x'] = math.random(conf.width - 1),
                ['y'] = math.random(conf.height - 1) + 1, -- first line is for info
                ['type'] = conf.food_type,
                ['health'] = math.random(conf.max_energy)}
            food = box.space[conf.space_name]:frommap(food)
            box.space[conf.space_name]:put(food)
        end
        fiber.sleep(5)
    end
end

fiber.new(food_loop)

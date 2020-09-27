local log = require('log')
local fiber = require('fiber')

local icons = require('icons')
local conf = require('conf')


--[[
    Цикл анимации подложки
]]
local delay = 3
local moon = 1
local x = 1
local function train()
    box.begin()
    local rc, err = pcall(function()
            box.space[conf.space_name]:update(conf.moon_id, {{'=', conf.icon_field, icons.moons[moon]}})
            log.info(icons.moons[moon])
            box.space[conf.space_name]:update(conf.train_id, {{'=', conf.x_field, x}})
    end)
    if not rc then
        log.info(err)
        box.rollback()
    else
        box.commit()
    end

    delay = delay - 1
    if delay > 0 then
        return
    else
        delay = 3
        moon = moon + 1
        if moon > #icons.moons then
            moon = 1
        end
        x = x + 1
        if x > conf.width then
            x = 1
        end
    end
end

local function train_loop()
    fiber.self():name("Train")

    while true do
        if type(box.cfg) ~= 'function' and box.space[conf.space_name] ~= nil and not box.info.ro then
            break
        end
        fiber.sleep(0.1)
    end

    box.space[conf.space_name]:put({conf.moon_id,
                                    icons.moons[moon],
                                    1,
                                    1,
                                    conf.moon_type,
                                    0})

    box.space[conf.space_name]:put({conf.train_id,
                                    icons.train,
                                    x,
                                    conf.height/2,
                                    conf.train_type,
                                    0})
    while true do
        train()
        fiber.sleep(1/26)
        collectgarbage('collect')
    end
end
local render_train = fiber.new(train_loop)

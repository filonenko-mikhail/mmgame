#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')

local conf = require('conf')

--[[
    Цикл сдувания ветром
]]
local function wind_loop()
    fiber.self():name("Wind")

    -- Ожидание кластера
    while true do
        if type(box.cfg) ~= 'function' and box.space[conf.space_name] ~= nil and not box.info.ro then
            break
        end
        fiber.sleep(0.2)
    end

    while true do
        box.begin()
        -- Сдунуть игроков вправо вниз
        local rc, err = pcall(function()
                for _, player in box.space[conf.space_name].index['type']:pairs(conf.player_type) do
                    local operations = {}
                    if player['x'] < conf.width then
                        table.insert(operations, {'+', conf.x_field, 1})
                    end
                    if player['y'] < conf.height then
                        table.insert(operations, {'+', conf.y_field, 1})
                    end
                    if #operations > 0 then
                        box.space[conf.space_name]:update(player['id'], operations)
                    end
                end
        end)
        if not rc then
            log.info(err)
            box.rollback()
        else
            box.commit()
        end
        fiber.sleep(3)
    end
end
fiber.new(wind_loop)

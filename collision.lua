local log = require('log')
local fiber = require('fiber')

local conf = require('conf')

--[[
    Цикл обработки столкновений
]]
local channel = fiber.channel(1000)
local function collision_loop()
    fiber.self():name("Collision")
    while true do
        local pair = channel:get()
        local obj = pair.obj
        local player = pair.player

        box.begin()
        local rc, res = pcall(function()
                -- Столкновение с поездом или огнем сбрасывает жизни
                if obj['type'] == conf.train_type or obj['type'] == conf.fire_type then
                    box.space[conf.space_name]:update(player['id'], {{'=', conf.health_field, conf.born_health}})
                    -- Столкновение с едой добавляем жизни и еда перестаэт существовать
                elseif obj['type'] == conf.food_type then
                    box.space[conf.space_name]:update(player['id'], {{'+', conf.health_field, obj['health']}})
                    box.space[conf.space_name]:delete(obj['id'])
                end
        end)
        if not rc then
            log.info(res)
            box.rollback()
        else
            box.commit()
        end
    end
end
fiber.new(collision_loop)

--[[
    Триггер проверки столкновений
]]
local function collision_trigger(old, new, sp, op)
    -- Не было движений - нечего делать
    if old ~= nil and new ~= nil then
        if old['x'] == new['x'] and old['y'] == new['y'] then
            return
        end
    end
    if new ~= nil then
        -- Двигался игрок
        if new['type'] == conf.player_type then
            for _, tuple in box.space[conf.space_name].index['pos']:pairs({new['x'], new['y']}) do
                if new['id'] ~= tuple['id'] then
                    channel:put({obj=tuple, player=new})
                end
            end
            -- Двигался поезд или двигался огонь
        elseif new['type'] == conf.train_type or new['type'] == conf.fire_type
        then
            for _, tuple in box.space[conf.space_name].index['pos']:pairs({new['x'], new['y'], conf.player_type}) do
                if new['id'] ~= tuple['id'] then
                    channel:put({obj=new, player=tuple})
                end
            end
        end
    end
end

-- Установка триггера проверки столкновений
box.ctl.on_schema_init(function()
        box.space._space:on_replace(function(old, sp)
                if not old and sp and sp.name == conf.space_name then
                    box.on_commit(function()
                            box.space[sp.name]:on_replace(collision_trigger)
                    end)
                end
        end)
end)

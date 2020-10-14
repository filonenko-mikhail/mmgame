#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')

local uuid = require('uuid')
local icons = require('icons')
local conf = require('conf')


local function make_a_bomb()
    if type(box.cfg) == 'function' or box.space[conf.space_name] == nil then
        return
    end

    local player = box.space[conf.space_name]:get(box.info.uuid)
    if player ~= nil then
        if player['health'] >= conf.born_health + conf.bomb_energy then
            box.begin()
            local rc, res = pcall(function()
                    local bomb = {
                        ['id'] = uuid.str(),
                        ['icon'] = icons.bomb,
                        ['x'] = player['x'],
                        ['y'] = player['y'],
                        ['type'] = conf.bomb_type,
                        ['health'] = conf.bomb_energy,
                    }
                    bomb, err  = box.space[conf.space_name]:frommap(bomb)

                    box.space[conf.space_name]:put(bomb)
                    box.space[conf.space_name]:update(player['id'], {{'-', conf.health_field, conf.bomb_energy}})
            end)
            if not rc then
                log.info(res)
                box.rollback()
                return
            end

            box.commit()
        end
    end
end
--[[
    Двигаем персонажа
]]
local function move_player(x, y)
    if x < -1 or x > 1 or y < -1 or y > 1 then
        return
    end
    if type(box.cfg) == 'function' or box.space[conf.space_name] == nil then
        return
    end
    -- Переместить персонажа в спейсе
    local player = box.space[conf.space_name]:get(box.info.uuid)
    if player == nil then
        player = box.tuple.new({box.info.uuid,
                                icons.players[math.random(#icons.players)],
                                conf.width,
                                conf.height,
                                conf.player_type,
                                conf.born_health})
        box.space[conf.space_name]:put(player)
        return
    end

    x, y = math.floor(x), math.floor(y)
    local operations = {}
    if x > 0 and player['x'] < conf.width then
        table.insert(operations, {'+', conf.x_field, x})
    elseif x < 0 and player['x'] > 1 then
        table.insert(operations, {'+', conf.x_field, x})
    end
    if y > 0  and player['y'] < conf.height then
        table.insert(operations, {'+', conf.y_field, y})
    elseif y < 0 and player['y'] > 2 then
        table.insert(operations, {'+', conf.y_field, y})
    end
    if #operations > 0 then
        box.space[conf.space_name]:update(player['id'], operations)
    end
end

local target = nil
local function bot_loop()
    fiber.self():name("Bot")

    while true do
        if type(box.cfg) ~= 'function' and box.space[conf.space_name] ~= nil and not box.info.ro then
            break
        end
        fiber.sleep(0.1)
    end

    while true do
        local player = box.space[conf.space_name]:get(box.info.uuid)
        if player == nil then
            move_player(0, 0)
            player = box.space[conf.space_name]:get(box.info.uuid)
        end
        if player ~= nil and player['y'] == conf.height then
            move_player(0, -1)
            player = box.space[conf.space_name]:get(box.info.uuid)
        end
        if target ~= nil then
            local x, y = 0, 0
            if target['x'] > player['x'] then
                x = 1
            elseif target['x'] < player['x'] then
                x = -1
            end
            if target['y'] > player['y'] then
                y = 1
            elseif target['y'] < player['y'] then
                y = -1
            end
            move_player(x, y)

            if math.random(5) == 1 then
                make_a_bomb()
            end
        else
            for _, t in box.space[conf.space_name].index['type']:pairs(conf.food_type) do
                if math.random(2) == 1 then
                    target = t
                    break
                end
            end
        end
        fiber.sleep(0.1 + math.random(100)/1000)
    end
end

fiber.new(bot_loop)

local function bot_trigger(old, new, sp, op)
    -- не реагировать на свои движения
    if new ~= nil and new['id'] == box.info.uuid then
        return
    end

    if old ~= nil and new == nil then
        if target ~= nil and old['id'] == target['id'] then
            target = nil
        end
    end

    if old == nil and new ~= nil and new['type'] == conf.food_type then
        local player = box.space[conf.space_name]:get(box.info.uuid)
        if player == nil then
            target = new
        elseif target == nil then
            target = new
        elseif target ~= nil and target['id'] ~= new['id'] then
            local distance = math.sqrt((player['x'] - target['x'])^2 + (player['y'] - target['y'])^2)
            local newdistance = math.sqrt((player['x'] - new['x'])^2 + (player['y'] - new['y'])^2)
            if newdistance < distance and math.random(2) == 1 then
                target = new
            end
        end
    end
end

-- установка триггера для ботана спейс
box.ctl.on_schema_init(function()
        box.space._space:on_replace(function(old, sp)
                if not old and sp and sp.name == conf.space_name then
                    box.on_commit(function()
                            box.space[conf.space_name]:on_replace(bot_trigger)
                    end)
                end
        end)
end)

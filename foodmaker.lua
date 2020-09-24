#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local uuid = require('uuid')
local uri = require('uri')

local icons = require('icons')
local conf = require('conf')

-- рендерер
local render = require('render')
-- ветер
local wind = require('wind')

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

        player = player:tomap({names_only=true})
        if obj['type'] == conf.train_type then
            player['health'] = conf.born_health
        else
            player['health'] = player['health'] + obj['health']
        end
        player = box.space[conf.space_name]:frommap(player)

        if obj['type'] ~= conf.train_type then
            box.space[conf.space_name]:delete(obj['id'])
        end
        box.space[conf.space_name]:put(player)
    end
end
fiber.new(collision_loop)

--[[
    Триггер проверки столкновений
]]
local function collision_trigger(old, new, sp, op)
    if new ~= nil then
        if new['type'] == conf.player_type then
            for _, tuple in box.space[conf.space_name].index['pos']:pairs({new['x'], new['y']}) do
                if new['id'] ~= tuple['id'] then
                    log.info({obj=tuple, player=new})
                    channel:put({obj=tuple, player=new})
                end
            end
        end
    end
end

function add_player(port)
    if box.session.peer() == nil then
        return
    end
    local replica = uri.parse(box.session.peer())
    replica.service = tostring(port)
    replica.login = conf.user
    replica.password = conf.password
    replica = uri.format(replica, {include_password=true})
    local replication = box.cfg.replication or {}
    local found = false
    for _, it in ipairs(replication) do
        if it == replica then
            found = true
            break
        end
    end
    if not found then
        table.insert(replication, replica)
        box.cfg({replication=replication})
    end
end

-- Устновки триггера проверки столкновений
box.ctl.on_schema_init(function()
        box.space._space:on_replace(function(old, sp)
                if not old and sp and sp.name == conf.space_name then
                    box.on_commit(function()
                            box.space[sp.name]:on_replace(collision_trigger)
                    end)
                end
        end)
end)

-- Создание спейс, индексов
local fio = require('fio')
fio.mktree('./storage')
box.cfg{
    listen='0.0.0.0:8081',
    replication_connect_timeout=0.1,
    replication_connect_quorum=0,
    work_dir="./storage",
    log="file:foodmaker.log",
}

box.schema.func.create('add_player', { if_not_exists=true} )
box.schema.user.grant(conf.user, 'execute', 'function', 'add_player', { if_not_exists=true })

box.schema.user.create(conf.user, { password = conf.password, if_not_exists=true })
box.schema.user.grant(conf.user, 'replication', nil, nil, { if_not_exists=true })
box.schema.user.grant('guest', 'read,write,execute', 'universe', nil, { if_not_exists=true })

box.schema.space.create(conf.space_name, { if_not_exists=true })
local format = {
    {name="id",     type="string"},
    {name="icon",   type="string"},
    {name="x",      type="unsigned"},
    {name="y",      type="unsigned"},
    {name="type",   type="string"},
    {name="health", type="unsigned"},
}
box.space[conf.space_name]:format(format, {if_not_exists=true})

box.space[conf.space_name]:create_index('id',
                                        {parts={{field="id", type="string"}},
                                         if_not_exists = true})

box.space[conf.space_name]:create_index('pos',
                                        {parts={{field="x", type="unsigned"},
                                             {field="y", type="unsigned"},
                                             {field="type", type="string"}},
                                         unique=false,
                                         if_not_exists = true})

box.space[conf.space_name]:create_index('type',
                                        {parts={{field="type", type="string"}},
                                         unique=false,
                                         if_not_exists = true})

-- Цикл создания продуктов
math.randomseed(fiber.time())
local function food_loop()
    fiber.self():name("Food")
    while true do
        if box.space[conf.space_name].index['type']:count(conf.food_type) < 10 then
            box.space[conf.space_name]:put({uuid.str(),
                                            icons.food[math.random(#icons.food)],
                                            math.random(conf.width - 1),
                                            math.random(conf.height - 1) + 1, -- first line is for info
                                            conf.food_type,
                                            math.random(conf.max_energy)})
        end
        fiber.sleep(5)
    end
end

fiber.new(food_loop)


--[[
    Цикл анимации подложки
]]
local delay = 3
local moon = 1
local x = 1
local function loader()
    box.space[conf.space_name]:put({'1',
                                    icons.moons[moon],
                                    1,
                                    1,
                                    conf.moon_type,
                                    0})

    box.space[conf.space_name]:put({'2',
                                    icons.train,
                                    x,
                                    conf.height/2,
                                    conf.train_type,
                                    0})
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

local function loader_loop()
    fiber.self():name("Loader")
    while true do
        loader()
        fiber.sleep(1/26)
        collectgarbage('collect')
    end
end
local render_loader = fiber.new(loader_loop)

#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local uuid = require('uuid')

local icons = require('icons')
local conf = require('conf')

-- рендерер
local render = require('render')

--[[
   Цикл обработки столкновений
]]
local channel = fiber.channel(1000)
local function collision_loop()
   fiber.self():name("Collision")
   while true do
      local pair = channel:get()
      local food = pair.food
      local player = pair.player

      player = player:tomap({names_only=true})
      if food['id'] == '2' then
         player['health'] = conf.born_health
      else
         player['health'] = player['health'] + food['health']
      end
      player = box.space[conf.space_name]:frommap(player)

      if food['id'] ~= '2' then
         box.space[conf.space_name]:delete(food['id'])
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
      if #new['id'] > 3 and new['food'] ~= true then
         local food = box.space[conf.space_name].index['pos']:min({new['x'], new['y'], true})
         if food ~= nil then
            if new['id'] ~= food['id'] then
               channel:put({food=food, player=new})
            end
         end
      end
   end
end

-- Устновки триггера проверки столкновений
box.ctl.on_schema_init(function()
      box.space._space:on_replace(function(old, sp)
            if not old and sp and sp.name == conf.space_name then
               box.on_commit(function()
                     box.space[conf.space_name]:on_replace(collision_trigger)
               end)
            end
      end)
end)

-- Создание спейс, индексов
local fio = require('fio')
fio.mktree('./storage')
box.cfg{
   listen='0.0.0.0:3300',
   replication=conf.replication,
   replication_connect_timeout=0.1,
   replication_connect_quorum=0,
   work_dir="./storage",
   log="file:foodmaker.log",
}

box.schema.user.create('rep', { password = 'pwd', if_not_exists=true })
box.schema.user.grant('rep', 'replication', nil, nil, { if_not_exists=true })

box.schema.space.create(conf.space_name, { if_not_exists=true })
box.space[conf.space_name]:format({
      {name="id", type="string"},
      {name="icon", type="string"},
      {name="x", type="unsigned"},
      {name="y", type="unsigned"},
      {name="food", type="boolean"},
      {name="health", type="unsigned"},
                                  }, {if_not_exists=true})

box.space[conf.space_name]:create_index('id',
                            {parts={{field="id", type="string"}},
                             if_not_exists = true})

box.space[conf.space_name]:create_index('pos',
                                        {parts={{field="x", type="unsigned"},
                                            {field="y", type="unsigned"},
                                            {field="food", type="boolean"}},
                                         unique=false,
                                         if_not_exists = true})

box.space[conf.space_name]:create_index('food',
                                        {parts={{field="food", type="boolean"}},
                                         unique=false,
                                         if_not_exists = true})

-- Цикл создания продуктов
math.randomseed(fiber.time())
local function food_loop()
   fiber.self():name("Food")
   while true do
      if box.space[conf.space_name].index['food']:count(true) < 10 then
         box.space[conf.space_name]:put({uuid.str(),
                                         icons.food[math.random(#icons.food)],
                                         math.random(conf.width - 1),
                                         math.random(conf.height - 1) + 1, -- first line is for info
                                         true,
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
                                   false,
                                   0})

   box.space[conf.space_name]:put({'2',
                                   '🚃',
                                   x,
                                   conf.height/2,
                                   true,
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

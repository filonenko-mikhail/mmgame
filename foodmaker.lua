#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local uuid = require('uuid')

local icons = require('icons')
local conf = require('conf')

local fio = require('fio')
fio.mktree('./storage')


local render = require('render')

local x_field = 3
local y_field = 4
local food_field = 5
local health_field = 6

local channel = fiber.channel(1000)
local function collision_loop()
   fiber.self():name("Collision")
   while true do
      local pair = channel:get()
      local food = pair.food
      local player = pair.player

      local newplayer = box.tuple.new({
            player[1],
            player[2],
            player[3],
            player[4],
            player[5],
            player[health_field] + food[health_field],
      })

      box.space[conf.space_name]:delete(food[1])
      box.space[conf.space_name]:put(newplayer)
   end
end

fiber.new(collision_loop)
local function collision_trigger(old, new, sp, op)
   if new ~= nil then
      if #new[1] > 3 and new[food_field] ~= true then
         local food = box.space[conf.space_name].index['pos']:min({new[x_field], new[y_field], true})
         if food ~= nil then
            if new[1] ~= food[1] and #food[1] > 3 then
               channel:put({food=food, player=new})
            end
         end
      end
   end
end

local train_channel = fiber.channel(1000)
local function train_loop()
   fiber.self():name("Train")
   while true do
      local pair = train_channel:get()
      local player = pair.player

      local newplayer = box.tuple.new({
            player[1],
            player[2],
            player[3],
            player[4],
            player[5],
            conf.born_health,
      })

      box.space[conf.space_name]:put(newplayer)
   end
end
fiber.new(train_loop)
local function train_trigger(old, new, sp, op)
   if new ~= nil then
      if #new[1] > 3 and new[food_field] ~= true then
         local train = box.space[conf.space_name].index['train']:min({'2', new[x_field], new[y_field]})
         if train ~= nil then
            log.info('!!!!@!@!@!@!@2')
            train_channel:put({player=new})
         end
      end
   end
end

box.ctl.on_schema_init(function()
      box.space._space:on_replace(function(old, sp)
            if not old and sp and sp.name == conf.space_name then
               box.on_commit(function()
                     box.space[conf.space_name]:on_replace(collision_trigger)
                     box.space[conf.space_name]:on_replace(train_trigger)
               end)
            end
      end)
end)

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

box.space[conf.space_name]:create_index('train',
                                        {parts={{field="id", type="string"},
                                            {field="x", type="unsigned"},
                                            {field="y", type="unsigned"}},
                                         unique=false,
                                         if_not_exists = true})

math.randomseed(fiber.time())
local function food_loop()
   while true do
      box.space[conf.space_name]:put({uuid.str(),
                                      icons.food[math.random(#icons.food)],
                                      math.random(conf.width - 1),
                                      math.random(conf.height - 1) + 1, -- first line is for info
                                      true,
                                      math.random(conf.max_energy)})
      fiber.sleep(5)
      break
   end
end

fiber.new(food_loop)

local width = conf.width
local height = conf.height

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
                                   height/2,
                                   false,
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
      if x > width then
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

--io.write(upperleft) io.flush()
--io.write(clrscr) io.flush()

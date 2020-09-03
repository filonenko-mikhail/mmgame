#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local uuid = require('uuid')

local icons = require('icons')
local conf = require('conf')

local fio = require('fio')
fio.mktree('./storage')


local render = require('render')

local function game_trigger(old, new, sp, op)
   -- op:  ‘INSERT’, ‘DELETE’, ‘UPDATE’, or ‘REPLACE’
   if new == nil then
      print("No new during "..op, old)
      return -- deletes are ok
   end
   if old == nil then
      print("Insert new, no old", new)
      return new  -- insert without old value: ok
   end
   print(op.." duplicate", old, new)
   if op == 'INSERT' then
      -- if replace box.tuple.new
      -- Creating new tuple will change op to REPLACE
   end
   return new -- or old
end

box.ctl.on_schema_init(function()
      box.space._space:on_replace(function(_, sp)
            if sp.name == conf.space_name then
               box.on_commit(function()
                     box.space[conf.space_name]:before_replace(game_trigger)
               end)
            end
      end)
end)

box.cfg{
   listen=3300,
   replication=conf.replication,
   replication_connect_quorum=1,
   work_dir="./storage"
}

box.schema.user.create('rep', { password = 'pwd', if_not_exists=true })
box.schema.user.grant('rep', 'replication', nil, nil, { if_not_exists=true }) -- grant replication role

box.schema.space.create(conf.space_name, { if_not_exists=true })
box.space[conf.space_name]:format({
      {name="id", type="string"},
      {name="icon", type="string"},
      {name="x", type="unsigned"},
      {name="y", type="unsigned"},
      {name="food", type="boolean"},
                                  }, {if_not_exists=true})

box.space[conf.space_name]:create_index('id',
                            {parts={{field="id", type="string"}},
                             if_not_exists = true})

math.randomseed(fiber.time())
local function food_loop()
   while true do
      box.space[conf.space_name]:put({uuid.str(),
                                      icons.food[math.random(#icons.food)],
                                      math.random(conf.width),
                                      math.random(conf.height),
                                      true,})
      fiber.sleep(5)
   end
end

fiber.new(food_loop)

local width = conf.width
local height = conf.height

local delay = 3
local moon = 1
local x = 1

local function loader()
   box.space[conf.space_name]:put({uuid.str(),
                                   icons.moons[moon],
                                   0,
                                   0,
                                   false,})

   --move_cursor(x, height/2)
   --io.write('🚃') io.flush()

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

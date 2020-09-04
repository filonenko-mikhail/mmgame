#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local socket = require('socket')

local icons = require('icons')
local conf = require('conf')

local esc = string.char(27)
local clrscr = esc .. '[J'
local upperleft = esc .. '[H'

local function move_cursor(x, y)
   x = math.floor(x)
   y = math.floor(y)
   io.write(esc .. ('[%i;%iH'):format(y, x)) io.flush()
end

local function render_trigger(old, new, sp, op)
   if old ~= nil then
      move_cursor(old['x'], old['y'])
      io.write(' ') io.flush()
   end
   if new ~= nil then
      move_cursor(new['x'], new['y'])
      io.write(new['icon']) io.flush()

      if new['id'] == box.info.uuid then
         move_cursor(5, 1)
         io.write('Player: ' .. new['icon'])
         io.write(' Health: ' .. tostring(new['health']) .. '   ') io.flush()
      end
   end
end

box.ctl.on_schema_init(function()
      box.space._space:on_replace(function(_, sp)
            if sp.name == conf.space_name then
               box.on_commit(function()
                     box.space[conf.space_name]:on_replace(render_trigger)
               end)
            end
      end)
      io.write(upperleft)io.flush()
      io.flush(clrscr)io.flush()
end)

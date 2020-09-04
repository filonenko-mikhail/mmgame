#!/usr/bin/env tarantool

local log = require('log')

local conf = require('conf')

local esc = string.char(27)

-- двигаем курсор для рисования
local function move_cursor(x, y)
   x = math.floor(x)
   y = math.floor(y)
   io.write(esc .. ('[%i;%iH'):format(y, x)) io.flush()
end

-- рендерер
-- используется io.write io.flush чтобы не было лишних переводов строк
local function render_trigger(old, new, sp, op)
   -- затереть старый кадр при условии что было смещение
   if old ~= nil then
      if (new ~= nil and
             (old['x'] ~= new['x'] or old['y'] ~= new['y']) )
         or new == nil then
            move_cursor(old['x'], old['y'])
            io.write(' ') io.flush()
      end
   end
   -- новый кадр
   if new ~= nil then
      move_cursor(new['x'], new['y'])
      io.write(new['icon']) io.flush()

      -- обновить информационную панель
      if new['id'] == box.info.uuid then
         move_cursor(5, 1)
         io.write('Player: ' .. new['icon'])
         io.write(' Health: ' .. tostring(new['health']) .. '   ') io.flush()
      end
   end
end

-- установка рендерера на спейс
box.ctl.on_schema_init(function()
      box.space._space:on_replace(function(old, sp)
            if not old and sp and sp.name == conf.space_name then
               box.on_commit(function()
                     box.space[conf.space_name]:on_replace(render_trigger)
               end)
            end
      end)
end)

#!/usr/bin/env tarantool

local log = require('log')

local conf = require('conf')

local esc = string.char(27)

-- выключаем курсор сейчас
io.write(esc .. '[?25l') io.flush()
-- включаем курсор при выходе
box.ctl.on_shutdown(function() io.write(esc .. '[?25h') io.flush()end)

-- Двигаем курсор для рисования
local function move_cursor(x, y)
    x = math.floor(x)
    y = math.floor(y)
    io.write(esc .. ('[%i;%iH'):format(y, x))
end

local esc = string.char(27)

-- Используется `io.write` `io.flush` чтобы не было лишних переводов строк
local function draw_icon(tuple)
    io.write(tuple['icon'])
end

local function render_trigger(old, new, sp, op)
    -- Обновить информационную панель, если изменилось `health`
    if new ~= nil and new['id'] == box.info.uuid then
        if old == nil or (old['health'] ~= new['health']) then
            move_cursor(5, 1)
            io.write('Player: ' .. new['icon'])
            io.write(' Health: ' .. tostring(new['health']) .. (' '):rep(20))
            io.flush()
        end
    end

    -- Если движения не было, ничего не делать
    if old ~= nil and new ~= nil then
        if old['x'] == new['x'] and old['y'] == new['y'] and old['icon'] == new['icon'] then
            return
        end
    end

    -- Затереть старую позицию при условии что было смещение
    if old ~= nil then
        move_cursor(old['x'], old['y'])
        io.write(' ')
        -- Восстанавливаем только один спрайт на старой позиции, если он был
        for _, tuple in box.space[conf.space_name].index['pos']:pairs({old['x'], old['y']}, 'EQ') do
            if tuple['id'] ~= old['id'] then
                move_cursor(old['x'], old['y'])
                draw_icon(tuple)
                break
            end
        end
    end
    -- Новый кадр
    if new ~= nil then
        move_cursor(new['x'], new['y'])
        draw_icon(new)
    end
    io.flush()
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

#!/usr/bin/env tarantool

local log = require('log')
local uri = require('uri')

local conf = require('conf')

local esc = string.char(27)
-- двигаем курсор для рисования
local function move_cursor(x, y)
    x = math.floor(x)
    y = math.floor(y)
    io.write(esc .. ('[%i;%iH'):format(y, x)) io.flush()
end
local function clrscr()
    io.write(esc .. '[2J') io.flush()
end

local function print_scores()
    move_cursor(1, 1)
    clrscr()
    print('------------ Scores ---------------')
    for _, player in box.space[conf.space_name].index['health']:pairs({conf.player_type}, 'LE') do
        if player['type'] ~= conf.player_type then
            break
        end
        print(player['icon'], player['health'])
    end
end

local function score_trigger(old, new, sp, op)
    if old ~= nil and old['type'] == conf.player_type then
        if new == nil or (new ~= nil and old['health'] ~= new['health']) then
            print_scores()
        end
    elseif new ~= nil and new['type'] == conf.player_type then
        print_scores()
    end
end

-- установка детектора на спейс
box.ctl.on_schema_init(function()
        box.space._space:on_replace(function(old, sp)
                if not old and sp and sp.name == conf.space_name then
                    box.on_commit(function()
                            box.space[conf.space_name]:on_replace(score_trigger)
                    end)
                end
        end)
end)

local fio = require('fio')
fio.mktree('./datascores')
if arg[1] == nil then
    print('Add command line arg with coordinator replication url')
    os.exit(1)
end

url = uri.parse(arg[1])
url.login = conf.user
url.password = conf.password

local server = uri.format(url, {include_password=true})
local localport = 8083
box.cfg{listen=('0.0.0.0:%u'):format(localport),
        replication={ server },
        replication_connect_timeout=60,
        replication_connect_quorum=1,
        read_only=true,
        replication_anon=true,
        work_dir="./datascores"}

print('Waiting for schema. Ctrl-C to exit')
while box.space[conf.space_name] == nil do
    fiber.sleep(0.1)
end

print_scores()

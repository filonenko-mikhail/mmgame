#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local socket = require('socket')
local ffi = require('ffi')
local uri = require('uri')
local netbox = require('net.box')
local uuid = require('uuid')

local icons = require('icons')
local conf = require('conf')

math.randomseed(fiber.time())

--[[
    Отключить обязательный <enter> в stdin
]]
local termattr = require('termattr')
old = termattr.get()
new = termattr.get()
termattr.makeraw(new)
termattr.set(new)

box.ctl.on_shutdown(function()
        termattr.set(old)
end)

local exit = function()
    termattr.set(old)
    os.exit(0)
end

-- Загружаем рендерер
local render = require('render')

local width = conf.width
local height = conf.height

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
        local r, err = box.space[conf.space_name]:update(player['id'], operations)
        log.info(err)
    end
end


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
    Цикл чтения клавиатуры
    Ctrl-C выход из цикла
]]
local buf = ffi.new('char[2]', {0, 0})
local reader = fiber.new(function()
        while true do
            local rc = socket.iowait(0, 'R', 1)
            if rc == 'R' then
                local len = ffi.C.read(0, buf, 1)
                local rc, res, err = pcall(function()
                        if len == 1 then
                            if buf[0] == 68 or buf[0] == 97 or buf[0] == 2 then -- left
                                move_player(-1, 0)
                            elseif buf[0] == 67 or buf[0] == 100 or buf[0] == 6 then -- right
                                move_player(1, 0)
                            elseif buf[0] == 66 or buf[0] == 115 or buf[0] == 14 then -- down
                                move_player(0, 1)
                            elseif buf[0] == 65 or buf[0] == 119 or buf[0] == 16 then -- up
                                move_player(0, -1)
                            elseif buf[0] == 32 then -- space
                                make_a_bomb()
                            elseif buf[0] == 3 then -- Ctrl-C
                                exit()
                            end
                        end
                end)
                if not rc then
                    log.info(res)
                end
            end
        end
end)
reader:name('Reader')

if arg[1] == nil then
    print('Add command line arg with coordinator replication url')
    exit(1)
end

url = uri.parse(arg[1])
url.login = conf.user
url.password = conf.password
local remoteserver = uri.format(url, {include_password=true})

local localserver = arg[2] or "0.0.0.0:8082"

local wrkdir = arg[3] or './playerstorage'
local fio = require('fio')
fio.mktree(wrkdir)

box.cfg{listen=localserver,
        replication={ remoteserver },
        replication_connect_timeout=60,
        replication_connect_quorum=1,
        work_dir=wrkdir,
        log="file:player.log"}

--[[
    Джем пока схема приедет по репликации
]]
print('Waiting for schema. Ctrl-C to exit')
while box.space[conf.space_name] == nil do
    fiber.sleep(0.1)
end

--[[
    Регистрируемся на сервере
]]
_G.conn = netbox.connect(remoteserver, {wait_connected=false,
                                  reconnect_after=2})
conn:on_connect(function(client)
        fiber.new(function ()
                local rc, res = pcall(client.call, client, 'add_player', {localserver})
                if not rc then
                    log.info(res)
                end
        end)
end)

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
    Настройка stdin буфера чтения
]]
if ffi.os == 'Linux' then
    ffi.cdef[[
typedef unsigned char  cc_t;
typedef unsigned int  speed_t;
typedef unsigned int  tcflag_t;

struct termios {
  tcflag_t c_iflag;
  tcflag_t c_oflag;
  tcflag_t c_cflag;
  tcflag_t c_lflag;
  cc_t c_cc[32];
  speed_t c_ispeed;
  speed_t c_ospeed;
};
int tcgetattr(int fildes, struct termios *termios_p);
int tcsetattr(int fildes, int optional_actions,
       const struct termios *termios_p);
void cfmakeraw(struct termios *termios_p);
]]
else
    ffi.cdef[[
typedef unsigned long   tcflag_t;
typedef unsigned char   cc_t;
typedef unsigned long   speed_t;

struct termios {
  tcflag_t        c_iflag;        /* input flags */
  tcflag_t        c_oflag;        /* output flags */
  tcflag_t        c_cflag;        /* control flags */
  tcflag_t        c_lflag;        /* local flags */
  cc_t            c_cc[20];     /* control chars */
  speed_t         c_ispeed;       /* input speed */
  speed_t         c_ospeed;       /* output speed */
};
int tcgetattr(int fildes, struct termios *termios_p);
int tcsetattr(int fildes, int optional_actions,
       const struct termios *termios_p);
void cfmakeraw(struct termios *termios_p);
]]
end

--[[
    Отключить обязательный <enter> в stdin
]]
local old = ffi.new('struct termios[1]', {{0}})
local new = ffi.new('struct termios[1]', {{0}})
if (ffi.C.tcgetattr(0, old) < 0) then
    error("tcgetattr old settings")
end
box.ctl.on_shutdown(function()
        if( ffi.C.tcsetattr( 0 , 0 , old ) < 0 ) then
            error( "tcssetattr makeraw new" );
        end
end)
if (ffi.C.tcgetattr(0, new) < 0 ) then
    error("tcgetaart new settings")
end
ffi.C.cfmakeraw(new);
if (ffi.C.tcsetattr(0, 0, new) < 0) then
    error("tcssetattr makeraw new")
end

local exit = function()
    if( ffi.C.tcsetattr( 0 , 0 , old ) < 0 ) then
        error( "tcssetattr makeraw new" );
    end
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
    else
        player = player:tomap({names_only=true})

        local newx, newy = player['x'] + x, player['y'] + y
        newx, newy = math.floor(newx), math.floor(newy)
        if newx > width then
            newx = width
        end
        if newy > height then
            newy = height
        end
        if newx < 1 then
            newx = 1
        end
        if newy < 2 then
            newy = 2
        end
        player['x'], player['y'] = newx, newy

        player = box.space[conf.space_name]:frommap(player)
    end
    box.space[conf.space_name]:put(player)
end


local function make_a_bomb()
    if type(box.cfg) == 'function' or box.space[conf.space_name] == nil then
        return
    end

    local player = box.space[conf.space_name]:get(box.info.uuid)
    if player ~= nil then
        player = player:tomap({names_only=true})
        if player['health'] >= conf.born_health + conf.bomb_energy then
            --player['health'] = player['health'] - conf.bomb_energy
            player = box.space[conf.space_name]:frommap(player)

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
                    box.space[conf.space_name]:update(player['id'], {{'-', 6, conf.bomb_energy}})
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
                        log.info(buf[0])
                        log.info(buf[1])
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
                            elseif buf[0] == 27 then --esc
                                --exit()
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
    os.exit(1)
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
                log.info(rc)
                log.info(res)
                if not rc then
                    log.info(res)
                end
        end)
end)

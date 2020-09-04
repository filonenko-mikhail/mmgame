#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local socket = require('socket')
local ffi = require('ffi')

local icons = require('icons')
local conf = require('conf')


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

local quorum = math.floor(#conf.replication/2)

local old = ffi.new('struct termios[1]', {{0}})
local new = ffi.new('struct termios[1]', {{0}})
if (ffi.C.tcgetattr(0, old) < 0) then
   error("tcgetattr old settings")
end
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

local render = require('render')

local width = conf.width
local height = conf.height

local player_index = 1
local player_x = width
local player_y = height

local move_player = function(x, y)
   if x > width then
      x = width
   end
   if y > height then
      y = height
   end
   if x < 1 then
      x = 1
   end
   if y < 2 then
      y = 2
   end

   x = math.floor(x)
   y = math.floor(y)
   player_x = x
   player_y = y

   if type(box.cfg) ~= 'function' then
      if box.space[conf.space_name] ~= nil then
         local player = box.space[conf.space_name]:get(box.info.uuid)
         if player == nil then
            player = box.tuple.new({box.info.uuid,
                                    icons.players[math.random(#icons.players)],
                                    player_x,
                                    player_y,
                                    false,
                                    conf.born_health})
         else
            player = player:tomap({names_only=true})
            player['x'] = player_x
            player['y'] = player_y
            player = box.space[conf.space_name]:frommap(player)
         end
         box.space[conf.space_name]:put(player)
      end
   end
end

local buf = ffi.new('char[2]', {0, 0})
local reader = fiber.new(function()
      while true do
         local rc = socket.iowait(0, 'R', 1)
         if rc == 'R' then
            local len = ffi.C.read(0, buf, 1)
            local rc, res, err = pcall(function()
            if len == 1 then
               if buf[0] == 68 or buf[0] == 97 then -- left
                  move_player(player_x - 1, player_y)
               elseif buf[0] == 67 or buf[0] == 100 then -- right
                  move_player(player_x + 1, player_y)
               elseif buf[0] == 66 or buf[0] == 115 then -- down
                  move_player(player_x, player_y + 1)
               elseif buf[0] == 65 or buf[0] == 119 then -- up
                  move_player(player_x, player_y - 1)
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

local fio = require('fio')
fio.mktree('./dataplayer')
box.cfg{listen='0.0.0.0:3301',
        replication=conf.replication,
        replication_connect_timeout=0.1,
        replication_connect_quorum=0,
        work_dir="./dataplayer",
        log="file:player.log"}

local player = box.space[conf.space_name]:get(box.info.uuid)
if player ~= nil then
   player = player:tomap({names_only=true})
   player_x = player['x']
   player_y = player['y']
end

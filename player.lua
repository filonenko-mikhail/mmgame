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
--if (ffi.C.tcsetattr(0, 0, new) < 0) then
--   error("tcssetattr makeraw new")
--end

local exit = function()
--   if( ffi.C.tcsetattr( 0 , 0 , old ) < 0 ) then
--      error( "tcssetattr makeraw new" );
--   end
   os.exit(0)
end

local render = require('render')

local width = conf.width
local height = conf.height

local person_index = 1
local person_x = width
local person_y = height

local move_person = function(x, y)
   if x > width then
      x = width
   end
   if y > height then
      y = height
   end
   if x < 0 then
      x = 0
   end
   if y < 0 then
      y = 0
   end

   x = math.floor(x)
   y = math.floor(y)
   person_x = x
   person_y = y

   if type(box.cfg) ~= 'function' then
      if box.space[conf.space_name] ~= nil then
         box.space[conf.space_name]:put({box.info.uuid,
                                         icons.food[math.random(#icons.food)],
                                         person_x,
                                         person_y,
                                         false,})
         print('MOOOVE')
      end
   end
end

local buf = ffi.new('char[2]', {0, 0})
local reader = fiber.new(function()
      while true do
         local rc = socket.iowait(0, 'R', 1)
         if rc == 'R' then
            local len = ffi.C.read(0, buf, 1)
            if len == 1 then
               if buf[0] == 68 or buf[0] == 97 then -- left
                  move_person(person_x - 1, person_y)
               elseif buf[0] == 67 or buf[0] == 100 then -- right
                  move_person(person_x + 1, person_y)
               elseif buf[0] == 66 or buf[0] == 115 then -- down
                  move_person(person_x, person_y + 1)
               elseif buf[0] == 65 or buf[0] == 119 then -- up
                  move_person(person_x, person_y - 1)
               elseif buf[0] == 3 then -- Ctrl-C
                  exit()
               end
            end
         end

      end
end)
reader:name('Reader')

local fio = require('fio')
fio.mktree('./player')
box.cfg{listen='0.0.0.0:3301',
        replication=conf.replication,
        replication_connect_quorum=1,
        work_dir="./player"}

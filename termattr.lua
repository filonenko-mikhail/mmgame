local ffi = require('ffi')
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

local function get()
    local res = ffi.new('struct termios[2]', {{0}})
    if (ffi.C.tcgetattr(0, res) < 0) then
        error("tcgetattr old settings")
    end
    return res
end
local function makeraw(attr)
    ffi.C.cfmakeraw(new);
end
local function set(attr)
    if (ffi.C.tcsetattr(0, 0, attr) < 0) then
        error("tcssetattr makeraw new")
    end
end

return {
    get=get,
    makeraw=makeraw,
    set=set,
}

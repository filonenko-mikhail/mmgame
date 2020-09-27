local esc = string.char(27)

local players = {
    esc .. '[1;30;47m' .. 'K' .. esc .. '[0m',
    esc .. '[1;30;47m' .. 'H' .. esc .. '[0m',
    esc .. '[1;30;47m' .. 'E' .. esc .. '[0m',
    esc .. '[1;30;47m' .. 'J' .. esc .. '[0m',
    esc .. '[1;30;47m' .. 'B' .. esc .. '[0m',
    esc .. '[1;30;47m' .. 'X' .. esc .. '[0m',
    esc .. '[1;30;47m' .. 'Y' .. esc .. '[0m',
}

local moons = {
    esc .. '[1;30;43m' ..  '|' .. esc .. '[0m',
    esc .. '[1;30;43m' ..  '/' .. esc .. '[0m',
    esc .. '[1;30;43m' ..  '-' .. esc .. '[0m',
    esc .. '[1;30;43m' ..  '\\' .. esc .. '[0m',
}

local food = {
    esc .. '[1;37;44m' .. '#' .. esc .. '[0m',
    esc .. '[1;37;44m' .. '$' .. esc .. '[0m',
    esc .. '[1;37;44m' .. '%' .. esc .. '[0m',
    esc .. '[1;37;44m' .. '&' .. esc .. '[0m',
}


local train = esc .. '[1;37;42m' .. 'W' .. esc .. '[0m'

local bomb = esc .. '[5;30;41m' ..  '@' .. esc .. '[0m'

local fire = esc .. '[5;38;5;0;48;5;202m' .. ' ' .. esc .. '[0m'

return {
    players = players,
    moons = moons,
    food = food,
    train = train,
    bomb = bomb,
    fire = fire,
}

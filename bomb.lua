local log = require('log')

local fiber = require('fiber')
local uuid = require('uuid')

local icons = require('icons')
local conf = require('conf')

local function bomb_loop()
    fiber.self():name("Bomb")

    while true do
        if type(box.cfg) ~= 'function' and box.space[conf.space_name] ~= nil and not box.info.ro then
            break
        end
        fiber.sleep(0.1)
    end

    while true do
        box.begin()
        local rc, res = pcall(function()
                -- Огонь живет две секунды
                for _, fire in box.space[conf.space_name].index['type']:pairs({conf.fire_type}) do
                    if fire['health'] <= 0 then
                        -- Огонь исчерпан
                        box.space[conf.space_name]:delete(fire['id'])
                    else
                        -- Таймер огня
                        box.space[conf.space_name]:update(fire['id'], {{'-', conf.health_field, 1}})
                    end
                end
                for _, bomb in box.space[conf.space_name].index['type']:pairs({conf.bomb_type}) do
                    if bomb['health'] <= 0 then
                        -- Сработала бомба - создаем поле из огня
                        for i=-2,2 do
                            for j=-2,2 do
                                local fire = {
                                    ['id'] = uuid.str(),
                                    ['icon'] = icons.fire,
                                    ['x'] = bomb['x'] + i,
                                    ['y'] = bomb['y'] + j,
                                    ['type'] = conf.fire_type,
                                    ['health'] = conf.fire_energy,
                                }
                                fire, err  = box.space[conf.space_name]:frommap(fire)
                                if err then
                                    log.info(err)
                                else
                                    box.space[conf.space_name]:put(fire)
                                end
                            end
                        end
                        box.space[conf.space_name]:delete(bomb['id'])
                    else
                        -- Таймер бомбы
                        box.space[conf.space_name]:update(bomb['id'], {{'-', conf.health_field, 1}})
                    end
                end
        end)
        if not rc then
            log.info(res)
            box.rollback()
        else
            box.commit()
        end
        fiber.sleep(1)
    end
end

fiber.new(bomb_loop)

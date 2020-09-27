#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local uuid = require('uuid')
local uri = require('uri')

local icons = require('icons')
local conf = require('conf')

local render = require('render')
local wind = require('wind')
local bomd = require('bomb')
local collision = require('collision')
local train = require('train')
local food = require('food')

function add_player(server)
    if box.session.peer() == nil then
        return false
    end
    local server = uri.parse(server)
    local replica = uri.parse(box.session.peer())
    replica.service = server.service
    replica.login = conf.user
    replica.password = conf.password
    replica = uri.format(replica, {include_password=true})
    local replication = box.cfg.replication or {}
    local found = false
    for _, it in ipairs(replication) do
        if it == replica then
            found = true
            break
        end
    end
    if not found then
        table.insert(replication, replica)
        box.cfg({replication={}})
        box.cfg({replication=replication})
    end
    return true
end

--[[
    Создание/загрузка базы данных и кластера
]]
local server = arg[1] or '0.0.0.0:8081'
local wrkdir = arg[2] or './foodstorage'
local fio = require('fio')
fio.mktree(wrkdir)
box.cfg{
    listen=server,
    replication_connect_timeout=0.1,
    replication_connect_quorum=0,
    work_dir=wrkdir,
    log="file:foodmaker.log",
}

--[[
    Создание схемы
]]
box.schema.user.create(conf.user, { password = conf.password, if_not_exists=true })
box.schema.user.grant(conf.user, 'replication', nil, nil, { if_not_exists=true })
box.schema.user.grant('guest', 'read,write,execute', 'universe', nil, { if_not_exists=true })
box.schema.func.create('add_player', { if_not_exists=true} )
box.schema.user.grant(conf.user, 'execute', 'function', 'add_player', { if_not_exists=true })

box.schema.space.create(conf.space_name, { if_not_exists=true })
box.space[conf.space_name]:format(conf.format, {if_not_exists=true})

box.space[conf.space_name]:create_index('id',
                                        {parts={{field="id", type="string"}},
                                         if_not_exists = true})

box.space[conf.space_name]:create_index('pos',
                                        {parts={{field="x", type="unsigned"},
                                             {field="y", type="unsigned"},
                                             {field="type", type="string"}},
                                         unique=false,
                                         if_not_exists = true})

box.space[conf.space_name]:create_index('type',
                                        {parts={{field="type", type="string"}},
                                         unique=false,
                                         if_not_exists = true})

box.space[conf.space_name]:create_index('health',
                                        {parts={{field="type", type="string"},
                                             {field="health", type="unsigned"}},
                                         unique=false,
                                         if_not_exists = true})

local Object = require 'lib.base-class'
local Monster = Object:extend()
local Resources = require 'src.resources'
local V = require 'src.vectors'
local dijkstra = require 'src.dijkstra'
local Animation = require 'src.animation'

function Monster.set(b, x, y, monsterSpeed, world)
    b.world = world
    b.w, b.h = 16, 16
    b.x, b.y = x-b.w/2, y-b.h/2
    b.oldTile = world.positionToTile({x=x, y=y})
    b.destroyed = false
    -- monsterSpeed = 100
    b.speed = monsterSpeed
    b.dx = -monsterSpeed
    b.dy = 0
    b.color = {math.random()*0.5+0.5, 0, 0}
    -- b.health = 20
    -- b.health = 1
    b.health = 2
    b.target = nil
    b.pathCalcTime = 0
    b.pathCalcDelay = math.random()*3+1
    b.state = 'wandering'
    b.deathTime = nil
    b.lastAttack = 0
    -- Flying slimes
    -- local yPixel = 24*32
    -- Spiders
    -- local yPixel = 28*32
    -- Bugs
    local yPixel = 5*32
    b.animation = Animation(Resources.creatureImg, {
        {x=0, y=yPixel, w=32, h=32},
        {x=32, y=yPixel, w=32, h=32},
        {x=64, y=yPixel, w=32, h=32},
    })
    b.deathAnimation = Animation(Resources.creatureImg, {
        {x=96, y=yPixel, w=32, h=32},
    })
end

local function shuffle(x)
	for i = #x, 2, -1 do
		local j = math.random(i)
		x[i], x[j] = x[j], x[i]
	end
end

local function getTowerList(items, monsterRoamDist, b)
    local towers = {}
    for _, item in ipairs(items) do
        local Tower = require 'src.tower'
        if item:is(Tower) and item.health > 0 and V.dist(item, b) <= monsterRoamDist*32 then
            table.insert(towers, item)
        end
    end
    return towers
end

function Monster.update(b, dt)

    b.animation:update(dt)
    if b.health <= 0 then
        b.deathAnimation:update(dt)
        if b.world.time - b.deathTime > 10 then
            b.destroyed = true
        end
        return
    end

    local monsterRoamDist = 24

    local towers = getTowerList(b.world.items, monsterRoamDist, b)

    -- Only update the path if the monster has moved to a new tile.
    -- local ti = world.positionToTile(b)
    local ti = b.world.positionToTile(V.add(b, {x=b.w/2,y=b.h/2}))
    local targetFound = false
    if b.world.time - b.pathCalcTime > b.pathCalcDelay then
        if #towers > 0 then
            local paths = dijkstra(b.world.structureTileMap.tiles, ti, monsterRoamDist)
            b.target = nil
            if paths then
                for _, item in ipairs(towers) do
                    local mNode = b.world.positionToTile(item)
                    if paths[mNode.y] and paths[mNode.y][mNode.x] then
                        local node = paths[mNode.y][mNode.x]
                        if node then
                            if node.distance ~= math.huge and ((b.target == nil) or
                                    (b.target ~= nil and node.distance < b.target.distance)) then
                                b.target = node
                                targetFound = true
                                b.pathCalcTime = b.world.time
                                b.state = 'hunting'
                            end
                        end
                    end
                end
            end
        end
        -- If a valid target wasn't found, then wander the caves.
        -- Take some random samples from the map and if they were
        -- part of the found areas, then choose it to be the target.
        if not targetFound then
            b.pathCalcTime = b.world.time
            b.state = 'wandering'
            local directions = {
                            { 0, -1},
                {-1,  0},           { 1,  0},
                            { 0,  1}
            }
            shuffle(directions)
            for _, v in ipairs(directions) do
                local newX, newY = ti.x+v[1], ti.y+v[2]
                local row = b.world.structureTileMap.tiles[newY]
                if row then
                    local tile = row[newX]
                    if tile then
                        if tile.type == nil then
                            b.target = {parent=nil,x=newX,y=newY}
                            break
                        end
                    end
                end
            end
        end
    end
    
    if b.target ~= nil then
        local nextNode = b.target
        while nextNode.parent ~= nil and not (nextNode.parent.x == ti.x and nextNode.parent.y == ti.y) and not (nextNode.x == ti.x and nextNode.y == ti.y) do
            nextNode = nextNode.parent
        end
        local n = V.norm(V.subtract(V.add(b.world.tileToPosition(nextNode), {x=16, y=16}), V.add(b, {x=b.w/2,y=b.h/2})))
        local d = V.scale(n, b.speed)
        b.dx = d.x
        b.dy = d.y
    else
        b.dx = 0
        b.dy = 0
    end
    
    b.x = b.x + (b.dx * dt)
    b.y = b.y + (b.dy * dt)

    -- If the monster is inside a wall, push it away from the wall.
    if b.world.structureTileMap.tiles[ti.y] and b.world.structureTileMap.tiles[ti.y][ti.x] and b.world.structureTileMap.tiles[ti.y][ti.x].type ~= nil then
        local vec = V.subtract(V.add(b, {x=b.w/2,y=b.h/2}), V.add(b.world.tileToPosition(ti), {x=16, y=16}))
        local strength = 30
        b.x = b.x + vec.x*dt*strength
        b.y = b.y + vec.y*dt*strength
    end

    -- If close to the target when hunting, then calculate a new target.
    if b.target ~= nil and b.state == 'hunting' then
        if V.dist(V.add(b, {x=b.w/2,y=b.h/2}), V.add(b.world.tileToPosition(b.target), {x=16, y=16})) < 16 then
            -- Force a path refresh.
            b.pathCalcTime = 0
        end
    end
end

function Monster.hurt(b, damage)
    b.health = b.health - damage
    if b.health <= 0 then
        b.deathTime = b.world.time
        -- b.destroyed = true
    end
end

function Monster.draw(b)
    love.graphics.setColor(1,1,1)
    local animation = nil
    if b.health <= 0 then
        animation = b.deathAnimation
    else
        animation = b.animation
    end
    animation:draw(b.x-16+b.w/2, b.y-16+b.h/2)
    -- love.graphics.setColor(b.color)
    -- love.graphics.rectangle('fill', b.x, b.y, b.w, b.h)
end

function Monster.collide(b, other, dt)

    if b.health <= 0 then return end

    local Tower = require 'src.tower'
    if other:is(Tower) and b.world.time-b.lastAttack > 1 then
        b.lastAttack = b.world.time
        other:hurt(1)
    elseif other:is(Monster) and other.health > 0 then
        -- Push the monsters away from each other.
        local vec = V.norm(V.subtract(other, b))
        local strength = 30
        other.x = other.x + vec.x*strength*dt
        other.y = other.y + vec.y*strength*dt
        b.x = b.x + -vec.x*strength*dt
        b.y = b.y + -vec.y*strength*dt
    end

end

return Monster

local Object = require 'lib.base-class'
local Tower = Object:extend()
local objectToString = require 'lib.object-to-string'
local Bullet = require 'src.bullet'
local Resources = require 'src.resources'
local Monster = require 'src.monster'
local Den = require 'src.den'
local V = require 'src.vectors'
local Animation = require 'src.animation'

function Tower.set(p, world, x, y)
    p.w, p.h = 16, 16
    p.x, p.y = x-p.w/2, y-p.h/2
    p.angle = nil
    p.world = world
    p.destroyed = false
    p.firing = false
    -- p.lineOfSight = 12
    p.lineOfSight = 6
    -- Set to world time when firing.
    p.fireStart = 0
    p.mineTime = 0
    p.health = 1
    p.turretQuad = love.graphics.newQuad(0, 0, 22, 26, Resources.weapons)
    p.facing = {x=math.random()-0.5,y=math.random()-0.5}
end

function Tower.getOres(p)
    local oreList = {}
    local pTile = p.world.positionToTile(p)
    local directions = {
                    { 0, -1},
        {-1,  0},           { 1,  0},
                    { 0,  1}
    }
    for _, d in ipairs(directions) do
        local row = p.world.structureTileMap.tiles[pTile.y+d[2]]
        if row then
            local tile = row[pTile.x+d[1]]
            if tile and tile.type == 'ore' then
                table.insert(oreList, tile)
            end
        end
    end
    return oreList
end

function Tower.update(p, dt)

    if p.destroyedAnimation then
        p.destroyedAnimation:update(dt)
        if p.world.time - p.destroyedTime >= 3 then
            p.destroyed = true
        end
    end

    if p.health <= 0 then
        return
    end

    local target = nil
    for _, item in ipairs(p.world.items) do
        if (item:is(Monster) or item:is(Den)) and item.health > 0 and V.dist(p, item) <= p.lineOfSight*32 then
            local towerPosition = p.world.positionToTile(p)
            local targetPosition = p.world.positionToTile(item)
            local count, isTargetObstacle = p.world:isSightClear(p.world.structureTileMap, towerPosition, targetPosition)
            if count == 0 then
                if target == nil then
                    target = item
                elseif V.dist(p, item) < V.dist(p, target) then
                    target = item
                end
            end
        end
    end

    if target then
        p.facing = V.subtract(target, p)
    end

    if target and p.world.time - p.fireStart > 3 then
        p.fireStart = p.world.time
        local direction = V.norm(p.facing)
        p.world:addItem(Bullet(p.x+p.w/2 + direction.x*18, p.y+p.h/2 + direction.y*18, target.x+target.w/2, target.y+target.h/2, 200, p.world))
    end

    -- Do mining if there is an ore block adjacent.
    if p.world.time - p.mineTime > 1 then
        p.mineTime = p.world.time
        local oreList = p:getOres()
        for _, tile in ipairs(oreList) do
            if tile.value >= 1 then
                tile.value = tile.value - 1
                p.world.money = p.world.money + 1
            else
                -- Turn the ore into depleted ore
                tile.type = 'depleted_ore'
            end
        end
    end

end

function Tower.hurt(p, damage)

    if p.health <= 0 then return end

    p.health = p.health - damage
    if p.health <= 0 then
        p.destroyedTime = p.world.time
        local frames = {}
        for i = 1, 12 do
            table.insert(frames, {
                x = (i-1)*96,
                y = 0,
                w = 96,
                h = 96
            })
        end
        p.destroyedAnimation = Animation(Resources.explosionImg, frames, {
            sx = 1/3, sy = 1/3, loop = false
        })
    end

end

function Tower.draw(p)
    
    if p.health > 0 or (p.health <= 0 and p.world.time - p.destroyedTime <= 1) then
        love.graphics.setColor(1, 1, 1)
        -- love.graphics.rectangle('fill', p.x, p.y, p.w, p.h)
        love.graphics.draw(Resources.weapons, p.turretQuad, p.x + p.w/2, p.y + p.h/2, math.atan2(p.facing.y, p.facing.x) + math.pi/2, 1, 1, 11, 18)
    end
    if p.destroyedAnimation then
        p.destroyedAnimation:draw(p.x-16+p.w/2, p.y-16+p.h/2)
    end

    if p.health > 0 then
        love.graphics.setColor(0.8, 0.8, 0)
        local oreList = p:getOres()
        for _, tile in ipairs(oreList) do
            local tilePosition = V.add(p.world.tileToPosition(tile), {x=16, y=16})
            love.graphics.line(p.x + p.w/2, p.y + p.h/2, tilePosition.x, tilePosition.y)
        end
    end

end

function Tower.collide(p, other)

end

return Tower

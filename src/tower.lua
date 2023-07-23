local Object = require 'src.lib.base-class'
local Tower = Object:extend()
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
    p.lineOfSight = 6
    p.rangeUpgrade = 0
    p.damageUpgrade = 0
    p.rateOfFireUpgrade = 0
    -- Set to world time when firing.
    p.fireStart = 0
    p.mineTime = 0
    p.health = 1
    p.turretQuad = love.graphics.newQuad(0, 0, 22, 26, Resources.weapons)
    p.facing = {x=math.random()-0.5,y=math.random()-0.5}
    p.fireDelaySeconds = 3
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

function Tower.getRange(p)
    return p.lineOfSight + 3*p.rangeUpgrade
end

function Tower.calculateLeadLocation(p, target)

    local bulletSpeed = 200
    local tVelocity = {x=target.dx or 0, y=target.dy or 0}

    local newTargetPosition = target
    local diffVec = nil

    for i = 1, 5 do
        diffVec = V.subtract(newTargetPosition, p)

        local timeToTarget = V.length(diffVec)/bulletSpeed
        newTargetPosition = V.add(V.scale(tVelocity, timeToTarget), target)
    end

    return V.norm(diffVec)

end

function Tower.update(p, dt)

    if p.destroyedAnimation then
        p.destroyedAnimation:update(dt)
        if p.world.time - p.destroyedTime >= 1 then
            p.destroyed = true
        end
    end

    if p.health <= 0 then
        return
    end

    local target = nil
    for _, item in ipairs(p.world.items) do
        if (item:is(Monster) or item:is(Den)) and item.health > 0 and V.dist(p, item) <= p:getRange()*32 then
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

    if target ~= nil then
        p.facing = p:calculateLeadLocation(target)
    end

    if target and p.world.time - p.fireStart > (p.fireDelaySeconds - p.rateOfFireUpgrade*1.5) then
        p.fireStart = p.world.time
        p.world:playSoundEffect(Resources.shotSound, p)
        local direction = V.norm(p.facing)
        p.world:addItem(Bullet(
            p.x+p.w/2 + direction.x*18,
            p.y+p.h/2 + direction.y*18,
            p.x+p.w/2 + direction.x*180,
            p.y+p.h/2 + direction.y*180,
            200,
            1 + p.damageUpgrade * 3,
            p.world))
    end

    -- Do mining if there is an ore block adjacent.
    if p.world.time - p.mineTime > 1 then
        p.mineTime = p.world.time
        local oreList = p:getOres()
        local totalOre = 0
        for _, tile in ipairs(oreList) do
            local oreAmount = math.min(1, tile.value)
            if tile.value > 0 then
                tile.value = tile.value - oreAmount
                p.world.money = p.world.money + oreAmount
                totalOre = totalOre + oreAmount
            else
                -- Turn the ore into depleted ore
                tile.type = 'depleted_ore'
            end
        end
        if totalOre > 0 then
            table.insert(p.world.moneyLabels, {time = p.world.time, value = totalOre, duration = 3, source = p})
            p.world:playSoundEffect(Resources.moneySound, p)
        end
    end

end

function Tower.hurt(p, damage)

    if p.health <= 0 then return end

    p.health = p.health - damage
    if p.health <= 0 then
        p.destroyedTime = p.world.time
        p.destroyedAnimation = Animation(Resources.explosionImg, Resources.explosionFrames, {
            sx = 1/3, sy = 1/3, loop = false, frameDuration = 1/12
        })
        p.world:playSoundEffect(Resources.explosionSound, p)
    end

end

function Tower.draw(p)
    
    if p.health > 0 or (p.health <= 0 and p.world.time - p.destroyedTime <= 1/3) then
        local oneSixteenth = 2*math.pi/16
        local centerDamage, centerRange, centerRateOfFire = 2*math.pi, 1/3*2*math.pi, 2/3*2*math.pi
        local dots = {
            {x=math.cos(centerDamage+oneSixteenth), y=math.sin(centerDamage+oneSixteenth), type="damageUpgrade", color={1,0,0}, index=1},
            {x=math.cos(centerDamage), y=math.sin(centerDamage), type="damageUpgrade", color={1,0,0}, index=1},
            {x=math.cos(centerDamage-oneSixteenth), y=math.sin(centerDamage-oneSixteenth), type="damageUpgrade", color={1,0,0}, index=1},

            {x=math.cos(centerRange+oneSixteenth), y=math.sin(centerRange+oneSixteenth), type="rangeUpgrade", color={0,0,1}, index=1},
            {x=math.cos(centerRange), y=math.sin(centerRange), type="rangeUpgrade", color={0,0,1}, index=1},
            {x=math.cos(centerRange-oneSixteenth), y=math.sin(centerRange-oneSixteenth), type="rangeUpgrade", color={0,0,1}, index=1},

            {x=math.cos(centerRateOfFire+oneSixteenth), y=math.sin(centerRateOfFire+oneSixteenth), type="rateOfFireUpgrade", color={0,1,0}, index=1},
            {x=math.cos(centerRateOfFire), y=math.sin(centerRateOfFire), type="rateOfFireUpgrade", color={0,1,0}, index=1},
            {x=math.cos(centerRateOfFire-oneSixteenth), y=math.sin(centerRateOfFire-oneSixteenth), type="rateOfFireUpgrade", color={0,1,0}, index=1},
        }
        for _, d in ipairs(dots) do
            if d.index <= p[d.type] then
                love.graphics.setColor(d.color)
            else
                love.graphics.setColor(0.2, 0.2, 0.2)
            end
            local newLoc = V.scale(V.norm(d), 10)
            love.graphics.circle('fill', p.x + p.w/2 + newLoc.x, p.y + p.h/2 + newLoc.y, 3)
        end
        love.graphics.setColor(1, 1, 1)
        -- love.graphics.rectangle('fill', p.x, p.y, p.w, p.h)
        love.graphics.draw(Resources.weapons, p.turretQuad, p.x + p.w/2, p.y + p.h/2, math.atan2(p.facing.y, p.facing.x) + math.pi/2, 1, 1, 11, 18)
        
    end
    if p.destroyedAnimation then
        p.destroyedAnimation:draw(p.x-16+p.w/2, p.y-16+p.h/2)
    end

    if p.health > 0 then
        love.graphics.setColor({0.8, 0.8, 0})
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

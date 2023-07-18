local Object = require 'src.lib.base-class'
local Den = Object:extend()
local Resources = require 'src.resources'
local V = require 'src.vectors'
local Monster = require 'src.monster'
local Animation = require 'src.animation'

function Den.set(b, x, y, world)
    b.lastMonsterSpawn = 0
    b.world = world
    b.w, b.h = 32, 32
    b.x, b.y = x-b.w/2, y-b.h/2
    b.destroyed = false
    b.color = {0, math.random()*0.5+0.5, 0}
    b.list = {}
    b.health = 10
    -- b.monsterCount = 3
    b.monsterCount = 10
end

function Den.update(b, dt)

    if b.destroyedAnimation then
        b.destroyedAnimation:update(dt)
        if b.world.time - b.destroyedTime >= 1 then
            b.destroyed = true
        end
    end

    -- Spawn monsters
    local SPAWN_DELAY = 5
    if b.world.time - b.lastMonsterSpawn > SPAWN_DELAY and #b.list < b.monsterCount then
        b.lastMonsterSpawn = b.world.time
        local m = Monster(
            b.x+b.w/2+math.random(-3,3),
            b.y+b.h/2+math.random(-3,3),
            50, -- Set monster speed
            5, -- Monster image index
            2, -- Monster health
            b.world
        )
        b.world:addItem(m)
        table.insert(b.list, m)
    end
    for i = #b.list, 1, -1 do
        if b.list[i].health <= 0 then
            table.remove(b.list, i)
        end
    end
end

function Den.hurt(b, damage)

    if b.health <= 0 then return end

    b.health = b.health - damage
    if b.health <= 0 then
        b.destroyedTime = b.world.time
        b.destroyedAnimation = Animation(Resources.explosionImg, Resources.explosionFrames, {
            sx = 1/2, sy = 1/2, loop = false, frameDuration = 1/12
        })
        b.world:playSoundEffect(Resources.explosionSound, b)
    end

end

function Den.draw(b)
    -- love.graphics.setColor(b.color)
    -- love.graphics.rectangle('fill', b.x, b.y, b.w, b.h)
    if b.health > 0 or (b.health <= 0 and b.world.time - b.destroyedTime <= 1/3) then
        love.graphics.setColor(1,1,1)
        love.graphics.draw(Resources.denImg, b.x, b.y)
    end
    if b.destroyedAnimation then
        b.destroyedAnimation:draw(b.x-24+b.w/2, b.y-24+b.h/2)
    end
end

function Den.collide(b, other)
    
end

return Den

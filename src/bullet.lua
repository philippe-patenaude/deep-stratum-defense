local Object = require 'src.lib.base-class'
local Bullet = Object:extend()
local Resources = require 'src.resources'
local Monster = require 'src.monster'
local Den = require 'src.den'
local V = require 'src.vectors'

function Bullet.set(b, x, y, tx, ty, bulletSpeed, damage, world)
    b.w, b.h = 4, 4
    b.x, b.y = x-b.w/2, y-b.h/2
    b.life = 1.5
    b.angle = angle
    b.destroyed = false
    b.damage = damage
    b.world = world
    local vx, vy = tx-x, ty-y
    local n = V.norm({x=vx,y=vy})
    b.dx = bulletSpeed * n.x
    b.dy = bulletSpeed * n.y
end

function Bullet.update(b, dt)
    b.x = b.x + (b.dx * dt)
    b.y = b.y + (b.dy * dt)
    b.life = b.life - dt
    local bulletTile = b.world.positionToTile(V.add(b, {x=b.w/2,y=b.h/2}))
    if b.life <= 0 or (b.world.structureTileMap.tiles[bulletTile.y]
            and b.world.structureTileMap.tiles[bulletTile.y][bulletTile.x]
            and b.world.structureTileMap.tiles[bulletTile.y][bulletTile.x].type ~= nil) then
        b.destroyed = true
        b.world:playSoundEffect(Resources.hitRockSound, b)
    end
end

function Bullet.draw(b)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', b.x, b.y, b.w, b.h)
end

function Bullet.collide(b, other)
    if (other:is(Monster) or other:is(Den)) and other.health > 0 and not b.destroyed then
        other:hurt(b.damage)
        b.destroyed = true
        b.world:playSoundEffect(Resources.hitSound, b)
    end
end

return Bullet

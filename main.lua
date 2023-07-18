local World = require 'src.world'
local Resources = require 'src.resources'
local Animation = require 'src.animation'
local AudioPlayer = require 'src.audio-player'

local gameTime = 0
local CAMERA_SPEED = 300

local right, left, up, down = 0, 0, 0, 0
local world = nil

-- local animation = nil

function love.load()

    Resources.creatureImg = love.graphics.newImage("resources/creatures edit_0.png")
    Resources.explosionImg = love.graphics.newImage("resources/Explosion.png")
    local frames = {}
    for i = 1, 12 do
        table.insert(frames, {
            x = (i-1)*96,
            y = 0,
            w = 96,
            h = 96
        })
    end
    Resources.explosionFrames = frames
    Resources.stoneImg = love.graphics.newImage("resources/stone-tile.png")
    Resources.grassImg = love.graphics.newImage("resources/grass-tile-2.png")
    Resources.rockImg = love.graphics.newImage("resources/rock wall tileset-small.png")
    Resources.weapons = love.graphics.newImage("resources/shipWeapons.png")
    Resources.turretBase = love.graphics.newImage("resources/Tower-small.png")
    Resources.ore = love.graphics.newImage("resources/ore.png")
    Resources.denImg = love.graphics.newImage("resources/beetlespawn.png")

    Resources.bugSound = love.audio.newSource("resources/monster.wav", "static")
    Resources.shotSound = love.audio.newSource("resources/explosion_dull.flac", "static")
    Resources.explosionSound = love.audio.newSource("resources/synthetic_explosion_1.flac", "static")
    Resources.moneySound = love.audio.newSource("resources/ring_inventory.wav", "static")
    Resources.hitSound = love.audio.newSource("resources/bfh1_hit_08.ogg", "static")
    Resources.hitRockSound = love.audio.newSource("resources/bfh1_rock_falling_05.ogg", "static")
    Resources.placeTowerSound = love.audio.newSource("resources/MachinePowerOff.ogg", "static")
    Resources.monsterWaveStartSound = love.audio.newSource("resources/MonsterSoundTutorial_clip.wav", "static")
    
    Resources.music = love.audio.newSource("resources/dark fallout.ogg", "stream")

    Resources.smallFont = love.graphics.newFont(12)
    Resources.mediumFont = love.graphics.newFont(24)
    Resources.largeFont = love.graphics.newFont(48)

    Resources.swishSounds = {}
    for i = 1, 13 do
        table.insert(Resources.swishSounds, love.audio.newSource("resources/swish-" .. tostring(i) .. ".wav", "static"))
    end

    -- local frames = {}
    -- for i = 1, 12 do
    --     table.insert(frames, {
    --         x = (i-1)*96,
    --         y = 0,
    --         w = 96,
    --         h = 96
    --     })
    -- end
    -- animation = Animation(Resources.explosionImg, frames, {
    --     sx = 1/3, sy = 1/3
    -- })
    world = World()
    AudioPlayer:play(Resources.music, {
        loop = true,
        type = "MUSIC",
        volume = 0.5
    })
end

function love.update(dt)
    gameTime = gameTime + dt
    world:update(dt)
    -- animation:update(dt)
    
    Resources.camera.cx = Resources.camera.cx + (right-left)*dt*CAMERA_SPEED
    Resources.camera.cy = Resources.camera.cy + (down-up)*dt*CAMERA_SPEED
end

function love.draw()
    world:draw()
    -- animation:draw(50, 50)
end

function love.keypressed(k, s)

    if s == 'right' then
        right = 1
    end
    if s == 'left' then
        left = 1
    end

    if s == 'up' then
        up = 1
    end
    if s == 'down' then
        down = 1
    end

    if s == '`' then
        world.cheatMode = not world.cheatMode
    end

    if world.cheatMode and s == 's' then
        world.drawShroud = not world.drawShroud
    end

    if world.won and s == 'n' then
        world:rebuild()
    end

end

function love.keyreleased(k, s)

    if s == 'right' then
        right = 0
    end
    if s == 'left' then
        left = 0
    end

    if s == 'up' then
        up = 0
    end
    if s == 'down' then
        down = 0
    end

end

function love.mousepressed(x, y, button)
    if button == 1 and world.won == false then
        local position = world.screenToPosition({x=x,y=y})
        local xTile, yTile = math.floor(position.x/world.towerTileMap.TILE_WIDTH)+1, math.floor(position.y/world.towerTileMap.TILE_HEIGHT)+1
        if world.cheatMode then
            world:placeTower({x=xTile,y=yTile}, true)
        else
            world:placeTower({x=xTile,y=yTile}, false)
        end
    end
end

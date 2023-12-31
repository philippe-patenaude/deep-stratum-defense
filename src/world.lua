local Object = require 'src.lib.base-class'
local World = Object:extend()
local Monster = require 'src.monster'
local Resources = require 'src.resources'
local TileMap = require 'src.tilemap'
local Den = require 'src.den'
local Tower = require 'src.tower'
local V = require 'src.vectors'
local AudioPlayer = require 'src.audio-player'

local function randomWalkTunnelBuilder(tileMap, start)
    local cursor = {x=start.x, y=start.y}
    local newX, newY = cursor.x, cursor.y
    while true do
        tileMap.tiles[cursor.y][cursor.x].type = nil
        if math.random() < 0.5 then
            if math.random() < 0.5 then
                newX = cursor.x - 1
            else
                newX = cursor.x + 1
            end
        else
            if math.random() < 0.5 then
                newY = cursor.y - 1
            else
                newY = cursor.y + 1
            end
        end
        if newX <= 1 or newX >= #tileMap.tiles[1] or
                newY <= 1 or newY >= #tileMap.tiles then
            -- We're at the edge of the map, so stop generating the map
            -- and return the last generated location.
            return cursor
        else
            cursor.x = newX
            cursor.y = newY
        end
    end
end

function World.set(w)
    w.cheatMode = false
    w.drawShroud = true
    w.oreSymbol = love.graphics.newQuad(3*32,8*32,32,32,Resources.ore)
    w:rebuild()
end

function World.rebuild(w)

    w.goalIncome = 10000
    w.selectedTile = nil
    w.screenShakeEffectStart = -100
    w.nextMonsterWaveTime = math.random(60,120)
    w.money = 150
    w.items = {}
    w.moneyLabels = {}
    w.futureSpawns = {}
    w.time = 0
    w.updateShroud = true
    w.won = false

    -- Set up the floor tiles

    w.floorTileMap = TileMap(Resources.TILES_WIDE, Resources.TILES_HIGH, {
        stone={image=Resources.stoneImg},
        grass={image=Resources.grassImg}
    }, w)
    -- Default to stone floor but add patches of grass.
    for y = 1, w.floorTileMap.height do
        for x = 1, w.floorTileMap.width do
            if math.random() < 0.2 then
                w.floorTileMap.tiles[y][x].type = 'grass'
            else
                w.floorTileMap.tiles[y][x].type = 'stone'
            end
        end
    end

    -- Set up the tower tiles

    w.towerTileMap = TileMap(Resources.TILES_WIDE, Resources.TILES_HIGH, {
        basic={image=Resources.turretBase}
    }, w)

    -- Setup structures
    
    w.structureTileMap = TileMap(Resources.TILES_WIDE, Resources.TILES_HIGH, {
        rock={image=Resources.rockImg},
        ore={image=Resources.ore,quad=love.graphics.newQuad(3*32,0,32,32,Resources.ore)},
        depleted_ore={image=Resources.ore,quad=love.graphics.newQuad(6*32,32,32,32,Resources.ore)},
    }, w)
    -- Fill with rocks.
    for y = 1, Resources.TILES_HIGH do
        for x = 1, Resources.TILES_WIDE do
            w.structureTileMap.tiles[y][x].type = 'rock'
        end
    end
    -- Create a tunnel from the middle to one of the edges.
    local startLocation = {x=math.floor(Resources.TILES_WIDE/2), y=math.floor(Resources.TILES_HIGH/2)}
    local tunnelEnd = randomWalkTunnelBuilder(w.structureTileMap, startLocation)
    w:addItem(Den(
        (tunnelEnd.x-0.5)*32,
        (tunnelEnd.y-0.5)*32,
        w))

    -- Create a second tunnel from the middle to one of the edges.
    tunnelEnd = randomWalkTunnelBuilder(w.structureTileMap, {x=math.floor(Resources.TILES_WIDE/2), y=math.floor(Resources.TILES_HIGH/2)})
    w:addItem(Den(
        (tunnelEnd.x-0.5)*32,
        (tunnelEnd.y-0.5)*32,
        w))

    -- Place the starting tower in the center of the map.
    local tower = w:placeTower(startLocation, true)
    tower.damageUpgrade = 1
    tower.rangeUpgrade = 1
    tower.rateOfFireUpgrade = 1

    -- Center the camera on the center of the map.
    Resources.camera.cx = startLocation.x*32-love.graphics.getWidth()/2
    Resources.camera.cy = startLocation.y*32-love.graphics.getHeight()/2

    -- Add ore randomly in the rock walls.
    for y = 1, Resources.TILES_HIGH do
        for x = 1, Resources.TILES_WIDE do
            if w.structureTileMap.tiles[y][x].type == 'rock' and math.random() < 0.1 then
                w.structureTileMap.tiles[y][x].type = 'ore'
                -- Each ore will provide a certain amount of resources.
                w.structureTileMap.tiles[y][x].value = 300
            end
        end
    end

    w.shroudTileMap = TileMap(Resources.TILES_WIDE, Resources.TILES_HIGH, {
        shroud={color={0,0,0}}
    }, w)
    -- Fill with shroud.
    for y = 1, Resources.TILES_HIGH do
        for x = 1, Resources.TILES_WIDE do
            w.shroudTileMap.tiles[y][x].type = 'shroud'
        end
    end

    -- Spawn some spider aliens.

    for y = 1, Resources.TILES_HIGH do
        for x = 1, Resources.TILES_WIDE do
            local thisTile = {x=x, y=y}
            if V.dist(thisTile, startLocation) > 10 then
                if w.structureTileMap.tiles[y][x].type == nil and math.random() < 0.01 then
                    local mPosition = V.add(w.tileToPosition(thisTile), 16)
                    local m = Monster(
                        mPosition.x,
                        mPosition.y,
                        25, -- Set monster speed
                        28, -- Monster image index
                        3, -- Monster health
                        w
                    )
                    w:addItem(m)
                end
            end
        end
    end


end

local function lineLineIntersection(x1, y1, x2, y2, x3, y3, x4, y4)
    local uA = ((x4-x3)*(y1-y3) - (y4-y3)*(x1-x3)) / ((y4-y3)*(x2-x1) - (x4-x3)*(y2-y1));
    local uB = ((x2-x1)*(y1-y3) - (y2-y1)*(x1-x3)) / ((y4-y3)*(x2-x1) - (x4-x3)*(y2-y1));
    return (uA >= 0 and uA <= 1 and uB >= 0 and uB <= 1)
end

local function lineRectangleIntersection(x1, y1, x2, y2, rx, ry, rw, rh)
    local left =   lineLineIntersection(x1,y1,x2,y2, rx,ry,rx, ry+rh);
    local right =  lineLineIntersection(x1,y1,x2,y2, rx+rw,ry, rx+rw,ry+rh);
    local top =    lineLineIntersection(x1,y1,x2,y2, rx,ry, rx+rw,ry);
    local bottom = lineLineIntersection(x1,y1,x2,y2, rx,ry+rh, rx+rw,ry+rh);
    return left or right or top or bottom
end

function World.isSightClear(w, tileMap, source, target)
    local startX, startY = math.min(source.x, target.x), math.min(source.y, target.y)
    local endX, endY = math.max(source.x, target.x), math.max(source.y, target.y)
    local collisionCount = 0
    local targetIsObstacle = false
    -- Trace a ray from the center of the tower to each
    -- corner of the obstacle. Use the least obscured
    -- result as the final result. This helps the tower
    -- see more of the walls when placed, even if the
    -- obstacle is partially obscured.
    local directions = {
        {-1, -1}, { 1, -1},
        {-1,  1}, { 1,  1}
    }
    local directionResults = {}
    for _, d in ipairs(directions) do
        local dR = {collisionCount=0,targetIsObstacle=false}
        table.insert(directionResults, dR)
        for y = startY, endY do
            for x = startX, endX do
                if tileMap.tiles[y] and tileMap.tiles[y][x] and tileMap.tiles[y][x].type ~= nil then
                    local tilePosition = w.tileToPosition({x=x, y=y})
                    
                    local sTilePosition = V.add(w.tileToPosition(source), {x=16,y=16})
                    local tTilePosition = V.add(w.tileToPosition(target), {x=16+16*d[1],y=16+16*d[2]})
                    local result = lineRectangleIntersection(sTilePosition.x, sTilePosition.y, tTilePosition.x, tTilePosition.y, tilePosition.x, tilePosition.y, 32, 32)
                    if result == true then
                        dR.collisionCount = dR.collisionCount + 1
                        if target.x == x and target.y == y then
                            dR.targetIsObstacle = true
                        end
                    end
                end
            end
        end
    end
    collisionCount = math.min(
        directionResults[1].collisionCount,
        directionResults[2].collisionCount,
        directionResults[3].collisionCount,
        directionResults[4].collisionCount)
    targetIsObstacle = directionResults[1].targetIsObstacle
    return collisionCount, targetIsObstacle
end

function World.doUpdateShroud(w)
    -- Fill with shroud.
    for y = 1, Resources.TILES_HIGH do
        for x = 1, Resources.TILES_WIDE do
            w.shroudTileMap.tiles[y][x].type = 'shroud'
        end
    end
    for _, v in ipairs(w.items) do
        if v:is(Tower) then
            local lineOfSight = v:getRange()
            local startTile = w.positionToTile({x=v.x+v.w/2-lineOfSight*32, y=v.y+v.h/2-lineOfSight*32})
            local endTile = w.positionToTile({x=v.x+v.w/2+lineOfSight*32, y=v.y+v.h/2+lineOfSight*32})
            local xStart = math.max(1,startTile.x)
            local yStart = math.max(1,startTile.y)
            local xEnd = math.min(Resources.TILES_WIDE, endTile.x)
            local yEnd = math.min(Resources.TILES_HIGH, endTile.y)
            for y = yStart, yEnd do
                for x = xStart, xEnd do
                    local tile = {x=x, y=y}
                    if V.dist(V.add(v, {x=v.w/2,y=v.h/2}), V.add(w.tileToPosition(tile), 16)) <= lineOfSight*32 then
                        local towerPosition = w.positionToTile(v)
                        local count, isTargetObstacle = w:isSightClear(w.structureTileMap, towerPosition, tile)
                        if count == 0 or (count == 1 and isTargetObstacle == true) then
                            w.shroudTileMap.tiles[y][x].type = nil
                        end
                    end
                end
            end
        end
    end
end

function World.isTileInMap(world, tilePosition)
    return tilePosition.x >= 1 and tilePosition.x <= world.towerTileMap.width and
        tilePosition.y >= 1 and tilePosition.y <= world.towerTileMap.height
end

function World.canDestroyTower(world, tilePosition)
    if world:isTileInMap(tilePosition) and world.structureTileMap.tiles[tilePosition.y][tilePosition.x].type == nil and
            (forcePlace or world.shroudTileMap.tiles[tilePosition.y][tilePosition.x].type == nil) and
            world.towerTileMap.tiles[tilePosition.y][tilePosition.x].type ~= nil then
        return true
    end
    return false
end

function World.destroyTower(world, tilePosition, forceDestroy)
    if world:canDestroyTower(tilePosition) then
        if not forceDestroy then
            local costDiff = 0
            local tower = world.towerTileMap:get(tilePosition).tower
            if tower.health > 0 then
                costDiff = world:getSellCost(tower)
            -- elseif world.money > 10 then
            --     costDiff = -10
            -- else
            --     -- Don't have enough money to destroy destroy the tower.
            --     return
            end
            world.money = world.money + costDiff
        end
        local tile = world.towerTileMap.tiles[tilePosition.y][tilePosition.x]
        if tile.type ~= nil then
            tile.tower.destroyed = true
            tile.tower.health = 0
            world.updateShroud = true
            tile.type = nil
            world:playSoundEffect(Resources.placeTowerSound, tile.tower)
            tile.tower = nil
        end
    end
end

function World.canPlaceTower(world, tilePosition, forcePlace)
    if world:isTileInMap(tilePosition) and world.structureTileMap.tiles[tilePosition.y][tilePosition.x].type == nil and
            (forcePlace or world.shroudTileMap.tiles[tilePosition.y][tilePosition.x].type == nil) and
            world.towerTileMap.tiles[tilePosition.y][tilePosition.x].type == nil then
        if forcePlace or world.money >= 25 then
            return true
        end
    end
    return false
end

function World.placeTower(world, tilePosition, forcePlace)
    if world:canPlaceTower(tilePosition, forcePlace) then
        if not forcePlace then
            world.money = world.money - 25
        end
        local tile = world.towerTileMap.tiles[tilePosition.y][tilePosition.x]
        if tile.type == nil then
            tile.type = 'basic'
            tile.tower = Tower(world, (tilePosition.x-0.5)*world.towerTileMap.TILE_WIDTH, (tilePosition.y-0.5)*world.towerTileMap.TILE_HEIGHT)
            world:addItem(tile.tower)
            world.updateShroud = true
            world:playSoundEffect(Resources.placeTowerSound, tile.tower)
            return tile.tower
        end
    end
    return nil
end

function World.selectTower(world, tilePosition)
    if world:isTileInMap(tilePosition) and world.towerTileMap:get(tilePosition).type ~= nil then
        world.selectedTile = tilePosition
    else
        world.selectedTile = nil
    end
end

function World.positionToTile(p)
    return {x=math.floor(p.x/32)+1, y=math.floor(p.y/32)+1}
end

function World.tileToPosition(tile)
    return {x=(tile.x-1)*32, y=(tile.y-1)*32}
end

function World.screenToPosition(s)
    return {x=s.x+Resources.camera.x, y=s.y+Resources.camera.y}
end

function World.addItem(w, item)
    w.items[#w.items + 1] = item
end

function World.getSellCost(w, tower)
    if tower == nil or tower.health <= 0 then
        return 0
    else
        return 25 + (tower.damageUpgrade+tower.rangeUpgrade+tower.rateOfFireUpgrade)*25
    end
end

function World.playSoundEffect(w, source, location)
    -- The volume is based on the distance from the middle of the screen.
    local screenCenter = V.add(Resources.camera, {x=love.graphics.getWidth()/2, y=love.graphics.getHeight()/2})
    local normalizedDist = V.dist(location, screenCenter)/1000

    -- Don't play the audio if it is out of range.
    if normalizedDist <= 1 then
        local options = {
            volume = 1-normalizedDist
        }
        AudioPlayer:play(source, options)
    end
end

function World.draw(w)

    love.graphics.translate(-Resources.camera.x, -Resources.camera.y)

    w.floorTileMap:draw()
    w.towerTileMap:draw()
    
    for i, v in ipairs(w.items) do
        v:draw()
    end

    w.structureTileMap:draw()

    local x, y = love.mouse.getPosition()
    local tileMousePosition = w.positionToTile(w.screenToPosition({x=x, y=y}))

    if w:isTileInMap(tileMousePosition) then
        if w.towerTileMap:get(tileMousePosition).type ~= nil then
            love.graphics.setColor(0,0,1,0.5)
            local oldLineWidth = love.graphics.getLineWidth()
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', (tileMousePosition.x-1)*32, (tileMousePosition.y-1)*32, 32, 32)
            love.graphics.setLineWidth(oldLineWidth)
        elseif w:canPlaceTower(tileMousePosition, w.cheatMode) then
            love.graphics.setColor(0,1,0,0.5)
            love.graphics.rectangle('fill', (tileMousePosition.x-1)*32, (tileMousePosition.y-1)*32, 32, 32)
        else
            love.graphics.setColor(1,0,0,0.5)
            love.graphics.rectangle('fill', (tileMousePosition.x-1)*32, (tileMousePosition.y-1)*32, 32, 32)
        end
    end
    
    if w.selectedTile then
        love.graphics.setColor(0,0,1,0.5)
        love.graphics.rectangle('fill', (w.selectedTile.x-1)*32, (w.selectedTile.y-1)*32, 32, 32)
    end
    
    if (w.cheatMode and w.drawShroud) or (not w.cheatMode) then
        w.shroudTileMap:draw()
    end
    
    for _, v in ipairs(w.moneyLabels) do
        local cycleTime = (w.time-v.time)/v.duration
        if cycleTime <= 1 then
            love.graphics.setColor(0,0,0,1-cycleTime)
            love.graphics.rectangle('fill', v.source.x + v.source.w/2 - 2, v.source.y + v.source.h/2 - 32 - cycleTime * 50 - 2, 11, 20)
            local color = {0.8, 0.8, 0, 1-cycleTime}
            love.graphics.setColor(color)
            love.graphics.print(tostring(v.value), v.source.x + v.source.w/2, v.source.y + v.source.h/2 - 32 - cycleTime * 50)
        end
    end

    love.graphics.origin()
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(Resources.mediumFont)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(Resources.ore, w.oreSymbol, 10, 10)
    love.graphics.print(tostring(w.money) .. "/" .. tostring(w.goalIncome), 42, 10)

    if w.selectedTile then
        local tileObj = w.towerTileMap:get(w.selectedTile)
        if tileObj.type ~= nil then
            love.graphics.setColor(0,0,0,0.5)
            love.graphics.rectangle('fill', love.graphics.getWidth()-300, 0, 300, love.graphics.getHeight())
            love.graphics.setColor(0.8, 0.8, 0)
            love.graphics.setLineWidth(3)
            love.graphics.line(love.graphics.getWidth()-300, 0, love.graphics.getWidth()-300, love.graphics.getHeight())
            love.graphics.setFont(Resources.smallFont)
            love.graphics.setColor(1,1,1)
            if tileObj.tower.health > 0 then
                love.graphics.printf("Upgrades\n\nDamage (1): 1->3\nRange (2): 6->9\nDelay between shots (3): 3->1.5\n\nSell (x): +$" .. w:getSellCost(tileObj.tower), love.graphics.getWidth()-300 + 10, 0 + 10, 280)
            else
                love.graphics.printf("Clear (x): No cost", love.graphics.getWidth()-300 + 10, 0 + 10, 280)
            end
        end
    end

    if w.won then
        love.graphics.setColor(0,0,0,0.5)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(Resources.largeFont)
        love.graphics.printf("Quota met!", 0, 100, love.graphics.getWidth(), 'center')
        love.graphics.setFont(Resources.mediumFont)
        love.graphics.printf("Press 'n' to dig deeper.", 0, 200, love.graphics.getWidth(), 'center')
    end

    if w.cheatMode then
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(Resources.smallFont)
        love.graphics.printf("Cheat mode is on.\nPress '`' (back tick) to turn off.\nPress 's' to turn the shroud on and off.\nTurrets no longer have a cost and can be placed in the shroud.", 10, 50, 200)
    end

    love.graphics.setFont(oldFont)

end

function collideRect(a, b)
    return a.x < b.x + b.w and
    a.x + a.w > b.x and
    a.y < b.y + b.h and
    a.y + a.h > b.y
end

function World.update(w, dt)

    Resources.camera.x = Resources.camera.cx
    Resources.camera.y = Resources.camera.cy

    if w.won then
        return
    end

    w.time = w.time + dt

    if w.time - w.screenShakeEffectStart <= 3 then
        Resources.camera.x = Resources.camera.cx + math.random(-3,3)
        Resources.camera.y = Resources.camera.cy + math.random(-3,3)
    end

    for i, v in ipairs(w.items) do
        v:update(dt)
        if v.collide then
            for i2, v2 in ipairs(w.items) do
                -- Check for collision and run collision callbacks.
                if v ~= v2 and v2.collide and collideRect(v, v2) then
                    v:collide(v2, dt)
                    v2:collide(v, dt)
                end
            end
        end
    end
    for i = #w.items, 1, -1 do
        if w.items[i] and w.items[i].destroyed == true then
            if w.items[i]:is(Tower) then
                w.updateShroud = true
            end
            table.remove(w.items, i)
        end
    end

    if w.updateShroud then
        w.updateShroud = false
        w:doUpdateShroud()
    end
    
    for i = #w.moneyLabels, 1, -1 do
        local v = w.moneyLabels[i]
        if w.time-v.time > v.duration then
            table.remove(w.moneyLabels, i)
        end
    end

    if w.nextMonsterWaveTime <= w.time then
        w.nextMonsterWaveTime = w.time + math.random(60, 120)
        AudioPlayer:play(Resources.monsterWaveStartSound)
        w.screenShakeEffectStart = w.time
        -- Only spawn monsters on empty tiles that
        -- are under the shroud.
        for y = 1, Resources.TILES_HIGH do
            for x = 1, Resources.TILES_WIDE do
                local thisTile = {x=x, y=y}
                if w.structureTileMap.tiles[y][x].type == nil and w.shroudTileMap.tiles[y][x].type ~= nil then
                    -- One percent spawn chance.
                    if math.random() <= 0.01 then
                        local mPosition = V.add(w.tileToPosition(thisTile), 16)
                        -- Two thirds will be spiders. One third will be bugs.
                        if math.random() <= 2/3 then
                            table.insert(w.futureSpawns, {
                                time = w.time + math.random()*4,
                                object = Monster(
                                    mPosition.x,
                                    mPosition.y,
                                    25, -- Set monster speed
                                    28, -- Monster image index
                                    3, -- Monster health
                                    w
                                )
                            })
                        else
                            table.insert(w.futureSpawns, {
                                time = w.time + math.random()*4,
                                object = Monster(
                                    mPosition.x,
                                    mPosition.y,
                                    50, -- Set monster speed
                                    5, -- Monster image index
                                    2, -- Monster health
                                    w
                                )
                            })
                        end
                    end
                end
            end
        end
    end

    for i = #w.futureSpawns, 1, -1 do
        local s = w.futureSpawns[i]
        if s.time < w.time then
            table.insert(w.items, s.object)
            table.remove(w.futureSpawns, i)
        end
    end

    -- Win if the player gets enough excess cash.
    if w.money >= w.goalIncome then
        w.won = true
    end

end

return World
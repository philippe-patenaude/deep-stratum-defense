local Object = require 'lib.base-class'
local World = Object:extend()
local Monster = require 'src.monster'
local Resources = require 'src.resources'
local TileMap = require 'src.tilemap'
local Den = require 'src.den'
local Tower = require 'src.tower'
local V = require 'src.vectors'

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
    w:rebuild()
end

function World.rebuild(w)

    w.money = 150
    w.items = {}
    w.time = 0
    w.drawShroud = true
    w.updateShroud = true
    w.won = false

    -- Set up the floor tiles

    w.floorTileMap = TileMap(Resources.TILES_WIDE, Resources.TILES_HIGH, {
        stone={image=Resources.stoneImg},
        grass={image=Resources.grassImg}
        -- stone={color={0.3,0.3,0.4}},
        -- grass={color={0.4,0.6,0.2}}
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
    -- Set a patch of grass.
    -- for y = 3, 8 do
    --     for x = 2, 11 do
    --         w.floorTileMap.tiles[y][x].type = 'grass'
    --     end
    -- end

    -- Set up the tower tiles

    w.towerTileMap = TileMap(Resources.TILES_WIDE, Resources.TILES_HIGH, {
        basic={image=Resources.turretBase}
        -- basic={color={0.6,0.3,0.6}}
    }, w)

    -- Setup structures
    
    w.structureTileMap = TileMap(Resources.TILES_WIDE, Resources.TILES_HIGH, {
        -- rock={color={0.1,0.1,0.2}},
        rock={image=Resources.rockImg},
        ore={image=Resources.ore,quad=love.graphics.newQuad(3*32,0,32,32,Resources.ore)},
        depleted_ore={image=Resources.ore,quad=love.graphics.newQuad(6*32,32,32,32,Resources.ore)},
        -- ore={color={0.2,0.8,0.7}},
        -- depleted_ore={color={0.1,0.4,0.35}},
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
    w:placeTower(startLocation, true)

    -- Center the camera on the center of the map.
    Resources.camera.x = startLocation.x*32-love.graphics.getWidth()/2
    Resources.camera.y = startLocation.y*32-love.graphics.getHeight()/2

    -- Add ore randomly in the rock walls.
    for y = 1, Resources.TILES_HIGH do
        for x = 1, Resources.TILES_WIDE do
            if w.structureTileMap.tiles[y][x].type == 'rock' and math.random() < 0.1 then
                w.structureTileMap.tiles[y][x].type = 'ore'
                -- Each ore will provide a certain amount of resources.
                w.structureTileMap.tiles[y][x].value = 100
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
            local startTile = w.positionToTile({x=v.x+v.w/2-v.lineOfSight*32, y=v.y+v.h/2-v.lineOfSight*32})
            local endTile = w.positionToTile({x=v.x+v.w/2+v.lineOfSight*32, y=v.y+v.h/2+v.lineOfSight*32})
            local xStart = math.max(1,startTile.x)
            local yStart = math.max(1,startTile.y)
            local xEnd = math.min(Resources.TILES_WIDE, endTile.x)
            local yEnd = math.min(Resources.TILES_HIGH, endTile.y)
            for y = yStart, yEnd do
                for x = xStart, xEnd do
                    local tile = {x=x, y=y}
                    if V.dist(v, V.add(w.tileToPosition(tile), {x=16,y=16})) < v.lineOfSight*32 then
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

function World.placeTower(world, tilePosition, forcePlace)
    if tilePosition.x >= 1 and tilePosition.x <= world.towerTileMap.width and
            tilePosition.y >= 1 and tilePosition.y <= world.towerTileMap.height and
            world.structureTileMap.tiles[tilePosition.y][tilePosition.x].type == nil and
            (forcePlace or world.shroudTileMap.tiles[tilePosition.y][tilePosition.x].type == nil) and
            world.towerTileMap.tiles[tilePosition.y][tilePosition.x].type == nil then
        if forcePlace or world.money >= 25 then
            if not forcePlace then
                world.money = world.money - 25
            end
            local tile = world.towerTileMap.tiles[tilePosition.y][tilePosition.x]
            if tile.type == nil then
                tile.type = 'basic'
                tile.tower = Tower(world, (tilePosition.x-0.5)*world.towerTileMap.TILE_WIDTH, (tilePosition.y-0.5)*world.towerTileMap.TILE_HEIGHT)
                world:addItem(tile.tower)
                world.updateShroud = true
            end
        end
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

function World.draw(w)

    love.graphics.translate(-Resources.camera.x, -Resources.camera.y)

    w.floorTileMap:draw()
    w.towerTileMap:draw()
    
    for i, v in ipairs(w.items) do
        v:draw()
    end

    w.structureTileMap:draw()
    
    if w.drawShroud then
        w.shroudTileMap:draw()
    end

    love.graphics.origin()
    love.graphics.setColor(1,1,1)
    love.graphics.print("$" .. tostring(w.money), 10, 10)
    if w.won then
        love.graphics.print("You win! Press 'n' to go to the next level.", 50, 10)
    end

end

function collideRect(a, b)
    return a.x < b.x + b.w and
    a.x + a.w > b.x and
    a.y < b.y + b.h and
    a.y + a.h > b.y
end

function World.update(w, dt)

    if w.won then
        return
    end

    w.time = w.time + dt

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

    -- Win if the player gets $500 of excess cash.
    if w.money >= 500 then
        w.won = true
    end

end

return World
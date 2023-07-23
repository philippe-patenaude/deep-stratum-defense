local Object = require 'src.lib.base-class'
local TileMap = Object:extend()
local Resources = require 'src.resources'

local TILE_WIDTH = 32
local TILE_HEIGHT = 32

function TileMap.set(t, width, height, types, world)
    t.world = world
    t.TILE_WIDTH = TILE_WIDTH
    t.TILE_HEIGHT = TILE_HEIGHT
    t.tiles = {}
    t.width = width
    t.height = height
    t.types = types
    for y = 1, t.height do
        t.tiles[y] = {}
        for x = 1, t.width do
            t.tiles[y][x] = {type=nil, x=x, y=y}
        end
    end
end

function TileMap.get(t, position)
    return t.tiles[position.y][position.x]
end

function TileMap.draw(t)
    
    local cameraTile = t.world.positionToTile(Resources.camera)
    local windowDimensionsInTiles = t.world.positionToTile({x=love.graphics.getWidth(), y=love.graphics.getHeight()})
    local xStart = math.max(1, cameraTile.x)
    local yStart = math.max(1, cameraTile.y)
    local xEnd = math.min(t.width, cameraTile.x+windowDimensionsInTiles.x)
    local yEnd = math.min(t.height, cameraTile.y+windowDimensionsInTiles.y)

    for y = yStart, yEnd do
        for x = xStart, xEnd do
            local tile = t.tiles[y][x]
            if tile.type then
                if t.types[tile.type].image then
                    love.graphics.setColor(1,1,1)
                    if t.types[tile.type].quad then
                        love.graphics.draw(t.types[tile.type].image, t.types[tile.type].quad, (x-1)*TILE_WIDTH, (y-1)*TILE_HEIGHT)
                    else
                        love.graphics.draw(t.types[tile.type].image, (x-1)*TILE_WIDTH, (y-1)*TILE_HEIGHT)
                    end
                else
                    love.graphics.setColor(t.types[tile.type].color)
                    love.graphics.rectangle('fill', (x-1)*TILE_WIDTH, (y-1)*TILE_HEIGHT, TILE_WIDTH, TILE_HEIGHT)
                end
            end
        end
    end

end

return TileMap

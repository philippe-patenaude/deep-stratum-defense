local Object = require 'src.lib.base-class'
local Animation = Object:extend()

function Animation.set(b, image, frames, options)
    options = options or {}
    b.sx = options.sx or 1
    b.sy = options.sy or 1
    if options.loop == nil then
        b.loop = true
    else
        b.loop = options.loop
    end
    -- local startIndex = 28
    -- local startIndex = 5
    b.image = image
    -- local yPixel = startIndex*32
    b.frames = {}
    for _, f in ipairs(frames) do
        table.insert(b.frames, love.graphics.newQuad(f.x, f.y, f.w, f.h, b.image))
    end
    -- b.frames = {
    --     love.graphics.newQuad(0, yPixel, 32, 32, b.image),
    --     love.graphics.newQuad(32, yPixel, 32, 32, b.image),
    --     love.graphics.newQuad(64, yPixel, 32, 32, b.image),
    -- }
    b.time = 0
end

function Animation.update(b, dt)
    b.time = b.time + dt
end

function Animation.draw(b, x, y)
    local frameIndex = nil
    if b.loop then
        frameIndex = math.floor(b.time*4)%#b.frames+1
    else
        frameIndex = math.floor(b.time*4)+1
    end
    if frameIndex <= #b.frames then
        love.graphics.draw(b.image, b.frames[frameIndex], x, y, 0, b.sx, b.sy)
    end
end

return Animation

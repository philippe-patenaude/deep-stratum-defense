local Vectors = {}

function Vectors.dist(a, b)
    return math.sqrt(math.pow(b.x-a.x,2) + math.pow(b.y-a.y,2))
end

function Vectors.norm(v)
    local length = math.sqrt(v.x*v.x+v.y*v.y)
    local nx, ny = v.x/length, v.y/length
    return {x=nx, y=ny}
end

function Vectors.scale(v, s)
    return {x=v.x*s, y=v.y*s}
end

function Vectors.subtract(a, b)
    return {x=a.x-b.x, y=a.y-b.y}
end

function Vectors.add(a, b)
    return {x=a.x+b.x, y=a.y+b.y}
end

return Vectors

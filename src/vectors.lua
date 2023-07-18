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

-- Can provide two vectors or a vector and a scalar.
function Vectors.subtract(a, b)
    if type(b) == "number" then
        return {x=a.x-b, y=a.y-b}
    end
    return {x=a.x-b.x, y=a.y-b.y}
end

-- Can provide two vectors or a vector and a scalar.
function Vectors.add(a, b)
    if type(b) == "number" then
        return {x=a.x+b, y=a.y+b}
    end
    return {x=a.x+b.x, y=a.y+b.y}
end

return Vectors

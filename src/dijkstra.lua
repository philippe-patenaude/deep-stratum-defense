-- Dijkstra's algorithm implementation in Lua

-- Function to find the vertex with the minimum distance value
local function minDistance(tiles, maxDist)
    local min = math.huge
    local minIndex = nil

    for y = 1, #tiles do
        for x = 1, #tiles[1] do
            if not tiles[y][x].visited and tiles[y][x].distance <= min and tiles[y][x].distance <= maxDist then
                min = tiles[y][x].distance
                minIndex = {x=x, y=y}
            end
        end
    end

    return minIndex
end

-- Dijkstra's algorithm function
function dijkstra(graph, source, maxDist)
    maxDist = maxDist or math.huge
    -- Assume a 2d tile map.
    local width, height = #graph[1], #graph
    if source.x < 1 or source.x > width or
            source.y < 1 or source.y > height then
        return nil
    end
    -- tiles have a "distance", "visited", and "parents" parameters.
    local tiles = {}

    -- Initialize distances and visited arrays
    for y = 1, height do
        tiles[y] = {}
        for x = 1, width do
            table.insert(tiles[y], {})
            tiles[y][x].distance = math.huge
            -- Close off pathways that are blocked. This will allow the
            -- algorithm to exit early if there are no paths forward.
            if graph[y][x].type ~= nil then
                tiles[y][x].visited = true
            else
                tiles[y][x].visited = false
            end

            tiles[y][x].parent = nil
            tiles[y][x].x = x
            tiles[y][x].y = y
        end
    end

    -- Distance from source to itself is 0
    tiles[source.y][source.x].distance = 0

    -- Find shortest path for all vertices
    -- I might be able to change this to "while target hasn't been found yet."
    for _ = 1, width*height do
        -- Find the vertex with the minimum distance value
        local u = minDistance(tiles, maxDist)
        -- Exit early if there are no more walkable nodes to iterate over.
        if u == nil then
            return tiles
        end
        tiles[u.y][u.x].visited = true

        local offsets = {
                     {0,-1},
            {-1, 0},         {1, 0},
                     {0, 1},
        }
        for offset = 1, #offsets do
            local x, y = u.x+offsets[offset][1], u.y+offsets[offset][2]
            if tiles[y] and tiles[y][x] and not tiles[y][x].visited and graph[y] and graph[y][x]
                    and graph[y][x].type == nil and tiles[u.y][u.x].distance + 1 < tiles[y][x].distance then
                tiles[y][x].distance = tiles[u.y][u.x].distance + 1
                tiles[y][x].parent = tiles[u.y][u.x]
            end
        end
    end

    return tiles
end

return dijkstra

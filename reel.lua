-- The reel consumes a preselected winner. There is deliberately no RNG here.
local Reel = {}

function Reel.new(entries, winner)
    local index
    for i, boss in ipairs(entries) do if boss.id == winner.id then index = i end end
    assert(index, 'Winner must be in the reel pool')
    return {entries=entries, winner=winner, elapsed=0, duration=2, position=0,
        target=20 + ((index - 1 - 20) % #entries), done=false}
end

function Reel.advance(spin, seconds)
    if type(seconds) ~= 'number' or seconds ~= seconds or seconds < 0 then return end
    spin.elapsed = math.min(spin.duration, spin.elapsed + seconds)
    local progress = spin.elapsed / spin.duration
    spin.position = spin.target * (1 - (1 - progress)^3)
    spin.done = progress >= 1
end

function Reel.tiles(entries, position, width, tileWidth)
    local tiles = {}
    if #entries == 0 or width <= 0 or tileWidth <= 0 then return tiles end
    local radius = math.ceil(width / tileWidth / 2) + 1
    local center = math.floor(position)
    for index = center - radius, center + radius do
        local x = width / 2 + (index - position - 0.5) * tileWidth
        if x + tileWidth > 0 and x < width then
            tiles[#tiles + 1] = {boss=entries[(index % #entries) + 1], x=x, width=tileWidth}
        end
    end
    return tiles
end

return Reel

-- Pure ticket arithmetic. No UI, game progression, persistence or animation.
local Pool = {}

function Pool.validWeight(weight)
    return type(weight) == 'number' and weight >= 1 and weight <= 10 and weight % 1 == 0
end

function Pool.entries(roster, prefs)
    local entries = {}
    for _, boss in ipairs(roster) do
        local pref = prefs and prefs[boss.id]
        if pref and pref.enabled == true and Pool.validWeight(pref.weight) then
            entries[#entries + 1] = {id=boss.id, name=boss.name, short=boss.short, weight=pref.weight}
        end
    end
    return entries
end

function Pool.total(entries)
    local total = 0
    for _, boss in ipairs(entries) do total = total + boss.weight end
    return total
end

function Pool.ticket(entries, ticket)
    local total = Pool.total(entries)
    assert(type(ticket) == 'number' and ticket % 1 == 0 and ticket >= 1 and ticket <= total, 'Ticket outside pool')
    local cumulative = 0
    for _, boss in ipairs(entries) do
        cumulative = cumulative + boss.weight
        if ticket <= cumulative then return boss end
    end
end

function Pool.draw(entries, randomInteger)
    local total = Pool.total(entries)
    if total == 0 then return nil end
    return Pool.ticket(entries, randomInteger(1, total))
end

function Pool.chance(entries, bossID)
    local total = Pool.total(entries)
    if total == 0 then return 0 end
    for _, boss in ipairs(entries) do
        if boss.id == bossID then return boss.weight * 100 / total end
    end
    return 0
end

return Pool

local Pool = require('pool')
local Preferences = {}

local function key(identity)
    if type(identity) ~= 'string' or identity == '' then return nil end
    return 'reaper_roulette:character:' .. identity
end

function Preferences.copy(prefs)
    local result = {}
    for id, pref in pairs(prefs) do
        result[id] = {enabled=pref.enabled, weight=pref.weight}
    end
    return result
end

function Preferences.load(db, identity, roster)
    local storageKey = key(identity)
    if not storageKey then return nil, 'Waiting for character identification.' end
    local ok, saved = pcall(function() return db:Get(storageKey) end)
    if not ok then return nil, 'Could not load settings. Retry when ready.' end
    local prefs = {}
    if saved ~= nil then
        if type(saved) ~= 'table' or saved.schema ~= 1 or type(saved.bosses) ~= 'table' then
            return nil, 'Settings format is unsupported. Saved data was kept.'
        end
        for id, pref in pairs(saved.bosses) do
            if type(id) ~= 'string' or type(pref) ~= 'table' or type(pref.enabled) ~= 'boolean' or not Pool.validWeight(pref.weight) then
                return nil, 'Settings are damaged. Saved data was kept.'
            end
            prefs[id] = {enabled=pref.enabled, weight=pref.weight}
        end
    end
    for _, boss in ipairs(roster) do
        if prefs[boss.id] == nil then prefs[boss.id] = {enabled=true, weight=1} end
    end
    return prefs
end

function Preferences.save(db, identity, prefs)
    local storageKey = key(identity)
    if not storageKey then return false, 'Waiting for character identification.' end
    local ok, saved = pcall(function()
        return db:Set(storageKey, {schema=1, bosses=Preferences.copy(prefs)})
    end)
    if not ok or saved ~= true then
        return false, 'Could not save change. Previous settings kept; try again.'
    end
    return true
end

return Preferences

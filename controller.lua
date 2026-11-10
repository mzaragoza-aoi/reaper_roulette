local Pool = require('pool')
local Preferences = require('preferences')
local Reel = require('reel')
local Controller = {}
Controller.__index = Controller

function Controller.new(deps)
    return setmetatable({deps=deps, roster=deps.roster, generation=0, spinning=false, opened=false}, Controller)
end

function Controller:changed()
    self.deps.changed()
end

function Controller:cancel(quiet)
    self.generation = self.generation + 1
    self.deps.unsubscribe()
    self.spin, self.winner, self.spinning = nil, nil, false
    if not quiet then self:changed() end
end

function Controller:syncIdentity(retry)
    local identity = self.deps.identity()
    if identity == self.character and not retry then return false end
    self:cancel(true)
    self.character, self.prefs, self.error = identity, nil, nil
    if identity then
        self.prefs, self.error = Preferences.load(self.deps.db, identity, self.roster)
    end
    self:changed()
    return true
end

function Controller:entries()
    return Pool.entries(self.roster, self.prefs)
end

function Controller:status()
    if self.error then return self.error end
    if not self.character then return 'Waiting for character identification. Log in, or Retry.' end
    if not self.prefs then return 'Settings unavailable. Retry to load.' end
    if #self:entries() == 0 then return 'Enable a boss in Settings to roll.' end
    if self.spinning then return 'Rolling...' end
    if self.winner then return self.winner.name end
    return 'Ready to roll'
end

function Controller:edit(expectedCharacter, bossID, field, value)
    self:syncIdentity()
    if not self.character or expectedCharacter ~= self.character or not self.prefs then return false end
    local known = false
    for _, boss in ipairs(self.roster) do if boss.id == bossID then known = true; break end end
    if not known then return false end
    if field == 'enabled' then
        if type(value) ~= 'boolean' then return false end
    elseif field == 'weight' then
        if not Pool.validWeight(value) then return false end
    else return false end
    if self.prefs[bossID][field] == value then return true end
    local nextPrefs = Preferences.copy(self.prefs)
    nextPrefs[bossID][field] = value
    local ok, err = Preferences.save(self.deps.db, self.character, nextPrefs)
    self.error = err
    if ok then
        self.prefs = nextPrefs
        -- Cancel any membership change so no excluded tile survives in the strip.
        if field == 'enabled' then self:cancel(true) end
    end
    self:changed()
    return ok
end

function Controller:open()
    self:cancel(true)
    self.opened = true
    self:syncIdentity()
    self:changed()
end

function Controller:close()
    self.opened = false
    self:cancel()
end

function Controller:poll()
    self:syncIdentity()
    if self.opened and not self.deps.visible() then self:close() end
end

function Controller:roll()
    if self:syncIdentity() then return false end
    if self.spinning or not self.opened or not self.deps.visible() or not self.prefs then return false end
    local entries = self:entries()
    if #entries == 0 then return false end
    self.error, self.winner = nil, nil
    if #entries == 1 then
        self.winner = entries[1]
        self:changed()
        return true
    end
    local winner = Pool.draw(entries, self.deps.random) -- Exactly one random integer.
    self.generation = self.generation + 1
    local generation = self.generation
    self.spin, self.spinning = Reel.new(entries, winner), true
    self.deps.subscribe(function(seconds)
        if self.generation ~= generation or not self.spinning then return end
        self:poll() -- Identity and visibility are checked BEFORE publishing a frame.
        if self.generation ~= generation or not self.spinning then return end
        Reel.advance(self.spin, seconds)
        if self.spin.done then
            self.winner, self.spinning = self.spin.winner, false
            self.deps.unsubscribe()
        end
        self:changed()
    end)
    self:changed()
    return true
end

return Controller

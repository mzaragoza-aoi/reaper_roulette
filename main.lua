-- Native RS3 entry point. See docs/api-notes.md for verified API contracts.
local Controller = require('controller')
local Views = require('views')
local ribbon, settings, controller
local inWorld -- Before the first state event, Player.IsAvailable is authoritative.
local FRAME_ID = 'reaper_roulette_spin'

local function identity()
    if inWorld == false or not Player.IsAvailable() then return nil end
    local entity = Player.GetEntity()
    if not entity or not entity.isValid then return nil end
    local name = entity.displayName
    if type(name) ~= 'string' or not name:find('%S') then return nil end
    -- PersistentDB documents character names as a per-character storage key.
    -- Keep the exact name in a separate namespace from older tracking-ID saves.
    -- A display-name change starts a new profile; no shared fallback is used.
    return 'name:' .. name
end

local function refresh()
    if ribbon then ribbon:refresh() end
    if settings then settings:refresh() end
end

controller = Controller.new({
    roster=require('bosses'), db=PersistentDB, identity=identity,
    random=function(low,high) return math.random(low,high) end,
    subscribe=function(callback)
        Event.Draw.Subscribe(FRAME_ID,function(event) callback(event.timeDeltaSecs) end)
    end,
    unsubscribe=function() Event.Draw.Unsubscribe(FRAME_ID) end,
    visible=function() return ribbon ~= nil and ribbon:visible() end,
    changed=refresh,
})

Event.ContentLayerReady.Subscribe('reaper_roulette_content',function(event)
    controller:close()
    if ribbon then ribbon:destroy() end
    ribbon=Views.ribbon(event.component,controller)
    controller:open()
end)

Event.SettingsLayerReady.Subscribe('reaper_roulette_settings',function(event)
    controller:syncIdentity()
    if settings then settings:destroy() end
    settings=Views.settings(event.component,controller)
end)

Event.GameStateChanged.Subscribe('reaper_roulette_character',function(event)
    inWorld = event.newState == GameState.GAME
    controller:cancel(true)
    controller:syncIdentity()
    refresh()
end)

-- A lightweight plugin-lifetime watcher remains while the ribbon is closed so
-- delayed player entities can become ready. It never advances the reel or saves data.
Event.Logic.Subscribe('reaper_roulette_lifecycle',function()
    controller:poll()
    if ribbon and not ribbon:alive() then ribbon:destroy(); ribbon=nil end
    if settings and not settings:alive() then settings:destroy(); settings=nil end
    if ribbon and ribbon:visible() and not controller.opened then controller:open() end
end)

controller:syncIdentity()

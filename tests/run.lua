package.path = './?.lua;./?/init.lua;' .. package.path
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function eq(a, b) assert(a == b, tostring(a) .. ' ~= ' .. tostring(b)) end
local function near(a, b) assert(math.abs(a - b) < 0.000001) end
local function copy(t)
    if type(t) ~= 'table' then return t end
    local result = {}; for k, v in pairs(t) do result[k] = copy(v) end; return result
end
local function database()
    local db = {data = {}, reads = 0, writes = 0}
    function db:Get(key) self.reads = self.reads + 1; return copy(self.data[key]) end
    function db:Set(key, value)
        self.writes = self.writes + 1
        if self.fail then return false end
        self.data[key] = copy(value); return true
    end
    return db
end
local roster = {
    {id = 'rasial', name = 'Rasial, the First Necromancer', short = 'Rasial'},
    {id = 'raksha', name = 'Raksha, the Shadow Colossus', short = 'Raksha'},
    {id = 'arch_glacor', name = 'Arch-Glacor', short = 'Arch-Glacor'},
}
local function fixture()
    local db, frames = database(), {}
    local env = {identity = 'character-A', visible = true, calls = 0, frames = frames, db = db}
    env.controller = require('controller').new({roster = roster, db = db,
        identity = function() return env.identity end,
        random = function(low, high) env.calls = env.calls + 1; eq(low, 1); return env.ticket or high end,
        subscribe = function(fn) frames.current = fn end,
        unsubscribe = function() frames.current = nil end,
        visible = function() return env.visible end,
        changed = function() end,
    })
    env.controller:syncIdentity(); env.controller:open()
    return env, env.controller
end

test('every one of 13 tickets maps exactly 10, 2, 1', function()
    local p = require('pool')
    local entries = p.entries(roster, {rasial={enabled=true,weight=10}, raksha={enabled=true,weight=2}, arch_glacor={enabled=true,weight=1}})
    local counts = {rasial=0,raksha=0,arch_glacor=0}
    for ticket = 1, 13 do
        local expected = ticket <= 10 and 'rasial' or (ticket <= 12 and 'raksha' or 'arch_glacor')
        local winner = p.ticket(entries, ticket); eq(winner.id, expected)
        counts[winner.id] = counts[winner.id] + 1
    end
    eq(counts.rasial,10); eq(counts.raksha,2); eq(counts.arch_glacor,1)
    near(p.chance(entries, 'rasial'), 1000/13); near(p.chance(entries, 'raksha'), 200/13)
    near(p.chance(entries, 'arch_glacor'),100/13)
    assert(not pcall(p.ticket, entries, 0)); assert(not pcall(p.ticket, entries, 14))
end)

test('roster includes combat and skilling encounters plus Abomination and Char once', function()
    local bosses = require('bosses'); local seen, names = {}, {}
    for _, boss in ipairs(bosses) do
        assert(not seen[boss.id] and not names[boss.name]); seen[boss.id]=true; names[boss.name]=true
    end
    assert(seen.amascut and seen.ivar and seen.silverquill and seen.ghrazi_blood_knights and seen.flesh_hatcher)
    assert(seen.nex and seen.nex_aod and seen.rex_matriarchs and seen.legiones)
    for _,id in ipairs({'abomination','char','beastmaster_durzag',
            'dragith_nurn','exiled_kalphite_queen','giant_mimic','osseous','tormented_wraith','yakamaru',
            'seiryu','black_stone_dragon','ambassador','nakatra',
            'croesus','gate_of_elidinis'}) do
        assert(seen[id],'Missing requested roster entry: '..id)
    end
    for _,id in ipairs({'astellarn','kezalam','masuta','sanctum_guardian','taraket',
            'verak_lith','vermyx','crassian_leviathan','wildywyrm'}) do
        assert(not seen[id],'Removed encounter remains in roster: '..id)
    end
    assert(not seen.araxxor) -- Araxxor/Araxxi are one encounter.
    local prefs = assert(require('preferences').load(database(), 'A', bosses))
    eq(#require('pool').entries(bosses, prefs), #bosses)
    for _, row in pairs(prefs) do eq(row.enabled,true); eq(row.weight,1) end
end)

test('expanding the roster preserves saved settings and defaults new bosses On at 1x',function()
    local preferences=require('preferences'); local db=database()
    assert(preferences.save(db,'A',{arch_glacor={enabled=false,weight=8},rasial={enabled=true,weight=10}}))
    local prefs=assert(preferences.load(db,'A',require('bosses')))
    eq(prefs.arch_glacor.enabled,false); eq(prefs.arch_glacor.weight,8); eq(prefs.rasial.weight,10)
    for _,id in ipairs({'abomination','char','osseous','yakamaru'}) do
        assert(prefs[id],'New boss missing from saved profile: '..id)
        eq(prefs[id].enabled,true); eq(prefs[id].weight,1)
    end
    eq(db.writes,1) -- Loading an expanded roster does not overwrite the save.
end)

test('no unlock, blessing, or task is needed to configure and roll', function()
    local env, c = fixture() -- Host exposes identity only: no unlock/task APIs exist.
    assert(c:edit('character-A', 'rasial', 'weight', 10))
    assert(c:roll()); eq(env.calls,1); assert(c.spinning)
    env.frames.current(2); eq(c.winner.id,'arch_glacor'); assert(not c.spinning)
end)

test('disabled boss never wins or appears on reel; empty and single pools', function()
    local env, c = fixture()
    c:edit('character-A','rasial','enabled',false)
    local p, reel = require('pool'), require('reel')
    for ticket=1,2 do assert(p.ticket(c:entries(),ticket).id ~= 'rasial') end
    for _, tile in ipairs(reel.tiles(c:entries(), 12.4, 390, 140)) do assert(tile.boss.id ~= 'rasial') end
    near(p.chance(c:entries(),'rasial'),0)
    c:edit('character-A','raksha','enabled',false)
    assert(c:roll()); eq(c.winner.id,'arch_glacor'); assert(not c.spinning); eq(env.calls,0)
    c:edit('character-A','arch_glacor','enabled',false)
    assert(not c:roll()); eq(c.winner,nil); eq(#c:entries(),0)
    eq(c:status(),'Enable a boss in Settings to roll.'); eq(env.frames.current,nil)
end)

test('weight survives off, reload, edit while off, re-enable and reload', function()
    local env, c = fixture()
    c:edit('character-A','arch_glacor','weight',8)
    c:edit('character-A','arch_glacor','enabled',false)
    local prefs = assert(require('preferences').load(env.db,'character-A',roster))
    eq(prefs.arch_glacor.weight,8); eq(prefs.arch_glacor.enabled,false)
    c.prefs = prefs
    c:edit('character-A','arch_glacor','weight',9); eq(c.prefs.arch_glacor.enabled,false)
    c:edit('character-A','arch_glacor','enabled',true)
    prefs = assert(require('preferences').load(env.db,'character-A',roster))
    eq(prefs.arch_glacor.weight,9); eq(prefs.arch_glacor.enabled,true); eq(env.db.writes,4)
end)

test('two characters retain separate preferences on one device', function()
    local env, c = fixture(); c:edit('character-A','rasial','weight',10)
    env.identity='character-B'; c:syncIdentity(); eq(c.prefs.rasial.weight,1)
    c:edit('character-B','raksha','enabled',false)
    env.identity='character-A'; c:syncIdentity(); eq(c.prefs.rasial.weight,10); eq(c.prefs.raksha.enabled,true)
    env.identity='character-B'; c:syncIdentity(); eq(c.prefs.raksha.enabled,false)
end)

test('missing identity never reads or writes a shared pool and retry succeeds', function()
    local env, c = fixture(); env.identity=nil; c:syncIdentity()
    local reads,writes=env.db.reads,env.db.writes
    assert(not c:roll()); assert(not c:edit(nil,'rasial','weight',2))
    c:syncIdentity(); eq(env.db.reads,reads); eq(env.db.writes,writes); eq(c.prefs,nil)
    env.identity='character-B'; c:syncIdentity(); assert(c:roll())
end)

test('save failure rolls back and invalid weights are rejected', function()
    local env,c=fixture(); env.db.fail=true
    assert(not c:edit('character-A','rasial','weight',8)); eq(c.prefs.rasial.weight,1); assert(c.error)
    for _, value in ipairs({0,11,1.5,'8'}) do assert(not c:edit('character-A','rasial','weight',value)) end
    eq(env.db.writes,1)
end)

test('malformed and future-schema storage are not overwritten', function()
    local preferences=require('preferences'); local db=database()
    assert(not preferences.load(db,nil,roster)); eq(db.reads,0)
    assert(preferences.save(db,'A',{rasial={enabled=false,weight=7}}))
    local key=next(db.data); db.data[key]='broken'
    assert(not preferences.load(db,'A',roster)); eq(db.writes,1)
    db.data[key]={schema=99,bosses={}}; assert(not preferences.load(db,'A',roster))
end)

test('repeated clicks draw once; original winner survives weight changes', function()
    local env,c=fixture(); env.ticket=1; assert(c:roll()); local old=c.spin.winner
    for _=1,10 do assert(not c:roll()) end
    eq(env.calls,1); c:edit('character-A','rasial','weight',10)
    env.frames.current(1); assert(c.spinning); eq(c.winner,nil)
    env.frames.current(1); eq(c.winner.id,old.id); eq(env.frames.current,nil)
    assert(c:roll()); env.frames.current(2); eq(c.winner.id,'rasial'); eq(env.calls,2)
end)

test('reel moves right-to-left, eases out, and centers original winner', function()
    local env,c=fixture(); local reel=require('reel'); local entries=c:entries()
    for _,winner in ipairs(entries) do
        local spin=reel.new(entries,winner)
        local p0=spin.position
        reel.advance(spin,0.5); local p1=spin.position
        reel.advance(spin,0.5); local p2=spin.position
        assert(p1>p0 and p2>p1 and p1-p0>p2-p1)
        reel.advance(spin,1); assert(spin.done)
        local tiles=reel.tiles(entries,spin.position,390,140); local center
        for _,tile in ipairs(tiles) do
            eq(tile.width,140)
            if math.abs(tile.x+70-195)<0.001 then center=tile.boss end
        end
        eq(center.id,winner.id)
    end
end)

test('cancel, close, hidden panel and character changes invalidate queued frames', function()
    for _,reason in ipairs({'cancel','close','hidden','switch','logout'}) do
        local env,c=fixture(); c:roll(); local queued=env.frames.current
        if reason=='cancel' then c:cancel()
        elseif reason=='close' then c:close()
        elseif reason=='hidden' then env.visible=false; c:poll()
        elseif reason=='switch' then env.identity='B'; c:syncIdentity()
        else env.identity=nil; c:syncIdentity() end
        eq(env.frames.current,nil); queued(100); eq(c.winner,nil); assert(not c.spinning)
    end
end)

test('membership edit cancels before any disabled tile is rendered', function()
    for _, boss in ipairs({'rasial','arch_glacor'}) do
        local env,c=fixture(); c:roll(); local queued=env.frames.current
        c:edit('character-A',boss,'enabled',false)
        queued(2); eq(c.winner,nil); eq(env.frames.current,nil)
        for _,entry in ipairs(c:entries()) do assert(entry.id~=boss) end
    end
end)

test('old callbacks cannot complete a later spin or edit another character', function()
    local env,c=fixture(); c:roll(); local queued=env.frames.current
    c:cancel(); c:roll(); queued(100); assert(c.spinning); eq(c.winner,nil)
    env.identity='B'
    assert(not c:edit('character-A','rasial','weight',9)); eq(c.prefs.rasial.weight,1)
    queued(100); eq(c.winner,nil)
end)

-- Native host-boundary tests are loaded when the integration module is added.
local native = io.open('tests/native.lua','r')
if native then native:close(); require('tests/native')(test,eq,near) end
print(string.format('\n%d passed, %d failed',passed,failed))
os.exit(failed == 0 and 0 or 1)

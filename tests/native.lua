return function(test,eq,near)
    local Host=require('tests/host')
    test('Settings builds beyond its heading using documented alignment values',function()
        local host=Host.new({permission=false}); host:start()
        local settings=host:layer('Settings',580,300)
        assert(host:text(settings,'Your boss pool'))
        assert(host:button(host:row(settings,'Amascut, the Devourer'),'On'))
        assert(host:button(settings,'Next').enabled)
        local ribbon=host:layer('Content')
        assert(host:text(ribbon,tostring(#require('bosses'))..' bosses'))
        assert(host:button(ribbon,'Roll a boss').enabled)
    end)
    test('player without Tracking permission can save settings and finish a spin',function()
        local host=Host.new({permission=false}); host:start()
        local settings=host:layer('Settings'); local ribbon=host:layer('Content')
        assert(host:button(ribbon,'Roll a boss').enabled,'Roll must not require Tracking permission')
        host:click(host:button(host:row(settings,'Arch-Glacor'),'+'))
        eq(host.data['reaper_roulette:character:name:Reaper One'].bosses.arch_glacor.weight,2)
        host:click(host:button(ribbon,'Roll a boss')); host:frame(2)
        assert(host:text(ribbon,'Amascut, the Devourer')); eq(host.draws,1)
    end)

    test('name profiles survive restart and switching names cancels stale results',function()
        local host=Host.new({permission=false}); host:start()
        local settings=host:layer('Settings'); local ribbon=host:layer('Content')
        host:click(host:button(host:row(settings,'Arch-Glacor'),'+'))
        host:click(host:button(host:row(settings,'Arch-Glacor'),'On'))
        host:click(host:button(ribbon,'Roll a boss')); local queued=assert(host:frameCallback())
        host.entity.displayName='Reaper Two'; host:emit('Logic')
        queued({timeDeltaSecs=5}); eq(host:frameCallback(),nil)
        assert(host:text(ribbon,'Ready to roll'))
        assert(host:button(host:row(settings,'Arch-Glacor'),'On'))
        host:click(host:button(host:row(settings,'Amascut, the Devourer'),'On'))
        local restarted=Host.new({permission=false,data=host.data}); restarted:start()
        settings=restarted:layer('Settings')
        local arch=restarted:row(settings,'Arch-Glacor')
        assert(restarted:button(arch,'Off')); assert(restarted:text(arch,'2×'))
        assert(restarted:button(restarted:row(settings,'Amascut, the Devourer'),'On'))
        restarted.entity.displayName='Reaper Two'; restarted:emit('Logic')
        assert(restarted:button(restarted:row(settings,'Amascut, the Devourer'),'Off'))
    end)

    test('missing or invalid player entity and empty names never load a shared profile',function()
        local invalid=setmetatable({isValid=false},{__index=function() error('Invalid entity was read') end})
        for _,entity in ipairs({false,invalid,{isValid=true,displayName=''},
                {isValid=true,displayName='   '},{isValid=true}}) do
            local host=Host.new({permission=false}); host.entity=entity or nil; host:start()
            local ribbon=host:layer('Content'); local settings=host:layer('Settings')
            eq(host.reads,0); eq(host.writes,0)
            assert(not host:button(ribbon,'Roll a boss').enabled)
            host:click(host:button(settings,'Retry')); eq(host.reads,0)
            host.entity={isValid=true,displayName='Ready Player'}; host:emit('Logic')
            assert(host:button(ribbon,'Roll a boss').enabled); eq(host.reads,1)
        end
    end)
    test('short panels keep roll, every settings page and failed-save controls in bounds',function()
        local function check(root,node,x,y)
            x,y=x+node.x,y+node.y
            if node._state.kind=='Button' and node.visibleGlobal then
                assert(x>=0 and y>=0 and x+node.width<=root.width and y+node.height<=root.height,
                    node.label..' outside '..root.width..'x'..root.height..' at '..x..','..y)
            end
            for _,child in ipairs(node._state.children) do if not child._state.dead then check(root,child,x,y) end end
        end
        for _,size in ipairs({{240,200},{200,220},{425,265}}) do
            local host=Host.new(); host:start(); local ribbon=host:layer('Content',size[1],size[2])
            check(ribbon,ribbon,0,0)
            local settings=host:layer('Settings',size[1],size[2]); check(settings,settings,0,0)
            host.failSave=true
            host:click(host:button(host:row(settings,'Amascut, the Devourer'),'On'))
            check(settings,settings,0,0); check(ribbon,ribbon,0,0)
            repeat
                local nextButton=host:button(settings,'Next')
                if not nextButton.enabled then break end
                host:click(nextButton); check(settings,settings,0,0)
            until false
        end
    end)

    test('repeated save failures restore the native toggle to the persisted state',function()
        local host=Host.new(); host:start(); local settings=host:layer('Settings')
        host.failSave=true
        for _=1,3 do
            local toggle=host:button(host:row(settings,'Amascut, the Devourer'),'On')
            host:click(toggle)
            toggle=host:button(host:row(settings,'Amascut, the Devourer'),'On')
            eq(toggle.isToggled,true)
        end
        eq(host.writes,3)
    end)
    test('native ribbon and Settings work for an unrestricted player; all roster pages accessible',function()
        local host=Host.new(); host:start()
        local settings=host:layer('Settings'); local ribbon=host:layer('Content',425,265)
        assert(host:button(ribbon,'Roll a boss').enabled)
        local seen={}
        repeat
            for _,boss in ipairs(require('bosses')) do if host:text(settings,boss.name) then seen[boss.id]=true end end
            local nextButton=host:button(settings,'Next')
            if not nextButton.enabled then break end
            host:click(nextButton)
        until false
        for _,boss in ipairs(require('bosses')) do assert(seen[boss.id],boss.name..' inaccessible') end
        host:click(host:button(ribbon,'Roll a boss')); local callback=host:frameCallback(); assert(callback)
        host:click(host:button(ribbon,'Rolling...')); eq(host.draws,1)
        host:frame(2); assert(host:text(ribbon,'Amascut, the Devourer')); eq(host:frameCallback(),nil)
    end)

    test('native settings retain off weights and refresh actual odds and ribbon immediately',function()
        local host=Host.new(); host:start(); local settings=host:layer('Settings'); local ribbon=host:layer('Content')
        local function row() return host:row(settings,'Arch-Glacor') end
        for _=1,7 do host:click(host:button(row(),'+')) end
        assert(host:text(row(),'8×')); host:click(host:button(row(),'On'))
        assert(host:text(row(),'8×')); assert(host:text(row(),'0%'))
        host:click(host:button(row(),'+')); assert(host:button(row(),'Off')); assert(host:text(row(),'9×'))
        host:click(host:button(row(),'Off'))
        assert(host:text(row(),string.format('%.2f%%',900/(#require('bosses')+8))))
        eq(host.writes,10)
        local stored=host.data['reaper_roulette:character:name:Reaper One']
        assert(stored); eq(stored.bosses.arch_glacor.weight,9); eq(stored.bosses.arch_glacor.enabled,true)
        assert(host:button(ribbon,'Roll a boss').enabled)
    end)

    test('native delayed identification disables actions without touching persistence',function()
        local host=Host.new(); host.entity=nil; host:start()
        local settings=host:layer('Settings'); local ribbon=host:layer('Content')
        eq(host.reads,0); eq(host.writes,0); assert(not host:button(ribbon,'Roll a boss').enabled)
        host:click(host:button(settings,'Retry')); eq(host.reads,0)
        host.entity={isValid=true,displayName='Ready Player'}; host:emit('Logic',{logicTick=50})
        assert(host:button(ribbon,'Roll a boss').enabled); eq(host.reads,1)
    end)

    test('native empty and single pools use full names at narrow widths',function()
        local host=Host.new(); local prefs={}
        for _,boss in ipairs(require('bosses')) do prefs[boss.id]={enabled=false,weight=1} end
        require('preferences').save(PersistentDB,'name:'..host.entity.displayName,prefs)
        host:start(); local ribbon=host:layer('Content',240,280)
        assert(not host:button(ribbon,'Roll a boss').enabled)
        assert(host:text(ribbon,'Enable a boss in Settings to roll.'))
        local settings=host:layer('Settings',240,480)
        host:click(host:button(host:row(settings,'Amascut, the Devourer'),'Off'))
        host:click(host:button(ribbon,'Roll a boss'))
        local winner=assert(host:text(ribbon,'Amascut, the Devourer')); eq(winner.maxLines,0)
        eq(host.draws,0); eq(host:frameCallback(),nil)
    end)

    test('hidden ancestor or destroyed ribbon cancels and releases the frame subscription',function()
        for _,destroy in ipairs({false,true}) do
            local host=Host.new(); host:start(); local ribbon=host:layer('Content')
            host:click(host:button(ribbon,'Roll a boss')); local queued=host:frameCallback()
            if destroy then ribbon:Destroy() else ribbon.hidden=true end
            host:emit('Logic',{logicTick=1}); eq(host:frameCallback(),nil)
            queued({timeDeltaSecs=5})
            local newRibbon=host:layer('Content'); assert(host:text(newRibbon,'Ready to roll'))
            assert(not host:text(newRibbon,'Amascut, the Devourer'))
        end
    end)

    test('native content replacement and game-state transition invalidate queued results',function()
        local host=Host.new(); host:start(); local ribbon=host:layer('Content')
        host:click(host:button(ribbon,'Roll a boss')); local queued=host:frameCallback()
        local replacement=host:layer('Content'); queued({timeDeltaSecs=5})
        assert(host:text(replacement,'Ready to roll')); eq(host:frameCallback(),nil)
        host:click(host:button(replacement,'Roll a boss')); queued=host:frameCallback()
        host.available=false; host:emit('GameStateChanged',{newState=GameState.LOBBY,oldState=GameState.GAME})
        queued({timeDeltaSecs=5}); eq(host:frameCallback(),nil)
        assert(not host:text(replacement,'Amascut, the Devourer'))
    end)

    test('native winning boss exclusion cancels; old settings callbacks cannot cross characters',function()
        local host=Host.new(); host:start(); local settings=host:layer('Settings'); local ribbon=host:layer('Content')
        local toggle=host:button(host:row(settings,'Amascut, the Devourer'),'On')
        local _,oldEdit=next(toggle._state.hooks.press)
        host:click(host:button(ribbon,'Roll a boss')); local queued=host:frameCallback()
        host:click(toggle); queued({timeDeltaSecs=4}); eq(host:frameCallback(),nil)
        assert(host:text(ribbon,'Ready to roll')); host.entity.displayName='Reaper Two'
        host:emit('Logic',{logicTick=1}); local writes=host.writes
        oldEdit(toggle,1,0); eq(host.writes,writes)
        assert(host:button(host:row(settings,'Amascut, the Devourer'),'On'))
    end)
end

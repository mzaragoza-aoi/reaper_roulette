local Pool = require('pool')
local Reel = require('reel')
local Views = {}
local GOLD, TEXT, MUTED = 0xE2BE72FF, 0xF0E5CFFF, 0xADBDBAFF
local BACKGROUND, HEADER = 0x091D23FF, 0x203638FF
local TILE_COLOURS = {0x245860FF, 0x4B4263FF, 0x613F38FF, 0x344D43FF}

local function label(parent, content, x, y, w, h, colour)
    local text = ui.Text.new(parent)
    text:SetPos(x,y); text:SetSize(w,h)
    text.font = id.Font.MUSEO_SANS_15PT_REGULAR
    text.content, text.rgba, text.maxLines = content, colour or TEXT, 0
    text:AlignTo(ui.AlignMode.TOPLEFT,ui.AlignMode.CENTRE)
    text.clickthrough = true
    return text
end

local function button(parent, content, x, y, w, h, callback)
    local btn = ui.Button.new(parent)
    btn:SetPos(x,y); btn:SetSize(w,h)
    btn.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
    btn.label, btn.mode = content, ui.TriggerMode.ONPRESS
    btn:Subscribe(ui.Hook.ONBUTTONPRESSED,'action',callback)
    return btn
end

local function base(root)
    local view = {root=root, layer=ui.Layer.new(root), disposed=false}
    function view:alive()
        if self.disposed then return false end
        local ok, width = pcall(function() return self.layer.width end)
        return ok and type(width) == 'number'
    end
    function view:visible()
        if not self:alive() then return false end
        local ok, visible = pcall(function() return self.layer.visibleGlobal end)
        return ok and visible == true
    end
    function view:destroy()
        self.disposed = true
        pcall(function() self.root:Unsubscribe(ui.Hook.ONRESIZE,'reaper_layout') end)
        pcall(function() self.layer:Destroy() end)
    end
    function view:dimensions()
        return math.max(1,self.root.width), math.max(1,self.root.height)
    end
    root:Subscribe(ui.Hook.ONRESIZE,'reaper_layout',function()
        if view:alive() then view:refresh(true) end
    end)
    return view
end

function Views.ribbon(root, controller)
    local view = base(root)
    local canvas = ui.Canvas.new(view.layer)
    canvas.clickthrough = true
    local title = label(view.layer,'Reaper Roulette',12,6,240,34,GOLD)
    local count = label(view.layer,'',0,6,100,34,MUTED)
    count:AlignTo(ui.AlignMode.CENTRE)
    local result = label(view.layer,'',12,144,380,64,GOLD)
    local roll = button(view.layer,'Roll a boss',0,0,132,36,function()
        if view:visible() then controller:roll() end
    end)
    local retry = button(view.layer,'Retry',12,0,76,36,function()
        if view:visible() then controller:syncIdentity(true) end
    end)
    local textConfig = ui.TextDataConfig.new()
    textConfig.font = id.Font.MUSEO_SANS_15PT_REGULAR
    textConfig.alignHorizontal, textConfig.alignVertical = ui.AlignMode.CENTRE, ui.AlignMode.CENTRE
    textConfig.colour = Vector4.new(0.94,0.9,0.81,1)
    textConfig.maxLines = 2

    function view:refresh()
        if not self:alive() then return end
        local w,h = self:dimensions()
        self.layer:SetSize(w,h); canvas:SetSize(w,h)
        local entries = controller:entries()
        count.content = tostring(#entries)..' bosses'
        count.hidden = w < 320
        count:SetPos(w-112,6)
        title:SetSize(w >= 320 and w-128 or w-24,34)
        local compact = h < 246
        local buttonY = math.max(0,h-48)
        local retryVisible = controller.prefs == nil or controller.error ~= nil
        local buttonWidth = retryVisible and w<320 and math.max(80,w-112) or 132
        roll:SetSize(buttonWidth,36)
        roll:SetPos(math.max(12,w-buttonWidth-12),buttonY)
        retry:SetPos(12,buttonY)
        retry.hidden = not retryVisible
        roll.enabled = controller.prefs ~= nil and #entries > 0 and not controller.spinning
        roll.label = controller.spinning and 'Rolling...' or 'Roll a boss'
        local reelY = compact and 40 or 58
        local reelHeight = compact and math.min(80,math.max(36,buttonY-100)) or 80
        local resultY = reelY+reelHeight+6
        result:SetPos(12,resultY)
        result:SetSize(math.max(1,w-24),math.max(1,buttonY-8-resultY))
        result.content = controller:status() -- Full assignment, never tile abbreviation.

        canvas:Clear()
        canvas:AddRectangle(0,0,w,h,BACKGROUND)
        local headerHeight = compact and 32 or 44
        title:SetPos(12,compact and 0 or 6); title:SetSize(w>=320 and w-128 or w-24,headerHeight)
        count:SetPos(w-112,compact and 0 or 6); count:SetSize(100,headerHeight)
        canvas:AddRectangle(0,0,w,headerHeight,HEADER)
        canvas:AddOutline(0,0,w,h,1,0x526567FF)
        canvas:AddLine(0,headerHeight,w,headerHeight,1,0x6C6446FF)
        local reelWidth = math.max(1,w-24)
        local tileWidth = math.max(1,math.floor(reelWidth/2.8))
        local position = controller.spin and controller.spin.position or 0
        local tiles = Reel.tiles(entries,position,reelWidth,tileWidth)
        canvas:AddRectangle(12,reelY,reelWidth,reelHeight,0x071319FF)
        for _,tile in ipairs(tiles) do
            local x = math.floor(12+tile.x)
            -- Clip the tile geometry explicitly; edge masks crop native text.
            local left,right = math.max(12,x+2),math.min(w-12,x+tileWidth-2)
            local colourIndex = 0
            for i=1,#tile.boss.id do colourIndex=colourIndex+string.byte(tile.boss.id,i) end
            if right > left then
                canvas:AddGradientV(left,reelY+3,right-left,reelHeight-6,TILE_COLOURS[colourIndex % #TILE_COLOURS+1],0x142A30FF)
            end
            canvas:AddText(x+6,reelY+8,math.max(1,tileWidth-12),math.max(16,reelHeight-38),tile.boss.short or tile.boss.name,textConfig)
            canvas:AddText(x+6,reelY+reelHeight-25,math.max(1,tileWidth-12),20,tostring(tile.boss.weight)..'×',textConfig)
        end
        -- An opaque mask prevents partial tiles from painting the ribbon margins.
        canvas:AddRectangle(0,reelY-3,12,reelHeight+6,BACKGROUND)
        canvas:AddRectangle(w-12,reelY-3,12,reelHeight+6,BACKGROUND)
        canvas:AddOutline(12,reelY,reelWidth,reelHeight,1,0x71613AFF)
        if #entries > 0 then
            local center,left = math.floor(w/2),math.floor((w-tileWidth)/2)
            canvas:AddOutline(left,reelY+1,tileWidth,reelHeight-2,2,GOLD)
            canvas:AddTriangle(center-7,reelY+1,center+7,reelY+1,center,reelY+8,GOLD)
            canvas:AddTriangle(center-7,reelY+reelHeight-2,center+7,reelY+reelHeight-2,center,reelY+reelHeight-9,GOLD)
        end
        canvas:AddLine(12,buttonY-8,w-12,buttonY-8,1,0x526567FF)
    end
    view:refresh()
    return view
end

function Views.settings(root, controller)
    local view = base(root)
    view.page, view.generation = 1,0
    function view:refresh(force)
        if not self:alive() then return end
        local w,h = self:dimensions()
        if not force and self.lastPrefs == controller.prefs and self.lastCharacter == controller.character
            and self.lastError == controller.error and self.lastW == w and self.lastH == h then return end
        if self.lastCharacter ~= controller.character then self.page=1 end
        self.lastPrefs, self.lastCharacter, self.lastError = controller.prefs,controller.character,controller.error
        self.lastW,self.lastH = w,h
        self.generation = self.generation+1
        local generation, character = self.generation,controller.character
        self.layer:DeleteAll(); self.layer:SetSize(w,h)
        local function action(fn)
            return function()
                if self.generation == generation and self:visible() then fn() end
            end
        end
        local function edit(bossID,field,value)
            if not controller:edit(character,bossID,field,value) then
                -- Native toggle buttons change their own appearance before this
                -- callback. Restore it even when a repeated error is identical.
                self:refresh(true)
            end
        end
        local canvas=ui.Canvas.new(self.layer); canvas:SetSize(w,h); canvas.clickthrough=true
        canvas:AddRectangle(0,0,w,h,BACKGROUND)
        local heading=label(self.layer,'Your boss pool',12,6,w-24,30,GOLD)
        if not controller.prefs then
            label(self.layer,controller:status(),12,42,w-24,math.max(1,h-96),GOLD)
            button(self.layer,'Retry',12,math.max(0,h-44),80,32,action(function() controller:syncIdentity(true) end))
            return
        end
        local rowHeight = w >= 240 and 84 or 106
        local top = math.max(0,math.min(controller.error and 132 or 88,h-rowHeight-46))
        if controller.error then
            local errorY=top>=80 and 36 or 0
            heading.hidden=errorY==0
            label(self.layer,controller.error,12,errorY,w-24,math.max(1,top-errorY),GOLD)
        elseif top>=80 then
            label(self.layer,'On / Off and weight are independent. Changes save immediately.',12,36,w-24,46,MUTED)
        end
        local perPage = math.max(1,math.floor((h-top-52)/rowHeight))
        local pages = math.ceil(#controller.roster/perPage)
        self.page = math.max(1,math.min(self.page,pages))
        local entries = controller:entries()
        for index=(self.page-1)*perPage+1,math.min(self.page*perPage,#controller.roster) do
            local boss = controller.roster[index]
            local pref = controller.prefs[boss.id]
            local row = ui.Layer.new(self.layer)
            row:SetPos(12,top+((index-1)%perPage)*rowHeight); row:SetSize(w-24,rowHeight)
            local name=label(row,boss.name,0,0,w-24,38,TEXT)
            name.isShadowed=true
            local toggle=button(row,pref.enabled and 'On' or 'Off',0,40,46,30,action(function()
                edit(boss.id,'enabled',not pref.enabled)
            end))
            toggle.canToggle=true; toggle.isToggled=pref.enabled
            local minus=button(row,'-',52,40,28,30,action(function()
                edit(boss.id,'weight',pref.weight-1)
            end))
            minus.enabled=pref.weight>1
            local weight=label(row,tostring(pref.weight)..'×',82,40,34,30,GOLD)
            weight:AlignTo(ui.AlignMode.CENTRE)
            local plus=button(row,'+',118,40,28,30,action(function()
                edit(boss.id,'weight',pref.weight+1)
            end))
            plus.enabled=pref.weight<10
            local chance=Pool.chance(entries,boss.id)
            local odds=chance==0 and '0%' or string.format('%.2f%%',chance)
            local oddsLabel=label(row,odds,w>=240 and w-98 or 0,w>=240 and 40 or 72,74,30,MUTED)
            oddsLabel:AlignTo(ui.AlignMode.CENTRE)
        end
        local navY=top+perPage*rowHeight+4
        local previous=button(self.layer,'Previous',12,navY,80,30,action(function()
            self.page=self.page-1; self:refresh(true)
        end))
        previous.enabled=self.page>1
        local nextButton=button(self.layer,'Next',w-80,navY,68,30,action(function()
            self.page=self.page+1; self:refresh(true)
        end))
        nextButton.enabled=self.page<pages
        local pageLabel=label(self.layer,tostring(self.page)..' / '..tostring(pages),96,navY,math.max(1,w-180),30,MUTED)
        pageLabel:AlignTo(ui.AlignMode.CENTRE)
    end
    view:refresh(true)
    return view
end

return Views

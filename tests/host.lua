-- Boundary double for the unavailable RS3 process. Only documented APIs used by
-- the plugin are accepted; this is not a renderer or proof of native behavior.
local Host = {}
local baseMath = math
local function clone(value)
    if type(value) ~= 'table' then return value end
    local result = {}; for k,v in pairs(value) do result[k]=clone(v) end; return result
end

function Host.new(options)
    options=options or {}
    local host={available=options.available~=false, tracking=options.tracking or 9007199254740993,
        permission=options.permission~=false, entity={isValid=true,displayName=options.name or 'Reaper One'},
        data=options.data or {}, reads=0, writes=0, draws=0, components={}}
    local methods={}
    local writable={hidden=true,enabled=true,clickthrough=true,rgba=true,rgb=true,colour=true,alpha=true,
        stylesheetID=true,content=true,font=true,maxLines=true,alignHorizontal=true,alignVertical=true,
        isShadowed=true,label=true,mode=true,canToggle=true,isToggled=true,lineSpacing=true}
    local function make(kind,parent)
        local state={kind=kind,parent=parent,children={},hooks={},draws={},width=425,height=280,x=0,y=0,
            enabled=true,hidden=false,dead=false}
        local node={_state=state}
        setmetatable(node,{
            __index=function(_,key)
                assert(not state.dead,'Access to destroyed component: '..key)
                if key=='visibleGlobal' then return not state.hidden and (not parent or parent.visibleGlobal) end
                if methods[key] then return methods[key] end
                if state[key]~=nil then return state[key] end
                if writable[key] then return nil end
                error('Undocumented UI property: '..key)
            end,
            __newindex=function(_,key,value)
                assert(not state.dead,'Write to destroyed component')
                assert(writable[key],'Undocumented UI property: '..key)
                state[key]=value
            end,
        })
        if parent then table.insert(parent._state.children,node) end
        table.insert(host.components,node)
        return node
    end
    function methods:SetSize(w,h,pw,ph)
        local s=self._state
        s.width=baseMath.max(0,w+(pw or 0)*(s.parent and s.parent.width or 0))
        s.height=baseMath.max(0,h+(ph or 0)*(s.parent and s.parent.height or 0))
    end
    function methods:SetPos(x,y,px,py,sx,sy)
        local s=self._state
        s.x=x+(px or 0)*(s.parent and s.parent.width or 0)+(sx or 0)*s.width
        s.y=y+(py or 0)*(s.parent and s.parent.height or 0)+(sy or 0)*s.height
    end
    function methods:SetX(x,px,sx) self:SetPos(x,self.y,px,0,sx,0) end
    function methods:SetY(y,py,sy) self:SetPos(self.x,y,0,py,0,sy) end
    function methods:AlignTo(h,v)
        local function valid(value)
            for _,mode in pairs(ui.AlignMode) do if mode==value then return true end end
            return false
        end
        assert(valid(h) and (v==nil or valid(v)),'Invalid ui.AlignMode passed to AlignTo')
        self.alignHorizontal=h; self.alignVertical=v or h
    end
    function methods:Subscribe(hook,id,fn)
        if type(id)=='function' then fn=id; id='default' end
        self._state.hooks[hook]=self._state.hooks[hook] or {}; self._state.hooks[hook][id]=fn
    end
    function methods:Unsubscribe(hook,id)
        if self._state.hooks[hook] then self._state.hooks[hook][id or 'default']=nil end
    end
    function methods:Destroy()
        for _,child in ipairs(self._state.children) do if not child._state.dead then methods.Destroy(child) end end
        self._state.dead=true; self._state.hooks={}
    end
    function methods:DeleteAll()
        for _,child in ipairs(self._state.children) do if not child._state.dead then methods.Destroy(child) end end
        self._state.children={}
    end
    function methods:Clear() self._state.draws={} end
    for _,name in ipairs({'AddRectangle','AddOutline','AddLine','AddGradientH','AddGradientV','AddTriangle','AddText'}) do
        methods[name]=function(self,...) table.insert(self._state.draws,{name=name,args={...}}) end
    end
    _G.ui={Hook={ONBUTTONPRESSED='press',ONRESIZE='resize'},
        AlignMode={TOPLEFT='topleft',CENTRE='center',BOTTOMRIGHT='bottomright',JUSTIFY='justify'},
        TriggerMode={ONPRESS='onpress'},TextDataConfig={new=function() return {} end}}
    for _,kind in ipairs({'Layer','Text','Button','Canvas'}) do ui[kind]={new=function(parent) return make(kind,parent) end} end
    _G.id={Font={MUSEO_SANS_15PT_REGULAR=15},StyleSheet={BUTTON_DEFAULT=1}}
    _G.Vector4={new=function(...) return {...} end}
    _G.PluginPermissions={trackingAccess='trackingAccess'}
    _G.Plugin={HasPermission=function(permission) assert(permission=='trackingAccess'); return host.permission end}
    _G.Player={IsAvailable=function() return host.available end,
        GetTrackingID=function() assert(host.permission,'Tracking permission was not granted'); return host.tracking end,
        GetEntity=function() return host.entity end}
    _G.PersistentDB={
        Get=function(_,key) host.reads=host.reads+1; return clone(host.data[key]) end,
        Set=function(_,key,value)
            host.writes=host.writes+1
            if host.failSave then return false end
            host.data[key]=clone(value); return true
        end,
    }
    _G.math=setmetatable({random=function(low,high)
        assert(low==1 and high>=1); host.draws=host.draws+1; return host.ticket or low
    end},{__index=baseMath})
    _G.GameState={GAME=30,LOBBY=20,LOGINSCREEN=10}
    _G.Event={}
    for _,name in ipairs({'Draw','Logic','GameStateChanged','SettingsLayerReady','ContentLayerReady'}) do
        local listeners={}
        Event[name]={listeners=listeners,Subscribe=function(key,fn) listeners[key]=fn end,
            Unsubscribe=function(key) listeners[key]=nil end}
    end
    function host:emit(name,payload)
        local queue={}; for _,fn in pairs(Event[name].listeners) do queue[#queue+1]=fn end
        for _,fn in ipairs(queue) do fn(payload or {}) end
    end
    function host:layer(kind,w,h)
        local root=make('Layer'); root:SetSize(w or 425,h or 480)
        self:emit(kind..'LayerReady',{component=root}); return root
    end
    function host:click(node)
        if node.enabled and node.visibleGlobal then
            if node.canToggle then node.isToggled=not node.isToggled end
            local queue={}; for _,fn in pairs(node._state.hooks.press or {}) do queue[#queue+1]=fn end
            for _,fn in ipairs(queue) do fn(node,1,0) end
        end
    end
    function host:find(root,kind,text)
        if not root._state.dead and root.visibleGlobal then
            if root._state.kind==kind and (text==nil or root._state.label==text or root._state.content==text) then return root end
            for _,child in ipairs(root._state.children) do local found=self:find(child,kind,text); if found then return found end end
        end
    end
    function host:text(root,content) return self:find(root,'Text',content) end
    function host:button(root,label) return assert(self:find(root,'Button',label),'Missing button: '..label) end
    function host:row(root,name) return assert(self:text(root,name),'Missing row: '..name).parent end
    function host:frame(seconds) self:emit('Draw',{timeDeltaSecs=seconds}) end
    function host:frameCallback() local _,fn=next(Event.Draw.listeners); return fn end
    function host:start() dofile('main.lua') end
    return host
end
return Host

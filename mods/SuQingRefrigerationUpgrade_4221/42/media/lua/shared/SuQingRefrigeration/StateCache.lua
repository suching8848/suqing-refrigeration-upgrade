-- Short-lived, container-grouped cooling-state lookup only. No world/ModData writes.
-- The resolver must depend on the direct ItemContainer and its ancestor state.
require "SuQingRefrigeration/Core"
local C=SuQingRefrigeration
C.StateCache=C.StateCache or {}
local S=C.StateCache
if S.loaded then return S end
S.loaded=true
S.TTL_HOURS=1/60 -- one game minute; known changes invalidate immediately
local TTL=S.TTL_HOURS
local Cache={}
Cache.__index=Cache

local function entries() return setmetatable({}, {__mode="k"}) end
local function finite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
local function plainOrNative(value)
    local kind=type(value)
    return kind=="userdata" or (kind=="table" and getmetatable(value)==nil)
end
local function trustedFood(food)
    return plainOrNative(food) and type(instanceof)=="function"
        and instanceof(food,"Food") and type(food.getContainer)=="function"
end
local function trustedContainer(container)
    return plainOrNative(container) and type(instanceof)=="function"
        and instanceof(container,"ItemContainer")
        and type(container.getContainingItem)=="function"
end
local function strict(self,food)
    self._stats.strictCalls=self._stats.strictCalls+1
    -- Deliberately no pcall: caller sees the resolver's original failure.
    local result=self._resolver(food)
    if type(result)~="boolean" then
        error("SuQingRefrigeration StateCache resolver must return a boolean")
    end
    return result
end

function S.New(resolver)
    if type(resolver)~="function" then error("StateCache.New requires a resolver function") end
    return setmetatable({_resolver=resolver,_entries=entries(),_generation=0,
        _stats={hits=0,misses=0,invalidations=0,strictCalls=0,resets=0}},Cache)
end

function Cache:Resolve(food,t)
    -- A finite backwards clock invalidates even when its new value is negative.
    local validTime=finite(t)
    if validTime and self._lastTime~=nil and t<self._lastTime then self:Reset() end
    if not validTime or t<0 then
        self._stats.misses=self._stats.misses+1
        return strict(self,food)
    end
    self._lastTime=t
    if not trustedFood(food) then
        self._stats.misses=self._stats.misses+1
        return strict(self,food)
    end
    local container=food:getContainer()
    if container==nil or not plainOrNative(container) then
        self._stats.misses=self._stats.misses+1
        return strict(self,food)
    end
    local entry=self._entries[container]
    if entry and entry.generation==self._generation and t>=entry.time and t<entry.expires then
        self._stats.hits=self._stats.hits+1
        return entry.value
    end
    self._stats.misses=self._stats.misses+1
    -- Container class/interface is immutable for a trusted native object. An
    -- existing entry already proved it; new/untrusted objects use strict lookup.
    if not entry and not trustedContainer(container) then return strict(self,food) end
    self._entries[container]=nil
    local generation=self._generation
    local result=strict(self,food)
    -- A resolver may synchronously invalidate or reset; never publish into the
    -- new generation using the state observed before that invalidation.
    if self._generation==generation and food:getContainer()==container then
        self._entries[container]={generation=generation,time=t,expires=t+TTL,value=result}
    end
    return result
end

function Cache:Invalidate()
    self._generation=self._generation+1
    self._entries=entries()
    self._stats.invalidations=self._stats.invalidations+1
end

function Cache:Reset()
    self:Invalidate()
    self._lastTime=nil
    self._stats.resets=self._stats.resets+1
end

function Cache:GetStats()
    local stats=self._stats
    return {hits=stats.hits,misses=stats.misses,invalidations=stats.invalidations,
        strictCalls=stats.strictCalls,resets=stats.resets,generation=self._generation}
end

return S

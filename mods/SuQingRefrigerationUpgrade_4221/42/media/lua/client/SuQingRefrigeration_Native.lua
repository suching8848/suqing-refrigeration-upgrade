-- Optional, explicitly installed Java backend. Absence retains the Lua runtime.
require "SuQingRefrigeration/Core"
local C=SuQingRefrigeration
C.NativeBackend=C.NativeBackend or {}
local B=C.NativeBackend
if B.loaded then return B end
B.loaded=true
B.active=false
B.attempted=false
local names={"apiVersion","bootstrap","isReady","isActive","activate",
    "setCoolingEnabled","invalidate","settle","flushKnown","fridgeFactor",
    "foodRotSpeed","status","shutdown"}
local function warning(message)
    print("[SuQingRefrigeration] native backend: "..tostring(message))
end
local function enabled()
    local s=SandboxVars and SandboxVars.SuQingRefrigeration
    return not s or s.Enabled~=false
end
function B.IsActive() return B.active==true end
function B.AssertUsable()
    if B.blocked then error(B.failure or "native backend requires a normal restart",0) end
end
local function stopped()
    local calls=B.calls
    if not calls then return true end
    local ok,message=pcall(calls.activate,false)
    if not ok then return false,message end
    local checked,active=pcall(calls.isActive)
    if not checked or active~=false then
        return false,checked and "native deactivation was not confirmed" or active
    end
    return true
end
local function block(message)
    B.blocked=true
    B.failure="[SuQingRefrigeration] native backend isolated; normal restart required: "..tostring(message)
    error(B.failure,0)
end
-- Health loss is not a seamless hot-uninstall. Never run both ledgers when
-- native deactivation cannot be confirmed by the captured API.
function B.Fail(runtime,message)
    local ok,why=stopped()
    if not ok then block(tostring(message).."; "..tostring(why)) end
    B.active=false
    B.failure=tostring(message)
    local rebuilt,rebuildError=pcall(runtime.RebuildLegacy)
    if not rebuilt then block(tostring(message).."; legacy registry rebuild failed: "..tostring(rebuildError)) end
    warning("Lua fallback rebuilt after "..tostring(message).."; save and restart normally before continuing / 原生接管失效，已重建Lua登记；请正常退出并重启")
    return false
end
local function identities(runtime)
    if SuQingNativeColdApi~=B.api or C.NativeBackend~=B or C.Runtime~=runtime
        or C.version~=B.baseVersion or runtime.nativeAge~=B.priorAge
        or runtime.ageWrapper~=B.ageWrapper then return false end
    for _,name in ipairs(names) do
        if B.api[name]~=B.calls[name] then return false end
    end
    return true
end
function B.Check(runtime)
    B.AssertUsable()
    if not B.active then return false end
    local ok,healthy=pcall(function()
        return identities(runtime) and B.calls.apiVersion()==1
            and B.calls.isReady()==true and B.calls.isActive()==true
    end)
    if not ok or not healthy then return B.Fail(runtime,not ok and healthy or "API or captured identity changed") end
    return true
end
function B.Config()
    B.AssertUsable()
    local on=enabled()
    if B.enabled~=on then B.calls.setCoolingEnabled(on);B.enabled=on end
    local rate,rot=B.calls.fridgeFactor(),B.calls.foodRotSpeed()
    if not C.Finite(rate) or rate<0 or not C.Finite(rot) or rot<0 then
        error("native backend returned invalid vanilla aging factors",0)
    end
    return on,rate,rot
end
function B.Invalidate() B.AssertUsable();return B.calls.invalidate() end
function B.Settle(food) B.AssertUsable();return B.calls.settle(food) end
function B.FlushKnown() B.AssertUsable();return B.calls.flushKnown() end
function B.Status()
    if B.calls then return B.calls.status() end
    return B.failure or "Lua backend"
end
function B.TryStart(runtime)
    B.AssertUsable()
    if B.attempted then return B.active end
    B.attempted=true
    local api=SuQingNativeColdApi
    if api==nil then return false end
    local calls={}
    local ok,message=pcall(function()
        for _,name in ipairs(names) do
            local f=api[name]
            if type(f)~="function" then error("missing API method "..name,0) end
            calls[name]=f
        end
        if calls.apiVersion()~=1 then error("unsupported API version",0) end
    end)
    if not ok then warning(tostring(message).."; Lua path retained");return false end
    B.api,B.calls=api,calls
    B.baseVersion,B.priorAge,B.ageWrapper=C.version,runtime.nativeAge,runtime.ageWrapper
    local checked,prepared=pcall(function()
        if calls.isActive()~=false then error("backend already active before handover",0) end
        if calls.bootstrap(C.version)~=true or calls.isReady()~=true then
            error("backend bootstrap rejected: "..tostring(calls.status()),0)
        end
        if calls.isActive()~=false then error("bootstrap unexpectedly activated backend",0) end
        B.Config()
        return true
    end)
    if not checked or not prepared then
        local off,why=stopped()
        if not off then block(tostring(prepared).."; "..tostring(why)) end
        warning(tostring(prepared).."; Lua path retained")
        return false
    end
    -- This is deliberately the original strict flush, with Java still inactive.
    local flushed,flushError=runtime.FlushAll()
    if not flushed then warning("handover flush failed: "..tostring(flushError).."; Lua path retained");return false end
    local activated,result=pcall(calls.activate,true)
    local confirmed,active=pcall(calls.isActive)
    if not activated or result~=true or not confirmed or active~=true then
        local off,why=stopped()
        if not off then block(tostring(result).."; "..tostring(why)) end
        warning("activation rejected: "..tostring(result).."; Lua path retained")
        return false
    end
    B.active=true
    local synced,syncError=pcall(function()
        runtime.ClearLegacyForNative()
        runtime.SyncConfig(getGameTime():getWorldAgeHours(),false)
    end)
    if not synced then return B.Fail(runtime,syncError) end
    warning("active; native food scheduling owns aging / 已由原生食品调度接管老化")
    return true
end
function B.Shutdown()
    local calls=B.calls
    if calls then
        local ok,message=pcall(calls.shutdown)
        local checked,active=pcall(calls.isActive)
        if not ok or not checked or active~=false then
            B.blocked=true
            local why=not ok and message or (not checked and active or "native backend remained active")
            B.failure="native shutdown not confirmed; normal restart required: "..tostring(why)
            return false,B.failure
        end
    end
    B.active,B.attempted,B.blocked=false,false,false
    B.api,B.calls,B.failure,B.enabled=nil,nil,nil,nil
    B.baseVersion,B.priorAge,B.ageWrapper=nil,nil,nil
    return true
end
return B

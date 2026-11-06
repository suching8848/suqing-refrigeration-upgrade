-- Display-only context for the audited B42.21 inventory renderer.
-- No item timing, transfers or UI renderer implementation is replaced here.
require "SuQingRefrigeration_Runtime"
local C=SuQingRefrigeration
local R=C.Runtime
C.Display=C.Display or {}
local D=C.Display
if D.loaded then return D end
D.loaded=true
D.compatRevision="deferred-render-chain-3"
D.enabled=false
D.attempted=false
D.normalTicks=0
D.stableTicks=0
R.displayDepth=0

local function pack(...) return {n=select("#",...),...} end
local function normalized(path)
    if type(path)~="string" then return nil end
    return path:gsub("\\","/"):gsub("^@",""):lower()
end
local function ends(path,suffix) return path:sub(-#suffix)==suffix end
local function observe(fn)
    local ok,source=pcall(function()return getFilenameOfClosure(fn)end)
    local lineOk,line=pcall(function()return getFirstLineOfClosure(fn)end)
    D.rendererSource=ok and tostring(source) or "unavailable"
    D.rendererLine=lineOk and tostring(line) or "unavailable"
end
local function version(id)
    if type(getModInfoByID)~="function" then return nil end
    local ok,value=pcall(function()
        local info=getModInfoByID(id) or getModInfoByID("\\"..id)
        return info and info.getModVersion and tostring(info:getModVersion()) or nil
    end)
    return ok and value or nil
end
local function reviewedP4()
    local ok,v,dir=pcall(function()
        local info=getModInfoByID("P4HasBeenRead") or getModInfoByID("\\P4HasBeenRead")
        if not info then return nil,nil end
        return tostring(info:getModVersion()),info:getVersionDir()
    end)
    if not ok then return nil,nil,"P4 metadata query failed: "..tostring(v) end
    dir=normalized(dir)
    if (v=="3.8.1" and dir and ends(dir,"/42.15"))
        or (v=="2.14.1" and dir and ends(dir,"/42")) then
        return v,dir
    end
    return nil,nil,"unsupported P4 version/branch: "..tostring(v).." / "..tostring(dir)
end
local function stop(reason)
    D.enabled=false
    D.reason=reason
    R.displayDepth=0
    if not D.warned then
        D.warned=true
        print("[SuQingRefrigeration] Display coalescing disabled; immediate settlement retained: "..tostring(reason).."; renderer="..tostring(D.rendererSource).."; line="..tostring(D.rendererLine))
    end
    return false,reason
end

-- getFilenameOfClosure is the game's supported closure-source API; debug.getinfo
-- is not required. These paths and wrapper versions are the locally audited
-- render-only chain, not a blanket allowance for arbitrary UI wrappers.
local function reviewedRenderer(fn)
    if type(fn)~="function" or type(getFilenameOfClosure)~="function"
        or type(getActivatedMods)~="function" or type(getCore)~="function" then
        return nil,"source APIs unavailable"
    end
    local ok,gameVersion=pcall(function()return getCore():getVersionNumber()end)
    if not ok then return nil,"game version query failed: "..tostring(gameVersion) end
    -- Core.getVersionNumber() is GameVersion.toString(): the current native
    -- value is "42.21". Core.getGameAndBuildVersion()/the boot log add ".0".
    -- Accept only these two equivalent representations, never another build
    -- number, neighbouring version or arbitrary suffix.
    if type(gameVersion)~="string" or (gameVersion~="42.21" and gameVersion~="42.21.0") then
        return nil,"unsupported game version: "..tostring(gameVersion)
    end
    D.gameVersion=gameVersion
    local buildOk,gameBuild=pcall(function()return getCore():getGameAndBuildVersion()end)
    if not buildOk then return nil,"game build query failed: "..tostring(gameBuild) end
    if type(gameBuild)~="string" or gameBuild~="42.21.0" then
        return nil,"unsupported game build: "..tostring(gameBuild)
    end
    D.gameBuild=gameBuild
    local clean,mods
    ok,clean=pcall(function()
        mods=getActivatedMods()
        return mods:contains("CleanUI") or mods:contains("\\CleanUI")
    end)
    if not ok then return nil,"active UI metadata unavailable" end
    if clean and version("CleanUI")~="2.10.4" then return nil,"unsupported CleanUI version" end
    -- A reviewed outer wrapper can capture these known inner wrappers. A
    -- later version of either needs review even when its source is not outermost.
    for _,entry in ipairs({{"CleanUI","2.10.4","42.19"},
        {"PinyinSearch_SafeSources_4221_LocalFix","1.1","42"},
        {"Codex_InventoryTransferPerformance_4221","1.2.2","42"},
        {"NeatUI_Equipment","1.0.2","42.20"},
        {"SuQingUIInteractionFixes","1.0.1","42"},{"SuQingSearchEnhancement","0.1.1","42"}})do
        local activeOk,active=pcall(function()return mods:contains(entry[1]) or mods:contains("\\"..entry[1])end)
        if not activeOk then return nil,"active wrapper metadata unavailable" end
        if active then
            if version(entry[1])~=entry[2] then return nil,"unsupported active "..entry[1] end
            local dirOk,dir=pcall(function()
                local info=getModInfoByID(entry[1]) or getModInfoByID("\\"..entry[1])
                return normalized(info:getVersionDir())
            end)
            if not dirOk or not dir or not ends(dir,"/"..entry[3]) then
                return nil,"unsupported active branch "..entry[1]
            end
        end
    end
    local p4ActiveOk,p4Active=pcall(function()return mods:contains("P4HasBeenRead") or mods:contains("\\P4HasBeenRead")end)
    if not p4ActiveOk then return nil,"active P4 metadata unavailable" end
    local p4Version,p4Dir,p4Reason
    if p4Active then
        p4Version,p4Dir,p4Reason=reviewedP4()
        if not p4Version then return nil,p4Reason end
        D.p4Version=p4Version;D.p4VersionDir=p4Dir
    end
    local source
    ok,source=pcall(getFilenameOfClosure,fn)
    source=ok and normalized(source) or nil
    if not source then return nil,"renderer source unavailable" end
    -- These two later local wrappers are presentation-only. Match the native
    -- selected branch, rather than trusting a basename or folder suffix.
    for _,entry in ipairs({
        {"SuQingUIInteractionFixes","1.0.1","suqing_proximityselectionfix.lua"},
        {"SuQingSearchEnhancement","0.1.1","suqingsearch/runtime.lua"}})do
        local infoOk,dir=pcall(function()
            local info=getModInfoByID(entry[1]) or getModInfoByID("\\"..entry[1])
            return info and info:getVersionDir() or nil
        end)
        dir=infoOk and normalized(dir) or nil
        if dir and source==dir.."/media/lua/client/"..entry[3] then
            if not (mods:contains(entry[1]) or mods:contains("\\"..entry[1]))
                or version(entry[1])~=entry[2] or not ends(dir,"/42") then
                return nil,"unsupported local renderer branch: "..entry[1]
            end
            if entry[1]=="SuQingUIInteractionFixes" then
                local bridge=SuQingUIInteractionFixes and SuQingUIInteractionFixes.proximitySelection
                if not clean or type(bridge)~="table" or bridge.version~="1.0.1" or bridge.installed~=true or bridge.enabled~=true then
                    return nil,"proximity selection renderer not ready"
                end
            elseif type(SuQingSearch)~="table" or SuQingSearch.rendererInstalled~=true then
                return nil,"search renderer not ready"
            else
                local helper=SuQingSearch.Ordering and SuQingSearch.Ordering.render
                local helperOk,helperSource=pcall(getFilenameOfClosure,helper)
                if not helperOk or normalized(helperSource)~=dir.."/media/lua/client/suqingsearch/ordering.lua" then
                    return nil,"unreviewed search ordering helper"
                end
                D.orderingHelper=helper
            end
            return entry[1].."-"..entry[2]..(clean and "/CleanUI-2.10.4" or "/vanilla")
        end
    end
    local base="media/lua/client/isui/isinventorypane.lua"
    local vanilla=(source==base or source=="isui/isinventorypane.lua"
        or (ends(source,"/"..base) and not source:find("/mods/",1,true)
            and not source:find("/workshop/",1,true)))
    if vanilla and not clean then return "vanilla" end
    if clean and ends(source,"/3437629766/mods/cleanui/42.19/"..base) then return "CleanUI-2.10.4" end
    if ends(source,"/inventorytransferperformance_4221_local/42/media/lua/client/codex_inventorytransferperformance.lua") then
        local m=CodexInventoryTransferPerformance
        if type(m)=="table" and m.installed==true and m.version=="1.2.2" and clean then
            return "InventoryTransferPerformance-1.2.2/CleanUI-2.10.4"
        end
        return nil,"unsupported inventory performance wrapper"
    end
    if ends(source,"/pinyin_ui_4221_localcompat/42/media/lua/client/pinyinsafecompat.lua")
        and version("PinyinSearch_SafeSources_4221_LocalFix")=="1.1" then
        return clean and "Pinyin-1.1/CleanUI-2.10.4" or "Pinyin-1.1/vanilla"
    end
    if ends(source,"/p4hasbeenread.lua") then
        if not p4Version then p4Version,p4Dir,p4Reason=reviewedP4() end
        if p4Version and source==p4Dir.."/media/lua/client/p4hasbeenread.lua" then
            D.p4Version=p4Version;D.p4VersionDir=p4Dir
            return "P4HasBeenRead-"..p4Version..(clean and "/CleanUI-2.10.4" or "/vanilla")
        end
        return nil,p4Reason or "P4 renderer source does not match selected branch"
    end
    return nil,"unreviewed renderer source"
end

function D.Check()
    if not D.enabled then return false end
    if ISInventoryPane~=D.class or D.class.renderdetails~=D.wrapper then
        observe(type(ISInventoryPane)=="table" and ISInventoryPane.renderdetails or nil)
        return stop("renderer was replaced after installation")
    end
    if D.orderingHelper and (type(SuQingSearch)~="table" or type(SuQingSearch.Ordering)~="table"
        or SuQingSearch.Ordering.render~=D.orderingHelper) then
        return stop("search ordering helper was replaced after installation")
    end
    return true
end
function D.Install()
    if D.attempted then return D.Check(),"already attempted" end
    D.attempted=true
    if not C.SP() or not R.ready then return stop("single-player runtime unavailable") end
    local class=ISInventoryPane
    local prior=type(class)=="table" and class.renderdetails or nil
    observe(prior)
    local supported,reason=reviewedRenderer(prior)
    if not supported then return stop(reason) end
    D.class=class
    D.prior=prior
    D.source=supported
    D.wrapper=function(...)
        if not D.Check() or not R.ready then return prior(...) end
        local previous=R.displayDepth
        R.displayDepth=previous+1
        local result=pack(pcall(prior,...))
        -- A nested replacement must not reinstate an already revoked scope.
        R.displayDepth=D.enabled and previous or 0
        if not result[1] then error(result[2],0) end
        return unpack(result,2,result.n)
    end
    class.renderdetails=D.wrapper
    D.enabled=true
    print("[SuQingRefrigeration] display context ready; compat="..D.compatRevision.."; game="..D.gameVersion.."; build="..D.gameBuild.."; source="..supported.."; renderer="..D.rendererSource.."; line="..D.rendererLine.."; mod="..tostring(C.version).."; P4="..tostring(D.p4Version or "inactive").."; P4dir="..tostring(D.p4VersionDir or ""))
    return true,supported
end
local function onTick()
    -- Search Enhancement installs from a deferred first OnTick, after all
    -- OnGameStart bridges. Wait for two normal ticks (independent of callback
    -- order), then observe the same final slot on two paused/normal callbacks.
    -- Starting paused deliberately retains strict settlement until unpaused.
    if not D.attempted and R.ready then
        local class=ISInventoryPane
        local candidate=type(class)=="table" and class.renderdetails or nil
        if D.candidate~=candidate or D.candidateClass~=class then
            D.candidate=candidate;D.candidateClass=class;D.stableTicks=0
            observe(candidate)
            print("[SuQingRefrigeration] display renderer observed; renderer="..D.rendererSource.."; line="..D.rendererLine.."; normalTicks="..D.normalTicks)
        end
        if D.normalTicks<2 then return end
        D.stableTicks=D.stableTicks+1
        if D.stableTicks>=2 then D.Install() end
    elseif D.enabled then D.Check() end
end
Events.OnTick.Add(function()if R.ready and D.normalTicks<2 then D.normalTicks=D.normalTicks+1 end end)
Events.OnTickEvenPaused.Add(onTick)
Events.OnMainMenuEnter.Add(function()R.displayDepth=0 end)
return D

-- Display-only context for reviewed B42 inventory renderers.
-- No item timing, transfers or UI renderer implementation is replaced here.
require "SuQingRefrigeration_Runtime"
local C=SuQingRefrigeration
local R=C.Runtime
C.Display=C.Display or {}
local D=C.Display
if D.loaded then return D end
D.loaded=true
D.compatRevision="deferred-render-chain-6"
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
local reviewedCleanUI4222 = {
    ["2.10.5"]={performance="1.2.4", proximity="1.0.3", search="0.1.4-rc.3",
        performanceLine=445, proximityLine=226, searchLine=376, orderingLine=393},
    ["2.10.6"]={performance="1.2.5", proximity="1.0.4", search="0.1.4-rc.4",
        performanceLine=449, proximityLine=230, searchLine=376, orderingLine=398},
    ["2.10.7"]={performance="1.2.6", proximity="1.0.5", search="0.1.4-rc.5",
        performanceLine=456, proximityLine=238, searchLine=376, orderingLine=401},
}

local function reviewedRenderer(fn)
    if type(fn)~="function" or type(getFilenameOfClosure)~="function"
        or type(getActivatedMods)~="function" or type(getCore)~="function" then
        return nil,"source APIs unavailable"
    end
    local ok,gameVersion=pcall(function()return getCore():getVersionNumber()end)
    if not ok then return nil,"game version query failed: "..tostring(gameVersion) end
    -- The short Core version omits the build suffix.
    local newer=gameVersion=="42.22"
    if not newer and gameVersion~="42.21" and gameVersion~="42.21.0" then
        return nil,"unsupported game version: "..tostring(gameVersion)
    end
    D.gameVersion=gameVersion
    local buildOk,gameBuild=pcall(function()return getCore():getGameAndBuildVersion()end)
    if not buildOk then return nil,"game build query failed: "..tostring(gameBuild) end
    local expectedBuild=newer and "42.22.2" or "42.21.0"
    if gameBuild~=expectedBuild then
        return nil,"unsupported game build: "..tostring(gameBuild)
    end
    D.gameBuild=gameBuild
    local clean,mods
    ok,clean=pcall(function()
        mods=getActivatedMods()
        return mods:contains("CleanUI") or mods:contains("\\CleanUI")
    end)
    if not ok then return nil,"active UI metadata unavailable" end
    local cleanVersion=clean and version("CleanUI") or nil
    local chain=newer and reviewedCleanUI4222[cleanVersion] or nil
    if newer and not clean then return nil,"B42.22.2 renderer outside reviewed CleanUI chain" end
    if clean and ((newer and not chain) or (not newer and cleanVersion~="2.10.4")) then
        return nil,"unsupported CleanUI version"
    end
    local hasLegacyOverlay=newer and cleanVersion=="2.10.6"
    local hasReadingCallback=newer and cleanVersion=="2.10.7"
    local cleanBranch=newer and "42.22" or "42.19"
    local performanceVersion=chain and chain.performance or "1.2.2"
    local proximityVersion=chain and chain.proximity or "1.0.1"
    local searchVersion=chain and chain.search or "0.1.1"
    if newer and (CleanUI_SnakeUtilsRenderCompatInstalled
        or mods:contains("SMP_SnakeUtilsPack") or mods:contains("\\SMP_SnakeUtilsPack")) then
        return nil,"unsupported CleanUI Snake Utils renderer"
    end
    if hasReadingCallback and (mods:contains("EURY_CONTAINERS") or mods:contains("\\EURY_CONTAINERS")
        or mods:contains("ProjectExile") or mods:contains("\\ProjectExile")) then
        return nil,"unreviewed CleanUI row renderer interoperability"
    end
    -- A reviewed outer wrapper can capture inner wrappers. Check each
    -- active participant's selected version and branch before opening the context.
    local reviewedDirs={}
    for _,entry in ipairs({{"CleanUI",cleanVersion,cleanBranch},
        {"PinyinSearch_SafeSources_4221_LocalFix","1.1","42"},
        {"Codex_InventoryTransferPerformance_4221",performanceVersion,"42"},
        {"NeatUI_Equipment","1.0.2","42.20"},
        {"SuQingUIInteractionFixes",proximityVersion,"42"},
        {"SuQingSearchEnhancement",searchVersion,"42"}})do
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
            reviewedDirs[entry[1]]=dir
        end
    end
    if newer and not ends(reviewedDirs.CleanUI,"/3437629766/mods/cleanui/"..cleanBranch) then
        return nil,"unreviewed CleanUI source directory"
    end
    local p4ActiveOk,p4Active=pcall(function()return mods:contains("P4HasBeenRead") or mods:contains("\\P4HasBeenRead")end)
    if not p4ActiveOk then return nil,"active P4 metadata unavailable" end
    local p4Version,p4Dir,p4Reason
    if p4Active then
        p4Version,p4Dir,p4Reason=reviewedP4()
        if not p4Version then return nil,p4Reason end
        D.p4Version=p4Version;D.p4VersionDir=p4Dir
        if hasReadingCallback then
            local draw=rawget(_G,"CleanUI_HasBeenReadDrawVisibleMarks")
            local drawOk,drawSource=pcall(getFilenameOfClosure,draw)
            local drawLineOk,drawLine=pcall(getFirstLineOfClosure,draw)
            if type(draw)~="function" or not drawOk or not drawLineOk or drawLine~=212
                or normalized(drawSource)~=reviewedDirs.CleanUI.."/media/lua/client/patch/cleanui_hasbeenreadcompat.lua" then
                return nil,"unreviewed CleanUI reading callback"
            end
            D.readingCallback=draw
        end
    end
    local source
    ok,source=pcall(getFilenameOfClosure,fn)
    source=ok and normalized(source) or nil
    if not source then return nil,"renderer source unavailable" end
    local cleanLabel=clean and "/CleanUI-"..cleanVersion or "/vanilla"
    -- These local wrappers participate in presentation only. Verify the
    -- selected source and the audited first executable line on B42.22.2.
    for _,entry in ipairs({
        {"SuQingUIInteractionFixes",proximityVersion,"suqing_proximityselectionfix.lua",chain and chain.proximityLine},
        {"SuQingSearchEnhancement",searchVersion,"suqingsearch/runtime.lua",chain and chain.searchLine}})do
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
            if newer and tonumber(D.rendererLine)~=entry[4] then
                return nil,"unreviewed local renderer entry: "..entry[1]
            end
            if entry[1]=="SuQingUIInteractionFixes" then
                local bridge=SuQingUIInteractionFixes and SuQingUIInteractionFixes.proximitySelection
                if not clean or type(bridge)~="table" or bridge.version~=proximityVersion or bridge.installed~=true or bridge.enabled~=true then
                    return nil,"proximity selection renderer not ready"
                end
            elseif type(SuQingSearch)~="table" or SuQingSearch.rendererInstalled~=true then
                return nil,"search renderer not ready"
            else
                local helper=SuQingSearch.Ordering and SuQingSearch.Ordering.render
                local helperOk,helperSource=pcall(getFilenameOfClosure,helper)
                local helperLineOk,helperLine=pcall(getFirstLineOfClosure,helper)
                if not helperOk or normalized(helperSource)~=dir.."/media/lua/client/suqingsearch/ordering.lua"
                    or (newer and (not helperLineOk or helperLine~=chain.orderingLine)) then
                    return nil,"unreviewed search ordering helper"
                end
                D.orderingHelper=helper
            end
            return entry[1].."-"..entry[2]..cleanLabel
        end
    end
    local base="media/lua/client/isui/isinventorypane.lua"
    local vanilla=(source==base or source=="isui/isinventorypane.lua"
        or (ends(source,"/"..base) and not source:find("/mods/",1,true)
            and not source:find("/workshop/",1,true)))
    if vanilla and not clean then return "vanilla" end
    local cleanDir=reviewedDirs.CleanUI
    local cleanSource=clean and ends(source,"/3437629766/mods/cleanui/"..cleanBranch.."/"..base)
    if cleanSource and (not newer or (cleanDir and source==cleanDir.."/"..base
        and tonumber(D.rendererLine)==5678)) then
        return "CleanUI-"..cleanVersion
    end
    -- CleanUI's own reading-mark overlay is a pure display wrapper and can
    -- be the outermost renderer when the optional local patches are absent.
    if hasLegacyOverlay and p4Active and source==cleanDir.."/media/lua/client/patch/cleanui_hasbeenreadcompat.lua"
        and tonumber(D.rendererLine)==283 and rawget(ISInventoryPane,"_cleanUIHasBeenReadWrapper")==fn then
        local original=rawget(ISInventoryPane,"_cleanUIOwnRenderdetails")
        local originalOk,originalSource=pcall(getFilenameOfClosure,original)
        local lineOk,line=pcall(getFirstLineOfClosure,original)
        if originalOk and normalized(originalSource)==cleanDir.."/"..base and lineOk and line==5678 then
            return "CleanUI-"..cleanVersion.."/HasBeenRead"
        end
        return nil,"unreviewed underlying CleanUI renderer"
    end
    if ends(source,"/inventorytransferperformance_4221_local/42/media/lua/client/codex_inventorytransferperformance.lua") then
        local m=CodexInventoryTransferPerformance
        local perfDir=reviewedDirs.Codex_InventoryTransferPerformance_4221
        if type(m)=="table" and m.installed==true and m.version==performanceVersion and clean
            and (not newer or (perfDir and tonumber(D.rendererLine)==chain.performanceLine
                and source==perfDir.."/media/lua/client/codex_inventorytransferperformance.lua")) then
            return "InventoryTransferPerformance-"..performanceVersion..cleanLabel
        end
        return nil,"unsupported inventory performance wrapper"
    end
    -- B42.22.2 was audited only with a CleanUI or local presentation entry.
    if newer then return nil,"unreviewed B42.22.2 renderer source" end
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
    if D.gameBuild=="42.22.2" and CleanUI_SnakeUtilsRenderCompatInstalled then
        return stop("CleanUI Snake Utils renderer appeared after installation")
    end
    if D.readingCallback and rawget(_G,"CleanUI_HasBeenReadDrawVisibleMarks")~=D.readingCallback then
        return stop("CleanUI reading callback was replaced after installation")
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
    -- Preserve CleanUI's overlay registration so a recheck of the same pane
    -- retains the renderer chain that already delegates to that overlay.
    if rawget(class,"_cleanUIHasBeenReadWrapper")==prior then
        class._cleanUIHasBeenReadWrapper=D.wrapper
    end
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

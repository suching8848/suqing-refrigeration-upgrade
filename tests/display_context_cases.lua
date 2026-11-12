-- Focused standalone model: no game/world or save APIs are invoked.
local cases,checks=0,0
local function check(ok,why)checks=checks+1;if not ok then error(why or "assertion")end end
local function eq(a,b,why)check(a==b,(why or "equal")..": "..tostring(a).." / "..tostring(b))end
local function pack(...)return {n=select("#",...),...}end
local function test(name,fn)cases=cases+1;fn()end
local VANILLA="D:/steam/steamapps/common/ProjectZomboid/media/lua/client/ISUI/ISInventoryPane.lua"
local CLEAN="D:/steam/steamapps/workshop/content/108600/3437629766/mods/CleanUI/42.19/media/lua/client/ISUI/ISInventoryPane.lua"
local CLEANNEW=CLEAN:gsub("/42.19/","/42.22/")
local PERF="C:/Users/test/Zomboid/mods/InventoryTransferPerformance_4221_Local/42/media/lua/client/Codex_InventoryTransferPerformance.lua"
local PINYIN="C:/Users/test/Zomboid/mods/Pinyin_UI_4221_LocalCompat/42/media/lua/client/PinyinSafeCompat.lua"
local P4="D:/steam/steamapps/workshop/content/108600/2544353492/mods/P4HasBeenRead/42/media/lua/client/P4HasBeenRead.lua"
local P4NEW="D:/steam/steamapps/workshop/content/108600/2544353492/mods/P4HasBeenRead/42.15/media/lua/client/P4HasBeenRead.lua"
local P4DIR="D:/steam/steamapps/workshop/content/108600/2544353492/mods/P4HasBeenRead/42"
local P4NEWDIR="D:/steam/steamapps/workshop/content/108600/2544353492/mods/P4HasBeenRead/42.15"
local PROXDIR="C:/Users/test/Zomboid/mods/SuQingUIInteractionFixes/42"
local SEARCHDIR="C:/Users/test/Zomboid/mods/SuQingSearchEnhancement/42"
local PROX=PROXDIR.."/media/lua/client/SuQing_ProximitySelectionFix.lua"
local SEARCH=SEARCHDIR.."/media/lua/client/SuQingSearch/Runtime.lua"
local function fixture(options)
    local o=options or {};local callbacks={};local sources={};local logs={}
    require=function()return true end
    Events=setmetatable({}, {__index=function(t,k)
        local v={Add=function(fn)callbacks[k]=callbacks[k]or {};callbacks[k][#callbacks[k]+1]=fn end}
        rawset(t,k,v);return v
    end})
    print=function(msg)logs[#logs+1]=msg end
    getCore=function()
        local core={getVersionNumber=function()if o.versionError then error("injected version accessor failure",0)end;return o.game or "42.21" end}
        if not o.noBuildAPI then core.getGameAndBuildVersion=function()if o.buildError then error("injected build accessor failure",0)end;return o.build or "42.21.0" end end
        return core
    end
    getActivatedMods=function()return {contains=function(_,id)return (o.clean==true and id=="CleanUI") or (o.activeMods and o.activeMods[id]==true) or false end}end
    getModInfoByID=function(id)
        id=id:gsub("^\\","")
        local versions={CleanUI=o.cleanVersion or "2.10.4",PinyinSearch_SafeSources_4221_LocalFix=o.pinyinVersion or "1.1",P4HasBeenRead=o.p4Version or "2.14.1",Codex_InventoryTransferPerformance_4221=o.perfVersion or "1.2.2",SuQingUIInteractionFixes=o.proxVersion or "1.0.1",SuQingSearchEnhancement=o.searchVersion or "0.1.1",NeatUI_Equipment=o.neatVersion or "1.0.2"}
        local v=versions[id];if not v then return nil end
        local info={getModVersion=function()return v end}
        if not (id=="P4HasBeenRead" and o.noP4DirAPI) then
            info.getVersionDir=function()
                if id=="P4HasBeenRead" then return o.p4Dir or P4DIR end
                if id=="CleanUI" then return o.cleanDir or "CleanUI/42.19" end
                if id=="NeatUI_Equipment" then return o.neatDir or "NeatUI_Equipment/42.20" end
                if id=="SuQingUIInteractionFixes" then return o.proxDir or PROXDIR end
                if id=="SuQingSearchEnhancement" then return o.searchDir or SEARCHDIR end
                return "unused/42"
            end
        end
        return info
    end
    getFilenameOfClosure=function(fn)if o.sourceError then error("injected source failure")end;return sources[fn]end
    local lines={}
    getFirstLineOfClosure=function(fn)return lines[fn] or 240 end
    CleanUI_SnakeUtilsRenderCompatInstalled=o.snake==true and true or nil
    if o.noSourceAPI then getFilenameOfClosure=nil end
    CodexInventoryTransferPerformance={installed=o.perfInstalled~=false,version=o.perfVersion or "1.2.2"}
    SuQingUIInteractionFixes={proximitySelection={version=o.proxVersion or "1.0.1",installed=o.proxInstalled~=false,enabled=o.proxEnabled~=false}}
    SuQingSearch={rendererInstalled=o.searchInstalled~=false,Ordering={render=function()end}}
    sources[SuQingSearch.Ordering.render]=o.helperSource or SEARCHDIR.."/media/lua/client/SuQingSearch/Ordering.lua"
    lines[SuQingSearch.Ordering.render]=o.helperLine
    local C={Runtime={ready=o.ready~=false},SP=function()return o.multiplayer~=true end}
    SuQingRefrigeration=C
    local context={C=C,R=C.Runtime,callbacks=callbacks,sources=sources,logs=logs}
    local prior=o.prior or function(...)return ... end
    ISInventoryPane={renderdetails=prior};sources[prior]=o.source or VANILLA
    lines[prior]=o.rendererLine
    context.prior=prior;context.class=ISInventoryPane
    local chunk=assert(loadstring(DISPLAY_MODULE_SOURCE,DISPLAY_MODULE_PATH))
    context.D=chunk()
    function context:pausedTick()for _,fn in ipairs(callbacks.OnTickEvenPaused or {})do fn()end end
    function context:normalTick()for _,fn in ipairs(callbacks.OnTick or {})do fn()end end
    function context:tick()
        if not self.D.attempted and self.R.ready then
            self:normalTick();self:pausedTick();self:normalTick();self:pausedTick();self:pausedTick()
        else self:pausedTick() end
    end
    function context:menu()for _,fn in ipairs(callbacks.OnMainMenuEnter or {})do fn()end end
    return context
end

local function newer(options)
    local values={game="42.22",build="42.22.2",clean=true,cleanVersion="2.10.5",
        cleanDir=CLEANNEW:match("^(.-)/media/"),perfVersion="1.2.4",
        proxVersion="1.0.3",searchVersion="0.1.4-rc.3",
        activeMods={SuQingSearchEnhancement=true,SuQingUIInteractionFixes=true,
            Codex_InventoryTransferPerformance_4221=true,NeatUI_Equipment=true,P4HasBeenRead=true},
        p4Version="3.8.1",p4Dir=P4NEWDIR,source=SEARCH,rendererLine=376,helperLine=393}
    for key,value in pairs(options or {}) do values[key]=value end
    return fixture(values)
end
test("actual native Core version is accepted",function()
 check(type(DISPLAY_NATIVE_CORE_VERSION)=="string","native Core readback required")
 local x
 if DISPLAY_NATIVE_CORE_VERSION=="42.22" then
    eq(DISPLAY_NATIVE_CORE_BUILD_VERSION,"42.22.2")
    x=newer()
 else
    eq(DISPLAY_NATIVE_CORE_VERSION,"42.21");eq(DISPLAY_NATIVE_CORE_BUILD_VERSION,"42.21.0")
    x=fixture({game=DISPLAY_NATIVE_CORE_VERSION,build=DISPLAY_NATIVE_CORE_BUILD_VERSION})
 end
 x:tick();eq(x.D.enabled,true)
 eq(x.D.compatRevision,"deferred-render-chain-4");eq(x.D.gameVersion,DISPLAY_NATIVE_CORE_VERSION);eq(x.D.gameBuild,DISPLAY_NATIVE_CORE_BUILD_VERSION)
 check(x.logs[#x.logs]:find("display context ready",1,true)~=nil,"installation evidence")
end)
test("equivalent explicit old short version representation is accepted",function()
 local x=fixture({game="42.21.0"});x:tick();eq(x.D.enabled,true)
end)
test("failed version accessor is reported rather than mislabeled",function()
 local x=fixture({versionError=true})
 local originalOk,originalError=pcall(function()return getCore():getVersionNumber()end)
 x:tick();eq(originalOk,false);eq(x.D.enabled,false)
 eq(x.D.reason,"game version query failed: "..tostring(originalError),"engine error value retained")
 eq(x.class.renderdetails,x.prior)
end)
for _,raw in ipairs({"42.21.1","42.22","42.21beta","42.210","42.21.0-extra","142.21",42.21})do
 test("strict native version gate "..tostring(raw),function()
  local x=fixture({game=raw});x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
 end)
end
test("different build is rejected even when numeric version matches",function()
 local x=fixture({game="42.21",build="42.21.1"});x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
 check(x.D.reason:find("unsupported game build",1,true)~=nil,"explicit build rejection")
end)
test("failed build accessor preserves original engine error",function()
 local x=fixture({buildError=true});local originalOk,originalError=pcall(function()return getCore():getGameAndBuildVersion()end)
 x:tick();eq(originalOk,false);eq(x.D.enabled,false);eq(x.D.reason,"game build query failed: "..tostring(originalError));eq(x.class.renderdetails,x.prior)
end)
test("missing build accessor fails closed",function()
 local x=fixture({noBuildAPI=true});x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
 check(x.D.reason:find("game build query failed",1,true)~=nil,"missing method reason")
end)
for _,build in ipairs({"42.21","42.22.0","42.21.0-extra",42.21})do
 test("strict build representation "..tostring(build),function()
  local x=fixture({game="42.21",build=build});x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
 end)
end
test("actual P4 3.8.1 branch behind current outer wrapper",function()
 local x=fixture({clean=true,source=PERF,p4Version="3.8.1",p4Dir=P4NEWDIR,activeMods={P4HasBeenRead=true}});x:tick();eq(x.D.enabled,true);eq(x.D.p4Version,"3.8.1");eq(x.D.p4VersionDir,P4NEWDIR:lower())
end)
test("direct P4 3.8.1 selected branch source",function()
 local x=fixture({clean=true,source=P4NEW,p4Version="3.8.1",p4Dir=P4NEWDIR,activeMods={P4HasBeenRead=true}});x:tick();eq(x.D.enabled,true)
end)
for _,spec in ipairs({{"3.8.1",P4DIR},{"2.14.1",P4NEWDIR},{"3.8.2",P4NEWDIR},{"3.8.1",P4NEWDIR.."-other"}})do
 test("reject mismatched P4 version branch "..spec[1].." "..spec[2],function()
  local x=fixture({clean=true,source=PERF,p4Version=spec[1],p4Dir=spec[2],activeMods={P4HasBeenRead=true}});x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
 end)
end
test("direct P4 source must equal native selected branch",function()
 local x=fixture({clean=true,source=P4,p4Version="3.8.1",p4Dir=P4NEWDIR,activeMods={P4HasBeenRead=true}});x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
end)
test("missing native P4 versionDir accessor rejects",function()
 local x=fixture({clean=true,source=PERF,p4Version="3.8.1",noP4DirAPI=true,activeMods={P4HasBeenRead=true}});x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior);check(x.D.reason:find("P4 metadata query failed",1,true)~=nil)
end)
test("defer until ready and preserve latest GameStart wrapper",function()
 local x=fixture({ready=false});x:tick();eq(x.D.attempted,false)
 local later=function()return "late"end;x.sources[later]=VANILLA;x.class.renderdetails=later;x.R.ready=true
 x:tick();eq(x.D.enabled,true);eq(x.D.prior,later);eq(x.class.renderdetails(),"late");eq(x.R.displayDepth,0)
end)
test("multiple return values including leading/middle/trailing nil",function()
 local seen;local x
 x=fixture({prior=function(a,b)seen=x.R.displayDepth;return nil,a,nil,b,nil end});x:tick()
 local r=pack(x.class.renderdetails("a","b"));eq(r.n,5);eq(r[1],nil);eq(r[2],"a");eq(r[3],nil);eq(r[4],"b");eq(r[5],nil);eq(seen,1);eq(x.R.displayDepth,0)
end)
test("error object and depth restoration",function()
 local marker={why="sentinel"};local x=fixture({prior=function()error(marker,0)end});x:tick()
 local directOk,directErr=pcall(x.prior)
 local ok,err=pcall(x.class.renderdetails);eq(directOk,false);eq(ok,false);eq(err,directErr);eq(x.R.displayDepth,0);eq(x.D.enabled,true)
end)
test("string error preserves the engine error value",function()
 local x=fixture({prior=function()error("display sentinel",0)end});x:tick()
 local directOk,directErr=pcall(x.prior);local ok,err=pcall(x.class.renderdetails)
 eq(directOk,false);eq(ok,false);eq(err,directErr);eq(x.R.displayDepth,0)
end)
test("nested contexts restore the parent depth",function()
 local depths={};local x
 x=fixture({prior=function(n)
  depths[#depths+1]=x.R.displayDepth
  if n==1 then local a,b=x.class.renderdetails(2);eq(a,2);eq(b,nil);depths[#depths+1]=x.R.displayDepth end
  return n,nil
 end});x:tick();eq(x.class.renderdetails(1),1);eq(depths[1],1);eq(depths[2],2);eq(depths[3],1);eq(x.R.displayDepth,0)
end)
test("nested error restores the preexisting depth",function()
 local x;x=fixture({prior=function(n)if n==1 then return x.class.renderdetails(2)end;error("nested sentinel",0)end});x:tick()
 x.R.displayDepth=3;local ok=pcall(x.class.renderdetails,1);eq(ok,false);eq(x.R.displayDepth,3)
end)
test("idempotent installation and module reload",function()
 local x=fixture();x:tick();local wrapper=x.class.renderdetails;local count=#x.callbacks.OnTickEvenPaused
 eq(x.D.Install(),true);eq(x.class.renderdetails,wrapper);x:tick();eq(x.class.renderdetails,wrapper)
 eq(assert(loadstring(DISPLAY_MODULE_SOURCE,DISPLAY_MODULE_PATH))(),x.D);eq(#x.callbacks.OnTickEvenPaused,count);eq(x.class.renderdetails,wrapper)
end)
for _,spec in ipairs({{"CleanUI",CLEAN},{"performance",PERF},{"pinyin",PINYIN},{"hasbeenread",P4}})do
 test("audited chain "..spec[1],function()local x=fixture({clean=true,source=spec[2]});x:tick();eq(x.D.enabled,true);eq(x.D.prior,x.prior)end)
end
test("reviewed active inner wrappers remain supported",function()
 local x=fixture({clean=true,source=PERF,activeMods={P4HasBeenRead=true,PinyinSearch_SafeSources_4221_LocalFix=true}});x:tick();eq(x.D.enabled,true)
end)
test("unknown inner P4 behind a known outer wrapper is rejected",function()
 local x=fixture({clean=true,source=PERF,activeMods={P4HasBeenRead=true},p4Version="2.15.0"});x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
end)
test("unknown inner Pinyin behind a known outer wrapper is rejected",function()
 local x=fixture({clean=true,source=PERF,activeMods={PinyinSearch_SafeSources_4221_LocalFix=true},pinyinVersion="1.2"});x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
end)
test("vanilla wrappers without CleanUI",function()
 for _,src in ipairs({PINYIN,P4})do local x=fixture({source=src});x:tick();eq(x.D.enabled,true)end
end)
local rejected={{"unknown source",{source="C:/mods/Unknown/42/media/lua/client/Other.lua"}},
 {"missing API",{noSourceAPI=true}},{"source error",{sourceError=true}},
 {"wrong game",{game="42.22.0"}},{"wrong CleanUI",{clean=true,source=CLEAN,cleanVersion="2.10.5"}},
 {"wrong wrapper",{clean=true,source=PERF,perfVersion="1.2.3"}},
 {"uninstalled wrapper",{clean=true,source=PERF,perfInstalled=false}},
 {"wrong pinyin",{source=PINYIN,pinyinVersion="1.2"}},{"wrong P4",{source=P4,p4Version="2.15.0"}},
 {"multiplayer",{multiplayer=true}},{"forged vanilla mod path",{source="C:/mods/Unknown/media/lua/client/ISUI/ISInventoryPane.lua"}}}
for _,spec in ipairs(rejected)do
 test("reject "..spec[1],function()local x=fixture(spec[2]);x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior);eq(x.R.displayDepth,0);local n=#x.logs;x:tick();eq(#x.logs,n)end)
end
test("later replacement is retained without display context",function()
 local depth;local x=fixture({prior=function()depth=SuQingRefrigeration.Runtime.displayDepth;return "prior"end});x:tick()
 local captured=x.class.renderdetails;local outsider=function()return captured()end;x.class.renderdetails=outsider
 eq(x.class.renderdetails(),"prior");eq(depth,0);eq(x.D.enabled,false);eq(x.R.displayDepth,0);eq(x.class.renderdetails,outsider);x:tick();eq(x.class.renderdetails,outsider);eq(#x.logs,3)
end)
test("tick detects replacement before the next draw",function()
 local x=fixture();x:tick();local outsider=function()return "unknown"end;x.class.renderdetails=outsider;x:tick()
 eq(x.D.enabled,false);eq(x.class.renderdetails,outsider);eq(x.R.displayDepth,0)
end)
test("nested replacement revokes and does not restore scope",function()
 local x;local changed=false;local innerDepth
 x=fixture({prior=function()
  if not changed then changed=true;x.class.renderdetails=function()return "unknown"end;x.D.wrapper()
  else innerDepth=x.R.displayDepth end
  return "ok"
 end});x:tick();eq(x.D.wrapper(),"ok");eq(innerDepth,0);eq(x.R.displayDepth,0);eq(x.D.enabled,false)
end)
test("runtime not ready and main menu have no context",function()
 local depth;local x=fixture({prior=function()depth=SuQingRefrigeration.Runtime.displayDepth end});x:tick();x.R.ready=false;x.class.renderdetails();eq(depth,0)
 x.R.displayDepth=4;x:menu();eq(x.R.displayDepth,0)
end)
test("paused startup waits for deferred normal Tick installation",function()
 local x=fixture({clean=true,source=PROX,activeMods={SuQingUIInteractionFixes=true,SuQingSearchEnhancement=true}})
 for i=1,10 do x:pausedTick() end
 eq(x.D.attempted,false);eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
 x:normalTick();x:pausedTick();eq(x.D.attempted,false)
 local later=function()return "search"end;x.sources[later]=SEARCH;x.class.renderdetails=later
 x:normalTick();x:pausedTick();eq(x.D.attempted,false)
 x:pausedTick();eq(x.D.enabled,true);eq(x.D.prior,later);eq(x.D.rendererSource,SEARCH);eq(x.D.rendererLine,"240")
end)
test("changing candidate resets startup stability",function()
 local x=fixture();x:normalTick();x:normalTick();x:pausedTick();eq(x.D.attempted,false)
 local later=function()end;x.sources[later]=VANILLA;x.class.renderdetails=later
 x:pausedTick();eq(x.D.attempted,false);x:pausedTick();eq(x.D.enabled,true);eq(x.D.prior,later)
end)
for _,spec in ipairs({{"proximity",PROX,{SuQingUIInteractionFixes=true}},
 {"search",SEARCH,{SuQingUIInteractionFixes=true,SuQingSearchEnhancement=true}}})do
 test("reviewed late wrapper "..spec[1],function()
  local x=fixture({clean=true,source=spec[2],activeMods=spec[3]});x:tick();eq(x.D.enabled,true);eq(x.D.prior,x.prior)
 end)
end
test("later search helper replacement revokes display scope",function()
 local seen;local x=fixture({clean=true,source=SEARCH,activeMods={SuQingSearchEnhancement=true},prior=function()seen=SuQingRefrigeration.Runtime.displayDepth end})
 x:tick();eq(x.D.enabled,true)
 SuQingSearch.Ordering.render=function()end
 x.class.renderdetails();eq(x.D.enabled,false);eq(seen,0);eq(x.R.displayDepth,0)
 check(x.D.reason:find("helper was replaced",1,true)~=nil)
end)
for _,spec in ipairs({
 {source=PROX,activeMods={SuQingUIInteractionFixes=true},proxVersion="1.0.2"},
 {source=PROX,activeMods={SuQingUIInteractionFixes=true},proxInstalled=false},
 {source=PROX,activeMods={SuQingUIInteractionFixes=true},proxEnabled=false},
 {source=SEARCH,activeMods={SuQingSearchEnhancement=true},searchVersion="0.1.2"},
 {source=SEARCH,activeMods={SuQingSearchEnhancement=true},searchInstalled=false},
 {source=SEARCH,activeMods={SuQingSearchEnhancement=true},helperSource="C:/other/Ordering.lua"},
 {source=SEARCH,activeMods={SuQingSearchEnhancement=true,NeatUI_Equipment=true},neatVersion="1.0.3"},
 {source=SEARCH,activeMods={SuQingSearchEnhancement=true,NeatUI_Equipment=true},neatDir="NeatUI_Equipment/42.21"},
 {source=SEARCH,activeMods={SuQingSearchEnhancement=true},cleanDir="CleanUI/42.22"},
 {source=SEARCH,activeMods={SuQingSearchEnhancement=true,SuQingUIInteractionFixes=true},proxVersion="1.0.2"},
 {source=SEARCH,activeMods={SuQingSearchEnhancement=true},searchDir=SEARCHDIR..".other"},
 {source=SEARCH,activeMods={}},
 {source="C:/other/Runtime.lua",activeMods={SuQingSearchEnhancement=true}}})do
 test("unsupported late wrapper is rejected",function()
  spec.clean=true;local x=fixture(spec);x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
  check(x.logs[#x.logs]:find("renderer=",1,true)~=nil);check(x.logs[#x.logs]:find("line=240",1,true)~=nil)
 end)
end

test("new CleanUI selected render entry opens display scope",function()
 local x=newer({source=CLEANNEW,rendererLine=5678,activeMods={}});x:tick()
 eq(x.D.enabled,true);eq(x.D.source,"CleanUI-2.10.5")
end)
test("new proximity wrapper opens display scope",function()
 local x=newer({source=PROX,rendererLine=226});x:tick()
 eq(x.D.enabled,true);eq(x.D.source,"SuQingUIInteractionFixes-1.0.3/CleanUI-2.10.5")
end)
test("new Search wrapper preserves results and late Snake compatibility revokes scope",function()
 local seen={}
 local x=newer({prior=function(...)seen[#seen+1]=SuQingRefrigeration.Runtime.displayDepth;return ... end})
 x:tick();eq(x.D.enabled,true);eq(x.D.source,"SuQingSearchEnhancement-0.1.4-rc.3/CleanUI-2.10.5")
 eq(select("#",x.class.renderdetails("item",nil,"tail")),3);eq(seen[1],1);eq(x.R.displayDepth,0)
 CleanUI_SnakeUtilsRenderCompatInstalled=true
 x.class.renderdetails("item");eq(seen[2],0);eq(x.D.enabled,false);eq(x.R.displayDepth,0)
end)
for _,spec in ipairs({
 {build="42.22.1"}, {clean=false}, {cleanVersion="2.10.4"}, {cleanDir="CleanUI/42.19"},
 {searchVersion="0.1.4-rc.2"}, {proxVersion="1.0.2"}, {perfVersion="1.2.3"},
 {rendererLine=377}, {helperLine=394}, {source=CLEANNEW,rendererLine=5679},
 {source=VANILLA}, {cleanDir="C:/unreviewed/CleanUI/42.22"}, {snake=true}, {activeMods={SMP_SnakeUtilsPack=true}}
}) do
 test("new game declines unsupported builds and chains",function()
    local x=newer(spec);x:tick();eq(x.D.enabled,false);eq(x.class.renderdetails,x.prior)
 end)
end
return "PASS display context cases="..cases.." checks="..checks

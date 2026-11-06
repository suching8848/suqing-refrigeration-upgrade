local A=NativeBridgeAudit
local C=SuQingRefrigeration
local R=C.Runtime
local B=C.NativeBackend
local cases,assertions=0,0
local function check(v,label) assertions=assertions+1;assert(v,label or "native bridge") end
local function eq(x,y,label) check(x==y,(label or "equal").." / "..tostring(x).." vs "..tostring(y)) end
local function count(k) return A.calls[k] or 0 end
local function empty(t) for _ in pairs(t) do return false end;return true end
local function setup(api)
    if B.calls then B.calls.shutdown();B.blocked=false end
    emit("OnMainMenuEnter")
    SuQingNativeColdApi=api
    clock=100;players={};processItems=list()
    SandboxVars.FoodRotSpeed=5
    SandboxVars.SuQingRefrigeration={Enabled=true,RotSpeedPercent=2.5}
    local p=player();players[1]=p
    local b=bag("Fixture.NativeBag");b.inner.kind="ItemContainer"
    b.md[C.key]={schema=1,on=true,paid=true,token="native-bridge",batteries={1,1,1,1,1,1}}
    p.inv:AddItem(b)
    local f=item("Base.Apple","Food");b.inner:AddItem(f)
    A.bag,A.food,A.player=b,f,p
    A.calls={};A.events={};A.legacyAge=0
    return b,f,p
end
local function test(name,fn) cases=cases+1;fn();print("NATIVE_BRIDGE_CASE "..name.." PASS") end
test("missing Java API retains full legacy behavior",function()
    local b,f=setup(nil);R.Start()
    eq(B.IsActive(),false);check(R.foods[f]);clock=101
    local prior=A.legacyAge;R.Tick();check(A.legacyAge>prior)
end)
test("unsupported and incomplete APIs never bootstrap",function()
    for _,kind in ipairs({"version","missing"}) do
        local api=A.api();if kind=="version" then api.version=2 else api.settle=nil end
        local b,f=setup(api);R.Start()
        eq(B.IsActive(),false);eq(count("bootstrap"),0);check(R.foods[f])
    end
end)
test("bootstrap rejection leaves Java inactive and legacy registered",function()
    local api=A.api();api.reject=true;local b,f=setup(api);R.Start()
    eq(B.IsActive(),false);eq(api.active,false);check(R.foods[f]);eq(count("activateOn"),0)
end)
test("strict legacy flush precedes activation and handover is idempotent",function()
    local api=A.api();local b,f=setup(api)
    local flush=R.FlushAll
    R.FlushAll=function(...)
        eq(B.IsActive(),false,"old flush still selected");eq(api.active,false)
        A.events[#A.events+1]="legacyFlush"
        return flush(...)
    end
    R.Start();R.FlushAll=flush
    eq(api.baseVersion,C.version);eq(B.IsActive(),true);check(empty(R.foods));check(R.bags[b])
    eq(table.concat(A.events,","),"bootstrap,legacyFlush,activateOn")
    B.TryStart(R);R.Start();eq(count("bootstrap"),1);eq(count("activateOn"),1)
end)
test("failed legacy flush never activates",function()
    local api=A.api();local b,f=setup(api);local flush=R.FlushAll
    R.FlushAll=function() return false,"legacy flush sentinel" end
    R.Start();R.FlushAll=flush
    eq(B.IsActive(),false);eq(count("activateOn"),0);check(R.foods[f])
end)
test("activation rejection confirms deactivation and keeps fallback",function()
    local api=A.api();api.rejectActivation=true;local b,f=setup(api);R.Start()
    eq(B.IsActive(),false);eq(api.active,false);check(R.foods[f])
end)
test("native ticks and paused callbacks do not enumerate food",function()
    local api=A.api();local b,f=setup(api);R.Start()
    local oldMD=f.getModData;local reads=0
    f.getModData=function(self) reads=reads+1;return oldMD(self) end
    A.legacyAge=0;A.calls.settle=0
    for n=1,30 do clock=100+n/100;R.Tick();emit("OnTickEvenPaused") end
    eq(A.legacyAge,0);eq(count("settle"),0);eq(reads,0);check(empty(R.foods))
    R.Discover(clock);eq(count("settle"),0)
end)
test("post-activation clear failure stops native before rebuilding Lua",function()
    local api=A.api();local b,f=setup(api)
    local clear=R.ClearLegacyForNative;local calls=0
    R.ClearLegacyForNative=function()
        calls=calls+1
        if calls==1 then error("native handover clear sentinel",0) end
        return clear()
    end
    R.Start();R.ClearLegacyForNative=clear
    eq(B.IsActive(),false);eq(api.active,false);check(R.foods[f]);eq(calls,2)
end)
test("failed clear and failed rebuild isolate without restarting legacy",function()
    local api=A.api();setup(api);local clear=R.ClearLegacyForNative
    R.ClearLegacyForNative=function() error("native clear and rebuild sentinel",0) end
    local ok,message=pcall(R.Start);R.ClearLegacyForNative=clear
    eq(ok,false);eq(api.active,false);check(B.blocked)
    check(string.find(tostring(message),"registry rebuild failed",1,true)~=nil)
    eq(pcall(R.Tick),false)
end)
test("native history uses vanilla factors and only master Enabled",function()
    local api=A.api();setup(api);R.Start()
    eq(R.configRate,.2);eq(R.configRot,.4)
    SandboxVars.SuQingRefrigeration.RotSpeedPercent=100;clock=101;R.Tick();eq(R.configRate,.2)
    api.factor=.13;clock=102;R.Tick();eq(R.configRate,.13)
    local h=C.Global().history;eq(h[#h].rate,.13);eq(h[#h].rot,.4)
    SandboxVars.SuQingRefrigeration.Enabled=false;emit("OnTickEvenPaused")
    eq(api.enabled,false);eq(h[#h].rate,1)
end)
test("native age wrapper delegates the captured prior and preserves arguments",function()
    local api=A.api();local b,f=setup(api);R.Start()
    local prior=R.nativeAge;local got
    R.nativeAge=function(food,...) got={n=select("#",...),...};return nil,"prior",nil end
    local result={n=select("#",f:updateAge(false,nil,7)),f:updateAge(false,nil,7)}
    eq(result.n,3);eq(result[2],"prior");eq(result[3],nil)
    eq(got.n,3);eq(got[1],false);eq(got[2],nil);eq(got[3],7)
    R.nativeAge=prior
end)
test("strict subtrees settle actual foods and Toggle sees both contexts",function()
    local api=A.api();local b,f,p=setup(api);local nested=bag("Fixture.Nested");b.inner:AddItem(nested)
    local g=item("Base.Potato","Food");nested.inner:AddItem(g);R.Start()
    api.settled={};R.ScanItem(b);eq(#api.settled,2)
    api.settled={};check(C.Toggle(p,b));eq(#api.settled,4)
    eq(api.settled[1].on,true);eq(api.settled[3].on,false)
end)
test("transfer pre and post keep native owner handoff and original return",function()
    local api=A.api();local b,f,p=setup(api);R.Start();api.settled={}
    local result=ISTransferAction.transferItem({},p,f,b.inner,p.inv)
    eq(result,f);eq(#api.settled,2);eq(api.settled[1].container,b.inner);eq(api.settled[2].container,p.inv)
end)
test("transfer keeps middle and trailing nil returns and post-cleans original errors",function()
    local api=A.api();local b,f,p=setup(api);R.Start()
    local prior=R.nativeTransfer
    R.nativeTransfer=function(self,owner,food,src,dst)
        prior(self,owner,food,src,dst)
        return nil,"transfer-tail",nil
    end
    local function pack(...) return {n=select("#",...),...} end
    local result=pack(ISTransferAction.transferItem({},p,f,b.inner,p.inv))
    eq(result.n,3);eq(result[1],nil);eq(result[2],"transfer-tail");eq(result[3],nil)
    R.nativeTransfer=function(self,owner,food,src,dst)
        prior(self,owner,food,src,dst)
        error("original transfer sentinel",0)
    end
    api.settled={}
    local ok,message=pcall(ISTransferAction.transferItem,{},p,f,p.inv,b.inner)
    eq(ok,false);check(string.find(tostring(message),"original transfer sentinel",1,true)~=nil)
    eq(#api.settled,2);eq(api.settled[1].container,p.inv);eq(api.settled[2].container,b.inner)
    R.nativeTransfer=prior
end)
test("settle void success, original errors and busy cleanup",function()
    local api=A.api();local b,f=setup(api);R.Start();api.reenter=true
    eq(R.Settle(f,clock),true);eq(R.busy[f],nil)
    api.reenter=false;api.settleThrows=true
    local ok,message=R.Settle(f,clock);eq(ok,false);eq(message,"native settle sentinel");eq(R.busy[f],nil)
    local succeeded,err=pcall(R.ScanItem,b);eq(succeeded,false);check(string.find(tostring(err),"native settle sentinel",1,true)~=nil)
end)
test("save uses flushKnown and preserves lastSeen on failure",function()
    local api=A.api();setup(api);R.Start();clock=101
    eq(R.FlushAll(),true);eq(count("flush"),1);eq(C.Global().lastSeen,101)
    api.flushThrows=true;clock=102
    local ok,message=R.FlushAll();eq(ok,false);eq(message,"native flush sentinel");eq(C.Global().lastSeen,101)
    local saved,err=pcall(emit,"OnSave");eq(saved,false);check(string.find(tostring(err),"native flush sentinel",1,true)~=nil)
end)
test("health loss deactivates then rebuilds legacy registry",function()
    local api=A.api();local b,f=setup(api);R.Start();api.ready=false
    clock=101;R.Tick();eq(B.IsActive(),false);eq(api.active,false);check(R.foods[f]);check(R.bags[b])
    local prior=A.legacyAge;clock=102;R.Tick();check(A.legacyAge>prior)
    eq(count("activateOn"),1,"never automatically reactivates")
end)
test("replaced API method is rejected without bypassing old instance",function()
    local api=A.api();local b,f=setup(api);R.Start()
    api.fridgeFactor=function() return .9 end
    R.Tick();eq(B.IsActive(),false);eq(api.active,false);check(R.foods[f])
end)
test("global API replacement deactivates captured old API only",function()
    local api=A.api();local b,f=setup(api);R.Start()
    local replacement=A.api();SuQingNativeColdApi=replacement
    R.Tick();eq(B.IsActive(),false);eq(api.active,false);eq(replacement.ready,false)
    check(R.foods[f]);eq(count("bootstrap"),1)
end)
test("unconfirmed deactivation isolates and throws without legacy overlap",function()
    local api=A.api();local b,f=setup(api);R.Start();api.ready=false;api.refuseStop=true
    local ok,message=pcall(R.Tick);eq(ok,false);check(string.find(tostring(message),"normal restart required",1,true)~=nil)
    check(B.blocked);check(B.IsActive());check(empty(R.foods));eq(api.active,true)
    local again=pcall(R.Tick);eq(again,false)
    api.refuseStop=false;api.ready=true
end)
test("main menu shuts down and reload bootstraps once again",function()
    local api=A.api();setup(api);R.Start();emit("OnMainMenuEnter")
    eq(api.active,false);eq(B.IsActive(),false);eq(R.ready,false);eq(B.attempted,false)
    setup(api);R.Start();eq(B.IsActive(),true);eq(count("bootstrap"),1)
end)
test("shutdown errors clear Lua state and remain visible",function()
    local api=A.api();setup(api);R.Start();api.shutdownThrows=true
    local ok,message=pcall(emit,"OnMainMenuEnter");eq(ok,false);check(string.find(tostring(message),"shutdown",1,true)~=nil)
    eq(R.ready,false);check(empty(R.foods));check(B.blocked)
    api.shutdownThrows=false;api.healthThrows=false;api.shutdown();B.blocked=false;B.Shutdown()
end)
local summary="NATIVE_BRIDGE_SUMMARY cases="..cases.." assertions="..assertions.." PASS"
print(summary)
return summary

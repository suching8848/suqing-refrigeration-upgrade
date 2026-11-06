local REVIEW_FEATURES=true
-- First display subscribes before the existing exact-signature assertions.
-- Real PZO Kahlua; trusted plain ownership mocks only, no game/world/save.
local C,R=SuQingRefrigeration,SuQingRefrigeration.Runtime
local cases,assertions=0,0
local counts={native=0,cooling=0,config=0,integral=0}
local wall=100000
function getTimestampMs() return wall end
local function check(ok,label) assertions=assertions+1;assert(ok,label or "runtime load review") end
local function eq(a,b,label) check(a==b,(label or "equal")..": "..tostring(a).." / "..tostring(b)) end
local function test(name,fn) cases=cases+1;fn() end
local function empty(values) for _ in pairs(values) do return false end return true end
local function pack(...) return {n=select("#",...),...} end
local function resetCounts() counts={native=0,cooling=0,config=0,integral=0} end
local oldConfig=C.Config
C.Config=function(...) counts.config=counts.config+1;return oldConfig(...) end
local oldIntegral=R.Integral
R.Integral=function(...) counts.integral=counts.integral+1;return oldIntegral(...) end
local oldCooling=R.Cooling
R.Cooling=function(...) counts.cooling=counts.cooling+1;return oldCooling(...) end
local oldNative=FoodIndex.updateAge
FoodIndex.updateAge=function(food,...)
    counts.native=counts.native+1
    if food.failNative then error("deliberate native failure") end
    local result=oldNative(food,...)
    if food.onNative then food.onNative(food) end
    return result
end
clock=1000
SandboxVars.FoodRotSpeed=5
SandboxVars.SuQingRefrigeration={Enabled=true,RotSpeedPercent=2.5}
R.Start();check(R.ready,"runtime starts")
local function setup(number,bags)
    clock=1000;wall=100000
    R.foods=setmetatable({}, {__mode="k"});R.bags=setmetatable({}, {__mode="k"});R.busy=setmetatable({}, {__mode="k"})
    R.lastTime=nil;R.processCount=0;R.ticks=0;R.dirty=false;R.processBudget=nil;R.discoveryMs=nil
    if R.lastSettled then R.lastSettled=setmetatable({}, {__mode="k"}) end
    if R.stateCache then R.stateCache:Reset();R.batch=nil;R.queue={};R.queueHead=1;R.queued=setmetatable({}, {__mode="k"}) end
    SandboxVars.FoodRotSpeed=5;SandboxVars.SuQingRefrigeration={Enabled=true,RotSpeedPercent=2.5}
    C.global=nil;local global=C.Global()
    global.history={{time=-1000000000,rate=0.2,rot=1},{time=24,rate=0,rot=1},
        {time=48,rate=1,rot=1.4},{time=120,rate=0.2,rot=0.7},
        {time=240,rate=0.1,rot=0.4},{time=360,rate=0.025,rot=0.4},
        {time=480,rate=0.05,rot=0.4},{time=744,rate=0.025,rot=0.4}}
    global.lastSeen=clock
    players={};processItems=list()
    local owners,foods={},{}
    for n=1,bags do
        local owner=bag("Fixture.Cold"..n);owner.inner.kind="ItemContainer"
        owner.md[C.key]={schema=1,on=true,paid=true,token="fixture-paid-"..n,batteries={1,2,3,4,5,6}}
        owners[n]=owner;R.bags[owner]=true
    end
    for n=1,number do
        local owner=owners[(n-1)%bags+1]
        local value=item("Base.Apple","Food")
        setmetatable(value,nil) -- trusted plain mock, matching the cache contract
        function value:updateAge(...) return FoodIndex.updateAge(self,...) end
        function value:getLastAged() return self.last end
        value.nativeRate=n%3==0 and 0 or (n%3==1 and 1 or 0.2)
        owner.inner:AddItem(value)
        value.md[C.foodKey]={schema=1,time=clock,age=value.age,heat=value.heat}
        foods[n]=value;R.foods[value]=true
    end
    R.SyncConfig(clock,false)
    resetCounts()
    return foods,owners
end

local foods,owners=setup(571,6)
for step=1,8 do clock=1000+step/6000;wall=wall+16;R.Tick() end
local first={native=counts.native,cooling=counts.cooling,config=counts.config,integral=counts.integral}
eq(first.native,571*8,"all eight world steps still call nativeAge for all foods")
if REVIEW_FEATURES then
    eq(first.cooling,6,"six direct containers require six strict Cooling calls")
    eq(first.config,8,"one config read per tick")
    eq(first.integral,8,"one common integral per tick")
else
    eq(first.cooling,571*8,"reference strict Cooling per food and tick")
    eq(first.config,571*8+8,"reference per-food and per-tick config")
    eq(first.integral,571*8,"reference per-food integral")
end
local vectors={}
for _,value in ipairs(foods) do vectors[#vectors+1]=tostring(value.age)..":"..tostring(value.heat)..":"..tostring(value.last) end
local vector=table.concat(vectors,",")
clock=1000+1/60+1/6000;wall=wall+16;R.Tick()
if REVIEW_FEATURES then eq(counts.cooling,12,"next TTL window rechecks six direct containers") end
local metric="STATE_RUNTIME_LOAD native="..first.native.." cooling="..first.cooling
    .." config="..first.config.." integral="..first.integral.." foods=571 containers=6 ticks=8 history=8"

if REVIEW_FEATURES then
test("native freshness callback preserves a valid current batch",function()
    local f,b=setup(12,2)
    f[1].onNative=function(value) emit("OnContainerUpdate",value) end
    clock=1000.001;R.Tick()
    eq(counts.native,12);eq(counts.cooling,2);eq(counts.config,1);eq(counts.integral,1)
    eq(R.batch,nil);eq(R.busy[f[1]],nil)
end)
test("known callback invalidation leaves the remaining items strict",function()
    local f,b=setup(12,2);local fired=false
    for _,value in ipairs(f) do
        value.onNative=function()
            if not fired then fired=true;R.InvalidateState() end
        end
    end
    clock=1000.001;R.Tick()
    check(counts.cooling>=12,"after invalidation remaining settlements cannot use the discarded batch")
    eq(R.batch,nil);eq(counts.native,12)
end)
test("throwing public wrapper cannot leak batch context",function()
    setup(1,1);local prior=R.Settle
    R.Settle=function() error("deliberate wrapper failure") end
    clock=1000.001;local result=pack(pcall(R.Tick));R.Settle=prior
    eq(result[1],false);eq(R.batch,nil);eq(R.lastTime,nil)
    check(string.find(tostring(result[2]),"deliberate wrapper failure",1,true)~=nil)
end)
test("failed native settlement clears stale display memo",function()
    local f=setup(1,1);R.Settle(f[1],clock);check(R.lastSettled[f[1]]~=nil)
    f[1].failNative=true;local errors=R.stats.errors
    eq(R.Settle(f[1],clock),false);eq(R.lastSettled[f[1]],nil)
    eq(R.busy[f[1]],nil);eq(R.stats.errors,errors+1)
end)
test("ScanItem and ScanContainer bypass a stale state cache",function()
    local f,b=setup(2,1);clock=1000.001;R.Tick()
    b[1].md[C.key].on=false
    R.ScanItem(f[1]);eq(f[1].md[C.foodKey],nil,"single-item scan immediately sees carrier switch")
    R.ScanContainer(b[1].inner);eq(f[2].md[C.foodKey],nil,"container scan is strict")
end)
test("public ScanItem with supplied seen remains strict inside a batch",function()
    local f,b=setup(2,1);clock=1000.001;R.Tick()
    R.batch={time=clock,enabled=true,rate=0.025,epoch=R.stateEpoch,ms=wall}
    b[1].md[C.key].on=false
    R.ScanItem(f[1],{},0)
    eq(R.batch,nil,"public scan invalidates even when caller supplies recursion arguments")
    eq(f[1].md[C.foodKey],nil,"explicit-seen scan uses live carrier state")
    eq(R.foods[f[1]],nil,"explicit-seen scan releases old cooling ownership")
end)
test("transfer after insertion failure still clears old cooling ownership",function()
    local f,b=setup(1,1);local warm=inventory();warm.kind="ItemContainer"
    local prior=R.nativeTransfer
    R.nativeTransfer=function(self,person,value,source,destination)
        source:Remove(value);destination:AddItem(value);error("inserted then failed")
    end
    local result=pack(pcall(ISTransferAction.transferItem,{},nil,f[1],b[1].inner,warm));R.nativeTransfer=prior
    eq(result[1],false);eq(f[1].parent,warm);eq(f[1].md[C.foodKey],nil)
    check(string.find(tostring(result[2]),"inserted then failed",1,true)~=nil)
end)
test("transfer preserves multiple returns including nil",function()
    local f,b=setup(1,1);local prior=R.nativeTransfer
    R.nativeTransfer=function(self,person,value,source,destination,...) return value,nil,"tail",nil end
    local result=pack(ISTransferAction.transferItem({},nil,f[1],b[1].inner,b[1].inner));R.nativeTransfer=prior
    eq(result.n,4);eq(result[1],f[1]);eq(result[2],nil);eq(result[3],"tail");eq(result[4],nil)
end)
test("bounded discovery continues pending containers without restarting",function()
    setup(0,1);local root=inventory();root.kind="ItemContainer"
    for n=1,100 do root:AddItem(item("Base.Apple","Food")) end
    R.queue={};R.queueHead=1;R.queued=setmetatable({}, {__mode="k"});R.processBudget=0
    R.QueueContainer(root);local before=R.stats.queued
    R.Discover(clock);check(R.stats.queued-before<=32,"first discovery stays within item budget")
    local progress=R.queue[1].index;check(progress>0 and progress<=32)
    R.Discover(clock);check(R.queue[1].index>progress,"pending pass progresses at same wall time")
    R.Discover(clock);R.Discover(clock)
    eq(R.stats.queued-before,100,"all pending items eventually scanned")
end)
test("backward time rewrites food anchors without negative credit",function()
    local f=setup(2,1);clock=1000.001;R.Tick();local before=f[1].age
    clock=999.9;R.Tick();eq(f[1].md[C.foodKey].time,clock)
    check(f[1].age>=before,"rollback cannot invent rejuvenation")
    eq(R.batch,nil)
end)
test("display hit requires same time and complete memo signatures",function()
    local f=setup(1,1);R.Settle(f[1],clock);R.SettleDisplay(f[1],clock);local before=counts.native
    eq(R.SettleDisplay(f[1],clock),true);eq(counts.native,before,"valid memo avoids native call")
    eq(getmetatable(R.lastSettled[f[1]].containerRef).__mode,"v","memo owner reference is weak-valued")
    f[1].last=f[1].last-0.001;R.SettleDisplay(f[1],clock)
    eq(counts.native,before+1,"lastAged change forces strict settlement")
    local record=f[1].md[C.foodKey];record.heat=record.heat+0.01
    R.SettleDisplay(f[1],clock);eq(counts.native,before+2,"record mutation forces strict settlement")
    R.SettleDisplay(f[1],clock+0.001);eq(counts.native,before+3,"different world time forces strict settlement")
end)
test("failed flush restores saved lastSeen and reports failure",function()
    local f=setup(1,1);local global=C.Global();global.lastSeen=999.5
    f[1].failNative=true;local ok=R.FlushAll()
    eq(ok,false);eq(global.lastSeen,999.5);eq(R.batch,nil)
end)
test("main menu drops pending state and data references",function()
    setup(2,1);clock=1000.001;R.Tick();emit("OnMainMenuEnter")
    eq(R.ready,false);eq(R.batch,nil);check(empty(R.foods));check(empty(R.lastSettled))
    eq(R.discoveryMs,nil);eq(R.processBudget,nil);eq(C.global,nil)
end)
end
return metric.."\nSTATE_RUNTIME_VECTOR "..vector
    .."\nSTATE_RUNTIME_REVIEW cases="..cases.." assertions="..assertions.." PASS"

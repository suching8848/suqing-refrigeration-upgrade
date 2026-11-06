require "SuQingRefrigeration/Core"
require "SuQingRefrigeration/StateCache"
require "SuQingRefrigeration_Native"
require "TimedActions/ISTransferAction"
local C=SuQingRefrigeration
C.Runtime=C.Runtime or {}
local R=C.Runtime
local N=C.NativeBackend
if R.loaded then return R end
R.loaded=true
R.foods=setmetatable({}, {__mode="k"})
R.bags=setmetatable({}, {__mode="k"})
R.busy=setmetatable({}, {__mode="k"})
R.lastSettled=setmetatable({}, {__mode="k"})
R.stats={settled=0,discovered=0,errors=0,strictCooling=0,displayHits=0,queued=0,memoCaptures=0,memoSkips=0}
R.displayDepth=0
R.stateEpoch=0
R.queue={};R.queueHead=1;R.queued=setmetatable({}, {__mode="k"})
local function now() return getGameTime():getWorldAgeHours() end
local function wallMs()
    return type(getTimestampMs)=="function" and getTimestampMs() or nil
end
R.stateCache=C.StateCache.New(function(food) return R.Cooling(food) end)
function R.InvalidateState()
    R.stateEpoch=R.stateEpoch+1
    R.batch=nil
    R.stateCache:Invalidate()
    if N and N.IsActive() then N.Invalidate() end
end
-- Read-only lookup: do not allocate a new table for every food settlement.
local ROT_SPEED = {[1]=1.7,[2]=1.4,[3]=1,[4]=0.7,[5]=0.4}
local function rotSpeed()
    return ROT_SPEED[SandboxVars and SandboxVars.FoodRotSpeed or 3] or 1
end
function R.SyncConfig(t,starting)
    local g=C.Global(); g.history=g.history or {}
    local h=g.history; local enabled,rate,rot
    if N and N.IsActive() then enabled,rate,rot=N.Config()
    else enabled,rate=C.Config();rot=rotSpeed() end
    if R.configEnabled~=enabled or R.configRate~=rate or R.configRot~=rot
        or (R.configTime and t<R.configTime) then R.InvalidateState() end
    R.configEnabled,R.configRate,R.configRot,R.configTime=enabled,rate,rot,t
    -- A save that advanced while this mod was absent gets an ordinary-aging
    -- gap. Loading the same save normally does not advance world time.
    if starting and C.Finite(g.lastSeen) and t>g.lastSeen+0.0001 then
        h[#h+1]={time=g.lastSeen,rate=1,rot=rot}
    end
    local effective=enabled and rate or 1
    local last=h[#h]
    if not last then h[1]={time=-1000000000,rate=effective,rot=rot}
    elseif last.time>t then
        while #h>0 and h[#h].time>t do table.remove(h) end
        h[#h+1]={time=t,rate=effective,rot=rot}
    elseif last.rate~=effective or last.rot~=rot then
        h[#h+1]={time=t,rate=effective,rot=rot}
    end
    g.lastSeen=t
    return enabled,rate
end
-- Integrate world-time settings changes, including time outside loaded chunks.
function R.Integral(first,last)
    if last<=first then return 0 end
    local h=C.Global().history or {}; local rate,rot=1,rotSpeed(); local cursor=first; local sum=0
    for _,v in ipairs(h) do
        if v.time<=first then rate,rot=v.rate,v.rot
        elseif v.time<last then
            sum=sum+(v.time-cursor)*rate*rot; cursor=v.time; rate,rot=v.rate,v.rot
        else break end
    end
    return sum+(last-cursor)*rate*rot
end
function R.Cooling(food)
    R.stats.strictCooling=R.stats.strictCooling+1
    local container=food:getContainer(); local seen
    for _=1,64 do
        if not container or (seen and seen[container]) then return false end
        local bag=container:getContainingItem()
        if not bag then return false end
        local record=C.Record(bag)
        -- Most traversed containers have no cooling record. Inspect the cheap
        -- record fields before crossing into Java to classify their equipment.
        -- No result is cached: moves, toggles and external record edits are seen
        -- on the very next call, including calls at the same world time.
        if type(record)=="table" and record.on==true and C.Wearable(bag) and C.Valid(record) then
            R.bags[bag]=true; return true
        end
        local parent=bag:getContainer()
        if not parent then return false end
        -- Direct cold bags, loose food and root inventories need no cycle table.
        seen=seen or {}; seen[container]=true
        container=parent
    end
    return false
end
local function settlementIntegral(first,last)
    local batch=R.batch
    if batch and batch.time==last and batch.epoch==R.stateEpoch then
        if batch.first==first then return batch.integral end
        local value=R.Integral(first,last)
        batch.first,batch.integral=first,value
        return value
    end
    return R.Integral(first,last)
end
local function validFoodRecord(r)
    return type(r)=="table" and r.schema==1 and C.Finite(r.time)
        and C.Finite(r.age) and r.age>=0
end
-- Reuse a stateless protected-call target instead of allocating a closure per
-- food and tick. Each invocation still reads live food/container/config state.
local function settleFood(food,t)
        local md=food:getModData(); local previous=md[C.foodKey]
        local cooling
        if R.batch then cooling=R.stateCache:Resolve(food,t)
        else cooling=R.Cooling(food) end
        local raw=food:getAge()
        local incomingHeat=food.getHeat and food:getHeat() or nil
        if not C.Finite(raw) or raw<0 then return end
        -- Invoke the real Java implementation once. This preserves natural
        -- fridge/freezer aging and thawing; the cap never multiplies them.
        R.nativeAge(food,false)
        local aged=food:getAge()
        if not C.Finite(aged) then return end
        if validFoodRecord(previous) and t>=previous.time then
            local baseline=math.min(previous.age,raw)
            -- Same-time explicit external edits are not mistaken for catch-up.
            if t==previous.time and raw>previous.age then baseline=raw end
            local maximum=baseline+settlementIntegral(previous.time,t)/24
            local adjusted=math.min(aged,math.max(baseline,maximum))
            food:setAge(adjusted)
        end
        food:setLastAged(t)
        if cooling then
            local nextHeat=incomingHeat
            R.foods[food]=true
            local enabled,rate
            if R.batch then enabled,rate=R.batch.enabled,R.batch.rate
            else enabled,rate=C.Config() end
            if enabled and rate<1 and C.Finite(incomingHeat) and food.setHeat then
                -- Normalized 1 -> 0.2 in 20 game minutes; age cap unchanged.
                local before=validFoodRecord(previous) and C.Finite(previous.heat) and previous.heat or incomingHeat
                before=math.min(before,incomingHeat)
                local elapsed=validFoodRecord(previous) and math.max(0,t-previous.time) or 0
                nextHeat=math.min(incomingHeat,math.max(0.2,before-2.4*elapsed))
                food:setHeat(nextHeat)
            end
            md[C.foodKey]={schema=1,time=t,age=food:getAge(),heat=nextHeat}
        else
            md[C.foodKey]=nil; R.foods[food]=nil
        end
        local memo=R.lastSettled[food]
        if not memo then
            memo={containerRef=setmetatable({}, {__mode="v"})}
            R.lastSettled[food]=memo
        end
        local stamp=R.batch and R.batch.ms or wallMs()
        local shown=memo.displaySeen
        -- Keep discovery ownership current even when nobody displays the food.
        if shown and stamp and stamp>=shown and stamp-shown<500 then
            memo.time,memo.ms,memo.epoch=t,stamp,R.stateEpoch
            memo.containerRef[1]=food:getContainer()
            memo.age,memo.heat=food:getAge(),food.getHeat and food:getHeat() or nil
            memo.lastAged=food.getLastAged and food:getLastAged() or nil
            memo.record=md[C.foodKey]
            -- Logical ledger doubles remain distinct from physical Java floats.
            memo.recordTime=memo.record and memo.record.time
            memo.recordAge=memo.record and memo.record.age
            memo.recordHeat=memo.record and memo.record.heat
            R.stats.memoCaptures=R.stats.memoCaptures+1
        else
            memo.containerRef[1]=food:getContainer()
            if shown then memo.displaySeen=nil end
            if memo.ms~=nil then
                memo.time,memo.ms,memo.epoch=nil,nil,nil
                memo.age,memo.heat,memo.lastAged=nil,nil,nil
                memo.record,memo.recordTime,memo.recordAge,memo.recordHeat=nil,nil,nil,nil
            end
            R.stats.memoSkips=R.stats.memoSkips+1
        end
        R.stats.settled=R.stats.settled+1
end
function R.Settle(food,t)
    if not R.ready or R.busy[food] or not instanceof(food,"Food") then return end
    if N then N.AssertUsable() end
    if N and N.IsActive() then
        R.busy[food]=true
        local ok,message=pcall(N.Settle,food)
        R.busy[food]=nil
        if not ok then
            R.stats.errors=R.stats.errors+1
            if R.stats.errors<=5 then print("[SuQingRefrigeration] native settle: "..tostring(message)) end
            return false,message
        end
        R.stats.settled=R.stats.settled+1
        return true
    end
    R.busy[food]=true
    local ok,err=pcall(settleFood,food,t)
    R.busy[food]=nil
    if not ok then
        R.lastSettled[food]=nil
        R.stats.errors=R.stats.errors+1
        if R.stats.errors<=5 then print("[SuQingRefrigeration] settle: "..tostring(err)) end
    end
    return ok
end
-- This entry is used only inside the audited inventory-render context. Real
-- actions, transfers and unknown callers always retain the strict Settle path.
local function displayResult(food,placeholder,ok,...)
    if (not ok or not (...)) and placeholder and R.lastSettled[food]==placeholder then
        R.lastSettled[food]=nil
    end
    if not ok then error((...),0) end
    return ...
end
function R.SettleDisplay(food,t)
    if N and N.IsActive() then return R.Settle(food,t) end
    local memo=R.lastSettled[food]
    local stamp=wallMs()
    local placeholder
    if R.ready and stamp then
        if not memo and instanceof(food,"Food") then
            -- A first display still performs strict settlement. This placeholder
            -- arms its signature capture without trusting any existing ledger.
            memo={containerRef=setmetatable({}, {__mode="v"})}
            R.lastSettled[food]=memo
            placeholder=memo
        end
        if memo then memo.displaySeen=stamp end
    end
    if R.ready and R.foods[food] and memo and stamp and memo.ms and stamp>=memo.ms
        and stamp-memo.ms<500 and memo.epoch==R.stateEpoch and memo.time==t
        and food:getContainer()==memo.containerRef[1] and food:getAge()==memo.age
        and (not food.getHeat or food:getHeat()==memo.heat)
        and food.getLastAged and food:getLastAged()==memo.lastAged
        and food:getModData()[C.foodKey]==memo.record
        and memo.record and memo.record.schema==1 and memo.record.time==memo.recordTime
        and memo.recordTime==memo.time and memo.record.age==memo.recordAge
        and memo.recordAge==memo.age and memo.record.heat==memo.recordHeat then
        R.stats.displayHits=R.stats.displayHits+1
        return true
    end
    return displayResult(food,placeholder,pcall(R.Settle,food,t))
end
local function scanItem(item,seen,depth)
    if not item then return end
    if depth>64 or seen[item] then return end
    seen[item]=true
    if instanceof(item,"Food") then
        if N and N.IsActive() then
            local ok,message=R.Settle(item,now())
            if ok==false then error(message or "native subtree settlement failed",0) end
        elseif R.Cooling(item) or item:getModData()[C.foodKey] then
            R.stats.discovered=R.stats.discovered+1; R.Settle(item,now())
        end
    end
    local inner=C.Inner(item)
    if inner then
        if C.Valid(C.Record(item)) then R.bags[item]=true end
        local items=inner:getItems()
        for i=0,items:size()-1 do scanItem(items:get(i),seen,depth+1) end
    end
end
function R.ScanItem(item,seen,depth)
    -- Public scans are strict even when a caller supplies its own seen table.
    -- Only the private recursive walk may retain the current scan context.
    R.InvalidateState()
    return scanItem(item,seen or {},depth or 0)
end
function R.ScanContainer(container)
    if not container then return end
    R.InvalidateState()
    local items=container:getItems(); local seen={}
    for i=0,items:size()-1 do scanItem(items:get(i),seen,0) end
end
function R.SettleTree(item) R.ScanItem(item) end
function R.ScanPlayers()
    for i=0,getNumActivePlayers()-1 do
        local p=getSpecificPlayer(i)
        if p then R.ScanContainer(p:getInventory()) end
    end
end
function R.ScanSquare(square)
    if not R.ready or not square then return end
    local objects=square:getObjects()
    for i=0,objects:size()-1 do
        local obj=objects:get(i)
        for j=0,obj:getContainerCount()-1 do R.ScanContainer(obj:getContainerByIndex(j)) end
    end
    local world=square:getWorldObjects()
    for i=0,world:size()-1 do R.ScanItem(world:get(i):getItem()) end
    local moving=square:getStaticMovingObjects()
    for i=0,moving:size()-1 do
        local o=moving:get(i)
        if o.getContainer then R.ScanContainer(o:getContainer()) end
    end
end
-- B42.21 ordering was audited in IngameState: IsoWorld.update runs before
-- GameTime.update, and OnTick runs after GameTime.update. Settling at OnTick
-- stamps the new native lastAged BEFORE the next native process-item pass.
function R.QueueContainer(container)
    if not container or R.queued[container] then return end
    R.queued[container]=true
    R.queue[#R.queue+1]={container=container,index=0}
end
local function queueRoots()
    for i=0,getNumActivePlayers()-1 do
        local player=getSpecificPlayer(i)
        if player then R.QueueContainer(player:getInventory()) end
    end
    for bag in pairs(R.bags) do R.QueueContainer(C.Inner(bag)) end
end
local function discover(item,t)
    if not item then return end
    if instanceof(item,"Food") then
        local memo=R.lastSettled[item]
        if not R.foods[item] or not memo or item:getContainer()~=memo.containerRef[1] then
            if item:getModData()[C.foodKey] or R.Cooling(item) then
                R.stats.discovered=R.stats.discovered+1
                R.Settle(item,t)
            end
        end
    end
    local inner=C.Inner(item)
    if inner then
        if C.Valid(C.Record(item)) then R.bags[item]=true end
        R.QueueContainer(inner)
    end
end
function R.Discover(t)
    if N and N.IsActive() then return end
    local stamp=wallMs()
    if not R.discoveryMs or not stamp or stamp<R.discoveryMs or stamp-R.discoveryMs>=1000 then
        R.discoveryMs=stamp
        -- Keep a pending pass; restarting it would starve later containers.
        if R.queueHead>#R.queue and (R.processBudget or 0)<=0 then
            R.queue={};R.queueHead=1;R.queued=setmetatable({}, {__mode="k"})
            queueRoots()
            local cell=getCell()
            local list=cell and cell:getProcessItems()
            R.processBudget=list and list:size() or 0
        end
    end
    local started=stamp
    for n=1,32 do
        local job=R.queue[R.queueHead]
        local item
        if job then
            local list=job.container:getItems()
            if job.index<list:size() then
                item=list:get(job.index);job.index=job.index+1
            else
                R.queueHead=R.queueHead+1
            end
        elseif (R.processBudget or 0)>0 then
            local cell=getCell()
            local list=cell and cell:getProcessItems()
            local size=list and list:size() or 0
            if size>0 then
                R.cursor=((R.cursor or -1)+1)%size
                item=list:get(R.cursor)
            end
            R.processBudget=R.processBudget-1
        else break end
        if item then discover(item,t);R.stats.queued=R.stats.queued+1 end
        if n%8==0 and started then
            local current=wallMs()
            if current and current-started>=1 then break end
        end
    end
end
local function settleBatch(t)
    for food in pairs(R.foods) do R.Settle(food,t) end
end
local function nativeHeartbeat()
    if N then N.AssertUsable() end
    if not N or not N.IsActive() then return false end
    if N.Check(R) then
        local ok,message=pcall(R.SyncConfig,now(),false)
        if not ok then N.Fail(R,message) end
    end
    return true
end
function R.Tick()
    if not R.ready then return end
    if nativeHeartbeat() then
        R.ticks=(R.ticks or 0)+1;R.dirty=false
        return
    end
    local t=now();local enabled,rate=R.SyncConfig(t,false)
    if R.lastTime~=t then
        R.lastTime=t
        R.batch={time=t,enabled=enabled,rate=rate,epoch=R.stateEpoch,ms=wallMs()}
        local ok,message=pcall(settleBatch,t)
        R.batch=nil
        if not ok then R.lastTime=nil;error(message) end
    end
    R.ticks=(R.ticks or 0)+1
    R.dirty=false
    R.Discover(t)
end
local function flushBody(t)
    R.SyncConfig(t,false)
    R.ScanPlayers()
    for bag in pairs(R.bags) do R.ScanItem(bag) end
    for food in pairs(R.foods) do R.Settle(food,t) end
end
function R.FlushAll()
    if not R.ready then return false,"not_ready" end
    if N then N.AssertUsable() end
    if N and N.IsActive() then
        local global=C.Global();local previous=global.lastSeen
        local ok,message=pcall(function()
            R.SyncConfig(now(),false)
            N.FlushKnown()
        end)
        if not ok then global.lastSeen=previous;return false,message end
        return true
    end
    R.InvalidateState()
    local t=now();local global=C.Global();local previous=global.lastSeen
    local errors=R.stats.errors
    local ok,message=pcall(flushBody,t)
    R.batch=nil
    if not ok or R.stats.errors~=errors then
        global.lastSeen=previous
        return false,not ok and message or "food settlement failed"
    end
    global.lastSeen=t
    return true
end
function R.ClearLegacyForNative()
    R.foods=setmetatable({}, {__mode="k"})
    R.lastSettled=setmetatable({}, {__mode="k"})
    R.stateCache:Reset();R.batch=nil;R.lastTime=nil
    R.queue={};R.queueHead=1;R.queued=setmetatable({}, {__mode="k"})
    R.discoveryMs=nil;R.processBudget=nil
end
function R.RebuildLegacy()
    R.ClearLegacyForNative()
    R.SyncConfig(now(),false)
    R.ScanPlayers()
    for bag in pairs(R.bags) do R.ScanItem(bag) end
end
function R.Start()
    if not C.SP() or R.ready then return end
    local meta=__classmetatables and Food and __classmetatables[Food.class]
    local index=meta and meta.__index
    if not index or not index.updateAge or not ISTransferAction or not ISTransferAction.transferItem then
        print("[SuQingRefrigeration] required B42.21 hooks unavailable; installation disabled")
        return
    end
    if R.hooksInstalled and index.updateAge~=R.ageWrapper then
        print("[SuQingRefrigeration] another mod replaced the cooling hook; installation disabled")
        return
    end
    if not R.hooksInstalled then
    R.nativeAge=index.updateAge
    R.ageWrapper=function(food,...)
        if N then N.AssertUsable() end
        if R.ready and N and N.IsActive() then return R.nativeAge(food,...) end
        if R.ready and not R.busy[food] and (food:getModData()[C.foodKey] or R.Cooling(food)) then
            if R.displayDepth>0 then return R.SettleDisplay(food,now()) end
            R.Settle(food,now()); return
        end
        return R.nativeAge(food,...)
    end
    index.updateAge=R.ageWrapper
    R.nativeTransfer=ISTransferAction.transferItem
    local function pack(...) return {n=select("#",...),...} end
    ISTransferAction.transferItem=function(self,character,item,source,destination,...)
        if not R.ready then return R.nativeTransfer(self,character,item,source,destination,...) end
        R.ScanItem(item)
        local result=pack(pcall(R.nativeTransfer,self,character,item,source,destination,...))
        local postOk,postError=pcall(function()
            R.ScanItem(item)
            if result[1] and result[2] and result[2]~=item then R.ScanItem(result[2]) end
        end)
        R.dirty=true
        if not result[1] then
            if not postOk then print("[SuQingRefrigeration] transfer cleanup: "..tostring(postError)) end
            error(result[2])
        end
        if not postOk then error(postError) end
        return unpack(result,2,result.n)
    end
    R.hooksInstalled=true
    end
    R.ready=true
    R.stateCache:Reset()
    R.lastSettled=setmetatable({}, {__mode="k"})
    R.queue={};R.queueHead=1;R.queued=setmetatable({}, {__mode="k"})
    R.discoveryMs=nil;R.displayDepth=0
    R.SyncConfig(now(),true)
    R.ScanPlayers()
    if N then N.TryStart(R) end
    print("[SuQingRefrigeration] "..C.version.." single-player cooling ready")
end
Events.OnGameStart.Add(R.Start)
Events.OnTick.Add(R.Tick)
Events.OnTickEvenPaused.Add(function()
    if not R.ready then return end
    if nativeHeartbeat() then return end
    local cell=getCell(); if not cell then return end
    local items=cell:getProcessItems(); local count=items:size()
    if count~=R.processCount then
        R.processCount=count
        R.InvalidateState()
        -- A changed native list may contain freshly loaded cold food. Settle
        -- before IsoWorld's first pass, including near-rotten replacements.
        R.SyncConfig(now(),false)
        for i=0,count-1 do
            local food=items:get(i)
            if instanceof(food,"Food") and (food:getModData()[C.foodKey] or R.Cooling(food)) then
                R.Settle(food,now())
            end
        end
    end
end)
Events.LoadGridsquare.Add(function(square) if R.ready then R.ScanSquare(square) end end)
Events.OnContainerUpdate.Add(function(container)
    if not R.ready then return end
    R.dirty=true
    -- Native aging can report a freshness change inside our own settlement.
    -- It did not change the carrier entitlement and must not invalidate the
    -- entire current batch or recursively enter updateAge again.
    if container and R.busy[container] then return end
    R.InvalidateState()
    if N and N.IsActive() then return end
    if container and container.getItems then R.QueueContainer(container)
    elseif container and container.getContainer then R.QueueContainer(container:getContainer()) end
end)
Events.OnSave.Add(function()
    if R.ready then
        local ok,message=R.FlushAll()
        if not ok then error("[SuQingRefrigeration] save settlement: "..tostring(message)) end
    end
end)
Events.OnMainMenuEnter.Add(function()
    local shutdownOk,shutdownError=true,nil
    if N then shutdownOk,shutdownError=N.Shutdown() end
    R.ready=false; R.lastTime=nil; R.processCount=nil; R.cursor=nil
    R.foods=setmetatable({}, {__mode="k"}); R.bags=setmetatable({}, {__mode="k"})
    R.lastSettled=setmetatable({}, {__mode="k"})
    R.stateCache:Reset();R.batch=nil;R.displayDepth=0
    R.queue={};R.queueHead=1;R.queued=setmetatable({}, {__mode="k"})
    R.discoveryMs=nil;R.processBudget=nil
    R.configEnabled=nil;R.configRate=nil;R.configRot=nil;R.configTime=nil
    C.global=nil; C.proven=setmetatable({}, {__mode="k"})
    if not shutdownOk then error(shutdownError,0) end
end)
return R

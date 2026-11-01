require "SuQingRefrigeration/Core"
require "TimedActions/ISTransferAction"
local C=SuQingRefrigeration
C.Runtime=C.Runtime or {}
local R=C.Runtime
if R.loaded then return R end
R.loaded=true
R.foods=setmetatable({}, {__mode="k"})
R.bags=setmetatable({}, {__mode="k"})
R.busy=setmetatable({}, {__mode="k"})
R.stats={settled=0,discovered=0,errors=0}
local function now() return getGameTime():getWorldAgeHours() end
-- Read-only lookup: do not allocate a new table for every food settlement.
local ROT_SPEED = {[1]=1.7,[2]=1.4,[3]=1,[4]=0.7,[5]=0.4}
local function rotSpeed()
    return ROT_SPEED[SandboxVars and SandboxVars.FoodRotSpeed or 3] or 1
end
function R.SyncConfig(t,starting)
    local g=C.Global(); g.history=g.history or {}
    local h=g.history; local enabled,rate=C.Config(); local rot=rotSpeed()
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
local function validFoodRecord(r)
    return type(r)=="table" and r.schema==1 and C.Finite(r.time)
        and C.Finite(r.age) and r.age>=0
end
-- Reuse a stateless protected-call target instead of allocating a closure per
-- food and tick. Each invocation still reads live food/container/config state.
local function settleFood(food,t)
        local md=food:getModData(); local previous=md[C.foodKey]
        local cooling=R.Cooling(food)
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
            local maximum=baseline+R.Integral(previous.time,t)/24
            local adjusted=math.min(aged,math.max(baseline,maximum))
            food:setAge(adjusted)
        end
        food:setLastAged(t)
        if cooling then
            local nextHeat=incomingHeat
            R.foods[food]=true
            local enabled,rate=C.Config()
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
        R.stats.settled=R.stats.settled+1
end
function R.Settle(food,t)
    if not R.ready or R.busy[food] or not instanceof(food,"Food") then return end
    R.busy[food]=true
    local ok,err=pcall(settleFood,food,t)
    R.busy[food]=nil
    if not ok then
        R.stats.errors=R.stats.errors+1
        if R.stats.errors<=5 then print("[SuQingRefrigeration] settle: "..tostring(err)) end
    end
    return ok
end
function R.ScanItem(item,seen,depth)
    if not item then return end
    seen=seen or {}; depth=depth or 0
    if depth>64 or seen[item] then return end
    seen[item]=true
    if instanceof(item,"Food") then
        if R.Cooling(item) or item:getModData()[C.foodKey] then
            R.stats.discovered=R.stats.discovered+1; R.Settle(item,now())
        end
    end
    local inner=C.Inner(item)
    if inner then
        if C.Valid(C.Record(item)) then R.bags[item]=true end
        local items=inner:getItems()
        for i=0,items:size()-1 do R.ScanItem(items:get(i),seen,depth+1) end
    end
end
function R.ScanContainer(container)
    if not container then return end
    local items=container:getItems(); local seen={}
    for i=0,items:size()-1 do R.ScanItem(items:get(i),seen,0) end
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
function R.Tick()
    if not R.ready then return end
    local t=now(); R.SyncConfig(t,false)
    if R.lastTime~=t then
        R.lastTime=t
        for food in pairs(R.foods) do R.Settle(food,t) end
    end
    R.ticks=(R.ticks or 0)+1
    if R.dirty or R.ticks%120==0 then
        R.dirty=false; R.ScanPlayers()
        -- Only already known cold bags, no neighborhood/world scan.
        for bag in pairs(R.bags) do
            if C.Valid(C.Record(bag)) then R.ScanItem(bag) else R.bags[bag]=nil end
        end
    end
    -- Bounded discovery fallback for vehicle/foreign AddItem paths. Never copy
    -- or traverse the whole process list each tick; 16 entries per tick max.
    local cell=getCell()
    if cell then
        local list=cell:getProcessItems(); local size=list:size()
        if size>0 then
            for _=1,math.min(16,size) do
                R.cursor=((R.cursor or -1)+1)%size
                local item=list:get(R.cursor)
                if instanceof(item,"Food") and (item:getModData()[C.foodKey] or R.Cooling(item)) then
                    R.Settle(item,t)
                end
            end
        end
    end
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
        if R.ready and not R.busy[food] and (food:getModData()[C.foodKey] or R.Cooling(food)) then
            R.Settle(food,now()); return
        end
        return R.nativeAge(food,...)
    end
    index.updateAge=R.ageWrapper
    R.nativeTransfer=ISTransferAction.transferItem
    ISTransferAction.transferItem=function(self,character,item,source,destination,...)
        if not R.ready then return R.nativeTransfer(self,character,item,source,destination,...) end
        R.ScanItem(item)
        local result=R.nativeTransfer(self,character,item,source,destination,...)
        R.ScanItem(item); if result and result~=item then R.ScanItem(result) end
        R.dirty=true
        return result
    end
    R.hooksInstalled=true
    end
    R.ready=true
    R.SyncConfig(now(),true)
    R.ScanPlayers()
    print("[SuQingRefrigeration] "..C.version.." single-player cooling ready")
end
Events.OnGameStart.Add(R.Start)
Events.OnTick.Add(R.Tick)
Events.OnTickEvenPaused.Add(function()
    if not R.ready then return end
    local cell=getCell(); if not cell then return end
    local items=cell:getProcessItems(); local count=items:size()
    if count~=R.processCount then
        R.processCount=count
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
    -- This event also occurs inside updateAge; avoid reentrant traversal.
end)
Events.OnSave.Add(function()
    if R.ready then
        R.Tick()
        C.Global().lastSeen=now()
    end
end)
Events.OnMainMenuEnter.Add(function()
    R.ready=false; R.lastTime=nil; R.processCount=nil; R.cursor=nil
    R.foods=setmetatable({}, {__mode="k"}); R.bags=setmetatable({}, {__mode="k"})
    C.global=nil; C.proven=setmetatable({}, {__mode="k"})
end)
return R

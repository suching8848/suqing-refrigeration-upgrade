-- Independent wearable-container entitlement. No script/stat/Workshop edits.
SuQingRefrigeration = SuQingRefrigeration or {}
local C = SuQingRefrigeration
if C.coreLoaded then return C end
C.coreLoaded = true
C.version = "1.0.0-rc.2-perf.8"
C.key = "SuQingRefrigeration"
C.foodKey = "SuQingRefrigerationFood"
C.cost = { {"Base.Battery", 6}, {"Base.ElectricWire", 4},
    {"Base.ElectronicsScrap", 4}, {"Base.SmallSheetMetal", 2} }
C.proven = setmetatable({}, {__mode="k"})
C.locks = setmetatable({}, {__mode="k"})
C.overrides = {}
local deny = { ["AcceptItemFunction.AmmoStrap_Bullets"]=true,
    ["AcceptItemFunction.AmmoStrap_Shells"]=true,
    ["AcceptItemFunction.HolsterShoulder"]=true,
    ["AcceptItemFunction.KeyRing"]=true, ["AcceptItemFunction.Wallet"]=true }
function C.Finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
function C.SP()
    return not (type(isClient)=="function" and isClient())
        and not (type(isServer)=="function" and isServer())
end
function C.Config()
    local v=SandboxVars and SandboxVars.SuQingRefrigeration or {}
    local n=v.RotSpeedPercent
    if not C.Finite(n) then n=20 end
    return v.Enabled~=false, math.max(0,math.min(100,n))/100
end
function C.Global()
    if not C.global then
        C.global=ModData and ModData.getOrCreate and ModData.getOrCreate(C.key) or {}
    end
    C.global.refunded=C.global.refunded or {}
    return C.global
end
function C.Copy(t)
    if type(t)~="table" then return t end
    local r={}; for k,v in pairs(t) do r[k]=C.Copy(v) end; return r
end
function C.Inner(item)
    if not item or not instanceof(item,"InventoryContainer") then return nil end
    return item:getInventory()
end
function C.Wearable(item)
    if not C.Inner(item) then return false end
    local slot=item:canBeEquipped()
    return slot~=nil and tostring(slot)~="" and tostring(slot)~="null"
end
function C.Record(item)
    return item and item:getModData()[C.key]
end
function C.Valid(r)
    if type(r)~="table" or r.schema~=1 or type(r.on)~="boolean"
        or type(r.token)~="string" or #r.token>160
        or type(r.batteries)~="table" or #r.batteries~=6 then return false end
    for _,n in ipairs(r.batteries) do
        -- The closed range also rejects infinities and NaN, without six nested
        -- Lua calls to Finite for every bag check. Keep validating live values.
        if type(n)~="number" or not (n>=0 and n<=100000) then return false end
    end
    return r.paid==true
end
-- An extension may explicitly classify a nonstandard filter. Never change it.
function C.RegisterContainer(fullType, allowed) C.overrides[fullType]=allowed==true end
function C.AcceptsFood(item)
    if not C.Wearable(item) then return false,"not_wearable" end
    local override=C.overrides[item:getFullType()]
    if override~=nil then return override, override and nil or "food_filter" end
    local inner=item:getInventory()
    local category=inner:getOnlyAcceptCategory()
    if category and category~="" then
        return string.lower(category)=="food", "food_filter"
    end
    local fn=inner:getAcceptItemFunction()
    if not fn or fn=="" then return true end
    if deny[fn] then return false,"food_filter" end
    if C.proven[item] then return true end
    local items=inner:getItems()
    for i=0,items:size()-1 do
        local food=items:get(i)
        if instanceof(food,"Food") and inner:isItemAllowed(food) then
            C.proven[item]=true; return true
        end
    end
    -- Positive probes only. Unrecognised negative probes do not claim all food
    -- is forbidden: place an allowed food once, inspect, empty, then install.
    if not C.samples and type(instanceItem)=="function" then
        C.samples={}
        for _,id in ipairs({"Base.Apple","Base.Steak","Base.Bread","Base.Potato"}) do
            local ok,v=pcall(instanceItem,id)
            if ok and v and instanceof(v,"Food") then C.samples[#C.samples+1]=v end
        end
    end
    for _,food in ipairs(C.samples or {}) do
        local ok,allowed=pcall(function() return inner:isItemAllowed(food) end)
        if ok and allowed then C.proven[item]=true; return true end
    end
    return false,"custom_filter"
end
local function has(inv,item) return inv and inv:getItems():contains(item) end
function C.Target(character,item,empty)
    if not C.SP() then return false,"multiplayer" end
    if not character or not C.Wearable(item) then return false,"not_wearable" end
    local inv=character:getInventory()
    if item:getContainer()~=inv or not has(inv,item) then return false,"main_inventory" end
    if empty then
        if character:isEquipped(item) or character:getPrimaryHandItem()==item
            or character:getSecondaryHandItem()==item then return false,"equipped" end
        if item:getInventory():getItems():size()~=0 then return false,"not_empty" end
        local f=item.getFluidContainer and item:getFluidContainer()
        if f and f:getAmount()>0 then return false,"fluid" end
    end
    local r=C.Record(item)
    if r~=nil and not C.Valid(r) then return false,"invalid_record" end
    return true
end
function C.Payment(character)
    local inv=character:getInventory(); local items=inv:getItems(); local selected={}
    for _,spec in ipairs(C.cost) do
        local found={}
        for i=0,items:size()-1 do
            local item=items:get(i)
            if item:getFullType()==spec[1] and not item:isFavorite() then
                found[#found+1]=item
                if #found==spec[2] then break end
            end
        end
        if #found~=spec[2] then return nil,"materials" end
        for _,item in ipairs(found) do selected[#selected+1]=item end
    end
    return selected
end
function C.CanInstallTarget(character,item)
    local accepted,reason=C.AcceptsFood(item)
    if not accepted then return false,reason end
    local ok,why=C.Target(character,item,true); if not ok then return false,why end
    if C.Record(item) then return false,"already_installed" end
    local enabled=C.Config(); if not enabled then return false,"disabled" end
    if not C.Runtime or not C.Runtime.ready then return false,"not_ready" end
    return true
end
function C.CanInstall(character,item)
    local ok,why=C.CanInstallTarget(character,item);if not ok then return false,why end
    local pay,err=C.Payment(character); if not pay then return false,err end
    return true,nil,pay
end
-- Native crafting has consumed these exact snapshotted objects already.
function C.PaidRecord(item,snapshots)
    local counts,batteries={},{}
    for _,s in ipairs(snapshots) do
        local id=s.fullType
        if id=="Base.Battery" or id=="Base.ElectricWire" or id=="Base.ElectronicsScrap" or id=="Base.SmallSheetMetal" then
            counts[id]=(counts[id] or 0)+1
            if id=="Base.Battery" then batteries[#batteries+1]=s.uses end
        elseif s.item~=item then return nil,"invalid_material" end
    end
    for _,cost in ipairs(C.cost) do if counts[cost[1]]~=cost[2] then return nil,"invalid_material" end end
    local g=C.Global();g.serial=(g.serial or 0)+1
    local r={schema=1,on=true,paid=true,batteries=batteries,
        token=tostring(item:getID())..":"..tostring(getTimestampMs())..":"..tostring(g.serial)}
    if not C.Valid(r) then return nil,"invalid_material" end
    return r
end
function C.Install(character,item)
    if C.locks[character] then return false,"busy" end
    local ok,why,pay=C.CanInstall(character,item); if not ok then return false,why end
    local inv=character:getInventory(); local batteries={}
    for _,material in ipairs(pay) do
        if material:getFullType()=="Base.Battery" then
            batteries[#batteries+1]=material:getCurrentUsesFloat()
        end
    end
    local g=C.Global(); g.serial=(g.serial or 0)+1
    local record={schema=1,on=true,paid=true,batteries=batteries,
        token=tostring(item:getID())..":"..tostring(getTimestampMs())..":"..tostring(g.serial)}
    if not C.Valid(record) then return false,"invalid_material" end
    C.locks[character]=true
    local succeeded,errorMessage=pcall(function()
        for _,material in ipairs(pay) do
            if not has(inv,material) then error("payment_changed") end
            inv:Remove(material)
            if has(inv,material) then error("payment_remove") end
        end
        item:getModData()[C.key]=record
        if not C.Valid(C.Record(item)) then error("record_write") end
    end)
    if not succeeded then
        item:getModData()[C.key]=nil
        for _,material in ipairs(pay) do if not has(inv,material) then inv:AddItem(material) end end
    end
    C.locks[character]=nil
    if not succeeded then return false,"rollback:"..tostring(errorMessage) end
    if C.Runtime then C.Runtime.ScanItem(item) end
    return true
end
function C.Toggle(character,item)
    local ok,why=C.Target(character,item,false); if not ok then return false,why end
    local r=C.Record(item); if not C.Valid(r) then return false,"not_installed" end
    if C.Runtime then C.Runtime.SettleTree(item) end
    r.on=not r.on
    if C.Runtime and C.Runtime.InvalidateState then C.Runtime.InvalidateState() end
    if C.Runtime then C.Runtime.ScanItem(item) end
    return true
end
function C.Remove(character,item)
    if C.locks[character] then return false,"busy" end
    local ok,why=C.Target(character,item,true); if not ok then return false,why end
    local r=C.Record(item); if not C.Valid(r) then return false,"not_installed" end
    local g=C.Global(); if g.refunded[r.token] then return false,"already_refunded" end
    local inv=character:getInventory(); local staged={}; local added={}
    C.locks[character]=true
    local succeeded,errorMessage=pcall(function()
        for _,spec in ipairs(C.cost) do
            for i=1,spec[2]/2 do
                local v=instanceItem(spec[1]); if not v then error("factory") end
                if spec[1]=="Base.Battery" then v:setCurrentUsesFloat(r.batteries[i]) end
                staged[#staged+1]=v
            end
        end
        for _,v in ipairs(staged) do
            inv:AddItem(v); added[#added+1]=v
            if not has(inv,v) then error("refund_add") end
        end
        item:getModData()[C.key]=nil
        g.refunded[r.token]=true
    end)
    if not succeeded then
        for _,v in ipairs(staged) do if has(inv,v) then inv:Remove(v) end end
        item:getModData()[C.key]=r
    end
    C.locks[character]=nil
    if succeeded then
        if C.Runtime and C.Runtime.InvalidateState then C.Runtime.InvalidateState() end
        return true
    end
    return false,"rollback:"..tostring(errorMessage)
end
return C

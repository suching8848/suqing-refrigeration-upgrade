-- Deterministic Kahlua business/lifecycle model, separate from native tests.
require=function()return true end
local callbacks={}
Events=setmetatable({}, {__index=function(t,k)
    callbacks[k]={};local event={Add=function(f) table.insert(callbacks[k],f) end};rawset(t,k,event);return event
end})
function emit(name,...) for _,f in ipairs(callbacks[name] or {}) do f(...) end end
clock=0
function getGameTime() return {getWorldAgeHours=function()return clock end} end
function getTimestampMs() return 1000000+clock*3600000 end
function isClient()return false end
function isServer()return false end
function instanceof(v,kind)
    return type(v)=="table" and (v.kind==kind or (kind=="InventoryItem" and v.kind~=nil))
end
SandboxVars={FoodRotSpeed=3,SuQingRefrigeration={Enabled=true,RotSpeedPercent=20}}
local global={}
ModData={getOrCreate=function(k)global[k]=global[k] or {};return global[k] end}
function list(values)
    local o={values=values or {}}
    function o:size()return #self.values end
    function o:get(i)return self.values[i+1]end
    function o:contains(v)for _,x in ipairs(self.values)do if x==v then return true end end return false end
    function o:clear()self.values={}end
    function o:add(v)self.values[#self.values+1]=v end
    function o:addAll(other)for _,v in ipairs(other.values)do self:add(v)end end
    return o
end
function inventory(owner)
    local o={items=list(),owner=owner}
    function o:getItems()return self.items end
    function o:AddItem(v)
        table.insert(self.items.values,v);v.parent=self
        if self.failAdd then self.failAdd=false;error("injected add after insertion")end
        return v
    end
    function o:Remove(v)
        self.removes=(self.removes or 0)+1
        for i,x in ipairs(self.items.values)do if x==v then table.remove(self.items.values,i);v.parent=nil;break end end
        if self.failRemove==self.removes then error("injected removal after mutation") end
    end
    function o:getContainingItem()return self.owner end
    function o:getOnlyAcceptCategory()return self.category end
    function o:getAcceptItemFunction()return self.filter end
    function o:isItemAllowed(v)return not self.allow or self.allow(v)end
    return o
end
local nextID=0
FoodIndex={}
function rawAge(food)
    local delta=math.max(0,clock-food.last)/24*(food.nativeRate or 1)
    food.age=food.age+delta;food.last=clock
end
FoodIndex.updateAge=rawAge
Food={class="FoodClass"}
__classmetatables={[Food.class]={__index=FoodIndex}}
function item(fullType,kind)
    nextID=nextID+1
    local o={fullType=fullType,kind=kind or "InventoryItem",md={},id=nextID,uses=50,age=1,last=clock,heat=1}
    function o:getFullType()return self.fullType end
    function o:getModData()return self.md end
    function o:getID()return self.id end
    function o:getContainer()return self.parent end
    function o:isFavorite()return self.favorite==true end
    function o:getCurrentUsesFloat()return self.uses end
    function o:setCurrentUsesFloat(n)self.uses=n end
    function o:getAge()return self.age end
    function o:setAge(n)self.age=n end
    function o:setLastAged(n)self.last=n end
    function o:getHeat()return self.heat end
    function o:setHeat(n)self.heat=n end
    function o:setJobDelta(n)self.jobDelta=n end
    function o:setJobType(n)self.jobType=n end
    if kind=="Food"then setmetatable(o,{__index=FoodIndex})end
    return o
end
function bag(fullType)
    local o=item(fullType or "OtherMod.NewBag","InventoryContainer")
    o.inner=inventory(o);o.slot="base:back";o.capacity=49;o.weightReduction=99;o.weight=1
    function o:getInventory()return self.inner end
    function o:canBeEquipped()return self.slot end
    function o:getFluidContainer()return self.fluid end
    return o
end
function instanceItem(id)
    if id=="Base.Apple" or id=="Base.Steak" or id=="Base.Bread" or id=="Base.Potato" then return item(id,"Food") end
    return item(id)
end
function player()
    local p={inv=inventory()}
    function p:getInventory()return self.inv end
    function p:isEquipped(v)return v.worn==true end
    function p:getPrimaryHandItem()return self.primary end
    function p:getSecondaryHandItem()return self.secondary end
    function p:Say(text)self.said=text end
    function p:setIsFarming()end
    return p
end
players={}
function getNumActivePlayers()return #players end
function getSpecificPlayer(i)return players[i+1]end
processItems=list()
function getCell()return {getProcessItems=function()return processItems end}end
ISTransferAction={transferItem=function(self,p,v,src,dst)
    src:Remove(v);dst:AddItem(v);return v
end}
ISBaseTimedAction={}
function ISBaseTimedAction:derive()local c={};setmetatable(c,{__index=self});return c end
function ISBaseTimedAction:new(p)local o={character=p};setmetatable(o,{__index=self});return o end
function ISBaseTimedAction:stop()end
function ISBaseTimedAction:perform()end
ISTimedActionQueue={add=function(a)return a end}
ISToolTipInv={render=function()return "original"end}
ISInventoryPage={}
ISHandcraftAction={performRecipe=function()return "other_recipe"end}
ItemType={CONTAINER="container"}
ArrayList={new=function()return list()end}
local function script(id,container)
    return {getFullName=function()return id end,getObsolete=function()return false end,
        isHidden=function()return false end,isItemType=function(_,kind)return container and kind==ItemType.CONTAINER end}
end
mockRecipes={}
for _,name in ipairs({"InstallCooling","RemoveCooling"})do
    local input={ids=list({"Base.Bag_Schoolbag"}),cache=list()}
    function input:isKeep()return true end
    function input:isItemCount()return true end
    function input:getItems()return self.ids end
    function input:getPossibleInputItems()return self.cache end
    local r={input=input,name="SuQingRefrigeration."..name}
    function r:getInputs()return list({self.input})end
    function r:getScriptObjectFullType()return self.name end
    mockRecipes[r.name]=r
end
function getScriptManager()
    return {getAllItems=function()return list({script("Base.Bag_Schoolbag",true),script("OtherMod.NewBag",true),script("Base.Apple",false)})end,
        getCraftRecipe=function(_,name)return mockRecipes[name]end}
end
ISInventoryPaneContextMenu={addToolTip=function()return {}end}
function getText(key,...)return key end
function getTexture(path)return path end
function getCore()return {getScreenHeight=function()return 1080 end}end

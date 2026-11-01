local C=SuQingRefrigeration;local F=C.Crafting;local R=C.Runtime
local n,cases=0,0
local function check(v,label)n=n+1;assert(v,label)end
local function test(name,f)cases=cases+1;f()end
local function setup(mode)
    clock=0;C.global=nil
    local g=C.Global();g.refunded={};g.history={{time=-1000000,rate=0.2,rot=1}};g.lastSeen=0
    SandboxVars.SuQingRefrigeration={Enabled=true,RotSpeedPercent=20}
    local p=player();players={p};local b=bag();p.inv:AddItem(b)
    if mode=="remove"then
        b.md[C.key]={schema=1,on=false,paid=true,token="rc1-existing",batteries={1,2,3,4,5,6}}
    else
        for _,cost in ipairs(C.cost)do for i=1,cost[2]do local v=item(cost[1]);v.uses=i*2;p.inv:AddItem(v)end end
    end
    local inputs={};for _,v in ipairs(p.inv.items.values)do inputs[#inputs+1]=v end
    local data={}
    function data:getAllKeepInputItems()return list({b})end
    function data:getAllInputItems()return list(inputs)end
    function data:processDestroyAndUsedItems()if self.failProcess then error("native process failure")end end
    local logic={calls=0}
    function logic:getRecipeData()return data end
    function logic:canPerformCurrentRecipe()error("must not retest a reserved keep target")end
    function logic:performCurrentRecipe()
        self.calls=self.calls+1
        if mode=="install"then
            for i,v in ipairs(inputs)do
                if v~=b then p.inv:Remove(v)end
                if self.failAfter==i then return false end
            end
        end
        return true
    end
    local action={character=p,logic=logic,craftRecipe=mockRecipes["SuQingRefrigeration."..(mode=="remove" and "RemoveCooling"or"InstallCooling")]}
    setmetatable(action,{__index=ISHandcraftAction})
    C.Recipes.ready=true;F.ready=true
    return p,b,action,data
end
test("native candidate and resolved-script lists match",function()
    C.Recipes.ready=false;check(C.Recipes.Install(),"recipe discovery")
    for _,r in pairs(mockRecipes)do
        check(r.input.ids:size()==2,"two standard container candidates")
        check(r.input.cache:size()==2,"resolved input cache updated too")
    end
end)
test("native install charges exact sixteen objects once",function()
    local p,b,a=setup("install")
    check(a:performRecipe(),"native crafting completion")
    check(p.inv.items:size()==1,"not thirty-two materials / not six battery uses")
    check(C.Valid(C.Record(b)),"paid refrigeration state")
    check(C.Record(b).batteries[1]==2,"partial charge captured before native destruction")
    check(not a:performRecipe(),"action replay blocked")
    check(a.logic.calls==1,"native execution once")
end)
test("native remove restores legacy rc1 record without migration",function()
    local p,b,a=setup("remove")
    b.md.SuQingContainerUpgrade={level=5};b.md.ExSuQingBackpackSuperUpgrade={targetCapacity=98}
    check(a:performRecipe(),"rc1 removal")
    check(C.Record(b)==nil and p.inv.items:size()==9,"one-half refund once")
    check(b.md.SuQingContainerUpgrade.level==5 and b.md.ExSuQingBackpackSuperUpgrade.targetCapacity==98,"foreign states unchanged")
end)
test("native partial failure restores original objects",function()
    local p,b,a=setup("install");a.logic.failAfter=8
    check(not a:performRecipe(),"partial execution rejected")
    check(p.inv.items:size()==17 and C.Record(b)==nil,"all original material objects restored")
    check(C.locks[p]==nil and F.active==nil,"transaction released")
end)
test("post-native processing failure restores payment",function()
    local p,b,a,data=setup("install");data.failProcess=true
    check(not a:performRecipe(),"native processing rejected")
    check(p.inv.items:size()==17 and C.Record(b)==nil,"payment rollback")
end)
test("recipe state guards and foreign recipe continuation",function()
    local p,b,a=setup("install")
    b.worn=true;check(not C.TestRecipeInstall(b,p),"worn target rejected")
    b.worn=false;check(C.TestRecipeInstall(b,p),"native readiness")
    F.ready=false;check(not C.TestRecipeInstall(b,p),"no guard means no payment")
    F.ready=true
    a.craftRecipe={getScriptObjectFullType=function()return "OtherMod.InstallCooling"end}
    check(a:performRecipe()=="other_recipe","other recipes bypass our transaction")
end)
test("no tooltip renderer hook",function()
    check(ISToolTipInv.render()=="original","CleanUI/vanilla renderer preserved")
end)
test("gradual cooling and cold legacy item retained",function()
    local p,b=setup("remove");b.md[C.key].on=true
    local f=item("Base.Apple","Food");b.inner:AddItem(f);R.ScanItem(f)
    check(f.heat==1,"warm food does not jump to cold")
    clock=5/60;R.Settle(f,clock);check(f.heat>0.2 and f.heat<1,"five minute transition")
    clock=20/60;R.Settle(f,clock);check(math.abs(f.heat-0.2)<0.000001,"twenty minute cold point")
    check(math.abs(f.age-(1+0.2*clock/24))<0.000001,"spoilage remains unchanged")
    f.md[C.foodKey]={schema=1,age=f.age,time=clock};f.heat=0.2
    R.Settle(f,clock);check(f.heat==0.2,"rc1 cold item stays cold")
end)
return "CRAFTING_REVISION cases="..cases.." assertions="..n.." failures=0"

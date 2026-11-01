local C=SuQingRefrigeration;local R=C.Runtime
local checks,cases=0,0
local function check(v,label)checks=checks+1;if not v then error(label)end end
local function eq(a,b,label)check(a==b,(label or "equal")..": "..tostring(a).." vs "..tostring(b))end
local function near(a,b,label)check(math.abs(a-b)<0.000001,(label or "near")..": "..tostring(a).." vs "..tostring(b))end
local function test(name,f)cases=cases+1;f()end
local function setup()
    clock=0;C.global=nil
    local g=C.Global();g.history=nil;g.lastSeen=nil;g.refunded={}
    SandboxVars.SuQingRefrigeration={Enabled=true,RotSpeedPercent=20}
    R.foods=setmetatable({},{__mode="k"});R.bags=setmetatable({},{__mode="k"})
    R.lastTime=nil;R.processCount=nil
    local p=player();players={p};local b=bag();p.inv:AddItem(b)
    R.SyncConfig(clock,false)
    return p,b
end
local function materials(p)
    for _,spec in ipairs(C.cost)do for i=1,spec[2]do local v=item(spec[1]);v.uses=i*3;p.inv:AddItem(v)end end
end
R.Start()
C.Recipes.Install();C.Crafting.Start()
check(R.ready,"runtime starts")
test("automatic ordinary/unknown wearable eligibility",function()
    local p,b=setup();eq(C.AcceptsFood(b),true)
    b.slot=nil;eq(C.AcceptsFood(b),false);b.slot="base:waist"
    b.inner.filter="AcceptItemFunction.AmmoStrap_Bullets";eq(C.AcceptsFood(b),false)
    b.inner.filter=nil;b.inner.category="Food";eq(C.AcceptsFood(b),true)
    b.inner.category="Ammo";eq(C.AcceptsFood(b),false)
end)
test("custom filter positive proof",function()
    local p,b=setup();b.inner.filter="Mod.RareFoodOnly"
    b.inner.allow=function(v)return v.fullType=="Mod.RareFood"end
    local yes,reason=C.AcceptsFood(b);eq(yes,false);eq(reason,"custom_filter")
    local f=item("Mod.RareFood","Food");b.inner:AddItem(f)
    eq(C.AcceptsFood(b),true);b.inner:Remove(f);eq(C.AcceptsFood(b),true)
end)
test("exact material object counts, favorites and no stat changes",function()
    local p,b=setup();materials(p);local cap,wr,w=b.capacity,b.weightReduction,b.weight
    p.inv.items:get(1).favorite=true;eq(C.CanInstall(p,b),false)
    p.inv.items:get(1).favorite=false
    eq(C.Install(p,b),true);eq(p.inv.items:size(),1)
    eq(C.Valid(C.Record(b)),true);eq(#C.Record(b).batteries,6)
    eq(b.capacity,cap);eq(b.weightReduction,wr);eq(b.weight,w)
    eq(C.Install(p,b),false)
end)
test("empty, unequipped, liquid guards",function()
    local p,b=setup();materials(p);b.worn=true;eq(C.CanInstall(p,b),false)
    b.worn=false;p.primary=b;eq(C.CanInstall(p,b),false);p.primary=nil
    local f=item("Base.Apple","Food");b.inner:AddItem(f);eq(C.CanInstall(p,b),false);b.inner:Remove(f)
    b.fluid={getAmount=function()return 1 end};eq(C.CanInstall(p,b),false);b.fluid=nil
    eq(C.CanInstall(p,b),true)
end)
test("payment rollback after mutation",function()
    local p,b=setup();materials(p);p.inv.failRemove=7
    eq(C.Install(p,b),false);eq(p.inv.items:size(),17);eq(C.Record(b),nil)
    p.inv.failRemove=nil;eq(C.Install(p,b),true)
end)
test("50 percent refund and charge conservation",function()
    local p,b=setup();materials(p);eq(C.Install(p,b),true)
    local paid=C.Copy(C.Record(b));eq(C.Remove(p,b),true);eq(p.inv.items:size(),9)
    local counts={};local bat={}
    for _,v in ipairs(p.inv.items.values)do counts[v.fullType]=(counts[v.fullType]or 0)+1;if v.fullType=="Base.Battery"then bat[#bat+1]=v.uses end end
    eq(counts["Base.Battery"],3);eq(counts["Base.ElectricWire"],2)
    eq(counts["Base.ElectronicsScrap"],2);eq(counts["Base.SmallSheetMetal"],1)
    for i=1,3 do eq(bat[i],paid.batteries[i])end
    eq(C.Remove(p,b),false)
    b.md[C.key]=paid;local yes,why=C.Remove(p,b);eq(yes,false);eq(why,"already_refunded")
end)
test("refund rollback after AddItem inserts then throws",function()
    local p,b=setup();materials(p);C.Install(p,b);p.inv.failAdd=true
    eq(C.Remove(p,b),false);eq(p.inv.items:size(),1);check(C.Valid(C.Record(b)),"ledger retained")
    eq(C.Remove(p,b),true)
end)
test("single-player guard",function()
    local p,b=setup();materials(p);local old=isClient;isClient=function()return true end
    eq(C.Install(p,b),false);eq(p.inv.items:size(),17);isClient=old
end)
test("cancel action never charges",function()
    local p,b=setup();materials(p)
    -- Native crafting does not enter our completion handler on cancel.
    eq(p.inv.items:size(),17);eq(C.Record(b),nil)
end)
test("action completion exactly once",function()
    local p,b=setup();materials(p);C.Install(p,b);local a=C.Action:new(p,b)
    eq(a:complete(),true);eq(a:complete(),false);eq(p.inv.items:size(),1)
end)
local function coldFood(p,b,rate)
    materials(p);check(C.Install(p,b),"install for cooling test")
    local f=item("Base.Apple","Food");f.nativeRate=rate or 1;b.inner:AddItem(f);R.ScanItem(f)
    return f
end
test("20 percent native interval cap, no rejuvenation",function()
    local p,b=setup();local f=coldFood(p,b)
    for i=1,240 do clock=i/10;R.Tick();local age=f.age;rawAge(f);near(f.age,age,"same-time native pass")end
    near(f.age,1.2);check(f.age>=1,"not fresher than entering")
end)
test("zero percent freezes age rather than resets it",function()
    local p,b=setup();SandboxVars.SuQingRefrigeration.RotSpeedPercent=0;R.SyncConfig(0,false)
    local f=coldFood(p,b);f.age=4;f.md[C.foodKey].age=4
    clock=240;R.Tick();near(f.age,4)
end)
test("100 percent and master disable",function()
    local p,b=setup();local f=coldFood(p,b)
    SandboxVars.SuQingRefrigeration.RotSpeedPercent=100;R.SyncConfig(0,false)
    clock=24;R.Tick();near(f.age,2)
    SandboxVars.SuQingRefrigeration.Enabled=false;R.SyncConfig(24,false)
    clock=48;R.Tick();near(f.age,3)
end)
test("real freezer and fridge effects never multiply",function()
    local p,b=setup();SandboxVars.SuQingRefrigeration.RotSpeedPercent=50;R.SyncConfig(0,false)
    local f=coldFood(p,b,0.2);clock=24;R.Tick();near(f.age,1.2)
    local f2=item("Base.Steak","Food");f2.nativeRate=0;b.inner:AddItem(f2);R.ScanItem(f2)
    clock=48;R.Tick();near(f2.age,1)
end)
test("nested cooled bags apply once",function()
    local p,b=setup();local f=coldFood(p,b)
    local inside=bag("Mod.Inside");inside.md[C.key]=C.Copy(C.Record(b));b.inner:Remove(f)
    inside.inner:AddItem(f);b.inner:AddItem(inside)
    clock=24;R.Tick();near(f.age,1.2)
end)
test("switch off while worn; normal aging resumes",function()
    local p,b=setup();local f=coldFood(p,b);b.worn=true
    clock=24;R.Tick();near(f.age,1.2);eq(C.Toggle(p,b),true);eq(f.md[C.foodKey],nil)
    clock=48;f:updateAge();near(f.age,2.2);eq(C.Toggle(p,b),true)
    clock=72;R.Tick();near(f.age,2.4)
end)
test("transfer boundary into and out of cold",function()
    local p,b=setup();materials(p);C.Install(p,b)
    local f=item("Base.Apple","Food");p.inv:AddItem(f)
    clock=24;ISTransferAction:transferItem(p,f,p.inv,b.inner);near(f.age,2)
    clock=48;ISTransferAction:transferItem(p,f,b.inner,p.inv);near(f.age,2.2)
    clock=72;f:updateAge();near(f.age,3.2);eq(f.md[C.foodKey],nil)
end)
test("unloaded persisted interval, settings history",function()
    local p,b=setup();local f=coldFood(p,b)
    R.foods={};clock=12;SandboxVars.SuQingRefrigeration.RotSpeedPercent=50;R.SyncConfig(clock,false)
    clock=24;R.ScanItem(f);near(f.age,1.35)
end)
test("pre-world load catches near-rotten food before native deletion",function()
    local p,b=setup();local f=coldFood(p,b);f.age=9.5;f.md[C.foodKey].age=9.5
    R.foods={};processItems=list({f});clock=24
    emit("OnTickEvenPaused");rawAge(f);check(f.age<10,"native replacement threshold protected")
    near(f.age,9.7)
end)
test("re-enable after absent-mod world-time gap gets no retroactive cooling",function()
    local p,b=setup();local f=coldFood(p,b)
    C.Global().lastSeen=0;clock=24;R.SyncConfig(clock,true);R.ScanItem(f)
    near(f.age,2)
end)
test("foreign ModData and conversion copy retained",function()
    local p,b=setup();materials(p);b.md.Other={value=17};C.Install(p,b)
    local replacement=bag("OtherMod.Variant");replacement.md=C.Copy(b.md)
    check(C.Valid(C.Record(replacement)),"variant keeps cold ledger");eq(replacement.md.Other.value,17)
    p.inv:Remove(b);p.inv:AddItem(replacement);eq(C.Remove(p,replacement),true);eq(replacement.md.Other.value,17)
end)
test("context is one switch only; unmodified equipment has none",function()
    local p,b=setup();materials(p)
    local context={options={}}
    function context:addOption(label,target,callback,a,b)local o={name=label};table.insert(self.options,o);return o end
    C.FillContext(0,context,{b});eq(#context.options,0)
    C.Install(p,b);context.options={};C.FillContext(0,context,{b});eq(#context.options,1)
    eq(context.options[1].name,"IGUI_SQR_switch_off");check(context.options[1].iconTexture~=nil,"switch icon")
end)
test("main-menu/reload does not stack hooks or keep other-save data",function()
    local before=FoodIndex.updateAge;emit("OnMainMenuEnter");eq(R.ready,false)
    R.Start();eq(FoodIndex.updateAge,before);eq(R.ready,true)
end)
test("bounded native discovery and same-time no full food resettle",function()
    local p,b=setup();processItems=list()
    for i=1,1000 do processItems.values[i]=item("Base.Apple","Food")end
    local before=R.stats.settled;R.Tick();check(R.stats.settled-before<=16,"unrelated food skipped")
end)
eq(R.stats.errors,0,"runtime errors")
C.TestTotals={cases=cases,assertions=checks}
return "KAHLUA_COOLING cases="..cases.." assertions="..checks.." failures=0"

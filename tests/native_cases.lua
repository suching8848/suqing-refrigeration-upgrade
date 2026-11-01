local C=SuQingRefrigeration
local R=C.Runtime
local index=__classmetatables[Food.class].__index
assert(index and index.updateAge,"actual exposed Food.updateAge")
R.nativeAge=index.updateAge
R.ready=true
local cold=true
R.Cooling=function(food) return cold end
local t=getGameTime():getWorldAgeHours()
R.SyncConfig(t,false)
ProbeFood:setAge(1);ProbeFood:setLastAged(t)
assert(R.Settle(ProbeFood,t))
local initial=ProbeFood:getAge()
local startDay=ProbeTime:getTimeOfDay()
for i=1,240 do
    ProbeTime:setTimeOfDay(startDay+i/10)
    local current=getGameTime():getWorldAgeHours()
    assert(R.Settle(ProbeFood,current))
    local settled=ProbeFood:getAge()
    -- Next native world pass runs at the same world time as the preceding
    -- OnTick. This exact native call must not apply a second spoilage increment.
    R.nativeAge(ProbeFood,false)
    assert(math.abs(ProbeFood:getAge()-settled)<0.00001,"native double aging")
end
assert(math.abs(ProbeFood:getAge()-initial-0.2)<0.0002,"real Food native 24h refrigerated rate")
local age=ProbeFood:getAge()
SandboxVars.SuQingRefrigeration.RotSpeedPercent=0
t=getGameTime():getWorldAgeHours();R.SyncConfig(t,false)
ProbeTime:setTimeOfDay(ProbeTime:getTimeOfDay()+48)
assert(R.Settle(ProbeFood,getGameTime():getWorldAgeHours()))
assert(math.abs(ProbeFood:getAge()-age)<0.00001,"zero percent preserves, never rejuvenates")
SandboxVars.SuQingRefrigeration.Enabled=false
t=getGameTime():getWorldAgeHours();R.SyncConfig(t,false)
ProbeTime:setTimeOfDay(ProbeTime:getTimeOfDay()+24)
assert(R.Settle(ProbeFood,getGameTime():getWorldAgeHours()))
assert(math.abs(ProbeFood:getAge()-age-1)<0.0002,"master off real native normal aging")
cold=false
R.Settle(ProbeFood,getGameTime():getWorldAgeHours())
assert(ProbeFood:getModData()[C.foodKey]==nil,"leaving cooling clears only own food bookkeeping")
cold=true
SandboxVars.SuQingRefrigeration.Enabled=true
SandboxVars.SuQingRefrigeration.RotSpeedPercent=50
t=getGameTime():getWorldAgeHours();R.SyncConfig(t,false)
ProbeFood:setContainer(ProbeFridge);ProbeFood:setHeat(1)
ProbeFood:setAge(1);ProbeFood:setLastAged(t)
R.Settle(ProbeFood,t)
ProbeTime:setTimeOfDay(ProbeTime:getTimeOfDay()+24)
assert(R.Settle(ProbeFood,getGameTime():getWorldAgeHours()))
assert(math.abs(ProbeFood:getAge()-1.2)<0.0002,"actual native fridge 20% with cooling 50% must remain20%, not10%")
ProbeFood:setContainer(nil);ProbeFood:setHeat(1)
ProbeFood:getModData()[C.foodKey]=nil
t=getGameTime():getWorldAgeHours();R.Settle(ProbeFood,t)
assert(ProbeFood:getHeat()==1,"native warm food initially remains warm")
ProbeTime:setTimeOfDay(ProbeTime:getTimeOfDay()+5/60)
assert(R.Settle(ProbeFood,getGameTime():getWorldAgeHours()))
assert(ProbeFood:getHeat()>0.2 and ProbeFood:getHeat()<1,"native heat transitions after five game minutes")
ProbeTime:setTimeOfDay(ProbeTime:getTimeOfDay()+15/60)
assert(R.Settle(ProbeFood,getGameTime():getWorldAgeHours()))
-- Native timeOfDay is float32: the 20-minute endpoint can differ by one ULP.
assert(math.abs(ProbeFood:getHeat()-0.2)<0.0001,"native heat cold after twenty game minutes: "..tostring(ProbeFood:getHeat()))
assert(R.stats.errors==0)
print("NATIVE_COOLING actual Food.updateAge: 240 world passes, 24h at20%, 48h at0%, 24h master off: PASS")
return "NATIVE_COOLING: 240 native world passes; 20%, 0%, master off, actual fridge not multiplied: PASS; gradual native heat: PASS"

local C=SuQingRefrigeration
local R=C.Runtime
local B=C.NativeBackend
local api=SuQingNativeColdApi
local assertions=0
local function check(v,label) assertions=assertions+1;assert(v,label or "actual native Lua API") end
local function near(a,b,label) check(math.abs(a-b)<.00002,(label or "near").." / "..tostring(a).." vs "..tostring(b)) end
local names={"apiVersion","bootstrap","isReady","isActive","activate","setCoolingEnabled","invalidate","settle","flushKnown","fridgeFactor","foodRotSpeed","status","shutdown"}
check(type(api)=="table","actual Exposer creates API table")
for _,name in ipairs(names) do
    local f=api[name];check(type(f)=="function","actual callable type: "..name)
    for n=1,20 do check(api[name]==f,"stable native method identity: "..name) end
end
check(api.apiVersion()==1);check(not api.isReady());check(not api.isActive())
local original=R.FlushAll;local flushes=0
R.FlushAll=function(...)
    flushes=flushes+1
    check(not B.IsActive() and not api.isActive(),"legacy flush still owns handover")
    return original(...)
end
R.Start();R.FlushAll=original
check(flushes==1);check(R.ready);check(B.IsActive());check(api.isReady());check(api.isActive())
check(B.Check(R),"real API/captured identities stay healthy")
near(R.configRate,api.fridgeFactor());near(R.configRot,api.foodRotSpeed())
check(R.configRate~=.025,"custom RotSpeedPercent ignored by native mode")
ProbeAdvance(24)
check(R.Settle(ProbeFood,getGameTime():getWorldAgeHours())==true,"real void settle succeeds through Lua pcall")
near(ProbeFood:getAge(),1.2,"actual retransformed Food gets vanilla portable cold aging")
local checkpoint=ProbeFood:getModData()[C.foodKey]
check(type(checkpoint)=="table" and checkpoint.schema==1,"actual native settle writes compatible schema checkpoint")
near(checkpoint.age,ProbeFood:getAge());near(checkpoint.time,ProbeFood:getLastAged())
for n=1,20 do R.Tick();NativeApiEmit("OnTickEvenPaused");check(B.IsActive()) end
SandboxVars.SuQingRefrigeration.RotSpeedPercent=100;R.Tick();near(R.configRate,api.fridgeFactor())
SandboxVars.SuQingRefrigeration.Enabled=false;NativeApiEmit("OnTickEvenPaused")
local h=C.Global().history;near(h[#h].rate,1,"master-off history becomes ordinary rate")
SandboxVars.SuQingRefrigeration.Enabled=true;R.Tick();near(h[#h].rate,api.fridgeFactor())
check(R.FlushAll()==true,"real void flushKnown is success")
NativeApiEmit("OnMainMenuEnter")
check(not R.ready and not B.IsActive() and not api.isActive(),"actual native shutdown via Lua menu callback")
local summary="NATIVE_LUA_API assertions="..assertions.." PASS"
print(summary)
return summary

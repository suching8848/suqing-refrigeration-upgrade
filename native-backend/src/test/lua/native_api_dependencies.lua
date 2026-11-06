-- Only dependencies are controlled. Food/API/Exposer/time remain native.
require=function() return true end
local callbacks={}
Events=setmetatable({}, {__index=function(t,k)
    callbacks[k]={};local e={Add=function(f) callbacks[k][#callbacks[k]+1]=f end};rawset(t,k,e);return e
end})
function NativeApiEmit(name,...) for _,f in ipairs(callbacks[name] or {}) do f(...) end end
function getNumActivePlayers() return 0 end
function getSpecificPlayer() error("test has no player",0) end
function getCell() error("unexpected World/Cell access in native handover",0) end
function isClient() return false end
function isServer() return false end
function getTimestampMs() return 123456789 end
function getGameTime() return ProbeTime end
SandboxVars={FoodRotSpeed=3,SuQingRefrigeration={Enabled=true,RotSpeedPercent=2.5}}
local global={}
ModData={getOrCreate=function() return global end}
ISTransferAction={transferItem=function() error("test has no transfer action",0) end}

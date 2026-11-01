require=function() return true end
Events=setmetatable({}, {__index=function(t,k) local e={Add=function()end};rawset(t,k,e);return e end})
ISTransferAction={transferItem=function(self,character,item) return item end}
local data={}
ModData={getOrCreate=function(key) data[key]=data[key] or {}; return data[key] end}
SandboxVars={FoodRotSpeed=3,SuQingRefrigeration={Enabled=true,RotSpeedPercent=20}}
function getNumActivePlayers() return 0 end
function getCell() return nil end

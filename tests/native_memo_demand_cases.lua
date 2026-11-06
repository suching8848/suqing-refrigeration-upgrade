local DEMAND_CANDIDATE=true
-- Actual Java Food and GameTime methods; no cell/client/world is created.
local C,R=SuQingRefrigeration,SuQingRefrigeration.Runtime
local native=__classmetatables[Food.class].__index.updateAge
local calls,wall=0,100000
function getTimestampMs()return wall end
R.Start();R.nativeAge=function(food,...)calls=calls+1;return native(food,...)end
R.Cooling=function()return true end
local function now()return getGameTime():getWorldAgeHours()end
local rows={}
local function show()R.displayDepth=1;ProbeFood:updateAge(false);R.displayDepth=0 end
local function scenario(name,hours)
 ProbeFood:setContainer(nil);ProbeFood:setHeat(1);ProbeFood:setAge(1);ProbeFood:setLastAged(now());ProbeFood:getModData()[C.foodKey]=nil
 R.lastSettled[ProbeFood]=nil;if R.displaySeen then R.displaySeen[ProbeFood]=nil end
 R.SyncConfig(now(),false);assert(R.Settle(ProbeFood,now()));ProbeTime:setTimeOfDay(ProbeTime:getTimeOfDay()+hours);assert(R.Settle(ProbeFood,now()))
 local age,heat,last,frozen=ProbeFood:getAge(),ProbeFood:getHeat(),ProbeFood:getLastAged(),ProbeFood:getFreezingTime()
 local before=calls;show();local first=calls-before
 assert(first==(DEMAND_CANDIDATE and 1 or 0),'only unsubscribed first display becomes strict')
 assert(ProbeFood:getAge()==age and ProbeFood:getHeat()==heat and ProbeFood:getLastAged()==last,'strict first display must preserve physical Age/Heat/LastAged')
 assert(ProbeFood:getFreezingTime()==frozen,'same-clock first display preserves actual native freezing state')
 before=calls;show();assert(calls==before,'second actual ageWrapper call hits complete memo')
 local rec=ProbeFood:getModData()[C.foodKey];rec.heat=rec.heat+1e-12;before=calls;show();assert(calls==before+1,'tiny logical heat edit stays strict')
 local physical=ProbeFood:getHeat();ProbeFood:setHeat(physical+.0001);before=calls;show();assert(calls==before+1,'physical float edit stays strict')
 wall=wall+501;assert(R.Settle(ProbeFood,now()));if DEMAND_CANDIDATE then assert(R.lastSettled[ProbeFood].ms==nil)end
 before=calls;show();local reopen=calls-before;assert(reopen==(DEMAND_CANDIDATE and 1 or 0));before=calls;show();assert(calls==before)
 rows[#rows+1]='NATIVE_DEMAND scenario='..name..' first_native='..first..' reopen_native='..reopen..' same_physical=true same_freezing=true'
end
scenario('floor',1);scenario('gradient',5/60)
return table.concat(rows,'\n')..'\nNATIVE_DEMAND scenarios=2 PASS'

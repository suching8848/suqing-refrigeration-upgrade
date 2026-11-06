local DEMAND_CANDIDATE=true
-- Actual PZO Kahlua with trusted plain mocks; no game/world/save.
local C,R=SuQingRefrigeration,SuQingRefrigeration.Runtime
local cases,assertions=0,0
local wall=100000
function getTimestampMs()return wall end
local counts={native=0,age=0,heat=0,last=0,ledger=0}
local function check(v,label)assertions=assertions+1;assert(v,label or 'memo demand')end
local function eq(a,b,label)check(a==b,(label or 'equal')..': '..tostring(a)..' / '..tostring(b))end
local function test(name,fn)cases=cases+1;fn()end
local function empty(t)for _ in pairs(t)do return false end;return true end
local native=FoodIndex.updateAge
FoodIndex.updateAge=function(food,...)counts.native=counts.native+1;if food.failNative then error('deliberate failure')end;return native(food,...)end
R.Start()
local function setup(number,bags)
 clock=1000;wall=100000;function getTimestampMs()return wall end
 players={};processItems=list();R.lastTime=nil;R.processCount=0;R.ticks=0
 R.foods=setmetatable({}, {__mode='k'});R.bags=setmetatable({}, {__mode='k'});R.busy=setmetatable({}, {__mode='k'})
 R.lastSettled=setmetatable({}, {__mode='k'});if R.displaySeen then R.displaySeen=setmetatable({}, {__mode='k'})end
 R.stateCache:Reset();R.batch=nil;R.queue={};R.queueHead=1;R.queued=setmetatable({}, {__mode='k'});R.discoveryMs=wall;R.processBudget=nil
 SandboxVars.FoodRotSpeed=5;SandboxVars.SuQingRefrigeration={Enabled=true,RotSpeedPercent=2.5}
 C.global=nil;local g=C.Global();g.lastSeen=clock
 g.history={{time=-1000000000,rate=.2,rot=1},{time=24,rate=0,rot=1},{time=48,rate=1,rot=1.4},{time=120,rate=.2,rot=.7},{time=240,rate=.1,rot=.4},{time=360,rate=.025,rot=.4},{time=480,rate=.05,rot=.4},{time=744,rate=.025,rot=.4}}
 local owners,foods={},{}
 for n=1,bags do local b=bag('Fixture.Cold'..n);b.inner.kind='ItemContainer';b.md[C.key]={schema=1,on=true,paid=true,token='paid-'..n,batteries={1,2,3,4,5,6}};owners[n]=b;R.bags[b]=true end
 for n=1,number do
  local f=item('Base.Apple','Food');setmetatable(f,nil)
  function f:updateAge(...)return FoodIndex.updateAge(self,...)end
  function f:getAge()counts.age=counts.age+1;return self.age end
  function f:getHeat()counts.heat=counts.heat+1;return self.heat end
  function f:getLastAged()counts.last=counts.last+1;return self.last end
  f.nativeRate=n%3==0 and 0 or (n%3==1 and 1 or .2)
  owners[(n-1)%bags+1].inner:AddItem(f);f.md[C.foodKey]={schema=1,time=clock,age=f.age,heat=f.heat};foods[n]=f;R.foods[f]=true
 end
 R.SyncConfig(clock,false);counts={native=0,age=0,heat=0,last=0}
 if DEMAND_CANDIDATE then R.stats.memoCaptures=0;R.stats.memoSkips=0 end
 return foods,owners
end
local function step(ms)clock=clock+1/6000;wall=wall+(ms or 16);R.Tick()end
local function display(f)R.displayDepth=1;local ok=R.SettleDisplay(f,clock);R.displayDepth=0;return ok end

local f,b=setup(571,6)
for n=1,8 do step()end
local metric='MEMO_LOAD native='..counts.native..' getAge='..counts.age..' getHeat='..counts.heat..' getLastAged='..counts.last
eq(counts.native,4568,'full background native protection unchanged')
eq(counts.age,DEMAND_CANDIDATE and 13704 or 18272)
eq(counts.heat,DEMAND_CANDIDATE and 4568 or 9136)
eq(counts.last,DEMAND_CANDIDATE and 0 or 4568)
if DEMAND_CANDIDATE then eq(R.stats.memoCaptures,0);eq(R.stats.memoSkips,4568)end
local vector={};for _,v in ipairs(f)do vector[#vector+1]=tostring(v.age)..':'..tostring(v.heat)..':'..tostring(v.last)end
local before=counts.native;R.QueueContainer(b[1].inner);R.Discover(clock);eq(counts.native,before,'minimal ownership memo avoids rediscovery settle')
if DEMAND_CANDIDATE then eq(R.lastSettled[f[1]].ms,nil);eq(R.lastSettled[f[1]].containerRef[1],b[1].inner)end

test('first render strict, second render hit, and later ticks keep active signatures',function()
 local f=setup(1,1);step();local before=counts.native
 check(display(f[1]));eq(counts.native,before+(DEMAND_CANDIDATE and 1 or 0))
 before=counts.native;check(display(f[1]));eq(counts.native,before)
 if DEMAND_CANDIDATE then eq(R.stats.memoCaptures,1);eq(R.stats.memoSkips,1)end
 check(R.lastSettled[f[1]].ms~=nil);step();before=counts.native;check(display(f[1]));eq(counts.native,before)
 eq(getmetatable(R.lastSettled[f[1]].containerRef).__mode,'v')
end)
test('closed UI expires all full signatures at exactly 500ms',function()
 local f=setup(1,1);step();display(f[1]);local before={age=counts.age,heat=counts.heat,last=counts.last,native=counts.native};step(500)
 eq(counts.native,before.native+1)
 eq(counts.age-before.age,DEMAND_CANDIDATE and 3 or 4)
 eq(counts.heat-before.heat,DEMAND_CANDIDATE and 1 or 2)
 eq(counts.last-before.last,DEMAND_CANDIDATE and 0 or 1)
 if DEMAND_CANDIDATE then local m=R.lastSettled[f[1]];eq(m.ms,nil);eq(m.record,nil);eq(m.age,nil);eq(m.containerRef[1],f[1].parent);eq((R.lastSettled[f[1]] and R.lastSettled[f[1]].displaySeen),nil)end
 before=counts.native;display(f[1]);eq(counts.native,before+(DEMAND_CANDIDATE and 1 or 0));before=counts.native;display(f[1]);eq(counts.native,before)
end)
test('actual display refresh extends interest and close to reopen is strict once',function()
 local f=setup(1,1);step();display(f[1]);step(400);display(f[1]);step(400)
 local before=counts.native;display(f[1]);eq(counts.native,before)
 step(501);before=counts.native;display(f[1]);eq(counts.native,before+(DEMAND_CANDIDATE and 1 or 0));before=counts.native;display(f[1]);eq(counts.native,before)
end)
test('wall rewind invalidates stale subscription without affecting discovery',function()
 local f,b=setup(1,1);step();display(f[1]);wall=wall-50;step(0)
 if DEMAND_CANDIDATE then eq(R.lastSettled[f[1]].ms,nil);eq((R.lastSettled[f[1]] and R.lastSettled[f[1]].displaySeen),nil)end
 local before=counts.native;R.QueueContainer(b[1].inner);R.Discover(clock);eq(counts.native,before)
 display(f[1]);before=counts.native;display(f[1]);eq(counts.native,before)
end)
test('missing wall clock always remains strict',function()
 local f=setup(1,1);step();display(f[1]);getTimestampMs=function()return nil end;step()
 local before=counts.native;display(f[1]);display(f[1]);eq(counts.native,before+2)
end)
test('external age physical heat and lastAged edits stay strict',function()
 local f=setup(1,1);step();display(f[1]);local before=counts.native
 f[1].age=f[1].age+.001;display(f[1]);eq(counts.native,before+1)
 f[1].heat=f[1].heat+.001;display(f[1]);eq(counts.native,before+2)
 f[1].last=f[1].last-.001;display(f[1]);eq(counts.native,before+3)
end)
test('tiny ledger edit and equal valued record replacement stay strict',function()
 local f=setup(1,1);step();display(f[1]);local before=counts.native
 local rec=f[1].md[C.foodKey];rec.heat=rec.heat+1e-12;display(f[1]);eq(counts.native,before+1)
 rec=f[1].md[C.foodKey];f[1].md[C.foodKey]={schema=1,time=rec.time,age=rec.age,heat=rec.heat};display(f[1]);eq(counts.native,before+2)
end)
test('strict settlement still replaces ledger and drops unknown fields',function()
 local f=setup(1,1);local old=f[1].md[C.foodKey];old.extra='foreign';step();check(old~=f[1].md[C.foodKey]);eq(old.extra,'foreign');eq(f[1].md[C.foodKey].extra,nil)
 old=f[1].md[C.foodKey];step();check(old~=f[1].md[C.foodKey])
end)
test('move to warm container clears entitlement immediately under strict scan',function()
 local f,b=setup(1,1);step();display(f[1]);local warm=inventory();warm.kind='ItemContainer';b[1].inner:Remove(f[1]);warm:AddItem(f[1]);R.ScanItem(f[1])
 eq(R.foods[f[1]],nil);eq(f[1].md[C.foodKey],nil);eq(R.lastSettled[f[1]].containerRef[1],warm)
 local before=R.stats.displayHits;display(f[1]);eq(R.stats.displayHits,before)
end)
test('failed settlement drops complete memo and interest',function()
 local f=setup(1,1);step();display(f[1]);f[1].failNative=true;eq(R.Settle(f[1],clock),false);eq(R.lastSettled[f[1]],nil)
 if DEMAND_CANDIDATE then eq((R.lastSettled[f[1]] and R.lastSettled[f[1]].displaySeen),nil)end
end)
test('world rewind preserves strict food anchors',function()
 local f=setup(1,1);step();display(f[1]);local age=f[1].age;clock=999.9;R.Tick();check(f[1].age>=age);eq(f[1].md[C.foodKey].time,clock)
end)
test('new food without any memo starts strict and then reuses complete signature',function()
 local f=setup(1,1);eq(R.lastSettled[f[1]],nil);local before=counts.native
 check(display(f[1]));eq(counts.native,before+1);check(R.lastSettled[f[1]].ms~=nil)
 before=counts.native;display(f[1]);eq(counts.native,before)
end)
test('first display preserves complete multiple returns including nil',function()
 local f=setup(1,1);local prior=R.Settle
 R.Settle=function()return true,nil,'tail',nil end
 local function pack(...)return {n=select('#',...),...}end
 local result=pack(R.SettleDisplay(f[1],clock));R.Settle=prior
 eq(result.n,4);eq(result[1],true);eq(result[2],nil);eq(result[3],'tail');eq(result[4],nil)
end)
test('failed first display clears only its own placeholder and retains original error object',function()
 local f=setup(1,1);local prior=R.Settle;local token={failure=true}
 R.Settle=function()error(token)end
 local ok,err=pcall(R.SettleDisplay,f[1],clock);R.Settle=prior
 eq(ok,false);eq(err,token);eq(R.lastSettled[f[1]],nil)
 local replacement={foreign=true};R.Settle=function()R.lastSettled[f[1]]=replacement;error(token)end
 ok,err=pcall(R.SettleDisplay,f[1],clock);R.Settle=prior
 eq(ok,false);eq(err,token);eq(R.lastSettled[f[1]],replacement)
end)
test('false first display removes own placeholder without dropping a replacement',function()
 local f=setup(1,1);local prior=R.Settle
 R.Settle=function()return false end;eq(R.SettleDisplay(f[1],clock),false);eq(R.lastSettled[f[1]],nil)
 local replacement={foreign=true};R.Settle=function()R.lastSettled[f[1]]=replacement;return false end
 eq(R.SettleDisplay(f[1],clock),false);eq(R.lastSettled[f[1]],replacement);R.Settle=prior
end)
test('save and main menu preserve lifecycle cleanup',function()
 local f=setup(1,1);step();display(f[1]);check(R.FlushAll());eq(f[1].md[C.foodKey].time,clock);emit('OnMainMenuEnter');eq(R.ready,false);check(empty(R.lastSettled))
 if DEMAND_CANDIDATE then eq(getmetatable(R.lastSettled).__mode,'k');check(empty(R.lastSettled))end
end)
return metric..' foods=571 containers=6 history=8 ticks=8\nMEMO_VECTOR '..table.concat(vector,',')..'\nMEMO_REVIEW cases='..cases..' assertions='..assertions..' PASS'

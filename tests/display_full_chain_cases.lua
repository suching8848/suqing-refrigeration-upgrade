local D=SuQingRefrigeration.Display;local R=SuQingRefrigeration.Runtime
local check,eq=Chain.check,Chain.eq
local function pack(...)return{n=select('#',...),...}end
check(type(getFilenameOfClosure)=='function'and type(getFirstLineOfClosure)=='function','native closure APIs required')
eq(getCore():getVersionNumber(),'42.21','native Core number');eq(getCore():getGameAndBuildVersion(),'42.21.0','native Core build')
eq(getActivatedMods():size(),231,'saved active IDs copied in memory')
for i=1,3 do Events.OnTickEvenPaused.fire()end
check(not D.attempted and not D.enabled,'no attempt before GameStart readiness')
Events.OnGameStart.fire()
check(SuQingUIInteractionFixes.proximitySelection.installed==true,'full UIInteraction registrar executed')
check(SuQingSearch.rendererInstalled~=true,'full Search registrar genuinely waits first OnTick')
local proxSource=getFilenameOfClosure(ISInventoryPane.renderdetails)
check(proxSource:lower():find('/suqing_proximityselectionfix.lua',1,true)~=nil,'actual UIInteraction closure source')
local proxLine=getFirstLineOfClosure(ISInventoryPane.renderdetails);check(type(proxLine)=='number'and proxLine>0,'actual UIInteraction first line')
for i=1,10 do Events.OnTickEvenPaused.fire()end
check(not D.attempted and not D.enabled,'paused start never installs before first normal ticks')
local expectedSource,expectedLine,prior
local installedAt
for frame=1,6 do
 if CHAIN_OPTIONS.evenFirst then Events.OnTickEvenPaused.fire();Events.OnTick.fire()
 else Events.OnTick.fire();Events.OnTickEvenPaused.fire()end
 if frame==1 then
  check(SuQingSearch.rendererInstalled==true,'actual first-tick Search deferred registrar ran')
  expectedSource=getFilenameOfClosure(ISInventoryPane.renderdetails);expectedLine=getFirstLineOfClosure(ISInventoryPane.renderdetails);prior=ISInventoryPane.renderdetails
  check(expectedSource:lower():find('/suqingsearch/runtime.lua',1,true)~=nil,'actual final outer Search closure source')
  check(type(expectedLine)=='number'and expectedLine>0,'actual Search closure first line')
  check(not D.enabled and not D.attempted,'never install on first normal tick')
 end
 if D.enabled and not installedAt then installedAt=frame end
end
check(D.enabled and D.attempted,'delayed native-gated chain eventually installs')
check(installedAt>=3,'at least two normal ticks and stable observations elapsed')
eq(D.prior,prior,'captures actual completed Search wrapper')
eq(D.rendererSource,expectedSource,'observed source is actual native closure file')
eq(tonumber(D.rendererLine),expectedLine,'observed native first line retained')
eq(D.orderingHelper,SuQingSearch.Ordering.render,'captures actual complete Ordering helper')
check(D.source:find('SuQingSearchEnhancement-0.1.1',1,true)~=nil,'native selected Search version accepted')
local before=pack(prior(Chain.pane,false));local after=pack(ISInventoryPane.renderdetails(Chain.pane,false))
eq(before.n,after.n,'preserves real predecessor return arity');for i=1,before.n do eq(before[i],after[i],'predecessor result')end
check(Chain.depths[#Chain.depths]>0,'actual local renderer chain enters Display context')
eq(R.displayDepth,0,'render restores context')
Chain.pane.fail=true
local ok,message=pcall(ISInventoryPane.renderdetails,Chain.pane,false)
check(not ok and tostring(message):find('full-chain renderer error',1,true)~=nil,'real wrapper stack propagates base failure')
eq(R.displayDepth,0,'failure restores context');Chain.pane.fail=false
if CHAIN_OPTIONS.lateHelper then
 SuQingSearch.Ordering.render=function()return'unknown-helper'end
 Events.OnTickEvenPaused.fire()
 check(not D.enabled,'late unknown helper disables coalescing')
 eq(R.displayDepth,0,'unknown helper leaves no Display context')
else
 local wrapped=ISInventoryPane.renderdetails
 local unknown=function(...)return wrapped(...)end
 ISInventoryPane.renderdetails=unknown
 Events.OnTickEvenPaused.fire()
 check(not D.enabled,'late unknown renderer disables coalescing')
 eq(ISInventoryPane.renderdetails,unknown,'does not overwrite late unknown renderer')
 local result=ISInventoryPane.renderdetails(Chain.pane,false)
 eq(result,'base-result','captured previous chain still delegates after disable')
 eq(Chain.depths[#Chain.depths],0,'disabled captured wrapper uses strict zero-depth path')
end
local summary='FULL_CHAIN_CASE '..CHAIN_OPTIONS.label..' checks='..Chain.checks..' PASS; source='..expectedSource..'; firstline='..expectedLine..'; proxline='..proxLine..'; installedFrame='..installedAt
print(summary)
return summary

-- Native Core, ModInfo, active IDs and closure source APIs are never replaced.
-- The base renderer, options, player count and event timing are isolated models.
local C=SuQingRefrigeration
C.Display=nil;C.Runtime={ready=false,displayDepth=0}
SuQingUIInteractionFixes=nil;SuQingSearch=nil
Chain={checks=0,renderCalls=0,depths={},wall=100000}
function Chain.check(value,why)Chain.checks=Chain.checks+1;if not value then error(why or "chain assertion",0)end end
function Chain.eq(a,b,why)Chain.check(a==b,(why or "equal")..": "..tostring(a).." / "..tostring(b))end
local function event()
 local e={callbacks={}}
 function e.Add(fn)e.callbacks[#e.callbacks+1]=fn end
 function e.Remove(fn)for i=#e.callbacks,1,-1 do if e.callbacks[i]==fn then table.remove(e.callbacks,i)end end end
 function e.fire(...)
  local current={};for i,fn in ipairs(e.callbacks)do current[i]=fn end
  for _,fn in ipairs(current)do local live=false;for _,listed in ipairs(e.callbacks)do if listed==fn then live=true;break end end;if live then fn(...)end end
 end
 return e
end
Events={OnGameStart=event(),OnTick=event(),OnTickEvenPaused=event(),OnMainMenuEnter=event(),OnRefreshInventoryWindowContainers=event(),OnContainerUpdate=event()}
Events.OnGameStart.Add(function()C.Runtime.ready=true end)
function getNumActivePlayers()return 0 end
function getPlayerInventory()error("Unexpected real/uncaptured inventory UI dependency")end
function getPlayerLoot()error("Unexpected real/uncaptured loot UI dependency")end
function getTimestampMs()return Chain.wall end
function isMouseButtonDown()return false end
ISInventoryPane={}
function ISInventoryPane.renderdetails(self,...)
 Chain.renderCalls=Chain.renderCalls+1;Chain.depths[#Chain.depths+1]=C.Runtime.displayDepth
 if self.fail then error("full-chain renderer error",0)end
 return "base-result",nil,"tail",nil
end
function ISInventoryPane.refreshContainer()end
function ISInventoryPane.update()end
local options={values={integrate=true,clickPopup=false,showCounts=false,showHelp=false,pinyin=false,sortMatches=false,showContextMenu=false}}
function options:addTickBox(key,title,value)self.values[key]=value end
function options:addKeyBind(key,title,value)self.values[key]=value end
function options:getOption(key)local value=self.values[key];return{getValue=function()return value end}end
PZAPI={ModOptions={}}
function PZAPI.ModOptions:getOptions()return options end
function PZAPI.ModOptions:create()return options end
local allowed={['SuQingRefrigeration_Runtime']=true,['ISUI/ISInventoryPane']=true,['PZAPI/ModOptions']=true,
 ['SuQingSearch/Core']=true,['SuQingSearch/Text']=true,['SuQingSearch/Settings']=true,['SuQingSearch/Ordering']=true}
function require(name)
 if name=='pinyin'then return nil end
 if not allowed[name]then error("Uncontrolled dependency: "..tostring(name),0)end
 return true
end
Chain.pane={player=0,parent={onCharacter=true},selected={},items={},inventory={getType=function()return'container'end}}

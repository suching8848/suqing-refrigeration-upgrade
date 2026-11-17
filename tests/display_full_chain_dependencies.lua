-- Native Core, ModInfo, active IDs and closure source APIs are never replaced.
-- The base renderer, options, player count and event timing are isolated models.
local C=SuQingRefrigeration
C.Display=nil;C.Runtime={ready=false,displayDepth=0}
SuQingUIInteractionFixes=nil;SuQingSearch=nil;CodexInventoryTransferPerformance=nil
CleanUI_HasBeenReadDrawVisibleMarks=nil
Chain={checks=0,renderCalls=0,overlayCalls=0,depths={},wall=100000}
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
Events={OnGameStart=event(),OnTick=event(),OnTickEvenPaused=event(),OnMainMenuEnter=event(),OnRefreshInventoryWindowContainers=event(),OnContainerUpdate=event(),OnPlayerUpdate=event()}
Events.OnGameStart.Add(function()C.Runtime.ready=true end)
function getNumActivePlayers()return 0 end
function getPlayerInventory()error("Unexpected real/uncaptured inventory UI dependency")end
function getPlayerLoot()error("Unexpected real/uncaptured loot UI dependency")end
function getSpecificPlayer()Chain.overlayCalls=Chain.overlayCalls+1;return nil end
function getTexture()return {}end
function getTimestampMs()return Chain.wall end
function isMouseButtonDown()return false end
UIFont={Small="Small",Medium="Medium",Large="Large"}
function getTextManager()
 return {getFontHeight=function()return 14 end,
     getFontFromEnum=function()return {getLineHeight=function()return 14 end}end}
end
ISPanel={}
function ISPanel:derive(name)
 local class={Type=name};class.__index=class;setmetatable(class,{__index=self});return class
end
CleanUI_Vanilla_ISInventoryPane={renderdetails=function()end}
ISInventoryPage={refreshBackpacks=function()end,dirtyUI=function()end,cleanUIApplyScaleSettings=function()end}
ISTimedActionQueue={queues={}}
local options={values={integrate=true,clickPopup=false,showCounts=false,showHelp=false,pinyin=false,sortMatches=false,showContextMenu=false}}
function options:addTickBox(key,title,value)self.values[key]=value end
function options:addKeyBind(key,title,value)self.values[key]=value end
function options:getOption(key)local value=self.values[key];return{getValue=function()return value end}end
PZAPI={ModOptions={}}
function PZAPI.ModOptions:getOptions()return options end
function PZAPI.ModOptions:create()return options end
local allowed={['SuQingRefrigeration_Runtime']=true,['ISUI/ISInventoryPane']=true,['PZAPI/ModOptions']=true,
 ['ISUI/ISInventoryPage']=true,['ISUI/ISPanel']=true,['ISUI/ISButton']=true,['ISUI/ISMouseDrag']=true,['ISUI/ISInventoryItem']=true,
 ['TimedActions/ISTimedActionQueue']=true,['TimedActions/ISEatFoodAction']=true,
 ['BodyDragging/corpseStorageCheck']=true,['TimedActions/ISInventoryTransferUtil']=true,
 ['SuQingSearch/Core']=true,['SuQingSearch/Text']=true,['SuQingSearch/Settings']=true,['SuQingSearch/Ordering']=true}
function require(name)
 if name=='pinyin'then return nil end
 if not allowed[name]then error("Uncontrolled dependency: "..tostring(name),0)end
 return true
end
function Chain.prepareNativePane()
 CleanUI_Clean_ISInventoryPane=ISInventoryPane
 Chain.base=ISInventoryPane.renderdetails
 Chain.pane={player=0,parent={onCharacter=true},selected={},items={},itemslist={},collapsed={},
   width=300,height=180,itemHgt=18,headerHgt=0,column2=120,column3=210,
   inventory={getType=function()return'container'end,isDrawDirty=function()return false end}}
 setmetatable(Chain.pane,{__index=ISInventoryPane})
 function Chain.pane:updateScrollbars()
  Chain.renderCalls=Chain.renderCalls+1
  Chain.depths[#Chain.depths+1]=C.Runtime.displayDepth
  if self.fail then error("full-chain renderer error",0)end
 end
 function Chain.pane:isVScrollBarVisible()return false end
 function Chain.pane:getYScroll()return 0 end
 function Chain.pane:getWidth()return self.width end
 function Chain.pane:getHeight()return self.height end
 function Chain.pane:setScrollHeight()end
 function Chain.pane:setScrollWidth()end
 function Chain.pane:drawRectStatic()end
 function CleanUI_shouldShowWeightColumn()return false end
 function CleanUI_shouldShowColumnHeaders()return false end
end

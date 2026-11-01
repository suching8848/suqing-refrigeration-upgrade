-- Context menu: one switch on installed equipment only. No custom tooltip.
require "SuQingRefrigeration/Core"
require "SuQingRefrigeration_Runtime"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
local C=SuQingRefrigeration
if C.uiLoaded then return end
C.uiLoaded=true
local A=ISBaseTimedAction:derive("SuQingRefrigerationToggle")
function A:isValid()
    return not self.done and C.Target(self.character,self.item,false) and C.Valid(C.Record(self.item))
end
function A:start() self:setActionAnim("Craft") end
function A:perform() ISBaseTimedAction.perform(self) end
function A:complete()
    if self.done then return false end
    self.done=true
    return C.Toggle(self.character,self.item)
end
function A:new(character,item)
    local o=ISBaseTimedAction.new(self,character);o.item=item;o.maxTime=10;return o
end
local function queue(character,item) ISTimedActionQueue.add(A:new(character,item)) end
local function fill(player,context,selection)
    if not C.SP() then return end
    local character=getSpecificPlayer(player);if not character then return end
    local unique,target={}
    for _,entry in ipairs(selection) do
        local item=instanceof(entry,"InventoryItem") and entry or entry.items and entry.items[1]
        if item and not unique[item] then
            unique[item]=true;if target then return end;target=item
        end
    end
    if not target or not C.Valid(C.Record(target)) then return end
    local allowed=C.Target(character,target,false)
    local option=context:addOption(getText(C.Record(target).on and "IGUI_SQR_switch_off" or "IGUI_SQR_switch_on"),character,queue,target)
    option.notAvailable=not allowed
    option.iconTexture=getTexture("media/textures/Item_SQR_Switch.png")
end
Events.OnFillInventoryObjectContextMenu.Add(fill)
C.Action=A
C.FillContext=fill

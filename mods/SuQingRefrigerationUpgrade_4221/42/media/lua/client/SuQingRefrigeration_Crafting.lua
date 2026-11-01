if isServer() then return end
require "SuQingRefrigeration/Core"
require "SuQingRefrigeration_Runtime"
require "SuQingRefrigeration/Recipes"
require "Entity/TimedActions/ISHandcraftAction"
local C=SuQingRefrigeration
C.Crafting=C.Crafting or {}
local F=C.Crafting
if F.loaded then return F end
F.loaded=true
function F.Mode(recipe)
    if not recipe then return nil end
    local name=recipe.getScriptObjectFullType and recipe:getScriptObjectFullType() or recipe:getName()
    if name=="SuQingRefrigeration.InstallCooling" then return "install" end
    if name=="SuQingRefrigeration.RemoveCooling" then return "remove" end
end
function F.Target(data)
    if not data or not data.getAllKeepInputItems then return nil,"no_target" end
    local items=data:getAllKeepInputItems();local target
    for i=0,items:size()-1 do
        local item=items:get(i)
        if C.Inner(item) then
            if target and target~=item then return nil,"multiple_targets" end
            target=item
        end
    end
    if not target then return nil,"no_target" end
    return target
end
function F.Capture(data)
    local items=data:getAllInputItems();local result,seen={},{}
    for i=0,items:size()-1 do
        local item=items:get(i)
        if not seen[item] then
            seen[item]=true
            local container=item:getContainer()
            if not container or not container:getItems():contains(item) then return nil,"inputs_changed" end
            local s={item=item,container=container,fullType=item:getFullType()}
            if s.fullType=="Base.Battery" then s.uses=item:getCurrentUsesFloat() end
            result[#result+1]=s
        end
    end
    return result
end
function F.RestoreInputs(snapshots)
    local restored=true
    for _,s in ipairs(snapshots or {}) do
        local ok=pcall(function()
            local current=s.item:getContainer()
            if current and current~=s.container and current:getItems():contains(s.item) then current:Remove(s.item) end
            if s.uses~=nil then s.item:setCurrentUsesFloat(s.uses) end
            if not s.container:getItems():contains(s.item) then s.container:AddItem(s.item) end
            if not s.container:getItems():contains(s.item) then error("restore_input") end
        end)
        if not ok then restored=false end
    end
    return restored
end
function F.Refresh(character,item)
    pcall(function()
        if item.setDrawDirty then item:setDrawDirty(true) end
        if CodexInventoryTransferPerformance and CodexInventoryTransferPerformance.flush then
            CodexInventoryTransferPerformance.flush(character:getPlayerNum())
        end
        if ISInventoryPage and ISInventoryPage.dirtyUI then ISInventoryPage.dirtyUI() end
    end)
end
function F.RefreshPanel(panel)
    if not panel or not panel.logic or not ArrayList then return end
    pcall(function()
        local logic=panel.logic;local containers=ArrayList.new();containers:addAll(logic:getContainers())
        logic:setContainers(ArrayList.new());logic:setContainers(containers)
        if logic.autoPopulateInputs then logic:autoPopulateInputs() end
        if logic.sortRecipeList then logic:sortRecipeList() end
        local info=panel.HandCraftPanel and panel.HandCraftPanel.recipeInfoPanel
        if info and info.onRecipeChanged then info:onRecipeChanged() end
    end)
end
local function locked(action,mode)
    if not F.ready or not C.Recipes.ready or not C.Runtime.ready then return false,"not_ready" end
    local data=action.logic and action.logic:getRecipeData()
    local target,reason=F.Target(data);if not target then return false,reason end
    local ready,why
    if mode=="install" then ready,why=C.CanInstallTarget(action.character,target)
    else ready,why=C.Target(action.character,target,true) end
    if not ready then return false,why end
    if mode=="remove" and not C.TestRecipeRemove(target,action.character) then return false,"not_installed" end
    local inputs,inputReason=F.Capture(data);if not inputs then return false,inputReason end
    local before=C.Copy(C.Record(target));local proposed
    if mode=="install" then
        proposed,why=C.PaidRecord(target,inputs);if not proposed then return false,why end
    end
    local ok,err=pcall(function()
        -- craftStarted has reserved this action's keep input already. The real
        -- perform validates current inputs; never re-run canPerform here.
        if not action.logic:performCurrentRecipe() then error("ingredients") end
        data:processDestroyAndUsedItems(action.character)
        if mode=="install" then
            local stillValid,changedReason=C.CanInstallTarget(action.character,target)
            if not stillValid then error(changedReason) end
            target:getModData()[C.key]=proposed
            if not C.Valid(C.Record(target)) then error("record_write") end
        else
            C.locks[action.character]=nil
            local removed,removeReason=C.Remove(action.character,target)
            C.locks[action.character]=action
            if not removed then error(removeReason) end
        end
    end)
    if not ok then
        -- Remove's own transaction stages/revokes every output before failing.
        -- An unexpected later exception must never restore already-spent credit.
        local spent=before and C.Global().refunded[before.token]
        if not spent then pcall(function() target:getModData()[C.key]=before end) end
        local restored=F.RestoreInputs(inputs)
        print("[SuQingRefrigeration] craft aborted: "..tostring(err).." inputsRestored="..tostring(restored))
        F.Refresh(action.character,target);return false,"failed"
    end
    F.Refresh(action.character,target)
    if mode=="install" then C.Runtime.ScanItem(target) end
    return true
end
function F.Perform(action,mode)
    if action.sqrFinished or not C.SP() or C.locks[action.character] then return false,"busy" end
    action.sqrFinished=true
    if not action.sqrCompletionRefresh then
        local original=action.onCompleteFunc
        action.onCompleteFunc=function(panel)
            if original then original(panel) end
            F.RefreshPanel(panel)
        end
        action.sqrCompletionRefresh=true
    end
    -- Remove uses the same actor lock internally; hold a separate transaction
    -- marker for the native action and let its synchronous core transaction lock.
    if F.active then return false,"busy" end
    F.active=action
    C.locks[action.character]=action
    local ok,result,reason=pcall(locked,action,mode)
    if C.locks[action.character]==action then C.locks[action.character]=nil end
    F.active=nil
    if not ok then print("[SuQingRefrigeration] crafting exception: "..tostring(result));return false,"failed" end
    return result,reason
end
function F.Start()
    if not C.SP() or F.ready or not ISHandcraftAction or not ISHandcraftAction.performRecipe then return end
    local original=ISHandcraftAction.performRecipe
    F.wrapper=function(action,...)
        local mode=F.Mode(action.craftRecipe)
        if not mode then return original(action,...) end
        return F.Perform(action,mode)
    end
    ISHandcraftAction.performRecipe=F.wrapper;F.ready=true
    print("[SuQingRefrigeration] native crafting category ready")
end
Events.OnGameStart.Add(F.Start)
return F

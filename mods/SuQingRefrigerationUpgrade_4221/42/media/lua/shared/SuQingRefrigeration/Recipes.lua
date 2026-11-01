-- Update both native input IDs and item-script caches, without script/tag edits.
require "SuQingRefrigeration/Core"
local C=SuQingRefrigeration
C.Recipes=C.Recipes or {}
local A=C.Recipes
if A.loaded then return A end
A.loaded=true
local function copy(list)
    local t={};for i=0,list:size()-1 do t[#t+1]=list:get(i) end;return t
end
local function replace(list,values)
    list:clear();for _,v in ipairs(values) do list:add(v) end
end
function A.Install()
    if A.ready then return true end
    if not C.SP() then return false end
    local manager=type(getScriptManager)=="function" and getScriptManager()
    if not manager or not ItemType or not ItemType.CONTAINER then return false end
    local candidates,scripts={},{}
    local all=manager:getAllItems()
    for i=0,all:size()-1 do
        local s=all:get(i)
        if not s:getObsolete() and not s:isHidden() and s:isItemType(ItemType.CONTAINER) then
            local id=s:getFullName();if id then candidates[#candidates+1]=id;scripts[id]=s end
        end
    end
    table.sort(candidates)
    if #candidates==0 then return false end
    local stages={}
    for _,name in ipairs({"InstallCooling","RemoveCooling"}) do
        local recipe=manager:getCraftRecipe("SuQingRefrigeration."..name)
        if not recipe then return false end
        local input=recipe:getInputs():get(0)
        if not input or not input:isKeep() or not input:isItemCount() then return false end
        local ids,cache=input:getItems(),input:getPossibleInputItems()
        if not ids or not cache then return false end
        local itemScripts={};for _,id in ipairs(candidates) do itemScripts[#itemScripts+1]=scripts[id] end
        stages[#stages+1]={ids=ids,cache=cache,oldIds=copy(ids),oldCache=copy(cache),scripts=itemScripts}
    end
    local ok,err=pcall(function()
        for _,s in ipairs(stages) do replace(s.ids,candidates);replace(s.cache,s.scripts) end
    end)
    if not ok then
        for _,s in ipairs(stages) do pcall(replace,s.ids,s.oldIds);pcall(replace,s.cache,s.oldCache) end
        print("[SuQingRefrigeration] recipe discovery failed: "..tostring(err));return false
    end
    A.ready=true;A.candidateCount=#candidates
    print("[SuQingRefrigeration] native crafting candidates="..#candidates)
    return true
end
function C.TestRecipeInstall(item,character)
    if not C.SP() or not A.ready or not C.Crafting or not C.Crafting.ready then return false end
    if not C.Inner(item) then return true end
    return C.CanInstallTarget(character,item)
end
function C.TestRecipeRemove(item,character)
    if not C.SP() or not A.ready or not C.Crafting or not C.Crafting.ready then return false end
    if not C.Inner(item) then return true end
    local ok=C.Target(character,item,true);local r=C.Record(item)
    return ok and C.Valid(r) and not C.Global().refunded[r.token]
end
Events.OnGameStart.Add(A.Install)
Events.OnMainMenuEnter.Add(function() A.ready=false end)
return A

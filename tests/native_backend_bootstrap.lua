-- Added after the existing controlled-object bootstrap; no game/native init.
NativeBridgeAudit={calls={},events={},legacyAge=0}
local A=NativeBridgeAudit
local age=FoodIndex.updateAge
FoodIndex.updateAge=function(food,...)
    A.legacyAge=A.legacyAge+1
    return age(food,...)
end
function A.count(name) A.calls[name]=(A.calls[name] or 0)+1 end
function A.api()
    local api={ready=false,active=false,version=1,factor=.2,rot=.4,settled={}}
    api.apiVersion=function() return api.version end
    api.bootstrap=function(version)
        A.count("bootstrap");A.events[#A.events+1]="bootstrap"
        api.baseVersion=version
        if api.reject then return false end
        api.ready=true;return true
    end
    api.isReady=function() return api.ready end
    api.isActive=function()
        if api.healthThrows then error("native health sentinel",0) end
        return api.active
    end
    api.activate=function(on)
        A.count(on and "activateOn" or "activateOff")
        A.events[#A.events+1]=on and "activateOn" or "activateOff"
        if not on and api.refuseStop then return true end
        api.active=on and not api.rejectActivation
        return api.active
    end
    api.setCoolingEnabled=function(on) A.count("enabled");api.enabled=on end
    api.invalidate=function() A.count("invalidate") end
    api.settle=function(food)
        A.count("settle")
        if api.settleThrows then error("native settle sentinel",0) end
        api.settled[#api.settled+1]={food=food,container=food:getContainer(),
            on=SuQingRefrigeration.Record(A.bag).on}
        if api.reenter then
            local prior=A.calls.settle
            assert(SuQingRefrigeration.Runtime.Settle(food,clock)==nil)
            assert(A.calls.settle==prior)
        end
        -- All actual API mutation methods are void, including successful settle.
    end
    api.flushKnown=function()
        A.count("flush");A.events[#A.events+1]="nativeFlush"
        if api.flushThrows then error("native flush sentinel",0) end
    end
    api.fridgeFactor=function() A.count("factor");return api.factor end
    api.foodRotSpeed=function() A.count("rot");return api.rot end
    api.status=function() return "controlled-api" end
    api.shutdown=function()
        A.count("shutdown")
        if api.shutdownThrows then error("native shutdown sentinel",0) end
        api.active=false;api.ready=false
    end
    return api
end

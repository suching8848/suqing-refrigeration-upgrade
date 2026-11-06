-- Standalone state-cache contract tests; resolver/object fixtures only.
local C=SuQingRefrigeration
local S=C.StateCache
local cases,assertions=0,0
local function check(ok,label) assertions=assertions+1;assert(ok,label or "StateCache regression") end
local function eq(a,b,label) check(a==b,(label or "equal")..": "..tostring(a).." / "..tostring(b)) end
local function test(name,fn) cases=cases+1;fn() end
local function empty(values) for _ in pairs(values) do return false end return true end
local function container(cold)
    local result={kind="ItemContainer",cold=cold}
    function result:getContainingItem() return self.owner end
    return result
end
local function food(owner)
    local result={kind="Food",container=owner}
    function result:getContainer() return self.container end
    return result
end
local function resolver(item) return item.container~=nil and item.container.cold==true end
local originalInstanceof=instanceof
instanceof=function(value,kind) return type(value)=="table" and value.kind==kind end

test("shared direct container caches true",function()
    local owner=container(true);local a,b=food(owner),food(owner)
    local cache=S.New(resolver)
    eq(cache:Resolve(a,1),true);eq(cache:Resolve(b,1),true)
    local stats=cache:GetStats();eq(stats.strictCalls,1);eq(stats.misses,1);eq(stats.hits,1)
end)
test("false is a cached value",function()
    local owner=container(false);local a=food(owner);local cache=S.New(resolver)
    eq(cache:Resolve(a,2),false);eq(cache:Resolve(a,2),false)
    eq(cache:GetStats().strictCalls,1);eq(cache:GetStats().hits,1)
end)
test("one-minute TTL boundary and unknown bypass edits",function()
    local owner=container(true);local a=food(owner);local cache=S.New(resolver)
    eq(cache:Resolve(a,3),true);owner.cold=false
    eq(cache:Resolve(a,3+S.TTL_HOURS/2),true,"unknown edit waits at most TTL")
    eq(cache:Resolve(a,3+S.TTL_HOURS),false,"exact expiration is a miss")
    eq(cache:GetStats().strictCalls,2)
end)
test("move to new direct container misses immediately",function()
    local cold,warm=container(true),container(false);local a=food(cold);local cache=S.New(resolver)
    eq(cache:Resolve(a,4),true);a.container=warm;eq(cache:Resolve(a,4),false)
    eq(cache:GetStats().strictCalls,2)
end)
test("global invalidation observes a same-container change now",function()
    local owner=container(true);local a=food(owner);local cache=S.New(resolver)
    cache:Resolve(a,5);local before=cache._entries;owner.cold=false;cache:Invalidate()
    check(cache._entries~=before,"Invalidate replaces the memo in O(1)")
    eq(cache:Resolve(a,5),false);eq(cache:GetStats().invalidations,1);eq(cache:GetStats().strictCalls,2)
end)
test("reset discards memo and clock anchor",function()
    local owner=container(true);local a=food(owner);local cache=S.New(resolver)
    cache:Resolve(a,6);cache:Reset();eq(cache._lastTime,nil)
    eq(cache:Resolve(a,1),true);eq(cache:GetStats().strictCalls,2);eq(cache:GetStats().resets,1)
end)
test("backward clock resets every container",function()
    local first,second=container(true),container(true);local a,b=food(first),food(second)
    local cache=S.New(resolver);cache:Resolve(a,8);cache:Resolve(b,8)
    first.cold=false;second.cold=false
    eq(cache:Resolve(a,7.999),false);eq(cache:Resolve(b,7.999),false)
    eq(cache:GetStats().resets,1);eq(cache:GetStats().strictCalls,4)
end)
test("invalid times always use strict lookup",function()
    local owner=container(true);local a=food(owner);local cache=S.New(resolver)
    local values={false,"1",0/0,math.huge,-math.huge,-1}
    eq(cache:Resolve(a,nil),true)
    for _,value in ipairs(values) do eq(cache:Resolve(a,value),true) end
    eq(cache:GetStats().strictCalls,7);eq(cache:GetStats().hits,0)
    check(empty(cache._entries),"invalid time creates no memo")
end)
test("untrusted objects and absent type proof stay strict",function()
    local owner=container(true);local a=food(owner);local calls=0
    local cache=S.New(function() calls=calls+1;return false end)
    cache:Resolve(nil,9);cache:Resolve({},9);cache:Resolve(food(nil),9)
    cache:Resolve(food({kind="Other"}),9)
    cache:Resolve(setmetatable(a,{__metatable=false}),9)
    local hidden=container(true);setmetatable(hidden,{__metatable=false})
    cache:Resolve(food(hidden),9)
    local prior=instanceof;instanceof=nil;cache:Resolve(a,9);instanceof=prior
    eq(calls,7);eq(cache:GetStats().hits,0);check(empty(cache._entries))
end)
test("resolver errors propagate and are never cached",function()
    local owner=container(true);local a=food(owner);local calls=0
    local cache=S.New(function() calls=calls+1;if calls==1 then error("deliberate resolver failure") end;return true end)
    local ok,message=pcall(cache.Resolve,cache,a,10)
    eq(ok,false);check(string.find(tostring(message),"deliberate resolver failure",1,true)~=nil)
    check(empty(cache._entries));eq(cache:Resolve(a,10),true);eq(calls,2)
    eq(cache:GetStats().strictCalls,2);eq(cache:GetStats().hits,0)
end)
test("invalid resolver results are rejected without poisoning cache",function()
    local owner=container(true);local a=food(owner);local cache=S.New(function() return nil end)
    eq(pcall(cache.Resolve,cache,a,10),false);check(empty(cache._entries))
    eq(pcall(S.New,nil),false)
end)
test("entries are weak keys and values retain no food/container",function()
    local owner=container(true);local a=food(owner);local cache=S.New(resolver);cache:Resolve(a,11)
    eq(getmetatable(cache._entries).__mode,"k")
    local entry=cache._entries[owner];check(type(entry)=="table")
    for key,value in pairs(entry) do
        check(value~=owner and value~=a,"entry cannot retain either object through "..tostring(key))
        check(type(value)~="table" and type(value)~="userdata","entry contains only scalar state")
    end
    cache:Invalidate();eq(getmetatable(cache._entries).__mode,"k")
    cache:Reset();eq(getmetatable(cache._entries).__mode,"k")
end)
test("New instances and returned statistics are independent",function()
    local owner=container(true);local a=food(owner);local first,second=S.New(resolver),S.New(resolver)
    first:Resolve(a,12);second:Resolve(a,12);first:Invalidate()
    eq(second:GetStats().invalidations,0);eq(second:Resolve(a,12),true);eq(second:GetStats().hits,1)
    local snapshot=second:GetStats();snapshot.hits=999;eq(second:GetStats().hits,1)
end)
test("synchronous invalidation during resolution never publishes a stale entry",function()
    local owner=container(true);local a=food(owner);local cache
    cache=S.New(function(item) cache:Invalidate();return true end)
    eq(cache:Resolve(a,13),true);check(empty(cache._entries))
    eq(cache:Resolve(a,13),true);eq(cache:GetStats().strictCalls,2)
end)
test("a dynamic resolver bridge is honored on the next invalidation",function()
    local owner=container(true);local a=food(owner);local active=function() return true end
    local cache=S.New(function(item) return active(item) end)
    eq(cache:Resolve(a,14),true);active=function() return false end;cache:Invalidate()
    eq(cache:Resolve(a,14),false)
end)
test("a resolver moving food cannot poison its former container",function()
    local old,new=container(false),container(true)
    local moved,stationary=food(old),food(old)
    local cache=S.New(function(item)
        if item==moved then item.container=new end
        return resolver(item)
    end)
    eq(cache:Resolve(moved,14),true);check(empty(cache._entries),"moved result is not attached to old key")
    eq(cache:Resolve(stationary,14),false);eq(cache:GetStats().strictCalls,2)
end)
test("571 foods in six direct containers need six strict calls per window",function()
    local owners,foods={},{}
    for i=1,6 do owners[i]=container(i%2==0) end
    for i=1,571 do foods[i]=food(owners[(i-1)%6+1]) end
    local cache=S.New(resolver)
    for _,item in ipairs(foods) do eq(cache:Resolve(item,15),item.container.cold) end
    local stats=cache:GetStats();eq(stats.strictCalls,6);eq(stats.hits,565);eq(stats.misses,6)
    for _,item in ipairs(foods) do cache:Resolve(item,15+S.TTL_HOURS/2) end
    eq(cache:GetStats().strictCalls,6)
    for _,item in ipairs(foods) do cache:Resolve(item,15+S.TTL_HOURS) end
    eq(cache:GetStats().strictCalls,12,"six new strict calls after exact TTL")
    cache:Invalidate();for _,item in ipairs(foods) do cache:Resolve(item,15+S.TTL_HOURS) end
    eq(cache:GetStats().strictCalls,18,"known invalidation immediately rechecks six containers")
end)
instanceof=originalInstanceof
return "STATE_CACHE cases="..cases.." assertions="..assertions.." PASS; 571foods/6containers strict=6 per one-minute window"

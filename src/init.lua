--// Packages
local Promise = require(script.Parent.Promise)
type Promise<result> = Promise.TypedPromise<result>

--// Module
local Cache = {}

--// Types
type mode = 'k'|'v'|'kv'

--// Functions
function Cache.async<value, key>(mode: mode?,...: mode?)
    
    local self = Cache.new(mode,...)
    
    --// Methods
    function self:getPromise(...: key): Promise<value>
        
        local promise = self:find(...)
        if promise then return promise end
        
        local resolve, reject, onCancel
        promise = Promise.new(function(_resolve, _reject, _onCancel)
            
            function resolve(...) _resolve(...); return promise end
            onCancel = _onCancel
            reject = _reject
            
            coroutine.yield()
        end)
        self:set(promise,...)
        return resolve, reject, onCancel
    end
    
    --// End
    return self
end
export type AsyncCache<value, key...> = Cache<value, key...> & {
    getPromise: (any, key...) -> Promise<value>
}

--// Factory
function Cache.new<value, key...>(mode: mode?,...: mode?)
    
    --// End
    local self = {}
    local modes = {...}
    local branch = setmetatable({}, { __mode = mode })
    
    --// Methods
    function self:find(...): value?
        
        local value = branch
        
        for index, key in {...} do
            
            if not value[key] then value[key] = setmetatable({}, { __mode = modes[index] }) end
            value = value[key]
        end
        
        return branch
    end
    function self:set(value: value,...: key...): value?
        
        local lastBranch = self:find(select(select('#',...)-1,...))
        local lastKey = select(-1,...)
        
        local lastValue = lastBranch[lastKey]
        lastBranch[lastKey] = value
        
        return lastValue
    end
    
    --// End
    return self
end
export type Cache<value, key...> = {
    set: (any, value, key...) -> value?,
    find: ((any, key...) -> value?)
        | ((any, ...any) -> { [any]: any|value })
}

--// End
return Cache
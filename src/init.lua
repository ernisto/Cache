--// Packages
local Promise = require(script.Parent.Promise)
type Promise<result> = Promise.TypedPromise<result>

--// Module
local Cache = {}

--// Types
type mode = 'k'|'v'|'kv'

--// Functions
function Cache.async<value, key>(lifetime: number, mode: mode?,...: mode?): AsyncCache<value, ...key>
    
    local self = Cache.new(-1, mode,...)
    local loadings = Cache.new(lifetime, mode,...)
    
    --// Methods
    function self:findResolvedPromise(...: key): Promise<value>?
        
        local promise = loadings:find(...)[1]
        return if promise and promise.Status == "Resolved" then promise:expect() else nil
    end
    function self:findPromise(...: key): Promise<value>?
        
        local promises = loadings:find(...)
        if not promises then return end
        
        local promise = promises[#promises]
        if not promise then return end
        
        if lifetime > 0 and os.clock() > promise.expiration then return end
        return promise
    end
    
    type job = (
        resolve: (value) -> (),
        reject: (any) -> (),
        onCancel: (cancelHandler: (...any) -> ()) -> ()
    ) -> value
    function self:promise(job: job,...: key): Promise<value>
        
        local promise = Promise.new(job)
        local loadings = loadings:find(...) or loadings:set({},...)
        local keys = {...}
        
        promise:finally(function(success, value)
            
            local index = table.find(loadings, promise)
            if index then table.remove(loadings, index) end
            
            if not success then return end
            self:set(value, unpack(keys))
            loadings[1] = promise
            
            promise.expiration = os.clock() + lifetime
        end)
        table.insert(loadings, promise)
        return promise
    end
    function self:handlePromise(...: key): (
        Promise<value>,
        (value) -> Promise<value>,
        (any) -> (),
        (...any) -> ()
    )
        local resolve, reject, onCancel
        local promise; promise = self:promise(function(_resolve, _reject, _onCancel)
            
            function resolve(value)
                
                _resolve(value)
                return promise
            end
            onCancel = _onCancel
            reject = _reject
            
            coroutine.yield()
        end)
        return promise, resolve, reject, onCancel
    end
    
    --// End
    return self
end
export type AsyncCache<value, key...> = Cache<value, key...> & {
    findResolvedPromise: (any, key...) -> Promise<value>?,
    findLatestPromise: (any, key...) -> Promise<value>?,
    handlePromise: (any, key...) -> (
        Promise<value>,
        (value) -> Promise<value>,
        (any) -> (),
        (...any) -> ()
    )
}

--// Factory
function Cache.new<value, key...>(lifetime: number, mode: mode?,...: mode?)
    
    --// Instance
    local self = { mode = mode }
    local branch = setmetatable({}, { __mode = mode })
    local modes = {...}
    
    --// Methods
    function self:find(...): value?
        
        local lastBranch
        local value = branch
        
        for index, key in {...} do
            
            if not value[key] and index < select('#',...) then value[key] = setmetatable({}, { __mode = modes[index] }) end
            
            lastBranch = value
            value = value[key]
        end
        
        return value, lastBranch
    end
    function self:set<v>(value: v,...: key...): v
        
        local _lastValue, lastBranch = self:find(select(1 :: any,...))
        local lastKey = select(-1,...)
        
        lastBranch[lastKey] = value
        return value
    end
    
    --// End
    return self
end
export type Cache<value, key...> = {
    set: <v>(any, v, key...) -> v?,
    find: ((any, key...) -> value?)
        | ((any, ...any) -> { [any]: any|value })
}

--// End
return Cache
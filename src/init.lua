--// Packages
local Promise = require(script.Parent.Promise)
type Promise<result> = Promise.TypedPromise<result>

--// Module
local Cache = {}

--// Types
type mode = 'k'|'v'|'kv'
type job<value> = (
    resolve: (value) -> (),
    reject: (any) -> (),
    onCancel: (cancelHandler: (...any) -> ()) -> ()
) -> ()

--// Functions
function Cache.async<value, key>(lifetime: number, mode: mode?,...: mode?): AsyncCache<value, ...key>
    
    local self = Cache.new(-1, mode,...)
    local loadings = Cache.new(lifetime, mode,...)
    
    --// Methods
    function self:findFirstPromise(...: key): Promise<value>?
        
        local promises = loadings:find(...)
        if not promises then return end
        
        local promise
            repeat promise = promises[1]
            until lifetime < 0 or os.clock() < promise.expiration
            or not table.remove(promises)
        
        return promise
    end
    function self:findLastPromise(...: key): Promise<value>?
        
        local promises = loadings:find(...)
        if not promises then return end
        
        local promise
            repeat promise = promises[#promises]
            until lifetime < 0 or os.clock() < promise.expiration
            or not table.remove(promises)
        
        return promise
    end
    function self:promise(job: job<value>,...: key): Promise<value>
        
        local traceback = debug.traceback("unresolved cache", 2)
        local resolve, reject, onCancel
        
        local loadings = loadings:find(...) or loadings:set({},...)
        local keys = {...}
        
        local promise = Promise.new(function(...) resolve, reject, onCancel = ...; coroutine.yield() end)
        promise.expiration = 1/0
        
        table.insert(loadings, promise)
        promise:tap(function(result)
            
            promise.expiration = os.clock() + lifetime
            
            self:set(result, unpack(keys))
            loadings[1] = promise
        end)
        
        task.spawn(function()
            
            local success, result = xpcall(job, debug.traceback, resolve, reject, onCancel)
            if promise:getStatus() == 'Started' then
                
                if success then
                    
                    warn('unresolved cache (the return has used instead)')
                    print(traceback)
                    resolve(result)
                else
                    
                    warn(`error: {result}`)
                    reject(`has not possible get trait\n{result}`)
                end
            end
            
            local index = table.find(loadings, promise, 2)
            if index then table.remove(loadings, index) end
        end)
        return promise
    end
    
    --// End
    return self
end
export type AsyncCache<value, key...> = Cache<value, key...> & {
    promise: (job: job<value>, key...) -> Promise<value>,
    findFirstPromise: (any, key...) -> Promise<value>?,
    findLastPromise: (any, key...) -> Promise<value>?,
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
function table.empty(self)
	for _, _ in pairs(self) do
		return false
	end
	return true
end

local _Storage = {}

function _Storage:new(redis)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.getObject = function(typeObj, tm)
		if typeObj == nil then
			return nil, "Please, give me a type"
		end
		if tm == nil then
			local interval = 3600
			tm = math.floor(os.time() / interval) * interval
		end
		local timeout = 1
		local list = 'type'..typeObj..'_'..tm
		local key, err = redis:brpoplpush(list, list, timeout)
		if not key then
			return nil, "Failed to select key"
		end
		local object, err = redis:hgetall(key)
		if not object then
			return nil, "Failed to select object"
		end
		object = redis:array_to_hash(object)
		local cnt = redis:hincrby(key, "cnt", 1)
		if object.is_cnt == "0" then
			return object
		elseif cnt > tonumber(object.cnt_max) then
			redis:hincrby(key, "cnt", -1)
			redis:lrem(list, 0, key)
			return o.getObject(typeObj, tm)
		else
			return object
		end
	end
	o.getStat = function(typeObj)
		if typeObj == nil then
			return nil, "Please, give me a type"
		end
		local keys, err = redis:keys('t'..typeObj..'h*')
		if table.empty(keys) then
			return nil, "Failed to select keys"
		end
		local result = {}
		for i, key in ipairs(keys) do
			local object, err = redis:hgetall(key)
			if not object then
				return nil, "Failed to select object"
			end
			result[key] = redis:array_to_hash(object)
		end
		return result
	end
	return o
end

return { createStorage = function(...)
	return _Storage:new(...)
end }
local JSON = require "JSON"
local Redis = require "resty.redis"
local Storage = require "lua-queue-system.lib.storage"
local Config = require "lua-queue-system.lib.constants.config"

local _ResponseSender = {}

function _ResponseSender:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.sendJSON = function(status, obj)
		status = status or 500
		obj = obj or {}
		if status == 200 then
			obj.status = "OK"
		else
			obj.status = "NOK"
		end
		ngx.header["Content-type"] = "application/json"
		ngx.status = status
		ngx.send_headers()
		ngx.say(JSON:encode(obj))
		ngx.exit(status)
	end
	return o
end

local _QueueSystem = {}

function _QueueSystem:new()
	local responseSender = _ResponseSender:new()
	local redis = Redis:new()
	redis:set_timeout(Config.redis.timeout)
	local ok, err = redis:connect(Config.redis.host, Config.redis.port)
	if not ok then
		responseSender.sendJSON(500, {msg = "Sorry, can't give you any information"})
		return
	end
	redis:select(Config.redis.db)
	local storage = Storage.createStorage(redis)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.sendObject = function()
		local args = ngx.req.get_uri_args()
		if args["type"] == nil then
			responseSender.sendJSON(403, {msg = "Please send a type"})
			return
		end
		local obj, err = storage.getObject(args["type"])
		if not obj then
			responseSender.sendJSON(500, {msg = "Sorry, can't give you the object"})
			return
		end
		responseSender.sendJSON(200, {
			name = obj.name,
			cnt = obj.cnt
		})
	end
	o.sendStat = function()
		local args = ngx.req.get_uri_args()
		if args["type"] == nil then
			responseSender.sendJSON(403, {msg = "Please send a type"})
			return
		end
		local objects, err = storage.getStat(args["type"])
		if not objects then
			responseSender.sendJSON(500, {msg = "Sorry, can't give you statistics"})
			return
		end
		responseSender.sendJSON(200, {objects = objects})
	end
	return o
end

return { createSystem = function(...)
	return _QueueSystem:new(...)
end }
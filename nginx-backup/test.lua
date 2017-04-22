local redis_host    = "127.0.0.1"
local redis_port    = 6379
local redis_timeout = 200

ngx.log( ngx.ERR, "test" )

local resty = require "resty.redis"
local redis = resty:new()

redis:set_timeout(redis_timeout)

local connected, err = redis:connect(redis_host, redis_port)
if not connected then
  ngx.log(ngx.ERR, "could not connect to redis @"..redis_host..": "..err)
  return
end

return true;

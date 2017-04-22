-- a quick LUA access script for nginx to check IP addresses against an
-- `ip_blacklist` set in Redis, and if a match is found send a HTTP 403.
--
-- allows for a common blacklist to be shared between a bunch of nginx
-- web servers using a remote redis instance. lookups are cached for a
-- configurable period of time.
--
-- block an ip:
--   redis-cli SADD ip_blacklist 10.1.1.1
-- remove an ip:
--   redis-cli SREM ip_blacklist 10.1.1.1
--
-- also requires lua-resty-redis from:
--   https://github.com/agentzh/lua-resty-redis
--
-- your nginx http context should contain something similar to the
-- below: (assumes resty/redis.lua exists in /etc/nginx/lua/)
--
--   lua_package_path "/etc/nginx/lua/?.lua;;";
--   lua_shared_dict ip_blacklist_cache 10m;
--
-- you can then use the below (adjust path where necessary) to check
-- against the blacklist in a http, server, location, if context:
--
-- access_by_lua_file /etc/nginx/lua/ip_blacklist.lua;
--
-- chris boulton, @surfichris

local redis_host    = "127.0.0.1"
local redis_port    = 6379

-- connection timeout for redis in ms. don't set this too high!
local redis_timeout = 200

-- check a set with this key for blacklist entries
local redis_key     = "ip_blacklist"

-- cache lookups for this many seconds
local cache_ttl     = 86400

-- end configuration

local ip                 = ngx.var.remote_addr
local ip_blacklist_cache = ngx.shared.ip_blacklist_cache

-- setup a local cache
if cache_ttl > 0 then
  -- lookup the value in the cache
  local cache_result = ip_blacklist_cache:get(ip)
  if cache_result then
    --ngx.log(ngx.DEBUG, "ip_blacklist: found result in cache for "..ip.." -> "..cache_result)

    if cache_result == 0 then
    --ngx.log(ngx.DEBUG, "ip_blacklist: (cache) no result found for "..ip)
      return
    end

    --ngx.log(ngx.INFO, "ip_blacklist: (cache) "..ip.." is blacklisted")
    ngx.header.content_type = 'text/plain'
    ngx.say("Too many requests.")
    ngx.exit(200)
  end
end

-- lookup against redis
local resty = require "resty.redis"
local redis = resty:new()

redis:set_timeout(redis_timeout)

local connected, err = redis:connect(redis_host, redis_port)
if not connected then
  --ngx.log(ngx.ERR, "ip_blacklist: could not connect to redis @"..redis_host..": "..err)
  return
end

local result, err = redis:sismember("ip_blacklist", ip)
if not result then
  --ngx.log(ngx.ERR, "ip_blacklist: lookup failed for "..ip..":"..err)
  return
end

-- cache the result from redis
if cache_ttl > 0 then
  ip_blacklist_cache:set(ip, result, cache_ttl)
end

redis:set_keepalive(10000, 2)
if result == 0 then
  --ngx.log(ngx.INFO, "ip_blacklist: no result found for "..ip)
  return
end

--ngx.log(ngx.INFO, "ip_blacklist: "..ip.." is blacklisted")
ngx.header.content_type = 'text/plain'
ngx.say("Too many requests.")
ngx.exit(403)

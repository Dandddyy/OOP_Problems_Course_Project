local key = KEYS[1]
local rate, capacity = tonumber(ARGV[1]), tonumber(ARGV[2])
local time = redis.call('TIME')
local now = time[1] * 1000 + math.floor(time[2] / 1000)
local state = redis.call('HMGET', key, 'tokens', 'at')
local tokens = capacity
if state[1] then
    local previous = tonumber(state[2])
    now = math.max(now, previous)
    tokens = math.min(capacity, tonumber(state[1]) + (now - previous) * rate / 60000)
end
if tokens < 1 then return 0 end
redis.call('HSET', key, 'tokens', tokens - 1, 'at', now)
redis.call('PEXPIRE', key, math.ceil(capacity * 60000 / rate))
return 1

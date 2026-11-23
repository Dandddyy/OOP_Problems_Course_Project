local failedKey, pendingKey = KEYS[1], KEYS[2]
local action, id = ARGV[1], ARGV[2]
local limit, window = tonumber(ARGV[3]), tonumber(ARGV[4])

if action == 'release' then
    redis.call('ZREM', pendingKey, id)
    return 0
end

local time = redis.call('TIME')
local now = time[1] * 1000 + math.floor(time[2] / 1000)
local failed = tonumber(redis.call('GET', failedKey) or '0')
if action == 'reserve' then
    local pending = redis.call('ZCOUNT', pendingKey, '(' .. now, '+inf')
    if failed + pending >= limit then return -1 end
    redis.call('ZREMRANGEBYSCORE', pendingKey, '-inf', now)
    redis.call('ZADD', pendingKey, now + window, id)
    redis.call('PEXPIRE', pendingKey, window)
    return 0
end

local expiry = redis.call('ZSCORE', pendingKey, id)
if not expiry or tonumber(expiry) <= now then return -2 end
if action == 'failure' then
    failed = math.min(failed + 1, limit)
    redis.call('SET', failedKey, failed, 'PX', window)
elseif action == 'success' then
    redis.call('DEL', failedKey)
end
redis.call('ZREM', pendingKey, id)
return failed

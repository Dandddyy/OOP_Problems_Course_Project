-- Keys: one sorted set per quota.
-- Arguments: receipt ID, quota count, then (window count, (window ms, limit)...) per quota.
local quotas = tonumber(ARGV[2])
local time = redis.call('TIME')
local now = time[1] * 1000 + math.floor(time[2] / 1000)
local longest = {}
local offset = 3
for quota = 1, quotas do
    local windows = tonumber(ARGV[offset])
    offset = offset + 1
    for window = 1, windows do
        local duration = tonumber(ARGV[offset])
        local cutoff = now - duration
        local count = redis.call('ZCOUNT', KEYS[quota], '(' .. cutoff, '+inf')
        if count >= tonumber(ARGV[offset + 1]) then return quota end
        longest[quota] = duration
        offset = offset + 2
    end
end
-- Only write after every quota admits the same request.
for quota = 1, quotas do
    local key = KEYS[quota]
    redis.call('ZADD', key, now, ARGV[1])
    redis.call('ZREMRANGEBYSCORE', key, '-inf', now - longest[quota])
    redis.call('PEXPIRE', key, longest[quota])
end
return 0

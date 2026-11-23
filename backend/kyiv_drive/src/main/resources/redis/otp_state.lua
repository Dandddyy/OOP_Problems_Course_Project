local codeKey, attemptsKey = KEYS[1], KEYS[2]
local action = ARGV[1]
if action == 'issue' then
    redis.call('SET', codeKey, ARGV[2], 'PX', ARGV[3])
    redis.call('DEL', attemptsKey)
    return 1
end
local saved = redis.call('GET', codeKey)
if action == 'discard' then
    if saved == ARGV[2] then redis.call('DEL', codeKey, attemptsKey) end
    return 1
end
if not saved then return 0 end
local attempts = tonumber(redis.call('GET', attemptsKey) or '0')
if attempts >= tonumber(ARGV[3]) then
    redis.call('DEL', codeKey, attemptsKey)
    return -2
end
if string.match(saved, '^[^:]+:(%d+)$') == ARGV[2] then
    redis.call('DEL', codeKey, attemptsKey)
    return 1
end
local remaining = redis.call('PTTL', codeKey)
if remaining <= 0 then return 0 end
redis.call('SET', attemptsKey, attempts + 1, 'PX', remaining)
return -1

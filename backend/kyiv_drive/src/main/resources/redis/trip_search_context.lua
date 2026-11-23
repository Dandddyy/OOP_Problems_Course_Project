-- KEYS: active session pointer, context hash, pending search and optional previous context hash (publish only).
-- ARGV: mode, context ID, variant ID, sort, idle TTL ms, variant limit, reserved,
--       data/variant JSON, metadata JSON, order JSON, fingerprint, source variant, replace, previous context ID.
-- Publish uses payload slots 8..12 for snapshot, immutable definition, variant, order and mutable state JSON.
-- ARGV[15] optionally stores request identity for deduplicating full-search retries.
local mode, context, variant, sort = ARGV[1], ARGV[2], ARGV[3], ARGV[4]
local time = redis.call('TIME')
local now = time[1] * 1000 + math.floor(time[2] / 1000)
local expires = now + tonumber(ARGV[5])

if mode == 'publish' then
    if redis.call('GET', KEYS[3]) ~= context then return -4 end
    local current = redis.call('GET', KEYS[1])
    if current and current ~= ARGV[14] then return -4 end
    redis.call('HSET', KEYS[2], 'data', ARGV[8], 'meta', ARGV[9], 'state', ARGV[12],
        'variant:' .. variant, ARGV[10], 'order:' .. variant .. ':' .. sort, ARGV[11])
    if ARGV[15] ~= '' then redis.call('HSET', KEYS[2], 'request', ARGV[15]) end
    redis.call('PEXPIREAT', KEYS[2], expires)
    redis.call('SET', KEYS[1], context, 'PXAT', expires)
    redis.call('DEL', KEYS[3])
    if #KEYS == 4 and KEYS[4] ~= KEYS[2] then redis.call('DEL', KEYS[4]) end
    return expires
end

if redis.call('GET', KEYS[1]) ~= context
    or redis.call('HEXISTS', KEYS[2], 'data') == 0
    or redis.call('HEXISTS', KEYS[2], 'meta') == 0
    or redis.call('HEXISTS', KEYS[2], 'state') == 0 then return -1 end
local meta = cjson.decode(redis.call('HGET', KEYS[2], 'state'))
local field = 'variant:' .. variant

if mode == 'variant' then
    if ARGV[13] ~= '1' and redis.call('HEXISTS', KEYS[2], 'variant:' .. ARGV[12]) == 0 then return -2 end
    local sorts = {'SCORE', 'PRICE', 'WALKING', 'DEPARTURE', 'ARRIVAL'}
    for index = #meta.variants, 1, -1 do
        local item = meta.variants[index]
        if item.fingerprint == ARGV[11] then
            if redis.call('HEXISTS', KEYS[2], 'variant:' .. item.id) == 1 then return -3 end
            table.remove(meta.variants, index)
            for _, order in ipairs(sorts) do redis.call('HDEL', KEYS[2], 'order:' .. item.id .. ':' .. order) end
        end
    end
    while #meta.variants >= tonumber(ARGV[6]) do
        local oldest = 1
        for i = 2, #meta.variants do
            if meta.variants[i].lastUsed < meta.variants[oldest].lastUsed then oldest = i end
        end
        local removed = table.remove(meta.variants, oldest)
        redis.call('HDEL', KEYS[2], 'variant:' .. removed.id)
        for _, order in ipairs(sorts) do redis.call('HDEL', KEYS[2], 'order:' .. removed.id .. ':' .. order) end
    end
    table.insert(meta.variants, {id = variant, fingerprint = ARGV[11], lastUsed = 0})
    redis.call('HSET', KEYS[2], field, ARGV[8], 'order:' .. variant .. ':' .. sort, ARGV[10])
else
    if redis.call('HEXISTS', KEYS[2], field) == 0 then return -2 end
    if mode == 'order' then
        redis.call('HSETNX', KEYS[2], 'order:' .. variant .. ':' .. sort, ARGV[10])
    end
end

meta.sequence = meta.sequence + 1
for _, item in ipairs(meta.variants) do
    if item.id == variant then item.lastUsed = meta.sequence end
end
redis.call('HSET', KEYS[2], 'state', cjson.encode(meta))
redis.call('PEXPIREAT', KEYS[2], expires)
redis.call('PEXPIREAT', KEYS[1], expires)
return expires

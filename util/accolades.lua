local Acc = {}

-- Windower JSON library (parser/reader). It registers under _libs.json. [1](https://github.com/Tny5989/UnityNPC/blob/master/model/menu/buy.lua)
pcall(require, 'json')
local wjson = (_libs and _libs.json) or nil

local WEEKLY_CAP = 100000
local SAVE_PATH = windower.addon_path .. 'data/accolades.json'
local data = {}

-- ---------- Minimal JSON encoder (for our simple tables) ----------
local function escape_str(s)
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return s
end

local function is_array(t)
    local max = 0
    for k,_ in pairs(t) do
        if type(k) ~= 'number' then return false end
        if k > max then max = k end
    end
    return max > 0
end

local function encode_value(v)
    local tv = type(v)
    if tv == 'nil' then
        return 'null'
    elseif tv == 'number' then
        return tostring(v)
    elseif tv == 'boolean' then
        return v and 'true' or 'false'
    elseif tv == 'string' then
        return '"' .. escape_str(v) .. '"'
    elseif tv == 'table' then
        if is_array(v) then
            local parts = {}
            for i = 1, #v do parts[#parts+1] = encode_value(v[i]) end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            local parts = {}
            for k,val in pairs(v) do
                parts[#parts+1] = '"' .. escape_str(tostring(k)) .. '":' .. encode_value(val)
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    else
        return '"' .. escape_str(tostring(v)) .. '"'
    end
end

local function encode_json(tbl)
    -- If your Windower json.lua ever gains encode(), use it.
    if wjson and type(wjson.encode) == 'function' then
        return wjson.encode(tbl)
    end
    return encode_value(tbl)
end

local function decode_json(str)
    if not str or str == '' then return {} end

    -- Prefer Windower parser: json.parse(content) -> table or nil, err 
    if wjson and type(wjson.parse) == 'function' then
        local parsed = wjson.parse(str)
        return (type(parsed) == 'table') and parsed or {}
    end

    -- No parser available
    return {}
end
-- ---------- End JSON helpers ----------

local function ensure_data_dir()
    if windower.create_dir then
        windower.create_dir(windower.addon_path .. 'data')
    end
end

local function load()
    local f = io.open(SAVE_PATH, 'r')
    if f then
        local content = f:read('*a')
        f:close()
        data = decode_json(content)
        if type(data) ~= 'table' then data = {} end
    else
        data = {}
    end
end

local function save()
    ensure_data_dir()

    -- ✅ Reload latest file before writing (prevents overwrite conflicts)
    local existing = {}
    local f = io.open(SAVE_PATH, 'r')
    if f then
        local content = f:read('*a')
        f:close()
        existing = decode_json(content) or {}
    end

    -- ✅ Merge current memory into file
    for k, v in pairs(data) do
        existing[k] = v
    end

    -- ✅ Write merged result
    local f2 = io.open(SAVE_PATH, 'w+')
    if f2 then
        f2:write(encode_json(existing))
        f2:close()
    end

    -- ✅ Keep memory in sync
    data = existing
end

-- Character key: character name only (as requested)
local function char_key()
    local player = windower.ffxi.get_player()
    if not player or not player.name then return nil end
    return player.name
end

-- JST = UTC + 9; reset at JST Monday 00:00 (Sunday 10:00 AM CST).
local function now_jst()
    return os.time(os.date('!*t')) + (9 * 3600)
end

local function jst_week_start()
    local t = os.date('*t', now_jst())
    -- wday: Sunday=1 .. Saturday=7; want Monday 00:00
    local wday = t.wday
    local days_since_monday = (wday == 1) and 6 or (wday - 2)
    t.hour, t.min, t.sec = 0, 0, 0
    t.day = t.day - days_since_monday
    return os.time(t)
end



function Acc.init()
    load()
    save() -- create file even before first update_balance()
end

function Acc.ensure_character()
    local key = char_key()
    if not key then return end

    if not data[key] then
        data[key] = {
            week_start = jst_week_start(),
            spent = 0,
            last_balance = 0,
        }

        save()
    end
end


function Acc.update_balance(new_balance)
    local key = char_key()
    if not key then return end

    new_balance = tonumber(new_balance) or 0
    local week_start = jst_week_start()

    data[key] = data[key] or { week_start = week_start, spent = 0, last_balance = new_balance }
    local c = data[key]

    if c.week_start ~= week_start then
        c.week_start = week_start
        c.spent = 0
        c.last_balance = new_balance
        save()
        return
    end

    if new_balance < (tonumber(c.last_balance) or new_balance) then
        c.spent = (tonumber(c.spent) or 0) + ((tonumber(c.last_balance) or new_balance) - new_balance)
    end

    c.last_balance = new_balance
    save()
end

function Acc.spent_this_week()
    local key = char_key()
    return (key and data[key] and tonumber(data[key].spent)) or 0
end

function Acc.remaining_weekly()
    return math.max(0, WEEKLY_CAP - Acc.spent_this_week())
end

function Acc.weekly_cap()
    return WEEKLY_CAP
end

function Acc.set_spent(value)
    local key = char_key()
    if not key then return end

    data[key] = data[key] or {}

    data[key].spent = math.max(0, tonumber(value) or 0)
    save()
end

function Acc.add_spent(value)
    local key = char_key()
    if not key then return end

    data[key] = data[key] or {}

    local current = tonumber(data[key].spent) or 0
    data[key].spent = math.max(0, current + (tonumber(value) or 0))
    save()
end


return Acc
-- util/powder.lua
local M = {}

-- Cached via incoming 0x113 (Currencies 1 update)
M._cached_accolades = 0

function M.set_accolades(v)
    M._cached_accolades = tonumber(v) or 0
end

function M.get_accolades()
    return M._cached_accolades or 0
end

local Items = require('data/items')

-- Constants for Prize Powder
local ITEM_EN_NAME = 'Prize Powder'
local COST = 10
local STACK_SIZE = 99
local BAG_INV = 0

local function get_prize_powder_item_id()
    local item = Items.GetByProperty('en', ITEM_EN_NAME)
    if item and type(item) == 'table' and item.id and item.id ~= 0 then
        return item.id
    end
    return nil
end

local function get_unity_accolades()
    return M.get_accolades()
end

local function get_inventory_state()
    local items = windower.ffxi.get_items()
    local inv = items and items.inventory or nil

    local inv_max = nil
    if windower.ffxi.get_bag_info then
        local bag_info = windower.ffxi.get_bag_info(BAG_INV)
        inv_max = bag_info and bag_info.max or nil
    end

    if (not inv_max) and type(inv) == 'table' then
        local max_guess = 0
        for k, _ in pairs(inv) do
            if type(k) == 'number' and k > max_guess then
                max_guess = k
            end
        end
        if max_guess > 0 then inv_max = max_guess end
    end

    return inv, inv_max
end

local function count_free_inventory_slots(inv, inv_max)
    if type(inv) ~= 'table' or not inv_max then return 0 end

    local used = 0
    for i = 1, inv_max do
        local slot = inv[i]
        if type(slot) == 'table' and slot.id and slot.id ~= 0 then
            used = used + 1
        end
    end

    return inv_max - used
end

local function remaining_stack_capacity(inv, item_id, stack_size)
    if type(inv) ~= 'table' or not item_id then return 0 end

    local rem = 0
    for _, slot in pairs(inv) do
        if type(slot) == 'table' and slot.id == item_id then
            local count = tonumber(slot.count) or 0
            if count < stack_size then
                rem = rem + (stack_size - count)
            end
        end
    end

    return rem
end

-- Returns: buy_count, accolades, free_slots, rem_in_stacks, err
function M.max_prize_powder_buyable()
    local item_id = get_prize_powder_item_id()
    if not item_id then
        return 0, 0, 0, 0, 'Could not resolve item id for: ' .. ITEM_EN_NAME
    end

    local accolades = get_unity_accolades()
    if accolades <= 0 then
        return 0, accolades, 0, 0, 'Unity Accolades not available yet (waiting for 0x113 refresh).'
    end

    local max_by_accolades = math.floor(accolades / COST)

    local inv, inv_max = get_inventory_state()
    if type(inv) ~= 'table' or not inv_max then
        return 0, accolades, 0, 0, 'Could not read inventory state'
    end

    local free_slots = count_free_inventory_slots(inv, inv_max)
    local rem_in_stacks = remaining_stack_capacity(inv, item_id, STACK_SIZE)
    local max_by_space = rem_in_stacks + (free_slots * STACK_SIZE)

    local buy_count = math.min(max_by_accolades, max_by_space)

    -- Optional debug (comment out once stable)
    -- windower.add_to_chat(207, string.format(
    --     '[UnityNPC] Accolades=%d | MaxByAcc=%d | FreeSlots=%d | StackRoom=%d | MaxBySpace=%d | Buy=%d',
    --     accolades, max_by_accolades, free_slots, rem_in_stacks, max_by_space, buy_count
    -- ))

    return buy_count, accolades, free_slots, rem_in_stacks, nil
end

return M

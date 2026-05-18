local NilCommand = require('command/nil')
local WarpCommand = require('command/warp')
local BuyCommand = require('command/buy')
local Npcs = require('data/npcs')
local Warps = require('data/warps')
local Items = require('data/items')
local Powder = require ('util/powder')
local Accolades = require('util/accolades')

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local CommandFactory = {}

--------------------------------------------------------------------------------
local function StringToZoneId(name)
    local zone = resources.zones:with('en', windower.convert_auto_trans(name))
    if zone then
        return zone.id
    else
        return 0
    end
end

--------------------------------------------------------------------------------

local function ComputePrizePowderAllCount()
    local ok, buy_count, accolades, free_slots, rem_in_stacks, err = pcall(function()
        return Powder.max_prize_powder_buyable()
    end)
	-- Enforce weekly Unity Accolade cap
	local remaining = Accolades.remaining_weekly()
	local max_by_week = math.floor(remaining / 10) -- 10 per powder

	buy_count = math.min(buy_count, max_by_week)
    if not ok then
        log('[UnityNPC] powder.lua error: ' .. tostring(buy_count))
        return 0
    end

    -- If your powder.lua returns err as 5th value, it will land in `err`.
    if err then
        log('[UnityNPC] powder.lua: ' .. tostring(err))
        return 0
    end

    buy_count = tonumber(buy_count) or 0
    return math.floor(buy_count)
end

--------------------------------------------------------------------------------
function CommandFactory.CreateCommand (cmd, p1, p2)
    if cmd == 'warp' then
        if not p1 then
            log ('Zone must be provided')
            return NilCommand:NilCommand ()
        end

        local warp = Warps.GetByProperty ('zone', StringToZoneId (p1))
        local npc = Npcs.GetForCurrentZone ()

        return WarpCommand:WarpCommand (npc.id, warp)

    elseif cmd == 'buy' then
        local item = Items.GetByProperty ('en', p1)
        if item.id == 0 then
            log ('Invalid item argument')
            return NilCommand:NilCommand ()
        end

        if not p2 then
            log ('Invalid count argument')
            return NilCommand:NilCommand ()
        end

        local count = nil

        -- allow "all" for Prize Powder (handle both common names)
		
        if type(p2) == 'string' and p2:lower() == 'all' then
			local en = (item.en or ''):lower()
			if en == 'prize powder' or en == 'pinch of prize powder' then
				count = ComputePrizePowderAllCount()
				if count > 1000 then
					windower.add_to_chat(207, '[UnityNPC] Large buy detected ('..count..'), proceeding...')
				end
				if count == 0 then
					log('[UnityNPC] Cannot buy Prize Powder: Unity Accolades not available yet. (Waiting for 0x113 refresh)')
					return NilCommand:NilCommand()
				end

		end
	end

        -- fallback: numeric count
        if count == nil then
			count = tonumber(p2)
		end

        if not count or count <= 0 then
            log ('Invalid count argument')
            return NilCommand:NilCommand ()
        end

        local npc = Npcs.GetForCurrentZone ()
        return BuyCommand:BuyCommand (npc.id, item, npc.zone, count)

    else
        log ('Unknown command')
        return NilCommand:NilCommand ()
    end
end



return CommandFactory
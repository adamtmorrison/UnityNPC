_addon.name = 'UnityNPC'
_addon.author = 'Areint/Alzade + VC-MSCP (Vibe coding using Microsoft CoPilot)'
_addon.version = '1.1.6'
_addon.commands = {'unpc'}

--------------------------------------------------------------------------------
require('logger')
unpc_debug = false 
-- IMPORTANT:
-- dupes = UnityNPC's duplicate-packet detector (util/packets.lua)
-- packets = Windower's packets library (parse/new/inject)
settings      = require('util/settings')
resources     = require('resources')
packets 	  = require('packets')  
local dupes   = require('util/packets')
local CommandFactory = require('command/factory')
local Aliases        = require('util/aliases')
local NilCommand     = require('command/nil')
local Powder         = require('util/powder')
local Accolades 	 = require('util/accolades')

--------------------------------------------------------------------------------
local command = NilCommand:NilCommand()

--------------------------------------------------------------------------------
-- Currency tracking state
local last_currency_update_ts = 0
local pending_buy_all = nil

local STALE_AFTER_SECONDS = 30
local MIN_REQUEST_GAP_SECONDS = 5
local last_request_ts = 0
local COMMAND_TIMEOUT_SECONDS = 8   -- adjust if you want (5–10 is typical)
local command_started_ts = 0
-- Command queue
local command_queue = {}
local queue_active = false
local dequeue_and_run

-- Accolades report state (prevents duplicate printing)
local pending_accolades_report = false
local pending_accolades_report_deadline = 0

-- Chat colors (Windower default palette commonly used)
-- If your client uses different palette, you can tweak these numbers.
local CHAT_WHITE  = 207
local CHAT_GREEN  = 158
local CHAT_YELLOW = 160
local CHAT_RED    = 167

--------------------------------------------------------------------------------
local function OnCommandFinished()
    command = NilCommand:NilCommand()
    queue_active = false
    dequeue_and_run()
end

--------------------------------------------------------------------------------
local function currency_is_stale()
    if last_currency_update_ts == 0 then
        return true
    end
    return (os.clock() - last_currency_update_ts) > STALE_AFTER_SECONDS
end

local function request_currency_update(force)
    local now = os.clock()
    if not force and (now - last_request_ts) < MIN_REQUEST_GAP_SECONDS then
        return
    end
    last_request_ts = now

    -- Outgoing 0x10F requests the "Currencies 1" info; server replies with 0x113. [1](https://datascience.101workbook.org/07-wrangling/01-file-access/03e-download-github-folders-svn/)[2](https://linuxvox.com/blog/wget-a-raw-file-from-github-from-a-private-repo/)[3](https://loltank.com/2023/07/01/ff11-gil-guide-maximizing-frming-final-fantasy-xi-in-reisenjima)
    local p = packets.new('outgoing', 0x10F)
    packets.inject(p)
end

local function refresh_tick()
    local info = windower.ffxi.get_info()
    if info and info.logged_in then
        -- Only request if stale AND we're not mid-complex-command AND not already waiting on a buy-all refresh
        if currency_is_stale() and command:Type() == 'NilCommand' and pending_buy_all == nil then
            request_currency_update(false)
        end
    end
    coroutine.schedule(refresh_tick, STALE_AFTER_SECONDS)
end

--------------------------------------------------------------------------------
local function usage_color(spent, cap)
    if cap <= 0 then return CHAT_WHITE end
    local pct = (spent / cap) * 100

    if pct <= 75 then
        return CHAT_GREEN
    elseif pct <= 89 then
        return CHAT_YELLOW
    else
        return CHAT_RED
    end
end
--------------------------------------------------------------------------------
local function print_accolades_report()
    local spent = Accolades.spent_this_week()
    local cap = Accolades.weekly_cap()
    local remain = Accolades.remaining_weekly()

    local current = 0
    if type(Powder.get_accolades) == 'function' then
        current = Powder.get_accolades()
    elseif Powder._cached_accolades then
        current = Powder._cached_accolades
    end

    local color = usage_color(spent, cap)

    windower.add_to_chat(color,
        string.format('[UnityNPC] Accolades: %d | Spent this week: %d / %d | Remaining: %d',
            current, spent, cap, remain
        )
    )
end

--------------------------------------------------------------------------------
local function print_accolades_status()
    local val = 0

    -- safely get cached accolades
    if type(Powder.get_accolades) == 'function' then
        val = Powder.get_accolades()
    elseif Powder._cached_accolades then
        val = Powder._cached_accolades
    end

    local age = 'never'
    if last_currency_update_ts and last_currency_update_ts ~= 0 then
        age = string.format('%.1f sec ago', os.clock() - last_currency_update_ts)
    end

    local stale = currency_is_stale() and 'STALE' or 'FRESH'
	if unpc_debug == true then 
		windower.add_to_chat(207,
			string.format('[UnityNPC] Accolades: %d | Last update: %s | Status: %s',
				val, age, stale
			)
		)
	end
end
--------------------------------------------------------------------------------
local function OnLoad()
    coroutine.schedule(function()
		Accolades.ensure_character()
	end, 2)

	
	settings.load()
    Aliases.Update()
	Accolades.init()

    -- Seed refresh soon after load (smart loop will handle the rest)
    coroutine.schedule(function()
        request_currency_update(true)
        refresh_tick()
    end, 1)
end

--------------------------------------------------------------------------------
local function arm_command_timeout()
    command_started_ts = os.clock()
    coroutine.schedule(function()
        -- If command is still running after timeout, force reset.
        if command:Type() ~= 'NilCommand'
		   and (os.clock() - command_started_ts) >= COMMAND_TIMEOUT_SECONDS then

			if unpc_debug then
				windower.add_to_chat(207, '[UnityNPC] Command timeout; forcing reset.')
			end

			pending_buy_all = nil
			command = NilCommand:NilCommand()
			queue_active = false
			dequeue_and_run()
		end
    end, COMMAND_TIMEOUT_SECONDS)
end

--------------------------------------------------------------------------------
dequeue_and_run = function()
    if queue_active then return end

    if #command_queue == 0 then
        return
    end

    local next_cmd = table.remove(command_queue, 1)

    queue_active = true

    if unpc_debug then
        windower.add_to_chat(207,
            '[UnityNPC] Starting command from queue: ' ..
            tostring(next_cmd.cmd) .. ' ' ..
            tostring(next_cmd.p1) .. ' ' ..
            tostring(next_cmd.p2)
        )
    end

    command = CommandFactory.CreateCommand(next_cmd.cmd, next_cmd.p1, next_cmd.p2)
    command:SetSuccessCallback(OnCommandFinished)
    command:SetFailureCallback(OnCommandFinished)
    command()

    arm_command_timeout()
end

local function enqueue_command(cmd, p1, p2)
    table.insert(command_queue, { cmd = cmd, p1 = p1, p2 = p2 })

    if unpc_debug then
        windower.add_to_chat(207,
            string.format('[UnityNPC] Queued command: %s %s %s',
                tostring(cmd), tostring(p1), tostring(p2))
        )
    end

    dequeue_and_run()
end

--------------------------------------------------------------------------------
local function OnCommand(cmd, ...)
    	
    local args = {...}
    local p1 = args[1]
    local p2 = args[2]
	-- ✅ Help command: //unpc help  OR  //unpc ?
	if cmd == 'help' or cmd == '?' then
		windower.add_to_chat(207, '================ UnityNPC Commands ================')

		windower.add_to_chat(207, '//unpc buy "<item>" <count>')
		windower.add_to_chat(207, '   Buy an item (supports "all" for Prize Powder)')

		windower.add_to_chat(207, '//buypowder [count|all]')
		windower.add_to_chat(207, '   Shortcut: Buy Prize Powder')

		windower.add_to_chat(207, '//buykeys [count]')
		windower.add_to_chat(207, '   Shortcut: Buy SP Gobbie Keys')

		windower.add_to_chat(207, '//buywarp')
		windower.add_to_chat(207, '   Shortcut: Buy Warp Scroll')

		windower.add_to_chat(207, '--------------------------------------------------')
		windower.add_to_chat(207, '//unpc accolades')
		windower.add_to_chat(207, '   Show current accolades + weekly usage')

		windower.add_to_chat(207, '//unpc setspent <amount>')
		windower.add_to_chat(207, '   Manually set weekly accolades spent')

		windower.add_to_chat(207, '//unpc addspent <amount>')
		windower.add_to_chat(207, '   Add to weekly accolades spent')

		windower.add_to_chat(207, '--------------------------------------------------')
		windower.add_to_chat(207, '//unpc help  or  //unpc ?')
		windower.add_to_chat(207, '   Show this help menu')

		windower.add_to_chat(207, '==================================================')
		return
	end
	-- New command: //unpc accolades
	if cmd == 'accolades' then
    -- If stale, refresh first and print once after update (or after 1 second fallback)
    if currency_is_stale() then
        pending_accolades_report = true
        pending_accolades_report_deadline = os.clock() + 1.0

        if unpc_debug then
            windower.add_to_chat(CHAT_WHITE, '[UnityNPC] Accolades are stale, requesting refresh...')
        end

        request_currency_update(true)

        -- Fallback: print after 1 second even if packet doesn't arrive
        coroutine.schedule(function()
            if pending_accolades_report and os.clock() >= pending_accolades_report_deadline then
                pending_accolades_report = false
                print_accolades_report()
				end
			end, 1)

			return
		end

		-- Fresh data: print immediately (once)
		print_accolades_report()
		return
	end
	-- //unpc setspent <amount>
	if cmd == 'setspent' then
		local n = tonumber(args[1])
		if not n then
			windower.add_to_chat(207, '[UnityNPC] Usage: //unpc setspent <number>')
			return
		end

		Accolades.set_spent(n)
		windower.add_to_chat(207,
			string.format('[UnityNPC] Weekly spent manually set to: %d', n)
		)
		return
	end

	-- //unpc addspent <amount>
	if cmd == 'addspent' then
		local n = tonumber(args[1])
		if not n then
			windower.add_to_chat(207, '[UnityNPC] Usage: //unpc addspent <number>')
			return
		end

		Accolades.add_spent(n)
		windower.add_to_chat(207,
			string.format('[UnityNPC] Added %d to weekly spend', n)
		)
		return
	end

    -- Special handling for: //unpc buy <item name...> <count|all>
    if cmd == 'buy' then
		if not args[1] then
			log('Invalid buy arguments')
			return
		end

		-- default behavior when no count provided
		if not args[2] then
			p1 = args[1]
			p2 = '1'   -- ✅ FIX: default to 1
		else
			p2 = args[#args]

			if #args == 2 then
				p1 = args[1]
			else
				p1 = table.concat(args, ' ', 1, #args - 1)
			end
		end

		-- clean quotes
		if type(p1) == 'string' then
			p1 = p1:gsub('^"(.*)"$', '%1')
		end
	end


    -- Smart behavior: if buy "all" and accolades cache is stale, refresh first then execute.
    if cmd == 'buy' and type(p2) == 'string' and p2:lower() == 'all' then
        if currency_is_stale() then
            pending_buy_all = {cmd = cmd, p1 = p1, p2 = p2}
            windower.add_to_chat(207, '[UnityNPC] Refreshing Unity Accolades...')
            request_currency_update(true)
            return
        end
    end
	if unpc_debug then 
		windower.add_to_chat(207,
			string.format('[DEBUG] p1="%s" p2="%s"', tostring(p1), tostring(p2))
		)
	end
    enqueue_command(cmd, p1, p2)
end

--------------------------------------------------------------------------------
local function OnIncomingData(id, original, pkt, b, i)

    -- 1) Handle currency packet FIRST (so it always runs)
    if id == 0x113 then
        local data = packets.parse('incoming', pkt)
        if data and data['Unity Accolades'] then
            local val = tonumber(data['Unity Accolades']) or 0

            -- cache
            if type(Powder.set_accolades) == 'function' then
                Powder.set_accolades(val)
            else
                Powder._cached_accolades = val
            end

            -- weekly tracking
            Accolades.update_balance(val)

            -- fresh timestamp
            last_currency_update_ts = os.clock()

            -- if waiting to print, print now (once)
            if pending_accolades_report then
                pending_accolades_report = false
                print_accolades_report()
            end
        end
    end

    -- 2) Always send packets to command (critical for dialogue flow)
    local handled = false
    if command and command.OnIncomingData then
        handled = command:OnIncomingData(id, pkt)
    end

    -- 3) Duplicate tracking should NOT block command processing.
    -- Keep the check for your own diagnostics / optional filtering.
    dupes.is_duplicate(id, pkt)

    return handled
end


--------------------------------------------------------------------------------
local function OnOutgoingData(id, _, pkt, b, i)
    return command:OnOutgoingData(id, pkt)
end

--------------------------------------------------------------------------------
windower.register_event('load', OnLoad)
windower.register_event('addon command', OnCommand)
windower.register_event('incoming chunk', OnIncomingData)
windower.register_event('outgoing chunk', OnOutgoingData)

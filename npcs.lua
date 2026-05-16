--------------------------------------------------------------------------------
local function ByValue(name, search_value, domain)
    for _, value in pairs(domain) do
        if value[name] == search_value then
            return value
        end
    end

    return domain['']
end

--------------------------------------------------------------------------------
local function AllByValue(name, search_value, domain)
    local matches = {}
    for _, value in pairs(domain) do
        if value[name] == search_value then
            table.insert(matches, value)
        end
    end

    table.insert(matches, domain[''])
    return matches
end

--------------------------------------------------------------------------------
local Npcs = {}

Npcs.Values = {}
Npcs.Values['']       = { id = 00000000, en = '',                 	zone = 000 }

Npcs.Values[17739958] = { id = 17739958, en = 'Igsli', 				zone = 235 }
Npcs.Values[17719643] = { id = 17719643, en = 'Urbiolaine', 		zone = 230 }
Npcs.Values[17764608] = { id = 17764608, en = 'Teldro-Kesdrodo', 	zone = 241 }
Npcs.Values[17764609] = { id = 17764609, en = 'Yonolala', 			zone = 241 }
Npcs.Values[17826178] = { id = 17826178, en = 'Nunaarl Bthtrogg', 	zone = 256 }

--------------------------------------------------------------------------------
function Npcs.GetByProperty(key, value)
    return ByValue(tostring(key), value, Npcs.Values)
end

--------------------------------------------------------------------------------
function Npcs.GetAllByProperty(key, value)
    return AllByValue(tostring(key), value, Npcs.Values)
end

--------------------------------------------------------------------------------
function Npcs.GetForCurrentZone()
    return Npcs.GetAllByProperty('zone', windower.ffxi.get_info().zone)[1]
end

return Npcs

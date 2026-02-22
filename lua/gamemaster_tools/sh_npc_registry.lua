--[[
    Gamemaster Tools - NPC Registry
    Stores detected NPCs and their base types for spawning
]]

GM_Tools.NPCRegistry = GM_Tools.NPCRegistry or {}
GM_Tools.NPCRegistry.List = GM_Tools.NPCRegistry.List or {}
GM_Tools.NPCRegistry.Categories = GM_Tools.NPCRegistry.Categories or {}

-- Base type identifiers
GM_Tools.BaseType = {
    UNKNOWN = 0,
    DEFAULT = 1,
    VJ_BASE = 2,
    DROID = 3,
    LVS = 4,
    NEXTBOT = 5,
    CUSTOM = 6,
}

GM_Tools.BaseTypeNames = {
    [0] = "Unknown",
    [1] = "Default",
    [2] = "VJ Base",
    [3] = "Droid",
    [4] = "LVS",
    [5] = "NextBot",
    [6] = "Custom",
}

-- Register an NPC to the registry
function GM_Tools.NPCRegistry:Register(class, data)
    self.List[class] = {
        Class = class,
        Name = data.Name or class,
        Category = data.Category or "Other",
        BaseType = data.BaseType or GM_Tools.BaseType.UNKNOWN,
        SpawnFlags = data.SpawnFlags or 0,
        KeyValues = data.KeyValues or {},
        Weapons = data.Weapons or {},
        Health = data.Health or nil,
        Model = data.Model or nil,
    }

    -- Add to category list
    local cat = self.List[class].Category
    self.Categories[cat] = self.Categories[cat] or {}
    table.insert(self.Categories[cat], class)
end

-- Get NPC data
function GM_Tools.NPCRegistry:Get(class)
    return self.List[class]
end

-- Get all NPCs of a specific base type
function GM_Tools.NPCRegistry:GetByBaseType(baseType)
    local result = {}
    for class, data in pairs(self.List) do
        if data.BaseType == baseType then
            table.insert(result, data)
        end
    end
    return result
end

-- Get all categories
function GM_Tools.NPCRegistry:GetCategories()
    local cats = {}
    for cat, _ in pairs(self.Categories) do
        table.insert(cats, cat)
    end
    table.sort(cats)
    return cats
end

-- Get NPCs in a category
function GM_Tools.NPCRegistry:GetByCategory(category)
    local result = {}
    if self.Categories[category] then
        for _, class in ipairs(self.Categories[category]) do
            table.insert(result, self.List[class])
        end
    end
    return result
end

-- Network the registry to clients
if SERVER then
    util.AddNetworkString("GM_Tools_SyncRegistry")

    function GM_Tools.NPCRegistry:SyncToClient(ply)
        local data = util.TableToJSON(self.List)
        local compressed = util.Compress(data)

        net.Start("GM_Tools_SyncRegistry")
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
        net.Send(ply)
    end

    function GM_Tools.NPCRegistry:SyncToAll()
        local data = util.TableToJSON(self.List)
        local compressed = util.Compress(data)

        net.Start("GM_Tools_SyncRegistry")
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
        net.Broadcast()
    end
end

if CLIENT then
    net.Receive("GM_Tools_SyncRegistry", function()
        local len = net.ReadUInt(32)

        -- Validate data length to prevent memory issues
        if len <= 0 or len > 1048576 then -- 1MB max
            print("[Gamemaster Tools] Warning: Invalid registry sync data length")
            return
        end

        local compressed = net.ReadData(len)
        if not compressed then return end

        local data = util.Decompress(compressed)

        if data then
            local tbl = util.JSONToTable(data)
            if tbl and istable(tbl) then
                GM_Tools.NPCRegistry.List = tbl
                -- Rebuild categories
                GM_Tools.NPCRegistry.Categories = {}
                for class, npcData in pairs(tbl) do
                    if npcData and istable(npcData) and npcData.Category then
                        local cat = npcData.Category
                        GM_Tools.NPCRegistry.Categories[cat] = GM_Tools.NPCRegistry.Categories[cat] or {}
                        table.insert(GM_Tools.NPCRegistry.Categories[cat], class)
                    end
                end
                local debugCvar = GetConVar("gmt_debug")
                if debugCvar and debugCvar:GetBool() then
                    print("[Gamemaster Tools] NPC Registry synced - " .. table.Count(tbl) .. " NPCs")
                end
            end
        end
    end)
end

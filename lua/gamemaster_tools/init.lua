--[[
    Gamemaster Tools - Main Initialization
    Universal NPC Management System
    Supports: VJ Base, Droids, LVS, Default NPCs, and more

    Tools are in lua/weapons/gmod_tool/stools/
    Entities are in lua/entities/
]]

local path = GM_Tools.Path

-- Shared files
local shared = {
    "sh_config.lua",
    "sh_npc_registry.lua",
}

-- Server-only files
local server = {
    "sv_npc_detector.lua",
}

-- Load shared
for _, file in ipairs(shared) do
    AddCSLuaFile(path .. file)
    include(path .. file)
end

-- Load server files
if SERVER then
    for _, file in ipairs(server) do
        include(path .. file)
    end
    
    -- Create debug convar (default: off to reduce console spam)
    CreateConVar("gmt_debug", "0", FCVAR_ARCHIVE, "Enable debug prints for Gamemaster Tools")
    
    print("[Gamemaster Tools] Server initialized - v" .. GM_Tools.Version)
end

if CLIENT then
    print("[Gamemaster Tools] Client initialized - v" .. GM_Tools.Version)
end

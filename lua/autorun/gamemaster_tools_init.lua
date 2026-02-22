--[[
    Gamemaster Tools - Loader
    Everything is in lua/gamemaster_tools/
]]

GM_Tools = GM_Tools or {}
GM_Tools.Version = "1.0.0"
GM_Tools.Path = "gamemaster_tools/"

AddCSLuaFile()

-- Load main module
include(GM_Tools.Path .. "init.lua")
AddCSLuaFile(GM_Tools.Path .. "init.lua")

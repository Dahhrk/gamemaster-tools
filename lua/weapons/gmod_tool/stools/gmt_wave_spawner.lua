--[[
    Gamemaster Tools - Wave Spawner Tool
    Click to place spawn point, configure waves in tool panel
]]

TOOL.Category = "Gamemaster Tools"
TOOL.Name = "#tool.gmt_wave_spawner.name"

TOOL.Information = {
    { name = "left" },
    { name = "right" },
    { name = "reload" },
}

TOOL.ClientConVar = {
    -- Quick Preset
    ["preset"] = "default",
    -- Wave Settings
    ["npc_class"] = "npc_combine_s",
    ["npcs_per_wave"] = "5",
    ["wave_count"] = "10",
    ["wave_delay"] = "10",
    ["spawn_radius"] = "300",
    ["scaling"] = "1.2",
    ["max_active"] = "30",
    ["team"] = "2",
    ["weapon"] = "",
    ["auto_start"] = "0",
    -- Spawn Formation (0=Random, 1=Line, 2=V-Shape, 3=Arc, 4=Grid)
    ["spawn_formation"] = "1",
    -- Tactical Behavior (0=March&Attack, 1=Hold, 2=Patrol, 3=Rush, 4=Defensive, 5=Flank)
    ["tactical_behavior"] = "0",
    -- Spawn Mode (0=Static, 1=Fly-In, 2=Hyperspace, 3=Landing)
    ["spawn_mode"] = "0",
    ["spawn_height"] = "500",
    ["spawn_angle"] = "0",
    -- NPC Appearance Randomization
    ["randomize_skin"] = "0",
    ["randomize_bodygroups"] = "0",
    -- NPC Stats
    ["npc_health"] = "100",
    ["weapon_difficulty"] = "1",
    ["damage_multiplier"] = "1",
    -- VJ Base Settings
    ["skill_preset"] = "assault",
    ["squad_name"] = "",
    ["vj_wandering"] = "1",
    ["vj_callforhelp"] = "1",
    ["vj_godmode"] = "0",
    ["vj_grenades"] = "1",
    ["vj_passive"] = "0",
    ["vj_bleeding"] = "1",
    ["vj_become_enemy"] = "1",
    -- Additional VJ Base Settings
    ["vj_melee_attack"] = "1",
    ["vj_range_attack"] = "1",
    ["vj_leap_attack"] = "1",
    ["vj_follow_player"] = "0",
    ["vj_has_sounds"] = "1",
    ["vj_can_flinch"] = "1",
    ["vj_death_ragdoll"] = "1",
    ["vj_run_on_damage"] = "0",
    ["vj_medic"] = "0",
    ["vj_sight_distance"] = "6500",
    ["vj_hearing_distance"] = "3000",
    -- Additional VJ Base Movement Settings
    ["vj_can_dodge"] = "1",
    ["vj_use_cover"] = "1",
    ["vj_investigate"] = "1",
    ["vj_can_crouch"] = "1",
    ["vj_open_doors"] = "1",
    ["vj_push_props"] = "1",
    ["vj_move_speed"] = "1",
    -- Spawner Settings
    ["use_debug_model"] = "0",
    ["debug_model_path"] = "",           -- Model path from dropdown
    ["use_custom_model"] = "0",          -- Enable custom model override
    ["custom_model_path"] = "",          -- Custom model path (only used if enabled)
    ["spawner_health"] = "0",            -- 0 = invulnerable
    ["kill_npcs_on_death"] = "0",
}

-- Cleanup type
cleanup.Register("gmt_wave_spawners")

if SERVER then
    util.AddNetworkString("GMT_WaveUpdate")
    util.AddNetworkString("GMT_StartWaves")
    util.AddNetworkString("GMT_StopWaves")
end

function TOOL:LeftClick(trace)
    if not trace.Hit then return false end
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) then return false end

    -- Create the spawn point entity
    local spawner = ents.Create("gmt_wave_spawner")
    if not IsValid(spawner) then return false end

    spawner:SetPos(trace.HitPos + Vector(0, 0, 10))
    spawner:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    spawner:Spawn()
    spawner:Activate()

    -- Configure wave settings from tool convars
    spawner:SetNPCClass(self:GetClientInfo("npc_class"))
    spawner:SetNPCsPerWave(self:GetClientNumber("npcs_per_wave", 5))
    spawner:SetWaveCount(self:GetClientNumber("wave_count", 10))
    spawner:SetWaveDelay(self:GetClientNumber("wave_delay", 10))
    spawner:SetSpawnRadius(self:GetClientNumber("spawn_radius", 300))
    spawner:SetScaling(self:GetClientNumber("scaling", 1.2))
    spawner:SetMaxActive(self:GetClientNumber("max_active", 30))
    spawner:SetTeamID(self:GetClientNumber("team", 2))
    spawner:SetWeapon(self:GetClientInfo("weapon"))
    spawner:SetSpawnFormation(self:GetClientNumber("spawn_formation", 1))
    spawner:SetTacticalBehavior(self:GetClientNumber("tactical_behavior", 0))
    spawner:SetSpawnMode(self:GetClientNumber("spawn_mode", 0))
    spawner:SetSpawnHeight(self:GetClientNumber("spawn_height", 500))
    spawner:SetSpawnAngle(self:GetClientNumber("spawn_angle", 0))
    spawner:SetRandomizeSkin(self:GetClientNumber("randomize_skin", 0) == 1)
    spawner:SetRandomizeBodygroups(self:GetClientNumber("randomize_bodygroups", 0) == 1)

    -- Configure NPC stats
    spawner:SetNPCHealth(self:GetClientNumber("npc_health", 100))
    spawner:SetWeaponDifficulty(self:GetClientNumber("weapon_difficulty", 1))
    spawner:SetDamageMultiplier(self:GetClientNumber("damage_multiplier", 1))

    -- Configure VJ Base settings
    spawner:SetSkillPreset(self:GetClientInfo("skill_preset"))
    spawner:SetSquadName(self:GetClientInfo("squad_name"))
    spawner:SetVJWandering(self:GetClientNumber("vj_wandering", 1) == 1)
    spawner:SetVJCallForHelp(self:GetClientNumber("vj_callforhelp", 1) == 1)
    spawner:SetVJGodMode(self:GetClientNumber("vj_godmode", 0) == 1)
    spawner:SetVJGrenades(self:GetClientNumber("vj_grenades", 1) == 1)
    spawner:SetVJPassive(self:GetClientNumber("vj_passive", 0) == 1)
    spawner:SetVJBleeding(self:GetClientNumber("vj_bleeding", 1) == 1)
    spawner:SetVJBecomeEnemy(self:GetClientNumber("vj_become_enemy", 1) == 1)

    -- Configure additional VJ Base settings
    spawner:SetVJMeleeAttack(self:GetClientNumber("vj_melee_attack", 1) == 1)
    spawner:SetVJRangeAttack(self:GetClientNumber("vj_range_attack", 1) == 1)
    spawner:SetVJLeapAttack(self:GetClientNumber("vj_leap_attack", 1) == 1)
    spawner:SetVJFollowPlayer(self:GetClientNumber("vj_follow_player", 0) == 1)
    spawner:SetVJHasSounds(self:GetClientNumber("vj_has_sounds", 1) == 1)
    spawner:SetVJCanFlinch(self:GetClientNumber("vj_can_flinch", 1) == 1)
    spawner:SetVJDeathRagdoll(self:GetClientNumber("vj_death_ragdoll", 1) == 1)
    spawner:SetVJRunOnDamage(self:GetClientNumber("vj_run_on_damage", 0) == 1)
    spawner:SetVJMedic(self:GetClientNumber("vj_medic", 0) == 1)
    spawner:SetVJSightDistance(self:GetClientNumber("vj_sight_distance", 6500))
    spawner:SetVJHearingDistance(self:GetClientNumber("vj_hearing_distance", 3000))

    -- Configure additional VJ Base movement settings
    spawner:SetVJCanDodge(self:GetClientNumber("vj_can_dodge", 1) == 1)
    spawner:SetVJUseCover(self:GetClientNumber("vj_use_cover", 1) == 1)
    spawner:SetVJInvestigate(self:GetClientNumber("vj_investigate", 1) == 1)
    spawner:SetVJCanCrouch(self:GetClientNumber("vj_can_crouch", 1) == 1)
    spawner:SetVJOpenDoors(self:GetClientNumber("vj_open_doors", 1) == 1)
    spawner:SetVJPushProps(self:GetClientNumber("vj_push_props", 1) == 1)
    spawner:SetVJMoveSpeed(self:GetClientNumber("vj_move_speed", 1))

    -- Configure spawner settings (model, health)
    -- If custom model is enabled and path is set, use that; otherwise use dropdown selection
    local useCustom = self:GetClientNumber("use_custom_model", 0) == 1
    local customPath = self:GetClientInfo("custom_model_path")
    local dropdownPath = self:GetClientInfo("debug_model_path")

    if useCustom and customPath and customPath ~= "" then
        spawner:SetDebugModelPath(customPath)
    else
        spawner:SetDebugModelPath(dropdownPath)
    end

    spawner:SetUseDebugModel(self:GetClientNumber("use_debug_model", 0) == 1)
    spawner:SetSpawnerHealth(self:GetClientNumber("spawner_health", 0))
    spawner:SetKillNPCsOnDeath(self:GetClientNumber("kill_npcs_on_death", 0) == 1)

    -- Update model based on selected team/faction (or debug model)
    spawner:UpdateModelForTeam()

    -- Apply spawner health
    spawner:ApplySpawnerHealth()

    -- Begin arrival animation (will position spawner based on spawn mode)
    local targetPos = trace.HitPos + Vector(0, 0, 10)
    local targetAng = Angle(0, ply:EyeAngles().y, 0)
    spawner:BeginArrival(targetPos, targetAng)

    -- Auto-start waves after arrival completes (if enabled)
    if self:GetClientNumber("auto_start", 0) == 1 then
        -- Delay auto-start based on spawn mode
        local spawnMode = self:GetClientNumber("spawn_mode", 0)
        local delay = 0
        if spawnMode == 1 then delay = 5.5      -- Fly-In
        elseif spawnMode == 2 then delay = 4    -- Hyperspace
        elseif spawnMode == 3 then delay = 4.5  -- Landing
        end

        if delay > 0 then
            timer.Simple(delay, function()
                if IsValid(spawner) then
                    spawner:StartWaves()
                end
            end)
        else
            spawner:StartWaves()
        end
    end

    spawner:SetPlayer(ply)
    ply:AddCleanup("gmt_wave_spawners", spawner)

    undo.Create("Wave Spawner")
        undo.AddEntity(spawner)
        undo.SetPlayer(ply)
    undo.Finish()

    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end

    local ent = trace.Entity
    if IsValid(ent) and ent:GetClass() == "gmt_wave_spawner" then
        -- Toggle waves on/off (pause/resume behavior)
        if ent:GetActive() then
            ent:StopWaves()
            -- Message handled by entity
        else
            ent:StartWaves()
            -- Message handled by entity
        end
        return true
    end

    return false
end

function TOOL:Reload(trace)
    if CLIENT then return true end

    local ent = trace.Entity
    if IsValid(ent) and ent:GetClass() == "gmt_wave_spawner" then
        -- Update wave settings from current convars
        ent:SetNPCClass(self:GetClientInfo("npc_class"))
        ent:SetNPCsPerWave(self:GetClientNumber("npcs_per_wave", 5))
        ent:SetWaveCount(self:GetClientNumber("wave_count", 10))
        ent:SetWaveDelay(self:GetClientNumber("wave_delay", 10))
        ent:SetSpawnRadius(self:GetClientNumber("spawn_radius", 300))
        ent:SetScaling(self:GetClientNumber("scaling", 1.2))
        ent:SetMaxActive(self:GetClientNumber("max_active", 30))
        ent:SetTeamID(self:GetClientNumber("team", 2))
        ent:SetWeapon(self:GetClientInfo("weapon"))
        ent:SetSpawnFormation(self:GetClientNumber("spawn_formation", 1))
        ent:SetTacticalBehavior(self:GetClientNumber("tactical_behavior", 0))
        ent:SetSpawnMode(self:GetClientNumber("spawn_mode", 0))
        ent:SetSpawnHeight(self:GetClientNumber("spawn_height", 500))
        ent:SetSpawnAngle(self:GetClientNumber("spawn_angle", 0))
        ent:SetRandomizeSkin(self:GetClientNumber("randomize_skin", 0) == 1)
        ent:SetRandomizeBodygroups(self:GetClientNumber("randomize_bodygroups", 0) == 1)

        -- Update NPC stats
        ent:SetNPCHealth(self:GetClientNumber("npc_health", 100))
        ent:SetWeaponDifficulty(self:GetClientNumber("weapon_difficulty", 1))
        ent:SetDamageMultiplier(self:GetClientNumber("damage_multiplier", 1))

        -- Update VJ Base settings
        ent:SetSkillPreset(self:GetClientInfo("skill_preset"))
        ent:SetSquadName(self:GetClientInfo("squad_name"))
        ent:SetVJWandering(self:GetClientNumber("vj_wandering", 1) == 1)
        ent:SetVJCallForHelp(self:GetClientNumber("vj_callforhelp", 1) == 1)
        ent:SetVJGodMode(self:GetClientNumber("vj_godmode", 0) == 1)
        ent:SetVJGrenades(self:GetClientNumber("vj_grenades", 1) == 1)
        ent:SetVJPassive(self:GetClientNumber("vj_passive", 0) == 1)
        ent:SetVJBleeding(self:GetClientNumber("vj_bleeding", 1) == 1)
        ent:SetVJBecomeEnemy(self:GetClientNumber("vj_become_enemy", 1) == 1)

        -- Update additional VJ Base settings
        ent:SetVJMeleeAttack(self:GetClientNumber("vj_melee_attack", 1) == 1)
        ent:SetVJRangeAttack(self:GetClientNumber("vj_range_attack", 1) == 1)
        ent:SetVJLeapAttack(self:GetClientNumber("vj_leap_attack", 1) == 1)
        ent:SetVJFollowPlayer(self:GetClientNumber("vj_follow_player", 0) == 1)
        ent:SetVJHasSounds(self:GetClientNumber("vj_has_sounds", 1) == 1)
        ent:SetVJCanFlinch(self:GetClientNumber("vj_can_flinch", 1) == 1)
        ent:SetVJDeathRagdoll(self:GetClientNumber("vj_death_ragdoll", 1) == 1)
        ent:SetVJRunOnDamage(self:GetClientNumber("vj_run_on_damage", 0) == 1)
        ent:SetVJMedic(self:GetClientNumber("vj_medic", 0) == 1)
        ent:SetVJSightDistance(self:GetClientNumber("vj_sight_distance", 6500))
        ent:SetVJHearingDistance(self:GetClientNumber("vj_hearing_distance", 3000))

        -- Update additional VJ Base movement settings
        ent:SetVJCanDodge(self:GetClientNumber("vj_can_dodge", 1) == 1)
        ent:SetVJUseCover(self:GetClientNumber("vj_use_cover", 1) == 1)
        ent:SetVJInvestigate(self:GetClientNumber("vj_investigate", 1) == 1)
        ent:SetVJCanCrouch(self:GetClientNumber("vj_can_crouch", 1) == 1)
        ent:SetVJOpenDoors(self:GetClientNumber("vj_open_doors", 1) == 1)
        ent:SetVJPushProps(self:GetClientNumber("vj_push_props", 1) == 1)
        ent:SetVJMoveSpeed(self:GetClientNumber("vj_move_speed", 1))

        -- Update spawner settings (model, health)
        local useCustom = self:GetClientNumber("use_custom_model", 0) == 1
        local customPath = self:GetClientInfo("custom_model_path")
        local dropdownPath = self:GetClientInfo("debug_model_path")

        if useCustom and customPath and customPath ~= "" then
            ent:SetDebugModelPath(customPath)
        else
            ent:SetDebugModelPath(dropdownPath)
        end

        ent:SetUseDebugModel(self:GetClientNumber("use_debug_model", 0) == 1)
        ent:SetSpawnerHealth(self:GetClientNumber("spawner_health", 0))
        ent:SetKillNPCsOnDeath(self:GetClientNumber("kill_npcs_on_death", 0) == 1)

        -- Update model based on selected team/faction (or debug model)
        ent:UpdateModelForTeam()

        -- Apply spawner health
        ent:ApplySpawnerHealth()

        -- If waves have been started before, offer to restart
        local currentWave = ent:GetCurrentWave()
        if currentWave > 0 or ent:GetActive() then
            -- Stop current waves and restart from wave 1
            ent:RestartWaves()
            self:GetOwner():ChatPrint("[GMT] Spawner settings updated & waves restarted")
        else
            self:GetOwner():ChatPrint("[GMT] Spawner settings updated")
        end
        return true
    end

    return false
end

-- Helper function to format class names nicely (npc_combine_s -> Combine S)
local function FormatClassName(class)
    if not class then return "Unknown" end
    -- Remove common prefixes
    local name = class:gsub("^npc_", ""):gsub("^weapon_", ""):gsub("^item_", "")
    -- Replace underscores with spaces and capitalize each word
    name = name:gsub("_", " ")
    name = name:gsub("(%a)([%w]*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return name
end

function TOOL.BuildCPanel(panel)
    -- Store references to controls for updating
    local controls = {}

    -- Helper to create collapsible category
    local function CreateCategory(name, expanded)
        local cat = vgui.Create("DCollapsibleCategory", panel)
        cat:SetLabel(name)
        cat:SetExpanded(expanded ~= false)

        local content = vgui.Create("DPanelList")
        content:SetAutoSize(true)
        content:SetSpacing(4)
        content:SetPadding(8)
        content:EnableHorizontal(false)
        content:EnableVerticalScrollbar(false)

        cat:SetContents(content)
        panel:AddItem(cat)

        return content
    end

    -- Helper to add slider
    local function AddSlider(parent, label, convar, min, max, decimals, controlKey)
        local slider = vgui.Create("DNumSlider")
        slider:SetText(label)
        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetDecimals(decimals)
        slider:SetConVar(convar)
        slider.Label:SetTextColor(Color(0, 0, 0))
        parent:AddItem(slider)
        if controlKey then
            controls[controlKey] = slider
        end
        return slider
    end

    -- Helper to add checkbox
    local function AddCheckbox(parent, label, convar, controlKey)
        local cb = vgui.Create("DCheckBoxLabel")
        cb:SetText(label)
        cb:SetConVar(convar)
        cb:SetTextColor(Color(0, 0, 0))
        cb:SizeToContents()
        parent:AddItem(cb)
        if controlKey then
            controls[controlKey] = cb
        end
        return cb
    end

    -- Helper to add combobox
    local function AddCombo(parent, label, options, onSelect, controlKey)
        local lbl = vgui.Create("DLabel")
        lbl:SetText(label)
        lbl:SetTextColor(Color(0, 0, 0))
        lbl:SizeToContents()
        parent:AddItem(lbl)

        local combo = vgui.Create("DComboBox")
        combo:SetSortItems(false)
        for name, data in pairs(options) do
            combo:AddChoice(name, data)
        end
        if onSelect then
            combo.OnSelect = onSelect
        end
        parent:AddItem(combo)
        if controlKey then
            controls[controlKey] = combo
        end
        return combo
    end

    -- Helper to select combo by value
    local function SelectComboByValue(combo, value)
        if not IsValid(combo) then return end
        for i, item in pairs(combo.Choices or {}) do
            if combo:GetOptionData(i) == value then
                combo:ChooseOptionID(i)
                return
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════
    -- NPC SELECTION
    -- ═══════════════════════════════════════════════════════════════
    local npcCat = CreateCategory("NPC Selection", true)

    local npcOptions = {}
    for class, data in pairs(list.Get("NPC") or {}) do
        local displayName = data.Name or FormatClassName(class)
        npcOptions[displayName] = class
    end
    AddCombo(npcCat, "NPC Class", npcOptions, function(_, _, _, class)
        RunConsoleCommand("gmt_wave_spawner_npc_class", class)
    end)

    local weaponOptions = { ["None"] = "" }
    for _, wepData in pairs(list.Get("NPCUsableWeapons") or {}) do
        if wepData.class then
            local displayName = wepData.title or FormatClassName(wepData.class)
            weaponOptions[displayName] = wepData.class
        end
    end
    AddCombo(npcCat, "Weapon", weaponOptions, function(_, _, _, class)
        RunConsoleCommand("gmt_wave_spawner_weapon", class)
    end)

    -- Faction selector (will be enhanced below after other controls are created)
    local teamOptions = {}
    if GM_Tools and GM_Tools.Config and GM_Tools.Config.Teams then
        for id, data in SortedPairs(GM_Tools.Config.Teams) do
            teamOptions[data.name or ("Team " .. id)] = tostring(id)
        end
    else
        teamOptions = {
            ["GAR"] = "1",
            ["CIS"] = "2",
            ["Neutral"] = "3",
            ["Mandalorian"] = "4",
            ["Custom"] = "5",
        }
    end
    local factionCombo = AddCombo(npcCat, "Faction", teamOptions, nil, "faction")

    -- ═══════════════════════════════════════════════════════════════
    -- WAVE SETTINGS
    -- ═══════════════════════════════════════════════════════════════
    local waveCat = CreateCategory("Wave Settings", true)

    AddSlider(waveCat, "NPCs Per Wave", "gmt_wave_spawner_npcs_per_wave", 1, 50, 0)
    AddSlider(waveCat, "Number Of Waves", "gmt_wave_spawner_wave_count", 1, 100, 0)
    AddSlider(waveCat, "Wave Delay (Seconds)", "gmt_wave_spawner_wave_delay", 1, 120, 0)
    AddSlider(waveCat, "Scaling Per Wave", "gmt_wave_spawner_scaling", 1, 3, 2)

    -- ═══════════════════════════════════════════════════════════════
    -- SPAWN SETTINGS
    -- ═══════════════════════════════════════════════════════════════
    local spawnCat = CreateCategory("Spawn Settings", true)

    -- Formation selector
    local formationOptions = {
        ["Random"] = "0",
        ["Line (March)"] = "1",
        ["V-Shape (Wedge)"] = "2",
        ["Arc (Semi-Circle)"] = "3",
        ["Grid"] = "4",
    }
    AddCombo(spawnCat, "Spawn Formation", formationOptions, function(_, _, _, val)
        RunConsoleCommand("gmt_wave_spawner_spawn_formation", val)
    end)

    -- Tactical behavior selector - simplified to basics that work with VJ Base AI
    local tacticOptions = {
        ["Aggressive"] = "0",      -- Chase enemies, VJ Base handles movement
        ["Hold Position"] = "1",   -- Stay near spawn, engage nearby enemies
        ["Patrol"] = "2",          -- Wander around spawn area
    }
    local tacticCombo = AddCombo(spawnCat, "NPC Behavior", tacticOptions, function(_, _, _, val)
        RunConsoleCommand("gmt_wave_spawner_tactical_behavior", val)
    end, "tactical")

    AddSlider(spawnCat, "Spawn Radius", "gmt_wave_spawner_spawn_radius", 50, 2000, 0)
    AddSlider(spawnCat, "Max Active NPCs", "gmt_wave_spawner_max_active", 1, 100, 0)
    AddCheckbox(spawnCat, "Auto-Start On Place", "gmt_wave_spawner_auto_start")

    -- ═══════════════════════════════════════════════════════════════
    -- SHIP ARRIVAL
    -- ═══════════════════════════════════════════════════════════════
    local arrivalCat = CreateCategory("Ship Arrival", false)

    -- Spawn Mode
    local spawnModeOptions = {
        ["Static (Instant)"] = "0",
        ["Fly-In (Approach)"] = "1",
        ["Hyperspace (Jump In)"] = "2",
        ["Landing (Descend)"] = "3",
    }
    AddCombo(arrivalCat, "Arrival Mode", spawnModeOptions, function(_, _, _, val)
        RunConsoleCommand("gmt_wave_spawner_spawn_mode", val)
    end)

    AddSlider(arrivalCat, "Spawn Height", "gmt_wave_spawner_spawn_height", 0, 2000, 0)
    AddSlider(arrivalCat, "Approach Angle", "gmt_wave_spawner_spawn_angle", 0, 360, 0)

    -- ═══════════════════════════════════════════════════════════════
    -- NPC APPEARANCE RANDOMIZATION
    -- ═══════════════════════════════════════════════════════════════
    local randomCat = CreateCategory("NPC Appearance", false)

    AddCheckbox(randomCat, "Randomize Skin", "gmt_wave_spawner_randomize_skin")
    AddCheckbox(randomCat, "Randomize Bodygroups", "gmt_wave_spawner_randomize_bodygroups")

    -- ═══════════════════════════════════════════════════════════════
    -- SPAWNER APPEARANCE
    -- ═══════════════════════════════════════════════════════════════
    local appearCat = CreateCategory("Spawner Appearance", true)

    -- Simple model dropdown from config
    local modelLbl = vgui.Create("DLabel")
    modelLbl:SetText("Spawner Model")
    modelLbl:SetTextColor(Color(0, 0, 0))
    modelLbl:SizeToContents()
    appearCat:AddItem(modelLbl)

    local modelCombo = vgui.Create("DComboBox")
    modelCombo:SetSortItems(false)

    -- Add models from config
    if GM_Tools and GM_Tools.Config and GM_Tools.Config.Teams then
        for teamID, teamData in SortedPairs(GM_Tools.Config.Teams) do
            if teamData.models then
                for _, model in ipairs(teamData.models) do
                    local name = string.match(model, "([^/]+)%.mdl$") or model
                    modelCombo:AddChoice(teamData.name .. ": " .. name, model)
                end
            end
            -- Also add default model for team
            if teamData.defaultModel then
                local name = string.match(teamData.defaultModel, "([^/]+)%.mdl$") or teamData.defaultModel
                modelCombo:AddChoice(teamData.name .. " Default: " .. name, teamData.defaultModel)
            end
        end
    end

    -- Add fallback model
    modelCombo:AddChoice("Fallback: Combine Mine", "models/props_combine/combine_mine01.mdl")
    modelCombo:AddChoice("Debug: Oil Drum", "models/props_c17/oildrum001.mdl")

    modelCombo.OnSelect = function(_, _, _, modelPath)
        RunConsoleCommand("gmt_wave_spawner_debug_model_path", modelPath)
        -- Disable custom model when selecting from dropdown
        RunConsoleCommand("gmt_wave_spawner_use_custom_model", "0")
    end
    appearCat:AddItem(modelCombo)

    -- Custom model section
    local customLbl = vgui.Create("DLabel")
    customLbl:SetText("--- OR Use Custom Model ---")
    customLbl:SetTextColor(Color(150, 170, 200))
    customLbl:SizeToContents()
    appearCat:AddItem(customLbl)

    -- Enable custom model checkbox
    local customCheck = vgui.Create("DCheckBoxLabel")
    customCheck:SetText("Enable Custom Model")
    customCheck:SetConVar("gmt_wave_spawner_use_custom_model")
    customCheck:SetTextColor(Color(0, 0, 0))
    customCheck:SizeToContents()
    appearCat:AddItem(customCheck)

    -- Custom model path entry
    local customEntry = vgui.Create("DTextEntry")
    customEntry:SetConVar("gmt_wave_spawner_custom_model_path")
    customEntry:SetPlaceholderText("models/your/custom/model.mdl")
    appearCat:AddItem(customEntry)

    -- ═══════════════════════════════════════════════════════════════
    -- NPC STATS
    -- ═══════════════════════════════════════════════════════════════
    local statsCat = CreateCategory("NPC Stats", false)

    AddSlider(statsCat, "Health", "gmt_wave_spawner_npc_health", 1, 100000, 0, "health")
    AddSlider(statsCat, "Damage Multiplier", "gmt_wave_spawner_damage_multiplier", 0, 25, 1, "damage_mult")

    local diffOptions = {
        ["Poor"] = "0",
        ["Average"] = "1",
        ["Good"] = "2",
        ["Very Good"] = "3",
        ["Perfect"] = "4",
    }
    AddCombo(statsCat, "Weapon Difficulty", diffOptions, function(_, _, _, val)
        RunConsoleCommand("gmt_wave_spawner_weapon_difficulty", val)
    end, "weapon_diff")

    -- ═══════════════════════════════════════════════════════════════
    -- VJ BASE SETTINGS
    -- ═══════════════════════════════════════════════════════════════
    local vjCat = CreateCategory("VJ Base Settings", false)

    local skillOptions = {
        ["Assault"] = "assault",
        ["Sniper"] = "sniper",
        ["Grenadier"] = "grenadier",
        ["Lightsaber"] = "lightsaber",
        ["Elite"] = "elite",
    }
    AddCombo(vjCat, "Skill Preset", skillOptions, function(_, _, _, val)
        RunConsoleCommand("gmt_wave_spawner_skill_preset", val)
    end, "skill_preset")

    local squadLbl = vgui.Create("DLabel")
    squadLbl:SetText("Squad Name")
    squadLbl:SetTextColor(Color(0, 0, 0))
    squadLbl:SizeToContents()
    vjCat:AddItem(squadLbl)

    local squadEntry = vgui.Create("DTextEntry")
    squadEntry:SetConVar("gmt_wave_spawner_squad_name")
    vjCat:AddItem(squadEntry)

    AddCheckbox(vjCat, "Wandering", "gmt_wave_spawner_vj_wandering", "vj_wandering")
    AddCheckbox(vjCat, "Call For Help", "gmt_wave_spawner_vj_callforhelp", "vj_callforhelp")
    AddCheckbox(vjCat, "Grenade Attacks", "gmt_wave_spawner_vj_grenades", "vj_grenades")
    AddCheckbox(vjCat, "God Mode", "gmt_wave_spawner_vj_godmode", "vj_godmode")
    AddCheckbox(vjCat, "Spawn Passive", "gmt_wave_spawner_vj_passive", "vj_passive")
    AddCheckbox(vjCat, "Bleeding", "gmt_wave_spawner_vj_bleeding", "vj_bleeding")
    AddCheckbox(vjCat, "Become Enemy On Death", "gmt_wave_spawner_vj_become_enemy", "vj_become_enemy")

    -- ═══════════════════════════════════════════════════════════════
    -- ADDITIONAL VJ BASE SETTINGS
    -- ═══════════════════════════════════════════════════════════════
    local vjAdvCat = CreateCategory("VJ Base - Combat & Attacks", false)

    AddCheckbox(vjAdvCat, "Melee Attacks", "gmt_wave_spawner_vj_melee_attack", "vj_melee_attack")
    AddCheckbox(vjAdvCat, "Ranged Attacks (Projectiles)", "gmt_wave_spawner_vj_range_attack", "vj_range_attack")
    AddCheckbox(vjAdvCat, "Leap Attacks", "gmt_wave_spawner_vj_leap_attack", "vj_leap_attack")
    AddCheckbox(vjAdvCat, "Can Flinch", "gmt_wave_spawner_vj_can_flinch", "vj_can_flinch")
    AddCheckbox(vjAdvCat, "Run Away on Unknown Damage", "gmt_wave_spawner_vj_run_on_damage", "vj_run_on_damage")

    local vjBehaviorCat = CreateCategory("VJ Base - Behavior & Sounds", false)

    AddCheckbox(vjBehaviorCat, "NPC Sounds", "gmt_wave_spawner_vj_has_sounds", "vj_has_sounds")
    AddCheckbox(vjBehaviorCat, "Death Ragdoll", "gmt_wave_spawner_vj_death_ragdoll", "vj_death_ragdoll")
    AddCheckbox(vjBehaviorCat, "Follow Spawner Owner", "gmt_wave_spawner_vj_follow_player", "vj_follow_player")
    AddCheckbox(vjBehaviorCat, "Medic Behavior (Heal Allies)", "gmt_wave_spawner_vj_medic", "vj_medic")

    AddSlider(vjBehaviorCat, "Sight Distance", "gmt_wave_spawner_vj_sight_distance", 500, 15000, 0, "vj_sight_distance")
    AddSlider(vjBehaviorCat, "Hearing Distance", "gmt_wave_spawner_vj_hearing_distance", 500, 10000, 0, "vj_hearing_distance")

    -- ═══════════════════════════════════════════════════════════════
    -- VJ BASE MOVEMENT SETTINGS
    -- ═══════════════════════════════════════════════════════════════
    local vjMoveCat = CreateCategory("VJ Base - Movement", false)

    AddCheckbox(vjMoveCat, "Can Dodge Attacks", "gmt_wave_spawner_vj_can_dodge", "vj_can_dodge")
    AddCheckbox(vjMoveCat, "Use Cover", "gmt_wave_spawner_vj_use_cover", "vj_use_cover")
    AddCheckbox(vjMoveCat, "Investigate Sounds", "gmt_wave_spawner_vj_investigate", "vj_investigate")
    AddCheckbox(vjMoveCat, "Can Crouch", "gmt_wave_spawner_vj_can_crouch", "vj_can_crouch")
    AddCheckbox(vjMoveCat, "Can Open Doors", "gmt_wave_spawner_vj_open_doors", "vj_open_doors")
    AddCheckbox(vjMoveCat, "Push Props Out of Way", "gmt_wave_spawner_vj_push_props", "vj_push_props")

    AddSlider(vjMoveCat, "Movement Speed Multiplier", "gmt_wave_spawner_vj_move_speed", 0.1, 3, 2, "vj_move_speed")

    -- ═══════════════════════════════════════════════════════════════
    -- SPAWNER SETTINGS (health, destructible)
    -- ═══════════════════════════════════════════════════════════════
    local spawnerCat = CreateCategory("Spawner Settings", false)

    AddSlider(spawnerCat, "Spawner Health (0 = Invulnerable)", "gmt_wave_spawner_spawner_health", 0, 10000, 0, "spawner_health")
    AddCheckbox(spawnerCat, "Kill NPCs When Destroyed", "gmt_wave_spawner_kill_npcs_on_death", "kill_npcs_on_death")

    -- Help text
    local helpLbl = vgui.Create("DLabel")
    helpLbl:SetText("When health > 0, the spawner can be destroyed.\nThis creates objectives for players to attack!")
    helpLbl:SetTextColor(Color(150, 170, 200))
    helpLbl:SetWrap(true)
    helpLbl:SetAutoStretchVertical(true)
    spawnerCat:AddItem(helpLbl)

    -- ═══════════════════════════════════════════════════════════════
    -- QUICK PRESET (at bottom so it can reference all controls)
    -- ═══════════════════════════════════════════════════════════════
    local presetCat = CreateCategory("Quick Presets", true)

    local presetOptions = {}
    if GM_Tools and GM_Tools.Config and GM_Tools.Config.Presets then
        for id, preset in pairs(GM_Tools.Config.Presets) do
            presetOptions[preset.name] = id
        end
    else
        presetOptions = {
            ["Default"] = "default",
            ["Weak"] = "weak",
            ["Elite"] = "elite",
            ["Boss"] = "boss",
        }
    end

    local presetCombo = AddCombo(presetCat, "Apply Preset", presetOptions, function(_, _, value, presetID)
        local preset
        if GM_Tools and GM_Tools.Config and GM_Tools.Config.Presets then
            preset = GM_Tools.Config.Presets[presetID]
        end
        if not preset then return end

        -- Apply NPC Stats (console commands)
        RunConsoleCommand("gmt_wave_spawner_npc_health", tostring(preset.health or 100))
        RunConsoleCommand("gmt_wave_spawner_damage_multiplier", tostring(preset.damage_multiplier or 1))
        RunConsoleCommand("gmt_wave_spawner_weapon_difficulty", tostring(preset.weapon_difficulty or 1))
        RunConsoleCommand("gmt_wave_spawner_skill_preset", preset.skill_preset or "assault")

        -- Apply VJ Base Settings (console commands)
        RunConsoleCommand("gmt_wave_spawner_vj_wandering", preset.wandering and "1" or "0")
        RunConsoleCommand("gmt_wave_spawner_vj_callforhelp", preset.call_for_help and "1" or "0")
        RunConsoleCommand("gmt_wave_spawner_vj_godmode", preset.godmode and "1" or "0")
        RunConsoleCommand("gmt_wave_spawner_vj_grenades", preset.grenades and "1" or "0")
        RunConsoleCommand("gmt_wave_spawner_vj_passive", preset.passive and "1" or "0")
        RunConsoleCommand("gmt_wave_spawner_vj_bleeding", preset.bleeding and "1" or "0")
        RunConsoleCommand("gmt_wave_spawner_vj_become_enemy", preset.become_enemy and "1" or "0")

        -- Determine tactical behavior based on preset type
        local tacticVal = "0"  -- Default: March & Attack
        if presetID == "passive" then
            tacticVal = "2"  -- Patrol
        elseif presetID == "sniper" then
            tacticVal = "4"  -- Defensive
        elseif presetID == "melee" then
            tacticVal = "3"  -- Rush
        elseif presetID == "elite" then
            tacticVal = "5"  -- Flank
        elseif presetID == "grenadier" then
            tacticVal = "6"  -- Suppression Fire
        end
        RunConsoleCommand("gmt_wave_spawner_tactical_behavior", tacticVal)

        -- Update UI controls visually (deferred to allow convars to update)
        timer.Simple(0.05, function()
            -- Update sliders
            if IsValid(controls.health) then
                controls.health:SetValue(preset.health or 100)
            end
            if IsValid(controls.damage_mult) then
                controls.damage_mult:SetValue(preset.damage_multiplier or 1)
            end

            -- Update weapon difficulty combo
            if IsValid(controls.weapon_diff) then
                SelectComboByValue(controls.weapon_diff, tostring(preset.weapon_difficulty or 1))
            end

            -- Update skill preset combo
            if IsValid(controls.skill_preset) then
                SelectComboByValue(controls.skill_preset, preset.skill_preset or "assault")
            end

            -- Update tactical behavior combo
            if IsValid(controls.tactical) then
                SelectComboByValue(controls.tactical, tacticVal)
            end

            -- Update VJ checkboxes
            if IsValid(controls.vj_wandering) then
                controls.vj_wandering:SetChecked(preset.wandering == true)
            end
            if IsValid(controls.vj_callforhelp) then
                controls.vj_callforhelp:SetChecked(preset.call_for_help == true)
            end
            if IsValid(controls.vj_godmode) then
                controls.vj_godmode:SetChecked(preset.godmode == true)
            end
            if IsValid(controls.vj_grenades) then
                controls.vj_grenades:SetChecked(preset.grenades == true)
            end
            if IsValid(controls.vj_passive) then
                controls.vj_passive:SetChecked(preset.passive == true)
            end
            if IsValid(controls.vj_bleeding) then
                controls.vj_bleeding:SetChecked(preset.bleeding == true)
            end
            if IsValid(controls.vj_become_enemy) then
                controls.vj_become_enemy:SetChecked(preset.become_enemy == true)
            end
        end)

        -- Show preset details in chat
        local healthStr = tostring(preset.health or 100)
        local dmgStr = tostring(preset.damage_multiplier or 1) .. "x"
        local passiveStr = preset.passive and " (Passive)" or ""
        chat.AddText(
            Color(100, 200, 100), "[GMT] ",
            Color(255, 255, 255), "Applied preset: ",
            Color(255, 200, 100), preset.name,
            Color(150, 150, 150), " - HP: " .. healthStr .. ", DMG: " .. dmgStr .. passiveStr
        )
    end, "preset")

    -- ═══════════════════════════════════════════════════════════════
    -- SET UP FACTION SELECTOR HANDLER (now that controls exist)
    -- ═══════════════════════════════════════════════════════════════
    if IsValid(factionCombo) then
        factionCombo.OnSelect = function(_, _, name, id)
            RunConsoleCommand("gmt_wave_spawner_team", id)

            -- Apply faction-specific defaults
            local teamID = tonumber(id) or 2
            local tacticVal = "0"
            local passiveVal = "0"
            local msg = ""
            local msgColor = Color(255, 255, 255)

            if teamID == 1 then
                -- GAR (Republic) - Friendly to players, patrol/defensive
                passiveVal = "1"
                tacticVal = "2"  -- Patrol
                msg = "GAR selected - Set to Patrol, Player-Friendly"
                msgColor = Color(100, 150, 255)

            elseif teamID == 2 then
                -- CIS (Droids) - Hostile, march and attack
                passiveVal = "0"
                tacticVal = "0"  -- March & Attack
                msg = "CIS selected - Set to March & Attack, Hostile"
                msgColor = Color(150, 150, 150)

            elseif teamID == 3 then
                -- Neutral - Won't attack unless provoked
                passiveVal = "1"
                tacticVal = "2"  -- Patrol
                msg = "Neutral selected - Set to Patrol, Passive"
                msgColor = Color(255, 255, 100)

            elseif teamID == 4 then
                -- Mandalorian - Aggressive flanking tactics
                passiveVal = "0"
                tacticVal = "5"  -- Flank
                msg = "Mandalorian selected - Set to Flank, Hostile"
                msgColor = Color(100, 255, 255)
            end

            -- Apply console commands
            RunConsoleCommand("gmt_wave_spawner_vj_passive", passiveVal)
            RunConsoleCommand("gmt_wave_spawner_tactical_behavior", tacticVal)

            -- Update UI controls visually
            timer.Simple(0.05, function()
                if IsValid(controls.vj_passive) then
                    controls.vj_passive:SetChecked(passiveVal == "1")
                end
                if IsValid(controls.tactical) then
                    SelectComboByValue(controls.tactical, tacticVal)
                end
            end)

            if msg ~= "" then
                chat.AddText(msgColor, "[GMT] " .. msg)
            end
        end
    end
end

-- Language strings
if CLIENT then
    language.Add("tool.gmt_wave_spawner.name", "Wave Spawner")
    language.Add("tool.gmt_wave_spawner.desc", "Place wave spawn points for NPCs")
    language.Add("tool.gmt_wave_spawner.left", "Place spawn point")
    language.Add("tool.gmt_wave_spawner.right", "Start/Stop waves")
    language.Add("tool.gmt_wave_spawner.reload", "Update spawner settings")
end

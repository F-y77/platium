local MakePlayerCharacter = require "prefabs/player_common"

local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
}

-- 角色属性
TUNING.ESCTEMPLATE_HEALTH = 90  -- 较低的生命值
TUNING.ESCTEMPLATE_HUNGER = 180  -- 能吃
TUNING.ESCTEMPLATE_SANITY = 250  -- 三位一体的精神

-- 自定义起始物品
TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.ESCTEMPLATE = {
    "spear",     -- 给予一把矛作为起始武器
    "armorwood", -- 给予一件木甲
}

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.ESCTEMPLATE
end
local prefabs = FlattenTree(start_inv, true)

-- 当角色从鬼魂状态复活
local function onbecamehuman(inst)
    -- 设置非鬼魂状态下的速度
    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "esctemplate_speed_mod", 1.15)
end

local function onbecameghost(inst)
    -- 移除速度修饰符
    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "esctemplate_speed_mod")
end

-- 加载或生成角色时
local function onload(inst)
    inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)
    inst:ListenForEvent("ms_becameghost", onbecameghost)

    if inst:HasTag("playerghost") then
        onbecameghost(inst)
    else
        onbecamehuman(inst)
    end
end

-- 能量护盾功能
local function OnAttacked(inst, data)
    if not inst.components.health:IsDead() and not inst.sg:HasStateTag("attack") then
        -- 有25%几率完全抵消伤害
        if math.random() < 0.25 then
            if data.damage then
                data.damage = 0
            end
            -- 播放护盾效果
            inst.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour")
            local fx = SpawnPrefab("sparks")
            if fx then
                fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            end
        end
    end
end

-- 初始化客户端和服务器共有的部分
local common_postinit = function(inst) 
    -- 小地图图标
    inst.MiniMapEntity:SetIcon("esctemplate.tex")
    
    -- 添加机器人标签
    inst:AddTag("robot")
    inst:AddTag("battlemachine")
end

-- 仅在服务器上初始化的部分
local master_postinit = function(inst)
    -- 设置起始物品
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default
    
    -- 选择角色使用的声音
    inst.soundsname = "willow"
    
    -- 属性设置
    inst.components.health:SetMaxHealth(TUNING.ESCTEMPLATE_HEALTH)
    inst.components.hunger:SetMax(TUNING.ESCTEMPLATE_HUNGER)
    inst.components.sanity:SetMax(TUNING.ESCTEMPLATE_SANITY)
    
    -- 伤害倍率
    inst.components.combat.damagemultiplier = 1.25 --超高的伤害倍率
    
    -- 饥饿速率
    inst.components.hunger.hungerrate = 1.2 * TUNING.WILSON_HUNGER_RATE --超快的饥饿速率
    
    -- 移动速度提升
    inst.components.locomotor.walkspeed = TUNING.WILSON_WALK_SPEED * 1.25 --超快的移动速度
    inst.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED * 1.25
    
    -- 添加护盾效果
    inst:ListenForEvent("attacked", OnAttacked)
    
    -- 机器人特性：不受食物腐烂影响
    inst.components.eater:SetIgnoresSpoilage(true)

    inst.OnLoad = onload
    inst.OnNewSpawn = onload
end

return MakePlayerCharacter("esctemplate", prefabs, assets, common_postinit, master_postinit, prefabs)

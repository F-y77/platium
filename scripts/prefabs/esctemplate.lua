local MakePlayerCharacter = require "prefabs/player_common"

-- 添加这一行来获取全局变量
local GLOBAL = _G

local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
}

-- 角色属性
TUNING.ESCTEMPLATE_HEALTH = 90  -- 较低的生命值
TUNING.ESCTEMPLATE_HUNGER = 180  -- 能吃
TUNING.ESCTEMPLATE_SANITY = 250  -- 三位一体的精神

-- 自定义起始物品
TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.ESCTEMPLATE = {
    "icestaff",     
    "firestaff", 
    "staff_lunarplant",
    "amulet",
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

-- 添加白金的被动效果
local function AddPassiveEffects(inst)
    if not inst or not inst:IsValid() then return end
    
    -- 确保组件存在
    if not inst.components.locomotor then return end
    
    -- 1. 制作速度加快50%
    if inst.components.builder then
        inst.components.builder.buildingmultiplier = 0.5  -- 制作时间减少50%
    end
    
    -- 2. 雇佣时间延长
    inst:ListenForEvent("hirebyfood", function(inst, data)
        local target = data.target
        if target and target.components.follower then
            -- 获取原始跟随时间
            local original_time = target.components.follower.targettime - GetTime()
            -- 延长50%的时间
            local bonus_time = original_time * 0.5
            target.components.follower:AddLoyaltyTime(bonus_time)
            
            -- 显示效果提示
            if inst.components.talker then
                inst.components.talker:Say("你会跟随我更久~")
            end
            
            -- 添加特效
            local fx = SpawnPrefab("heart")
            if fx then
                fx.Transform:SetPosition(target.Transform:GetWorldPosition())
                fx.Transform:SetScale(1.5, 1.5, 1.5)
            end
        end
    end)
    
    -- 3. 特殊合成能力 - 更便宜的生命护符
    if inst.components.builder then
        -- 添加特殊配方
        local amulet_recipe = Recipe("amulet", 
            {
                Ingredient("redgem", 1),    -- 只需要1个红宝石(原版需要2个)
                Ingredient("goldnugget", 2)  -- 只需要2个金块(原版需要3个)
            }, 
            RECIPETABS.MAGIC, 
            TECH.MAGIC_ONE,
            nil, nil, nil, nil, "platinum_builder")
            
        -- 只对白金角色可用
        amulet_recipe.builder_tag = "platinum_builder"
        
        -- 添加特殊标签
        inst:AddTag("platinum_builder")
    end
    
    -- 4. 夜视能力 - 夜晚视野略微增强
    if inst.components.playervision then
        inst.components.playervision:ForceNightVision(true)
        inst.components.playervision:SetCustomCCTable({
            day = nil,
            dusk = nil,
            night = {brightness = 0, contrast = 0.8, saturation = 0.7, tint = {r=0.8, g=0.8, b=1}},
            full_moon = nil,
        })
    end
    
    -- 5. 魔法亲和力 - 魔法装备耐久消耗减少
    inst:ListenForEvent("equipped", function(inst, data)
        local item = data.item
        if item and item.components.finiteuses and 
           (item:HasTag("magicitem") or item.prefab == "icestaff" or 
            item.prefab == "firestaff" or item.prefab == "staff_lunarplant" or
            item.prefab:find("amulet") or 
            item.prefab:find("staff")) then
            
            -- 保存原始的耐久消耗函数
            if not item.platinum_original_use_fn then
                item.platinum_original_use_fn = item.components.finiteuses.onfinished
            end
            
            -- 设置新的耐久消耗函数
            item.components.finiteuses:SetConsumption(item.prefab, 0.75)  -- 减少25%的消耗
            
            if inst.components.talker then
                inst.components.talker:Say("我能更好地使用这件魔法物品")
            end
        end
    end)
    
    -- 当卸下魔法装备时恢复原始耐久消耗
    inst:ListenForEvent("unequipped", function(inst, data)
        local item = data.item
        if item and item.components.finiteuses and item.platinum_original_use_fn then
            item.components.finiteuses:SetConsumption(item.prefab, 1.0)  -- 恢复正常消耗
        end
    end)
    
    -- 6. 移动速度加成 (已在modmain.lua中实现)
    
    -- 7. 食物效果增强
    if inst.components.eater then
        local old_eat_fn = inst.components.eater.oneatfn
        inst.components.eater.oneatfn = function(inst, food)
            if old_eat_fn then
                old_eat_fn(inst, food)
            end
            
            -- 增强食物效果
            if food and food.components.edible then
                -- 如果是魔法或特殊食物，增加额外效果
                if food:HasTag("magic") or food.prefab == "mandrakesoup" or 
                   food.prefab == "butterflymuffin" or food.prefab == "waffles" then
                    
                    -- 增加理智
                    if inst.components.sanity then
                        inst.components.sanity:DoDelta(10)
                    end
                    
                    -- 添加特效
                    local fx = SpawnPrefab("sanity_lower")
                    if fx then
                        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
                        fx.Transform:SetScale(1, 1, 1)
                    end
                    
                    if inst.components.talker then
                        inst.components.talker:Say("这食物真美味~")
                    end
                end
            end
        end
    end
end

-- 仅在服务器上初始化的部分
local master_postinit = function(inst)
    if not inst or not inst:IsValid() then return end
    
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

    -- 添加被动效果
    AddPassiveEffects(inst)

    -- 安全地添加事件监听
    if inst.components.health then
        inst:ListenForEvent("healthdelta", function(inst, data)
            if not inst:IsValid() then return end
            -- ... 处理逻辑 ...
        end)
    end
end

return MakePlayerCharacter("esctemplate", prefabs, assets, common_postinit, master_postinit, prefabs)

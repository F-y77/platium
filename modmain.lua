local GLOBAL = _G

PrefabFiles = {
	"esctemplate",
	"esctemplate_none",
	"platinum_shield",
}

Assets = {
    Asset( "IMAGE", "images/saveslot_portraits/esctemplate.tex" ),
    Asset( "ATLAS", "images/saveslot_portraits/esctemplate.xml" ),

    Asset( "IMAGE", "images/selectscreen_portraits/esctemplate.tex" ),
    Asset( "ATLAS", "images/selectscreen_portraits/esctemplate.xml" ),
	
    Asset( "IMAGE", "images/selectscreen_portraits/esctemplate_silho.tex" ),
    Asset( "ATLAS", "images/selectscreen_portraits/esctemplate_silho.xml" ),

    Asset( "IMAGE", "bigportraits/esctemplate.tex" ),
    Asset( "ATLAS", "bigportraits/esctemplate.xml" ),
	
	Asset( "IMAGE", "images/map_icons/esctemplate.tex" ),
	Asset( "ATLAS", "images/map_icons/esctemplate.xml" ),
	
	Asset( "IMAGE", "images/avatars/avatar_esctemplate.tex" ),
    Asset( "ATLAS", "images/avatars/avatar_esctemplate.xml" ),
	
	Asset( "IMAGE", "images/avatars/avatar_ghost_esctemplate.tex" ),
    Asset( "ATLAS", "images/avatars/avatar_ghost_esctemplate.xml" ),
	
	Asset( "IMAGE", "images/avatars/self_inspect_esctemplate.tex" ),
    Asset( "ATLAS", "images/avatars/self_inspect_esctemplate.xml" ),
	
	Asset( "IMAGE", "images/names_esctemplate.tex" ),
    Asset( "ATLAS", "images/names_esctemplate.xml" ),
	
	Asset( "IMAGE", "images/names_gold_esctemplate.tex" ),
    Asset( "ATLAS", "images/names_gold_esctemplate.xml" ),
    
    Asset("ANIM", "anim/abigail_shield.zip"),
}

AddMinimapAtlas("images/map_icons/esctemplate.xml")

local require = GLOBAL.require
local STRINGS = GLOBAL.STRINGS

-- 角色选择界面信息
STRINGS.CHARACTER_TITLES.esctemplate = "白金三位一体"
STRINGS.CHARACTER_NAMES.esctemplate = "白金"
STRINGS.CHARACTER_DESCRIPTIONS.esctemplate = "*性别未知\n*能量护盾\n*魔法少女"
STRINGS.CHARACTER_QUOTES.esctemplate = "\"juber桑麻さん、大好きですよ~\""
STRINGS.CHARACTER_SURVIVABILITY.esctemplate = "困难"

-- 自定义对话字符串
STRINGS.CHARACTERS.ESCTEMPLATE = require "speech_esctemplate"

-- 游戏中显示的角色名称
STRINGS.NAMES.ESCTEMPLATE = "白金"
STRINGS.SKIN_NAMES.esctemplate_none = "白金"

-- The skins shown in the cycle view window on the character select screen.
-- A good place to see what you can put in here is in skinutils.lua, in the function GetSkinModes
local skin_modes = {
    { 
        type = "ghost_skin",
        anim_bank = "ghost",
        idle_anim = "idle", 
        scale = 0.75, 
        offset = { 0, -25 } 
    },
}

-- 添加全局变量和键位绑定
local TheInput = GLOBAL.TheInput
local CONTROL_FORCE_INSPECT = GLOBAL.CONTROL_FORCE_INSPECT
local FRAMES = GLOBAL.FRAMES
local ACTIONS = GLOBAL.ACTIONS
local SpawnPrefab = GLOBAL.SpawnPrefab
local TheWorld = GLOBAL.TheWorld
local TheNet = GLOBAL.TheNet
local TheFrontEnd = GLOBAL.TheFrontEnd

-- 修改白金的护盾效果参数
local SHIELD_DURATION = 3  -- 护盾持续时间改为3秒
local SHIELD_COOLDOWN = 10  -- 护盾冷却时间改为10秒

-- 修改苍翼默示录白金的特性机制
local DASH_COOLDOWN = 5  -- 闪避冷却时间（秒）
local DASH_DISTANCE = 6  -- 闪避距离
local COMBO_DURATION = 3  -- 连击持续时间（秒）
local MAX_COMBO = 10  -- 最大连击数改为10
local COMBO_DAMAGE_BONUS = 0.1  -- 每次连击增加的伤害百分比

-- 获取按键配置
local SHIELD_KEY = GetModConfigData("shield_key")
local DASH_KEY = GetModConfigData("dash_key")
local MOONSLASH_KEY = GetModConfigData("moonslash_key")

-- 添加RPC事件用于网络同步
AddModRPCHandler("PlatinumMod", "ActivateShield", function(player)
    if player.prefab == "esctemplate" and not player:HasTag("playerghost") then
        -- 服务器端激活护盾
        ActivateShieldServer(player)
    end
end)

-- 添加RPC事件用于网络同步闪避
AddModRPCHandler("PlatinumMod", "ActivateDash", function(player)
    if player.prefab == "esctemplate" and not player:HasTag("playerghost") then
        -- 服务器端激活闪避
        ActivateDashServer(player)
    end
end)

-- 添加月牙斩RPC
AddModRPCHandler("PlatinumMod", "PerformMoonSlash", function(player)
    if player.prefab == "esctemplate" and not player:HasTag("playerghost") then
        PerformMoonSlash(player)
    end
end)

-- 原始的OnAttacked函数（需要在ActivateShieldServer之前定义）
local function OnAttacked(inst, data)
    if not inst.components.health:IsDead() and not inst.sg:HasStateTag("attack") then
        if math.random() < 0.25 then
            if data.damage then
                data.damage = 0
            end
            inst.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour")
            local fx = SpawnPrefab("sparks")
            if fx then
                fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            end
            return true
        end
    end
    return false
end

-- 修改OnAttacked函数以支持完全护盾（确保100%无敌）
local function OnAttackedWithShield(inst, data)
    if inst:HasTag("platinum_shielded") then
        -- 护盾激活时完全免疫伤害
        if data and data.damage then
            data.damage = 0
        end
        
        -- 播放护盾效果
        inst.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour")
        local fx = SpawnPrefab("sparks")
        if fx then
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end
        
        -- 确保不会受到任何伤害
        return true
    end
    
    -- 原有的25%几率护盾逻辑保持不变
    return OnAttacked(inst, data)
end

-- 服务器端护盾激活函数
local function ActivateShieldServer(inst)
    -- 确保有计时器组件
    if not inst.components.timer then
        inst:AddComponent("timer")
    end

    if inst.components.timer:TimerExists("shield_cooldown") then
        -- 如果护盾在冷却中，显示提示
        inst.components.talker:Say("护盾冷却中...")
        return
    end
    
    -- 如果已经有护盾，不要重复激活
    if inst:HasTag("platinum_shielded") then
        return
    end
    
    -- 激活护盾
    inst.components.talker:Say("能量护盾激活！")
    
    -- 创建护盾视觉效果
    local shield = SpawnPrefab("platinum_shield")
    shield.entity:SetParent(inst.entity)
    shield.Transform:SetPosition(0, 0.5, 0)
    
    -- 保存护盾引用以便后续移除
    inst.platinum_shield_fx = shield
    
    -- 添加无敌状态
    inst:AddTag("platinum_shielded")
    
    -- 设置护盾持续时间
    inst.components.timer:StartTimer("shield_duration", SHIELD_DURATION)
    
    -- 护盾结束时的回调
    inst:ListenForEvent("timerdone", function(inst, data)
        if data.name == "shield_duration" then
            -- 移除护盾
            inst:RemoveTag("platinum_shielded")
            
            -- 移除护盾视觉效果
            if inst.platinum_shield_fx and inst.platinum_shield_fx:IsValid() then
                inst.platinum_shield_fx:Remove()
                inst.platinum_shield_fx = nil
            end
            
            inst.components.talker:Say("护盾已消失...")
            
            -- 设置冷却时间
            inst.components.timer:StartTimer("shield_cooldown", SHIELD_COOLDOWN)
        end
    end)
    
    -- 额外保护：确保在护盾激活期间不会受到任何伤害
    if inst.components.health then
        inst.components.health.invincible = true
        inst:DoTaskInTime(SHIELD_DURATION, function()
            if inst.components.health then
                inst.components.health.invincible = false
            end
        end)
    end
end

-- 客户端护盾激活函数
local function ActivateShield(inst)
    -- 只在客户端发送RPC请求
    if TheWorld and not TheWorld.ismastersim then
        SendModRPCToServer(MOD_RPC["PlatinumMod"]["ActivateShield"])
    else
        -- 如果是主机，直接激活
        ActivateShieldServer(inst)
    end
end

-- 服务器端闪避激活函数
local function ActivateDashServer(inst)
    -- 确保有计时器组件
    if not inst.components.timer then
        inst:AddComponent("timer")
    end

    if inst.components.timer:TimerExists("dash_cooldown") then
        -- 如果闪避在冷却中，显示提示
        inst.components.talker:Say("闪避冷却中...")
        return
    end
    
    -- 如果已经在闪避中，不要重复激活
    if inst:HasTag("platinum_dashing") then
        return
    end
    
    -- 获取玩家面向的方向
    local x, y, z = inst.Transform:GetWorldPosition()
    local angle = inst.Transform:GetRotation() * GLOBAL.DEGREES
    local dx = math.cos(angle)
    local dz = -math.sin(angle)
    
    -- 激活闪避
    inst.components.talker:Say("闪避！")
    inst:AddTag("platinum_dashing")
    
    -- 创建闪避视觉效果
    local dash_fx = SpawnPrefab("shadow_puff")
    dash_fx.Transform:SetPosition(x, 0, z)
    
    -- 播放闪避音效
    inst.SoundEmitter:PlaySound("dontstarve/common/staff_blink")
    
    -- 执行闪避移动（不添加无敌状态）
    local target_x = x + dx * DASH_DISTANCE
    local target_z = z + dz * DASH_DISTANCE
    
    -- 检查目标位置是否可通行
    local world = GLOBAL.TheWorld
    if world and world.Map and world.Map.IsPassableAtPoint then
        if world.Map:IsPassableAtPoint(target_x, 0, target_z) then
            -- 瞬移到目标位置
            inst.Physics:Teleport(target_x, 0, target_z)
        else
            -- 如果目标位置不可通行，找到最远的可通行位置
            for dist = DASH_DISTANCE, 1, -1 do
                local test_x = x + dx * dist
                local test_z = z + dz * dist
                if world.Map:IsPassableAtPoint(test_x, 0, test_z) then
                    inst.Physics:Teleport(test_x, 0, test_z)
                    break
                end
            end
        end
    else
        -- 如果无法检查地形，直接尝试瞬移（可能会卡在障碍物中）
        inst.Physics:Teleport(target_x, 0, target_z)
    end
    
    -- 在目标位置创建另一个特效
    local end_fx = SpawnPrefab("shadow_puff")
    end_fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    
    -- 设置闪避结束
    inst:DoTaskInTime(0.2, function()
        inst:RemoveTag("platinum_dashing")
    end)
    
    -- 设置闪避冷却时间
    inst.components.timer:StartTimer("dash_cooldown", DASH_COOLDOWN)
end

-- 客户端闪避激活函数
local function ActivateDash(inst)
    -- 调试信息
    print("尝试激活闪避")
    
    -- 只在客户端发送RPC请求
    if GLOBAL.TheWorld and not GLOBAL.TheWorld.ismastersim then
        SendModRPCToServer(MOD_RPC["PlatinumMod"]["ActivateDash"])
    else
        -- 如果是主机，直接激活
        ActivateDashServer(inst)
    end
end

-- 特殊攻击：月牙斩
local function PerformMoonSlash(inst)
    -- 确保有计时器组件
    if not inst.components.timer then
        inst:AddComponent("timer")
    end
    
    if not inst.components.timer:TimerExists("moonslash_cooldown") then
        inst.components.talker:Say("月牙斩！")
        
        -- 创建月牙斩特效
        local x, y, z = inst.Transform:GetWorldPosition()
        local angle = inst.Transform:GetRotation() * GLOBAL.DEGREES
        local dx = math.cos(angle)
        local dz = -math.sin(angle)
        
        -- 创建月牙特效 - 增加数量和范围
        for i = 1, 5 do  -- 从3个增加到5个
            local dist = i * 2
            local slash = SpawnPrefab("cane_victorian_fx")
            slash.Transform:SetPosition(x + dx * dist, 0.5, z + dz * dist)
            slash.Transform:SetRotation(inst.Transform:GetRotation() + 90)
            slash.Transform:SetScale(1.5, 1.5, 1.5)  -- 增大特效尺寸
            
            -- 对范围内的敌人造成伤害 - 增加范围和伤害
            local ents = GLOBAL.TheSim:FindEntities(x + dx * dist, 0, z + dz * dist, 3.5, {"_combat"}, {"player", "companion", "INLIMBO"})
            for _, ent in ipairs(ents) do
                if ent.components.combat and ent.components.health and not ent.components.health:IsDead() then
                    ent.components.combat:GetAttacked(inst, 70, nil)  -- 伤害从50增加到70
                    
                    -- 添加击退效果
                    if ent.Physics and not ent:HasTag("epic") then  -- 不对大型怪物应用击退
                        local knock_dir = ent:GetAngleToPoint(x, 0, z) * GLOBAL.DEGREES
                        local knock_x = math.cos(knock_dir) * 3  -- 击退距离
                        local knock_z = -math.sin(knock_dir) * 3
                        ent.Physics:Teleport(ent.Transform:GetWorldPosition() + knock_x, 0, ent.Transform:GetWorldPosition() + knock_z)
                    end
                    
                    -- 添加额外视觉效果
                    local hit_fx = SpawnPrefab("impact")
                    if hit_fx then
                        hit_fx.Transform:SetPosition(ent.Transform:GetWorldPosition())
                    end
                end
            end
        end
        
        -- 添加中心爆炸效果
        local explosion = SpawnPrefab("firering_fx")
        explosion.Transform:SetPosition(x + dx * 5, 0, z + dz * 5)  -- 在最远处产生爆炸效果
        explosion.Transform:SetScale(0.7, 0.7, 0.7)
        
        -- 播放音效
        inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
        inst.SoundEmitter:PlaySound("dontstarve/common/whip_large")
        
        -- 设置冷却时间
        inst.components.timer:StartTimer("moonslash_cooldown", 15)
    else
        inst.components.talker:Say("月牙斩冷却中...")
    end
end

-- 连击系统
local function InitComboSystem(inst)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.ismastersim then
        -- 初始化连击计数器
        inst.combo_count = 0
        inst.last_attack_time = 0
        
        -- 监听攻击事件
        inst:ListenForEvent("onattackother", function(inst, data)
            local target = data.target
            local weapon = data.weapon
            local now = GLOBAL.GetTime()
            
            -- 检查是否在连击时间窗口内
            if now - inst.last_attack_time <= COMBO_DURATION then
                -- 增加连击计数
                inst.combo_count = math.min(inst.combo_count + 1, MAX_COMBO)
                
                -- 显示连击数
                if inst.combo_count > 1 then
                    inst.components.talker:Say(inst.combo_count .. "连击！")
                end
                
                -- 增加伤害
                if data.damage and inst.combo_count > 1 then
                    local bonus = 1 + (inst.combo_count - 1) * COMBO_DAMAGE_BONUS
                    data.damage = data.damage * bonus
                    
                    -- 连击达到最大时的特殊效果
                    if inst.combo_count == MAX_COMBO then
                        -- 创建爆炸效果
                        local fx = SpawnPrefab("explode_small")
                        if target and target:IsValid() then
                            fx.Transform:SetPosition(target.Transform:GetWorldPosition())
                        end
                        
                        -- 重置连击计数
                        inst.combo_count = 0
                    end
                end
            else
                -- 超出连击时间窗口，重置连击
                inst.combo_count = 1
            end
            
            -- 更新最后攻击时间
            inst.last_attack_time = now
            
            -- 设置连击计时器
            if inst.combo_count > 0 then
                if inst.combo_timer then
                    inst.combo_timer:Cancel()
                end
                
                inst.combo_timer = inst:DoTaskInTime(COMBO_DURATION, function()
                    if inst.combo_count > 1 then
                        inst.components.talker:Say("连击中断！")
                    end
                    inst.combo_count = 0
                end)
            end
        end)
    end
end

-- 修改玩家初始化函数，添加苍翼默示录特性
AddPlayerPostInit(function(inst)
    if inst.prefab == "esctemplate" then
        -- 添加技能按键监听
        inst:DoTaskInTime(1, function()
            if inst == GLOBAL.ThePlayer then
                -- 简化闪避按键绑定，只使用一种方法
                GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_Z, function()
                    print("Z键被按下")
                    if inst:IsValid() and not inst:HasTag("playerghost") and 
                       not inst.sg:HasStateTag("busy") then
                        ActivateDash(inst)
                    end
                end)
                
                -- 其他按键保持不变
                GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_R, function()
                    if inst:IsValid() and not inst:HasTag("playerghost") and 
                       not inst.sg:HasStateTag("busy") then
                        ActivateShield(inst)
                    end
                end)
                
                GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_G, function()
                    if inst:IsValid() and not inst:HasTag("playerghost") and 
                       not inst.sg:HasStateTag("busy") then
                        if GLOBAL.TheWorld and not GLOBAL.TheWorld.ismastersim then
                            SendModRPCToServer(MOD_RPC["PlatinumMod"]["PerformMoonSlash"])
                        else
                            PerformMoonSlash(inst)
                        end
                    end
                end)
            end
            
            -- 服务器端替换原有的攻击处理函数
            if GLOBAL.TheWorld and GLOBAL.TheWorld.ismastersim then
                -- 确保我们不会重复添加事件监听器
                inst:RemoveEventCallback("attacked", OnAttacked)
                inst:RemoveEventCallback("attacked", OnAttackedWithShield)
                inst:ListenForEvent("attacked", OnAttackedWithShield)
                
                -- 添加额外的伤害拦截，确保无敌状态下不会受到任何伤害
                inst:ListenForEvent("healthdelta", function(inst, data)
                    if inst:HasTag("platinum_shielded") and data.amount < 0 then
                        -- 如果在护盾状态下受到伤害，恢复生命值
                        inst.components.health:DoDelta(-data.amount)
                        return true
                    end
                end)
                
                -- 初始化连击系统
                InitComboSystem(inst)
                
                -- 增加移动速度
                inst.components.locomotor:SetExternalSpeedMultiplier(inst, "platinum_speed_mod", 1.25)
            end
        end)
    end
end)

-- 添加护盾相关的字符串
STRINGS.NAMES.PLATINUM_SHIELD = "白金护盾"
STRINGS.CHARACTERS.ESCTEMPLATE.DESCRIBE.PLATINUM_SHIELD = "我的能量护盾！"

-- 添加角色到模组角色列表，指定性别为ROBOT
AddModCharacter("esctemplate", "ROBOT", skin_modes)

-- 添加特性相关的字符串
STRINGS.CHARACTERS.ESCTEMPLATE.DASH = "闪避！"
STRINGS.CHARACTERS.ESCTEMPLATE.DASH_COOLDOWN = "闪避冷却中..."
STRINGS.CHARACTERS.ESCTEMPLATE.MOONSLASH = "月牙斩！"
STRINGS.CHARACTERS.ESCTEMPLATE.MOONSLASH_COOLDOWN = "月牙斩冷却中..."
STRINGS.CHARACTERS.ESCTEMPLATE.COMBO = "连击！"
STRINGS.CHARACTERS.ESCTEMPLATE.COMBO_BREAK = "连击中断！"

-- 添加特殊合成能力的提示
STRINGS.CHARACTERS.ESCTEMPLATE.ANNOUNCE_MAKE_AMULET = "这个护符会保护我~"


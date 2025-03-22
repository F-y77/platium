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
    
    Asset("ANIM", "anim/platinum_shield.zip"),
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
local CONTROL_FORCE_INSPECT = GLOBAL.CONTROL_FORCE_INSPECT  -- V键
local FRAMES = GLOBAL.FRAMES
local ACTIONS = GLOBAL.ACTIONS
local SpawnPrefab = GLOBAL.SpawnPrefab
local TheWorld = GLOBAL.TheWorld
local TheNet = GLOBAL.TheNet

-- 添加白金的护盾效果
local SHIELD_DURATION = 5  -- 护盾持续时间（秒）
local SHIELD_COOLDOWN = 15  -- 护盾冷却时间（秒）

-- 添加RPC事件用于网络同步
AddModRPCHandler("PlatinumMod", "ActivateShield", function(player)
    if player.prefab == "esctemplate" and not player:HasTag("playerghost") then
        -- 服务器端激活护盾
        ActivateShieldServer(player)
    end
end)

-- 服务器端护盾激活函数
local function ActivateShieldServer(inst)
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
            inst.components.talker:Say("护盾已消失...")
            
            -- 设置冷却时间
            inst.components.timer:StartTimer("shield_cooldown", SHIELD_COOLDOWN)
        end
    end)
end

-- 客户端护盾激活函数
local function ActivateShield(inst)
    -- 只在客户端发送RPC请求
    if not TheWorld.ismastersim then
        SendModRPCToServer(MOD_RPC["PlatinumMod"]["ActivateShield"])
    else
        -- 如果是主机，直接激活
        ActivateShieldServer(inst)
    end
end

-- 修改OnAttacked函数以支持完全护盾
local function OnAttackedWithShield(inst, data)
    if inst:HasTag("platinum_shielded") then
        -- 护盾激活时完全免疫伤害
        if data.damage then
            data.damage = 0
        end
        
        -- 播放护盾效果
        inst.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour")
        local fx = SpawnPrefab("sparks")
        if fx then
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end
        
        return true
    end
    
    -- 原有的25%几率护盾逻辑保持不变
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

-- 添加按键监听
AddPlayerPostInit(function(inst)
    if inst.prefab == "esctemplate" then
        -- 确保有计时器组件
        if TheWorld.ismastersim and not inst.components.timer then
            inst:AddComponent("timer")
        end
        
        -- 添加护盾激活按键监听（仅在本地玩家上）
        inst:DoTaskInTime(0, function()
            -- 检查是否是本地玩家
            if inst == GLOBAL.ThePlayer then
                -- 使用KeyUp事件而不是KeyHandler组件
                GLOBAL.TheInput:AddKeyUpHandler(GLOBAL.KEY_V, function()
                    if inst:IsValid() and not inst:HasTag("playerghost") and 
                       not inst.sg:HasStateTag("busy") and not GLOBAL.TheFrontEnd:GetActiveScreen():IsMessageScreenOpen() then
                        ActivateShield(inst)
                    end
                end)
            end
            
            -- 服务器端替换原有的攻击处理函数
            if TheWorld.ismastersim then
                inst:RemoveEventCallback("attacked", OnAttacked)
                inst:ListenForEvent("attacked", OnAttackedWithShield)
            end
        end)
    end
end)

-- 添加护盾相关的字符串
STRINGS.NAMES.PLATINUM_SHIELD = "白金护盾"
STRINGS.CHARACTERS.ESCTEMPLATE.DESCRIBE.PLATINUM_SHIELD = "我的能量护盾！"

-- 添加角色到模组角色列表，指定性别为ROBOT
AddModCharacter("esctemplate", "ROBOT", skin_modes)

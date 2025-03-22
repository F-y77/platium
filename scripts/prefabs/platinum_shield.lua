local assets =
{
    -- 使用阿比盖尔的保护罩效果
    Asset("ANIM", "anim/abigail_shield.zip"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()
    
    inst:AddTag("FX")
    
    -- 使用阿比盖尔的保护罩效果
    inst.AnimState:SetBank("abigail_shield")
    inst.AnimState:SetBuild("abigail_shield")
    inst.AnimState:PlayAnimation("idle_pre")
    inst.AnimState:PushAnimation("idle_loop", true)
    inst.AnimState:SetScale(1.5, 1.5, 1.5)
    inst.AnimState:SetMultColour(0.3, 0.5, 1, 0.7)  -- 蓝色调
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    
    -- 添加光效
    inst.entity:AddLight()
    inst.Light:SetRadius(2)
    inst.Light:SetFalloff(0.7)
    inst.Light:SetIntensity(0.6)
    inst.Light:SetColour(0.3, 0.5, 1)
    inst.Light:Enable(true)
    
    -- 确保网络同步
    inst.Network:SetClassifiedTarget(inst)
    
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end
    
    inst.persists = false
    
    -- 播放护盾激活音效
    inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/shield/on")
    
    -- 5秒后自动销毁
    inst:DoTaskInTime(TUNING.ABIGAIL_SHIELD_DURATION or 5, function()
        inst.AnimState:PlayAnimation("idle_pst")
        inst:ListenForEvent("animover", inst.Remove)
        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/shield/off")
    end)
    
    return inst
end

return Prefab("platinum_shield", fn, assets) 
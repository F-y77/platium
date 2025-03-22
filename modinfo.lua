name = "BBCF-Platium the Trinity"
description = "白金三位一体-短发装，拥有能量护盾、闪避和月牙斩技能，以及多种被动效果。"
author = "Va6gn"
version = "0.3" 

api_version = 10

dst_compatible = true

dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = true 

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {
"character",
"白金" ,
"Platium_the_trinity",
"BBCF"   
}

-- 按键配置选项
configuration_options = {
    {
        name = "shield_key",
        label = "护盾按键",
        options = {
            {description = "R键", data = "KEY_R"},
            {description = "V键", data = "KEY_V"},
            {description = "F键", data = "KEY_F"}
        },
        default = "KEY_R"
    },
    {
        name = "dash_key",
        label = "闪避按键",
        options = {
            {description = "Z键", data = "KEY_Z"},
            {description = "SHIFT键", data = "KEY_SHIFT"},
            {description = "SPACE键", data = "KEY_SPACE"}
        },
        default = "KEY_Z"
    },
    {
        name = "moonslash_key",
        label = "月牙斩按键",
        options = {
            {description = "G键", data = "KEY_G"},
            {description = "C键", data = "KEY_C"},
            {description = "X键", data = "KEY_X"}
        },
        default = "KEY_G"
    }
}

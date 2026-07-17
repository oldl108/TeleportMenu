local _, tpm = ...

--- @type { [integer]: boolean }
tpm.ItemTeleports = {
	-- 肯瑞托戒指
	-- 小提示：理论上你可以拥有全部这些戒指，但那会占用太多背包空间。
	[32757] = true, -- 卡拉波的祝福勋章
	[37863] = true, -- 迪尔格的遥控器
	[40586] = true, -- 肯瑞托指环
	[44935] = true, -- 肯瑞托戒指
	[40585] = true, -- 肯瑞托印戒
	[44934] = true, -- 肯瑞托环
	[45688] = true, -- 铭文的肯瑞托指环
	[45690] = true, -- 铭文的肯瑞托戒指
	[45691] = true, -- 铭文的肯瑞托印戒
	[45689] = true, -- 铭文的肯瑞托环
	[48954] = true, -- 蚀刻的肯瑞托指环
	[48955] = true, -- 蚀刻的肯瑞托环
	[48956] = true, -- 蚀刻的肯瑞托戒指
	[48957] = true, -- 蚀刻的肯瑞托印戒
	[51557] = true, -- 符文的肯瑞托印戒
	[51558] = true, -- 符文的肯瑞托环
	[51559] = true, -- 符文的肯瑞托戒指
	[51560] = true, -- 符文的肯瑞托指环
	[52251] = true, -- 吉安娜的吊坠
	-- 阵营披风
	[63206] = UnitFactionGroup("player") == "Alliance", -- 团结披风：暴风城
	[63207] = UnitFactionGroup("player") == "Horde", -- 团结披风：奥格瑞玛
	[63352] = UnitFactionGroup("player") == "Alliance", -- 合作披风：暴风城
	[63353] = UnitFactionGroup("player") == "Horde", -- 合作披风：奥格瑞玛
	[65274] = UnitFactionGroup("player") == "Horde", -- 协调披风：奥格瑞玛
	[65360] = UnitFactionGroup("player") == "Alliance", -- 协调披风：暴风城
	-- 其他物品
	[43824] = true, -- 奥术魔法学校 - 精通
	[46874] = true, -- 银色十字军战袍
	[50287] = true, -- 海湾之靴
	[58487] = true, -- 深岩之洲药剂
	[61379] = true, -- 吉德温的炉石
	[63378] = true, -- 地狱咆哮的战袍
	[63379] = true, -- 巴拉德的守望者战袍
	[64457] = true, -- 阿古斯最后的遗物
	[68808] = true, -- 英雄的炉石
	[68809] = true, -- 老兵的炉石
	[87548] = true, -- 游学者罗盘
	[92510] = true, -- 沃金的炉石
	[95050] = UnitFactionGroup("player") == "Horde", -- 最黄铜指节（搏击俱乐部竞技场）
	[95051] = UnitFactionGroup("player") == "Alliance", -- 最黄铜指节（比兹莫搏击酒馆）
	[95567] = UnitFactionGroup("player") == "Alliance", -- 肯瑞托信标
	[95568] = UnitFactionGroup("player") == "Horde", -- 夺日者信标
	[103678] = true, -- 时光失落神器
	[117389] = true, -- 德拉诺考古学家的罗盘
	[118662] = true, -- 刃牙阵营圣物
	[118663] = true, -- 卡拉波圣物
	[118907] = UnitFactionGroup("player") == "Alliance", -- 拳击手的猛击戒指（比兹莫搏击酒馆）
	[118908] = UnitFactionGroup("player") == "Horde", -- 拳击手的猛击戒指（搏击俱乐部竞技场）
	[119183] = true, -- 冒险召回卷轴
	[128353] = true, -- 舰队司令的罗盘
	[128502] = true, -- 猎人的寻踪水晶
	[128503] = true, -- 大师猎人的寻踪水晶
	[129276] = true, -- 次元裂隙入门指南
	[132119] = UnitFactionGroup("player") == "Horde", -- 奥格瑞玛传送石
	[132120] = UnitFactionGroup("player") == "Alliance", -- 暴风城传送石
	[132517] = true, -- 达拉然内部虫洞发生器
	[132523] = true, -- 里弗斯电池
	[136849] = UnitClass("player") == "DRUID", -- 自然信标（德鲁伊玩具）
	[138448] = true, -- 玛戈斯的徽记
	[139590] = true, -- 传送卷轴：拉文霍德
	[139599] = true, -- 强化的肯瑞托戒指
	[140324] = true, -- 移动远程信标
	[140493] = true, -- 次元裂隙熟手指南
	[141013] = true, -- 回城卷轴：沙拉尼尔
	[141014] = true, -- 回城卷轴：萨什贾
	[141015] = true, -- 回城卷轴：卡尔德拉
	[141016] = true, -- 回城卷轴：法罗纳尔
	[141017] = true, -- 回城卷轴：利安特里尔
	[141324] = true, -- 沙尔多雷的护符
	[141605] = true, -- 飞行管理员的哨子
	[142298] = true, -- 惊艳猩红拖鞋
	[142469] = true, -- 大法师的紫印
	[142543] = true, -- 回城卷轴（暗黑破坏神3活动）
	[144341] = true, -- 可充电里弗斯电池
	[144391] = UnitFactionGroup("player") == "Alliance", -- 拳击手强力猛击戒指（联盟）
	[144392] = UnitFactionGroup("player") == "Horde", -- 拳击手强力猛击戒指（部落）
	[150733] = true, -- 回城卷轴（阿拉希的阿戈洛克）
	[151016] = true, -- 碎裂的死灵法师头骨
	[159224] = true, -- 祖尔达萨的炉石
	[160219] = true, -- 回城卷轴（阿拉希的激流堡）
	[163694] = true, -- 奢华召回卷轴
	[166559] = true, -- 指挥官战斗印戒
	[166560] = true, -- 队长指挥印戒
	[167075] = true, -- 麦卡贡超安全传送器
	[168862] = true, -- G.E.A.R. 追踪信标
	[169064] = true, -- 欺诈者的多彩披风
	[169297] = UnitFactionGroup("player") == "Alliance", -- 风暴之钉徽记
	[172203] = true, -- 碎裂的炉石
	[173373] = true, -- 法尔的炉石
	[173430] = true, -- 晶红圣所传送卷轴
	[173528] = true, -- 镀金炉石
	[173532] = true, -- 提瑞斯法营地卷轴
	[173537] = true, -- 发光炉石
	[173716] = true, -- 苔藓炉石
	[180817] = true, -- 迁跃密码（维娜丽的避难所）
	[181163] = true, -- 传送卷轴：伤逝剧场
	[184500] = true, -- 侍从的便携传送门：晋升堡垒
	[184501] = true, -- 侍从的便携传送门：雷文德斯
	[184502] = true, -- 侍从的便携传送门：玛卓克萨斯
	[184503] = true, -- 侍从的便携传送门：炽蓝仙野
	[184504] = true, -- 侍从的便携传送门：奥利波斯
	[189827] = true, -- Xy 财阀的入会证明
	[191029] = true, -- 莉莉安的炉石
	[193000] = true, -- 环缚沙漏
	[200613] = true, -- 艾拉格风石碎片
	[201957] = true, -- 萨尔炉石
	[202046] = true, -- 幸运海龟人护符
	[204481] = true, -- 莫夸特炉石图腾
	[205255] = true, -- 尼弗吸盘挖掘手套
	[205456] = true, -- 遗失的龙鳞（1）
	[205458] = true, -- 遗失的龙鳞（2）
	[211788] = UnitRace("player") == "Worgen", -- 苔丝的和平草
	[230850] = true, -- 地下堡机器人 7001
	[234389] = true, -- 加拉基奥忠诚度奖励卡：银
	[234390] = true, -- 加拉基奥忠诚度奖励卡：金
	[234391] = true, -- 加拉基奥忠诚度奖励卡：铂金
	[234392] = true, -- 加拉基奥忠诚度奖励卡：黑
	[234393] = true, -- 加拉基奥忠诚度奖励卡：钻石
	[234394] = true, -- 加拉基奥忠诚度奖励卡：传说
	[238727] = true, -- 诺斯温的代金券
	[243056] = true, -- 地下探索者的法力束缚以太门
	[249699] = true, -- 暗影卫士传送器
	[253629] = true, -- 阿坎提娜的私人钥匙
	[266370] = true, -- 墩墩的丰富旅行法
	[276371] = true, -- 光帷召回信标 12.0.7	
}

function tpm:GetAvailableItemTeleports()
	return tpm.AvailableItemTeleports
end

local cachedToys = {}
function tpm:IsToyTeleport(id)
	return cachedToys[id] or false
end

function tpm:UpdateAvailableItemTeleports()
	local AvailableItemTeleports = {}

	for id, _ in pairs(tpm.ItemTeleports) do
		local hasItem = (C_Item.GetItemCount(id) or 0) > 0
		local isToy = select(1, C_ToyBox.GetToyInfo(id)) ~= nil
		local usableToy = isToy and PlayerHasToy(id)
		if (hasItem or usableToy) and TeleportMenuDB[id] == true then
			cachedToys[id] = isToy
			table.insert(AvailableItemTeleports, id)
		end
	end

	tpm.AvailableItemTeleports = AvailableItemTeleports
end

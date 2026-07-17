local _, tpm = ...

local AvailableHearthstones = {}
local covenantsMaxed = nil
local function GetCovenantData(id) -- 该 id 来自成就“声名赫赫再再再”的进度索引
	if covenantsMaxed then
		return covenantsMaxed[id]
	end
	covenantsMaxed = {}
	for i = 1, 4 do
		local _, _, completed = GetAchievementCriteriaInfo(15646, i)
		covenantsMaxed[i] = completed
	end
end

--- @type { [integer]: boolean|fun(): boolean|nil }
tpm.Hearthstones = {
	[54452] = true, -- 虚灵传送门
	[64488] = true, -- 旅店老板的女儿
	[93672] = true, -- 黑暗之门
	[142542] = true, -- 回城之书
	[162973] = true, -- 冬爷爷的炉石
	[163045] = true, -- 无头骑士的炉石
	[163206] = true, -- 疲惫之魂的束缚
	[165669] = true, -- 长者的炉石
	[165670] = true, -- 小匹德脚的可爱炉石
	[165802] = true, -- 高贵园丁的炉石
	[166746] = true, -- 吞火者的炉石
	[166747] = true, -- 啤酒节狂欢者的炉石
	[168907] = true, -- 全息数字化炉石
	[172179] = true, -- 永恒行者的炉石
	[180290] = function()
		-- 法夜炉石
		if GetCovenantData(3) then
			return true
		end
		local covenantID = C_Covenants.GetActiveCovenantID()
		if covenantID == 3 then
			return true
		end
	end,
	[182773] = function()
		-- 通灵领主炉石
		if GetCovenantData(2) then
			return true
		end
		local covenantID = C_Covenants.GetActiveCovenantID()
		if covenantID == 4 then
			return true
		end
	end,
	[183716] = function()
		-- 温西尔罪碑
		if GetCovenantData(4) then
			return true
		end
		local covenantID = C_Covenants.GetActiveCovenantID()
		if covenantID == 2 then
			return true
		end
	end,
	[184353] = function()
		-- 格里恩炉石
		if GetCovenantData(1) then
			return true
		end
		local covenantID = C_Covenants.GetActiveCovenantID()
		if covenantID == 1 then
			return true
		end
	end,
	[188952] = true, -- 被支配的炉石
	[190196] = true, -- 启悟者的炉石
	[190237] = true, -- 掮灵传送矩阵
	[193588] = true, -- 时光行者的炉石
	[200630] = true, -- 欧恩伊尔风语者的炉石
	[206195] = true, -- 纳鲁之路
	[208704] = true, -- 深居者的土灵炉石
	[209035] = true, -- 烈焰炉石
	[210455] = function()
		-- 德莱尼全息宝石（仅德莱尼与光铸德莱尼）
		local _, _, raceId = UnitRace("player")
		if raceId == 11 or raceId == 30 then
			return true
		end
	end,
	[212337] = true, -- 炉石之石
	[228940] = true, -- 恶名丝线的炉石
	[236687] = true, -- 爆炸炉石
	[235016] = true, -- 再部署模块
	[245970] = true, -- 邮政所所长的快速炉石
	[246565] = true, -- 宇宙炉石
	[257736] = true, -- 光召炉石 12.0
	[263489] = true, -- 纳鲁的环抱
	[263933] = true, -- 觅猎者的炉石 12.0
	[264367] = true, -- 菌语者的炉石孢子 12.0.7
	[265100] = true, -- 核心守卫的炉石 12.0
}

function tpm:GetAvailableHearthstoneToys()
	local hearthstoneNames = {}
	for _, toyId in pairs(AvailableHearthstones) do
		--- @type unknown, string, string | integer
		local _, name, texture = C_ToyBox.GetToyInfo(toyId)
		if not texture then
			texture = "Interface\\Icons\\inv_hearthstonepet"
		end
		if not name then
			name = tostring(toyId)
		end
		hearthstoneNames[toyId] = { name = name, texture = texture }
	end
	return hearthstoneNames
end

function tpm:UpdateAvailableHearthstones()
	AvailableHearthstones = {}
	for id, usable in pairs(tpm.Hearthstones) do
		if PlayerHasToy(id) then
			if type(usable) == "function" and usable() then
				table.insert(AvailableHearthstones, id)
			elseif usable == true then
				table.insert(AvailableHearthstones, id)
			end
		end
	end
	tpm.AvailableHearthstones = AvailableHearthstones
end

do
	local lastRandomHearthstone = nil
	function tpm:GetRandomHearthstone(retry)
		if #tpm.AvailableHearthstones == 0 then
			return
		end
		if #tpm.AvailableHearthstones == 1 then
			return tpm.AvailableHearthstones[1]
		end -- （仅一个时直接返回）
		local randomHs = tpm.AvailableHearthstones[math.random(#tpm.AvailableHearthstones)]
		if lastRandomHearthstone == randomHs then -- （不完全随机，保证每次换新）
			randomHs = self:GetRandomHearthstone(true) --[[@as integer]]
		end
		if not retry then
			lastRandomHearthstone = randomHs
		end
		return randomHs
	end
end

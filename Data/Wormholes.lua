local _, tpm = ...
local push = table.insert

--- @type { [integer]: boolean }
tpm.Wormholes = {
	[30542] = true, -- 空间撕裂器 - 52区
	[18984] = true, -- 空间撕裂器 - 永望镇
	[18986] = true, -- 超安全传送器：加基森
	[30544] = true, -- 超安全传送器：托什雷的营地
	[48933] = true, -- 虫洞发生器：诺森德
	[87215] = true, -- 虫洞发生器：潘达利亚
	[112059] = true, -- 虫洞离心机（德拉诺）6
	[151652] = true, -- 虫洞发生器：阿古斯
	[168807] = true, -- 虫洞发生器：库尔提拉斯 5
	[168808] = true, -- 虫洞发生器：赞达拉
	[172924] = true, -- 虫洞发生器：暗影界 3
	[198156] = true, -- 龙洞发生器：巨龙群岛 4
	[221966] = true, -- 虫洞发生器：卡兹阿加
	[248485] = true, -- 虫洞发生器：奎尔萨拉斯 12.0
}

function tpm:UpdateAvailableWormholes()
	local availableWormholes = {}
	for id, _ in pairs(tpm.Wormholes) do
		if PlayerHasToy(id) then
			push(availableWormholes, id)
		end
	end

	tpm.AvailableWormholes = availableWormholes
	tpm.AvailableWormholes.GetUsable = function()
		if #tpm.AvailableWormholes == 0 then
			return {}
		end

		local usableWormholes = {}
		for _, wormholeId in ipairs(availableWormholes) do
			if C_ToyBox.IsToyUsable(wormholeId) then
				table.insert(usableWormholes, wormholeId)
			end
		end
		table.sort(usableWormholes)
		return usableWormholes
	end
end

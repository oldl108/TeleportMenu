-- =====================================================================
-- HydrationAlarm - 游戏内「喝水提醒 + 多组闹钟」
-- 作为 传送菜单(TeleportMenu) 汉化版的「自制小工具」内置模块
-- 作者(汉化/自制): 拉面-克苏恩
--
-- 合规说明（暴雪插件规范）:
--   纯 UI / 提醒类工具，仅读取玩家自身的生命/法力(UnitHealth/
--   UnitPower)、战斗状态(InCombatLockdown) 等公开 API，不读写文件、
--   不联网、不自动施法/使用物品、不解析战斗日志或敌方信息、不 taint
--   安全环境，完全符合《魔兽世界》插件使用条款。
-- =====================================================================

local HA = {}
HA.NAME  = "HydrationAlarm"
HA.TITLE = "提醒与闹钟"
HA.C     = "|cff4fc3f7"   -- 浅蓝
HA.R     = "|r"

-- 可选提示音（全部为游戏内置 SoundKit，无需附带音频文件）
HA.SOUNDS = {
  { value = "ALARM_CLOCK_WARNING_1", label = "闹钟声 1" },
  { value = "ALARM_CLOCK_WARNING_2", label = "闹钟声 2" },
  { value = "ALARM_CLOCK_WARNING_3", label = "闹钟声 3" },
  { value = "READY_CHECK",           label = "就绪检查" },
  { value = "RAID_WARNING",          label = "团队警告" },
  { value = "IG_MAINMENU_OPEN",       label = "菜单开启" },
}

-- 默认配置（首次加载时写入 TeleportMenuDB.HA）
HA.DEFAULTS = {
  drink = {
    enabled    = true,   -- 定时喝水提醒
    combatOnly = true,   -- 仅脱战时提醒（战斗中不打扰）
    interval   = 45,     -- 间隔（分钟）
    lowRes     = true,   -- 资源偏低时提醒吃喝
    lowPct     = 50,     -- 低资源阈值（%）
  },
  reminder = {
    duration = 15,       -- 弹窗自动隐藏（秒）
    flash    = true,     -- 屏幕边缘闪烁
    sound    = true,     -- 播放声音
    soundKit = "ALARM_CLOCK_WARNING_3",
  },
  alarms = {
    { name = "做世界任务", enabled = true,  type = "interval", interval = 60,  clock = "20:00", msg = "该去做世界任务啦！",               sound = "ALARM_CLOCK_WARNING_3", flash = true  },
    { name = "收菜/邮件",  enabled = false, type = "interval", interval = 120, clock = "12:00", msg = "记得收菜、清邮件～",               sound = "ALARM_CLOCK_WARNING_2", flash = true  },
    { name = "定时休息",   enabled = true,  type = "clock",    interval = 60,  clock = "22:00", msg = "晚上10点啦，休息眼睛准备下线！", sound = "ALARM_CLOCK_WARNING_1", flash = false },
  },
}

local DB  -- 指向 TeleportMenuDB.HA

----------------------------------------
-- 基础工具
----------------------------------------
function HA:Print(msg)
  print(self.C .. "[" .. self.TITLE .. "] " .. self.R .. (msg or ""))
end

function HA:ResolveSound(key)
  if SOUNDKIT and SOUNDKIT[key] then return SOUNDKIT[key] end
  if SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 then return SOUNDKIT.ALARM_CLOCK_WARNING_3 end
  return 8953
end

function HA:PlayAlarm(soundKey)
  if not DB or (DB.reminder and DB.reminder.sound == false) then return end
  local key = soundKey or (DB.reminder and DB.reminder.soundKit) or "ALARM_CLOCK_WARNING_3"
  local id = self:ResolveSound(key)
  pcall(PlaySound, id)
end

-- 深合并默认值，保留用户已有的设置
function HA:MergeDefaults(t, defaults)
  for k, v in pairs(defaults) do
    if k == "alarms" then
      if type(t[k]) ~= "table" or #t[k] == 0 then
        t[k] = CopyTable(v)
      end
    elseif t[k] == nil then
      t[k] = v
    elseif type(v) == "table" and type(t[k]) == "table" then
      self:MergeDefaults(t[k], v)
    end
  end
  return t
end

----------------------------------------
-- 提醒弹窗
----------------------------------------
function HA:CreateReminderFrame()
  if self.reminder then return end
  local f = CreateFrame("Frame", "HydrationAlarmReminder", UIParent)
  f:SetSize(340, 150)
  f:SetPoint("TOP", UIParent, "TOP", 0, -40)
  f:SetFrameStrata("HIGH")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16, tile = false,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.05, 0.15, 0.25, 0.95)
  f:SetBackdropBorderColor(0.31, 0.76, 0.97, 1)
  f:Hide()

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(40, 40)
  icon:SetPoint("TOPLEFT", 14, -14)
  icon:SetTexture("Interface\\Icons\\INV_Drink_05")

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
  title:SetText(self.C .. "提醒与闹钟" .. self.R)

  local msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  msg:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
  msg:SetPoint("RIGHT", f, "RIGHT", -14, 0)
  msg:SetWordWrap(true)
  msg:SetJustifyH("LEFT")

  local dismiss = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  dismiss:SetSize(100, 24)
  dismiss:SetPoint("BOTTOMLEFT", 14, 12)
  dismiss:SetText("知道了")
  dismiss:SetScript("OnClick", function() f:Hide() end)

  local snooze = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  snooze:SetSize(100, 24)
  snooze:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
  snooze:SetText("稍后提醒")
  snooze:SetScript("OnClick", function() f:Hide(); HA:Snooze() end)

  f.title, f.msg = title, msg
  self.reminder = f
end

function HA:Flash()
  if not self.flashFrame then
    local ff = CreateFrame("Frame", "HydrationAlarmFlash", UIParent)
    ff:SetFrameStrata("FULLSCREEN_DIALOG")
    ff:EnableMouse(false)
    ff:SetAllPoints(UIParent)
    ff:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 28,
      insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    ff:Hide()
    self.flashFrame = ff
  end
  local ff = self.flashFrame
  ff:SetBackdropBorderColor(0.4, 0.9, 1, 1)
  ff:Show()
  if UIFrameFadeOut then
    UIFrameFadeOut(ff, 1.5, 1, 0)
  else
    C_Timer.After(1.5, function() ff:Hide() end)
  end
end

function HA:Notify(titleText, message, soundKey, flash)
  self:CreateReminderFrame()
  local f = self.reminder
  f.title:SetText(self.C .. (titleText or "提醒与闹钟") .. self.R)
  f.msg:SetText(message or "")
  f:Show()
  self:PlayAlarm(soundKey)
  if flash ~= false and DB and DB.reminder.flash then
    self:Flash()
  end
  self._lastNotify = { title = titleText, msg = message, sound = soundKey, flash = flash }
  local dur = (DB and DB.reminder and DB.reminder.duration) or 15
  if self._hideTimer then self._hideTimer:Cancel() end
  self._hideTimer = C_Timer.After(dur, function() if f:IsShown() then f:Hide() end end)
end

function HA:Snooze()
  if not self._lastNotify then return end
  local n = self._lastNotify
  self:Print("已暂停提醒，5 分钟后再叫你。")
  C_Timer.After(300, function() HA:Notify(n.title, n.msg, n.sound, n.flash) end)
end

----------------------------------------
-- 提醒逻辑
----------------------------------------
function HA:CheckDrink()
  local d = DB.drink
  if not d.enabled then return end
  if d.combatOnly and InCombatLockdown() then return end
  if UnitIsDeadOrGhost("player") then return end
  local now = GetTime()
  if not self._lastDrink then self._lastDrink = now end
  if now - self._lastDrink >= d.interval * 60 then
    self._lastDrink = now
    self:Notify("该喝水啦", "你已经连续玩了 " .. d.interval .. " 分钟，起来喝口水、活动一下筋骨吧！")
  end
end

function HA:CheckLowRes()
  local d = DB.drink
  if not d.lowRes then return end
  if InCombatLockdown() then return end
  if UnitIsDeadOrGhost("player") then return end
  local hp = UnitHealth("player") / math.max(1, UnitHealthMax("player")) * 100
  local hasMana = UnitPowerMax("player", 0) > 0
  local mp = hasMana and (UnitPower("player", 0) / UnitPowerMax("player", 0) * 100) or 100
  local low = (hp < d.lowPct) or (hasMana and mp < d.lowPct)
  if low and not self._lowResActive then
    self._lowResActive = true
    self:Notify("资源偏低", "你的生命/法力偏低，记得吃点东西或喝饮料恢复一下状态～")
  elseif not low then
    self._lowResActive = false
  end
end

function HA:FireAlarm(a)
  a.lastTrigger = GetTime()
  self:Notify("闹钟 · " .. (a.name or "提醒"), a.msg or "时间到！", a.sound, a.flash)
end

function HA:CheckClockAlarm(a)
  if not C_DateAndTime or not C_DateAndTime.GetCurrentCalendarTime then return end
  local t = C_DateAndTime.GetCurrentCalendarTime()
  if not t then return end
  local curKey = string.format("%02d:%02d", t.hour, t.minute)
  local target = a.clock or "20:00"
  self._clockState = self._clockState or {}
  if curKey == target and self._clockState[a.name] ~= curKey then
    self._clockState[a.name] = curKey
    self:Notify("闹钟 · " .. (a.name or "提醒"), a.msg or "时间到！", a.sound, a.flash)
  elseif curKey ~= target then
    self._clockState[a.name] = nil
  end
end

function HA:Tick()
  if not DB then return end
  self:CheckDrink()
  self:CheckLowRes()
  for _, a in ipairs(DB.alarms) do
    if a.enabled then
      if a.type == "interval" then
        if GetTime() - (a.lastTrigger or 0) >= (tonumber(a.interval) or 60) * 60 then
          self:FireAlarm(a)
        end
      elseif a.type == "clock" then
        self:CheckClockAlarm(a)
      end
    end
  end
end

----------------------------------------
-- 游戏菜单「左侧按钮」
----------------------------------------
function HA:CreateMenuButton()
  if self.menuButton then return end
  local parent = _G.TeleportMeButtonsFrameLeft or GameMenuFrame
  if not parent then return end
  local size = (_G.TeleportMenuDB and _G.TeleportMenuDB["Button:Size"]) or 40

  local btn = CreateFrame("Button", "HAMenuButton", parent, "SecureActionButtonTemplate")
  btn:SetSize(size, size)
  btn:SetFrameStrata("HIGH")
  btn:SetFrameLevel(102)
  btn:EnableMouse(true)
  btn:RegisterForClicks("AnyUp")

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetAllPoints()
  icon:SetTexture("Interface\\Icons\\INV_Drink_05")
  btn.icon = icon

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(HA.C .. "提醒与闹钟" .. HA.R)
    GameTooltip:AddLine("左键：打开「喝水提醒 / 多组闹钟」设置", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  btn:SetScript("OnClick", function() HA:OpenOptions() end)

  self.menuButton = btn
  self.menuButtonSize = size
end

function HA:PositionMenuButton()
  local btn = self.menuButton
  if not btn then
    self:CreateMenuButton()
    btn = self.menuButton
  end
  if not btn then return end
  if not GameMenuFrame or not GameMenuFrame:IsShown() then
    btn:Hide()
    return
  end
  btn:Show()
  local left = _G.TeleportMeButtonsFrameLeft
  local size = self.menuButtonSize or 40
  btn:SetSize(size, size)
  if left and left:IsShown() then
    local n = (left.GetButtonAmount and left:GetButtonAmount()) or 0
    btn:SetPoint("LEFT", left, "TOPRIGHT", 0, -size * n)
  else
    btn:SetPoint("TOPLEFT", GameMenuFrame, "BOTTOMLEFT", 0, -4)
  end
end

----------------------------------------
-- 设置面板（游戏内「设置 / 插件」）
----------------------------------------
local function MakeCheck(parent, label, getVal, setVal)
  local c = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  c.Text:SetText(label)
  c:SetChecked(getVal())
  c:SetScript("OnClick", function() setVal(c:GetChecked()) end)
  return c
end

local function MakeSlider(parent, label, minV, maxV, step, getVal, setVal)
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetValue(getVal())
  s:SetScript("OnValueChanged", function(_, v)
    setVal(v)
    if s.Text then s.Text:SetText(label .. "：" .. math.floor(v + 0.5)) end
  end)
  if s.Text then s.Text:SetText(label .. "：" .. math.floor(getVal() + 0.5)) end
  if s.Low then s.Low:SetText(minV) end
  if s.High then s.High:SetText(maxV) end
  return s
end

local function MakeEdit(parent, w, h, text)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(w, h or 20)
  eb:SetText(text or "")
  eb:SetAutoFocus(false)
  eb:SetFontObject("ChatFontNormal")
  eb:SetScript("OnEscapePressed", function() eb:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function() eb:ClearFocus() end)
  return eb
end

-- 下拉选择用「循环按钮」实现，避免依赖 UIDropDownMenu，兼容性最好
local function MakeCycle(parent, values, getVal, setVal, width)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width or 120, 22)
  local function labelOf(v)
    for _, o in ipairs(values) do if o.value == v then return o.label end end
    return tostring(v)
  end
  local function refresh() btn:SetText(labelOf(getVal())) end
  btn:SetScript("OnClick", function()
    local cur = getVal()
    local idx = 1
    for i, o in ipairs(values) do if o.value == cur then idx = i; break end end
    idx = (idx % #values) + 1
    setVal(values[idx].value)
    refresh()
  end)
  refresh()
  return btn
end

function HA:BuildOptions()
  local panel = CreateFrame("Frame", "HydrationAlarmOptionsPanel", UIParent)
  panel.name = self.TITLE
  self.optionsPanel = panel
  InterfaceOptions_AddCategory(panel)

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(self.TITLE .. " 设置（传送菜单 内置小工具）")

  local d = DB.drink
  local r = DB.reminder

  -- 一、喝水提醒
  local sec1 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  sec1:SetPoint("TOPLEFT", 16, -48)
  sec1:SetText(self.C .. "一、喝水提醒" .. self.R)

  local y = -70
  local c1 = MakeCheck(panel, "启用定时喝水提醒（每 N 分钟提醒一次）",
    function() return d.enabled end, function(v) d.enabled = v end)
  c1:SetPoint("TOPLEFT", 24, y); y = y - 28

  local s1 = MakeSlider(panel, "间隔(分钟)", 10, 120, 5,
    function() return d.interval end, function(v) d.interval = math.floor(v) end)
  s1:SetPoint("TOPLEFT", 24, y); s1:SetWidth(220); y = y - 36

  local c2 = MakeCheck(panel, "仅脱战时提醒（战斗中不弹出）",
    function() return d.combatOnly end, function(v) d.combatOnly = v end)
  c2:SetPoint("TOPLEFT", 24, y); y = y - 28

  local c3 = MakeCheck(panel, "资源偏低时提醒吃喝（脱战且血/蓝低于阈值）",
    function() return d.lowRes end, function(v) d.lowRes = v end)
  c3:SetPoint("TOPLEFT", 24, y); y = y - 28

  local s2 = MakeSlider(panel, "低资源阈值(%)", 10, 90, 5,
    function() return d.lowPct end, function(v) d.lowPct = math.floor(v) end)
  s2:SetPoint("TOPLEFT", 24, y); s2:SetWidth(220); y = y - 44

  -- 二、提醒样式
  local sec2 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  sec2:SetPoint("TOPLEFT", 16, y); y = y - 22
  sec2:SetText(self.C .. "二、提醒样式" .. self.R)

  local c4 = MakeCheck(panel, "播放声音",
    function() return r.sound end, function(v) r.sound = v end)
  c4:SetPoint("TOPLEFT", 24, y); y = y - 28

  local sndCycle = MakeCycle(panel, HA.SOUNDS,
    function() return r.soundKit end, function(v) r.soundKit = v end, 150)
  sndCycle:SetPoint("TOPLEFT", 24, y)
  local sndLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sndLabel:SetPoint("LEFT", sndCycle, "RIGHT", 6, 0)
  sndLabel:SetText("默认提示音")
  y = y - 30

  local c5 = MakeCheck(panel, "屏幕边缘闪烁",
    function() return r.flash end, function(v) r.flash = v end)
  c5:SetPoint("TOPLEFT", 24, y); y = y - 28

  local s3 = MakeSlider(panel, "自动隐藏(秒)", 5, 60, 5,
    function() return r.duration end, function(v) r.duration = math.floor(v) end)
  s3:SetPoint("TOPLEFT", 24, y); s3:SetWidth(220); y = y - 44

  -- 三、多组闹钟
  local sec3 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  sec3:SetPoint("TOPLEFT", 16, y); y = y - 22
  sec3:SetText(self.C .. "三、多组闹钟" .. self.R)

  self._alarmTopY = y
  self:RebuildAlarmList()
end

function HA:RebuildAlarmList()
  local panel = self.optionsPanel
  local topY = self._alarmTopY or -360

  if self.alarmScroll then
    self.alarmScroll:Hide()
    self.alarmScroll:SetParent(nil)
    self.alarmScroll = nil
  end

  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, topY)
  scroll:SetSize(640, 320)
  local inner = CreateFrame("Frame", nil, scroll)
  scroll:SetScrollChild(inner)
  inner:SetWidth(620)
  self.alarmScroll = scroll
  self.alarmInner = inner

  local y = 0
  for i, a in ipairs(DB.alarms) do
    y = self:BuildAlarmRow(inner, a, i, y)
    y = y - 8
  end

  local add = CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
  add:SetSize(120, 24)
  add:SetPoint("TOPLEFT", 0, y)
  add:SetText("+ 添加闹钟")
  add:SetScript("OnClick", function()
    tinsert(DB.alarms, {
      name = "新闹钟", enabled = true, type = "interval",
      interval = 60, clock = "20:00", msg = "时间到！",
      sound = "ALARM_CLOCK_WARNING_3", flash = true,
    })
    HA:RebuildAlarmList()
  end)

  inner:SetHeight(math.max(120, -y + 40))
  scroll:SetVerticalScroll(0)
  scroll:UpdateScrollChildRect()
end

function HA:BuildAlarmRow(parent, a, i, y)
  local rowH = 60
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(620, rowH)
  row:SetPoint("TOPLEFT", 0, y)

  -- 分隔线
  local line = row:CreateTexture(nil, "BACKGROUND")
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 0, 0)
  line:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  line:SetColorTexture(0.3, 0.3, 0.3, 0.5)

  -- 启用
  local en = MakeCheck(row, "启用",
    function() return a.enabled end, function(v) a.enabled = v end)
  en:SetPoint("TOPLEFT", 0, -4)

  -- 名称
  local nameL = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  nameL:SetPoint("TOPLEFT", 70, -6); nameL:SetText("名称")
  local name = MakeEdit(row, 120, 20, a.name)
  name:SetPoint("TOPLEFT", 70, -20)
  name:SetScript("OnTextChanged", function() a.name = name:GetText() end)

  -- 类型
  local typeL = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  typeL:SetPoint("TOPLEFT", 200, -6); typeL:SetText("类型")
  local typeBtn = MakeCycle(row,
    { { value = "interval", label = "间隔(分钟)" }, { value = "clock", label = "每日定时" } },
    function() return a.type end,
    function(v) a.type = v; HA:RebuildAlarmList() end, 110)
  typeBtn:SetPoint("TOPLEFT", 200, -20)

  -- 参数（间隔分钟 / 每日 HH:MM）
  local paramL = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  paramL:SetPoint("TOPLEFT", 320, -6)
  local param = MakeEdit(row, 70, 20,
    a.type == "interval" and tostring(a.interval or 60) or (a.clock or "20:00"))
  param:SetPoint("TOPLEFT", 320, -20)
  if a.type == "interval" then
    paramL:SetText("分钟")
    param:SetScript("OnTextChanged", function() a.interval = tonumber(param:GetText()) or 60 end)
  else
    paramL:SetText("HH:MM")
    param:SetScript("OnTextChanged", function() a.clock = param:GetText() end)
  end

  -- 闪烁
  local fl = MakeCheck(row, "闪烁",
    function() return a.flash end, function(v) a.flash = v end)
  fl:SetPoint("TOPLEFT", 400, -4)

  -- 删除
  local del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  del:SetSize(60, 22)
  del:SetPoint("TOPRIGHT", -4, -4)
  del:SetText("删除")
  del:SetScript("OnClick", function()
    for j, b in ipairs(DB.alarms) do
      if b == a then tremove(DB.alarms, j); break end
    end
    HA:RebuildAlarmList()
  end)

  -- 第二行：提示语 + 提示音
  local msgL = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  msgL:SetPoint("TOPLEFT", 0, -38); msgL:SetText("提示语")
  local msg = MakeEdit(row, 420, 20, a.msg)
  msg:SetPoint("TOPLEFT", 50, -36)
  msg:SetScript("OnTextChanged", function() a.msg = msg:GetText() end)

  local snd = MakeCycle(row, HA.SOUNDS,
    function() return a.sound end, function(v) a.sound = v end, 130)
  snd:SetPoint("TOPLEFT", 480, -36)

  return y - rowH
end

function HA:OpenOptions()
  self:Print("正在打开「提醒与闹钟」设置…")
  local panel = self.optionsPanel
  if not panel then
    self:Print("设置面板尚未初始化，请先重载界面（/reload）。")
    return
  end
  if InterfaceOptionsFrame_OpenToCategory then
    pcall(InterfaceOptionsFrame_OpenToCategory, panel)
  elseif Settings and Settings.OpenToCategory then
    pcall(Settings.OpenToCategory, panel)
  else
    self:Print("请在游戏内「设置 → 插件 / 插件」里找到「" .. self.TITLE .. "」。")
  end
end

----------------------------------------
-- 初始化
----------------------------------------
function HA:Init()
  local root = _G.TeleportMenuDB
  if type(root) ~= "table" then root = {}; _G.TeleportMenuDB = root end
  root.HA = root.HA or {}
  self:MergeDefaults(root.HA, self.DEFAULTS)
  DB = root.HA

  self:BuildOptions()

  local now = GetTime()
  for _, a in ipairs(DB.alarms) do
    if not a.lastTrigger then a.lastTrigger = now end
  end

  C_Timer.NewTicker(1, function() HA:Tick() end)
  self:Print("已加载（传送菜单汉化版内置小工具）。输入 /ha 打开设置，/ha test 测试提醒。")
end

----------------------------------------
-- 事件监听
----------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then HA:Init() end
end)

-- 游戏菜单（ESC）出现时，在左侧加一个按钮，点击打开「提醒与闹钟」设置
hooksecurefunc("ToggleGameMenu", function()
  C_Timer.After(0, function() HA:PositionMenuButton() end)
end)

----------------------------------------
-- 斜杠命令
----------------------------------------
SLASH_HYDRATIONALARM1 = "/ha"
SLASH_HYDRATIONALARM2 = "/hydration"
SlashCmdList["HYDRATIONALARM"] = function(input)
  local msg = (input or ""):lower()
  msg = msg:gsub("^%s*(.-)%s*$", "%1")
  if msg == "test" then
    HA:Notify("测试提醒", "这是一条测试提醒，如果能看到弹窗并听到声音就成功啦！")
  elseif msg == "drink" then
    HA:Notify("该喝水啦", "手动触发：起来喝口水吧！")
  elseif msg == "list" then
    if not DB then HA:Print("插件尚未初始化，请先重载界面（/reload）。"); return end
    HA:Print("当前闹钟 " .. #DB.alarms .. " 个：")
    for i, a in ipairs(DB.alarms) do
      local info = a.type == "interval" and (a.interval .. " 分钟") or (a.clock or "?")
      HA:Print(i .. ". " .. (a.enabled and "[开]" or "[关]") .. (a.name or "?") .. " - " .. info)
    end
  elseif msg == "" or msg == "options" or msg == "config" or msg == "设置" then
    HA:OpenOptions()
  else
    HA:Print("用法：/ha 打开设置 | /ha test 测试 | /ha drink 喝水提醒 | /ha list 列出闹钟")
  end
end

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
  },
  reminder = {
    duration = 10,       -- 文字自动隐藏（秒）
    sound    = true,     -- 播放声音
    soundKit = "ALARM_CLOCK_WARNING_3",
  },
  alarms = {
    { name = "该休息了",   enabled = true,  type = "clock",    interval = 60,  clock = "22:00", msg = "休息时间到", sound = "ALARM_CLOCK_WARNING_1" },
    { name = "做世界任务", enabled = false, type = "interval", interval = 60,  clock = "20:00", msg = "该去做世界任务啦！", sound = "ALARM_CLOCK_WARNING_3" },
    { name = "收菜/邮件",  enabled = false, type = "interval", interval = 120, clock = "12:00", msg = "记得收菜、清邮件～", sound = "ALARM_CLOCK_WARNING_2" },
  },
  stats = {
    drinkTotal = 0,      -- 累计喝水提醒次数
    drinkToday = 0,      -- 今日喝水提醒次数
    todayKey   = "",     -- 今日日期（用于跨天重置）
    alarmTotal = 0,      -- 累计闹钟触发次数
    log        = {},     -- 最近记录：{ t = "时:分", txt = "内容" }
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
  f:SetSize(640, 100)
  f:SetPoint("TOP", UIParent, "TOP", 0, -90)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:Hide()

  -- 纯文字提醒：屏幕中上方一行文字，无背景、无按钮、无闪烁
  local txt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  txt:SetPoint("CENTER", f, "CENTER", 0, 0)
  txt:SetWidth(600)
  txt:SetJustifyH("CENTER")
  txt:SetJustifyV("MIDDLE")
  txt:SetWordWrap(true)
  txt:SetNonSpaceWrap(true)              -- 中文按字换行
  txt:SetTextColor(1, 0.92, 0.6, 1)      -- 暖黄色，醒目
  txt:SetFont(select(1, txt:GetFont()), 20, "OUTLINE")
  f.txt = txt

  -- 自动隐藏：用 OnUpdate 累计时间，稳妥可靠（不依赖 C_Timer.After，避免文字卡在屏幕上不消失）
  -- 隐藏的 Frame 不会触发 OnUpdate，所以不占 CPU；每次显示时从 0 重新计时。
  f._hideT   = 0
  f._hideDur = (DB and DB.reminder and DB.reminder.duration) or 10
  f:SetScript("OnShow", function(self)
    self._hideT   = 0
    self._hideDur = (DB and DB.reminder and DB.reminder.duration) or 10
  end)
  f:SetScript("OnUpdate", function(self, elapsed)
    self._hideT = self._hideT + elapsed
    if self._hideT >= self._hideDur then
      self:Hide()
    end
  end)

  self.reminder = f
end

-- 纯文字提醒：屏幕中上方显示一行文字，到时自动隐藏（无弹窗/按钮/闪烁）
function HA:Notify(titleText, message, soundKey)
  self:CreateReminderFrame()
  local f = self.reminder
  local full = self.C .. (titleText or "提醒") .. self.R .. "：" .. (message or "")
  f.txt:SetText(full)
  f:Show()
  f._hideT   = 0   -- 每次新提醒都从 0 重新倒计时
  f._hideDur = (DB and DB.reminder and DB.reminder.duration) or 10
  self:PlayAlarm(soundKey)
end

----------------------------------------
-- 提醒逻辑
----------------------------------------
function HA:TodayKey()
  if not C_DateAndTime or not C_DateAndTime.GetCurrentCalendarTime then return "" end
  local t = C_DateAndTime.GetCurrentCalendarTime()
  if not t then return "" end
  return string.format("%04d-%02d-%02d", t.year or 0, t.month or 0, t.monthDay or 0)
end

function HA:NowText()
  if not C_DateAndTime or not C_DateAndTime.GetCurrentCalendarTime then return "" end
  local t = C_DateAndTime.GetCurrentCalendarTime()
  if not t then return "" end
  return string.format("%02d:%02d", t.hour or 0, t.minute or 0)
end

-- 记录触发（用于「记录统计」分页）
function HA:Record(kind, titleText, message)
  if not DB or not DB.stats then return end
  local s = DB.stats
  local key = self:TodayKey()
  if s.todayKey ~= key then s.todayKey = key; s.drinkToday = 0 end
  if kind == "drink" then
    s.drinkTotal = (s.drinkTotal or 0) + 1
    s.drinkToday = (s.drinkToday or 0) + 1
  else
    s.alarmTotal = (s.alarmTotal or 0) + 1
  end
  s.log = s.log or {}
  tinsert(s.log, 1, { t = self:NowText(), txt = (titleText or "") .. "：" .. (message or "") })
  while #s.log > 30 do tremove(s.log) end
end

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
    self:Record("drink", "该喝水啦", "你已经连续玩了 " .. d.interval .. " 分钟，起来喝口水")
  end
end

function HA:FireAlarm(a)
  a.lastTrigger = GetTime()
  self:Notify("闹钟 · " .. (a.name or "提醒"), a.msg or "时间到！", a.sound)
  self:Record("alarm", "闹钟 · " .. (a.name or "提醒"), a.msg or "时间到！")
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
    self:Notify("闹钟 · " .. (a.name or "提醒"), a.msg or "时间到！", a.sound)
    self:Record("alarm", "闹钟 · " .. (a.name or "提醒"), a.msg or "时间到！")
  elseif curKey ~= target then
    self._clockState[a.name] = nil
  end
end

function HA:Tick()
  if not DB then return end
  self:CheckDrink()
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

function HA:BuildFrame()
  if self.frame then return end
  local f = CreateFrame("Frame", "HydrationAlarmFrame", UIParent, "BackdropTemplate")
  f:SetSize(480, 560)
  f:SetPoint("CENTER", UIParent, "CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 24, tile = false,
    insets   = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  f:SetBackdropColor(0.08, 0.12, 0.18, 0.97)
  f:SetBackdropBorderColor(0.31, 0.76, 0.97, 1)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText(self.C .. "提醒与闹钟" .. self.R .. "  ·  传送菜单汉化版小工具")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  local tabRow = CreateFrame("Frame", nil, f)
  tabRow:SetSize(480, 28)
  tabRow:SetPoint("TOP", 0, -38)
  self.tabs = {}
  local function MakeTab(idx, text)
    local b = CreateFrame("Button", nil, tabRow, "UIPanelButtonTemplate")
    b:SetSize(140, 24)
    b:SetText(text)
    b:SetPoint("TOP", tabRow, "TOP", (idx - 2) * 150, 0)
    b:SetScript("OnClick", function() HA:SetTab(idx) end)
    self.tabs[idx] = b
  end
  MakeTab(1, "喝水提醒")
  MakeTab(2, "多组闹钟")
  MakeTab(3, "记录统计")

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", 12, -72)
  content:SetPoint("BOTTOMRIGHT", -12, 12)
  self.content = content

  local drinkPage = CreateFrame("Frame", nil, content); drinkPage:SetAllPoints(content)
  local alarmPage = CreateFrame("Frame", nil, content); alarmPage:SetAllPoints(content)
  local statsPage = CreateFrame("Frame", nil, content); statsPage:SetAllPoints(content)
  self.drinkPage = drinkPage
  self.alarmPage = alarmPage
  self.statsPage = statsPage

  self:BuildDrinkPage(drinkPage)
  self:BuildAlarmPage(alarmPage)
  self:BuildStatsPage(statsPage)
  self.frame = f
  self:SetTab(1)
end

function HA:SetTab(idx)
  if not self.frame then return end
  self.activeTab = idx
  for i, b in ipairs(self.tabs) do
    b:SetNormalFontObject(idx == i and "GameFontNormal" or "GameFontHighlight")
  end
  self.drinkPage:SetShown(idx == 1)
  self.alarmPage:SetShown(idx == 2)
  self.statsPage:SetShown(idx == 3)
  if idx == 3 and self.RefreshStats then self:RefreshStats() end
end

function HA:BuildDrinkPage(p)
  local d = DB.drink
  local r = DB.reminder
  local y = -14

  local sec1 = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  sec1:SetPoint("TOPLEFT", 8, y); sec1:SetText(self.C .. "喝水提醒" .. self.R); y = y - 36

  local c1 = MakeCheck(p, "启用定时喝水提醒（每 N 分钟提醒一次）",
    function() return d.enabled end, function(v) d.enabled = v end)
  c1:SetPoint("TOPLEFT", 16, y); y = y - 38

  local s1 = MakeSlider(p, "间隔(分钟)", 10, 120, 5,
    function() return d.interval end, function(v) d.interval = math.floor(v) end)
  s1:SetPoint("TOPLEFT", 16, y); s1:SetWidth(240); y = y - 50

  local c2 = MakeCheck(p, "仅脱战时提醒（战斗中不弹出）",
    function() return d.combatOnly end, function(v) d.combatOnly = v end)
  c2:SetPoint("TOPLEFT", 16, y); y = y - 38

  local sec2 = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  sec2:SetPoint("TOPLEFT", 8, y); sec2:SetText(self.C .. "提醒样式" .. self.R); y = y - 36

  local c4 = MakeCheck(p, "播放声音",
    function() return r.sound end, function(v) r.sound = v end)
  c4:SetPoint("TOPLEFT", 16, y); y = y - 38

  local sndCycle = MakeCycle(p, HA.SOUNDS,
    function() return r.soundKit end, function(v) r.soundKit = v end, 160)
  sndCycle:SetPoint("TOPLEFT", 16, y)
  local sndLabel = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sndLabel:SetPoint("LEFT", sndCycle, "RIGHT", 8, 0); sndLabel:SetText("默认提示音")
  y = y - 38

  local s3 = MakeSlider(p, "自动隐藏(秒)", 5, 60, 5,
    function() return r.duration end, function(v) r.duration = math.floor(v) end)
  s3:SetPoint("TOPLEFT", 16, y); s3:SetWidth(240); y = y - 50

  local testBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  testBtn:SetSize(160, 26)
  testBtn:SetPoint("TOPLEFT", 16, y)
  testBtn:SetText("测试文字提醒")
  testBtn:SetScript("OnClick", function()
    HA:Notify("测试提醒", "如果屏幕中上方出现这行文字并听到声音，说明提醒功能正常！")
  end)
end

function HA:BuildStatsPage(p)
  local head = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  head:SetPoint("TOPLEFT", 8, -14)
  head:SetText(self.C .. "喝水提醒 / 闹钟 · 记录与统计" .. self.R)

  local sum = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  sum:SetPoint("TOPLEFT", 8, -48)
  sum:SetJustifyH("LEFT")
  sum:SetWidth(440)
  sum:SetWordWrap(true)
  self.statsSummary = sum

  local logTitle = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  logTitle:SetPoint("TOPLEFT", 8, -128)
  logTitle:SetText(self.C .. "最近记录（最多 30 条）" .. self.R)

  local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -154)
  scroll:SetPoint("BOTTOMRIGHT", -24, 4)
  local inner = CreateFrame("Frame", nil, scroll)
  scroll:SetScrollChild(inner)
  inner:SetWidth(420)
  self.statsScroll = scroll
  self.statsInner = inner
  self:RefreshStats()
end

function HA:RefreshStats()
  if not self.statsSummary then return end
  local s = DB.stats or {}
  local today = self:TodayKey()
  local line = string.format(
    "累计喝水提醒：%d 次    今日：%d 次\n累计闹钟触发：%d 次    日期：%s",
    s.drinkTotal or 0,
    (s.todayKey == today and (s.drinkToday or 0) or 0),
    s.alarmTotal or 0,
    (today ~= "" and today or "—"))
  self.statsSummary:SetText(line)

  if self.statsRows then
    for _, r in ipairs(self.statsRows) do r:Hide(); r:SetParent(nil) end
  end
  self.statsRows = {}
  local inner = self.statsInner
  if not inner then return end
  local y = 0
  local log = s.log or {}
  if #log == 0 then
    local none = inner:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    none:SetPoint("TOPLEFT", 0, y)
    none:SetText("（暂无记录，触发提醒后会自动累计）")
    tinsert(self.statsRows, none)
  else
    for _, e in ipairs(log) do
      local t = inner:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      t:SetPoint("TOPLEFT", 0, y)
      t:SetWidth(400)
      t:SetJustifyH("LEFT")
      t:SetText("· " .. (e.t or "") .. "    " .. (e.txt or ""))
      y = y - 18
      tinsert(self.statsRows, t)
    end
  end
  inner:SetHeight(math.max(60, -y + 20))
  if self.statsScroll then
    self.statsScroll:SetVerticalScroll(0)
    self.statsScroll:UpdateScrollChildRect()
  end
end

function HA:BuildAlarmPage(p)
  local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -24, 4)
  local inner = CreateFrame("Frame", nil, scroll)
  scroll:SetScrollChild(inner)
  inner:SetWidth(420)
  self.alarmScroll = scroll
  self.alarmInner = inner
  self:RebuildAlarmList()
end

function HA:RebuildAlarmList()
  local inner = self.alarmInner
  if not inner then return end

  if self.alarmRows then
    for _, row in ipairs(self.alarmRows) do row:Hide(); row:SetParent(nil) end
  end
  self.alarmRows = {}

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
      name = "该休息了", enabled = true, type = "clock",
      interval = 60, clock = "22:00", msg = "休息时间到",
      sound = "ALARM_CLOCK_WARNING_1",
    })
    HA:RebuildAlarmList()
  end)
  tinsert(self.alarmRows, add)

  inner:SetHeight(math.max(120, -y + 40))
  if self.alarmScroll then
    self.alarmScroll:SetVerticalScroll(0)
    self.alarmScroll:UpdateScrollChildRect()
  end
end

function HA:BuildAlarmRow(parent, a, i, y)
  local rowH = 84
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(420, rowH)
  row:SetPoint("TOPLEFT", 0, y)

  -- 分隔线
  local line = row:CreateTexture(nil, "BACKGROUND")
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 0, 1)
  line:SetPoint("RIGHT", row, "RIGHT", 0, 1)
  line:SetColorTexture(0.3, 0.3, 0.3, 0.5)

  -- 第一行：启用 / 名称 / 类型 / 参数 / 删除
  local en = MakeCheck(row, "启用",
    function() return a.enabled end, function(v) a.enabled = v end)
  en:SetPoint("TOPLEFT", 0, -4)

  local nameL = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  nameL:SetPoint("TOPLEFT", 64, -6); nameL:SetText("名称")
  local name = MakeEdit(row, 110, 20, a.name)
  name:SetPoint("TOPLEFT", 64, -20)
  name:SetScript("OnTextChanged", function() a.name = name:GetText() end)

  local typeL = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  typeL:SetPoint("TOPLEFT", 188, -6); typeL:SetText("类型")
  local typeBtn = MakeCycle(row,
    { { value = "interval", label = "间隔(分)" }, { value = "clock", label = "按时间" } },
    function() return a.type end,
    function(v) a.type = v; HA:RebuildAlarmList() end, 84)
  typeBtn:SetPoint("TOPLEFT", 188, -20)

  -- 参数：间隔 = 分钟框；按时间 = 时 + 分 两个框
  local paramL = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  paramL:SetPoint("TOPLEFT", 284, -6)
  if a.type == "interval" then
    paramL:SetText("分钟")
    local param = MakeEdit(row, 56, 20, tostring(a.interval or 60))
    param:SetPoint("TOPLEFT", 284, -20)
    param:SetScript("OnTextChanged", function() a.interval = tonumber(param:GetText()) or 60 end)
  else
    paramL:SetText("时 : 分")
    local hh = a.clock and a.clock:match("^(%d+)") or "22"
    local mm = a.clock and a.clock:match(":(%d+)$") or "00"
    local he = MakeEdit(row, 40, 20, hh)
    he:SetPoint("TOPLEFT", 284, -20)
    local me = MakeEdit(row, 40, 20, mm)
    me:SetPoint("TOPLEFT", 330, -20)
    local function saveClock()
      local h = tonumber(he:GetText()) or 0
      local m = tonumber(me:GetText()) or 0
      if h < 0 then h = 0 end
      if h > 23 then h = 23 end
      if m < 0 then m = 0 end
      if m > 59 then m = 59 end
      a.clock = string.format("%02d:%02d", h, m)
    end
    he:SetScript("OnTextChanged", saveClock)
    me:SetScript("OnTextChanged", saveClock)
  end

  local del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  del:SetSize(56, 22)
  del:SetPoint("TOPRIGHT", -2, -4)
  del:SetText("删除")
  del:SetScript("OnClick", function()
    for j, b in ipairs(DB.alarms) do
      if b == a then tremove(DB.alarms, j); break end
    end
    HA:RebuildAlarmList()
  end)

  -- 第二行：提示语 / 提示音
  local msgL = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  msgL:SetPoint("TOPLEFT", 64, -46); msgL:SetText("提示语")
  local msg = MakeEdit(row, 250, 20, a.msg)
  msg:SetPoint("TOPLEFT", 64, -60)
  msg:SetScript("OnTextChanged", function() a.msg = msg:GetText() end)

  local snd = MakeCycle(row, HA.SOUNDS,
    function() return a.sound end, function(v) a.sound = v end, 92)
  snd:SetPoint("TOPLEFT", 322, -60)

  tinsert(self.alarmRows, row)
  return y - rowH
end

function HA:OpenOptions()
  if not self.frame then self:BuildFrame() end
  self:Print("已打开「提醒与闹钟」设置窗口。")
  self.frame:Show()
  pcall(function() self.frame:Raise() end)
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

  self:BuildFrame()

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
    HA:Notify("测试提醒", "这是一条测试提醒，屏幕中上方会出现这行文字并播放声音！")
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

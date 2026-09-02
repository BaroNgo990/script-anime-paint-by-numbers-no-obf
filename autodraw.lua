-- AutoDraw V25: STATUS HUD + PERFECT FILTER + ALL-IN-ONE + SMART BUYER - cook45
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local lp = Players.LocalPlayer
local TILE_SIZE = 1.3

-- ================= THÔNG SỐ KỸ THUẬT & TRẠNG THÁI =================
local Config = {
    UseTP = false,    
    SpeedFar = 500,   
    SpeedNear = 500,  
    TweenDelay = 0.02,
    TpDelay = 0.01    
}

local Stats = {
    StartTime = tick(),
    Tiles = 0,
    Pics = 0,
    Action = "Đang rảnh rỗi (Idle)",
    Anime = "N/A",
    Char = "N/A",
    ProgIdx = 0,
    ProgTotal = 0
}

local selectedCategories = {["All"] = true}
local categoryButtons = {}

local AutoDrawRunning = false
local ESP_ACTIVE = false
local ESP_FOLDER_NAME = "Cook45_ESP"

-- ================= ANTI-AFK =================
lp.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- ================= LẤY DANH SÁCH ANIME =================
local categories = {}
pcall(function()
    local cList = require(RS.Shared.Config.Categories).List
    for _, v in ipairs(cList) do table.insert(categories, v) end
end)
if #categories == 0 then categories = {"All"} end

-- ================= HỆ THỐNG ESP X-RAY =================
local function ClearESP()
    local folder = workspace:FindFirstChild(ESP_FOLDER_NAME)
    if folder then folder:Destroy() end
end

local function UpdateESP()
    ClearESP()
    if not ESP_ACTIVE then return end
    
    local wo = lp:GetAttribute("WorkingOn")
    local base = wo and workspace.Bases:FindFirstChild(wo)
    local bp = base and (base.PrimaryPart or base:FindFirstChild("Base"))
    local mapId = base and base:GetAttribute("CurrentMap")
    local targetColor = lp:GetAttribute("CurrentColor") 
    if not (base and bp and mapId and targetColor) then return end
    
    local imgMod = RS.ImageInfo:FindFirstChild(tostring(mapId))
    if not imgMod then return end
    local mapData = require(imgMod)
    local W, H = mapData.width, mapData.height
    
    local pixels = HttpService:JSONDecode(base:GetAttribute("ImageData"))
    local progBuf = HttpService:JSONDecode(base:GetAttribute("Progress"))
    
    local folder = Instance.new("Folder", workspace)
    folder.Name = ESP_FOLDER_NAME
    local fixedY = bp.Position.Y + 0.55
    
    for row = 0, H - 1 do
        for col = 0, W - 1 do
            local pxIdx = row * W + col + 1
            if pixels[pxIdx] + 1 == targetColor then
                local painted = buffer.readbits(progBuf, pxIdx - 1, 1) == 1
                local offsetX = (math.floor(W / 2) - col - 0.5) * TILE_SIZE
                local offsetZ = (math.floor(H / 2) - row - 0.5) * TILE_SIZE
                local targetCFrame = bp.CFrame * CFrame.new(offsetX, 0, offsetZ)
                
                local p = Instance.new("Part")
                p.Size = Vector3.new(1.3, 0.05, 1.3); p.Position = Vector3.new(targetCFrame.Position.X, fixedY, targetCFrame.Position.Z)
                p.Anchored = true; p.CanCollide = false; p.Transparency = 1; p.Parent = folder
                
                local box = Instance.new("BoxHandleAdornment")
                box.Name = "XRayESP"; box.Size = Vector3.new(1.25, 0.1, 1.25) 
                box.Adornee = p; box.AlwaysOnTop = true; box.ZIndex = 10
                
                if not painted then box.Color3 = Color3.fromRGB(50, 255, 50); box.Transparency = 0.4
                else box.Color3 = Color3.fromRGB(255, 50, 50); box.Transparency = 0 end
                box.Parent = p
            end
        end
    end
end

lp:GetAttributeChangedSignal("CurrentColor"):Connect(function() if ESP_ACTIVE then UpdateESP() end end)

-- ================= HỆ THỐNG AUTO TÔ =================
local lblStatusUpdate -- Forward declare
local function UpdateStatus(act)
    if act then Stats.Action = act end
    if lblStatusUpdate then lblStatusUpdate() end
end

local function CorePaint(targetColor)
    local MAX_PASS = 15
    local passCount = 1
    
    while AutoDrawRunning and passCount <= MAX_PASS do
        local wo = lp:GetAttribute("WorkingOn")
        local base = workspace.Bases:FindFirstChild(wo)
        local bp = base and (base.PrimaryPart or base:FindFirstChild("Base"))
        local mapId = base and base:GetAttribute("CurrentMap")
        if not (base and bp and mapId) then return false end
        
        local imgMod = RS.ImageInfo:FindFirstChild(tostring(mapId))
        local mapData = require(imgMod)
        local W, H = mapData.width, mapData.height
        
        local pixels = HttpService:JSONDecode(base:GetAttribute("ImageData"))
        local progBuf = HttpService:JSONDecode(base:GetAttribute("Progress"))
        
        local tiles = {}
        for row = 0, H - 1 do
            for col = 0, W - 1 do
                local pxIdx = row * W + col + 1
                if pixels[pxIdx] + 1 == targetColor then
                    if buffer.readbits(progBuf, pxIdx - 1, 1) == 0 then
                        local offsetX = (math.floor(W / 2) - col - 0.5) * TILE_SIZE
                        local offsetZ = (math.floor(H / 2) - row - 0.5) * TILE_SIZE
                        local targetCFrame = bp.CFrame * CFrame.new(offsetX, 0, offsetZ)
                        table.insert(tiles, {c = col, r = row, wx = targetCFrame.Position.X, wz = targetCFrame.Position.Z})
                    end
                end
            end
        end
        
        if #tiles == 0 then return true end

        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        if hrp and hum then
            local sortedTiles = {}
            local currPos = Vector2.new(hrp.Position.X, hrp.Position.Z)
            
            if #tiles > 3000 then
                for _, t in ipairs(tiles) do t.dist = (Vector2.new(t.wx, t.wz) - currPos).Magnitude end
                table.sort(tiles, function(a, b) return a.dist < b.dist end)
                sortedTiles = tiles
            else
                while #tiles > 0 do
                    local bestIdx = 1; local bestDist = math.huge
                    for i, t in ipairs(tiles) do
                        local d = (t.wx - currPos.X)^2 + (t.wz - currPos.Y)^2
                        if d < bestDist then bestDist = d; bestIdx = i end
                    end
                    table.insert(sortedTiles, table.remove(tiles, bestIdx))
                    currPos = Vector2.new(sortedTiles[#sortedTiles].wx, sortedTiles[#sortedTiles].wz)
                end
            end
            
            local safeY = hrp.Position.Y 
            local oldSpd = hum.WalkSpeed
            hum.WalkSpeed = 0 
            
            local activeFar = Config.SpeedFar
            local activeNear = Config.SpeedNear
            if passCount >= 3 then
                activeFar = math.min(Config.SpeedFar, 150); activeNear = math.min(Config.SpeedNear, 80)
            end
            
            for _, t in ipairs(sortedTiles) do
                if not AutoDrawRunning then pcall(function() hum.WalkSpeed = oldSpd end) return false end
                if not (char and hrp.Parent) then return false end
                
                if Config.UseTP then
                    hrp.CFrame = CFrame.new(t.wx, safeY, t.wz)
                    local currentDelay = Config.TpDelay
                    if passCount >= 3 then currentDelay = math.max(0.04, Config.TpDelay * 2) end
                    if currentDelay > 0 then task.wait(currentDelay) else task.wait() end
                else
                    local dist = (Vector2.new(t.wx, t.wz) - Vector2.new(hrp.Position.X, hrp.Position.Z)).Magnitude
                    local currentSpeed = (dist > 3.5) and activeFar or activeNear
                    local tweenTime = math.max(0.01, dist / currentSpeed) 
                    
                    local tween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {CFrame = CFrame.new(t.wx, safeY, t.wz)})
                    tween:Play()
                    tween.Completed:Wait() 
                    task.wait(Config.TweenDelay)
                end
                
                Stats.Tiles = Stats.Tiles + 1
                if Stats.Tiles % 10 == 0 then UpdateStatus() end
            end
            pcall(function() hum.WalkSpeed = oldSpd end)
            passCount = passCount + 1
            task.wait(0.5) 
        else
            break
        end
    end
    return true
end

-- ================= HỆ THỐNG RUNNER =================
local function ResetUI()
    local gui = lp.PlayerGui:FindFirstChild("AutoDrawRaw")
    if gui and gui:FindFirstChild("Frame") then
        local f = gui.Frame
        if f:FindFirstChild("BtnDraw") then f.BtnDraw.Text = "▶ START 1 MÀU"; f.BtnDraw.BackgroundColor3 = Color3.fromRGB(20, 20, 25) end
        if f:FindFirstChild("BtnFarm") then f.BtnFarm.Text = "🔥 AUTO 1 TRANH"; f.BtnFarm.BackgroundColor3 = Color3.fromRGB(20, 20, 25) end
        if f:FindFirstChild("BtnFarmAll") then f.BtnFarmAll.Text = "🌟 AUTO ALL (L: Bật | R: Chọn)"; f.BtnFarmAll.BackgroundColor3 = Color3.fromRGB(50, 20, 70) end
    end
    UpdateStatus("Đang rảnh rỗi (Đã dừng)")
end

local function RunSingleColor()
    AutoDrawRunning = true
    UpdateStatus("Đang tô 1 màu...")
    local targetColor = lp:GetAttribute("CurrentColor")
    if targetColor then CorePaint(targetColor) end
    AutoDrawRunning = false; ResetUI()
end

local function RunAutoFarm()
    AutoDrawRunning = true
    UpdateStatus("Đang farm 1 bức...")
    local wo = lp:GetAttribute("WorkingOn")
    local base = wo and workspace.Bases:FindFirstChild(wo)
    local mapId = base and base:GetAttribute("CurrentMap")
    
    if base and mapId then
        local imgMod = RS.ImageInfo:FindFirstChild(tostring(mapId))
        local mapData = require(imgMod)
        Stats.Anime = mapData.category; Stats.Char = mapData.name; UpdateStatus()
        
        for c = 1, #mapData.colors do
            if not AutoDrawRunning then break end
            local progBuf = HttpService:JSONDecode(base:GetAttribute("Progress"))
            local pixels = HttpService:JSONDecode(base:GetAttribute("ImageData"))
            local hasUnpainted = false
            for i = 1, #pixels do
                if pixels[i] + 1 == c and buffer.readbits(progBuf, i - 1, 1) == 0 then hasUnpainted = true; break end
            end
            if hasUnpainted then
                lp:SetAttribute("CurrentColor", c)
                pcall(function() require(RS.Client.ClientNetwork).ChangeColor.Fire(c) end)
                task.wait(0.5)
                UpdateStatus("Đang tô màu " .. c)
                if not CorePaint(c) then break end
            end
        end
        if AutoDrawRunning then Stats.Pics = Stats.Pics + 1 end
    end
    AutoDrawRunning = false; ResetUI()
end

local function RunAutoFarmAll()
    AutoDrawRunning = true
    UpdateStatus("Đang quét danh sách map...")
    local Globals = require(RS.UI.Globals)
    local Fusion = require(RS.Packages.Fusion)
    local ClientNetwork = require(RS.Client.ClientNetwork)
    
    local mapDataCache = {}
    local allMaps = {}
    
    -- Lọc KHÉP KÍN chống tràn ID
    local isAllMode = selectedCategories["All"] == true
    for _, v in ipairs(RS.ImageInfo:GetChildren()) do
        local mData = require(v)
        local cName = tostring(mData.category)
        if isAllMode or selectedCategories[cName] == true then
            table.insert(allMaps, mData.id)
            mapDataCache[mData.id] = mData.totalInstances or 999999
        end
    end
    
    Stats.ProgTotal = #allMaps
    
    local ownedInit = HttpService:JSONDecode(lp:GetAttribute("OwnedPictures") or "{}")
    table.sort(allMaps, function(a, b)
        local ownsA = ownedInit[tostring(a)] and 1 or 0
        local ownsB = ownedInit[tostring(b)] and 1 or 0
        if ownsA ~= ownsB then return ownsA > ownsB end
        return mapDataCache[a] < mapDataCache[b]
    end)
    
    for idx, mapId in ipairs(allMaps) do
        if not AutoDrawRunning then break end
        Stats.ProgIdx = idx
        
        local completed = Fusion.peek(Globals.completedMapsVal)
        if not completed[tostring(mapId)] and not completed[mapId] then
            local mapData = require(RS.ImageInfo:FindFirstChild(tostring(mapId)))
            Stats.Anime = mapData.category; Stats.Char = mapData.name
            
            local ownedDynamic = HttpService:JSONDecode(lp:GetAttribute("OwnedPictures") or "{}")
            local isOwned = ownedDynamic[tostring(mapId)]
            
            if not isOwned then
                local points = lp:GetAttribute("Points") or 0
                local cost = math.floor(mapDataCache[mapId] / 7) 
                if points < cost then 
                    UpdateStatus("Bỏ qua " .. mapData.name .. " (Không đủ " .. cost .. "$)")
                    task.wait(0.5)
                    continue 
                end
            end
            
            UpdateStatus("Đang Load/Mua Map: " .. mapData.name)
            pcall(function() ClientNetwork.ChangeMap.Fire(mapId) end)
            
            local base, newMapId
            local timeout = tick() + 6
            while tick() < timeout and AutoDrawRunning do
                local wo = lp:GetAttribute("WorkingOn")
                base = wo and workspace.Bases:FindFirstChild(wo)
                newMapId = base and base:GetAttribute("CurrentMap")
                if newMapId == mapId and base:GetAttribute("ImageData") then break end
                task.wait(0.5)
            end
            
            if newMapId == mapId then
                task.wait(1)
                for c = 1, #mapData.colors do
                    if not AutoDrawRunning then break end
                    local progBuf = HttpService:JSONDecode(base:GetAttribute("Progress"))
                    local pixels = HttpService:JSONDecode(base:GetAttribute("ImageData"))
                    local hasUnpainted = false
                    for i = 1, #pixels do
                        if pixels[i] + 1 == c and buffer.readbits(progBuf, i - 1, 1) == 0 then hasUnpainted = true; break end
                    end
                    if hasUnpainted then
                        lp:SetAttribute("CurrentColor", c)
                        pcall(function() ClientNetwork.ChangeColor.Fire(c) end)
                        task.wait(0.5)
                        UpdateStatus("Đang tô màu " .. c)
                        if not CorePaint(c) then break end
                    end
                end
                task.wait(2)
                if AutoDrawRunning then Stats.Pics = Stats.Pics + 1 end
            end
        end
    end
    AutoDrawRunning = false; ResetUI()
end

-- ================= GIAO DIỆN CHÍNH =================
if lp.PlayerGui:FindFirstChild("AutoDrawRaw") then lp.PlayerGui.AutoDrawRaw:Destroy() end
local sg = Instance.new("ScreenGui", lp.PlayerGui)
sg.Name = "AutoDrawRaw"
sg.ResetOnSpawn = false

local frame = Instance.new("Frame", sg)
frame.Name = "Frame"
frame.Size = UDim2.new(0, 220, 0, 310)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundTransparency = 1

local function MakeBtn(parent, name, text, posY, color)
    local btn = Instance.new("TextButton", parent)
    btn.Name = name; btn.Size = UDim2.new(1, 0, 0, 40); btn.Position = UDim2.new(0, 0, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25); btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 12; btn.Font = Enum.Font.GothamBold; btn.Text = text
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local uis = Instance.new("UIStroke", btn)
    uis.Color = color; uis.Thickness = 2
    return btn
end

local btnDraw = MakeBtn(frame, "BtnDraw", "▶ START 1 MÀU", 0, Color3.fromRGB(255, 180, 50))
local btnFarm = MakeBtn(frame, "BtnFarm", "🔥 AUTO 1 TRANH", 48, Color3.fromRGB(255, 50, 50))
local btnFarmAll = MakeBtn(frame, "BtnFarmAll", "🌟 AUTO ALL (L:Bật|R:Chọn)", 96, Color3.fromRGB(200, 50, 255))
btnFarmAll.BackgroundColor3 = Color3.fromRGB(50, 20, 70)
local btnEsp = MakeBtn(frame, "BtnEsp", "👁 BẬT ESP", 144, Color3.fromRGB(50, 255, 100))
local btnSet = MakeBtn(frame, "BtnSet", "⚙ CÀI ĐẶT TỐC ĐỘ", 192, Color3.fromRGB(100, 200, 255))
local btnStat = MakeBtn(frame, "BtnStat", "📊 BẬT BẢNG STATUS", 240, Color3.fromRGB(255, 150, 200))

-- MENU CHỌN ANIME
local catFrame = Instance.new("Frame", sg)
catFrame.Size = UDim2.new(0, 200, 0, 300); catFrame.Position = UDim2.new(0, 250, 0, 20)
catFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30); catFrame.Visible = false
Instance.new("UICorner", catFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", catFrame).Color = Color3.fromRGB(200, 50, 255); catFrame:FindFirstChildOfClass("UIStroke").Thickness = 2

local catTitle = Instance.new("TextLabel", catFrame)
catTitle.Size = UDim2.new(1, 0, 0, 30); catTitle.Text = " Anime: All"; catTitle.TextColor3 = Color3.new(1, 1, 1)
catTitle.BackgroundTransparency = 1; catTitle.Font = Enum.Font.GothamBold; catTitle.TextSize = 13; catTitle.TextXAlignment = Enum.TextXAlignment.Left

local scroll = Instance.new("ScrollingFrame", catFrame)
scroll.Size = UDim2.new(1, 0, 1, -30); scroll.Position = UDim2.new(0, 0, 0, 30)
scroll.CanvasSize = UDim2.new(0, 0, 0, #categories * 30); scroll.ScrollBarThickness = 4; scroll.BackgroundTransparency = 1
local uiList = Instance.new("UIListLayout", scroll)

local function UpdateCategoryUI()
    local count = 0; local lastName = ""
    for k, v in pairs(selectedCategories) do if v then count = count + 1; lastName = k end end
    if count == 0 then selectedCategories = {["All"] = true}; count = 1; lastName = "All" end
    
    if selectedCategories["All"] then catTitle.Text = " Anime: All"
    elseif count == 1 then catTitle.Text = " Anime: " .. lastName
    else catTitle.Text = " Anime: " .. count .. " Selected" end
    
    for name, btn in pairs(categoryButtons) do
        if selectedCategories[name] then btn.BackgroundColor3 = Color3.fromRGB(80, 40, 120)
        else btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40) end
    end
end

for _, catName in ipairs(categories) do
    local btn = Instance.new("TextButton", scroll)
    btn.Size = UDim2.new(1, 0, 0, 30); btn.Text = " " .. catName; btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 12; btn.TextXAlignment = Enum.TextXAlignment.Left
    categoryButtons[catName] = btn
    
    btn.MouseButton1Click:Connect(function()
        if catName == "All" then selectedCategories = {["All"] = true} else
            selectedCategories["All"] = nil
            selectedCategories[catName] = not selectedCategories[catName]
        end
        UpdateCategoryUI()
    end)
end
UpdateCategoryUI()

-- MENU CÀI ĐẶT TỐC ĐỘ
local setFrame = Instance.new("Frame", sg)
setFrame.Size = UDim2.new(0, 200, 0, 230); setFrame.Position = UDim2.new(0, 250, 0, 20)
setFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30); setFrame.Visible = false
Instance.new("UICorner", setFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", setFrame).Color = Color3.fromRGB(100, 200, 255); setFrame:FindFirstChildOfClass("UIStroke").Thickness = 2

local inputs = {}
local function CreateInput(y, text, defaultVal, configKey, isTpSetting)
    local lbl = Instance.new("TextLabel", setFrame)
    lbl.Size = UDim2.new(0.65, 0, 0, 30); lbl.Position = UDim2.new(0, 10, 0, y)
    lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.GothamSemibold; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", setFrame)
    box.Size = UDim2.new(0.25, 0, 0, 25); box.Position = UDim2.new(0.7, 0, 0, y + 2)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 45); box.TextColor3 = Color3.fromRGB(255, 255, 100)
    box.Text = tostring(defaultVal); box.Font = Enum.Font.GothamBold; box.TextSize = 12
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

    box.FocusLost:Connect(function()
        if not box.TextEditable then return end
        local num = tonumber(box.Text)
        if num then Config[configKey] = num else box.Text = tostring(Config[configKey]) end
    end)
    table.insert(inputs, {box = box, lbl = lbl, isTpSetting = isTpSetting})
end

CreateInput(10, "Tốc Độ Bay Xa:", Config.SpeedFar, "SpeedFar", false)
CreateInput(45, "Tốc Độ Lướt:", Config.SpeedNear, "SpeedNear", false)
CreateInput(80, "Delay Lướt (s):", Config.TweenDelay, "TweenDelay", false)

local btnToggleTP = Instance.new("TextButton", setFrame)
btnToggleTP.Size = UDim2.new(0.9, 0, 0, 35); btnToggleTP.Position = UDim2.new(0.05, 0, 0, 125)
btnToggleTP.Font = Enum.Font.GothamBold; btnToggleTP.TextSize = 13; btnToggleTP.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", btnToggleTP).CornerRadius = UDim.new(0, 6)

CreateInput(175, "Delay TP (s):", Config.TpDelay, "TpDelay", true)

local function UpdateSettingsUI()
    if Config.UseTP then
        btnToggleTP.Text = "CHẾ ĐỘ: TELEPORT"; btnToggleTP.BackgroundColor3 = Color3.fromRGB(150, 40, 200)
        for _, item in ipairs(inputs) do
            if not item.isTpSetting then
                item.box.TextEditable = false; item.box.TextColor3 = Color3.fromRGB(100, 100, 100); item.lbl.TextColor3 = Color3.fromRGB(100, 100, 100)
            else
                item.box.TextEditable = true; item.box.TextColor3 = Color3.fromRGB(255, 255, 100); item.lbl.TextColor3 = Color3.new(1, 1, 1)
            end
        end
    else
        btnToggleTP.Text = "CHẾ ĐỘ: LƯỚT TWEEN"; btnToggleTP.BackgroundColor3 = Color3.fromRGB(40, 150, 200)
        for _, item in ipairs(inputs) do
            if not item.isTpSetting then
                item.box.TextEditable = true; item.box.TextColor3 = Color3.fromRGB(255, 255, 100); item.lbl.TextColor3 = Color3.new(1, 1, 1)
            else
                item.box.TextEditable = false; item.box.TextColor3 = Color3.fromRGB(100, 100, 100); item.lbl.TextColor3 = Color3.fromRGB(100, 100, 100)
            end
        end
    end
end
btnToggleTP.MouseButton1Click:Connect(function() Config.UseTP = not Config.UseTP; UpdateSettingsUI() end)
UpdateSettingsUI()

-- BẢNG STATUS (HUD)
local statFrame = Instance.new("Frame", sg)
statFrame.Size = UDim2.new(0, 320, 0, 140); statFrame.Position = UDim2.new(0.5, -160, 0, 10)
statFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25); statFrame.Visible = false
Instance.new("UICorner", statFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", statFrame).Color = Color3.fromRGB(255, 150, 200); statFrame:FindFirstChildOfClass("UIStroke").Thickness = 2

local function MakeStatLbl(posY, defaultText, color)
    local l = Instance.new("TextLabel", statFrame)
    l.Size = UDim2.new(1, -20, 0, 20); l.Position = UDim2.new(0, 10, 0, posY)
    l.BackgroundTransparency = 1; l.Text = defaultText; l.TextColor3 = color
    l.Font = Enum.Font.GothamSemibold; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local lblTime = MakeStatLbl(10, "⏳ Thời gian: 00:00", Color3.fromRGB(255, 255, 255))
local lblInfo = MakeStatLbl(35, "🎬 Phim: N/A | Char: N/A (0/0)", Color3.fromRGB(150, 200, 255))
local lblTiles = MakeStatLbl(60, "🟩 Số ô đã quét qua: 0", Color3.fromRGB(100, 255, 100))
local lblPics = MakeStatLbl(85, "🖼️ Bức hoàn thành: 0", Color3.fromRGB(255, 200, 50))
local lblAct = MakeStatLbl(110, "⚙️ Trạng thái: Đang rảnh rỗi", Color3.fromRGB(255, 100, 100))

local function FormatTime(s)
    s = math.floor(s); local h = math.floor(s / 3600); local m = math.floor((s % 3600) / 60); local sec = s % 60
    if h > 0 then return string.format("%02d:%02d:%02d", h, m, sec) else return string.format("%02d:%02d", m, sec) end
end

task.spawn(function()
    while task.wait(1) do
        if statFrame.Visible then lblTime.Text = "⏳ Thời gian: " .. FormatTime(tick() - Stats.StartTime) end
    end
end)

lblStatusUpdate = function()
    if not statFrame.Visible then return end
    lblInfo.Text = "🎬 Phim: " .. Stats.Anime .. " | Char: " .. Stats.Char .. " (" .. Stats.ProgIdx .. "/" .. Stats.ProgTotal .. ")"
    lblTiles.Text = "🟩 Số ô đã quét qua: " .. Stats.Tiles
    lblPics.Text = "🖼️ Bức hoàn thành: " .. Stats.Pics
    lblAct.Text = "⚙️ Trạng thái: " .. Stats.Action
end

btnStat.MouseButton1Click:Connect(function()
    statFrame.Visible = not statFrame.Visible
    if statFrame.Visible then btnStat.Text = "📊 TẮT STATUS"; lblStatusUpdate()
    else btnStat.Text = "📊 BẬT BẢNG STATUS" end
end)

-- NỐI SỰ KIỆN MAIN
btnDraw.MouseButton1Click:Connect(function()
    if AutoDrawRunning then AutoDrawRunning = false; ResetUI() else
        btnDraw.Text = "■ DỪNG LẠI"; btnDraw.BackgroundColor3 = Color3.fromRGB(180, 30, 30); task.spawn(RunSingleColor)
    end
end)
btnFarm.MouseButton1Click:Connect(function()
    if AutoDrawRunning then AutoDrawRunning = false; ResetUI() else
        btnFarm.Text = "■ DỪNG AUTO FARM"; btnFarm.BackgroundColor3 = Color3.fromRGB(180, 30, 30); task.spawn(RunAutoFarm)
    end
end)
btnFarmAll.MouseButton1Click:Connect(function()
    if AutoDrawRunning then AutoDrawRunning = false; ResetUI() else
        btnFarmAll.Text = "■ DỪNG AUTO ALL"; btnFarmAll.BackgroundColor3 = Color3.fromRGB(180, 30, 30); task.spawn(RunAutoFarmAll)
    end
end)
btnFarmAll.MouseButton2Click:Connect(function() catFrame.Visible = not catFrame.Visible; setFrame.Visible = false end)
btnEsp.MouseButton1Click:Connect(function()
    ESP_ACTIVE = not ESP_ACTIVE
    if ESP_ACTIVE then btnEsp.Text = "👁 TẮT ESP"; btnEsp.BackgroundColor3 = Color3.fromRGB(40, 120, 60); UpdateESP()
    else btnEsp.Text = "👁 BẬT ESP SOI ĐƯỜNG"; btnEsp.BackgroundColor3 = Color3.fromRGB(20, 20, 25); ClearESP() end
end)
btnSet.MouseButton1Click:Connect(function() setFrame.Visible = not setFrame.Visible; catFrame.Visible = false end)

-- LocalScript: AdvancedVoiceControl
-- 配置場所: StarterPlayerScripts

local Players = game:GetService("Players")
local VoiceChatService = game:GetService("VoiceChatService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- 1. 設定と状態管理 (Configuration & State)
--------------------------------------------------------------------------------
local Config = {
    MyVolume = 1.0,           -- 自分の聞こえる音量倍率
    MyHearingDistance = 100,  -- 自分が音を聞ける最大距離 (Local Cutoff)
    GlobalVoiceRange = 50,    -- プレイヤー同士の声が届く物理的距離 (RollOffMaxDistance)
    IsMutedAll = false,       -- 全員ミュートフラグ
}

local mutedPlayers = {} -- 個別にミュートしたプレイヤーリスト

--------------------------------------------------------------------------------
-- 2. UI作成関数 (UI Construction)
--------------------------------------------------------------------------------
local function createUI()
    -- ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "VoiceMonitorUI"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 320, 0, 450)
    mainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true -- ドラッグ用
    mainFrame.Parent = gui

    -- 角丸
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = mainFrame

    -- Title Bar (ドラッグハンドル)
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar

    -- 下側の角丸を隠すためのパッチ
    local titlePatch = Instance.new("Frame")
    titlePatch.Size = UDim2.new(1, 0, 0, 10)
    titlePatch.Position = UDim2.new(0, 0, 1, -10)
    titlePatch.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    titlePatch.BorderSizePixel = 0
    titlePatch.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "🔊 ボイスチャット監視・制御"
    titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    titleLabel.Position = UDim2.new(0.05, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    -- 最小化ボタン
    local minBtn = Instance.new("TextButton")
    minBtn.Text = "-"
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -30, 0, 0)
    minBtn.BackgroundTransparency = 1
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 18
    minBtn.Parent = titleBar

    -- Scrolling Frame (コンテンツエリア)
    local contentScroll = Instance.new("ScrollingFrame")
    contentScroll.Size = UDim2.new(1, -10, 1, -40)
    contentScroll.Position = UDim2.new(0, 5, 0, 35)
    contentScroll.BackgroundTransparency = 1
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 6
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0) -- 自動調整用
    contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentScroll.Parent = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = contentScroll
    
    -- パディング
    local uiPadding = Instance.new("UIPadding")
    uiPadding.PaddingTop = UDim.new(0, 5)
    uiPadding.PaddingLeft = UDim.new(0, 5)
    uiPadding.PaddingRight = UDim.new(0, 5)
    uiPadding.Parent = contentScroll

    -- ヘルパー関数: セクション作成
    local function createSection(text, layoutOrder)
        local label = Instance.new("TextLabel")
        label.Text = text
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(150, 200, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.LayoutOrder = layoutOrder
        label.Parent = contentScroll
        return label
    end

    -- ヘルパー関数: スライダー作成
    local function createCustomSlider(name, min, max, default, layoutOrder, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.BackgroundTransparency = 1
        frame.LayoutOrder = layoutOrder
        frame.Parent = contentScroll

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Text = name
        nameLabel.Size = UDim2.new(1, 0, 0, 20)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = frame

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Text = tostring(default)
        valueLabel.Size = UDim2.new(1, 0, 0, 20)
        valueLabel.Position = UDim2.new(0, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.TextSize = 12
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = frame

        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(1, 0, 0, 6)
        sliderBg.Position = UDim2.new(0, 0, 0, 30)
        sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = frame
        local sliderCorner = Instance.new("UICorner"); sliderCorner.CornerRadius = UDim.new(1, 0); sliderCorner.Parent = sliderBg

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min)/(max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        fill.BorderSizePixel = 0
        fill.Parent = sliderBg
        local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(1, 0); fillCorner.Parent = fill

        local trigger = Instance.new("TextButton")
        trigger.Text = ""
        trigger.BackgroundTransparency = 1
        trigger.Size = UDim2.new(1, 0, 1, 0)
        trigger.Parent = sliderBg

        local isDragging = false

        local function update(input)
            local pos = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + (max - min) * pos)
            fill.Size = UDim2.new(pos, 0, 1, 0)
            valueLabel.Text = tostring(value)
            callback(value)
        end

        trigger.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = true
                update(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
    end

    -- === UI コンテンツ配置 ===

    -- セクション: 自分設定
    createSection("自分の設定 (MY SETTINGS)", 1)

    createCustomSlider("受信音量 (%)", 0, 400, 100, 2, function(val)
        Config.MyVolume = val / 100
    end)

    createCustomSlider("自分が聞こえる距離 (スタッド)", 10, 500, 100, 3, function(val)
        Config.MyHearingDistance = val
    end)

    -- セクション: 他プレイヤー・環境設定
    createSection("プレイヤー間の監視設定 (GLOBAL)", 4)

    createCustomSlider("声が届く物理距離 (RollOff)", 5, 200, 50, 5, function(val)
        Config.GlobalVoiceRange = val
        -- ※注意: これをサーバー全体に適用するにはRemoteEventが必要ですが、
        -- ここではローカルの視覚・聴覚効果として適用し、可能であればサーバーへ送信する形をとります。
        if ReplicatedStorage:FindFirstChild("VoiceEvents") and ReplicatedStorage.VoiceEvents:FindFirstChild("SetDistance") then
            ReplicatedStorage.VoiceEvents.SetDistance:FireServer(val)
        end
    end)

    -- ミュートオールボタン
    local muteAllBtn = Instance.new("TextButton")
    muteAllBtn.Text = "全員ミュート (OFF)"
    muteAllBtn.Size = UDim2.new(1, 0, 0, 35)
    muteAllBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    muteAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    muteAllBtn.Font = Enum.Font.GothamBold
    muteAllBtn.TextSize = 14
    muteAllBtn.LayoutOrder = 6
    muteAllBtn.Parent = contentScroll
    local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(0, 6); btnCorner.Parent = muteAllBtn

    muteAllBtn.MouseButton1Click:Connect(function()
        Config.IsMutedAll = not Config.IsMutedAll
        if Config.IsMutedAll then
            muteAllBtn.Text = "全員ミュート中 (ON)"
            muteAllBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
            muteAllBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        else
            muteAllBtn.Text = "全員ミュート (OFF)"
            muteAllBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            muteAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)

    -- === ドラッグ機能 ===
    local dragging, dragInput, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- === 最小化機能 ===
    local isMinimized = false
    minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            mainFrame:TweenSize(UDim2.new(0, 320, 0, 30), "Out", "Quad", 0.3, true)
            contentScroll.Visible = false
            minBtn.Text = "+"
        else
            mainFrame:TweenSize(UDim2.new(0, 320, 0, 450), "Out", "Quad", 0.3, true)
            contentScroll.Visible = true
            minBtn.Text = "-"
        end
    end)
    
    return gui
end

--------------------------------------------------------------------------------
-- 3. ボイス監視・制御ロジック (Core Voice Logic)
--------------------------------------------------------------------------------

local function updatePlayerVoice(otherPlayer)
    if otherPlayer == localPlayer then return end
    if not otherPlayer.Character then return end

    -- 他プレイヤーのキャラクターから音源を探す (通常はHeadかHumanoidRootPart)
    local head = otherPlayer.Character:FindFirstChild("Head")
    local root = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    -- ボイスチャットのSoundオブジェクトを探す
    -- Robloxの仕様上、AudioDeviceInputなどが使われることもあるが、
    -- 現状の多くはHead内のSoundオブジェクトとしてアクセス可能
    local sound = nil
    if head then sound = head:FindFirstChildWhichIsA("Sound") end
    
    if sound then
        -- 1. 距離計算（自分の位置 vs 相手の位置）
        local myChar = localPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        
        local isAudible = true
        
        if myRoot and root then
            local distance = (myRoot.Position - root.Position).Magnitude
            
            -- 設定: 自分が聞こえる距離を超えていたら音量を0にする (Local Cutoff)
            if distance > Config.MyHearingDistance then
                isAudible = false
            end
        end
        
        -- 2. 全員ミュート設定チェック
        if Config.IsMutedAll then isAudible = false end
        
        -- 3. 個別ミュートチェック
        if mutedPlayers[otherPlayer] then isAudible = false end

        -- 4. 適用
        if isAudible then
            sound.Volume = Config.MyVolume -- 音量適用
            sound.Playing = true
        else
            sound.Volume = 0 -- 実質ミュート
        end

        -- 5. プレイヤー間の物理的距離 (RollOff)
        -- これは、そのプレイヤーの声が「どれくらい遠くまで届く設定になっているか」をローカルで見ている
        -- 本来はサーバー側で設定すべきだが、ローカルでシミュレーションするために適用
        sound.RollOffMaxDistance = Config.GlobalVoiceRange
        sound.RollOffMinDistance = 5 -- 近距離ではクリアに聞こえるように
        sound.RollOffMode = Enum.RollOffMode.InverseTapered -- 自然な減衰
    end
end

-- 個別ミュートの切り替え (ショートカットキー 'M' 用)
local function toggleClosestPlayerMute()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local myChar = localPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if not myRoot then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (myRoot.Position - p.Character.HumanoidRootPart.Position).Magnitude
            if dist < shortestDistance and dist < 50 then -- 50スタッド以内を対象
                shortestDistance = dist
                closestPlayer = p
            end
        end
    end

    if closestPlayer then
        if mutedPlayers[closestPlayer] then
            mutedPlayers[closestPlayer] = nil
            VoiceChatService:SetMuted(closestPlayer.UserId, false) -- 念のため公式APIも呼ぶ
            print(closestPlayer.Name .. " のミュートを解除")
            
            -- UIフィードバック（簡易）
            local notification = Instance.new("Hint", workspace)
            notification.Text = "Unmuted: " .. closestPlayer.Name
            game.Debris:AddItem(notification, 2)
        else
            mutedPlayers[closestPlayer] = true
            VoiceChatService:SetMuted(closestPlayer.UserId, true)
            print(closestPlayer.Name .. " をミュート")
            
            local notification = Instance.new("Hint", workspace)
            notification.Text = "Muted: " .. closestPlayer.Name
            game.Debris:AddItem(notification, 2)
        end
    end
end

--------------------------------------------------------------------------------
-- 4. ループとイベント接続 (Loop & Connections)
--------------------------------------------------------------------------------

-- UI初期化
createUI()

-- 毎フレーム監視ループ
RunService.Heartbeat:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        updatePlayerVoice(player)
    end
end)

-- キー入力イベント
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.M then
        toggleClosestPlayerMute()
    end
end)

-- プレイヤー退出時のクリーンアップ
Players.PlayerRemoving:Connect(function(p)
    mutedPlayers[p] = nil
end)

print("Voice Control Script Loaded.")

-- LocalScript: 統合ボイスチャット制御システム
local Players = game:GetService("Players")
local VoiceChatService = game:GetService("VoiceChatService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 設定値
local config = {
    maxDistance = 50,  -- 最大聴取距離（スタッド）
    minDistance = 5,   -- 最小聴取距離
    volume = 1.0,      -- 音量（0.0-2.0）
    updateInterval = 0.5, -- 更新間隔（秒）
    autoMuteDistance = 100, -- 自動ミュート距離
}

-- 状態管理
local state = {
    mutedPlayers = {},  -- 手動でミュートしたプレイヤー
    distanceMuted = {}, -- 距離でミュートされたプレイヤー
    isMinimized = false,
    isDragging = false,
    dragOffset = Vector2.new(0, 0),
    lastUpdate = 0,
    playerSettings = {}, -- 各プレイヤーの個別設定
}

-- リモートイベントの設定（存在しない場合は作成）
local function ensureRemoteEvents()
    local repStorage = game:GetService("ReplicatedStorage")
    
    if not repStorage:FindFirstChild("VoiceEvents") then
        local folder = Instance.new("Folder")
        folder.Name = "VoiceEvents"
        folder.Parent = repStorage
    end
    
    local eventsFolder = repStorage:FindFirstChild("VoiceEvents")
    
    if not eventsFolder:FindFirstChild("SetDistance") then
        local setDistance = Instance.new("RemoteEvent")
        setDistance.Name = "SetDistance"
        setDistance.Parent = eventsFolder
    end
    
    if not eventsFolder:FindFirstChild("SetVolume") then
        local setVolume = Instance.new("RemoteEvent")
        setVolume.Name = "SetVolume"
        setVolume.Parent = eventsFolder
    end
    
    if not eventsFolder:FindFirstChild("UpdateSettings") then
        local updateSettings = Instance.new("RemoteEvent")
        updateSettings.Name = "UpdateSettings"
        updateSettings.Parent = eventsFolder
    end
end

ensureRemoteEvents()

-- UI作成関数
local function createUI()
    -- メインスクリーンGUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "VoiceControlSystem"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- メインコンテナ
    local mainContainer = Instance.new("Frame")
    mainContainer.Name = "MainContainer"
    mainContainer.Size = UDim2.new(0, 400, 0, 450)
    mainContainer.Position = UDim2.new(0.05, 0, 0.3, 0)
    mainContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainContainer.BackgroundTransparency = 0.1
    mainContainer.BorderSizePixel = 0
    mainContainer.ClipsDescendants = true
    mainContainer.Parent = screenGui
    
    -- ドラッグ可能なヘッダー
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    header.BorderSizePixel = 0
    header.Parent = mainContainer
    
    -- タイトル
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.05, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🎤 ボイスチャット制御システム"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    -- 最小化ボタン
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(0.85, 0, 0.12, 0)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.TextSize = 20
    minimizeBtn.Parent = header
    
    -- 閉じるボタン
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(0.92, 0, 0.12, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 20
    closeBtn.Parent = header
    
    -- コンテンツエリア（スクロール可能）
    local contentScrolling = Instance.new("ScrollingFrame")
    contentScrolling.Name = "ContentScrolling"
    contentScrolling.Size = UDim2.new(1, -10, 1, -50)
    contentScrolling.Position = UDim2.new(0, 5, 0, 45)
    contentScrolling.BackgroundTransparency = 1
    contentScrolling.BorderSizePixel = 0
    contentScrolling.ScrollBarThickness = 8
    contentScrolling.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    contentScrolling.CanvasSize = UDim2.new(0, 0, 0, 600)
    contentScrolling.Parent = mainContainer
    
    -- グローバル設定セクション
    local globalSection = Instance.new("Frame")
    globalSection.Name = "GlobalSection"
    globalSection.Size = UDim2.new(1, 0, 0, 180)
    globalSection.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    globalSection.BorderSizePixel = 0
    globalSection.Parent = contentScrolling
    
    local globalTitle = Instance.new("TextLabel")
    globalTitle.Name = "GlobalTitle"
    globalTitle.Size = UDim2.new(1, 0, 0, 30)
    globalTitle.BackgroundTransparency = 1
    globalTitle.Text = "🌐 グローバル設定"
    globalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    globalTitle.TextSize = 16
    globalTitle.Font = Enum.Font.GothamBold
    globalTitle.Parent = globalSection
    
    -- 距離スライダー（グローバル）
    local distanceContainer = Instance.new("Frame")
    distanceContainer.Name = "DistanceContainer"
    distanceContainer.Size = UDim2.new(1, -20, 0, 70)
    distanceContainer.Position = UDim2.new(0, 10, 0, 35)
    distanceContainer.BackgroundTransparency = 1
    distanceContainer.Parent = globalSection
    
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "DistanceLabel"
    distanceLabel.Size = UDim2.new(1, 0, 0, 25)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = "最大聴取距離: 50スタッド"
    distanceLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    distanceLabel.TextSize = 14
    distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
    distanceLabel.Parent = distanceContainer
    
    local distanceSlider = Instance.new("Slider")
    distanceSlider.Name = "DistanceSlider"
    distanceSlider.Size = UDim2.new(1, 0, 0, 20)
    distanceSlider.Position = UDim2.new(0, 0, 0, 30)
    distanceSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    distanceSlider.BorderSizePixel = 0
    distanceSlider.MinValue = config.minDistance
    distanceSlider.MaxValue = 200
    distanceSlider.Value = config.maxDistance
    distanceSlider.Parent = distanceContainer
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = distanceSlider
    
    -- 音量スライダー（グローバル）
    local volumeContainer = Instance.new("Frame")
    volumeContainer.Name = "VolumeContainer"
    volumeContainer.Size = UDim2.new(1, -20, 0, 70)
    volumeContainer.Position = UDim2.new(0, 10, 0, 110)
    volumeContainer.BackgroundTransparency = 1
    volumeContainer.Parent = globalSection
    
    local volumeLabel = Instance.new("TextLabel")
    volumeLabel.Name = "VolumeLabel"
    volumeLabel.Size = UDim2.new(1, 0, 0, 25)
    volumeLabel.BackgroundTransparency = 1
    volumeLabel.Text = "全体音量: 100%"
    volumeLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    volumeLabel.TextSize = 14
    volumeLabel.TextXAlignment = Enum.TextXAlignment.Left
    volumeLabel.Parent = volumeContainer
    
    local volumeSlider = Instance.new("Slider")
    volumeSlider.Name = "VolumeSlider"
    volumeSlider.Size = UDim2.new(1, 0, 0, 20)
    volumeSlider.Position = UDim2.new(0, 0, 0, 30)
    volumeSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    volumeSlider.BorderSizePixel = 0
    volumeSlider.MinValue = 0
    volumeSlider.MaxValue = 200
    volumeSlider.Value = config.volume * 100
    volumeSlider.Parent = volumeContainer
    
    local volumeFill = Instance.new("Frame")
    volumeFill.Name = "VolumeFill"
    volumeFill.Size = UDim2.new(1, 0, 1, 0)
    volumeFill.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
    volumeFill.BorderSizePixel = 0
    volumeFill.Parent = volumeSlider
    
    -- 個別プレイヤー設定セクション
    local playersSection = Instance.new("Frame")
    playersSection.Name = "PlayersSection"
    playersSection.Size = UDim2.new(1, 0, 0, 200)
    playersSection.Position = UDim2.new(0, 0, 0, 185)
    playersSection.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    playersSection.BorderSizePixel = 0
    playersSection.Parent = contentScrolling
    
    local playersTitle = Instance.new("TextLabel")
    playersTitle.Name = "PlayersTitle"
    playersTitle.Size = UDim2.new(1, 0, 0, 30)
    playersTitle.BackgroundTransparency = 1
    playersTitle.Text = "👥 個別プレイヤー設定"
    playersTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    playersTitle.TextSize = 16
    playersTitle.Font = Enum.Font.GothamBold
    playersTitle.Parent = playersSection
    
    -- プレイヤーリストコンテナ
    local playersList = Instance.new("Frame")
    playersList.Name = "PlayersList"
    playersList.Size = UDim2.new(1, -10, 0, 160)
    playersList.Position = UDim2.new(0, 5, 0, 35)
    playersList.BackgroundTransparency = 1
    playersList.Parent = playersSection
    
    -- 監視セクション
    local monitorSection = Instance.new("Frame")
    monitorSection.Name = "MonitorSection"
    monitorSection.Size = UDim2.new(1, 0, 0, 180)
    monitorSection.Position = UDim2.new(0, 0, 0, 390)
    monitorSection.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    monitorSection.BorderSizePixel = 0
    monitorSection.Parent = contentScrolling
    
    local monitorTitle = Instance.new("TextLabel")
    monitorTitle.Name = "MonitorTitle"
    monitorTitle.Size = UDim2.new(1, 0, 0, 30)
    monitorTitle.BackgroundTransparency = 1
    monitorTitle.Text = "📊 ボイスチャット監視"
    monitorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    monitorTitle.TextSize = 16
    monitorTitle.Font = Enum.Font.GothamBold
    monitorTitle.Parent = monitorSection
    
    -- 監視情報表示
    local monitorInfo = Instance.new("TextLabel")
    monitorInfo.Name = "MonitorInfo"
    monitorInfo.Size = UDim2.new(1, -20, 0, 140)
    monitorInfo.Position = UDim2.new(0, 10, 0, 35)
    monitorInfo.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    monitorInfo.BackgroundTransparency = 0.3
    monitorInfo.BorderSizePixel = 0
    monitorInfo.Text = "監視データ読み込み中..."
    monitorInfo.TextColor3 = Color3.fromRGB(220, 220, 220)
    monitorInfo.TextSize = 14
    monitorInfo.TextWrapped = true
    monitorInfo.TextXAlignment = Enum.TextXAlignment.Left
    monitorInfo.TextYAlignment = Enum.TextYAlignment.Top
    monitorInfo.Parent = monitorSection
    
    -- コントロールボタン
    local controlsSection = Instance.new("Frame")
    controlsSection.Name = "ControlsSection"
    controlsSection.Size = UDim2.new(1, 0, 0, 60)
    controlsSection.Position = UDim2.new(0, 0, 0, 575)
    controlsSection.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    controlsSection.BorderSizePixel = 0
    controlsSection.Parent = contentScrolling
    
    -- 全員ミュートボタン
    local muteAllBtn = Instance.new("TextButton")
    muteAllBtn.Name = "MuteAllBtn"
    muteAllBtn.Size = UDim2.new(0.4, -5, 0, 40)
    muteAllBtn.Position = UDim2.new(0.05, 0, 0.15, 0)
    muteAllBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    muteAllBtn.BorderSizePixel = 0
    muteAllBtn.Text = "全員ミュート"
    muteAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    muteAllBtn.TextSize = 14
    muteAllBtn.Font = Enum.Font.GothamBold
    muteAllBtn.Parent = controlsSection
    
    -- 全員ミュート解除ボタン
    local unmuteAllBtn = Instance.new("TextButton")
    unmuteAllBtn.Name = "UnmuteAllBtn"
    unmuteAllBtn.Size = UDim2.new(0.4, -5, 0, 40)
    unmuteAllBtn.Position = UDim2.new(0.55, 0, 0.15, 0)
    unmuteAllBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
    unmuteAllBtn.BorderSizePixel = 0
    unmuteAllBtn.Text = "全員ミュート解除"
    unmuteAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    unmuteAllBtn.TextSize = 14
    unmuteAllBtn.Font = Enum.Font.GothamBold
    unmuteAllBtn.Parent = controlsSection
    
    -- 最小化時の簡易UI
    local minimizedUI = Instance.new("Frame")
    minimizedUI.Name = "MinimizedUI"
    minimizedUI.Size = UDim2.new(0, 150, 0, 40)
    minimizedUI.Position = UDim2.new(0.05, 0, 0.3, 0)
    minimizedUI.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    minimizedUI.BackgroundTransparency = 0.1
    minimizedUI.BorderSizePixel = 0
    minimizedUI.Visible = false
    minimizedUI.Parent = screenGui
    
    local minimizedTitle = Instance.new("TextLabel")
    minimizedTitle.Name = "MinimizedTitle"
    minimizedTitle.Size = UDim2.new(0.7, 0, 1, 0)
    minimizedTitle.Position = UDim2.new(0.05, 0, 0, 0)
    minimizedTitle.BackgroundTransparency = 1
    minimizedTitle.Text = "🎤 VC制御"
    minimizedTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizedTitle.TextSize = 14
    minimizedTitle.Font = Enum.Font.GothamBold
    minimizedTitle.TextXAlignment = Enum.TextXAlignment.Left
    minimizedTitle.Parent = minimizedUI
    
    local restoreBtn = Instance.new("TextButton")
    restoreBtn.Name = "RestoreBtn"
    restoreBtn.Size = UDim2.new(0, 30, 0, 30)
    restoreBtn.Position = UDim2.new(0.8, 0, 0.12, 0)
    restoreBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    restoreBtn.BorderSizePixel = 0
    restoreBtn.Text = "+"
    restoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    restoreBtn.TextSize = 20
    restoreBtn.Parent = minimizedUI
    
    -- スライダーの更新
    distanceSlider:GetPropertyChangedSignal("Value"):Connect(function()
        local fillRatio = (distanceSlider.Value - distanceSlider.MinValue) / 
                         (distanceSlider.MaxValue - distanceSlider.MinValue)
        sliderFill.Size = UDim2.new(fillRatio, 0, 1, 0)
        distanceLabel.Text = string.format("最大聴取距離: %dスタッド", math.floor(distanceSlider.Value))
        config.maxDistance = distanceSlider.Value
        game:GetService("ReplicatedStorage").VoiceEvents.SetDistance:FireServer(config.maxDistance)
    end)
    
    volumeSlider:GetPropertyChangedSignal("Value"):Connect(function()
        local fillRatio = volumeSlider.Value / volumeSlider.MaxValue
        volumeFill.Size = UDim2.new(fillRatio, 0, 1, 0)
        volumeLabel.Text = string.format("全体音量: %d%%", math.floor(volumeSlider.Value))
        config.volume = volumeSlider.Value / 100
        game:GetService("ReplicatedStorage").VoiceEvents.SetVolume:FireServer(config.volume)
    end)
    
    return screenGui
end

-- UIの作成
local ui = createUI()
local mainContainer = ui:FindFirstChild("MainContainer")
local minimizedUI = ui:FindFirstChild("MinimizedUI")
local contentScrolling = mainContainer:FindFirstChild("ContentScrolling")
local playersList = contentScrolling:FindFirstChild("PlayersSection"):FindFirstChild("PlayersList")
local monitorInfo = contentScrolling:FindFirstChild("MonitorSection"):FindFirstChild("MonitorInfo")

-- UI操作関数
local function setupUIInteractions()
    local header = mainContainer:FindFirstChild("Header")
    local minimizeBtn = header:FindFirstChild("MinimizeBtn")
    local closeBtn = header:FindFirstChild("CloseBtn")
    local restoreBtn = minimizedUI:FindFirstChild("RestoreBtn")
    local muteAllBtn = contentScrolling:FindFirstChild("ControlsSection"):FindFirstChild("MuteAllBtn")
    local unmuteAllBtn = contentScrolling:FindFirstChild("ControlsSection"):FindFirstChild("UnmuteAllBtn")
    
    -- ドラッグ機能
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            state.isDragging = true
            local mousePos = UserInputService:GetMouseLocation()
            state.dragOffset = Vector2.new(
                mousePos.X - mainContainer.AbsolutePosition.X,
                mousePos.Y - mainContainer.AbsolutePosition.Y
            )
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if state.isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = UserInputService:GetMouseLocation()
            mainContainer.Position = UDim2.new(
                0, mousePos.X - state.dragOffset.X,
                0, mousePos.Y - state.dragOffset.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            state.isDragging = false
        end
    end)
    
    -- 最小化/最大化
    minimizeBtn.MouseButton1Click:Connect(function()
        state.isMinimized = true
        mainContainer.Visible = false
        minimizedUI.Visible = true
        minimizedUI.Position = mainContainer.Position
    end)
    
    restoreBtn.MouseButton1Click:Connect(function()
        state.isMinimized = false
        minimizedUI.Visible = false
        mainContainer.Visible = true
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        mainContainer.Visible = false
        minimizedUI.Visible = false
    end)
    
    -- キーボードショートカット (Alt+VでUI表示/非表示)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.V and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
            if state.isMinimized then
                if minimizedUI.Visible then
                    minimizedUI.Visible = false
                else
                    minimizedUI.Visible = true
                end
            else
                if mainContainer.Visible then
                    mainContainer.Visible = false
                else
                    mainContainer.Visible = true
                end
            end
        end
    end)
    
    -- 全員ミュート/ミュート解除
    muteAllBtn.MouseButton1Click:Connect(function()
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                VoiceChatService:SetMuted(otherPlayer.UserId, true)
                state.mutedPlayers[otherPlayer] = true
            end
        end
        updateMonitorInfo()
    end)
    
    unmuteAllBtn.MouseButton1Click:Connect(function()
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                VoiceChatService:SetMuted(otherPlayer.UserId, false)
                state.mutedPlayers[otherPlayer] = nil
            end
        end
        updateMonitorInfo()
    end)
end

-- プレイヤーリストの更新
local function updatePlayerList()
    playersList:ClearAllChildren()
    
    local yOffset = 0
    local itemHeight = 40
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local playerItem = Instance.new("Frame")
            playerItem.Name = otherPlayer.Name
            playerItem.Size = UDim2.new(1, 0, 0, itemHeight)
            playerItem.Position = UDim2.new(0, 0, 0, yOffset)
            playerItem.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            playerItem.BorderSizePixel = 0
            playerItem.Parent = playersList
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
            nameLabel.Position = UDim2.new(0, 5, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = otherPlayer.Name
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 14
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = playerItem
            
            -- ミュートボタン
            local muteBtn = Instance.new("TextButton")
            muteBtn.Name = "MuteBtn"
            muteBtn.Size = UDim2.new(0, 70, 0, 25)
            muteBtn.Position = UDim2.new(0.42, 0, 0.2, 0)
            muteBtn.BackgroundColor3 = state.mutedPlayers[otherPlayer] and 
                Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
            muteBtn.BorderSizePixel = 0
            muteBtn.Text = state.mutedPlayers[otherPlayer] and "解除" or "ミュート"
            muteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            muteBtn.TextSize = 12
            muteBtn.Font = Enum.Font.GothamBold
            muteBtn.Parent = playerItem
            
            muteBtn.MouseButton1Click:Connect(function()
                if state.mutedPlayers[otherPlayer] then
                    VoiceChatService:SetMuted(otherPlayer.UserId, false)
                    state.mutedPlayers[otherPlayer] = nil
                    muteBtn.Text = "ミュート"
                    muteBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
                else
                    VoiceChatService:SetMuted(otherPlayer.UserId, true)
                    state.mutedPlayers[otherPlayer] = true
                    muteBtn.Text = "解除"
                    muteBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
                end
                updateMonitorInfo()
            end)
            
            -- 個別音量スライダー
            local individualSlider = Instance.new("Slider")
            individualSlider.Name = "IndividualSlider"
            individualSlider.Size = UDim2.new(0.3, 0, 0, 20)
            individualSlider.Position = UDim2.new(0.65, 0, 0.25, 0)
            individualSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            individualSlider.BorderSizePixel = 0
            individualSlider.MinValue = 0
            individualSlider.MaxValue = 200
            individualSlider.Value = 100
            individualSlider.Parent = playerItem
            
            local individualFill = Instance.new("Frame")
            individualFill.Name = "IndividualFill"
            individualFill.Size = UDim2.new(1, 0, 1, 0)
            individualFill.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
            individualFill.BorderSizePixel = 0
            individualFill.Parent = individualSlider
            
            individualSlider:GetPropertyChangedSignal("Value"):Connect(function()
                local fillRatio = individualSlider.Value / individualSlider.MaxValue
                individualFill.Size = UDim2.new(fillRatio, 0, 1, 0)
                
                -- 個別プレイヤー設定の保存
                state.playerSettings[otherPlayer] = state.playerSettings[otherPlayer] or {}
                state.playerSettings[otherPlayer].volume = individualSlider.Value / 100
                
                -- サーバーに設定を送信
                game:GetService("ReplicatedStorage").VoiceEvents.UpdateSettings:FireServer(
                    otherPlayer.UserId,
                    {volume = individualSlider.Value / 100}
                )
            end)
            
            yOffset = yOffset + itemHeight + 5
        end
    end
    
    contentScrolling.CanvasSize = UDim2.new(0, 0, 0, math.max(600, yOffset + 200))
end

-- 距離ベースのボイス制御
local function updateDistanceBasedVoiceControl()
    local myCharacter = player.Character
    if not myCharacter then return end
    
    local myRoot = myCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and not state.mutedPlayers[otherPlayer] then
            local otherCharacter = otherPlayer.Character
            if otherCharacter then
                local otherRoot = otherCharacter:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local distance = (myRoot.Position - otherRoot.Position).Magnitude
                    
                    -- 距離による自動ミュート
                    if distance > config.maxDistance then
                        if not state.distanceMuted[otherPlayer] then
                            VoiceChatService:SetMuted(otherPlayer.UserId, true)
                            state.distanceMuted[otherPlayer] = true
                        end
                    else
                        if state.distanceMuted[otherPlayer] then
                            VoiceChatService:SetMuted(otherPlayer.UserId, false)
                            state.distanceMuted[otherPlayer] = nil
                        end
                    end
                end
            end
        end
    end
end

-- 監視情報の更新
local function updateMonitorInfo()
    local infoText = "=== ボイスチャット監視情報 ===\n\n"
    
    local activePlayers = 0
    local mutedPlayersCount = 0
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            activePlayers = activePlayers + 1
            
            local isMuted = state.mutedPlayers[otherPlayer] or state.distanceMuted[otherPlayer]
            if isMuted then
                mutedPlayersCount = mutedPlayersCount + 1
            end
            
            local status = isMuted and "🔇 ミュート中" or "🔊 通話中"
            local distanceText = ""
            
            -- 距離の計算
            local myCharacter = player.Character
            local otherCharacter = otherPlayer.Character
            if myCharacter and otherCharacter then
                local myRoot = myCharacter:FindFirstChild("HumanoidRootPart")
                local otherRoot = otherCharacter:FindFirstChild("HumanoidRootPart")
                if myRoot and otherRoot then
                    local distance = (myRoot.Position - otherRoot.Position).Magnitude
                    distanceText = string.format(" (距離: %.1fスタッド)", distance)
                end
            end
            
            infoText = infoText .. string.format("• %s: %s%s\n", 
                otherPlayer.Name, status, distanceText)
        end
    end
    
    infoText = infoText .. string.format("\n📊 統計:\n")
    infoText = infoText .. string.format("  総プレイヤー数: %d\n", activePlayers)
    infoText = infoText .. string.format("  ミュート中: %d\n", mutedPlayersCount)
    infoText = infoText .. string.format("  通話中: %d\n", activePlayers - mutedPlayersCount)
    infoText = infoText .. string.format("  最大聴取距離: %dスタッド\n", config.maxDistance)
    infoText = infoText .. string.format("  全体音量: %d%%", math.floor(config.volume * 100))
    
    monitorInfo.Text = infoText
end

-- 初期化
setupUIInteractions()
updatePlayerList()

-- プレイヤー参加/退出の監視
Players.PlayerAdded:Connect(function(newPlayer)
    wait(1) -- 少し待ってから更新
    updatePlayerList()
end)

Players.PlayerRemoving:Connect(function(leavingPlayer)
    state.mutedPlayers[leavingPlayer] = nil
    state.distanceMuted[leavingPlayer] = nil
    state.playerSettings[leavingPlayer] = nil
    updatePlayerList()
    updateMonitorInfo()
end)

-- メインループ
RunService.Heartbeat:Connect(function(deltaTime)
    state.lastUpdate = state.lastUpdate + deltaTime
    
    if state.lastUpdate >= config.updateInterval then
        updateDistanceBasedVoiceControl()
        updateMonitorInfo()
        state.lastUpdate = 0
    end
end)

-- 初期監視情報表示
updateMonitorInfo()

-- キーボードショートカットで最も近いプレイヤーをミュート/解除
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.M and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local myCharacter = player.Character
        if not myCharacter then return end
        
        local myRoot = myCharacter:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        
        local closestPlayer = nil
        local shortestDistance = math.huge
        
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local distance = (myRoot.Position - otherRoot.Position).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestPlayer = otherPlayer
                    end
                end
            end
        end
        
        if closestPlayer then
            if state.mutedPlayers[closestPlayer] then
                VoiceChatService:SetMuted(closestPlayer.UserId, false)
                state.mutedPlayers[closestPlayer] = nil
                print(closestPlayer.Name .. "のミュートを解除しました。")
            else
                VoiceChatService:SetMuted(closestPlayer.UserId, true)
                state.mutedPlayers[closestPlayer] = true
                print(closestPlayer.Name .. "をミュートしました。")
            end
            updatePlayerList()
            updateMonitorInfo()
        end
    end
end)

print("ボイスチャット制御システムが起動しました。Alt+VでUIを表示/非表示、Ctrl+Mで最も近いプレイヤーをミュート/解除します。")

-- [[ รอจนกว่าตัวละครจะโหลดเสร็จก่อนรัน ]]
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart", 10)

-- [[ ประกาศ Service ]]
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local camera = workspace.CurrentCamera

-- 🔗 อ้างอิง Remote
local events = ReplicatedStorage:WaitForChild("Events")
local remotes = {
    pounce = events:WaitForChild("Pounce"),
    followUp = events:WaitForChild("FollowUp"),
    dive = events:WaitForChild("DiveAttack"),
    dash = events:WaitForChild("Dash"),
    fallDamage = events:WaitForChild("FallDamage"),
    grip = events:WaitForChild("Grip"),
    runAttackFX = events:WaitForChild("RunAttackFX"),
    slashEffects = events:WaitForChild("SlashEffects"),
    parry = events:WaitForChild("ParryActivate"),
    critical = events:WaitForChild("ActivateCritical")
}

-- ⚙️ CONFIGURATION & STATES
local DangerousItems = {
    "Serum W", "Serum R", "Serum K", "Gravity Manipulation", 
    "Mist of The Lake", "Sinner Contract", "Wild Hunt", "Enchain", 
    "Deathseeking", "Chefs Blessing", "Borrowed Eyes", 
    "Silencing Gloves", "Shockwave", "Manifested Armor"
}

local newPassives = {
    "Agile", "QuickRest", "Hot-Headed", "Coldness", "Shimmering", 
    "Maniacal", "Token Of Rojima", "UnusedPassives", "Calm", 
    "Indomitable", "Resourceful", "Methodical", "Steadfast", 
    "GardePerdue", "Chromatic", "Proficient", "Reactive", 
    "Energetic", "Hypoxic", "Resolute", "Bizarre", "Paranoid", 
    "CulinaryKnowledge", "Immovable", "PermaChromatic"
}

local States = { 
    DiveSpam = false, 
    Flying = false, 
    AutoCombo = false, 
    IsGlitching = false,
    Gripping = false,
    SpamEffects = false,
    NoClip = false
}
local flySpeed = 100

-- 🔔 ฟังก์ชันแจ้งเตือน
local function Notify(title, text)
      StarterGui:SetCore("SendNotification", {
        Title = title;
        Text = text;
        Duration = 2;
    })
end

-------------------------------------------------------------------
-- [[ 1. DATA & PASSIVE SYSTEM (UPDATED) ]] --
-------------------------------------------------------------------
local function forceUpdateData()
    local data = lp:FindFirstChild("Data")
    if not data then return end

    -- 1. อัปเดต Passives เดิม
    local passivesObj = data:FindFirstChild("Passives")
    if passivesObj and passivesObj:IsA("StringValue") then
        local current = passivesObj.Value
        local updated = false
        for _, name in pairs(newPassives) do
            if not string.find(current, name) then
                current = current .. (current == "" and "" or ",") .. name
                updated = true
            end
        end
        if updated then passivesObj.Value = current end
    end

    -- 2. เพิ่มการ Force ค่า Poise (ที่ขอใหม่)
    -- ตั้งค่า PoiseStacks ให้เป็น 100 (หรือเปลี่ยนเลขตามต้องการ)
    local poise = data:FindFirstChild("RegenSpeedIncreaseStacks")
    if poise and (poise:IsA("IntValue") or poise:IsA("NumberValue")) then
        poise.Value = 50 
    end

    -- ตั้งค่า PoiseResonanceStacks ให้เป็น 100
    local poiseRes = data:FindFirstChild("DropRateIncreaseStacks")
    if poiseRes and (poiseRes:IsA("IntValue") or poiseRes:IsA("NumberValue")) then
        poiseRes.Value = 20
    end
end

-------------------------------------------------------------------
-- [[ 2. HIDE SELF NAME (ซ่อนชื่อตัวเอง) ]] --
-------------------------------------------------------------------
local function HideMyName()
    local function hide(char)
        task.wait(1)
        if char:FindFirstChild("Head") then
            for _, v in pairs(char.Head:GetChildren()) do
                if v:IsA("BillboardGui") then v.Enabled = false end
            end
        end
    end
    if lp.Character then hide(lp.Character) end
    lp.CharacterAdded:Connect(hide)
end

-------------------------------------------------------------------
-- [[ 3. ESP & PLAYER SCANNER ]] --
-------------------------------------------------------------------
local function CreateESP(plr)
    if plr == lp then return end
    
    local function Update()
        local char = plr.Character
        if not char or not char:FindFirstChild("Head") or not char:FindFirstChild("Humanoid") then return end
        
        local header = char:FindFirstChild("ESP_Header") or Instance.new("BillboardGui", char)
        header.Name = "ESP_Header"
        header.AlwaysOnTop = true
        header.Size = UDim2.new(0, 200, 0, 70)
        header.ExtentsOffset = Vector3.new(0, 3, 0)

        local label = header:FindFirstChild("NameTag") or Instance.new("TextLabel", header)
        label.Name = "NameTag"
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextStrokeTransparency = 0

        local foundItem = nil
        local backpack = plr:FindFirstChild("Backpack")
        for _, d in pairs(DangerousItems) do
            if (backpack and backpack:FindFirstChild(d)) or (char:FindFirstChild(d)) then
                foundItem = d
                break
            end
        end

        local hum = char.Humanoid
        local hp = math.floor(hum.Health)
        
        if foundItem then
            label.Text = plr.Name .. " [!]\nHP: "..hp.."\n("..foundItem..")"
            label.TextColor3 = Color3.fromRGB(255, 0, 0)
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
        else
            label.Text = plr.Name .. "\nHP: "..hp
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            highlight.FillColor = Color3.fromHSV(math.clamp(hum.Health/hum.MaxHealth, 0, 1) * 0.35, 1, 1)
        end
    end
    
    task.spawn(function()
        while plr and plr.Parent do
            pcall(Update)
            task.wait(1.5)
        end
    end)
end

-------------------------------------------------------------------
-- [[ 4. COMBAT & MOVEMENT SYSTEMS ]] --
-------------------------------------------------------------------

-- [T] Toggle Auto Combo
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.T then
        States.AutoCombo = not States.AutoCombo
        Notify("Auto Combo", States.AutoCombo and "เริ่มทำงาน (Normal Loop)" or "ปิดการทำงาน")
        if States.AutoCombo then
            task.spawn(function()
                while States.AutoCombo do
                    remotes.pounce:FireServer()
                    remotes.followUp:FireServer()
                    task.wait(0.1)
                end
            end)
        end
    end
end)

-- [R] Activate Critical
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.R then
        if lp.Character then
            remotes.critical:FireServer(lp.Character)
        end
    end
end)

-- [M2] Parry
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        remotes.parry:FireServer()
    end
end)

-- [Y] Auto-Glitch
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Y then
        States.IsGlitching = not States.IsGlitching
        Notify("Combo Glitch", States.IsGlitching and "เริ่มระบบบั๊ก..." or "ปิดการทำงาน")
        if States.IsGlitching then
            task.spawn(function()
                remotes.pounce:FireServer()
                task.wait(0.5) 
                remotes.followUp:FireServer()
                task.wait(1)
                remotes.followUp:FireServer()
                while States.IsGlitching do
                    remotes.followUp:FireServer()
                    task.wait(0.5) 
                end
            end)
        end
    end
end)

-- [L] NoClip
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.L then
        States.NoClip = not States.NoClip
        Notify("Movement", "NoClip: " .. (States.NoClip and "เปิด" or "ปิด"))
    end
end)

RunService.Stepped:Connect(function()
    if States.NoClip and lp.Character then
        for _, part in pairs(lp.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- [B] Grip Spam
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.B then
        States.Gripping = true
        task.spawn(function()
            while States.Gripping do
                if lp.Character then remotes.grip:FireServer(lp.Character) end
                task.wait(0.05) 
            end
        end)
    end
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.B then States.Gripping = false end
end)

-- [U] Effects Spam
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.U then
        States.SpamEffects = not States.SpamEffects
        Notify("Effects Spam", States.SpamEffects and "เปิด" or "ปิด")
        if States.SpamEffects then
            task.spawn(function()
                while States.SpamEffects do
                    remotes.runAttackFX:FireServer()
                    remotes.slashEffects:FireServer(1)
                    task.wait() 
                end
            end)
        end
    end
end)

-- [H] Fly System
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.H then
        States.Flying = not States.Flying
        Notify("Movement", "Fly: " .. (States.Flying and "ON" or "OFF"))
        local character = lp.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if States.Flying then
            local bv = Instance.new("BodyVelocity", root)
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            local bg = Instance.new("BodyGyro", root)
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); bg.P = 15000
            task.spawn(function()
                while States.Flying and character and root do
                    local direction = Vector3.new(0, 0, 0)
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.new(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direction -= Vector3.new(0, 1, 0) end
                    bv.Velocity = direction.Unit * flySpeed
                    if direction == Vector3.new(0,0,0) then bv.Velocity = Vector3.new(0,0,0) end
                    bg.CFrame = camera.CFrame
                    RunService.RenderStepped:Wait()
                end
                bv:Destroy()
                bg:Destroy()
            end)
        end
    end
end)

-------------------------------------------------------------------
-- [[ 5. INITIALIZE & RUN ]] --
-------------------------------------------------------------------
HideMyName()

task.spawn(function()
    while true do
        forceUpdateData()
        task.wait(5)
    end
end)

for _, p in pairs(Players:GetPlayers()) do CreateESP(p) end
Players.PlayerAdded:Connect(CreateESP)
-------------------------------------------------------------------
-- [[ 6. ALIVE FOLDER MOB ESP (เน้นสแกนในโฟลเดอร์ Alive) ]] --
-------------------------------------------------------------------
local AliveFolder = workspace:FindFirstChild("Alive")

local function ApplyMobESP(model)
    -- ถ้าเป็นคน (Player) ระบบเดิมของคุณจัดการอยู่แล้ว เราจะข้ามไป
    if game.Players:GetPlayerFromCharacter(model) then return end
    
    -- ตรวจสอบว่ามี Humanoid และยังไม่มี ESP ของเรา
    local hum = model:WaitForChild("Humanoid", 5)
    if hum and not model:FindFirstChild("Mob_ESP_Label") then
        
        task.spawn(function()
            local bgui = Instance.new("BillboardGui", model)
            bgui.Name = "Mob_ESP_Label"
            bgui.AlwaysOnTop = true
            bgui.Size = UDim2.new(0, 150, 0, 50)
            bgui.ExtentsOffset = Vector3.new(0, 3, 0)

            local label = Instance.new("TextLabel", bgui)
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 1, 0)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 12
            label.TextColor3 = Color3.fromRGB(255, 145, 0) -- สีส้ม Mob
            label.TextStrokeTransparency = 0

            -- อัปเดตเลือด Mob
            while model.Parent and hum.Health > 0 do
                label.Text = "[ MOB ]\n" .. model.Name .. "\nHP: " .. math.floor(hum.Health)
                task.wait(1)
            end
            bgui:Destroy()
        end)
    end
end

-- สแกนใน Alive Folder ทันทีที่รัน
if AliveFolder then
    for _, v in pairs(AliveFolder:GetChildren()) do
        ApplyMobESP(v)
    end

    -- ดักจับ Mob ใหม่ที่เกิดในโฟลเดอร์ Alive
    AliveFolder.ChildAdded:Connect(function(child)
        task.wait(0.5) -- รอให้โหลดครบ
        ApplyMobESP(child)
    end)
else
    warn("❌ ไม่พบโฟลเดอร์ชื่อ Alive ใน Workspace")
end

print("--- [ Alive Mob ESP Loaded ] ---")
print("--- [ All Modules Combined Successfully ] ---")
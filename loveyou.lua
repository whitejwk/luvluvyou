local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

-- ==========================================
-- โหลด Fluent UI
-- ==========================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Devwhite",
    SubTitle = "Tower Defense",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl 
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "box" }),
    Join = Window:AddTab({ Title = "Join", Icon = "map-pin" }),
    Macro = Window:AddTab({ Title = "Macro", Icon = "play" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}
local Options = Fluent.Options

-- ==========================================
-- ตัวแปรระบบ & Remotes
-- ==========================================
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaceRemote = Remotes:WaitForChild("PlaceRequest")
local MatchActionRemote = Remotes:WaitForChild("MatchAction")
local SellRemote = Remotes:WaitForChild("SellRequest")
local ActiveAbilityRemote = Remotes:WaitForChild("ActiveAbility")
local InventoryRequestRemote = Remotes:WaitForChild("InventoryRequest")
local QuestsRemote = Remotes:WaitForChild("Quests") 
local RoomRemote = Remotes:WaitForChild("LobbyRoomAction") 



local folderPath = "Makeaimacro/AAclone/Macro/"
local isRecording = false
local isPlaying = false
local isMacroActive = false 
local activePlayThread = nil 
local activeMacroFile = ""

local recordedData = {}
local recordStartTime = 0
local stepCounter = 1

pcall(function()
    if makefolder then 
        pcall(makefolder, "Makeaimacro")
        pcall(makefolder, "Makeaimacro/AAclone")
        pcall(makefolder, "Makeaimacro/AAclone/Macro")
    end
end)
-- ==========================================
-- ระบบ Anti-AFK (ป้องกันการถูกเตะเมื่ออยู่นิ่ง)
-- ==========================================

Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("🛡️ [Anti-AFK] ป้องกันการหลุดสำเร็จ!")
end)

-- ==========================================
-- ฟังก์ชันช่วยเหลือ
-- ==========================================
local function getMacroFiles()
    local files = {}
    pcall(function()
        if isfolder and isfolder(folderPath) then
            for _, file in ipairs(listfiles(folderPath)) do
                local fileName = file:match("([^/%\\]+)%.json$")
                if fileName then table.insert(files, fileName) end
            end
        end
    end)
    if #files == 0 then return {"ไม่มีไฟล์ (กรุณาสร้างใหม่)"} end
    return files
end

local function createPosString(vec3, yawAngle)
    local cf = CFrame.new(vec3) * CFrame.Angles(0, math.rad(yawAngle), 0)
    local comps = {cf:components()}
    for i, v in ipairs(comps) do comps[i] = string.format("%.8f", v) end
    return table.concat(comps, ", ")
end

local function parsePosData(posString)
    local s = string.split(posString, ", ")
    local numbers = {}
    for i=1, 12 do numbers[i] = tonumber(s[i]) end
    local vec3 = Vector3.new(numbers[1], numbers[2], numbers[3])
    local cf = CFrame.new(unpack(numbers))
    local _, yAngle, _ = cf:ToEulerAnglesYXZ()
    return vec3, math.deg(yAngle)
end

local function getUnitInstance(targetPos)
    local placedFolder = Workspace:FindFirstChild("PlacedUnits")
    if not placedFolder then return nil end
    for _, unit in pairs(placedFolder:GetChildren()) do
        local currentPos = unit:GetPivot().Position
        local dist = math.sqrt((currentPos.X - targetPos.X)^2 + (currentPos.Z - targetPos.Z)^2)
        if dist < 3 then return unit end
    end
    return nil
end

local function getPlaceId(targetPos)
    local unit = getUnitInstance(targetPos)
    if unit then return unit:GetAttribute("PlaceId") end
    return nil
end

local function getPosStringFromId(targetId)
    local placedFolder = Workspace:FindFirstChild("PlacedUnits")
    if placedFolder then
        for _, unit in pairs(placedFolder:GetChildren()) do
            if unit:GetAttribute("PlaceId") == targetId then
                return createPosString(unit:GetPivot().Position, 0)
            end
        end
    end
    return "0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1"
end


-- UI Components

--------------------------------------------
-- Main
--------------------------------------------
local AutoReplayToggle = Tabs.Main:AddToggle("AutoReplay", {Title = "Auto Replay", Default = false })
local AutoVoteToggle = Tabs.Main:AddToggle("AutoVote", {Title = "Auto Vote Start", Default = false })
local ClaimQuestToggle = Tabs.Main:AddToggle("claimquest", {Title = "Claim Quest ", Default = false })

--------------------------------------------

-- story
local SectionJoin = Tabs.Join:AddSection("Story")

local MapDrop = Tabs.Join:AddDropdown("JoinMap", { Title = "Map", Values = {"Namek", "Wall Maria", "Shibuya", "Fate"}, Default = 1 })
local ActDrop = Tabs.Join:AddDropdown("JoinAct", { Title = "Act", Values = {"1", "2", "3", "4", "5", "6"}, Default = 1 })
local DiffDrop = Tabs.Join:AddDropdown("JoinDiff", { Title = "Difficulty", Values = {"Normal", "Hard", "Nightmare", "Infinite"}, Default = 1 })
local JoinStoryToggle = Tabs.Join:AddToggle("JoinStory", {Title = "Join Story", Default = false })

-- raid
local SectionJoin = Tabs.Join:AddSection("Raid")

local RaidMapDrop = Tabs.Join:AddDropdown("RaidMap", { Title = "Raid Map", Values = {"Storm Hideout", "Entertainment District", "Strange Town"}, Default = 1 })
local RaidActDrop = Tabs.Join:AddDropdown("RaidAct", { Title = "Raid Act", Values = {"1", "2", "3", "4", "5"}, Default = 1 })
--==--local RaidDiffDrop = Tabs.Join:AddDropdown("RaidDiff", { Title = "Raid Difficulty", Values = {"Hard"}, Default = 1 })
local JoinRaidToggle = Tabs.Join:AddToggle("JoinRaid", {Title = "Join Raid", Default = false })

-- halloween
local SectionJoin = Tabs.Join:AddSection("Halloween")
local difficultyDrop = Tabs.Join:AddDropdown("HalloweenDiff", { Title = "Halloween Difficulty", Values = {"Normal", "Hard", "Nightmare"}, Default = 1 })
local JoinhalloweenToggle = Tabs.Join:AddToggle("JoinHalloween", {Title = "Join Halloween", Default = false })

--------------------------------------------
-- Macro
--------------------------------------------
local PlayToggle = Tabs.Macro:AddToggle("PlayToggle", {Title = "▶ Playmacro", Default = false })
local RecordToggle = Tabs.Macro:AddToggle("RecordToggle", {Title = "Record", Default = false })

local MacroDropdown = Tabs.Macro:AddDropdown("MacroDropdown", { Title = "Select File", Values = getMacroFiles(), Multi = false, Default = 1 })
local FileNameInput = Tabs.Macro:AddInput("FileNameInput", { Title = "📝 Create New Macro File", Default = "", Placeholder = "Set File Name (No need to include .json)", Numeric = false, Finished = false, Callback = function(Value) end })

--------------------------------------------
-- Functions join
-- ตัวแปรเก็บสถานะการทำงาน
local isJoinStory = false
local isJoinRaid = false
local isJoinHalloween = false

-- ฐานข้อมูลอ้างอิงชื่อแผนที่
local MapIds = {
    ["Namek"] = "namek",
    ["Wall Maria"] = "wall_maria",
    ["Shibuya"] = "shibuya",
    ["Fate"] = "fate",
    ["Storm Hideout"] = "storm_hideout",
    ["Entertainment District"] = "entertainment_district",
    ["Strange Town"] = "strange_town"
}

-- ==========================================
-- ฟังก์ชัน Join Story
-- ==========================================
JoinStoryToggle:OnChanged(function(Value)
    isJoinStory = Value
    if isJoinStory then
        task.spawn(function()
            while isJoinStory do
                local char = Players.LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    -- วาร์ปไปประตู Story
                    root.CFrame = CFrame.new(65885.0625, 11.7461128, 33.2876129, 1, 0, 0, 0, 1, 0, 0, 0, 1)
                    task.wait(1.5)

                    local mapName = Options.JoinMap.Value
                    local actVal = Options.JoinAct.Value
                    local diffName = Options.JoinDiff.Value
                    
                    local baseMapId = MapIds[mapName] or "namek"
                    local finalMapId = baseMapId
                    
                    -- ตรวจสอบเงื่อนไขชื่อด่าน
                    if diffName == "Infinite" then
                        finalMapId = baseMapId .. "_infinite"
                    else
                        if actVal == "1" then
                            finalMapId = baseMapId
                        else
                            finalMapId = baseMapId .. "_" .. actVal
                        end
                    end
                    
                    pcall(function()
                        RoomRemote:FireServer("select", finalMapId, string.lower(diffName))
                    end)
                    task.wait(0.5)
                    pcall(function()
                        RoomRemote:FireServer("start")
                    end)
                end
                task.wait(3) -- หน่วงเวลาป้องกันลูปรันรัวเกินไป
            end
        end)
    end
end)

-- ==========================================
-- ฟังก์ชัน Join Raid
-- ==========================================
JoinRaidToggle:OnChanged(function(Value)
    isJoinRaid = Value
    if isJoinRaid then
        task.spawn(function()
            while isJoinRaid do
                local char = Players.LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    -- วาร์ปไปประตู Raid
                    root.CFrame = CFrame.new(65942.4922, 2.39853287, -143.291794, 0.707134247, 0, 0.707079291, 0, 1, 0, -0.707079291, 0, 0.707134247)
                    task.wait(1.5)

                    local mapName = Options.RaidMap.Value
                    local actVal = Options.RaidAct.Value
                    local diffName = "hard" -- Raid บังคับ Hard เสมอ
                    
                    local baseMapId = MapIds[mapName] or "storm_hideout"
                    local finalMapId = baseMapId .. "_" .. actVal
                    
                    pcall(function()
                        RoomRemote:FireServer("select", finalMapId, diffName)
                    end)
                    task.wait(0.5)
                    pcall(function()
                        RoomRemote:FireServer("start")
                    end)
                end
                task.wait(3)
            end
        end)
    end
end)

-- ==========================================
-- ฟังก์ชัน Join Halloween
-- ==========================================
JoinhalloweenToggle:OnChanged(function(Value)
    isJoinHalloween = Value
    if isJoinHalloween then
        task.spawn(function()
            while isJoinHalloween do
                local char = Players.LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    -- วาร์ปไปประตู Halloween (จุดเดียวกับ Story)
                    root.CFrame = CFrame.new(65885.0625, 11.7461128, 33.2876129, 1, 0, 0, 0, 1, 0, 0, 0, 1)
                    task.wait(1.5)

                    local diffName = Options.HalloweenDiff.Value
                    
                    pcall(function()
                        RoomRemote:FireServer("select", "helloween", string.lower(diffName))
                    end)
                    task.wait(0.5)
                    pcall(function()
                        RoomRemote:FireServer("start")
                    end)
                end
                task.wait(3)
            end
        end)
    end
end)



---------------------------------------------
Tabs.Macro:AddButton({
    Title = "💾 Save Created File",
    Callback = function()
        local name = Options.FileNameInput.Value
        if name and name ~= "" then
            name = string.gsub(name, ".json", "")
            local fullPath = folderPath .. name .. ".json"
            pcall(function() writefile(fullPath, "{}") end)
            Fluent:Notify({ Title = "Success", Content = "File created: " .. name .. ".json", Duration = 3 })
            Options.MacroDropdown:SetValues(getMacroFiles())
            Options.MacroDropdown:SetValue(name)
        else
            Fluent:Notify({ Title = "Error", Content = "Please enter a file name", Duration = 3 })
        end
    end
})

MacroDropdown:OnChanged(function(Value)
    if Value ~= "No files available (please create a new one)" then
        activeMacroFile = folderPath .. Value .. ".json"
    end
end)

RecordToggle:OnChanged(function()
    isRecording = Options.RecordToggle.Value
    if isRecording then
        if activeMacroFile == "" then
            Fluent:Notify({ Title = "Notification", Content = "select a file for recording.", Duration = 3 })
            Options.RecordToggle:SetValue(false)
            return
        end
        recordedData = {}
        recordStartTime = tick()
        stepCounter = 1
        Fluent:Notify({ Title = "Record", Content = "Start recording", Duration = 2 })
    else
        if activeMacroFile ~= "" then
            if stepCounter > 1 then
                local jsonString = HttpService:JSONEncode(recordedData)
                pcall(function() writefile(activeMacroFile, jsonString) end)
                local totalSteps = stepCounter - 1
                Fluent:Notify({ Title = "Record", Content = "saved successfully! (" .. totalSteps .. " คิว)", Duration = 3 })
            else
                Fluent:Notify({ Title = "Record", Content = "No data recorded!", Duration = 3 })
            end
        end
    end
end)

local function playMacroFunc()
    while isPlaying do
        local success, fileData = pcall(function() return readfile(activeMacroFile) end)
        if not success then 
            break 
        end

        local macroData = HttpService:JSONDecode(fileData)
        local steps = {}
        for key, data in pairs(macroData) do table.insert(steps, { index = tonumber(key), action = data }) end
        table.sort(steps, function(a, b) return a.index < b.index end)

        local startTime = tick()
        isMacroActive = true 

        for _, stepInfo in ipairs(steps) do
            if not isPlaying or not isMacroActive then break end
            local step = stepInfo.action
            
            if step.time then
                while (tick() - startTime) < step.time do
                    if not isPlaying or not isMacroActive then break end
                    RunService.RenderStepped:Wait()
                end
            end

            if not isPlaying or not isMacroActive then break end
            local posVec3, yawAngle = parsePosData(step.pos)

            if step.type == "Place" then
                local targetSlot = tonumber(step.slot) or tonumber(step.unit)
                if targetSlot then
                    PlaceRemote:FireServer({ ["slot"] = targetSlot, ["position"] = posVec3, ["yaw"] = yawAngle })
                    task.wait(0.5)
                end
            elseif step.type == "Upgrade" then
                local targetPlaceId = getPlaceId(posVec3)
                if targetPlaceId then
                    MatchActionRemote:FireServer("upgrade", targetPlaceId)
                end
            elseif step.type == "Sell" then
                local targetPlaceId = getPlaceId(posVec3)
                if targetPlaceId then
                    SellRemote:FireServer({ ["copyId"] = targetPlaceId })
                end
            elseif type(step.type) == "string" and step.type == "Ability" then
                local targetUnit = getUnitInstance(posVec3)
                if targetUnit then
                    ActiveAbilityRemote:FireServer("use", targetUnit)
                end
            end
            task.wait(0.1) 
        end
        
        isMacroActive = false
        
        while isPlaying and not isMacroActive do
            task.wait(0.5)
        end
    end
end

PlayToggle:OnChanged(function()
    isPlaying = Options.PlayToggle.Value
    if isPlaying then
        if activeMacroFile == "" then
            Fluent:Notify({ Title = "Notification", Content = "Please select a file before running", Duration = 3 })
            Options.PlayToggle:SetValue(false)
            return
        end
        if activePlayThread then task.cancel(activePlayThread) end
        activePlayThread = task.spawn(playMacroFunc)
    else
        if activePlayThread then task.cancel(activePlayThread); activePlayThread = nil end
        isMacroActive = false
    end
end)

-- ==========================================
-- ลูปการทำงานเบื้องหลัง (คุมการทำงานของ Macro, Replay, Vote Start แบบใหม่)
-- ==========================================
task.spawn(function()
    -- ดึงโฟลเดอร์เก็บยูนิตของเกมมาไว้ตรวจสอบ
    local placedFolder = Workspace:WaitForChild("PlacedUnits", 10)

    while task.wait(1) do -- เช็คข้อมูลทุกๆ 1 วินาที
        
        -- 1. ระบบ Auto พื้นฐาน
        if Options.AutoReplay.Value then pcall(function() MatchActionRemote:FireServer("replay") end) end
        if Options.claimquest.Value then pcall(function() QuestsRemote:InvokeServer(unpack({[1] = "claimAll"})) end) end
        
        -- ถ้าเปิด Auto Vote Start ทิ้งไว้ (โดยไม่ได้เปิดรันมาโคร) ก็ให้มันกดปกติ
        if Options.AutoVote.Value and not isPlaying then 
            pcall(function() MatchActionRemote:FireServer("voteStart", true) end) 
        end

        -- 2. ระบบรันมาโครอัตโนมัติเมื่อรีเพลย์
        if isPlaying and placedFolder then
            -- ถ้าในด่านไม่มีตัวละครเลย (เพิ่งเข้าแมพ หรือ แมพเพิ่งรีเซ็ตจาก Replay) 
            -- และมาโครรอบเก่าวางจนจบแล้ว (isMacroActive เป็น false)
            if #placedFolder:GetChildren() == 0 and not isMacroActive then
                print("🔄 แมพถูกรีเซ็ต (รอ 2 วินาที...)")
                task.wait(2) -- รอ 2 วินาที
                
                print("✅ กด Vote Start และเริ่มรันมาโคร!")
                pcall(function() MatchActionRemote:FireServer("voteStart", true) end)
                
                isMacroActive = true -- เปิดสวิตช์ให้สคริปต์มาโครเริ่มทำงาน
            end
        end
    end
end)

-- ==========================================
-- ระบบ Hook ดักจับข้อมูล
-- ==========================================

-------------------------------------
-- ==========================================
-- ระบบ Hook ดักจับข้อมูล (อัปเดตระบบ Record ใหม่)
-- ==========================================
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if tostring(method) == "FireServer" or tostring(method) == "fireServer" then
        
        if isRecording then
            task.spawn(function()
                pcall(function()
                    local currentTime = math.floor(tick() - recordStartTime)
                    
                    if self.Name == "PlaceRequest" then
                        local slotInfo = args[1]
                        local yaw = slotInfo.yaw or 0 
                        recordedData[tostring(stepCounter)] = {
                            type = "Place",
                            time = currentTime,
                            money = 0,
                            pos = createPosString(slotInfo.position, yaw),
                            slot = slotInfo.slot
                        }
                        print("🔴 [บันทึก] วาง Slot " .. tostring(slotInfo.slot))
                        stepCounter = stepCounter + 1

                    elseif self.Name == "MatchAction" and args[1] == "upgrade" then
                        local unitId = args[2]
                        recordedData[tostring(stepCounter)] = {
                            type = "Upgrade",
                            time = currentTime,
                            money = 0,
                            pos = getPosStringFromId(unitId),
                            slot = 1
                        }
                        print("🔴 [บันทึก] อัปเกรดตัวละคร ID: " .. tostring(unitId))
                        stepCounter = stepCounter + 1
                        
                    elseif self.Name == "SellRequest" then
                        local unitId = args[1].copyId
                        recordedData[tostring(stepCounter)] = {
                            type = "Sell",
                            time = currentTime,
                            money = 0,
                            pos = getPosStringFromId(unitId),
                            slot = 1
                        }
                        print("🔴 [บันทึก] ขายตัวละคร ID: " .. tostring(unitId))
                        stepCounter = stepCounter + 1
                        
                    elseif self.Name == "ActiveAbility" and args[1] == "use" then
                        local unitInstance = args[2]
                        if typeof(unitInstance) == "Instance" then
                            recordedData[tostring(stepCounter)] = {
                                type = "Ability",
                                time = currentTime,
                                money = 0,
                                pos = createPosString(unitInstance:GetPivot().Position, 0),
                                slot = 1
                            }
                            print("🔴 [บันทึก] กดใช้สกิลตัวละคร: " .. tostring(unitInstance.Name))
                            stepCounter = stepCounter + 1
                        end
                    end
                end)
            end)
        end
    end
    
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)
-- ==========================================
-- Settings Manager
-- ==========================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
Fluent:Notify({ Title = "White", Content = "Loaded script successfully!", Duration = 5 })
SaveManager:LoadAutoloadConfig()

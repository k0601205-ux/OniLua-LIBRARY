local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Mouse = LocalPlayer:GetMouse()

local FADE_TIME = 0.12
local FADE_TWEEN = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WIN10_ANIM_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SNAP_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TASKBAR_SLIDE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Bảng màu các nút
local COLOR_CLOSE_ACTIVE = Color3.fromRGB(255, 79, 79)
local COLOR_MAX_ACTIVE   = Color3.fromRGB(118, 255, 94)
local COLOR_MIN_ACTIVE   = Color3.fromRGB(255, 255, 98)
local COLOR_NAV_INACTIVE = Color3.fromRGB(115, 115, 115)
local COLOR_NAV_DISABLED = Color3.fromRGB(75, 75, 75)

local SystemOS = {}
SystemOS.__index = SystemOS
SystemOS.IsInitialized = false
SystemOS.Windows = {}
SystemOS.ActiveContextMenus = {}
SystemOS.ZCounter = 100
SystemOS.ActiveWindow = nil
SystemOS.ModalWindow = nil

SystemOS.AutoHideTaskbar = false
local taskbarShowing = true
local mouseLeaveTaskbarTime = 0
local autoHideTaskbarTween = nil
local lastMenuOpenClock = 0 -- Chống kẹt click đóng menu

local function GetAutoTargetParent()
    if RunService:IsStudio() then
        return LocalPlayer:WaitForChild("PlayerGui")
    end

    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end

    local okCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if okCore and coreGui then
        local canAccess = pcall(function()
            local test = Instance.new("Folder")
            test.Parent = coreGui
            test:Destroy()
        end)
        if canAccess then return coreGui end
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

-- LẤY TOẠ ĐỘ CHUỘT CHUẨN XÁC: FIX LỆCH CHUỘT PHẢI
local function GetExactMousePosition()
    if SystemOS.ScreenGui and SystemOS.ScreenGui.IgnoreGuiInset then
        return UserInputService:GetMouseLocation()
    end
    if LocalPlayer and LocalPlayer:GetMouse() then
        local m = LocalPlayer:GetMouse()
        return Vector2.new(m.X, m.Y)
    end
    local mouseLoc = UserInputService:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    return Vector2.new(mouseLoc.X - inset.X, mouseLoc.Y - inset.Y)
end

local function UpdateDesktopLayout()
    if not SystemOS.Desktop then return end

    local hasTopBar = (SystemOS.Top and SystemOS.Top.Visible == true)
    local isAutoHide = (SystemOS.AutoHideTaskbar == true)

    local topOffset = hasTopBar and 20 or 0
    local bottomOffset = isAutoHide and 0 or 40

    local targetPos = UDim2.new(0, 0, 0, topOffset)
    local targetSize = UDim2.new(1, 0, 1, -(topOffset + bottomOffset))

    local tween = TweenService:Create(SystemOS.Desktop, SNAP_TWEEN_INFO, {
        Position = targetPos,
        Size = targetSize
    })
    tween:Play()
end

local function ShowTaskbarAnim()
    if taskbarShowing or not SystemOS.Taskbar then return end
    taskbarShowing = true
    if autoHideTaskbarTween then autoHideTaskbarTween:Cancel() end
    autoHideTaskbarTween = TweenService:Create(SystemOS.Taskbar, TASKBAR_SLIDE_INFO, {
        Position = UDim2.new(0, 0, 1, 0)
    })
    autoHideTaskbarTween:Play()
end

local function HideTaskbarAnim()
    if not taskbarShowing or not SystemOS.Taskbar or not SystemOS.AutoHideTaskbar then return end
    taskbarShowing = false
    if autoHideTaskbarTween then autoHideTaskbarTween:Cancel() end
    autoHideTaskbarTween = TweenService:Create(SystemOS.Taskbar, TASKBAR_SLIDE_INFO, {
        Position = UDim2.new(0, 0, 1, 40)
    })
    autoHideTaskbarTween:Play()
end

--------------------------------------------------------------------------------
-- 1. BẢN VẼ G2L GỐC - ĐẦY ĐỦ 100% 176 INSTANCES (KHÔNG CẮT BỚT BẤT KỲ CÁI GÌ)
--------------------------------------------------------------------------------
local function BuildOriginalStructure()
    local G2L = {}

    -- StarterGui.SystemUI
    G2L["1"] = Instance.new("ScreenGui")
    G2L["1"]["Name"] = [[SystemUI]]
    G2L["1"]["ZIndexBehavior"] = Enum.ZIndexBehavior.Sibling
    G2L["1"]["DisplayOrder"] = 2147483647

    -- StarterGui.SystemUI.Top
    G2L["2"] = Instance.new("Frame", G2L["1"])
    G2L["2"]["BorderSizePixel"] = 0
    G2L["2"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["2"]["Size"] = UDim2.new(1, 0, 0, 20)
    G2L["2"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["2"]["Name"] = [[Top]]
    G2L["2"]["Visible"] = false
    G2L["2"]["ZIndex"] = 50000

    G2L["3"] = Instance.new("UIGradient", G2L["2"])
    G2L["3"]["Rotation"] = 90
    G2L["3"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(85, 85, 85)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(0, 0, 0))}

    -- StarterGui.SystemUI.Top._SYSTEM
    G2L["4"] = Instance.new("Frame", G2L["2"])
    G2L["4"]["BorderSizePixel"] = 0
    G2L["4"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["4"]["AutomaticSize"] = Enum.AutomaticSize.X
    G2L["4"]["Size"] = UDim2.new(0, 20, 1, 0)
    G2L["4"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["4"]["Name"] = [[_SYSTEM]]
    G2L["4"]["BackgroundTransparency"] = 1

    G2L["5"] = Instance.new("UIListLayout", G2L["4"])
    G2L["5"]["Padding"] = UDim.new(0, 1)
    G2L["5"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["5"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["5"]["FillDirection"] = Enum.FillDirection.Horizontal

    -- StarterGui.SystemUI.Top._SYSTEM.Menu
    G2L["6"] = Instance.new("ImageButton", G2L["4"])
    G2L["6"]["BorderSizePixel"] = 0
    G2L["6"]["ScaleType"] = Enum.ScaleType.Fit
    G2L["6"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["6"]["ImageColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["6"]["Size"] = UDim2.new(0, 40, 1, 0)
    G2L["6"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["6"]["Name"] = [[Menu]]

    G2L["7"] = Instance.new("UIGradient", G2L["6"])
    G2L["7"]["Rotation"] = 90
    G2L["7"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(0, 0, 0))}

    G2L["8"] = Instance.new("TextLabel", G2L["6"])
    G2L["8"]["BorderSizePixel"] = 0
    G2L["8"]["TextSize"] = 14
    G2L["8"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["8"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    G2L["8"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["8"]["BackgroundTransparency"] = 1
    G2L["8"]["Size"] = UDim2.new(1, 0, 1, 0)
    G2L["8"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["8"]["Text"] = [[O]]
    G2L["8"]["Name"] = [[LOGO]]

    G2L["9"] = Instance.new("UIListLayout", G2L["2"])
    G2L["9"]["Padding"] = UDim.new(0, 1)
    G2L["9"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["9"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["9"]["FillDirection"] = Enum.FillDirection.Horizontal

    -- StarterGui.SystemUI.Top.Custom
    G2L["a"] = Instance.new("Frame", G2L["2"])
    G2L["a"]["BorderSizePixel"] = 0
    G2L["a"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["a"]["Size"] = UDim2.new(1, -41, 1, 0)
    G2L["a"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["a"]["Name"] = [[Custom]]
    G2L["a"]["LayoutOrder"] = 1
    G2L["a"]["BackgroundTransparency"] = 1

    -- StarterGui.SystemUI.Top.Custom.Game
    G2L["b"] = Instance.new("ImageButton", G2L["a"])
    G2L["b"]["BorderSizePixel"] = 0
    G2L["b"]["ScaleType"] = Enum.ScaleType.Fit
    G2L["b"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["b"]["ImageColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["b"]["AutomaticSize"] = Enum.AutomaticSize.X
    G2L["b"]["Size"] = UDim2.new(0, 45, 1, 0)
    G2L["b"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["b"]["Name"] = [[Game]]

    G2L["c"] = Instance.new("TextLabel", G2L["b"])
    G2L["c"]["BorderSizePixel"] = 0
    G2L["c"]["TextSize"] = 14
    G2L["c"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["c"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["c"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["c"]["BackgroundTransparency"] = 1
    G2L["c"]["Size"] = UDim2.new(1, 0, 1, 0)
    G2L["c"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["c"]["Text"] = [[Game]]
    G2L["c"]["AutomaticSize"] = Enum.AutomaticSize.X
    G2L["c"]["Name"] = [[LOGO]]

    G2L["d"] = Instance.new("UIGradient", G2L["b"])
    G2L["d"]["Rotation"] = 90
    G2L["d"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(85, 85, 85)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(0, 0, 0))}

    G2L["e"] = Instance.new("UIListLayout", G2L["a"])
    G2L["e"]["Padding"] = UDim.new(0, 1)
    G2L["e"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["e"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["e"]["FillDirection"] = Enum.FillDirection.Horizontal

    -- StarterGui.SystemUI.Container_MAINDESTOP
    G2L["f"] = Instance.new("Frame", G2L["1"])
    G2L["f"]["BorderSizePixel"] = 0
    G2L["f"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["f"]["ClipsDescendants"] = true
    G2L["f"]["Size"] = UDim2.new(1, 0, 1, -40)
    G2L["f"]["Position"] = UDim2.new(0, 0, 0, 0)
    G2L["f"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["f"]["Name"] = [[Container_MAINDESTOP]]
    G2L["f"]["BackgroundTransparency"] = 1

    -- Snap Preview Frame
    local SnapPreview = Instance.new("Frame", G2L["f"])
    SnapPreview.Name = "SnapPreview"
    SnapPreview.BorderSizePixel = 0
    SnapPreview.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    SnapPreview.BackgroundTransparency = 0.8
    SnapPreview.Visible = false
    SnapPreview.ZIndex = 35000

    local spCorner = Instance.new("UICorner", SnapPreview)
    spCorner.CornerRadius = UDim.new(0, 6)

    local spStroke = Instance.new("UIStroke", SnapPreview)
    spStroke.Color = Color3.fromRGB(0, 150, 255)
    spStroke.Thickness = 1.5

    -- StarterGui.SystemUI.Container_MAINDESTOP.Window (ImageButton chống click xuyên)
    G2L["10"] = Instance.new("ImageButton", G2L["f"])
    G2L["10"]["BorderSizePixel"] = 0
    G2L["10"]["AutoButtonColor"] = false
    G2L["10"]["BackgroundColor3"] = Color3.fromRGB(77, 77, 77)
    G2L["10"]["Size"] = UDim2.new(0, 200, 0, 200)
    G2L["10"]["Position"] = UDim2.new(0.4654, 0, 0.43835, 0)
    G2L["10"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["10"]["Name"] = [[Window]]

    G2L["11"] = Instance.new("ImageButton", G2L["10"])
    G2L["11"]["BorderSizePixel"] = 0
    G2L["11"]["AutoButtonColor"] = false
    G2L["11"]["BackgroundColor3"] = Color3.fromRGB(59, 59, 59)
    G2L["11"]["Size"] = UDim2.new(1, 0, 0, 25)
    G2L["11"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["11"]["Name"] = [[TopBar]]

    G2L["12"] = Instance.new("UICorner", G2L["11"])
    G2L["12"]["CornerRadius"] = UDim.new(0, 5)

    G2L["13"] = Instance.new("Frame", G2L["11"])
    G2L["13"]["BorderSizePixel"] = 0
    G2L["13"]["BackgroundColor3"] = Color3.fromRGB(59, 59, 59)
    G2L["13"]["AnchorPoint"] = Vector2.new(0, 1)
    G2L["13"]["Size"] = UDim2.new(1, 0, 0.5, 0)
    G2L["13"]["Position"] = UDim2.new(0, 0, 1, 0)
    G2L["13"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["13"]["Name"] = [[Fix]]

    G2L["14"] = Instance.new("Frame", G2L["11"])
    G2L["14"]["BorderSizePixel"] = 0
    G2L["14"]["BackgroundColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["14"]["AnchorPoint"] = Vector2.new(0, 1)
    G2L["14"]["Size"] = UDim2.new(1, 0, 0, 1)
    G2L["14"]["Position"] = UDim2.new(0, 0, 1, 0)
    G2L["14"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["14"]["Name"] = [[Line]]

    G2L["15"] = Instance.new("Frame", G2L["11"])
    G2L["15"]["BorderSizePixel"] = 0
    G2L["15"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["15"]["Size"] = UDim2.new(0.5, 0, 1, 0)
    G2L["15"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["15"]["Name"] = [[Title]]
    G2L["15"]["BackgroundTransparency"] = 1

    G2L["16"] = Instance.new("TextLabel", G2L["15"])
    G2L["16"]["BorderSizePixel"] = 0
    G2L["16"]["TextSize"] = 14
    G2L["16"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["16"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["16"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["16"]["BackgroundTransparency"] = 1
    G2L["16"]["Size"] = UDim2.new(0, 5, 1, 0)
    G2L["16"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["16"]["Text"] = [[BOX]]
    G2L["16"]["AutomaticSize"] = Enum.AutomaticSize.X
    G2L["16"]["Name"] = [[Text]]

    G2L["17"] = Instance.new("UIPadding", G2L["15"])
    G2L["17"]["PaddingLeft"] = UDim.new(0, 5)

    G2L["18"] = Instance.new("Frame", G2L["11"])
    G2L["18"]["BorderSizePixel"] = 0
    G2L["18"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["18"]["AnchorPoint"] = Vector2.new(1, 0)
    G2L["18"]["Size"] = UDim2.new(0.5, 0, 1, 0)
    G2L["18"]["Position"] = UDim2.new(1, 0, 0, 0)
    G2L["18"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["18"]["Name"] = [[Nav]]
    G2L["18"]["BackgroundTransparency"] = 1

    G2L["19"] = Instance.new("UIPadding", G2L["18"])
    G2L["19"]["PaddingRight"] = UDim.new(0, 5)

    G2L["1a"] = Instance.new("UIListLayout", G2L["18"])
    G2L["1a"]["HorizontalAlignment"] = Enum.HorizontalAlignment.Right
    G2L["1a"]["Padding"] = UDim.new(0, 5)
    G2L["1a"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["1a"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["1a"]["FillDirection"] = Enum.FillDirection.Horizontal

    G2L["1b"] = Instance.new("ImageButton", G2L["18"])
    G2L["1b"]["BorderSizePixel"] = 0
    G2L["1b"]["BackgroundColor3"] = COLOR_CLOSE_ACTIVE
    G2L["1b"]["Size"] = UDim2.new(0, 15, 0, 15)
    G2L["1b"]["LayoutOrder"] = 999999999
    G2L["1b"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["1b"]["Name"] = [[_CLOSE]]

    G2L["1c"] = Instance.new("UICorner", G2L["1b"])
    G2L["1c"]["CornerRadius"] = UDim.new(1, 0)
    G2L["1d"] = Instance.new("UIStroke", G2L["1b"])

    G2L["1e"] = Instance.new("ImageButton", G2L["18"])
    G2L["1e"]["BorderSizePixel"] = 0
    G2L["1e"]["BackgroundColor3"] = COLOR_MAX_ACTIVE
    G2L["1e"]["Size"] = UDim2.new(0, 15, 0, 15)
    G2L["1e"]["LayoutOrder"] = 999999998
    G2L["1e"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["1e"]["Name"] = [[_MAXIMIZE]]

    G2L["1f"] = Instance.new("UICorner", G2L["1e"])
    G2L["1f"]["CornerRadius"] = UDim.new(1, 0)
    G2L["20"] = Instance.new("UIStroke", G2L["1e"])

    G2L["21"] = Instance.new("ImageButton", G2L["18"])
    G2L["21"]["BorderSizePixel"] = 0
    G2L["21"]["BackgroundColor3"] = COLOR_MIN_ACTIVE
    G2L["21"]["Size"] = UDim2.new(0, 15, 0, 15)
    G2L["21"]["LayoutOrder"] = 999999997
    G2L["21"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["21"]["Name"] = [[_MINIMIZE]]

    G2L["22"] = Instance.new("UICorner", G2L["21"])
    G2L["22"]["CornerRadius"] = UDim.new(1, 0)
    G2L["23"] = Instance.new("UIStroke", G2L["21"])

    G2L["24"] = Instance.new("UICorner", G2L["10"])
    G2L["24"]["CornerRadius"] = UDim.new(0, 5)
    G2L["25"] = Instance.new("UIStroke", G2L["10"])

    -- Canvas Frame (Khóa ClipsDescendants = true)
    G2L["26"] = Instance.new("Frame", G2L["10"])
    G2L["26"]["BorderSizePixel"] = 0
    G2L["26"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["26"]["Size"] = UDim2.new(1, 0, 1, -28)
    G2L["26"]["Position"] = UDim2.new(0, 0, 0, 25)
    G2L["26"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["26"]["Name"] = [[Canvas]]
    G2L["26"]["ClipsDescendants"] = true

    -- ResizeSystem
    G2L["27"] = Instance.new("Folder", G2L["10"])
    G2L["27"]["Name"] = [[ResizeSystem]]

    local function MakeResizeHandle(name, anchor, pos, size)
        local btn = Instance.new("ImageButton", G2L["27"])
        btn.BorderSizePixel = 0
        btn.BackgroundTransparency = 1
        btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        btn.AnchorPoint = anchor
        btn.Position = pos
        btn.Size = size
        btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
        btn.Name = name
        return btn
    end

    G2L["28"] = MakeResizeHandle([[Left]], Vector2.new(0.5, 0.5), UDim2.new(1, 0, 0.5, 0), UDim2.new(0, 5, 1, -10))
    G2L["29"] = MakeResizeHandle([[Right]], Vector2.new(0.5, 0.5), UDim2.new(0, 0, 0.5, 0), UDim2.new(0, 5, 1, -10))
    G2L["2a"] = MakeResizeHandle([[Top]], Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0, 0), UDim2.new(1, -10, 0, 5))
    G2L["2b"] = MakeResizeHandle([[Bottom]], Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 1, 0), UDim2.new(1, -10, 0, 5))
    G2L["2c"] = MakeResizeHandle([[Left-Top]], Vector2.new(0.5, 0.5), UDim2.new(1, 0, 0, 0), UDim2.new(0, 10, 0, 10))
    G2L["2d"] = MakeResizeHandle([[Right-Top]], Vector2.new(0.5, 0.5), UDim2.new(0, 0, 0, 0), UDim2.new(0, 10, 0, 10))
    G2L["2e"] = MakeResizeHandle([[Right-Bottom]], Vector2.new(0.5, 0.5), UDim2.new(0, 0, 1, 0), UDim2.new(0, 10, 0, 10))
    G2L["2f"] = MakeResizeHandle([[Left-Bottom]], Vector2.new(0.5, 0.5), UDim2.new(1, 0, 1, 0), UDim2.new(0, 10, 0, 10))

    -- StarterGui.SystemUI.Container_MAINDESTOP.ContextMenu
    G2L["30"] = Instance.new("CanvasGroup", G2L["f"])
    G2L["30"]["BorderSizePixel"] = 0
    G2L["30"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["30"]["AutomaticSize"] = Enum.AutomaticSize.None
    G2L["30"]["Size"] = UDim2.new(0, 200, 0, 100)
    G2L["30"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["30"]["Name"] = [[ContextMenu]]
    G2L["30"]["ZIndex"] = 99999
    G2L["30"]["GroupTransparency"] = 1

    -- Template: Button_HoldEffect
    G2L["31"] = Instance.new("TextButton", G2L["30"])
    G2L["31"]["BorderSizePixel"] = 0
    G2L["31"]["TextSize"] = 14
    G2L["31"]["AutoButtonColor"] = false
    G2L["31"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["31"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["31"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["31"]["Size"] = UDim2.new(1, 0, 0, 25)
    G2L["31"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["31"]["Text"] = [[]]
    G2L["31"]["Name"] = [[Button_HoldEffect]]

    G2L["32"] = Instance.new("Frame", G2L["31"])
    G2L["32"]["BorderSizePixel"] = 0
    G2L["32"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["32"]["Size"] = UDim2.new(0, 20, 1, 0)
    G2L["32"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["32"]["Name"] = [[BOX]]
    G2L["32"]["BackgroundTransparency"] = 1

    G2L["33"] = Instance.new("UIListLayout", G2L["31"])
    G2L["33"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["33"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["33"]["FillDirection"] = Enum.FillDirection.Horizontal

    G2L["34"] = Instance.new("UIGradient", G2L["31"])
    G2L["34"]["Rotation"] = 90
    G2L["34"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(127, 168, 205))}

    G2L["35"] = Instance.new("Frame", G2L["31"])
    G2L["35"]["BorderSizePixel"] = 0
    G2L["35"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["35"]["Size"] = UDim2.new(1, -45, 1, 0)
    G2L["35"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["35"]["Name"] = [[Content]]
    G2L["35"]["LayoutOrder"] = 1
    G2L["35"]["BackgroundTransparency"] = 1

    G2L["36"] = Instance.new("TextLabel", G2L["35"])
    G2L["36"]["BorderSizePixel"] = 0
    G2L["36"]["TextSize"] = 14
    G2L["36"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["36"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["36"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["36"]["BackgroundTransparency"] = 1
    G2L["36"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["36"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["36"]["AutomaticSize"] = Enum.AutomaticSize.X

    G2L["37"] = Instance.new("Frame", G2L["31"])
    G2L["37"]["BorderSizePixel"] = 0
    G2L["37"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["37"]["Size"] = UDim2.new(0, 25, 1, 0)
    G2L["37"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["37"]["Name"] = [[Right]]
    G2L["37"]["LayoutOrder"] = 2
    G2L["37"]["BackgroundTransparency"] = 1

    -- Template: Button
    G2L["38"] = Instance.new("TextButton", G2L["30"])
    G2L["38"]["BorderSizePixel"] = 0
    G2L["38"]["TextSize"] = 14
    G2L["38"]["AutoButtonColor"] = false
    G2L["38"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["38"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["38"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["38"]["BackgroundTransparency"] = 1
    G2L["38"]["Size"] = UDim2.new(1, 0, 0, 25)
    G2L["38"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["38"]["Text"] = [[]]
    G2L["38"]["Name"] = [[Button]]

    G2L["39"] = Instance.new("Frame", G2L["38"])
    G2L["39"]["BorderSizePixel"] = 0
    G2L["39"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["39"]["Size"] = UDim2.new(0, 20, 1, 0)
    G2L["39"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["39"]["Name"] = [[BOX]]
    G2L["39"]["BackgroundTransparency"] = 1

    G2L["3a"] = Instance.new("UIListLayout", G2L["38"])
    G2L["3a"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["3a"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["3a"]["FillDirection"] = Enum.FillDirection.Horizontal

    G2L["3b"] = Instance.new("UIGradient", G2L["38"])
    G2L["3b"]["Enabled"] = false
    G2L["3b"]["Rotation"] = 90
    G2L["3b"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(127, 168, 205))}

    G2L["3c"] = Instance.new("Frame", G2L["38"])
    G2L["3c"]["BorderSizePixel"] = 0
    G2L["3c"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["3c"]["Size"] = UDim2.new(1, -45, 1, 0)
    G2L["3c"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["3c"]["Name"] = [[Content]]
    G2L["3c"]["LayoutOrder"] = 1
    G2L["3c"]["BackgroundTransparency"] = 1

    G2L["3d"] = Instance.new("TextLabel", G2L["3c"])
    G2L["3d"]["BorderSizePixel"] = 0
    G2L["3d"]["TextSize"] = 14
    G2L["3d"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["3d"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["3d"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["3d"]["BackgroundTransparency"] = 1
    G2L["3d"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["3d"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["3d"]["AutomaticSize"] = Enum.AutomaticSize.X

    G2L["3e"] = Instance.new("Frame", G2L["38"])
    G2L["3e"]["BorderSizePixel"] = 0
    G2L["3e"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["3e"]["Size"] = UDim2.new(0, 25, 1, 0)
    G2L["3e"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["3e"]["Name"] = [[Right]]
    G2L["3e"]["LayoutOrder"] = 2
    G2L["3e"]["BackgroundTransparency"] = 1

    -- Template: Tick_Select
    G2L["3f"] = Instance.new("TextButton", G2L["30"])
    G2L["3f"]["BorderSizePixel"] = 0
    G2L["3f"]["TextSize"] = 14
    G2L["3f"]["AutoButtonColor"] = false
    G2L["3f"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["3f"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["3f"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["3f"]["BackgroundTransparency"] = 1
    G2L["3f"]["Size"] = UDim2.new(1, 0, 0, 25)
    G2L["3f"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["3f"]["Text"] = [[]]
    G2L["3f"]["Name"] = [[Tick_Select]]

    G2L["40"] = Instance.new("Frame", G2L["3f"])
    G2L["40"]["BorderSizePixel"] = 0
    G2L["40"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["40"]["Size"] = UDim2.new(0, 20, 1, 0)
    G2L["40"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["40"]["Name"] = [[BOX]]
    G2L["40"]["BackgroundTransparency"] = 1

    G2L["41"] = Instance.new("Frame", G2L["40"])
    G2L["41"]["BorderSizePixel"] = 0
    G2L["41"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["41"]["AnchorPoint"] = Vector2.new(0.5, 0.5)
    G2L["41"]["Size"] = UDim2.new(0, 7, 0, 7)
    G2L["41"]["Position"] = UDim2.new(0.5, 0, 0.5, 0)
    G2L["41"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["41"]["Name"] = [[Tick]]
    G2L["41"]["Visible"] = false

    G2L["42"] = Instance.new("UICorner", G2L["41"])
    G2L["42"]["CornerRadius"] = UDim.new(1, 0)

    G2L["43"] = Instance.new("UIListLayout", G2L["3f"])
    G2L["43"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["43"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["43"]["FillDirection"] = Enum.FillDirection.Horizontal

    G2L["44"] = Instance.new("UIGradient", G2L["3f"])
    G2L["44"]["Enabled"] = false
    G2L["44"]["Rotation"] = 90
    G2L["44"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(127, 168, 205))}

    G2L["45"] = Instance.new("Frame", G2L["3f"])
    G2L["45"]["BorderSizePixel"] = 0
    G2L["45"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["45"]["Size"] = UDim2.new(1, -45, 1, 0)
    G2L["45"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["45"]["Name"] = [[Content]]
    G2L["45"]["LayoutOrder"] = 1
    G2L["45"]["BackgroundTransparency"] = 1

    G2L["46"] = Instance.new("TextLabel", G2L["45"])
    G2L["46"]["BorderSizePixel"] = 0
    G2L["46"]["TextSize"] = 14
    G2L["46"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["46"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["46"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["46"]["BackgroundTransparency"] = 1
    G2L["46"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["46"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["46"]["AutomaticSize"] = Enum.AutomaticSize.X

    G2L["47"] = Instance.new("Frame", G2L["3f"])
    G2L["47"]["BorderSizePixel"] = 0
    G2L["47"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["47"]["Size"] = UDim2.new(0, 25, 1, 0)
    G2L["47"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["47"]["Name"] = [[Right]]
    G2L["47"]["LayoutOrder"] = 2
    G2L["47"]["BackgroundTransparency"] = 1

    -- Template: Submenu
    G2L["48"] = Instance.new("TextButton", G2L["30"])
    G2L["48"]["BorderSizePixel"] = 0
    G2L["48"]["TextSize"] = 14
    G2L["48"]["AutoButtonColor"] = false
    G2L["48"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["48"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["48"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["48"]["BackgroundTransparency"] = 1
    G2L["48"]["Size"] = UDim2.new(1, 0, 0, 25)
    G2L["48"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["48"]["Text"] = [[]]
    G2L["48"]["Name"] = [[Submenu]]

    G2L["49"] = Instance.new("Frame", G2L["48"])
    G2L["49"]["BorderSizePixel"] = 0
    G2L["49"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["49"]["Size"] = UDim2.new(0, 20, 1, 0)
    G2L["49"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["49"]["Name"] = [[BOX]]
    G2L["49"]["BackgroundTransparency"] = 1

    G2L["4a"] = Instance.new("UIListLayout", G2L["48"])
    G2L["4a"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["4a"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["4a"]["FillDirection"] = Enum.FillDirection.Horizontal

    G2L["4b"] = Instance.new("UIGradient", G2L["48"])
    G2L["4b"]["Enabled"] = false
    G2L["4b"]["Rotation"] = 90
    G2L["4b"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(127, 168, 205))}

    G2L["4c"] = Instance.new("Frame", G2L["48"])
    G2L["4c"]["BorderSizePixel"] = 0
    G2L["4c"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["4c"]["Size"] = UDim2.new(1, -45, 1, 0)
    G2L["4c"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["4c"]["Name"] = [[Content]]
    G2L["4c"]["LayoutOrder"] = 1
    G2L["4c"]["BackgroundTransparency"] = 1

    G2L["4d"] = Instance.new("TextLabel", G2L["4c"])
    G2L["4d"]["BorderSizePixel"] = 0
    G2L["4d"]["TextSize"] = 14
    G2L["4d"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["4d"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["4d"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["4d"]["BackgroundTransparency"] = 1
    G2L["4d"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["4d"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["4d"]["AutomaticSize"] = Enum.AutomaticSize.X

    G2L["4e"] = Instance.new("Frame", G2L["48"])
    G2L["4e"]["BorderSizePixel"] = 0
    G2L["4e"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["4e"]["Size"] = UDim2.new(0, 25, 1, 0)
    G2L["4e"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["4e"]["Name"] = [[Right]]
    G2L["4e"]["LayoutOrder"] = 2
    G2L["4e"]["BackgroundTransparency"] = 1

    G2L["4f"] = Instance.new("ImageLabel", G2L["4e"])
    G2L["4f"]["BorderSizePixel"] = 0
    G2L["4f"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["4f"]["AnchorPoint"] = Vector2.new(0.5, 0.5)
    G2L["4f"]["Size"] = UDim2.new(1, -10, 1, -10)
    G2L["4f"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["4f"]["BackgroundTransparency"] = 1
    G2L["4f"]["Position"] = UDim2.new(0.5, 0, 0.5, 0)

    local function AddPixelLine(parent, xOffset, yMinus, color)
        local f = Instance.new("Frame", parent)
        f.BorderSizePixel = 0
        f.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
        f.AnchorPoint = Vector2.new(0, 0.5)
        f.Size = UDim2.new(0, 1, 1, -yMinus)
        f.Position = UDim2.new(0, xOffset, 0.5, 0)
        f.BorderColor3 = Color3.fromRGB(0, 0, 0)
        return f
    end

    AddPixelLine(G2L["4f"], 0, 0)
    AddPixelLine(G2L["4f"], 1, 2)
    AddPixelLine(G2L["4f"], 2, 4)
    AddPixelLine(G2L["4f"], 3, 6)
    AddPixelLine(G2L["4f"], 4, 8)
    AddPixelLine(G2L["4f"], 5, 10)
    AddPixelLine(G2L["4f"], 6, 12)
    AddPixelLine(G2L["4f"], 7, 14)

    -- Template: Submenu_HoldEffect
    G2L["58"] = Instance.new("TextButton", G2L["30"])
    G2L["58"]["BorderSizePixel"] = 0
    G2L["58"]["TextSize"] = 14
    G2L["58"]["AutoButtonColor"] = false
    G2L["58"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["58"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["58"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["58"]["Size"] = UDim2.new(1, 0, 0, 25)
    G2L["58"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["58"]["Text"] = [[]]
    G2L["58"]["Name"] = [[Submenu_HoldEffect]]

    G2L["59"] = Instance.new("Frame", G2L["58"])
    G2L["59"]["BorderSizePixel"] = 0
    G2L["59"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["59"]["Size"] = UDim2.new(0, 20, 1, 0)
    G2L["59"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["59"]["Name"] = [[BOX]]
    G2L["59"]["BackgroundTransparency"] = 1

    G2L["5a"] = Instance.new("UIListLayout", G2L["58"])
    G2L["5a"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["5a"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["5a"]["FillDirection"] = Enum.FillDirection.Horizontal

    G2L["5b"] = Instance.new("UIGradient", G2L["58"])
    G2L["5b"]["Rotation"] = 90
    G2L["5b"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(127, 168, 205))}

    G2L["5c"] = Instance.new("Frame", G2L["58"])
    G2L["5c"]["BorderSizePixel"] = 0
    G2L["5c"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["5c"]["Size"] = UDim2.new(1, -45, 1, 0)
    G2L["5c"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["5c"]["Name"] = [[Content]]
    G2L["5c"]["LayoutOrder"] = 1
    G2L["5c"]["BackgroundTransparency"] = 1

    G2L["5d"] = Instance.new("TextLabel", G2L["5c"])
    G2L["5d"]["BorderSizePixel"] = 0
    G2L["5d"]["TextSize"] = 14
    G2L["5d"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["5d"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["5d"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["5d"]["BackgroundTransparency"] = 1
    G2L["5d"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["5d"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["5d"]["AutomaticSize"] = Enum.AutomaticSize.X

    G2L["5e"] = Instance.new("Frame", G2L["58"])
    G2L["5e"]["BorderSizePixel"] = 0
    G2L["5e"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["5e"]["Size"] = UDim2.new(0, 25, 1, 0)
    G2L["5e"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["5e"]["Name"] = [[Right]]
    G2L["5e"]["LayoutOrder"] = 2
    G2L["5e"]["BackgroundTransparency"] = 1

    G2L["5f"] = Instance.new("ImageLabel", G2L["5e"])
    G2L["5f"]["BorderSizePixel"] = 0
    G2L["5f"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["5f"]["AnchorPoint"] = Vector2.new(0.5, 0.5)
    G2L["5f"]["Size"] = UDim2.new(1, -10, 1, -10)
    G2L["5f"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["5f"]["BackgroundTransparency"] = 1
    G2L["5f"]["Position"] = UDim2.new(0.5, 0, 0.5, 0)

    for i = 0, 7 do
        AddPixelLine(G2L["5f"], i, i * 2, Color3.fromRGB(0, 0, 0))
    end

    -- Template: Separator
    G2L["68"] = Instance.new("Frame", G2L["30"])
    G2L["68"]["BorderSizePixel"] = 0
    G2L["68"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["68"]["Size"] = UDim2.new(1, 0, 0, 5)
    G2L["68"]["BorderColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["68"]["Name"] = [[Separator]]
    G2L["68"]["BackgroundTransparency"] = 1

    G2L["69"] = Instance.new("Frame", G2L["68"])
    G2L["69"]["BorderSizePixel"] = 0
    G2L["69"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["69"]["AnchorPoint"] = Vector2.new(0, 0.5)
    G2L["69"]["Size"] = UDim2.new(1, 0, 0, 2)
    G2L["69"]["Position"] = UDim2.new(0, 0, 0.5, 0)
    G2L["69"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)

    G2L["6a"] = Instance.new("Frame", G2L["69"])
    G2L["6a"]["BorderSizePixel"] = 0
    G2L["6a"]["BackgroundColor3"] = Color3.fromRGB(133, 133, 133)
    G2L["6a"]["AnchorPoint"] = Vector2.new(0, 1)
    G2L["6a"]["Size"] = UDim2.new(1, 0, 0.5, 0)
    G2L["6a"]["Position"] = UDim2.new(0, 0, 1, 0)
    G2L["6a"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)

    -- Template: Tick_Select_HoldEffect
    G2L["6b"] = Instance.new("TextButton", G2L["30"])
    G2L["6b"]["BorderSizePixel"] = 0
    G2L["6b"]["TextSize"] = 14
    G2L["6b"]["AutoButtonColor"] = false
    G2L["6b"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["6b"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["6b"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["6b"]["Size"] = UDim2.new(1, 0, 0, 25)
    G2L["6b"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["6b"]["Text"] = [[]]
    G2L["6b"]["Name"] = [[Tick_Select_HoldEffect]]

    G2L["6c"] = Instance.new("Frame", G2L["6b"])
    G2L["6c"]["BorderSizePixel"] = 0
    G2L["6c"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["6c"]["Size"] = UDim2.new(0, 20, 1, 0)
    G2L["6c"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["6c"]["Name"] = [[BOX]]
    G2L["6c"]["BackgroundTransparency"] = 1

    G2L["6d"] = Instance.new("Frame", G2L["6c"])
    G2L["6d"]["BorderSizePixel"] = 0
    G2L["6d"]["BackgroundColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["6d"]["AnchorPoint"] = Vector2.new(0.5, 0.5)
    G2L["6d"]["Size"] = UDim2.new(1, -5, 1, -5)
    G2L["6d"]["Position"] = UDim2.new(0.5, 0, 0.5, 0)
    G2L["6d"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["6d"]["Name"] = [[Tick]]

    G2L["6e"] = Instance.new("UICorner", G2L["6d"])
    G2L["6e"]["CornerRadius"] = UDim.new(1, 0)

    G2L["6f"] = Instance.new("UIListLayout", G2L["6b"])
    G2L["6f"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["6f"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["6f"]["FillDirection"] = Enum.FillDirection.Horizontal

    G2L["70"] = Instance.new("UIGradient", G2L["6b"])
    G2L["70"]["Rotation"] = 90
    G2L["70"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(127, 168, 205))}

    G2L["71"] = Instance.new("Frame", G2L["6b"])
    G2L["71"]["BorderSizePixel"] = 0
    G2L["71"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["71"]["Size"] = UDim2.new(1, -45, 1, 0)
    G2L["71"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["71"]["Name"] = [[Content]]
    G2L["71"]["LayoutOrder"] = 1
    G2L["71"]["BackgroundTransparency"] = 1

    G2L["72"] = Instance.new("TextLabel", G2L["71"])
    G2L["72"]["BorderSizePixel"] = 0
    G2L["72"]["TextSize"] = 14
    G2L["72"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["72"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["72"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["72"]["BackgroundTransparency"] = 1
    G2L["72"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["72"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["72"]["AutomaticSize"] = Enum.AutomaticSize.X

    G2L["73"] = Instance.new("Frame", G2L["6b"])
    G2L["73"]["BorderSizePixel"] = 0
    G2L["73"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["73"]["Size"] = UDim2.new(0, 25, 1, 0)
    G2L["73"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["73"]["Name"] = [[Right]]
    G2L["73"]["LayoutOrder"] = 2
    G2L["73"]["BackgroundTransparency"] = 1

    -- Template: Button_Disable
    G2L["74"] = Instance.new("TextButton", G2L["30"])
    G2L["74"]["BorderSizePixel"] = 0
    G2L["74"]["TextSize"] = 14
    G2L["74"]["AutoButtonColor"] = false
    G2L["74"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["74"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["74"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["74"]["BackgroundTransparency"] = 1
    G2L["74"]["Size"] = UDim2.new(1, 0, 0, 25)
    G2L["74"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["74"]["Text"] = [[]]
    G2L["74"]["Name"] = [[Button_Disable]]

    G2L["75"] = Instance.new("Frame", G2L["74"])
    G2L["75"]["BorderSizePixel"] = 0
    G2L["75"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["75"]["Size"] = UDim2.new(0, 20, 1, 0)
    G2L["75"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["75"]["Name"] = [[BOX]]
    G2L["75"]["BackgroundTransparency"] = 1

    G2L["76"] = Instance.new("UIListLayout", G2L["74"])
    G2L["76"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["76"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["76"]["FillDirection"] = Enum.FillDirection.Horizontal

    G2L["77"] = Instance.new("UIGradient", G2L["74"])
    G2L["77"]["Enabled"] = false
    G2L["77"]["Rotation"] = 90
    G2L["77"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(127, 168, 205))}

    G2L["78"] = Instance.new("Frame", G2L["74"])
    G2L["78"]["BorderSizePixel"] = 0
    G2L["78"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["78"]["Size"] = UDim2.new(1, -45, 1, 0)
    G2L["78"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["78"]["Name"] = [[Content]]
    G2L["78"]["LayoutOrder"] = 1
    G2L["78"]["BackgroundTransparency"] = 1

    G2L["79"] = Instance.new("TextLabel", G2L["78"])
    G2L["79"]["BorderSizePixel"] = 0
    G2L["79"]["TextSize"] = 14
    G2L["79"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["79"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["79"]["TextColor3"] = Color3.fromRGB(168, 168, 168)
    G2L["79"]["BackgroundTransparency"] = 1
    G2L["79"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["79"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["79"]["AutomaticSize"] = Enum.AutomaticSize.X

    G2L["7a"] = Instance.new("Frame", G2L["74"])
    G2L["7a"]["BorderSizePixel"] = 0
    G2L["7a"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["7a"]["Size"] = UDim2.new(0, 25, 1, 0)
    G2L["7a"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["7a"]["Name"] = [[Right]]
    G2L["7a"]["LayoutOrder"] = 2
    G2L["7a"]["BackgroundTransparency"] = 1

    -- Template: Submenu_Disable
    G2L["7b"] = Instance.new("TextButton", G2L["30"])
    G2L["7b"]["BorderSizePixel"] = 0
    G2L["7b"]["TextSize"] = 14
    G2L["7b"]["AutoButtonColor"] = false
    G2L["7b"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["7b"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["7b"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["7b"]["BackgroundTransparency"] = 1
    G2L["7b"]["Size"] = UDim2.new(1, 0, 0, 25)
    G2L["7b"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["7b"]["Text"] = [[]]
    G2L["7b"]["Name"] = [[Submenu_Disable]]

    G2L["7c"] = Instance.new("Frame", G2L["7b"])
    G2L["7c"]["BorderSizePixel"] = 0
    G2L["7c"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["7c"]["Size"] = UDim2.new(0, 20, 1, 0)
    G2L["7c"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["7c"]["Name"] = [[BOX]]
    G2L["7c"]["BackgroundTransparency"] = 1

    G2L["7d"] = Instance.new("UIListLayout", G2L["7b"])
    G2L["7d"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["7d"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["7d"]["FillDirection"] = Enum.FillDirection.Horizontal

    G2L["7e"] = Instance.new("UIGradient", G2L["7b"])
    G2L["7e"]["Enabled"] = false
    G2L["7e"]["Rotation"] = 90
    G2L["7e"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(127, 168, 205))}

    G2L["7f"] = Instance.new("Frame", G2L["7b"])
    G2L["7f"]["BorderSizePixel"] = 0
    G2L["7f"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["7f"]["Size"] = UDim2.new(1, -45, 1, 0)
    G2L["7f"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["7f"]["Name"] = [[Content]]
    G2L["7f"]["LayoutOrder"] = 1
    G2L["7f"]["BackgroundTransparency"] = 1

    G2L["80"] = Instance.new("TextLabel", G2L["7f"])
    G2L["80"]["BorderSizePixel"] = 0
    G2L["80"]["TextSize"] = 14
    G2L["80"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["80"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["80"]["TextColor3"] = Color3.fromRGB(168, 168, 168)
    G2L["80"]["BackgroundTransparency"] = 1
    G2L["80"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["80"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["80"]["AutomaticSize"] = Enum.AutomaticSize.X

    G2L["81"] = Instance.new("Frame", G2L["7b"])
    G2L["81"]["BorderSizePixel"] = 0
    G2L["81"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["81"]["Size"] = UDim2.new(0, 25, 1, 0)
    G2L["81"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["81"]["Name"] = [[Right]]
    G2L["81"]["LayoutOrder"] = 2
    G2L["81"]["BackgroundTransparency"] = 1

    G2L["82"] = Instance.new("ImageLabel", G2L["81"])
    G2L["82"]["BorderSizePixel"] = 0
    G2L["82"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["82"]["AnchorPoint"] = Vector2.new(0.5, 0.5)
    G2L["82"]["Size"] = UDim2.new(1, -10, 1, -10)
    G2L["82"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["82"]["BackgroundTransparency"] = 1
    G2L["82"]["Position"] = UDim2.new(0.5, 0, 0.5, 0)

    for i = 0, 7 do
        AddPixelLine(G2L["82"], i, i * 2, Color3.fromRGB(168, 168, 168))
    end

    G2L["8b"] = Instance.new("UIStroke", G2L["30"])
    G2L["8c"] = Instance.new("UIGradient", G2L["30"])
    G2L["8c"]["Rotation"] = 90
    G2L["8c"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(37, 37, 37)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(67, 67, 67))}

    G2L["8d"] = Instance.new("UIListLayout", G2L["30"])
    G2L["8d"]["Padding"] = UDim.new(0, 1)
    G2L["8d"]["SortOrder"] = Enum.SortOrder.LayoutOrder

    -- StarterGui.SystemUI._Toolbar (KHÔI PHỤC ĐẦY ĐỦ)
    G2L["8e"] = Instance.new("Frame", G2L["1"])
    G2L["8e"]["Visible"] = false
    G2L["8e"]["BorderSizePixel"] = 0
    G2L["8e"]["BackgroundColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["8e"]["Size"] = UDim2.new(1, 0, 0, 100)
    G2L["8e"]["Position"] = UDim2.new(0, 0, 0, 20)
    G2L["8e"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["8e"]["Name"] = [[_Toolbar]]
    G2L["8e"]["BackgroundTransparency"] = 0.2

    G2L["8f"] = Instance.new("TextButton", G2L["8e"])
    G2L["8f"]["BorderSizePixel"] = 0
    G2L["8f"]["TextSize"] = 10
    G2L["8f"]["AutoButtonColor"] = false
    G2L["8f"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["8f"]["BackgroundColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["8f"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["8f"]["Size"] = UDim2.new(1, 0, 0, 10)
    G2L["8f"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["8f"]["Text"] = [[Hide]]
    G2L["8f"]["Name"] = [[Hide]]
    G2L["8f"]["Position"] = UDim2.new(0, 0, 1, 0)

    G2L["90"] = Instance.new("Frame", G2L["8e"])
    G2L["90"]["BorderSizePixel"] = 0
    G2L["90"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["90"]["Size"] = UDim2.new(1, 0, 1, 0)
    G2L["90"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["90"]["Name"] = [[Container]]

    -- StarterGui.SystemUI.Taskbar
    G2L["91"] = Instance.new("ImageButton", G2L["1"])
    G2L["91"]["BorderSizePixel"] = 0
    G2L["91"]["AutoButtonColor"] = false
    G2L["91"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["91"]["AnchorPoint"] = Vector2.new(0, 1)
    G2L["91"]["Size"] = UDim2.new(1, 0, 0, 40)
    G2L["91"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["91"]["Name"] = [[Taskbar]]
    G2L["91"]["Position"] = UDim2.new(0, 0, 1, 0)
    G2L["91"]["ZIndex"] = 50000

    G2L["92"] = Instance.new("UIGradient", G2L["91"])
    G2L["92"]["Rotation"] = 90
    G2L["92"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(85, 85, 85)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(0, 0, 0))}

    G2L["93"] = Instance.new("UIPadding", G2L["91"])
    G2L["93"]["PaddingRight"] = UDim.new(0, 10)
    G2L["93"]["PaddingLeft"] = UDim.new(0, 10)

    G2L["94"] = Instance.new("UIListLayout", G2L["91"])
    G2L["94"]["Padding"] = UDim.new(0, 10)
    G2L["94"]["VerticalAlignment"] = Enum.VerticalAlignment.Center
    G2L["94"]["SortOrder"] = Enum.SortOrder.LayoutOrder
    G2L["94"]["FillDirection"] = Enum.FillDirection.Horizontal

    -- App1 Inactive
    G2L["95"] = Instance.new("ImageButton", G2L["91"])
    G2L["95"]["BorderSizePixel"] = 0
    G2L["95"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["95"]["AutomaticSize"] = Enum.AutomaticSize.X
    G2L["95"]["Size"] = UDim2.new(0, 50, 1, -8)
    G2L["95"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["95"]["Name"] = [[App1]]

    G2L["97"] = Instance.new("TextLabel", G2L["95"])
    G2L["97"]["BorderSizePixel"] = 0
    G2L["97"]["TextSize"] = 14
    G2L["97"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["97"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["97"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["97"]["BackgroundTransparency"] = 1
    G2L["97"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["97"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["97"]["AutomaticSize"] = Enum.AutomaticSize.X
    G2L["97"]["Name"] = [[TItle]]

    G2L["98"] = Instance.new("UIGradient", G2L["95"])
    G2L["98"]["Rotation"] = 90
    G2L["98"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(85, 85, 85)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(0, 0, 0))}

    G2L["99"] = Instance.new("UIPadding", G2L["95"])
    G2L["99"]["PaddingRight"] = UDim.new(0, 10)
    G2L["99"]["PaddingLeft"] = UDim.new(0, 10)

    -- App1_On Active
    G2L["9b"] = Instance.new("ImageButton", G2L["91"])
    G2L["9b"]["BorderSizePixel"] = 0
    G2L["9b"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["9b"]["AutomaticSize"] = Enum.AutomaticSize.X
    G2L["9b"]["Size"] = UDim2.new(0, 50, 1, -8)
    G2L["9b"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["9b"]["Name"] = [[App1_On]]

    G2L["9c"] = Instance.new("UIPadding", G2L["9b"])
    G2L["9c"]["PaddingRight"] = UDim.new(0, 10)
    G2L["9c"]["PaddingLeft"] = UDim.new(0, 10)

    G2L["9f"] = Instance.new("UIGradient", G2L["9b"])
    G2L["9f"]["Rotation"] = 90
    G2L["9f"]["Color"] = ColorSequence.new{ColorSequenceKeypoint.new(0.000, Color3.fromRGB(158, 209, 255)),ColorSequenceKeypoint.new(0.497, Color3.fromRGB(142, 188, 230)),ColorSequenceKeypoint.new(1.000, Color3.fromRGB(116, 155, 187))}

    G2L["a0"] = Instance.new("TextLabel", G2L["9b"])
    G2L["a0"]["BorderSizePixel"] = 0
    G2L["a0"]["TextSize"] = 14
    G2L["a0"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["a0"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["a0"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["a0"]["BackgroundTransparency"] = 1
    G2L["a0"]["Size"] = UDim2.new(0, 0, 1, 0)
    G2L["a0"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["a0"]["AutomaticSize"] = Enum.AutomaticSize.X
    G2L["a0"]["Name"] = [[TItle]]

    -- StarterGui.SystemUI.NonUser
    G2L["a1"] = Instance.new("Frame", G2L["1"])
    G2L["a1"]["BorderSizePixel"] = 0
    G2L["a1"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["a1"]["ClipsDescendants"] = false
    G2L["a1"]["Size"] = UDim2.new(1, 0, 1, 0)
    G2L["a1"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["a1"]["Name"] = [[NonUser]]
    G2L["a1"]["BackgroundTransparency"] = 1
    G2L["a1"]["ZIndex"] = 999999

    -- StarterGui.SystemUI.LoginFrame (KHÔI PHỤC ĐẦY ĐỦ)
    G2L["a2"] = Instance.new("ImageButton", G2L["1"])
    G2L["a2"]["BorderSizePixel"] = 0
    G2L["a2"]["AutoButtonColor"] = false
    G2L["a2"]["Visible"] = false
    G2L["a2"]["BackgroundColor3"] = Color3.fromRGB(34, 34, 34)
    G2L["a2"]["ZIndex"] = 999999999
    G2L["a2"]["Size"] = UDim2.new(1, 0, 1, 0)
    G2L["a2"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["a2"]["Name"] = [[LoginFrame]]

    G2L["a3"] = Instance.new("Frame", G2L["a2"])
    G2L["a3"]["BorderSizePixel"] = 0
    G2L["a3"]["BackgroundColor3"] = Color3.fromRGB(67, 67, 67)
    G2L["a3"]["AnchorPoint"] = Vector2.new(0.5, 0.5)
    G2L["a3"]["AutomaticSize"] = Enum.AutomaticSize.Y
    G2L["a3"]["Size"] = UDim2.new(0, 400, 0, 50)
    G2L["a3"]["Position"] = UDim2.new(0.5, 0, 0.5, 0)
    G2L["a3"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["a3"]["Name"] = [[mainLogin]]

    G2L["a4"] = Instance.new("UIStroke", G2L["a3"])

    G2L["a5"] = Instance.new("TextBox", G2L["a3"])
    G2L["a5"]["CursorPosition"] = -1
    G2L["a5"]["Name"] = [[CustomName]]
    G2L["a5"]["BorderSizePixel"] = 0
    G2L["a5"]["TextSize"] = 14
    G2L["a5"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["a5"]["BackgroundColor3"] = Color3.fromRGB(85, 85, 85)
    G2L["a5"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["a5"]["AnchorPoint"] = Vector2.new(0.5, 0)
    G2L["a5"]["Size"] = UDim2.new(1, -20, 0, 25)
    G2L["a5"]["Position"] = UDim2.new(0.5, 0, 0.17778, 0)
    G2L["a5"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["a5"]["Text"] = [[]]
    G2L["a5"]["LayoutOrder"] = 1

    G2L["a6"] = Instance.new("UIStroke", G2L["a5"])
    G2L["a6"]["Enabled"] = false
    G2L["a6"]["Thickness"] = 1.6
    G2L["a6"]["Color"] = Color3.fromRGB(29, 131, 255)
    G2L["a6"]["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Border
    G2L["a6"]["LineJoinMode"] = Enum.LineJoinMode.Miter
    G2L["a6"]["Name"] = [[InputEffect]]

    G2L["a7"] = Instance.new("UIStroke", G2L["a5"])
    G2L["a7"]["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Border

    G2L["a8"] = Instance.new("UIPadding", G2L["a3"])
    G2L["a8"]["PaddingTop"] = UDim.new(0, 10)
    G2L["a8"]["PaddingBottom"] = UDim.new(0, 10)

    G2L["a9"] = Instance.new("UIListLayout", G2L["a3"])
    G2L["a9"]["HorizontalAlignment"] = Enum.HorizontalAlignment.Center
    G2L["a9"]["Padding"] = UDim.new(0, 10)
    G2L["a9"]["SortOrder"] = Enum.SortOrder.LayoutOrder

    G2L["aa"] = Instance.new("TextLabel", G2L["a3"])
    G2L["aa"]["TextWrapped"] = true
    G2L["aa"]["BorderSizePixel"] = 0
    G2L["aa"]["TextSize"] = 14
    G2L["aa"]["TextScaled"] = true
    G2L["aa"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["aa"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["aa"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["aa"]["BackgroundTransparency"] = 1
    G2L["aa"]["Size"] = UDim2.new(0, 200, 0, 20)
    G2L["aa"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["aa"]["Text"] = [[Text]]
    G2L["aa"]["Name"] = [[1]]

    G2L["ab"] = Instance.new("TextLabel", G2L["a3"])
    G2L["ab"]["TextWrapped"] = true
    G2L["ab"]["BorderSizePixel"] = 0
    G2L["ab"]["TextSize"] = 14
    G2L["ab"]["TextScaled"] = true
    G2L["ab"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["ab"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["ab"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["ab"]["BackgroundTransparency"] = 1
    G2L["ab"]["Size"] = UDim2.new(0, 200, 0, 20)
    G2L["ab"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["ab"]["Text"] = [[Text]]
    G2L["ab"]["LayoutOrder"] = 2
    G2L["ab"]["Name"] = [[2]]

    G2L["ac"] = Instance.new("TextBox", G2L["a3"])
    G2L["ac"]["CursorPosition"] = -1
    G2L["ac"]["Name"] = [[CustomPass]]
    G2L["ac"]["BorderSizePixel"] = 0
    G2L["ac"]["TextSize"] = 14
    G2L["ac"]["TextColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["ac"]["BackgroundColor3"] = Color3.fromRGB(85, 85, 85)
    G2L["ac"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    G2L["ac"]["AnchorPoint"] = Vector2.new(0.5, 0)
    G2L["ac"]["Size"] = UDim2.new(1, -20, 0, 25)
    G2L["ac"]["Position"] = UDim2.new(0.5, 0, 0, 0)
    G2L["ac"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["ac"]["Text"] = [[]]
    G2L["ac"]["LayoutOrder"] = 3

    G2L["ad"] = Instance.new("UIStroke", G2L["ac"])
    G2L["ad"]["Enabled"] = false
    G2L["ad"]["Thickness"] = 1.6
    G2L["ad"]["Color"] = Color3.fromRGB(29, 131, 255)
    G2L["ad"]["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Border
    G2L["ad"]["LineJoinMode"] = Enum.LineJoinMode.Miter
    G2L["ad"]["Name"] = [[InputEffect]]

    G2L["ae"] = Instance.new("UIStroke", G2L["ac"])
    G2L["ae"]["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Border

    G2L["af"] = Instance.new("TextButton", G2L["a3"])
    G2L["af"]["BorderSizePixel"] = 0
    G2L["af"]["TextSize"] = 14
    G2L["af"]["AutoButtonColor"] = false
    G2L["af"]["TextColor3"] = Color3.fromRGB(255, 255, 255)
    G2L["af"]["BackgroundColor3"] = Color3.fromRGB(86, 171, 255)
    G2L["af"]["FontFace"] = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    G2L["af"]["Size"] = UDim2.new(0, 200, 0, 30)
    G2L["af"]["LayoutOrder"] = 4
    G2L["af"]["BorderColor3"] = Color3.fromRGB(0, 0, 0)
    G2L["af"]["Text"] = [[Login]]

    -- StarterGui.SystemUI.UIScale
    G2L["b0"] = Instance.new("UIScale", G2L["1"])

    return G2L, SnapPreview
end

--------------------------------------------------------------------------------
-- 2. KHỞI TẠO FRAMEWORK
--------------------------------------------------------------------------------
local function CheckTopBarVisibility()
    if not SystemOS.Top then return end
    local sysCount = #SystemOS.SystemContainer:GetChildren() - 1
    local custCount = #SystemOS.CustomContainer:GetChildren() - 1
    local hasItems = (sysCount > 0 or custCount > 0)

    SystemOS.Top.Visible = hasItems
    UpdateDesktopLayout()
end

local function EnsureInitialized(callerSelf, config)
    if SystemOS.IsInitialized then
        return SystemOS
    end

    config = config or {}
    local G2L, SnapPreview = BuildOriginalStructure()

    local shouldReset = false
    if config.ResetOnSpawn ~= nil then
        shouldReset = config.ResetOnSpawn
    elseif config.ResetOnRespawn ~= nil then
        shouldReset = config.ResetOnRespawn
    end

    G2L["1"].ResetOnSpawn = shouldReset
    G2L["1"].IgnoreGuiInset = (config.IgnoreGuiInset == true)

    SystemOS.ScreenGui = G2L["1"]
    SystemOS.Top = G2L["2"]
    SystemOS.SystemContainer = G2L["4"]
    SystemOS.CustomContainer = G2L["a"]
    SystemOS.Desktop = G2L["f"]
    SystemOS.Toolbar = G2L["8e"]
    SystemOS.Taskbar = G2L["91"]
    SystemOS.NonUser = G2L["a1"]
    SystemOS.LoginFrame = G2L["a2"]
    SystemOS.UIScale = G2L["b0"]
    SystemOS.SnapPreview = SnapPreview
    SystemOS.AutoHideTaskbar = (config.AutoHideTaskbar == true)

    SystemOS.Templates = {
        SystemButton = G2L["6"]:Clone(),
        CustomButton = G2L["b"]:Clone(),
        Window = G2L["10"]:Clone(),
        ContextMenu = G2L["30"]:Clone(),
        TaskAppOff = G2L["95"]:Clone(),
        TaskAppOn = G2L["9b"]:Clone(),
    }

    G2L["6"]:Destroy()
    G2L["b"]:Destroy()
    G2L["10"]:Destroy()
    G2L["30"]:Destroy()
    G2L["95"]:Destroy()
    G2L["9b"]:Destroy()

    -- CLICK RA NGOÀI ĐÓNG CONTEXTMENU NGAY LẬP TỨC TRONG 1 LẦN NHẤP
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
            -- Nếu vừa mở menu xong trong vòng 0.05s thì bỏ qua (chính là cú click mở menu)
            if os.clock() - lastMenuOpenClock > 0.05 then
                local mousePos = UserInputService:GetMouseLocation()
                local clickedInsideMenu = false

                for _, menu in ipairs(SystemOS.ActiveContextMenus) do
                    if menu and menu.Parent then
                        local abs = menu.AbsolutePosition
                        local sz = menu.AbsoluteSize
                        if mousePos.X >= abs.X and mousePos.X <= (abs.X + sz.X)
                           and mousePos.Y >= abs.Y and mousePos.Y <= (abs.Y + sz.Y) then
                            clickedInsideMenu = true
                            break
                        end
                    end
                end

                -- Nếu bấm ra ngoài thì đóng ngay lập tức
                if not clickedInsideMenu then
                    SystemOS:CloseAllContextMenus()
                end
            end

            -- Xử lý Unfocus Window
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if SystemOS.PreventUnfocus then
                    SystemOS.PreventUnfocus = false
                    return
                end

                local mousePos = GetExactMousePosition()

                if SystemOS.ModalWindow and SystemOS.ModalWindow.Window and SystemOS.ModalWindow.Window.Visible then
                    local absPos = SystemOS.ModalWindow.Window.AbsolutePosition - SystemOS.NonUser.AbsolutePosition
                    local absSize = SystemOS.ModalWindow.Window.AbsoluteSize
                    local inModal = (mousePos.X >= absPos.X and mousePos.X <= (absPos.X + absSize.X)
                                    and mousePos.Y >= absPos.Y and mousePos.Y <= (absPos.Y + absSize.Y))
                    if not inModal then
                        SystemOS.ModalWindow:Flash()
                        return
                    end
                end

                local clickedInsideWindow = false
                for _, winObj in ipairs(SystemOS.Windows) do
                    if winObj.Window and winObj.Window.Visible then
                        local absPos = winObj.Window.AbsolutePosition - SystemOS.NonUser.AbsolutePosition
                        local absSize = winObj.Window.AbsoluteSize
                        if mousePos.X >= absPos.X and mousePos.X <= (absPos.X + absSize.X)
                           and mousePos.Y >= absPos.Y and mousePos.Y <= (absPos.Y + absSize.Y) then
                            clickedInsideWindow = true
                            break
                        end
                    end
                end

                local clickedTaskbar = false
                if SystemOS.Taskbar and SystemOS.Taskbar.Visible then
                    local tPos = SystemOS.Taskbar.AbsolutePosition - SystemOS.NonUser.AbsolutePosition
                    local tSize = SystemOS.Taskbar.AbsoluteSize
                    if mousePos.X >= tPos.X and mousePos.X <= (tPos.X + tSize.X)
                       and mousePos.Y >= tPos.Y and mousePos.Y <= (tPos.Y + tSize.Y) then
                        clickedTaskbar = true
                    end
                end

                local clickedTop = false
                if SystemOS.Top and SystemOS.Top.Visible then
                    local topPos = SystemOS.Top.AbsolutePosition - SystemOS.NonUser.AbsolutePosition
                    local topSize = SystemOS.Top.AbsoluteSize
                    if mousePos.X >= topPos.X and mousePos.X <= (topPos.X + topSize.X)
                       and mousePos.Y >= topPos.Y and mousePos.Y <= (topPos.Y + topSize.Y) then
                        clickedTop = true
                    end
                end

                if not clickedInsideWindow and not clickedTaskbar and not clickedTop then
                    SystemOS:UnfocusAllWindows()
                end
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not SystemOS.IsInitialized or not SystemOS.AutoHideTaskbar then return end

        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local mouseLoc = UserInputService:GetMouseLocation()

        local inBottomZone = (mouseLoc.Y >= (viewport.Y - 14))
        local tbPos = SystemOS.Taskbar.AbsolutePosition
        local tbSize = SystemOS.Taskbar.AbsoluteSize
        local inTaskbar = (mouseLoc.X >= tbPos.X and mouseLoc.X <= (tbPos.X + tbSize.X)
                           and mouseLoc.Y >= tbPos.Y and mouseLoc.Y <= (tbPos.Y + tbSize.Y))

        local hasActiveMenu = (#SystemOS.ActiveContextMenus > 0)

        if inBottomZone or inTaskbar or hasActiveMenu then
            ShowTaskbarAnim()
            mouseLeaveTaskbarTime = tick()
        else
            if taskbarShowing and (tick() - mouseLeaveTaskbarTime >= 3) then
                HideTaskbarAnim()
            end
        end
    end)

    local targetParent = GetAutoTargetParent()
    SystemOS.ScreenGui.Parent = targetParent
    SystemOS.IsInitialized = true

    CheckTopBarVisibility()
    if SystemOS.AutoHideTaskbar then
        HideTaskbarAnim()
    end
    UpdateDesktopLayout()

    if callerSelf and type(callerSelf) == "table" and callerSelf ~= SystemOS then
        for k, v in pairs(SystemOS) do
            callerSelf[k] = v
        end
    end

    return SystemOS
end

function SystemOS.Init(callerSelfOrConfig, optionalConfig)
    local cfg
    local target
    if type(callerSelfOrConfig) == "table" and callerSelfOrConfig.AddSystemMenu then
        target = callerSelfOrConfig
        cfg = optionalConfig or {}
    else
        target = SystemOS
        cfg = callerSelfOrConfig or {}
    end
    return EnsureInitialized(target, cfg)
end

function SystemOS:SetIgnoreGuiInset(enabled)
    EnsureInitialized(self)
    SystemOS.ScreenGui.IgnoreGuiInset = (enabled == true)
end

function SystemOS:SetAutoHideTaskbar(enabled)
    EnsureInitialized(self)
    SystemOS.AutoHideTaskbar = (enabled == true)
    if SystemOS.AutoHideTaskbar then
        mouseLeaveTaskbarTime = tick() - 1
        UpdateDesktopLayout()
    else
        ShowTaskbarAnim()
        UpdateDesktopLayout()
    end
end

--------------------------------------------------------------------------------
-- 3. HỆ THỐNG FOCUS / UNFOCUS WINDOWS
--------------------------------------------------------------------------------
local function UpdateNavButtonVisuals(winObj, isCurrent)
    if not winObj.ButtonStates._CLOSE then
        winObj.CloseBtn.BackgroundColor3 = COLOR_NAV_DISABLED
    else
        winObj.CloseBtn.BackgroundColor3 = isCurrent and COLOR_CLOSE_ACTIVE or COLOR_NAV_INACTIVE
    end

    if not winObj.ButtonStates._MAXIMIZE then
        winObj.MaxBtn.BackgroundColor3 = COLOR_NAV_DISABLED
    else
        winObj.MaxBtn.BackgroundColor3 = isCurrent and COLOR_MAX_ACTIVE or COLOR_NAV_INACTIVE
    end

    if not winObj.ButtonStates._MINIMIZE then
        winObj.MinBtn.BackgroundColor3 = COLOR_NAV_DISABLED
    else
        winObj.MinBtn.BackgroundColor3 = isCurrent and COLOR_MIN_ACTIVE or COLOR_NAV_INACTIVE
    end

    winObj.TitleLabel.TextColor3 = isCurrent and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
    winObj.TitleLabel.TextTransparency = isCurrent and 0 or 0.35
    winObj.TaskbarGrad.Color = isCurrent and SystemOS.Templates.TaskAppOn.UIGradient.Color or SystemOS.Templates.TaskAppOff.UIGradient.Color
end

function SystemOS:FocusWindow(targetWin)
    EnsureInitialized(self)
    if not targetWin or not targetWin.Window or not targetWin.Window.Parent then return end

    if SystemOS.ModalWindow and SystemOS.ModalWindow ~= targetWin and SystemOS.ModalWindow.Window.Visible then
        SystemOS.ModalWindow:Flash()
        return
    end

    if not targetWin.IsAlwaysOnTop then
        SystemOS.ZCounter = SystemOS.ZCounter + 2
        targetWin.Window.ZIndex = SystemOS.ZCounter
    else
        targetWin.Window.ZIndex = 40000
    end

    SystemOS.ActiveWindow = targetWin

    for _, winObj in ipairs(SystemOS.Windows) do
        if winObj.Window and winObj.Window.Parent then
            local isCurrent = (winObj == targetWin)
            UpdateNavButtonVisuals(winObj, isCurrent)

            if winObj.OverlayContainer then
                winObj.OverlayContainer.ZIndex = winObj.Window.ZIndex + 1
            end
        end
    end
end

function SystemOS:UnfocusAllWindows()
    EnsureInitialized(self)
    SystemOS.ActiveWindow = nil
    for _, winObj in ipairs(SystemOS.Windows) do
        if winObj.Window and winObj.Window.Parent then
            UpdateNavButtonVisuals(winObj, false)
        end
    end
end

--------------------------------------------------------------------------------
-- 4. SMART CONTEXTMENU (HOẠT ẢNH FADE GỐC + 1 CLICK ĐÓNG NGAY + SUBMENU THẲNG HÀNG)
--------------------------------------------------------------------------------
function SystemOS:CloseAllContextMenus()
    EnsureInitialized(self)
    for _, menu in ipairs(SystemOS.ActiveContextMenus) do
        if menu and menu.Parent then
            local tw = TweenService:Create(menu, FADE_TWEEN, { GroupTransparency = 1 })
            tw:Play()
            tw.Completed:Connect(function()
                menu:Destroy()
            end)
        end
    end
    SystemOS.ActiveContextMenus = {}
end

function SystemOS:CreateContextMenu(items, xPos, yPos, parentLayer, subOptions)
    EnsureInitialized(self)
    lastMenuOpenClock = os.clock() -- Ghi nhận thời điểm mở menu để 1 click ngoài là đóng ngay
    parentLayer = parentLayer or SystemOS.NonUser
    local screenSize = SystemOS.ScreenGui and SystemOS.ScreenGui.AbsoluteSize or Vector2.new(1920, 1080)

    local MenuFrame = SystemOS.Templates.ContextMenu:Clone()
    MenuFrame.Visible = true
    MenuFrame.AutomaticSize = Enum.AutomaticSize.None
    MenuFrame.ClipsDescendants = true
    MenuFrame.Parent = parentLayer
    MenuFrame.GroupTransparency = 1

    local t_Btn = MenuFrame:WaitForChild("Button"):Clone()
    local t_Tick = MenuFrame:WaitForChild("Tick_Select"):Clone()
    local t_Sub = MenuFrame:WaitForChild("Submenu"):Clone()
    local t_Sep = MenuFrame:WaitForChild("Separator"):Clone()
    local t_BtnDis = MenuFrame:WaitForChild("Button_Disable"):Clone()
    local t_SubDis = MenuFrame:WaitForChild("Submenu_Disable"):Clone()

    for _, child in ipairs(MenuFrame:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    local Scroll = Instance.new("ScrollingFrame", MenuFrame)
    Scroll.Name = "ScrollContent"
    Scroll.Size = UDim2.new(1, 0, 1, 0)
    Scroll.BackgroundTransparency = 1
    Scroll.BorderSizePixel = 0
    Scroll.ElasticBehavior = Enum.ElasticBehavior.Never
    Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(158, 209, 255)

    local SList = Instance.new("UIListLayout", Scroll)
    SList.Padding = UDim.new(0, 1)
    SList.SortOrder = Enum.SortOrder.LayoutOrder

    local calculatedMaxW = 120
    local totalHeight = 0
    local activeSubMenu = nil

    for _, item in ipairs(items) do
        if item.Text then
            local tSize = TextService:GetTextSize(item.Text, 14, Enum.Font.Ubuntu, Vector2.new(1000, 25))
            local itemW = tSize.X + 55
            if item.Type == "Submenu" then itemW = itemW + 15 end
            if itemW > calculatedMaxW then calculatedMaxW = itemW end
        end
    end
    local finalWidth = calculatedMaxW + 15

    for order, item in ipairs(items) do
        local rowInst
        local rowHeight = 25

        if item.Type == "Separator" then
            rowInst = t_Sep:Clone()
            rowHeight = 5
        elseif item.Disabled then
            if item.Type == "Submenu" then
                rowInst = t_SubDis:Clone()
                rowInst.Content.TextLabel.Text = item.Text or ""
            else
                rowInst = t_BtnDis:Clone()
                rowInst.Content.TextLabel.Text = item.Text or ""
            end
        elseif item.Type == "Checkbox" then
            rowInst = t_Tick:Clone()
            rowInst.Content.TextLabel.Text = item.Text or ""
            local tickBox = rowInst:FindFirstChild("BOX")
            local tickDot = tickBox and tickBox:FindFirstChild("Tick")
            
            if tickDot then
                tickDot.Visible = (item.Checked == true)
            end

            rowInst.MouseEnter:Connect(function()
                rowInst.BackgroundTransparency = 0
                local grad = rowInst:FindFirstChildOfClass("UIGradient")
                if grad then grad.Enabled = true end
                rowInst.Content.TextLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
                if tickDot then tickDot.BackgroundColor3 = Color3.fromRGB(0, 0, 0) end
            end)

            rowInst.MouseLeave:Connect(function()
                rowInst.BackgroundTransparency = 1
                local grad = rowInst:FindFirstChildOfClass("UIGradient")
                if grad then grad.Enabled = false end
                rowInst.Content.TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                if tickDot then tickDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end
            end)

            rowInst.MouseButton1Click:Connect(function()
                item.Checked = not item.Checked
                if tickDot then tickDot.Visible = (item.Checked == true) end
                SystemOS:CloseAllContextMenus()
                if item.Callback then item.Callback(item.Checked) end
            end)
        elseif item.Type == "Submenu" then
            rowInst = t_Sub:Clone()
            rowInst.Content.TextLabel.Text = item.Text or ""

            rowInst.MouseEnter:Connect(function()
                rowInst.BackgroundTransparency = 0
                local grad = rowInst:FindFirstChildOfClass("UIGradient")
                if grad then grad.Enabled = true end
                rowInst.Content.TextLabel.TextColor3 = Color3.fromRGB(0, 0, 0)

                local right = rowInst:FindFirstChild("Right")
                if right and right:FindFirstChild("ImageLabel") then
                    for _, pixel in ipairs(right.ImageLabel:GetChildren()) do
                        if pixel:IsA("Frame") then pixel.BackgroundColor3 = Color3.fromRGB(0, 0, 0) end
                    end
                end

                if activeSubMenu then
                    activeSubMenu:Destroy()
                    activeSubMenu = nil
                end

                if item.Items and #item.Items > 0 then
                    -- TÍNH TOẠ ĐỘ SUBMENU CHUẨN XÁC NỘI BỘ (KHÔNG BỊ NHẢY LÊN ĐỈNH)
                    local rowOffset = rowInst.AbsolutePosition - MenuFrame.AbsolutePosition
                    local subY = MenuFrame.Position.Y.Offset + rowOffset.Y
                    local subX = MenuFrame.Position.X.Offset + MenuFrame.AbsoluteSize.X

                    activeSubMenu = SystemOS:CreateContextMenu(item.Items, subX, subY, parentLayer, {
                        IsSubmenu = true,
                        ParentX = MenuFrame.Position.X.Offset,
                        ParentWidth = MenuFrame.AbsoluteSize.X,
                        ItemY = subY,
                        ItemHeight = rowInst.AbsoluteSize.Y
                    })
                end
            end)

            rowInst.MouseLeave:Connect(function()
                rowInst.BackgroundTransparency = 1
                local grad = rowInst:FindFirstChildOfClass("UIGradient")
                if grad then grad.Enabled = false end
                rowInst.Content.TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

                local right = rowInst:FindFirstChild("Right")
                if right and right:FindFirstChild("ImageLabel") then
                    for _, pixel in ipairs(right.ImageLabel:GetChildren()) do
                        if pixel:IsA("Frame") then pixel.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end
                    end
                end
            end)
        else
            rowInst = t_Btn:Clone()
            rowInst.Content.TextLabel.Text = item.Text or ""

            rowInst.MouseEnter:Connect(function()
                rowInst.BackgroundTransparency = 0
                local grad = rowInst:FindFirstChildOfClass("UIGradient")
                if grad then grad.Enabled = true end
                rowInst.Content.TextLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
                if activeSubMenu then
                    activeSubMenu:Destroy()
                    activeSubMenu = nil
                end
            end)

            rowInst.MouseLeave:Connect(function()
                rowInst.BackgroundTransparency = 1
                local grad = rowInst:FindFirstChildOfClass("UIGradient")
                if grad then grad.Enabled = false end
                rowInst.Content.TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end)

            rowInst.MouseButton1Click:Connect(function()
                SystemOS:CloseAllContextMenus()
                if item.Callback then item.Callback() end
            end)
        end

        rowInst.LayoutOrder = order
        rowInst.Parent = Scroll
        totalHeight = totalHeight + rowHeight + 1
    end

    totalHeight = totalHeight + 4

    local targetX = xPos
    local targetY = yPos
    local finalHeight = totalHeight
    local needScroll = false

    if subOptions and subOptions.IsSubmenu then
        local rightSideX = subOptions.ParentX + subOptions.ParentWidth
        if (rightSideX + finalWidth) <= (screenSize.X - 5) then
            targetX = rightSideX
        else
            targetX = subOptions.ParentX - finalWidth
        end

        targetY = subOptions.ItemY

        -- CHỈ DỊCH LÊN KHI THỰC SỰ CHẠM ĐÁY MÀN HÌNH
        if (targetY + finalHeight) > (screenSize.Y - 10) then
            targetY = screenSize.Y - finalHeight - 10
        end
        if targetY < 5 then targetY = 5 end
    else
        if (targetX + finalWidth) > (screenSize.X - 5) then
            targetX = targetX - finalWidth
        end

        if (targetY + finalHeight) > (screenSize.Y - 10) then
            if (yPos - finalHeight) >= 5 then
                targetY = yPos - finalHeight
            else
                targetY = screenSize.Y - finalHeight - 10
            end
        end
    end

    targetX = math.clamp(targetX, 5, math.max(5, screenSize.X - finalWidth - 5))
    targetY = math.clamp(targetY, 5, math.max(5, screenSize.Y - finalHeight - 10))

    if finalHeight > (screenSize.Y - 25) then
        finalHeight = screenSize.Y - 25
        targetY = 5
        needScroll = true
    end

    MenuFrame.Size = UDim2.new(0, finalWidth, 0, math.max(25, finalHeight))
    MenuFrame.Position = UDim2.new(0, targetX, 0, targetY)

    Scroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    Scroll.ScrollBarThickness = needScroll and 2 or 0
    Scroll.ScrollingEnabled = needScroll

    table.insert(SystemOS.ActiveContextMenus, MenuFrame)

    -- HOẠT ẢNH FADE IN GỐC CHUẨN OS
    local twIn = TweenService:Create(MenuFrame, FADE_TWEEN, { GroupTransparency = 0 })
    twIn:Play()

    return MenuFrame
end

--------------------------------------------------------------------------------
-- 5. GẮN CONTEXTMENU (CHUỘT PHẢI CHUẨN XÁC ĐẦU MŨI CHUỘT)
--------------------------------------------------------------------------------
local function SetupContextMenuTrigger(guiObject, getItemsCallback)
    local rmbStartPos = nil
    local rmbStartTime = 0
    local isRmbPressed = false

    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            isRmbPressed = true
            rmbStartPos = UserInputService:GetMouseLocation()
            rmbStartTime = tick()
        end
    end)

    guiObject.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 and isRmbPressed then
            isRmbPressed = false
            local currentPos = UserInputService:GetMouseLocation()
            local dist = (currentPos - rmbStartPos).Magnitude
            local elapsed = tick() - rmbStartTime

            if dist < 6 and elapsed < 0.35 then
                local items = getItemsCallback(guiObject)
                if items and #items > 0 then
                    SystemOS:CloseAllContextMenus()
                    local mPos = GetExactMousePosition()
                    SystemOS:CreateContextMenu(items, mPos.X, mPos.Y, SystemOS.NonUser)
                end
            end
        end
    end)

    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local touchStartPos = input.Position
            local cancelled = false

            local moveConn
            moveConn = UserInputService.InputChanged:Connect(function(changeInput)
                if changeInput == input and (Vector2.new(changeInput.Position.X, changeInput.Position.Y) - Vector2.new(touchStartPos.X, touchStartPos.Y)).Magnitude > 15 then
                    cancelled = true
                    if moveConn then moveConn:Disconnect() end
                end
            end)

            task.delay(0.5, function()
                if not cancelled and input.UserInputState ~= Enum.UserInputState.End and input.UserInputState ~= Enum.UserInputState.Cancel then
                    if moveConn then moveConn:Disconnect() end
                    local items = getItemsCallback(guiObject)
                    if items and #items > 0 then
                        SystemOS:CloseAllContextMenus()
                        local touchVec = Vector2.new(touchStartPos.X, touchStartPos.Y)
                        if not SystemOS.ScreenGui.IgnoreGuiInset then
                            touchVec = touchVec - GuiService:GetGuiInset()
                        end
                        SystemOS:CreateContextMenu(items, touchVec.X, touchVec.Y, SystemOS.NonUser)
                    end
                end
            end)

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    cancelled = true
                    if moveConn then moveConn:Disconnect() end
                end
            end)
        end
    end)
end

function SystemOS:BindContextMenu(guiObject, itemsOrBuilder)
    EnsureInitialized(self)
    if not guiObject then return end

    local builder = function(obj)
        if type(itemsOrBuilder) == "function" then
            return itemsOrBuilder(obj)
        end
        return itemsOrBuilder
    end

    SetupContextMenuTrigger(guiObject, builder)
end

function SystemOS:BindDesktopContextMenu(itemsOrBuilder)
    EnsureInitialized(self)
    self:BindContextMenu(SystemOS.Desktop, itemsOrBuilder)
end

--------------------------------------------------------------------------------
-- 6. THANH TOP
--------------------------------------------------------------------------------
function SystemOS:AddSystemMenu(logoText, menuItems)
    EnsureInitialized(self)
    local btn = SystemOS.Templates.SystemButton:Clone()
    btn.LOGO.Text = logoText or "O"
    btn.Parent = SystemOS.SystemContainer

    CheckTopBarVisibility()

    btn.MouseButton1Click:Connect(function()
        SystemOS:CloseAllContextMenus()
        local pos = btn.AbsolutePosition
        if not SystemOS.ScreenGui.IgnoreGuiInset then
            pos = pos - GuiService:GetGuiInset()
        end
        SystemOS:CreateContextMenu(menuItems, pos.X, pos.Y + btn.AbsoluteSize.Y + 2, SystemOS.NonUser)
    end)
    return btn
end

function SystemOS:AddTopMenu(name, menuItems)
    EnsureInitialized(self)
    local btn = SystemOS.Templates.CustomButton:Clone()
    btn.Name = name
    btn.LOGO.Text = name
    btn.Parent = SystemOS.CustomContainer

    CheckTopBarVisibility()

    btn.MouseButton1Click:Connect(function()
        SystemOS:CloseAllContextMenus()
        local pos = btn.AbsolutePosition
        if not SystemOS.ScreenGui.IgnoreGuiInset then
            pos = pos - GuiService:GetGuiInset()
        end
        SystemOS:CreateContextMenu(menuItems, pos.X, pos.Y + btn.AbsoluteSize.Y + 2, SystemOS.NonUser)
    end)
    return btn
end

--------------------------------------------------------------------------------
-- 7. WINDOW ENGINE
--------------------------------------------------------------------------------
function SystemOS:CreateWindow(config)
    EnsureInitialized(self)
    config = config or {}
    local title = config.Title or "BOX"
    local initSize = config.Size or UDim2.new(0, 260, 0, 220)
    local initPos = config.Position or UDim2.new(0.35, 0, 0.3, 0)
    local minSize = config.MinSize or Vector2.new(150, 100)

    local Window = SystemOS.Templates.Window:Clone()
    Window.Name = title
    Window.Size = initSize
    Window.Position = initPos
    Window.Visible = true
    Window.Parent = SystemOS.Desktop

    local TopBar = Window:WaitForChild("TopBar")
    local tbFix = TopBar:WaitForChild("Fix")
    local TitleFrame = TopBar:WaitForChild("Title")
    local titleLabel = TitleFrame.Text
    titleLabel.Text = title

    local Nav = TopBar:WaitForChild("Nav")
    local closeBtn = Nav:WaitForChild("_CLOSE")
    local maxBtn = Nav:WaitForChild("_MAXIMIZE")
    local minBtn = Nav:WaitForChild("_MINIMIZE")

    local Canvas = Window:WaitForChild("Canvas")
    Canvas.ClipsDescendants = true
    Canvas:GetPropertyChangedSignal("ClipsDescendants"):Connect(function()
        Canvas.ClipsDescendants = true
    end)

    local ResizeSystem = Window:WaitForChild("ResizeSystem")

    if config.CanvasColor then
        Canvas.BackgroundColor3 = config.CanvasColor
    end

    local TaskApp = SystemOS.Templates.TaskAppOn:Clone()
    TaskApp.Name = title
    TaskApp.TItle.Text = title
    TaskApp.Parent = SystemOS.Taskbar

    local winObj = {
        Window = Window,
        Canvas = Canvas,
        CanvasGroup = Canvas,
        Content = Canvas,
        TopBar = TopBar,
        FixFrame = tbFix,
        TitleLabel = titleLabel,
        CloseBtn = closeBtn,
        MaxBtn = maxBtn,
        MinBtn = minBtn,
        TaskApp = TaskApp,
        TaskbarGrad = TaskApp.UIGradient,
        OverlayContainer = nil,
        IsModal = (config.Modal == true),
        IsAlwaysOnTop = (config.AlwaysOnTop == true),
        ButtonStates = {
            _CLOSE = (config.AllowClose ~= false),
            _MAXIMIZE = (config.AllowMaximize ~= false),
            _MINIMIZE = (config.AllowMinimize ~= false),
        }
    }

    if winObj.IsModal then
        SystemOS.ModalWindow = winObj
    end

    table.insert(SystemOS.Windows, winObj)

    local transformBindable = Instance.new("BindableEvent")
    winObj.OnTransform = transformBindable.Event

    local function FireTransform()
        transformBindable:Fire(
            Window.AbsolutePosition,
            Window.AbsoluteSize,
            Canvas.AbsolutePosition,
            Canvas.AbsoluteSize
        )
    end

    local function RequestFocus()
        SystemOS:FocusWindow(winObj)
    end

    function winObj:SetCanvasColor(color) Canvas.BackgroundColor3 = color end

    function winObj:SetAlwaysOnTop(alwaysOnTop)
        winObj.IsAlwaysOnTop = (alwaysOnTop == true)
        if winObj.IsAlwaysOnTop then
            Window.ZIndex = 40000
        else
            RequestFocus()
        end
    end

    function winObj:SetTransparency(transparency)
        Canvas.BackgroundTransparency = transparency
        Window.BackgroundTransparency = transparency
        TopBar.BackgroundTransparency = transparency
        tbFix.BackgroundTransparency = transparency
    end

    local isFlashing = false
    function winObj:Flash(times)
        if isFlashing then return end
        isFlashing = true
        times = times or 4

        task.spawn(function()
            for i = 1, times * 2 do
                local showActive = (i % 2 == 1)
                UpdateNavButtonVisuals(winObj, showActive)
                task.wait(0.09)
            end
            UpdateNavButtonVisuals(winObj, (SystemOS.ActiveWindow == winObj))
            isFlashing = false
        end)
    end

    function winObj:SetModal(isModal)
        winObj.IsModal = (isModal == true)
        if winObj.IsModal then
            SystemOS.ModalWindow = winObj
            RequestFocus()
        elseif SystemOS.ModalWindow == winObj then
            SystemOS.ModalWindow = nil
        end
    end

    function winObj:SetButtonEnabled(btnName, enabled)
        local key = string.upper(btnName)
        if not string.find(key, "^_") then key = "_" .. key end
        if winObj.ButtonStates[key] ~= nil then
            winObj.ButtonStates[key] = (enabled == true)
            UpdateNavButtonVisuals(winObj, (SystemOS.ActiveWindow == winObj))
        end
    end

    function winObj:SetCloseEnabled(enabled) winObj:SetButtonEnabled("_CLOSE", enabled) end
    function winObj:SetMaximizeEnabled(enabled) winObj:SetButtonEnabled("_MAXIMIZE", enabled) end
    function winObj:SetMinimizeEnabled(enabled) winObj:SetButtonEnabled("_MINIMIZE", enabled) end

    Window.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
            RequestFocus()
        end
    end)
    Canvas.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
            RequestFocus()
        end
    end)

    local isMaximized = false
    local currentSnap = nil
    local prevSize = initSize
    local prevPos = initPos
    local lastTopBarClick = 0

    local function ApplyMaximize()
        if not isMaximized then
            prevSize = Window.Size
            prevPos = Window.Position
            Window.Position = UDim2.new(0, 0, 0, 0)
            Window.Size = UDim2.new(1, 0, 1, 0)
            isMaximized = true
            currentSnap = "Full"
        else
            Window.Size = prevSize
            Window.Position = prevPos
            isMaximized = false
            currentSnap = nil
        end
        FireTransform()
    end

    maxBtn.MouseButton1Click:Connect(function()
        if not winObj.ButtonStates._MAXIMIZE then return end
        RequestFocus()
        ApplyMaximize()
    end)

    local dragging = false
    local dragStart, startPos
    local activeSnapTarget = nil

    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            RequestFocus()

            local now = tick()
            if (now - lastTopBarClick) < 0.3 then
                lastTopBarClick = 0
                if winObj.ButtonStates._MAXIMIZE then
                    ApplyMaximize()
                end
                return
            end
            lastTopBarClick = now

            if isMaximized or currentSnap then
                isMaximized = false
                currentSnap = nil

                local mouseX = input.Position.X
                local newW = prevSize.X.Offset
                local newH = prevSize.Y.Offset
                local targetX = mouseX - (newW / 2)
                local targetY = input.Position.Y - 12

                Window.Size = prevSize
                Window.Position = UDim2.new(0, targetX, 0, targetY)
                FireTransform()
            end

            dragging = true
            dragStart = input.Position
            startPos = Window.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false

                    if activeSnapTarget then
                        SystemOS.SnapPreview.Visible = false
                        if activeSnapTarget == "Full" then
                            ApplyMaximize()
                        elseif activeSnapTarget == "Left" then
                            prevSize = Window.Size
                            prevPos = Window.Position
                            Window.Position = UDim2.new(0, 0, 0, 0)
                            Window.Size = UDim2.new(0.5, 0, 1, 0)
                            currentSnap = "Left"
                            isMaximized = false
                        elseif activeSnapTarget == "Right" then
                            prevSize = Window.Size
                            prevPos = Window.Position
                            Window.Position = UDim2.new(0.5, 0, 0, 0)
                            Window.Size = UDim2.new(0.5, 0, 1, 0)
                            currentSnap = "Right"
                            isMaximized = false
                        end
                        activeSnapTarget = nil
                        FireTransform()
                    end
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Window.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            FireTransform()

            local mouseLoc = GetExactMousePosition()
            local dSize = SystemOS.Desktop.AbsoluteSize
            local dPos = SystemOS.Desktop.Position

            local isTopEdge = (mouseLoc.Y <= dPos.Y.Offset + 6)
            local isLeftEdge = (mouseLoc.X <= 6)
            local isRightEdge = (mouseLoc.X >= (dSize.X - 6))

            if isTopEdge then
                activeSnapTarget = "Full"
                SystemOS.SnapPreview.Position = UDim2.new(0, 0, 0, 0)
                SystemOS.SnapPreview.Size = UDim2.new(1, 0, 1, 0)
                SystemOS.SnapPreview.Visible = true
            elseif isLeftEdge then
                activeSnapTarget = "Left"
                SystemOS.SnapPreview.Position = UDim2.new(0, 0, 0, 0)
                SystemOS.SnapPreview.Size = UDim2.new(0.5, 0, 1, 0)
                SystemOS.SnapPreview.Visible = true
            elseif isRightEdge then
                activeSnapTarget = "Right"
                SystemOS.SnapPreview.Position = UDim2.new(0.5, 0, 0, 0)
                SystemOS.SnapPreview.Size = UDim2.new(0.5, 0, 1, 0)
                SystemOS.SnapPreview.Visible = true
            else
                activeSnapTarget = nil
                SystemOS.SnapPreview.Visible = false
            end
        end
    end)

    local function ConnectHandle(handleName, dirX, dirY, isNegativeX, isNegativeY)
        local handle = ResizeSystem:FindFirstChild(handleName)
        if not handle then return end

        local resizing = false
        local rStartMouse, rStartSize, rStartPos

        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                RequestFocus()
                resizing = true
                rStartMouse = input.Position
                rStartSize = Window.AbsoluteSize
                rStartPos = Window.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        resizing = false
                    end
                end)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - rStartMouse
                local newW = rStartSize.X
                local newH = rStartSize.Y
                local newPosX = rStartPos.X.Offset
                local newPosY = rStartPos.Y.Offset

                if dirX ~= 0 then
                    if isNegativeX then
                        local diff = delta.X
                        newW = math.max(minSize.X, rStartSize.X - diff)
                        newPosX = rStartPos.X.Offset + (rStartSize.X - newW)
                    else
                        newW = math.max(minSize.X, rStartSize.X + delta.X)
                    end
                end

                if dirY ~= 0 then
                    if isNegativeY then
                        local diff = delta.Y
                        newH = math.max(minSize.Y, rStartSize.Y - diff)
                        newPosY = rStartPos.Y.Offset + (rStartSize.Y - newH)
                    else
                        newH = math.max(minSize.Y, rStartSize.Y + delta.Y)
                    end
                end

                Window.Size = UDim2.new(0, newW, 0, newH)
                Window.Position = UDim2.new(rStartPos.X.Scale, newPosX, rStartPos.Y.Scale, newPosY)
                FireTransform()
            end
        end)
    end

    ConnectHandle("Left", 1, 0, false, false)
    ConnectHandle("Right", 1, 0, true, false)
    ConnectHandle("Top", 0, 1, false, true)
    ConnectHandle("Bottom", 0, 1, false, false)
    ConnectHandle("Left-Top", 1, 1, false, true)
    ConnectHandle("Right-Top", 1, 1, true, true)
    ConnectHandle("Left-Bottom", 1, 1, false, false)
    ConnectHandle("Right-Bottom", 1, 1, true, false)

    local isMinimized = false
    local savedWinPos, savedWinSize
    local isAnimating = false

    local function DoMinimize()
        if not winObj.ButtonStates._MINIMIZE then return end
        if isAnimating or isMinimized then return end
        isAnimating = true

        savedWinPos = Window.Position
        savedWinSize = Window.Size

        local desktopAbsPos = SystemOS.Desktop.AbsolutePosition
        local taskAbsPos = TaskApp.AbsolutePosition
        local taskAbsSize = TaskApp.AbsoluteSize

        local targetX = taskAbsPos.X - desktopAbsPos.X + (taskAbsSize.X / 2) - 25
        local targetY = SystemOS.Desktop.AbsoluteSize.Y + 10
        local targetPos = UDim2.new(0, targetX, 0, targetY)
        local targetSize = UDim2.new(0, 50, 0, 15)

        local tweenPos = TweenService:Create(Window, WIN10_ANIM_INFO, { Position = targetPos, Size = targetSize })
        tweenPos:Play()

        tweenPos.Completed:Connect(function()
            Window.Visible = false
            isMinimized = true
            isAnimating = false
            if winObj.OverlayContainer then winObj.OverlayContainer.Visible = false end
        end)

        TaskApp.UIGradient.Color = SystemOS.Templates.TaskAppOff.UIGradient.Color
        if SystemOS.ActiveWindow == winObj then
            SystemOS.ActiveWindow = nil
        end
    end

    local function DoRestore()
        if isAnimating or not isMinimized then return end
        isAnimating = true

        local desktopAbsPos = SystemOS.Desktop.AbsolutePosition
        local taskAbsPos = TaskApp.AbsolutePosition
        local taskAbsSize = TaskApp.AbsoluteSize

        local startX = taskAbsPos.X - desktopAbsPos.X + (taskAbsSize.X / 2) - 25
        local startY = SystemOS.Desktop.AbsoluteSize.Y + 10

        Window.Visible = true
        Window.Position = UDim2.new(0, startX, 0, startY)
        Window.Size = UDim2.new(0, 50, 0, 15)

        SystemOS:FocusWindow(winObj)

        local tweenPos = TweenService:Create(Window, WIN10_ANIM_INFO, { Position = savedWinPos, Size = savedWinSize })
        tweenPos:Play()

        tweenPos.Completed:Connect(function()
            isMinimized = false
            isAnimating = false
            if winObj.OverlayContainer then winObj.OverlayContainer.Visible = true end
            FireTransform()
        end)
    end

    minBtn.MouseButton1Click:Connect(function()
        DoMinimize()
    end)

    TaskApp.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            SystemOS.PreventUnfocus = true
        end
    end)

    TaskApp.MouseButton1Click:Connect(function()
        if isMinimized then
            DoRestore()
        else
            if SystemOS.ActiveWindow == winObj then
                if winObj.ButtonStates._MINIMIZE then
                    DoMinimize()
                end
            else
                SystemOS:FocusWindow(winObj)
            end
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        if not winObj.ButtonStates._CLOSE then return end
        local tweenClose = TweenService:Create(Window, FADE_TWEEN, {
            Size = UDim2.new(Window.Size.X.Scale, Window.Size.X.Offset * 0.95, Window.Size.Y.Scale, Window.Size.Y.Offset * 0.95),
            BackgroundTransparency = 1
        })
        tweenClose:Play()
        tweenClose.Completed:Connect(function()
            if SystemOS.ModalWindow == winObj then
                SystemOS.ModalWindow = nil
            end
            for idx, w in ipairs(SystemOS.Windows) do
                if w == winObj then
                    table.remove(SystemOS.Windows, idx)
                    break
                end
            end
            if winObj.OverlayContainer then
                winObj.OverlayContainer:Destroy()
            end
            Window:Destroy()
            TaskApp:Destroy()
            transformBindable:Destroy()

            if #SystemOS.Windows > 0 then
                SystemOS:FocusWindow(SystemOS.Windows[#SystemOS.Windows])
            end
        end)
    end)

    function winObj:CreateOverlay()
        local overlay = Instance.new("Frame", SystemOS.NonUser)
        overlay.Name = title .. "_Overlay"
        overlay.BackgroundTransparency = 1
        overlay.BorderSizePixel = 0
        overlay.ZIndex = Window.ZIndex + 1
        winObj.OverlayContainer = overlay

        winObj.OnTransform:Connect(function(wPos, wSize, cPos, cSize)
            overlay.Position = UDim2.new(0, cPos.X, 0, cPos.Y)
            overlay.Size = UDim2.new(0, cSize.X, 0, cSize.Y)
        end)

        return overlay
    end

    SystemOS:FocusWindow(winObj)
    task.defer(FireTransform)

    return winObj
end

--------------------------------------------------------------------------------
-- 8. VẼ LÊN LAYER NonUser
--------------------------------------------------------------------------------
function SystemOS:DrawOnNonUser(guiType, properties)
    EnsureInitialized(self)
    local inst = Instance.new(guiType or "Frame", SystemOS.NonUser)
    if properties then
        for k, v in pairs(properties) do
            pcall(function() inst[k] = v end)
        end
    end
    return inst
end

--------------------------------------------------------------------------------
-- 9. WORLD RAYCAST CONTEXT MENU (CAMERA - BẮN TIA CHUẨN XÁC 100%)
--------------------------------------------------------------------------------
function SystemOS:BindWorldContextMenu(builderCallback)
    EnsureInitialized(self)

    local rmbStartPos = nil
    local rmbStartTime = 0
    local isRmbDown = false

    local function TryWorldRaycast()
        local camera = workspace.CurrentCamera
        if not camera then return end

        local mouseLoc = UserInputService:GetMouseLocation()
        local ray = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
        if not ray then return end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        if LocalPlayer.Character then
            params.FilterDescendantsInstances = { LocalPlayer.Character }
        end

        local result = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
        if result and result.Instance then
            local hitPart = result.Instance
            local items = builderCallback(hitPart, result.Position)
            if items and #items > 0 then
                SystemOS:CloseAllContextMenus()
                local exactPos = GetExactMousePosition()
                SystemOS:CreateContextMenu(items, exactPos.X, exactPos.Y, SystemOS.NonUser)
            end
        end
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            isRmbDown = true
            rmbStartPos = UserInputService:GetMouseLocation()
            rmbStartTime = tick()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 and isRmbDown then
            isRmbDown = false
            local curPos = UserInputService:GetMouseLocation()
            local dist = (curPos - rmbStartPos).Magnitude
            local elapsed = tick() - rmbStartTime

            if dist < 6 and elapsed < 0.35 then
                TryWorldRaycast()
            end
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Touch then
            local startPos = input.Position
            local cancelled = false

            local moveConn
            moveConn = UserInputService.InputChanged:Connect(function(changeInput)
                if changeInput == input and (Vector2.new(changeInput.Position.X, changeInput.Position.Y) - Vector2.new(startPos.X, startPos.Y)).Magnitude > 15 then
                    cancelled = true
                    if moveConn then moveConn:Disconnect() end
                end
            end)

            task.delay(0.5, function()
                if not cancelled and input.UserInputState ~= Enum.UserInputState.End and input.UserInputState ~= Enum.UserInputState.Cancel then
                    if moveConn then moveConn:Disconnect() end
                    local camera = workspace.CurrentCamera
                    if camera then
                        local ray = camera:ViewportPointToRay(startPos.X, startPos.Y)
                        if ray then
                            local params = RaycastParams.new()
                            params.FilterType = Enum.RaycastFilterType.Exclude
                            if LocalPlayer.Character then
                                params.FilterDescendantsInstances = { LocalPlayer.Character }
                            end

                            local result = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
                            if result and result.Instance then
                                local items = builderCallback(result.Instance, result.Position)
                                if items and #items > 0 then
                                    SystemOS:CloseAllContextMenus()
                                    local touchVec = Vector2.new(startPos.X, startPos.Y)
                                    if not SystemOS.ScreenGui.IgnoreGuiInset then
                                        touchVec = touchVec - GuiService:GetGuiInset()
                                    end
                                    SystemOS:CreateContextMenu(items, touchVec.X, touchVec.Y, SystemOS.NonUser)
                                end
                            end
                        end
                    end
                end
            end)

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    cancelled = true
                    if moveConn then moveConn:Disconnect() end
                end
            end)
        end
    end)
end

return SystemOS

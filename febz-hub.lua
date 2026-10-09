-- ============================================================
-- KEY SYSTEM START
-- ============================================================
local KEY_SYS = {
    KEYS_URL      = "https://raw.githubusercontent.com/FebzTzy/febz-hub/main/keys.json",
    CACHE_FILE    = "FebzHub/keycache.json",
    LOCAL_FILE    = "FebzHub/keydata.json",
    HWID_REQUIRED = true,
    CACHE_TTL     = 300,
    OFFLINE_GRACE = 86400,
}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local function ensure_folder(path)
    pcall(function() if not isfolder(path) then makefolder(path) end end)
end
local function read_json(path)
    local ok, data = pcall(function()
        if isfile(path) then return HttpService:JSONDecode(readfile(path)) end
        return nil
    end)
    return ok and data or nil
end
local function write_json(path, data)
    pcall(function() writefile(path, HttpService:JSONEncode(data)) end)
end
local function rm_file(path)
    pcall(function() if isfile(path) then delfile(path) end end)
end

local function get_hwid()
    local ok, hwid = pcall(function()
        if gethwid then return gethwid() end
        if syn and syn.get_hwid then return syn.get_hwid() end
        if get_hwid then return get_hwid() end
        return nil
    end)
    return ok and hwid or nil
end

local function notify(title, desc, color)
    local gui = Instance.new("ScreenGui")
    gui.Name = "FebzKeyNotify"
    gui.ResetOnSpawn = false
    gui.Parent = plr:WaitForChild("PlayerGui")
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 340, 0, 92)
    frame.Position = UDim2.new(0.5, -170, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = color or Color3.fromRGB(90, 90, 100)
    stroke.Thickness = 1
    local t = Instance.new("TextLabel", frame)
    t.Size = UDim2.new(1, -20, 0, 26)
    t.Position = UDim2.new(0, 10, 0, 8)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 14
    t.TextColor3 = color or Color3.fromRGB(240, 240, 240)
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = title
    local d = Instance.new("TextLabel", frame)
    d.Size = UDim2.new(1, -20, 0, 50)
    d.Position = UDim2.new(0, 10, 0, 34)
    d.BackgroundTransparency = 1
    d.Font = Enum.Font.GothamMedium
    d.TextSize = 12
    d.TextColor3 = Color3.fromRGB(220, 220, 230)
    d.TextWrapped = true
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.TextYAlignment = Enum.TextYAlignment.Top
    d.Text = desc
    task.delay(7, function() if gui and gui.Parent then gui:Destroy() end end)
end

local function fetch_keys_remote()
    local ok, body = pcall(function() return game:HttpGet(KEY_SYS.KEYS_URL, true) end)
    if not ok or not body or body == "" then return nil, "fetch_failed" end
    local decode_ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not decode_ok or type(data) ~= "table" then return nil, "decode_failed" end
    ensure_folder("FebzHub")
    write_json(KEY_SYS.CACHE_FILE, { fetched_at = os.time(), data = data })
    return data, "ok"
end

local function load_cache()
    local cache = read_json(KEY_SYS.CACHE_FILE)
    if not cache or not cache.data or not cache.fetched_at then return nil end
    if os.time() - cache.fetched_at > KEY_SYS.OFFLINE_GRACE then return nil end
    return cache.data, os.time() - cache.fetched_at
end

local function get_keys_config()
    local cache = read_json(KEY_SYS.CACHE_FILE)
    local age = cache and cache.fetched_at and (os.time() - cache.fetched_at) or math.huge
    if age >= KEY_SYS.CACHE_TTL then
        local data, err = fetch_keys_remote()
        if data then return data, "remote" end
        local cached = load_cache()
        if cached then return cached, "cache_stale" end
        return nil, err or "no_cache"
    end
    return cache.data, "cache"
end

local function validate(key, hwid, config)
    if not key or key == "" then return false, "empty" end
    if not config or not config.keys then return false, "no_config" end
    if config.maintenance == true then return false, "maintenance" end
    if hwid and type(config.blacklist_hwid) == "table" then
        for _, banned in ipairs(config.blacklist_hwid) do
            if banned == hwid then return false, "hwid_banned" end
        end
    end
    local entry = config.keys[key]
    if not entry then return false, "invalid" end
    local exp = tonumber(entry.expires) or 0
    if exp > 0 and os.time() > exp then return false, "expired" end
    if KEY_SYS.HWID_REQUIRED and hwid then
        ensure_folder("FebzHub")
        local bind_path = "FebzHub/keybind.json"
        local bind = read_json(bind_path) or {}
        if bind[key] and bind[key] ~= hwid then return false, "bound_elsewhere" end
        if not bind[key] then bind[key] = hwid; write_json(bind_path, bind) end
    end
    return true, "ok"
end

local function prompt_key(reason)
    local gui = Instance.new("ScreenGui")
    gui.Name = "FebzKeyPrompt"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = plr:WaitForChild("PlayerGui")

    local bd = Instance.new("Frame", gui)
    bd.Size = UDim2.new(1, 0, 1, 0)
    bd.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bd.BackgroundTransparency = 0.5
    bd.BorderSizePixel = 0

    local box = Instance.new("Frame", bd)
    box.Size = UDim2.new(0, 380, 0, 220)
    box.Position = UDim2.new(0.5, -190, 0.5, -110)
    box.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
    local bs = Instance.new("UIStroke", box)
    bs.Color = Color3.fromRGB(100, 100, 110)
    bs.Thickness = 1.2

    local title = Instance.new("TextLabel", box)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 12)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.Text = "Febz Hub — Key Required"

    local sub = Instance.new("TextLabel", box)
    sub.Size = UDim2.new(1, -40, 0, 34)
    sub.Position = UDim2.new(0, 20, 0, 46)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.GothamMedium
    sub.TextSize = 12
    sub.TextColor3 = Color3.fromRGB(160, 160, 170)
    sub.TextWrapped = true
    sub.Text = reason or "Masukin key lu. Hubungi owner kalau belum punya."

    local input = Instance.new("TextBox", box)
    input.Size = UDim2.new(1, -40, 0, 38)
    input.Position = UDim2.new(0, 20, 0, 92)
    input.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    input.BorderSizePixel = 0
    input.Font = Enum.Font.Code
    input.TextSize = 13
    input.TextColor3 = Color3.fromRGB(235, 235, 240)
    input.PlaceholderText = "XXXX-XXXX-XXXX-XXXX"
    input.PlaceholderColor3 = Color3.fromRGB(90, 90, 100)
    input.Text = ""
    input.ClearTextOnFocus = false
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)

    local status = Instance.new("TextLabel", box)
    status.Size = UDim2.new(1, -40, 0, 40)
    status.Position = UDim2.new(0, 20, 0, 134)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 11
    status.TextColor3 = Color3.fromRGB(255, 100, 100)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.TextWrapped = true
    status.Text = ""

    local submit = Instance.new("TextButton", box)
    submit.Size = UDim2.new(1, -40, 0, 32)
    submit.Position = UDim2.new(0, 20, 0, 178)
    submit.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
    submit.BorderSizePixel = 0
    submit.Font = Enum.Font.GothamBold
    submit.TextSize = 13
    submit.TextColor3 = Color3.fromRGB(235, 235, 240)
    submit.Text = "Verify"
    Instance.new("UICorner", submit).CornerRadius = UDim.new(0, 6)

    local done = false

    local function try_verify(key)
        status.TextColor3 = Color3.fromRGB(180, 180, 190)
        status.Text = "memverifikasi..."
        local config, source = get_keys_config()
        if not config then
            status.TextColor3 = Color3.fromRGB(255, 100, 100)
            status.Text = "gagal fetch key config — coba lagi"
            return
        end
        local ok, reason2 = validate(key, get_hwid(), config)
        if ok then
            ensure_folder("FebzHub")
            write_json(KEY_SYS.LOCAL_FILE, { key = key, saved_at = os.time(), hwid = get_hwid(), source = source })
            status.TextColor3 = Color3.fromRGB(120, 255, 120)
            status.Text = "berhasil — loading..."
            done = true
            task.wait(0.4)
            gui:Destroy()
        else
            local msg = ({
                empty           = "key kosong",
                invalid         = "key salah / nggak terdaftar",
                expired         = "key udah expired",
                bound_elsewhere = "key ini ke-lock ke device lain",
                hwid_banned     = "device lu di-ban",
                maintenance     = "hub lagi maintenance, coba nanti",
                no_config       = "config key kosong / rusak",
            })[reason2] or ("gagal: " .. tostring(reason2))
            status.TextColor3 = Color3.fromRGB(255, 100, 100)
            status.Text = msg
        end
    end

    submit.MouseButton1Click:Connect(function()
        local key = (input.Text or ""):gsub("%s+", ""):upper()
        try_verify(key)
    end)
    input.FocusLost:Connect(function(enter)
        if enter then
            local key = (input.Text or ""):gsub("%s+", ""):upper()
            try_verify(key)
        end
    end)

    while not done do task.wait(0.1) end
end

local function check_and_gate()
    local stored = read_json(KEY_SYS.LOCAL_FILE)
    if stored and stored.key then
        local config, source = get_keys_config()
        if config then
            local ok, reason = validate(stored.key, get_hwid(), config)
            if ok then
                if source == "cache_stale" then
                    notify("Febz Hub", "Key valid (offline).", Color3.fromRGB(255, 200, 100))
                else
                    notify("Febz Hub", "Key valid — welcome.", Color3.fromRGB(120, 255, 120))
                end
                return true
            end
            rm_file(KEY_SYS.LOCAL_FILE)
            if reason == "maintenance" then
                notify("Maintenance", "Script lagi maintenance.", Color3.fromRGB(255, 200, 100))
                return false
            end
        else
            notify("Connection", "Gagal fetch config + nggak ada cache.", Color3.fromRGB(255, 100, 100))
            return false
        end
    end
    prompt_key()
    local after = read_json(KEY_SYS.LOCAL_FILE)
    if after and after.key then
        local config = get_keys_config()
        if config then
            local ok = validate(after.key, get_hwid(), config)
            if ok then return true end
        end
    end
    return false
end

if not check_and_gate() then
    return
end
-- ============================================================
-- KEY SYSTEM END
-- ============================================================

-- Recovered Luau source by ZeroVector
local v1 = loadstring(game:HttpGet("https://script.panduhub.com/PanduUiLibrary.lua"))()
local v2, v3, v4, v5, v6, v7, v9, v10, v11, v12, v13, v14, v374, v375, v376, v379, v380, v384, v482, v487
local v539, v567, v568, v625, v765, v766, v771, v777, v791
do
    v1.Scheme.AccentColor = Color3.fromRGB(255, 255, 255)
    v1.Scheme.BackgroundColor = Color3.fromRGB(10, 10, 12)
    v1.Scheme.MainColor = Color3.fromRGB(16, 16, 18)
    v1.Scheme.OutlineColor = Color3.fromRGB(255, 255, 255)
    v1.Scheme.FontColor = Color3.fromRGB(235, 235, 240)
    v1.Scheme.SubTextColor = Color3.fromRGB(140, 140, 150)
    v1.Scheme.HoverColor = Color3.fromRGB(22, 22, 26)
    v2 = v1:CreateWindow({
        Title = "Febz Hub",
        Subtitle = "Violance District",
        SubtitleColor = Color3.fromRGB(190, 140, 255),
        Logo = "rbxassetid://140240380177843",
        LogoSize = 32,
        SphereText = false,
        SphereWords = "ZX",
        SphereImage = "rbxassetid://140240380177843",
        SphereIconSize = 38,
        Watermark = true,
        WatermarkText = "Febz",
        WatermarkIcon = "rbxassetid://140240380177843",
    })
    v3 = game:GetService("Players")
    v4 = v3.LocalPlayer
    v5 = game:GetService("RunService")
    v6 = game:GetService("UserInputService")
    v7 = game:GetService("VirtualInputManager")
    local v8 = game:GetService("GuiService")
    v9 = game:GetService("ReplicatedStorage")
    v10 = game:GetService("CoreGui")
    v11 = v4:WaitForChild("PlayerGui")
    v12 = workspace.CurrentCamera
    v13 = game:GetService("CollectionService")
    v14 = game:GetService("HttpService")
    game:GetService("TeleportService")
    local v15 = game:GetService("TweenService")
    _G.Ox = {}
    _G.Ox.AntiBlindEnabled = false
    _G.Ox.GotBlindedRemote = nil
    _G.Ox.NoSlowdownEnabled = false
    _G.Ox.BypassLeapEnabled = false
    _G.Ox.InfAbyssalEnabled = false
    _G.Ox.KILLER_SilentAimFlask = false
    _G.Ox.KILLER_FlaskLaser = false
    _G.Ox.NEX_CureFlaskLaserThread = nil
    _G.Ox.NEX_CureFlaskLaserPart = nil
    _G.Ox.InfiniteLungeEnabled = false
    local v16 = {
        ["122812055447896"] = "Veil lunge",
        ["133963973694098"] = "Mayers Basic",
        ["117042998468241"] = "Mayers lunge",
        ["135002183282873"] = "cure lunge",
        ["121216847022485"] = "cure Basic",
        ["132817836308238"] = "Jeff Basic",
        ["129784271201071"] = "Jeff lunge",
        ["82666958311998"] = "Jeff Frenzy",
        ["78432063483146"] = "Abyssal Basic",
        ["118907603246885"] = "Abyssal lunge",
        ["139369275981139"] = "Jason Basic",
        ["110355011987939"] = "Jason lunge",
        ["111920872708571"] = "Masked Basic",
        ["105374834496520"] = "Masked lunge",
        ["138720291317243"] = "Masked Tony",
        ["106871536134254"] = "Masked Alex",
        ["130593238885843"] = "Masked Cobra",
        ["115244153053858"] = "Masked Cobra lunge",
        ["74968262036854"] = "Hidden Basic",
        ["113255068724446"] = "Hidden lunge",
        ["98163597193511"] = "Hidden S1",
        ["80411309607666"] = "Abyssal S1",
    }
    _G.Ox.ParryConfig = {
        AutoParry = false,
        ParrySafety = false,
        ParryAggressive = false,
        ParryCircle = true,
        ParryRadius = 15,
        ParryFace = 0.7,
        AutoCrouch = false,
        Ignored_Skills = {},
    }
    _G.Ox.ParryV2 = {
        Enabled = false,
        SafetyParry = false,
        Mode = "Legit",
        Trigger = "Remote",
        Range = 12,
        KillerFace = 0.6,
        ShowCircle = true,
        IsOnCooldown = false,
        IsResolving = false,
        CooldownToken = 0,
        CooldownThread = nil,
        Attached = {},
        Gradients = {},
        Icon = nil,
        LockConnection = nil,
        ParryTrack = nil,
        RangeAdornment = nil,
        BtnCache = nil,
    }
    _G.Ox.ParryV2Anim = {
        Default = "rbxassetid://109133187196613",
        Shield = "rbxassetid://75939529748815",
        Robot = "rbxassetid://126894569253341",
        Katana = "rbxassetid://127096285501517",
        Fish = "rbxassetid://123307242865945",
        Watcher = "rbxassetid://81793464499285",
        Enten = "rbxassetid://127096285501517",
        BloodShield = "rbxassetid://75939529748815",
        Fih = "rbxassetid://123307242865945",
        Feedbacker = "rbxassetid://126894569253341",
        StopWatch = "rbxassetid://81793464499285",
    }
    _G.Ox.ParryV2AttackAnims = {
        ["rbxassetid://78432063483146"] = true,
        ["rbxassetid://121216847022485"] = true,
        ["rbxassetid://74968262036854"] = true,
        ["rbxassetid://132817836308238"] = true,
        ["rbxassetid://82666958311998"] = true,
        ["rbxassetid://111920872708571"] = true,
        ["rbxassetid://106871536134254"] = true,
        ["rbxassetid://109402730355822"] = true,
        ["rbxassetid://130593238885843"] = true,
        ["rbxassetid://138720291317243"] = true,
        ["rbxassetid://139369275981139"] = true,
        ["rbxassetid://133963973694098"] = true,
        ["rbxassetid://78935059863801"] = true,
        ["rbxassetid://118907603246885"] = true,
        ["rbxassetid://135002183282873"] = true,
        ["rbxassetid://113255068724446"] = true,
        ["rbxassetid://129784271201071"] = true,
        ["rbxassetid://105374834496520"] = true,
        ["rbxassetid://117070354890871"] = true,
        ["rbxassetid://115244153053858"] = true,
        ["rbxassetid://110355011987939"] = true,
        ["rbxassetid://117042998468241"] = true,
        ["rbxassetid://122812055447896"] = true,
    }
    _G.Ox._V2RayParams = RaycastParams.new()
    _G.Ox._V2RayParams.FilterType = Enum.RaycastFilterType.Exclude
    _G.Ox._V2ParryRangeRay = RaycastParams.new()
    _G.Ox._V2ParryRangeRay.FilterType = Enum.RaycastFilterType.Exclude
    _G.Ox._V2ParryLastRadius = -1
    _G.Ox._V2ParryLastRoot = nil
    _G.Ox.AttachedParry = {}
    if not _G.Ox.State then
        _G.Ox.State = {}
    end
    _G.Ox.State.ParryCooldown = false
    _G.Ox.State.ParryCooldownTime = 60
    _G.Ox.State.AutoParryAdornment = nil
    _G.Ox.State.ParryCooldownThread = nil
    _G.Ox.AutoParryCustom = {Gui = nil, IsActive = false, GuiVisible = false}
    local v17 = _G.Ox
    local v18 = _G.Ox.ParryHUD
    local v19 = v18
    if not v18 then
        local v20 = {}
        v19 = v20
        v20.gradients = {}
        v20.icon = nil
        v20.rescanConn = nil
        v20.cachedIconColor = nil
    end
    v17.ParryHUD = v19
    ParryHUD = _G.Ox.ParryHUD
    IsDowned = function(a1)
        if not a1 then
            return false
        end
        local v21 = a1:GetAttribute("Knocked") == true or a1:GetAttribute("IsHooked") == true
        return v21
    end
    IsKiller = function(a2)
        local v22 = a2 and a2.Team and a2.Team.Name == "Killer"
        return v22
    end
    TriggerCrouch = function()
        pcall(function()
            local v23 = v4:FindFirstChild("PlayerGui")
            for v28 in string.gmatch("Survivor-mob.Controls.crouch.icon", "[^%.]+") do
                if v23 then
                    v23 = v23:FindFirstChild(v28)
                end
            end
            if v23 and v23:IsA("GuiObject") and v23.Visible and v23.Parent and v23.Parent:IsA("GuiButton") then
                local v29 = v23.Parent
                if v6.TouchEnabled and type(firesignal) == "function" then
                    firesignal(v29.MouseButton1Click)
                    task.wait(1.4)
                    firesignal(v29.MouseButton1Click)
                else
                    v7:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
                    task.wait(1.4)
                    v7:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
                end
            else
                v7:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
                task.wait(1.4)
                v7:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
            end
        end)
    end
    IsSafeToParry = function(a3)
        if not _G.Ox.ParryConfig.ParrySafety then
            return true
        end
        if not a3 then
            return false
        end
        local v30 = a3:FindFirstChild("CheckInterractable")
        if v30 then
            if v30:GetAttribute("isVaulting") == true then
                return false
            end
            if v30:GetAttribute("isRepairing") == true then
                return false
            end
            if v30:GetAttribute("isUnhooking") == true then
                return false
            end
            if v30:GetAttribute("isHealing") == true then
                return false
            end
            if v30:GetAttribute("isSliding") == true then
                return false
            end
        end
        return true
    end
    tapMobileParryButton = function()
        local v31 = v4:FindFirstChild("PlayerGui")
        if not v31 then
            return
        end
        local v32 = v31:FindFirstChild("Survivor-mob")
        local v33 = v32 and v32:FindFirstChild("Controls") and v32.Controls:FindFirstChild("Gui-mob")
        if v33 and v33.Visible then
            if firesignal then
                pcall(function()
                    firesignal(v33.MouseButton1Down)
                    task.wait(0.01)
                    firesignal(v33.MouseButton1Up)
                end)
            end
        else
            pcall(function()
                if not mouse2click then
                    if mouse2press and mouse2release then
                        mouse2press()
                        task.wait(0.01)
                        mouse2release()
                        return
                    end
                    v7:SendMouseButtonEvent(0, 0, 1, true, game, 0)
                    task.wait(0.01)
                    v7:SendMouseButtonEvent(0, 0, 1, false, game, 0)
                    return
                end
                mouse2click()
            end)
        end
    end
    ExecuteParry = function()
        if _G.Ox.State.ParryCooldown then
            return
        end
        local v34 = v9:FindFirstChild("Remotes")
        local v35 = v34 and v34:FindFirstChild("Items")
        local v36 = v35 and v35:FindFirstChild("Parrying Dagger")
        local v37 = v36 and v36:FindFirstChild("parry")
        if v37 then
            for v39 = 1, 8 do
                v37:FireServer()
            end
        end
        task.spawn(tapMobileParryButton)
    end
    ParryHUD.Scan = function()
        local v40 = v4:FindFirstChild("PlayerGui")
        if not v40 then
            return false
        end
        table.clear(ParryHUD.gradients)
        ParryHUD.icon = nil
        for v45, v46 in ipairs({"Survivor", "Survivor-con"}) do
            local v47 = v40:FindFirstChild(v46)
            if v47 then
                local v48 = v47:FindFirstChild("Gen")
                local v49 = v48 and v48:FindFirstChild("ItemFrame")
                if v49 then
                    local v50 = v49:FindFirstChild("Gui")
                    local v51 = v50 and v50:FindFirstChild("Bar")
                    local v52 = v51 and v51:FindFirstChild("UIGradient")
                    if v52 then
                        table.insert(ParryHUD.gradients, v52)
                    end
                    local v53 = v49:FindFirstChild("icon")
                    if v53 then
                        ParryHUD.icon = v53
                    end
                end
            end
        end
        local v54 = v40:FindFirstChild("Survivor-mob")
        local v55 = v54 and v54:FindFirstChild("Controls")
        if v55 then
            for v60, v61 in ipairs(v55:GetChildren()) do
                if v61:IsA("ImageButton") and v61.Name == "Gui-mob" then
                    local v62 = v61:FindFirstChild("Bar")
                    local v63 = v62 and v62:FindFirstChild("UIGradient")
                    if v63 then
                        table.insert(ParryHUD.gradients, v63)
                    end
                end
            end
        end
        local v64 = #ParryHUD.gradients > 0 or ParryHUD.icon ~= nil
        return v64
    end
    ParryHUD.SetColor = function(a4)
        if #ParryHUD.gradients == 0 and not ParryHUD.icon then
            ParryHUD.Scan()
        end
        ParryHUD.cachedIconColor = a4
        for v69, v70 in ipairs(ParryHUD.gradients) do
            if v70 and v70.Parent and v70.Parent.Parent then
                local v71 = v70.Parent.Parent:FindFirstChild("icon")
                if v71 then
                    v71.ImageColor3 = a4
                end
                local v72 = v70.Parent.Parent:FindFirstChild("Gui")
                if v72 then
                    v72.ImageColor3 = a4
                end
            end
        end
        if ParryHUD.icon then
            ParryHUD.icon.ImageColor3 = a4
        end
    end
    ParryHUD.Tween = function(a5)
        if #ParryHUD.gradients == 0 then
            ParryHUD.Scan()
        end
        for v77, v78 in ipairs(ParryHUD.gradients) do
            if v78 and v78.Parent then
                v78.Offset = Vector2.new(0, 0.75)
                local v79 = v15:Create(v78, TweenInfo.new(a5, Enum.EasingStyle.Linear), {Offset = Vector2.new(0, 0.25)})
                v79:Play()
                v79.Completed:Connect(function()
                    if not _G.Ox.State.ParryCooldown then
                        ParryHUD.SetColor(Color3.fromRGB(255, 255, 255))
                    end
                end)
            end
        end
    end
    ParryHUD.Reset = function()
        ParryHUD.SetColor(Color3.fromRGB(255, 255, 255))
        for v84, v85 in ipairs(ParryHUD.gradients) do
            if v85 and v85.Parent then
                v85.Offset = Vector2.new(0, 0.25)
            end
        end
    end
    ParryHUD.SetupWatcher = function()
        if ParryHUD.rescanConn then
            ParryHUD.rescanConn:Disconnect()
        end
        local v86 = v4:FindFirstChild("PlayerGui")
        if not v86 then
            return
        end
        ParryHUD.rescanConn = v86.ChildAdded:Connect(function(a6)
            local v87 = a6.Name
            if v87 == "Survivor" or v87 == "Survivor-con" or v87 == "Survivor-mob" then
                task.wait(0.3)
                ParryHUD.Scan()
                if _G.Ox.State.ParryCooldown and ParryHUD.cachedIconColor then
                    ParryHUD.SetColor(ParryHUD.cachedIconColor)
                end
            end
        end)
        task.spawn(function()
            local v88 = 0
            while v88 < 10 and not ParryHUD.Scan() do
                task.wait(0.5)
                v88 = v88 + 0.5
            end
        end)
    end
    ParryHUD.SetupWatcher()
    v4.CharacterAdded:Connect(function()
        task.wait(1.5)
        ParryHUD.Scan()
        if _G.Ox.State.ParryCooldown and ParryHUD.cachedIconColor then
            ParryHUD.SetColor(ParryHUD.cachedIconColor)
        end
    end)
    ListenToParryResult = function()
        task.spawn(function()
            local v89 = v9:WaitForChild("Remotes", 5)
            local v90 = v89 and v89:WaitForChild("Items", 5):WaitForChild("Parrying Dagger", 5)
            local v91 = v90 and v90:WaitForChild("parryResult", 5)
            if v91 then
                v91.OnClientEvent:Connect(function(a7, a8)
                    local v92 = tonumber(a8)
                    local v93 = v92 or (a7 == true and 90 or 60)
                    _G.Ox.State.ParryCooldown = true
                    if _G.Ox.State.ParryCooldownThread then
                        task.cancel(_G.Ox.State.ParryCooldownThread)
                    end
                    ParryHUD.SetColor(Color3.fromRGB(77, 77, 77))
                    ParryHUD.Tween(v93)
                    _G.Ox.State.ParryCooldownThread = task.delay(v93, function()
                        _G.Ox.State.ParryCooldown = false
                        ParryHUD.SetColor(Color3.fromRGB(255, 255, 255))
                    end)
                end)
            end
        end)
    end
    ListenToParryResult()
    IsInKillerPOV = function(a9, a10, a11)
        if not a9 or not a10 then
            return false
        end
        local v94 = a10.Position - a9.Position
        local v95 = Vector3.new(v94.X, 0, v94.Z)
        if v95.Magnitude < 0.15 then
            return true
        end
        local v96 = Vector3.new(a9.CFrame.LookVector.X, 0, a9.CFrame.LookVector.Z)
        if v96.Magnitude < 0.05 then
            return false
        end
        local v97 = v96.Unit:Dot(v95.Unit)
        local v98 = a11 or 0.35
        local v99 = v98 <= v97
        return v99
    end
    AttachParrySensor = function(a12)
        if not a12 or _G.Ox.AttachedParry[a12] then
            return
        end
        _G.Ox.AttachedParry[a12] = true
        local v100 = a12:WaitForChild("Humanoid", 5)
        if not v100 then
            return
        end
        local v101 = v100:FindFirstChildOfClass("Animator")
        local v102 = v101 or v100:WaitForChild("Animator", 5)
        if not v102 then
            return
        end
        v100.ChildAdded:Connect(function(a13)
            if a13:IsA("Animator") then
                _G.Ox.AttachedParry[a12] = nil
                AttachParrySensor(a12)
            end
        end)
        a12.AncestryChanged:Connect(function(a14, a15)
            if not a15 then
                _G.Ox.AttachedParry[a12] = nil
            end
        end)
        v102.AnimationPlayed:Connect(function(a16)
            local v103 = a16.Animation
            local v104 = v103 and a16.Animation.AnimationId or ""
            local v105 = v104:match("%d+")
            local v106 = v16[v105]
            if not v106 then
                return
            end
            if v105 == "80411309607666" and _G.Ox.ParryConfig.AutoCrouch then
                local v107 = v4.Character
                if IsDowned(v107) then
                    return
                end
                local v108 = v107 and v107:FindFirstChild("HumanoidRootPart")
                local v109 = a12:FindFirstChild("HumanoidRootPart")
                if v108 and v109 and (v108.Position - v109.Position).Magnitude <= 40 then
                    TriggerCrouch()
                end
                return
            end
            if not _G.Ox.ParryConfig.AutoParry then
                return
            end
            if _G.Ox.State.ParryCooldown then
                return
            end
            if _G.Ox.ParryConfig.Ignored_Skills and _G.Ox.ParryConfig.Ignored_Skills[v106] then
                return
            end
            local v110 = v4.Character
            if IsDowned(v110) or not IsSafeToParry(v110) then
                return
            end
            local v111 = v110 and v110:FindFirstChild("HumanoidRootPart")
            local v112 = a12:FindFirstChild("HumanoidRootPart")
            if not v111 or not v112 then
                return
            end
            local v113 = (v111.Position - v112.Position).Magnitude
            local v114 = _G.Ox.ParryConfig.ParryFace
            if v114 < 0.2 then
                v114 = 0.35
            end
            if _G.Ox.ParryConfig.ParryAggressive then
                if _G.Ox.ParryConfig.ParryRadius + 5 < v113 then
                    return
                end
                local v115 = function()
                    if _G.Ox.State.ParryCooldown or IsDowned(v110) then
                        return true
                    end
                    if not v111 or not v112 or not v111.Parent or not v112.Parent then
                        return true
                    end
                    if (v111.Position - v112.Position).Magnitude > 12 or not IsInKillerPOV(v112, v111, v114) then
                        return false
                    end
                    ExecuteParry()
                    return true
                end
                if v115() then
                    return
                end
                local v116 = nil
                local v117 = os.clock()
                v116 = v5.Heartbeat:Connect(function()
                    if (os.clock() - v117 >= 0.85 or v115()) and v116 then
                        v116:Disconnect()
                    end
                end)
            else
                local v118 = _G.Ox.ParryConfig.ParryRadius + 2
                if _G.Ox.ParryConfig.ParryRadius + 6 < v113 then
                    return
                end
                if v113 <= v118 and IsInKillerPOV(v112, v111, v114) then
                    ExecuteParry()
                    return
                end
                local v119 = os.clock()
                local v120 = nil
                v120 = v5.Heartbeat:Connect(function()
                    if os.clock() - v119 < 0.28 and not _G.Ox.State.ParryCooldown and v111 and v112 and v111.Parent and v112.Parent and not IsDowned(v110) then
                        if (v111.Position - v112.Position).Magnitude <= v118 and IsInKillerPOV(v112, v111, v114) then
                            ExecuteParry()
                            if v120 then
                                v120:Disconnect()
                            end
                        end
                        return
                    end
                    if v120 then
                        v120:Disconnect()
                    end
                end)
            end
        end)
    end
    TryAttachParry = function(a17)
        if a17 ~= v4 and IsKiller(a17) and a17.Character then
            AttachParrySensor(a17.Character)
        end
    end
    SetupPlayerParry = function(a18)
        if a18 == v4 then
            return
        end
        a18.CharacterAdded:Connect(function()
            TryAttachParry(a18)
        end)
        a18:GetPropertyChangedSignal("Team"):Connect(function()
            TryAttachParry(a18)
        end)
        if a18.Character then
            TryAttachParry(a18)
        end
    end
    for v125, v126 in ipairs(v3:GetPlayers()) do
        SetupPlayerParry(v126)
    end
    v3.PlayerAdded:Connect(SetupPlayerParry)
    V2_HasParryingDagger = function()
        local v127 = v4.Character
        if not v127 then
            return false
        end
        if v127:FindFirstChild("Parrying Dagger") then
            return true
        end
        for v132, v133 in ipairs(v127:GetChildren()) do
            if v133.Name == "Parrying Dagger" and (v133:IsA("Tool") or v133:IsA("Accessory") or v133:IsA("Model")) then
                return true
            end
        end
        return false
    end
    V2_IsBusy = function()
        local v134 = v4.Character
        if not v134 then
            return true
        end
        if v4:GetAttribute("IsDead") then
            return true
        end
        if v134:GetAttribute("IsCarried") then
            return true
        end
        if v134:GetAttribute("IsHooked") then
            return true
        end
        local v135 = v134:FindFirstChild("HumanoidRootPart")
        if v135 and v13:HasTag(v135, "doing action") then
            return true
        end
        if IsDowned(v134) then
            return true
        end
        local v136 = v134:FindFirstChild("CheckInterractable")
        if v136 then
            if v136:GetAttribute("isVaulting") then
                return true
            end
            if v136:GetAttribute("isSliding") then
                return true
            end
            if v136:GetAttribute("isDroppingPallet") then
                return true
            end
            if v136:GetAttribute("isRepairing") then
                return true
            end
            if v136:GetAttribute("isHealing") then
                return true
            end
            if v136:GetAttribute("isUnhooking") then
                return true
            end
            if v136:GetAttribute("isExiting") then
                return true
            end
        end
        return false
    end
    V2_IsLowHealth = function()
        local v137 = v4.Character
        local v138 = v137 and v137:FindFirstChildOfClass("Humanoid")
        if not v138 then
            return true
        end
        local v139 = v138.Health < v138.MaxHealth * 0.5
        return v139
    end
    V2_CanParry = function()
        local v140 = _G.Ox.ParryV2
        if not v140.Enabled then
            return false
        end
        if not V2_HasParryingDagger() then
            return false
        end
        if v140.IsOnCooldown then
            return false
        end
        if v140.IsResolving then
            return false
        end
        if v140.SafetyParry and V2_IsBusy() then
            return false
        end
        if not V2_IsLowHealth() then
            return true
        end
        return false
    end
    V2_HasLOS = function(a19)
        local v141 = v4.Character
        local v142 = v141 and v141:FindFirstChild("HumanoidRootPart")
        local v143 = a19 and a19:FindFirstChild("HumanoidRootPart")
        if not v142 or not v143 then
            return false
        end
        local v144 = v143.Position
        local v145 = v142.Position - v144
        local v146 = v145.Magnitude
        if v146 < 0.1 then
            return true
        end
        _G.Ox._V2RayParams.FilterDescendantsInstances = {a19, v141}
        local v147
        if workspace:Raycast(v144, v145.Unit * v146, _G.Ox._V2RayParams) then
            v147 = false
        else
            v147 = true
        end
        return v147
    end
    V2_IsBtnValid = function(a20)
        if not a20 or not a20.Parent then
            return false
        end
        local v150, v151 = pcall(function()
            if not a20:IsA("GuiButton") and not a20:IsA("ImageButton") and not a20:IsA("TextButton") then
                return false
            end
            if a20.Visible == false then
                return false
            end
            if a20.AbsoluteSize.X < 4 or a20.AbsoluteSize.Y < 4 then
                return false
            end
            local v148 = a20.Parent
            local v149 = v4:FindFirstChild("PlayerGui")
            while v148 and v148 ~= v149 do
                if v148:IsA("GuiObject") and v148.Visible == false then
                    return false
                end
                v148 = v148.Parent
            end
            return true
        end)
        local v152 = v150 and v151 == true
        return v152
    end
    V2_FindParryButton = function()
        local v153 = _G.Ox.ParryV2
        if v153.BtnCache and V2_IsBtnValid(v153.BtnCache) then
            return v153.BtnCache
        end
        local v154 = v4:FindFirstChild("PlayerGui")
        if not v154 then
            return nil
        end
        local v155, v156, v157 = ipairs({
            {"Survivor-mob", "Controls", "Gui-mob"},
            {"SurvivorMob", "Controls", "GuiMob"},
            {"Survivor-mob", "Controls", "GuiMob"},
        })
        local v158 = v157
        local v159 = v155
        local v160 = v156
        while true do
            local v161, v162 = v159(v160, v158)
            if v161 == nil then
                break
            end
            local v163 = v154
            for v170, v171 in ipairs(v162) do
                local v172 = v163 and v163:FindFirstChild(v171)
                v163 = v172
            end
            v158 = v161
            if v163 and V2_IsBtnValid(v163) then
                v153.BtnCache = v163
                return v163
            end
        end
        return nil
    end
    V2_TriggerByButton = function()
        local v173 = V2_FindParryButton()
        if not v173 then
            pcall(function()
                local v180 = v6:GetMouseLocation()
                v7:SendMouseButtonEvent(v180.X, v180.Y, 1, true, game, 0)
                task.delay(0.06, function()
                    local v181 = v6:GetMouseLocation()
                    v7:SendMouseButtonEvent(v181.X, v181.Y, 1, false, game, 0)
                end)
            end)
            return false
        end
        pcall(function()
            if type(firesignal) == "function" then
                firesignal(v173.MouseButton1Down)
                task.delay(0.06, function()
                    pcall(function()
                        firesignal(v173.MouseButton1Up)
                        if v173.MouseButton1Click then
                            firesignal(v173.MouseButton1Click)
                        end
                    end)
                end)
            else
                local v174 = v173.AbsolutePosition
                local v175 = v173.AbsoluteSize
                local v176 = v8:GetGuiInset()
                local v177 = v174.X + v175.X / 2 + v176.X
                local v178 = v174.Y + v175.Y / 2 + v176.Y
                local v179 = 9901 + math.random(1, 400)
                v7:SendTouchEvent(v179, 0, v177, v178)
                task.delay(0.06, function()
                    pcall(function()
                        v7:SendTouchEvent(v179, 2, v177, v178)
                    end)
                end)
            end
        end)
        return true
    end
    V2_SetIconsColor = function(a21)
        local v182 = _G.Ox.ParryV2
        if #v182.Gradients == 0 then
            if ParryHUD and ParryHUD.Scan then
                ParryHUD.Scan()
            end
            local v183 = ParryHUD
            local v184 = v183 and ParryHUD.gradients or {}
            v182.Gradients = v184
            local v185 = ParryHUD
            local v186 = v185 and ParryHUD.icon or nil
            v182.Icon = v186
        end
        for v191, v192 in ipairs(v182.Gradients) do
            if v192 and v192.Parent and v192.Parent.Parent then
                local v193 = v192.Parent.Parent:FindFirstChild("icon")
                if v193 then
                    v193.ImageColor3 = a21
                end
                local v194 = v192.Parent.Parent:FindFirstChild("Gui")
                if v194 then
                    v194.ImageColor3 = a21
                end
            end
        end
        if v182.Icon then
            v182.Icon.ImageColor3 = a21
        end
    end
    V2_PlayCooldownTween = function(a22)
        local v195 = _G.Ox.ParryV2
        if #v195.Gradients == 0 then
            if ParryHUD and ParryHUD.Scan then
                ParryHUD.Scan()
            end
            local v196 = ParryHUD
            local v197 = v196 and ParryHUD.gradients or {}
            v195.Gradients = v197
        end
        for v202, v203 in ipairs(v195.Gradients) do
            if v203 and v203.Parent then
                v203.Offset = Vector2.new(0, 0.75)
                local v204 = v15:Create(v203, TweenInfo.new(a22, Enum.EasingStyle.Linear), {Offset = Vector2.new(0, 0.25)})
                v204:Play()
                v204.Completed:Connect(function()
                    if not v195.IsOnCooldown then
                        V2_SetIconsColor(Color3.fromRGB(255, 255, 255))
                    end
                end)
            end
        end
    end
    V2_StartCooldown = function(a23)
        local v205 = _G.Ox.ParryV2
        v205.CooldownToken = v205.CooldownToken + 1
        local v206 = v205.CooldownToken
        v205.IsResolving = false
        v205.IsOnCooldown = true
        V2_SetIconsColor(Color3.fromRGB(77, 77, 77))
        V2_PlayCooldownTween(a23)
        if v205.CooldownThread then
            task.cancel(v205.CooldownThread)
        end
        v205.CooldownThread = task.delay(a23, function()
            if v205.CooldownToken == v206 then
                v205.IsOnCooldown = false
                V2_SetIconsColor(Color3.fromRGB(255, 255, 255))
                v205.CooldownThread = nil
            end
        end)
    end
    V2_ResetCooldown = function()
        local v207 = _G.Ox.ParryV2
        if v207.CooldownThread then
            task.cancel(v207.CooldownThread)
            v207.CooldownThread = nil
        end
        v207.IsOnCooldown = false
        v207.IsResolving = false
        V2_SetIconsColor(Color3.fromRGB(255, 255, 255))
    end
    V2_FaceLookDirection = function()
        local v208 = workspace.CurrentCamera
        if not v208 then
            return
        end
        local v209 = v4.Character
        local v210 = v209 and v4.Character:FindFirstChild("HumanoidRootPart")
        if not v210 or not v210.Parent then
            return
        end
        local v211 = v4.Character
        local v212 = v211 and v4.Character:FindFirstChildOfClass("Humanoid")
        local v213 = v208.CFrame.LookVector
        local v214 = Vector3.new(v213.X, 0, v213.Z)
        if v214.Magnitude <= 0 then
            return
        end
        local v215 = CFrame.new(v210.Position, v210.Position + v214.Unit)
        v15:Create(v210, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {CFrame = v215}):Play()
        if v212 then
            v212.AutoRotate = false
        end
        local v216 = _G.Ox.ParryV2
        if v216.LockConnection then
            v216.LockConnection:Disconnect()
        end
        local v217 = tick()
        v216.LockConnection = v5.Heartbeat:Connect(function()
            if tick() - v217 >= 0.8 then
                if v216.LockConnection then
                    v216.LockConnection:Disconnect()
                    v216.LockConnection = nil
                end
                if v212 then
                    v212.AutoRotate = true
                end
                return
            end
            if v210 and v210.Parent then
                v210.CFrame = CFrame.new(v210.Position, v210.Position + v214.Unit)
            elseif v216.LockConnection then
                v216.LockConnection:Disconnect()
                v216.LockConnection = nil
            end
        end)
    end
    V2_MatchParrySkin = function(a24)
        if type(a24) ~= "string" or a24 == "" then
            return nil
        end
        local v218 = _G.Ox.ParryV2Anim
        if not v218 then
            return nil
        end
        if v218[a24] then
            return v218[a24]
        end
        local v219 = string.lower(a24):gsub("^equippedskin[_%-]?", ""):gsub("^skin[_%-]?", ""):gsub("[_%-]?parrying[_%-]?dagger", ""):gsub("[_%-]?dagger", ""):gsub("%s+", "")
        for v224, v225 in pairs(v218) do
            local v226 = string.lower(v224)
            if v226 == v219 or string.find(v219, v226, 1, true) or string.find(v226, v219, 1, true) then
                return v225
            end
        end
        return nil
    end
    V2_ScanSkinFromInstance = function(a25)
        if not a25 then
            return nil
        end
        for v231, v232 in ipairs({
            "EquippedSkin_Parrying_Dagger",
            "EquippedSkin_ParryingDagger",
            "EquippedSkin",
            "ParryingDaggerSkin",
            "ParrySkin",
            "Skin",
            "SkinName",
            "CurrentSkin",
            "EquippedSkinName",
        }) do
            local v233 = a25:GetAttribute(v232)
            local v234 = V2_MatchParrySkin(v233)
            if v234 then
                return v234
            end
        end
        local v235, v236 = pcall(function()
            return a25:GetAttributes()
        end)
        if v235 and type(v236) == "table" then
            for v241, v242 in pairs(v236) do
                if type(v241) == "string" and type(v242) == "string" then
                    local v243 = string.lower(v241)
                    if not v243:find("skin") and not v243:find("parry") then
                        continue
                    end
                    local v244 = V2_MatchParrySkin(v242)
                    if v244 then
                        return v244
                    end
                end
            end
        end
        return nil
    end
    V2_ResolveAnimId = function()
        local v245 = v4.Character
        if v245 then
            local v246 = V2_ScanSkinFromInstance(v245)
            if v246 then
                return v246
            end
            local v247 = v245:FindFirstChild("Parrying Dagger")
            local v248 = v247 or v245:FindFirstChild("ParryingDagger") or v245:FindFirstChild("parrying dagger")
            if v248 then
                local v249 = V2_ScanSkinFromInstance(v248)
                if v249 then
                    return v249
                end
                for v254, v255 in ipairs(v248:GetDescendants()) do
                    if not v255:IsA("StringValue") and (not v255:IsA("ValueBase") or type(v255.Value) ~= "string") then
                        continue
                    end
                    local v256 = V2_MatchParrySkin(tostring(v255.Value))
                    if v256 then
                        return v256
                    end
                end
            end
            local v257 = v4:FindFirstChild("Backpack")
            if v257 then
                local v258 = v257:FindFirstChild("Parrying Dagger")
                local v259 = v258 or v257:FindFirstChild("ParryingDagger")
                if v259 then
                    local v260 = V2_ScanSkinFromInstance(v259)
                    if v260 then
                        return v260
                    end
                end
            end
        end
        local v261 = V2_ScanSkinFromInstance(v4)
        if not v261 then
            return _G.Ox.ParryV2Anim.Default
        end
        return v261
    end
    V2_PlayParryAnim = function()
        local v262 = v4.Character
        local v263 = v262 and v262:FindFirstChildOfClass("Humanoid")
        local v264 = v263 and v263:FindFirstChildOfClass("Animator")
        if not v264 then
            return
        end
        local v265 = _G.Ox.ParryV2
        if v265.ParryTrack then
            pcall(function()
                v265.ParryTrack:Stop(0.05)
            end)
        end
        pcall(function()
            local v266 = Instance.new("Animation")
            v266.AnimationId = V2_ResolveAnimId()
            v265.ParryTrack = v264:LoadAnimation(v266)
            v265.ParryTrack.Priority = Enum.AnimationPriority.Action4
            v265.ParryTrack:Play()
        end)
    end
    V2_DoParry = function()
        if not V2_CanParry() then
            return
        end
        local v267 = _G.Ox.ParryV2
        v267.IsResolving = true
        V2_SetIconsColor(Color3.fromRGB(77, 77, 77))
        local v268 = v267.Trigger
        local v269 = v268 or "Remote"
        local v270 = v9:FindFirstChild("Remotes")
        if v269 == "Button" then
            V2_TriggerByButton()
        else
            local v271 = v270 and v270:FindFirstChild("Items") and v270.Items:FindFirstChild("Parrying Dagger")
            local v272 = v271 and v271:FindFirstChild("parry")
            if v272 then
                pcall(function()
                    v272:FireServer()
                end)
            end
            V2_FaceLookDirection()
            local v273 = v4.Character
            local v274 = v273 and v4.Character:FindFirstChildOfClass("Humanoid")
            if v274 then
                v274.AutoRotate = false
            end
            V2_PlayParryAnim()
            local v275 = v4.Character
            local v276 = v275 and v4.Character:FindFirstChild("HumanoidRootPart")
            if v276 then
                pcall(function()
                    v13:AddTag(v276, "doing action")
                end)
            end
            local v277 = v270 and v270:FindFirstChild("Mechanics") and v270.Mechanics:FindFirstChild("Slow")
            if v277 then
                pcall(function()
                    v277:Fire(0, 1, 0)
                end)
            end
        end
        task.delay(2, function()
            if v267.IsResolving then
                v267.IsResolving = false
                local v278 = v267.Trigger == "Button" and 1.2 or 60
                V2_StartCooldown(v278)
                local v279 = v4.Character
                local v280 = v279 and v4.Character:FindFirstChild("HumanoidRootPart")
                if v280 then
                    pcall(function()
                        v13:RemoveTag(v280, "doing action")
                    end)
                end
            end
        end)
    end
    task.spawn(function()
        local v281 = v9:WaitForChild("Remotes", 8)
        local v282 = v281 and v281:WaitForChild("Items", 5)
        local v283 = v282 and v282:WaitForChild("Parrying Dagger", 5)
        local v284 = v283 and v283:WaitForChild("parryResult", 5)
        if not v284 then
            return
        end
        v284.OnClientEvent:Connect(function(a26, a27)
            local v285 = _G.Ox.ParryV2
            if not v285.IsResolving then
                return
            end
            v285.IsResolving = false
            local v286 = tonumber(a27)
            if v286 and v286 > 0 then
                V2_StartCooldown(v286)
            elseif a26 == true then
                V2_StartCooldown(90)
            else
                V2_StartCooldown(60)
            end
            local v287 = v4.Character
            local v288 = v287 and v4.Character:FindFirstChild("HumanoidRootPart")
            if v288 then
                pcall(function()
                    v13:RemoveTag(v288, "doing action")
                end)
            end
        end)
    end)
    local v289 = Instance.new("CylinderHandleAdornment")
    v289.Name = "FEBZTZY_ParryRange_V2"
    local v290 = _G.Ox.ParryV2.Range
    local v291 = v290 or 12
    v289.Radius = v291
    local v292 = math.max
    local v293 = _G.Ox.ParryV2.Range
    local v294 = v293 or 12
    v289.InnerRadius = v292(0.1, v294 - 0.15)
    v289.Height = 0.01
    v289.Color3 = Color3.fromRGB(80, 80, 80)
    v289.AlwaysOnTop = false
    v289.Transparency = 1
    v289.Adornee = workspace:FindFirstChildOfClass("Terrain")
    pcall(function()
        v289.Parent = v10
    end)
    if not v289.Parent then
        pcall(function()
            v289.Parent = v4:WaitForChild("PlayerGui")
        end)
    end
    _G.Ox.ParryV2.RangeAdornment = v289
    V2_UpdateRangeCircle = function()
        local v295 = _G.Ox.ParryV2
        local v296 = v295.RangeAdornment
        if not v296 then
            return
        end
        if v295.Enabled and v295.ShowCircle then
            local v297 = v4.Character
            local v298 = v297 and v297:FindFirstChild("HumanoidRootPart")
            if not v298 then
                if v296.Transparency ~= 1 then
                    v296.Transparency = 1
                end
                return
            end
            local v299 = v295.Range
            local v300 = v299 or 12
            if v298 == _G.Ox._V2ParryLastRoot and v300 == _G.Ox._V2ParryLastRadius then
                return
            end
            _G.Ox._V2ParryLastRoot = v298
            _G.Ox._V2ParryLastRadius = v300
            v296.Transparency = 0.4
            v296.Radius = v300
            v296.InnerRadius = math.max(0.1, v300 - 0.15)
            local v301 = _G.Ox._V2ParryRangeRay
            v301.FilterDescendantsInstances = {v297}
            local v302 = workspace:Raycast(v298.Position, Vector3.new(0, -15, 0), v301)
            local v303 = v302 and v302.Position or v298.Position - Vector3.new(0, 3, 0)
            v296.CFrame = CFrame.new(v303 + Vector3.new(0, 0.05, 0)) * CFrame.Angles(math.pi / 2, 0, 0)
            return
        end
        if v296.Transparency ~= 1 then
            v296.Transparency = 1
        end
    end
    V2_AttachParrySensor = function(a28)
        if not a28 or _G.Ox.ParryV2.Attached[a28] then
            return
        end
        _G.Ox.ParryV2.Attached[a28] = true
        local v304 = a28:FindFirstChild("Humanoid")
        local v305 = v304
        if not v304 then
            local v306 = a28:WaitForChild("Humanoid", 5)
            v305 = v306
            if not v306 then
                return
            end
        end
        local v307 = v305:FindFirstChildOfClass("Animator")
        local v308 = v307
        if not v307 then
            local v309 = v305:WaitForChild("Animator", 5)
            v308 = v309
            if not v309 then
                return
            end
        end
        v305.ChildAdded:Connect(function(a29)
            if a29:IsA("Animator") then
                _G.Ox.ParryV2.Attached[a28] = nil
                V2_AttachParrySensor(a28)
            end
        end)
        a28.AncestryChanged:Connect(function(a30, a31)
            if not a31 then
                _G.Ox.ParryV2.Attached[a28] = nil
            end
        end)
        v308.AnimationPlayed:Connect(function(a32)
            local v310 = a32.Animation
            local v311 = v310 and a32.Animation.AnimationId or ""
            if not _G.Ox.ParryV2AttackAnims[v311] then
                return
            end
            local v312 = _G.Ox.ParryV2
            if not v312.Enabled then
                return
            end
            if not V2_HasParryingDagger() then
                return
            end
            if v312.IsOnCooldown or v312.IsResolving then
                return
            end
            local v313 = v4.Character
            if not v313 then
                return
            end
            local v314 = v313:FindFirstChild("HumanoidRootPart")
            local v315 = a28:FindFirstChild("HumanoidRootPart")
            if not v314 or not v315 then
                return
            end
            local v316 = (v314.Position - v315.Position).Magnitude
            local v317 = v312.Mode
            local v318 = v317 or "Legit"
            local v319 = v312.Range
            local v320 = v319 or 12
            if v318 == "Aggressive" then
                if v320 + 3 < v316 then
                    return
                end
                local v330 = tonumber(v312.KillerFace)
                local v331 = v330 or 0.6
                local v332 = math.clamp(v331, -1, 1)
                local v338 = function()
                    local v333 = v314.Position - v315.Position
                    local v334 = Vector3.new(v333.X, 0, v333.Z)
                    if v334.Magnitude < 0.05 then
                        return true
                    end
                    local v335 = Vector3.new(v315.CFrame.LookVector.X, 0, v315.CFrame.LookVector.Z)
                    if v335.Magnitude < 0.05 then
                        return false
                    end
                    local v336 = v335.Unit:Dot(v334.Unit)
                    local v337 = v332 <= v336
                    return v337
                end
                local v339 = function()
                    if v312.IsOnCooldown or v312.IsResolving or not v314 or not v315 or not v314.Parent or not v315.Parent then
                        return true
                    end
                    if (v314.Position - v315.Position).Magnitude > v320 or not v338() then
                        return false
                    end
                    V2_DoParry()
                    return true
                end
                if v339() then
                    return
                end
                local v340 = nil
                local v341 = os.clock()
                v340 = v5.Heartbeat:Connect(function()
                    if (os.clock() - v341 >= 1.5 or v339()) and v340 then
                        v340:Disconnect()
                    end
                end)
            else
                if v320 < v316 then
                    return
                end
                if not V2_HasLOS(a28) then
                    return
                end
                local v321 = Vector3.new(v314.Position.X, 0, v314.Position.Z) - Vector3.new(v315.Position.X, 0, v315.Position.Z)
                if v321.Magnitude > 0 then
                    local v322 = v321.Unit
                    local v323 = Vector3.new(v315.CFrame.LookVector.X, 0, v315.CFrame.LookVector.Z)
                    if v323.Magnitude > 0 then
                        local v324 = v323.Unit
                        local v325 = tonumber(v312.KillerFace)
                        local v326 = v325 or 0.6
                        local v327 = math.clamp(v326, -1, 1)
                        if v324:Dot(v322) < v327 then
                            return
                        end
                    end
                    if v318 == "Strict" then
                        local v328 = workspace.CurrentCamera
                        local v329 = nil
                        if v328 then
                            v329 = Vector3.new(v328.CFrame.LookVector.X, 0, v328.CFrame.LookVector.Z)
                        end
                        if not v329 or v329.Magnitude < 0.05 then
                            v329 = Vector3.new(v314.CFrame.LookVector.X, 0, v314.CFrame.LookVector.Z)
                        end
                        if v329.Magnitude > 0 and v329.Unit:Dot(-v322) < 0.5 then
                            return
                        end
                    end
                end
                V2_DoParry()
            end
        end)
    end
    V2_TryAttach = function(a33)
        if a33 ~= v4 and a33.Team and a33.Team.Name == "Killer" and a33.Character then
            V2_AttachParrySensor(a33.Character)
        end
    end
    V2_SetupPlayer = function(a34)
        if a34 == v4 then
            return
        end
        a34.CharacterAdded:Connect(function()
            V2_TryAttach(a34)
        end)
        a34:GetPropertyChangedSignal("Team"):Connect(function()
            V2_TryAttach(a34)
        end)
        if a34.Character then
            V2_TryAttach(a34)
        end
    end
    for v346, v347 in pairs(v3:GetPlayers()) do
        V2_SetupPlayer(v347)
    end
    v3.PlayerAdded:Connect(V2_SetupPlayer)
    v5.Heartbeat:Connect(function()
        if _G.Ox.ParryV2 and _G.Ox.ParryV2.Enabled and _G.Ox.ParryV2.ShowCircle then
            _G.Ox._V2ParryLastRoot = nil
            V2_UpdateRangeCircle()
        elseif _G.Ox.ParryV2 and _G.Ox.ParryV2.RangeAdornment and _G.Ox.ParryV2.RangeAdornment.Transparency ~= 1 then
            _G.Ox.ParryV2.RangeAdornment.Transparency = 1
        end
    end)
    UpdateCustomParryGUI = function(a35)
        if not _G.Ox.AutoParryCustom.Gui then
            return
        end
        local v348 = _G.Ox.AutoParryCustom.Gui:FindFirstChild("Frame")
        if not v348 then
            return
        end
        local v349 = v348:FindFirstChild("ActionButton")
        local v350 = v348:FindFirstChild("UIStroke")
        if a35 then
            if v349 then
                v349.Text = "PARRY [ON]"
                v349.TextColor3 = Color3.fromRGB(180, 255, 180)
                v349.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            end
            if v350 then
                v350.Color = Color3.fromRGB(100, 200, 100)
            end
        else
            if v349 then
                v349.Text = "PARRY [OFF]"
                v349.TextColor3 = Color3.fromRGB(200, 200, 200)
                v349.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            end
            if v350 then
                v350.Color = Color3.fromRGB(90, 90, 95)
            end
        end
    end
    ToggleParryStatus = function()
        local v351 = _G.Ox.ParryConfig
        local v352
        if _G.Ox.ParryConfig.AutoParry then
            v352 = false
        else
            v352 = true
        end
        v351.AutoParry = v352
        _G.Ox.AutoParryCustom.IsActive = _G.Ox.ParryConfig.AutoParry
        UpdateCustomParryGUI(_G.Ox.ParryConfig.AutoParry)
        local v353 = v1.Notify
        local v354 = {Title = "Auto Parry"}
        local v355 = _G.Ox.ParryConfig.AutoParry
        local v356 = v355 and "Aktif" or "Nonaktif"
        v354.Description = v356
        v354.Duration = 2
        v353(v1, v354)
    end
    CreateCustomParryGUI = function()
        if _G.Ox.AutoParryCustom.Gui then
            _G.Ox.AutoParryCustom.Gui:Destroy()
        end
        local v357 = Instance.new("ScreenGui")
        v357.Name = "AutoParryCustomGui"
        v357.ResetOnSpawn = false
        v357.IgnoreGuiInset = true
        v357.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        v357.Parent = v10
        v357.Enabled = false
        _G.Ox.AutoParryCustom.Gui = v357
        _G.Ox.AutoParryCustom.GuiVisible = false
        local v358 = Instance.new("Frame", v357)
        v358.Name = "Frame"
        v358.Size = UDim2.fromOffset(110, 36)
        v358.Position = UDim2.fromScale(0.85, 0.35)
        v358.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        v358.BackgroundTransparency = 0.1
        v358.Active = true
        v358.BorderSizePixel = 0
        Instance.new("UICorner", v358).CornerRadius = UDim.new(0, 8)
        local v359 = Instance.new("UIStroke", v358)
        v359.Name = "UIStroke"
        v359.Color = Color3.fromRGB(90, 90, 95)
        v359.Thickness = 1.5
        v359.Transparency = 0.2
        local v360 = Instance.new("TextButton", v358)
        v360.Name = "ActionButton"
        v360.Size = UDim2.new(1, 0, 1, 0)
        v360.Text = "PARRY [OFF]"
        v360.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        v360.Font = Enum.Font.GothamBold
        v360.TextSize = 12
        v360.TextColor3 = Color3.fromRGB(200, 200, 200)
        v360.BorderSizePixel = 0
        v360.AutoButtonColor = false
        Instance.new("UICorner", v360).CornerRadius = UDim.new(0, 8)
        local v361 = false
        local v362 = false
        local v363 = false
        local v364 = nil
        local v365 = nil
        local v366 = nil
        update = function(a36)
            if not v361 or not v363 or not v364 or not v365 then
                return
            end
            local v367 = a36.Position - v364
            if not v362 and (math.abs(v367.X) > 18 or math.abs(v367.Y) > 18) then
                v362 = true
            end
            if v362 then
                v358.Position = UDim2.new(v365.X.Scale, v365.X.Offset + v367.X, v365.Y.Scale, v365.Y.Offset + v367.Y)
            end
        end
        v360.InputBegan:Connect(function(a37)
            if a37.UserInputType == Enum.UserInputType.MouseButton1 or a37.UserInputType == Enum.UserInputType.Touch then
                v361 = true
                v362 = false
                v363 = false
                v364 = a37.Position
                v365 = v358.Position
                if v366 then
                    task.cancel(v366)
                end
                v366 = task.delay(0.18, function()
                    if v361 then
                        v363 = true
                    end
                end)
            end
        end)
        v360.InputEnded:Connect(function(a38)
            if a38.UserInputType == Enum.UserInputType.MouseButton1 or a38.UserInputType == Enum.UserInputType.Touch then
                if v366 then
                    task.cancel(v366)
                end
                if v361 and not v362 then
                    ToggleParryStatus()
                end
                v361 = false
                v362 = false
                v363 = false
                v364 = nil
                v365 = nil
            end
        end)
        v6.InputChanged:Connect(function(a39)
            if v361 and v363 and (a39.UserInputType == Enum.UserInputType.MouseMovement or a39.UserInputType == Enum.UserInputType.Touch) then
                update(a39)
            end
        end)
        if _G.Ox.AutoParryCustom._statusConn then
            _G.Ox.AutoParryCustom._statusConn:Disconnect()
        end
        _G.Ox.AutoParryCustom._statusConn = v5.Heartbeat:Connect(function()
            if _G.Ox.AutoParryCustom.Gui and _G.Ox.AutoParryCustom.Gui.Parent then
                if _G.Ox.AutoParryCustom.IsActive ~= _G.Ox.ParryConfig.AutoParry then
                    _G.Ox.AutoParryCustom.IsActive = _G.Ox.ParryConfig.AutoParry
                    UpdateCustomParryGUI(_G.Ox.ParryConfig.AutoParry)
                end
                return
            end
            if _G.Ox.AutoParryCustom._statusConn then
                _G.Ox.AutoParryCustom._statusConn:Disconnect()
            end
        end)
    end
    v4.CharacterAdded:Connect(function()
        task.wait(1)
        if _G.Ox.AutoParryCustom.GuiVisible and _G.Ox.AutoParryCustom.Gui then
            _G.Ox.AutoParryCustom.Gui.Enabled = true
            UpdateCustomParryGUI(_G.Ox.ParryConfig.AutoParry)
        end
    end)
    task.spawn(function()
        task.wait(1.5)
        CreateCustomParryGUI()
    end)
    _G.Ox.InstantTPGate = {
        Enabled = false,
        GateClientModule = nil,
        oldGateNew = nil,
        oldGateCanUse = nil,
    }
    _G.Ox.KorlessMorph = {Enabled = false, Connection = nil}
    _G.Ox.SelfHeal = {Enabled = false}
    _G.Ox.FlowstateNoCD = {Enabled = false, Connection = nil, CharAddedConn = nil}
    _G.Ox.NoFall = {Enabled = false}
    _G.Ox.BulletBlockConfig = {Enabled = false}
    _G.Ox.BypassGate = {Enabled = false}
    _G.Ox.NextKiller = {Enabled = false, IndicatorGui = nil}
    _G.Ox.CounterParry = {
        Enabled = false,
        Distance = 15,
        Interval = 0.3,
        AnimId = "rbxassetid://117042998468241",
        Thread = nil,
        Track = nil,
    }
    _G.Ox.AutoStalk = {Enabled = false, Range = 150, Conn = nil, LastFire = 0}
    _G.Ox.Crosshair = {
        Enabled = false,
        Size = 8,
        Thickness = 2,
        Color = Color3.fromRGB(255, 255, 255),
        Style = "Dot",
        OffsetX = 0,
        OffsetY = 0,
    }
    _G.Ox.Spectator = {Enabled = false, Gui = nil, Label = nil}
    _G.Ox.Moonwalk = {
        Enabled = false,
        GuiVisible = false,
        Gui = nil,
        IsActive = false,
    }
    _G.Ox.CrosshairGui = nil
    _G.Ox.CrosshairElements = {}
    _G.Ox.CrosshairCreated = false
    _G.Ox.LastCrosshairStyle = nil
    local v368 = _G.Ox
    local v369 = _G.Ox.Config
    local v370 = v369 or {}
    v368.Config = v370
    _G.Ox.Config.Surv_PerfectVault = false
    _G.Ox.autoVaultEnabled = false
    _G.Ox.autoPalletSlideEnabled = false
    _G.Ox.lastActionTime = 0
    _G.Ox.COOLDOWN = 1.5
    _G.Ox.StreamerMode = {Enabled = false, SpooferConns = {}}
    _G.Ox.InfinityZoom = {Enabled = false}
    _G.Ox.StretchRes = {Enabled = false, Amount = 0.67, Conn = nil}
    _G.Ox.CameraFOV = {Enabled = false, Value = 90, Connection = nil}
    _G.Ox.Auto = {SkillCheck = false, SkillCheckMode = "Legit"}
    _G.Ox.MapPredict = {Enabled = false}
    _G.Ox.KillerPerks = {Enabled = false, Gui = nil, Minimized = false}
    _G.Ox.Stun = {
        Enabled = false,
        Data = {},
        HitSoundEnabled = false,
        HitSoundVolume = 1,
        HitSoundId = "rbxassetid://106225491596534",
        HitSoundCooldown = 0.3,
        HitSoundLastTime = 0,
    }
    _G.Ox.GodMode = false
    _G.Ox.BypassGenEnabled = false
    _G.Ox.BypassGenMode = "Manual Repair"
    _G.Ox.RepairAnimTrack = nil
    _G.Ox.ProcessedGens = {}
    _G.Ox.AutoRepairEnabled = false
    _G.Ox.AutoRepairThread = nil
    _G.Ox.AutoCurrentPoint = nil
    _G.Ox.AutoCurrentGenModel = nil
    _G.Ox.LastFireTime = 0
    _G.Ox.AutoFireInterval = 0.5
    _G.Ox.ScriptAlive = true
    _G.Ox.BypassToggleValue = false
    _G.Ox.UnlimitedVaultEnabled = false
    local v371 = _G.Ox
    local v372 = _G.Ox.State
    local v373 = v372 or {}
    v371.State = v373
    _G.Ox.State.busy = false
    _G.Ox.State.RandomMode_IsNormal = false
    _G.Ox.Connections = {SkillHeartbeat = nil}
    _G.Ox.Speed = {Enabled = false, Value = 0.1, Connection = nil, Loop = nil}
    _G.Ox.AutoRun = {PC = false, Mobile = false, MobileThread = nil}
    _G.Ox.Utility = {
        InvisEnabled = false,
        BandageEnabled = false,
        BandageSpeed = 50,
    }
    _G.Ox.AntiHook = {
        Enabled = false,
        OffsetY = -250,
        Hz = 44,
        Interval = 0.022727272727272728,
        Remote = nil,
        Connection = nil,
        Accumulator = 0,
        SendCounter = 0,
        LastCounterTime = os.clock(),
    }
    _G.Ox.ConfigData = {Surv_SkillFrequency = 10, Surv_SkillSpeed = 1}
    _G.Ox.Teleport = {
        GenIndex = 1,
        HookIndex = 1,
        GateIndex = 1,
        PalletIndex = 1,
        WindowIndex = 1,
    }
    v374 = {
        Generators = {},
        Hooks = {},
        Gates = {},
        Pallets = {},
        Windows = {},
    }
    v375 = {Enabled = false, Conn = nil}
    if not _G.Ox.State then
        _G.Ox.State = {}
    end
    _G.Ox.State.ThirdPersonConn = nil
    v376 = {
        ["Left Arm"] = true,
        ["Right Arm"] = true,
        LeftHand = true,
        RightHand = true,
        LeftLowerArm = true,
        RightLowerArm = true,
        LeftUpperArm = true,
        RightUpperArm = true,
    }
    _G.Ox.FakePerks = {
        QuickRecoveryEnabled = false,
        PerfectLandingEnabled = false,
        FlowstateEnabled = false,
        FakeAdrenalineRush = false,
        PerkCooldown = 10,
        boostActive = false,
        perfectLandingBoostActive = false,
        fsOnCooldown = false,
        lastQRTime = 0,
        lastPLTime = 0,
        lastFSTime = 0,
        qrConnection = nil,
        plConnection = nil,
        fsConnection = nil,
        fsAnimConnection = nil,
        adrenalineOn = false,
        adrenalineConns = {},
        lastARTime = 0,
    }
    _G.Ox.AutoPallet = {
        Enabled = false,
        Safety = true,
        Distance = 10,
        Cooldown = 2.5,
        LastDrop = 0,
        UsedPallets = {},
        Connection = nil,
    }
    _G.Ox.FullBright = false
    _G.Ox.NoFog = false
    _G.Ox.NoShadow = false
    _G.Ox.TimeOfDayValue = 14
    _G.Ox.LowGFX = {
        Enabled = false,
        Textures = true,
        VisualEffects = true,
        Particles = true,
        Parts = true,
        Sky = false,
        Saved = {},
    }
    _G.Ox.AimConfig = {
        Aim_SilentVeilV2 = false,
        Veil_ShowFOV = true,
        SpearSmart_enable = false,
        Veil_FOV = 150,
        SPEAR_Speed = 165,
        SPEAR_Gravity = 103,
        SPEAR_AuraSpeed = 165,
        SPEAR_AuraGravity = 96.5,
        SPEAR_MaxDist = 500,
        Veil_LeadMultiplier = 1.4,
        AIM_TargetPart = "Torso",
        Pistol_BlockKnocked = false,
        LockAim = false,
        Flash_Silent = false,
        Flash_YOffset = 1.5,
    }
    _G.Ox.SurvivorFOVFrame = nil
    _G.Ox.SurvivorFOVGui = nil
    _G.Ox.isAimbotHolding = false
    _G.Ox.lockedAimbotTarget = nil
    _G.Ox.survivorAimbotHighlight = nil
    _G.Ox.isKillerAimbotHolding = false
    _G.Ox.lockedKillerAimbotTarget = nil
    _G.Ox.killerAimbotHighlight = nil
    _G.Ox.Config = {
        SpearSmart_enable = false,
        Surv_Aimbot_Enabled = false,
        Surv_Aimbot_ShowFOV = true,
        Surv_Aimbot_Radius = 150,
        Surv_Aimbot_MaxDist = 300,
        Surv_Aimbot_Smoothness = 0.5,
        Surv_Aimbot_Predict = 0.01,
        Killer_Aimbot_Enabled = false,
        Killer_Aimbot_MaxDist = 12,
        Killer_Aimbot_Smoothness = 0.5,
    }
    local v377 = false
    local v378 = false
    v379 = false
    _G.Ox.ESPConfig = {
        Master = false,
        Player = false,
        Killer = false,
        Outline = false,
        Name = false,
        Distance = false,
        KillerWarn = false,
        ItemIcon = false,
        Generator = false,
        GeneratorName = true,
        Pallet = false,
        Hook = false,
        Gate = false,
        Window = false,
        SCP = false,
        HookCount = false,
        Status = false,
        MaxDistance = 1000,
    }
    _G.Ox.ESPColors = {
        Player = Color3.fromRGB(60, 255, 60),
        Killer = Color3.fromRGB(255, 60, 60),
        Generator = Color3.fromRGB(255, 255, 0),
        GeneratorDone = Color3.fromRGB(0, 255, 0),
        Pallet = Color3.fromRGB(60, 255, 255),
        Hook = Color3.fromRGB(255, 105, 180),
        Gate = Color3.fromRGB(255, 255, 255),
        Window = Color3.fromRGB(60, 255, 255),
        SCP = Color3.fromRGB(255, 0, 255),
        Injured = Color3.fromRGB(255, 140, 0),
        Downed = Color3.fromRGB(255, 40, 40),
        Hooked = Color3.fromRGB(240, 240, 255),
    }
    v380 = {
        Generators = {},
        Windows = {},
        Pallets = {},
        Hooks = {},
        Gates = {},
        SCPs = {},
    }
    GetRole = function()
        if not v4.Team then
            return "Unknown"
        end
        local v381 = v4.Team.Name
        if v381 == "Killer" then
            return "Killer"
        end
        if v381 == "Survivors" then
            return "Survivor"
        end
        return "Spectator"
    end
    GetDistance = function(a40)
        local v382 = v4.Character
        local v383 = v382 and v4.Character:FindFirstChild("HumanoidRootPart")
        if not v383 then
            return math.huge
        end
        return (a40 - v383.Position).Magnitude
    end
    v384 = function(a41, a42)
        if a41 and type(a41.SetValue) == "function" then
            pcall(function()
                a41:SetValue(a42)
            end)
        end
    end
    ClearCrosshair = function()
        if _G.Ox.CrosshairGui then
            _G.Ox.CrosshairGui:Destroy()
            _G.Ox.CrosshairGui = nil
        end
        _G.Ox.CrosshairElements = {}
        _G.Ox.CrosshairCreated = false
        _G.Ox.LastCrosshairStyle = nil
    end
    DrawCrosshair = function()
        if not _G.Ox.Crosshair.Enabled then
            if _G.Ox.CrosshairGui then
                _G.Ox.CrosshairGui.Enabled = false
            end
            return
        end
        if _G.Ox.CrosshairGui then
            _G.Ox.CrosshairGui.Enabled = true
        end
        if _G.Ox.LastCrosshairStyle ~= _G.Ox.Crosshair.Style or not _G.Ox.CrosshairGui then
            ClearCrosshair()
            _G.Ox.LastCrosshairStyle = _G.Ox.Crosshair.Style
        end
        if not _G.Ox.CrosshairCreated then
            _G.Ox.CrosshairCreated = true
            _G.Ox.CrosshairGui = Instance.new("ScreenGui")
            _G.Ox.CrosshairGui.Name = "CrosshairUI"
            _G.Ox.CrosshairGui.IgnoreGuiInset = true
            _G.Ox.CrosshairGui.ResetOnSpawn = false
            _G.Ox.CrosshairGui.DisplayOrder = 999
            _G.Ox.CrosshairGui.Parent = v10
            local v386 = function(a43, a44)
                local v385 = Instance.new("Frame")
                v385.BackgroundColor3 = _G.Ox.Crosshair.Color
                v385.BorderSizePixel = 0
                v385.AnchorPoint = Vector2.new(0.5, 0.5)
                v385.Size = a43
                v385.Position = a44
                v385.Parent = _G.Ox.CrosshairGui
                return v385
            end
            local v387 = UDim2.new(0.5, _G.Ox.Crosshair.OffsetX, 0.5, _G.Ox.Crosshair.OffsetY)
            if _G.Ox.Crosshair.Style == "Plus" then
                _G.Ox.CrosshairElements[1] = v386(UDim2.new(0, _G.Ox.Crosshair.Size * 2, 0, _G.Ox.Crosshair.Thickness), v387)
                _G.Ox.CrosshairElements[2] = v386(UDim2.new(0, _G.Ox.Crosshair.Thickness, 0, _G.Ox.Crosshair.Size * 2), v387)
            elseif _G.Ox.Crosshair.Style == "Dot" then
                local v390 = Instance.new("Frame")
                v390.BackgroundColor3 = _G.Ox.Crosshair.Color
                v390.BorderSizePixel = 0
                v390.AnchorPoint = Vector2.new(0.5, 0.5)
                v390.Size = UDim2.new(0, _G.Ox.Crosshair.Size, 0, _G.Ox.Crosshair.Size)
                v390.Position = v387
                Instance.new("UICorner", v390).CornerRadius = UDim.new(1, 0)
                v390.Parent = _G.Ox.CrosshairGui
                _G.Ox.CrosshairElements[1] = v390
            elseif _G.Ox.Crosshair.Style == "Circle" then
                local v388 = Instance.new("Frame")
                v388.BackgroundTransparency = 1
                v388.BorderSizePixel = 0
                v388.AnchorPoint = Vector2.new(0.5, 0.5)
                v388.Size = UDim2.new(0, _G.Ox.Crosshair.Size * 2, 0, _G.Ox.Crosshair.Size * 2)
                v388.Position = v387
                v388.Parent = _G.Ox.CrosshairGui
                local v389 = Instance.new("UIStroke")
                v389.Color = _G.Ox.Crosshair.Color
                v389.Thickness = _G.Ox.Crosshair.Thickness
                v389.Parent = v388
                Instance.new("UICorner", v388).CornerRadius = UDim.new(1, 0)
                _G.Ox.CrosshairElements[1] = v388
            end
        end
        local v391 = UDim2.new(0.5, _G.Ox.Crosshair.OffsetX, 0.5, _G.Ox.Crosshair.OffsetY)
        if _G.Ox.Crosshair.Style == "Plus" then
            if _G.Ox.CrosshairElements[1] then
                _G.Ox.CrosshairElements[1].Size = UDim2.new(0, _G.Ox.Crosshair.Size * 2, 0, _G.Ox.Crosshair.Thickness)
                _G.Ox.CrosshairElements[1].Position = v391
                _G.Ox.CrosshairElements[1].BackgroundColor3 = _G.Ox.Crosshair.Color
            end
            if _G.Ox.CrosshairElements[2] then
                _G.Ox.CrosshairElements[2].Size = UDim2.new(0, _G.Ox.Crosshair.Thickness, 0, _G.Ox.Crosshair.Size * 2)
                _G.Ox.CrosshairElements[2].Position = v391
                _G.Ox.CrosshairElements[2].BackgroundColor3 = _G.Ox.Crosshair.Color
            end
        elseif _G.Ox.Crosshair.Style == "Dot" then
            if _G.Ox.CrosshairElements[1] then
                _G.Ox.CrosshairElements[1].Size = UDim2.new(0, _G.Ox.Crosshair.Size, 0, _G.Ox.Crosshair.Size)
                _G.Ox.CrosshairElements[1].Position = v391
                _G.Ox.CrosshairElements[1].BackgroundColor3 = _G.Ox.Crosshair.Color
            end
        elseif _G.Ox.Crosshair.Style == "Circle" and _G.Ox.CrosshairElements[1] then
            _G.Ox.CrosshairElements[1].Size = UDim2.new(0, _G.Ox.Crosshair.Size * 2, 0, _G.Ox.Crosshair.Size * 2)
            _G.Ox.CrosshairElements[1].Position = v391
            local v392 = _G.Ox.CrosshairElements[1]:FindFirstChildOfClass("UIStroke")
            if v392 then
                v392.Color = _G.Ox.Crosshair.Color
                v392.Thickness = _G.Ox.Crosshair.Thickness
            end
        end
    end
    local v401 = function()
        for v397, v398 in ipairs(v3:GetPlayers()) do
            if v398 ~= v4 and (not v398.Team or v398.Team.Name ~= "Survivors") then
                local v399 = v398.Character
                if not v399 then
                    continue
                end
                local v400 = v399:FindFirstChild("HumanoidRootPart")
                if v400 then
                    return v400
                end
            end
        end
        return nil
    end
    local v404 = function(a45)
        if not _G.Ox.AutoPallet.Safety then
            return true
        end
        if not a45 then
            return false
        end
        if a45:GetAttribute("Knocked") == true then
            return false
        end
        if a45:GetAttribute("IsCarried") == true then
            return false
        end
        if a45:GetAttribute("IsHooked") == true then
            return false
        end
        local v402 = a45:FindFirstChild("CheckInterractable")
        if v402 then
            if v402:GetAttribute("isVaulting") == true then
                return false
            end
            if v402:GetAttribute("isRepairing") == true then
                return false
            end
            if v402:GetAttribute("isUnhooking") == true then
                return false
            end
            if v402:GetAttribute("isHealing") == true then
                return false
            end
            if v402:GetAttribute("isSliding") == true then
                return false
            end
            if v402:GetAttribute("isCarrying") == true then
                return false
            end
        end
        local v403 = a45:FindFirstChildOfClass("Humanoid")
        if v403 and v403.Health <= 0 then
            return false
        end
        return true
    end
    local v421 = function(a46)
        local v405 = nil
        local v406 = _G.Ox.AutoPallet.Distance
        local v407 = ipairs
        local v408 = v380.Pallets
        local v409 = v408 or {}
        for v414, v415 in v407(v409) do
            if v415 and v415.Parent and not _G.Ox.AutoPallet.UsedPallets[v415] then
                local v416 = v415:FindFirstChild("PrimaryPartPallet")
                local v417 = v416 or v415:FindFirstChild("PalletPoint") or v415:FindFirstChild("PalletPointSlide") or v415:FindFirstChildWhichIsA("BasePart")
                if v417 then
                    local v418, v419 = pcall(function()
                        return v417.Position
                    end)
                    if v418 and v419 then
                        local v420 = (a46.Position - v419).Magnitude
                        if v420 < v406 then
                            v406 = v420
                            v405 = v415
                        end
                    end
                end
            end
        end
        return v405
    end
    local v426 = function(a47)
        if not a47 then
            return false
        end
        local v422 = a47:FindFirstChild("PalletPointSlide")
        local v423 = v422 or a47:FindFirstChild("PalletPoint") or a47:FindFirstChildWhichIsA("BasePart")
        if not v423 then
            return false
        end
        local v424 = v9:FindFirstChild("Remotes")
        local v425 = v424 and v424:FindFirstChild("Pallet") and v424.Pallet:FindFirstChild("PalletDropEvent")
        if not v425 then
            return false
        end
        pcall(function()
            v425:FireServer(v423)
        end)
        _G.Ox.AutoPallet.UsedPallets[a47] = true
        _G.Ox.AutoPallet.LastDrop = tick()
        return true
    end
    StartAutoPallet = function()
        if _G.Ox.AutoPallet.Connection then
            return
        end
        _G.Ox.AutoPallet.Connection = task.spawn(function()
            while _G.Ox.AutoPallet.Enabled do
                task.wait(0.3)
                if GetRole() == "Survivor" and tick() - _G.Ox.AutoPallet.LastDrop >= _G.Ox.AutoPallet.Cooldown then
                    pcall(function()
                        local v427 = v4.Character
                        local v428 = v427 and v427:FindFirstChild("HumanoidRootPart")
                        local v429 = v427 and v427:FindFirstChildOfClass("Humanoid")
                        if not v428 or not v429 or v429.Health <= 0 then
                            return
                        end
                        if not v404(v427) then
                            return
                        end
                        local v430 = v401()
                        if not v430 then
                            return
                        end
                        if _G.Ox.AutoPallet.Distance < (v428.Position - v430.Position).Magnitude then
                            return
                        end
                        local v431 = v421(v428)
                        if v431 then
                            v426(v431)
                        end
                    end)
                end
            end
        end)
    end
    StopAutoPallet = function()
        if _G.Ox.AutoPallet.Connection then
            task.cancel(_G.Ox.AutoPallet.Connection)
            _G.Ox.AutoPallet.Connection = nil
        end
        _G.Ox.AutoPallet.UsedPallets = {}
    end
    ToggleAutoPallet = function(a48)
        _G.Ox.AutoPallet.Enabled = a48
        if a48 then
            if GetRole() ~= "Survivor" then
                v1:Notify({
                    Title = "Auto Drop Pallet",
                    Description = "Kamu harus Survivor!",
                    Duration = 3,
                })
                _G.Ox.AutoPallet.Enabled = false
                if AutoPalletToggle then
                    v384(AutoPalletToggle, false)
                end
                return
            end
            _G.Ox.AutoPallet.UsedPallets = {}
            StartAutoPallet()
            v1:Notify({
                Title = "Auto Drop Pallet",
                Description = "AKTIF",
                Duration = 2,
            })
        else
            StopAutoPallet()
            v1:Notify({
                Title = "Auto Drop Pallet",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    v4.CharacterAdded:Connect(function()
        _G.Ox.AutoPallet.UsedPallets = {}
        _G.Ox.AutoPallet.LastDrop = 0
    end)
    DropAllPallets = function()
        local v432 = v9:FindFirstChild("Remotes")
        local v433 = v432 and v432:FindFirstChild("Pallet") and v432.Pallet:FindFirstChild("PalletDropEvent")
        if not v433 then
            v1:Notify({
                Title = "Drop All Pallet",
                Description = "Remote tidak ditemukan!",
                Duration = 2,
            })
            return
        end
        local v434 = {}
        local v435 = workspace:FindFirstChild("Map")
        if not v435 then
            v1:Notify({
                Title = "Drop All Pallet",
                Description = "Map tidak ditemukan!",
                Duration = 2,
            })
            return
        end
        for v440, v441 in ipairs(v435:GetDescendants()) do
            if v441.Name == "PalletPoint" and v441:IsA("BasePart") then
                local v442 = v441:FindFirstAncestorWhichIsA("Model")
                if v442 then
                    if not v434[v442] then
                        v434[v442] = {}
                    end
                    table.insert(v434[v442], v441)
                end
            end
        end
        local v443 = 0
        local v444, v445, v446 = pairs(v434)
        local v447 = v446
        local v448 = v444
        local v449 = v445
        while true do
            local v450, v451 = v448(v449, v447)
            if v450 == nil then
                break
            end
            for v458, v459 in ipairs(v451) do
                pcall(function()
                    v433:FireServer(v459)
                    v443 = v443 + 1
                end)
            end
            v447 = v450
        end
        v1:Notify({
            Title = "Drop All Pallet",
            Description = string.format("Berhasil menjatuhkan %d pallet!", v443),
            Duration = 3,
        })
    end
    local v460 = 0
    v482 = function(a49)
        if not a49 and tick() - v460 < 2 then
            return
        end
        v460 = tick()
        table.clear(v374.Generators)
        table.clear(v374.Windows)
        table.clear(v374.Pallets)
        table.clear(v374.Hooks)
        table.clear(v374.Gates)
        table.clear(v380.Generators)
        table.clear(v380.Windows)
        table.clear(v380.Pallets)
        table.clear(v380.Hooks)
        table.clear(v380.Gates)
        table.clear(v380.SCPs)
        local v461 = workspace:FindFirstChild("Map")
        local v462 = v461 or workspace
        local v463 = v462:GetDescendants()
        for v468, v469 in ipairs(v463) do
            if v468 % 200 == 0 then
                task.wait()
            end
            if v469:IsA("Model") then
                local v470 = string.lower(v469.Name)
                if v470 == "generator" then
                    local v471 = v469:FindFirstChild("GeneratorBody")
                    local v472 = v471 or v469:FindFirstChildWhichIsA("BasePart")
                    if v472 then
                        local v473 = {model = v469, part = v472}
                        table.insert(v374.Generators, v473)
                        table.insert(v380.Generators, v473)
                    end
                elseif v470 == "hook" and v469:FindFirstChild("HookPoint") then
                    table.insert(v374.Hooks, v469)
                    table.insert(v380.Hooks, v469)
                elseif v470 == "gate" and v469:FindFirstChild("ExitLever") then
                    table.insert(v374.Gates, v469)
                    table.insert(v380.Gates, v469)
                elseif v470 == "window" then
                    table.insert(v374.Windows, v469)
                    table.insert(v380.Windows, v469)
                end
            elseif v469:IsA("BasePart") and v469.Name == "PrimaryPartPallet" then
                local v474 = v469.Parent
                if v474 and not table.find(v374.Pallets, v474) then
                    table.insert(v374.Pallets, v474)
                    table.insert(v380.Pallets, v474)
                end
            end
        end
        local v475 = workspace:GetDescendants()
        for v480, v481 in ipairs(v475) do
            if v480 % 200 == 0 then
                task.wait()
            end
            if v481:IsA("Model") and string.match(string.lower(v481.Name), "^scp") and not table.find(v380.SCPs, v481) then
                table.insert(v380.SCPs, v481)
            end
        end
    end
    v487 = function(a50)
        if not a50 then
            return
        end
        local v483 = v4.Character
        local v484 = v483 and v483:FindFirstChild("HumanoidRootPart")
        if v484 then
            local v485 = Vector3.new(0, 3, 0)
            if a50:IsA("BasePart") then
                v484.CFrame = a50.CFrame + v485
            elseif a50:IsA("Model") then
                local v486 = a50:FindFirstChildWhichIsA("BasePart")
                if v486 then
                    v484.CFrame = v486.CFrame + v485
                end
            end
            v1:Notify({
                Title = "Teleport",
                Description = "Berhasil!",
                Duration = 1,
            })
        end
    end
    ApplyFullBright = function()
        local v488 = game:GetService("Lighting")
        if not v488 then
            return
        end
        if _G.Ox.FullBright then
            v488.Brightness = 2.8
            v488.ClockTime = _G.Ox.TimeOfDayValue
            v488.FogEnd = 100000
            v488.Ambient = Color3.fromRGB(200, 200, 200)
            v488.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        end
    end
    ApplyNoFog = function()
        local v489 = game:GetService("Lighting")
        if not v489 then
            return
        end
        if _G.Ox.NoFog then
            v489.FogStart = 0
            v489.FogEnd = 100000
            v489.FogColor = Color3.fromRGB(255, 255, 255)
            local v490 = v489:FindFirstChildOfClass("Atmosphere")
            if v490 then
                v490.Density = 0
                v490.Offset = 0
                v490.Glare = 0
                v490.Haze = 0
            end
        end
    end
    ApplyNoShadow = function()
        local v491 = game:GetService("Lighting")
        if not v491 then
            return
        end
        local v492
        if _G.Ox.NoShadow then
            v492 = false
        else
            v492 = true
        end
        v491.GlobalShadows = v492
    end
    ReapplyPerformance = function()
        ApplyFullBright()
        ApplyNoFog()
        ApplyNoShadow()
    end
    ReapplyPerformanceDelayed = function()
        task.spawn(function()
            ReapplyPerformance()
            task.wait(1.2)
            ReapplyPerformance()
            task.wait(2)
            ReapplyPerformance()
            task.wait(3)
            ReapplyPerformance()
        end)
    end
    StartLightingGuard = function()
        if _G.Ox.LightingGuardConn then
            return
        end
        local v493 = 0
        _G.Ox.LightingGuardConn = v5.Heartbeat:Connect(function()
            if not _G.Ox.FullBright and not _G.Ox.NoFog and not _G.Ox.NoShadow then
                return
            end
            local v494 = tick()
            if v494 - v493 < 0.4 then
                return
            end
            v493 = v494
            ReapplyPerformance()
        end)
    end
    StopLightingGuard = function()
        if _G.Ox.FullBright or _G.Ox.NoFog or _G.Ox.NoShadow then
            return
        end
        if _G.Ox.LightingGuardConn then
            _G.Ox.LightingGuardConn:Disconnect()
            _G.Ox.LightingGuardConn = nil
        end
    end
    if not _G.Ox.LightingChildConn then
        _G.Ox.LightingChildConn = game:GetService("Lighting").ChildAdded:Connect(function(a51)
            if not _G.Ox.FullBright and not _G.Ox.NoFog then
                return
            end
            task.defer(function()
                if a51:IsA("Atmosphere") and _G.Ox.NoFog then
                    a51.Density = 0
                    a51.Offset = 0
                    a51.Glare = 0
                    a51.Haze = 0
                end
                ReapplyPerformance()
            end)
        end)
    end
    local v495 = function(a52, a53, a54)
        table.insert(_G.Ox.LowGFX.Saved, {obj = a52, kind = a53, extra = a54})
    end
    LowGFX_ProcessOne = function(a55)
        if not _G.Ox.LowGFX.Enabled or not a55 then
            return
        end
        local v496 = _G.Ox.LowGFX
        if v496.Parts and (a55:IsA("BasePart") or a55:IsA("UnionOperation") or a55:IsA("MeshPart")) and a55.Material ~= Enum.Material.SmoothPlastic then
            v495(a55, "Part", a55.Material)
            a55.Material = Enum.Material.SmoothPlastic
        end
        if v496.Particles and (a55:IsA("ParticleEmitter") or a55:IsA("Smoke") or a55:IsA("Explosion") or a55:IsA("Sparkles") or a55:IsA("Fire")) and a55.Enabled ~= false then
            v495(a55, "Particle", true)
            a55.Enabled = false
        end
        if v496.VisualEffects and (a55:IsA("BloomEffect") or a55:IsA("BlurEffect") or a55:IsA("DepthOfFieldEffect") or a55:IsA("SunRaysEffect") or a55:IsA("ColorCorrectionEffect")) and a55.Enabled ~= false then
            v495(a55, "VFX", true)
            a55.Enabled = false
        end
        if v496.Textures and (a55:IsA("Decal") or a55:IsA("Texture")) and a55.Texture ~= "" then
            v495(a55, "Texture", a55.Texture)
            a55.Texture = ""
        end
        if v496.Sky and a55:IsA("Sky") then
            v495(a55, "Sky", a55.Parent)
            a55.Parent = nil
        end
    end
    ApplyLowGFX = function()
        if not _G.Ox.LowGFX.Enabled then
            return
        end
        local v497 = {workspace, game:GetService("Lighting")}
        local v498, v499, v500 = ipairs(v497)
        local v501 = v500
        local v502 = v498
        local v503 = v499
        while true do
            local v504, v505 = v502(v503, v501)
            if v504 == nil then
                break
            end
            local v506 = v505:GetDescendants()
            for v513, v514 in ipairs(v506) do
                if v513 % 250 == 0 then
                    task.wait()
                end
                LowGFX_ProcessOne(v514)
            end
            v501 = v504
        end
    end
    RestoreLowGFX = function()
        for v519, v520 in ipairs(_G.Ox.LowGFX.Saved) do
            local v521 = v520.obj
            if v521 and v521.Parent then
                pcall(function()
                    if v520.kind == "Part" then
                        v521.Material = v520.extra
                    elseif v520.kind ~= "Particle" and v520.kind ~= "VFX" then
                        if v520.kind == "Texture" then
                            v521.Texture = v520.extra
                        elseif v520.kind == "Sky" and v520.extra then
                            v521.Parent = v520.extra
                        end
                    else
                        v521.Enabled = v520.extra
                    end
                end)
            end
        end
        table.clear(_G.Ox.LowGFX.Saved)
    end
    ToggleLowGFX = function(a56)
        _G.Ox.LowGFX.Enabled = a56
        if a56 then
            task.spawn(ApplyLowGFX)
            v1:Notify({
                Title = "Remove Texture",
                Description = "AKTIF - Low GFX",
                Duration = 2,
            })
        else
            RestoreLowGFX()
            v1:Notify({
                Title = "Remove Texture",
                Description = "NONAKTIF - texture dikembalikan",
                Duration = 2,
            })
        end
    end
    if not _G.Ox.LowGFX.StreamConn then
        _G.Ox.LowGFX.StreamConn = workspace.DescendantAdded:Connect(function(a57)
            if not _G.Ox.LowGFX.Enabled then
                return
            end
            task.defer(function()
                LowGFX_ProcessOne(a57)
            end)
        end)
    end
    CreateSpectatorUI = function()
        if _G.Ox.Spectator.Gui then
            _G.Ox.Spectator.Gui:Destroy()
            _G.Ox.Spectator.Gui = nil
        end
        _G.Ox.Spectator.Gui = Instance.new("ScreenGui")
        _G.Ox.Spectator.Gui.Name = "SpectatorCounter"
        _G.Ox.Spectator.Gui.ResetOnSpawn = false
        _G.Ox.Spectator.Gui.Parent = v4:WaitForChild("PlayerGui")
        local v522 = Instance.new("Frame")
        v522.Name = "MainBox"
        v522.AnchorPoint = Vector2.new(0.5, 1)
        v522.Position = UDim2.new(0.5, 0, 0, -10)
        v522.Size = UDim2.new(0, 68, 0, 22)
        v522.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
        v522.BackgroundTransparency = 0.25
        v522.BorderSizePixel = 0
        v522.Parent = _G.Ox.Spectator.Gui
        Instance.new("UICorner", v522).CornerRadius = UDim.new(0, 8)
        local v523 = Instance.new("UIGradient")
        v523.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.3, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        })
        v523.Parent = v522
        local v524 = Instance.new("UIListLayout", v522)
        v524.FillDirection = Enum.FillDirection.Horizontal
        v524.HorizontalAlignment = Enum.HorizontalAlignment.Center
        v524.VerticalAlignment = Enum.VerticalAlignment.Center
        v524.Padding = UDim.new(0, 6)
        local v525 = Instance.new("ImageLabel", v522)
        v525.Size = UDim2.new(0, 15, 0, 15)
        v525.BackgroundTransparency = 1
        v525.Image = "rbxassetid://13321848320"
        v525.ImageColor3 = Color3.fromRGB(225, 225, 225)
        _G.Ox.Spectator.Label = Instance.new("TextLabel", v522)
        _G.Ox.Spectator.Label.BackgroundTransparency = 1
        _G.Ox.Spectator.Label.Font = Enum.Font.GothamMedium
        _G.Ox.Spectator.Label.Text = "0"
        _G.Ox.Spectator.Label.TextColor3 = Color3.fromRGB(240, 240, 240)
        _G.Ox.Spectator.Label.TextSize = 13
        _G.Ox.Spectator.Label.AutomaticSize = Enum.AutomaticSize.X
    end
    UpdateSpectatorCount = function()
        if not _G.Ox.Spectator.Enabled or not _G.Ox.Spectator.Label then
            return
        end
        local v526 = 0
        for v531, v532 in ipairs(v3:GetPlayers()) do
            if v532.Team and v532.Team.Name == "Spectator" then
                v526 = v526 + 1
            end
        end
        _G.Ox.Spectator.Label.Text = tostring(v526)
        local v533 = _G.Ox.Spectator.Gui
        local v534 = v533 and _G.Ox.Spectator.Gui:FindFirstChild("MainBox")
        if v534 then
            local v535 = UDim2.new
            local v536 = v526 >= 10 and 8 or 0
            local v537 = 55 + v536
            local v538 = v526 >= 100 and 8 or 0
            v534.Size = v535(0, v537 + v538, 0, 22)
        end
    end
    StartSpectatorInfo = function()
        if _G.Ox.Spectator.Enabled then
            return
        end
        _G.Ox.Spectator.Enabled = true
        CreateSpectatorUI()
        UpdateSpectatorCount()
        task.spawn(function()
            while _G.Ox.Spectator.Enabled do
                UpdateSpectatorCount()
                task.wait(1.2)
            end
        end)
        v1:Notify({
            Title = "Spectator Info",
            Description = "✅ Display aktif di pojok atas",
            Duration = 3,
        })
    end
    StopSpectatorInfo = function()
        _G.Ox.Spectator.Enabled = false
        if _G.Ox.Spectator.Gui then
            _G.Ox.Spectator.Gui:Destroy()
            _G.Ox.Spectator.Gui = nil
            _G.Ox.Spectator.Label = nil
        end
        v1:Notify({
            Title = "Spectator Info",
            Description = "Display dimatikan",
            Duration = 2,
        })
    end
    v539 = function(a58)
        if a58 then
            StartSpectatorInfo()
        else
            StopSpectatorInfo()
        end
    end
    ScanMapESP = function(a59)
        v482(a59)
    end
    ForceRefreshMap = function()
        v482(true)
        if _G.Ox.ESPConfig.Master then
            ClearAllESP()
            task.wait(0.1)
            UpdatePlayerESP()
            UpdateSCPESP()
            UpdateStaticESP()
        end
    end
    task.spawn(function()
        task.wait(2)
        ScanMapESP()
    end)
    v4.CharacterAdded:Connect(function()
        task.wait(1.5)
        ScanMapESP()
        if _G.Ox.ESPConfig.Master then
            task.spawn(function()
                task.wait(0.5)
                ClearAllESP()
                task.wait(0.2)
                UpdatePlayerESP()
                UpdateSCPESP()
                UpdateStaticESP()
            end)
        end
    end)
    workspace.ChildAdded:Connect(function(a60)
        if a60.Name == "Map" then
            task.wait(1)
            ScanMapESP(true)
            if _G.Ox.ESPConfig.Master then
                pcall(UpdatePlayerESP)
                pcall(UpdateSCPESP)
                pcall(UpdateStaticESP)
            end
            ReapplyPerformanceDelayed()
            if _G.Ox.LowGFX.Enabled then
                table.clear(_G.Ox.LowGFX.Saved)
                task.wait(1.5)
                ApplyLowGFX()
                task.wait(2.5)
                if _G.Ox.LowGFX.Enabled then
                    ApplyLowGFX()
                end
            end
        end
    end)
    task.spawn(function()
        while _G.Ox.ScriptAlive do
            task.wait(40)
            if _G.Ox.ESPConfig.Master then
                ScanMapESP()
                if _G.Ox.ESPConfig.Master then
                    pcall(UpdateStaticESP)
                    pcall(UpdatePlayerESP)
                    pcall(UpdateSCPESP)
                end
            end
        end
    end)
    local v545 = function()
        local v540 = v4:FindFirstChild("PlayerGui")
        if not v540 then
            return nil
        end
        local v541 = v540:FindFirstChild("Survivor-mob")
        if not v541 then
            return nil
        end
        local v542 = v541:FindFirstChild("Controls")
        if not v542 then
            return nil
        end
        local v543 = v542:FindFirstChild("sprint")
        if not v543 then
            return nil
        end
        if v543:IsA("GuiButton") then
            return v543
        end
        local v544 = v543:FindFirstChild("icon")
        if v544 and v544:IsA("GuiButton") then
            return v544
        end
        if v544 and v544.Parent and v544.Parent:IsA("GuiButton") then
            return v544.Parent
        end
        if v543.Parent and v543.Parent:IsA("GuiButton") then
            return v543.Parent
        end
        return v543
    end
    local v552 = function()
        local v546 = v545()
        if not v546 then
            return false
        end
        pcall(function()
            if type(firesignal) == "function" then
                firesignal(v546.MouseButton1Click)
                firesignal(v546.MouseButton1Down)
                task.wait(0.04)
                firesignal(v546.MouseButton1Up)
            else
                local v547 = v546.AbsolutePosition
                local v548 = v546.AbsoluteSize
                local v549 = v8:GetGuiInset()
                local v550 = v547.X + v548.X / 2 + v549.X
                local v551 = v547.Y + v548.Y / 2 + v549.Y
                v7:SendTouchEvent(9901, 0, v550, v551)
                task.wait(0.04)
                v7:SendTouchEvent(9901, 2, v550, v551)
            end
        end)
        return true
    end
    local v557 = function()
        local v553 = v4.Character
        if not v553 then
            return false
        end
        local v554 = v553:FindFirstChildOfClass("Humanoid")
        if not v554 then
            return false
        end
        if v554.MoveDirection.Magnitude > 0.12 then
            return true
        end
        local v555 = v553:FindFirstChild("HumanoidRootPart")
        if v555 then
            local v556 = v555.AssemblyLinearVelocity
            if Vector3.new(v556.X, 0, v556.Z).Magnitude > 1.5 then
                return true
            end
        end
        return false
    end
    local v560 = function()
        local v558 = v4.Character
        if not v558 then
            return false
        end
        local v559 = v558:GetAttribute("Crouching") == true or v558:GetAttribute("Crouchingserver") == true
        return v559
    end
    local v563 = function()
        local v561 = v4.Character
        if not v561 then
            return false
        end
        local v562 = v561:GetAttribute("Sprinting") == true or v561:GetAttribute("IsRunning") == true
        return v562
    end
    v567 = function()
        if _G.Ox.AutoRun.MobileThread then
            return
        end
        _G.Ox.AutoRun.MobileThread = task.spawn(function()
            while _G.Ox.AutoRun.Mobile do
                local v564 = v557()
                local v565 = v560()
                local v566 = v563()
                if v565 then
                    if v566 then
                        v552()
                    end
                elseif v564 and not v566 then
                    v552()
                elseif not v564 and v566 then
                    v552()
                end
                task.wait(0.12)
            end
            _G.Ox.AutoRun.MobileThread = nil
        end)
    end
    v568 = function()
        _G.Ox.AutoRun.Mobile = false
        if _G.Ox.AutoRun.MobileThread then
            task.cancel(_G.Ox.AutoRun.MobileThread)
            _G.Ox.AutoRun.MobileThread = nil
        end
        if v563() then
            v552()
        end
    end
    task.spawn(function()
        while _G.Ox.ScriptAlive do
            task.wait(0.1)
            if not _G.Ox.ScriptAlive then
                break
            end
            if not v6.TouchEnabled and tick() - _G.Ox.lastActionTime >= _G.Ox.COOLDOWN then
                local v569 = _G.Ox.autoVaultEnabled
                local v570 = _G.Ox.autoPalletSlideEnabled
                if v569 or v570 then
                    local v571 = v11:FindFirstChild("pcprompts")
                    local v572 = v571 and v571:FindFirstChild("Frame")
                    if v572 then
                        local v573 = v572:FindFirstChild("VaultPromptGui")
                        local v574 = v572:FindFirstChild("PalletSlidePromptGui")
                        local v575 = v573 and v573.Visible
                        local v576 = v574 and v574.Visible
                        if v569 and v575 or v570 and v576 then
                            v7:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                            task.wait(0.01)
                            v7:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                            _G.Ox.lastActionTime = tick()
                        end
                    end
                end
            end
        end
    end)
    local v596 = function()
        if not v6.TouchEnabled then
            return
        end
        local v577 = v11:FindFirstChild("Survivor-mob")
        local v578 = v577 or v11:WaitForChild("Survivor-mob", 8)
        if not v578 then
            return
        end
        local v579 = v578:FindFirstChild("Controls")
        local v580 = v579 or v578:WaitForChild("Controls", 5)
        local v581 = v580
        if v580 then
            local v582 = v580:FindFirstChild("action")
            v581 = v582 or v580:WaitForChild("action", 5)
        end
        if not v581 then
            return
        end
        local v583 = {
            vault = true,
            palletvault = true,
            palletslide = true,
            slide = true,
        }
        local v589 = function(a61)
            if not a61:IsA("ImageLabel") and not a61:IsA("ImageButton") then
                return
            end
            local v584 = a61.Name:lower()
            if not v583[v584] then
                return
            end
            a61:GetPropertyChangedSignal("Visible"):Connect(function()
                if not a61.Visible then
                    return
                end
                if tick() - _G.Ox.lastActionTime < _G.Ox.COOLDOWN then
                    return
                end
                local v585 = v584:find("vault")
                local v586 = v585
                if v585 then
                    if v584:find("pallet") then
                        v586 = false
                    else
                        v586 = true
                    end
                end
                local v587 = v584:find("pallet")
                local v588 = v587 or v584:find("slide")
                if v586 and _G.Ox.autoVaultEnabled or v588 and _G.Ox.autoPalletSlideEnabled then
                    pcall(function()
                        firesignal(v581.MouseButton1Down)
                        task.wait(0.01)
                        firesignal(v581.MouseButton1Up)
                    end)
                    _G.Ox.lastActionTime = tick()
                end
            end)
        end
        for v594, v595 in pairs(v581:GetChildren()) do
            v589(v595)
        end
        v581.ChildAdded:Connect(function(a62)
            task.wait()
            v589(a62)
        end)
    end
    task.spawn(v596)
    v4.CharacterAdded:Connect(function()
        task.wait(2)
        v596()
    end)
    v11.ChildAdded:Connect(function(a63)
        if a63.Name == "Survivor-mob" then
            task.wait(1)
            v596()
        end
    end);
    (function()
        task.spawn(function()
            local v597 = v9:WaitForChild("Remotes", 10)
            local v598 = v597 and v597:WaitForChild("KillerPerks", 5)
            local v599 = v598 and v598:WaitForChild("kingscourge", 5)
            local v600 = v599 and v599:WaitForChild("KingScourgeStart", 5)
            if v600 then
                v600.OnClientEvent:Connect(function()
                    if _G.Ox.Auto.SkillCheckMode == "Random" then
                        _G.Ox.State.RandomMode_IsNormal = true
                    end
                end)
            end
        end)
    end)()
    local v605 = function()
        if not v11 then
            return nil
        end
        local v601 = v11:FindFirstChild("Survivor-mob")
        if not v601 then
            return nil
        end
        local v602 = v601:FindFirstChild("Controls")
        if not v602 then
            return nil
        end
        local v603 = v602:FindFirstChild("action")
        local v604 = v603 or v602:FindFirstChild("check")
        return v604
    end
    local v611 = function()
        local v606 = v605()
        if v606 and v606:IsA("GuiObject") and v606.Visible and type(firesignal) == "function" then
            pcall(function()
                firesignal(v606.MouseButton1Down)
                task.wait(0.005)
                firesignal(v606.MouseButton1Up)
            end)
            return true
        end
        if v606 and v606:IsA("GuiObject") and v606.Visible then
            pcall(function()
                local v607 = v606.AbsolutePosition
                local v608 = v606.AbsoluteSize
                local v609 = v8:GetGuiInset()
                local v610 = 8822 + math.random(1, 9999)
                v7:SendTouchEvent(v610, 0, v607.X + v608.X / 2 + v609.X, v607.Y + v608.Y / 2 + v609.Y)
                task.wait(0.005)
                v7:SendTouchEvent(v610, 2, v607.X + v608.X / 2 + v609.X, v607.Y + v608.Y / 2 + v609.Y)
            end)
            return true
        end
        pcall(function()
            v7:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.005)
            v7:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
        return true
    end
    v625 = function()
        if _G.Ox.Connections.SkillHeartbeat then
            _G.Ox.Connections.SkillHeartbeat:Disconnect()
            _G.Ox.Connections.SkillHeartbeat = nil
        end
        _G.Ox.Connections.SkillHeartbeat = v5.Heartbeat:Connect(function()
            if not _G.Ox.Auto.SkillCheck or _G.Ox.State.busy then
                return
            end
            local v612 = v11:FindFirstChild("SkillCheckPromptGui")
            if not v612 then
                return
            end
            local v613 = v612:FindFirstChild("Check")
            if v613 and v613.Visible then
                local v614 = v613:FindFirstChild("Line")
                local v615 = v613:FindFirstChild("Goal")
                if not v614 or not v615 then
                    return
                end
                local v616 = _G.Ox.Auto.SkillCheckMode == "Instant"
                if not v616 then
                    v616 = _G.Ox.Auto.SkillCheckMode == "Random"
                    if v616 then
                        if _G.Ox.State.RandomMode_IsNormal then
                            v616 = false
                        else
                            v616 = true
                        end
                    end
                end
                if v616 then
                    v614.Rotation = v615.Rotation + 109
                    _G.Ox.State.busy = true
                    task.spawn(function()
                        v611()
                        task.wait(0.05)
                        _G.Ox.State.busy = false
                    end)
                else
                    local v617 = _G.Ox.Auto.SkillCheckMode == "Normal" or _G.Ox.Auto.SkillCheckMode == "Random" and _G.Ox.State.RandomMode_IsNormal
                    local v618 = v614.Rotation % 360
                    local v619 = v615.Rotation % 360
                    local v620, v621
                    if v617 then
                        v620 = (v619 + 116) % 360
                        v621 = (v619 + 140) % 360
                    else
                        v620 = (v619 + 102) % 360
                        v621 = (v619 + 116) % 360
                    end
                    local v623
                    if v621 < v620 then
                        local v624 = v620 <= v618 or v618 <= v621
                        v623 = v624
                    else
                        local v622 = v620 <= v618 and v618 <= v621
                        v623 = v622
                    end
                    if v623 then
                        _G.Ox.State.busy = true
                        task.spawn(function()
                            v611()
                            task.wait(0.05)
                            _G.Ox.State.busy = false
                        end)
                    end
                end
                return
            end
            _G.Ox.State.RandomMode_IsNormal = false
        end)
    end
    local v626 = game:GetService("ReplicatedStorage").Remotes.Generator.RepairEvent
    local v627 = {}
    local v628 = 0
    GetAllGenerators = function()
        local v629 = tick()
        if v629 - v628 < 5 then
            return v627
        end
        v627 = {}
        v628 = v629
        local v630 = workspace:FindFirstChild("Map")
        if not v630 then
            return v627
        end
        pcall(function()
            for v635, v636 in pairs(v630:GetDescendants()) do
                if v636:IsA("Model") and v636.Name == "Generator" then
                    local v637 = v636:GetAttribute("RepairProgress") ~= nil or v636:GetAttribute("kickcount") ~= nil or v636:GetAttribute("ProgressRepair") ~= nil
                    if v637 then
                        table.insert(v627, v636)
                    end
                end
            end
        end)
        return v627
    end
    _G.Ox.PlayRepairAnim = function()
        local v638 = v4.Character
        if not v638 then
            return
        end
        local v639 = v638:FindFirstChildOfClass("Humanoid")
        local v640 = v639 and v639:FindFirstChildOfClass("Animator")
        if not v640 then
            return
        end
        if _G.Ox.RepairAnimTrack and _G.Ox.RepairAnimTrack.IsPlaying then
            return
        end
        pcall(function()
            local v641 = Instance.new("Animation")
            v641.AnimationId = "rbxassetid://92960319113695"
            _G.Ox.RepairAnimTrack = v640:LoadAnimation(v641)
            _G.Ox.RepairAnimTrack.Priority = Enum.AnimationPriority.Action
            _G.Ox.RepairAnimTrack:Play()
        end)
    end
    _G.Ox.StopRepairAnim = function()
        if _G.Ox.RepairAnimTrack and _G.Ox.RepairAnimTrack.IsPlaying then
            pcall(function()
                _G.Ox.RepairAnimTrack:Stop()
            end)
        end
        _G.Ox.RepairAnimTrack = nil
    end
    GetGeneratorPoints = function(a64)
        local v642 = {}
        pcall(function()
            for v647, v648 in pairs(a64:GetChildren()) do
                if v648.Name:find("GeneratorPoint") and v648:IsA("BasePart") then
                    table.insert(v642, v648)
                end
            end
        end)
        return v642
    end
    _G.Ox.StopAutoRepair = function()
        _G.Ox.StopRepairAnim()
        local v649 = _G.Ox.AutoCurrentPoint
        _G.Ox.AutoCurrentPoint = nil
        if v649 then
            pcall(function()
                v626:FireServer(v649, false)
            end)
        end
    end
    _G.Ox.StartAutoRepairLoop = function(a65)
        _G.Ox.AutoCurrentGenModel = a65
        if _G.Ox.AutoRepairThread then
            task.cancel(_G.Ox.AutoRepairThread)
            _G.Ox.AutoRepairThread = nil
        end
        _G.Ox.StopAutoRepair()
        _G.Ox.AutoRepairThread = task.spawn(function()
            while _G.Ox.AutoRepairEnabled and _G.Ox.BypassGenEnabled do
                local v650 = v4.Character
                local v651 = v650 and v650:FindFirstChild("HumanoidRootPart")
                if not v651 then
                    task.wait(0.1)
                    continue
                end
                local v652 = nil
                local v653, v654, v655 = pairs(GetAllGenerators())
                local v656 = v655
                local v657 = v653
                local v658 = v654
                local v659, v660
                repeat
                    v659, v660 = v657(v658, v656)
                    if v659 == nil then
                        break
                    end
                    for v667, v668 in pairs(GetGeneratorPoints(v660)) do
                        if (v651.Position - v668.Position).Magnitude <= 5 then
                            v652 = v668
                            break
                        end
                    end
                    v656 = v659
                until v652
                if v652 then
                    _G.Ox.AutoCurrentPoint = v652
                    local v669 = tick()
                    if _G.Ox.AutoFireInterval <= v669 - _G.Ox.LastFireTime then
                        _G.Ox.PlayRepairAnim()
                        pcall(function()
                            v626:FireServer(v652, true)
                        end)
                        _G.Ox.LastFireTime = v669
                    end
                elseif _G.Ox.AutoCurrentPoint then
                    _G.Ox.StopAutoRepair()
                    _G.Ox.AutoRepairEnabled = false
                    if _G.Ox.AutoCurrentGenModel then
                        _G.Ox.ProcessedGens[_G.Ox.AutoCurrentGenModel] = nil
                        _G.Ox.AutoCurrentGenModel = nil
                    end
                    break
                end
                task.wait(0.1)
            end
            _G.Ox.StopAutoRepair()
        end)
    end
    waitForRepairing = function(a66, a67)
        local v670 = tick()
        while true do
            local v671 = tick() - v670
            local v672 = a67 or 1
            if v671 >= v672 then
                break
            end
            if a66:GetAttribute("IsRepairing") == true then
                return true
            end
            task.wait(0.05)
        end
        return false
    end
    RecreateBypassButton = function()
        local v673 = v10:FindFirstChild("BypassGenUI")
        if v673 then
            v673:Destroy()
        end
        _G.Ox.BypassUI = Instance.new("ScreenGui")
        _G.Ox.BypassUI.Name = "BypassGenUI"
        _G.Ox.BypassUI.ResetOnSpawn = false
        _G.Ox.BypassUI.IgnoreGuiInset = true
        _G.Ox.BypassUI.Parent = v10
        _G.Ox.BypassButton = Instance.new("ImageButton")
        _G.Ox.BypassButton.Name = "BypassGenButton"
        _G.Ox.BypassButton.Size = UDim2.new(0, 55, 0, 55)
        _G.Ox.BypassButton.Position = UDim2.new(0.88, 0, 0.55, 0)
        _G.Ox.BypassButton.AnchorPoint = Vector2.new(0.5, 0.5)
        _G.Ox.BypassButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        _G.Ox.BypassButton.BackgroundTransparency = 0.15
        _G.Ox.BypassButton.AutoButtonColor = true
        _G.Ox.BypassButton.Visible = false
        _G.Ox.BypassButton.ZIndex = 10
        _G.Ox.BypassButton.Parent = _G.Ox.BypassUI
        local v674 = Instance.new("UICorner")
        v674.CornerRadius = UDim.new(1, 0)
        v674.Parent = _G.Ox.BypassButton
        local v675 = Instance.new("UIStroke")
        v675.Color = Color3.fromRGB(255, 255, 255)
        v675.Thickness = 1.5
        v675.Transparency = 0.4
        v675.Parent = _G.Ox.BypassButton
        local v676 = Instance.new("TextLabel")
        v676.Size = UDim2.new(1, 0, 1, 0)
        v676.BackgroundTransparency = 1
        v676.Text = "GEN"
        v676.TextColor3 = Color3.fromRGB(255, 255, 255)
        v676.TextScaled = true
        v676.Font = Enum.Font.GothamBold
        v676.ZIndex = 11
        v676.Parent = _G.Ox.BypassButton
        local v677 = _G.Ox.BypassButton
        local v678 = _G.Ox.BypassToggleValue
        local v679 = v678 and v6.TouchEnabled
        if v679 then
            if v6.KeyboardEnabled then
                v679 = false
            else
                v679 = true
            end
        end
        v677.Visible = v679
    end
    RecreateBypassButton()
    _G.Ox.DoMultiRepairPlain = function(a68)
        local v680 = a68.Parent
        if _G.Ox.ProcessedGens[v680] then
            return
        end
        _G.Ox.ProcessedGens[v680] = true
        local v681 = GetGeneratorPoints(v680)
        local v682 = v4.Character
        local v683 = v682 and v682:FindFirstChild("HumanoidRootPart")
        if not v683 then
            _G.Ox.ProcessedGens[v680] = nil
            return
        end
        local v684 = v683.CFrame
        pcall(function()
            for v689, v690 in pairs(v681) do
                if v690 ~= a68 and v690.Parent then
                    v683.Anchored = true
                    v683.CFrame = v690.CFrame
                    task.wait(0.15)
                    pcall(function()
                        v626:FireServer(v690, true)
                    end)
                    if not waitForRepairing(v690, 0.8) then
                        pcall(function()
                            v626:FireServer(v690, false)
                        end)
                        task.wait(0.1)
                        v683.CFrame = v690.CFrame
                        task.wait(0.15)
                        pcall(function()
                            v626:FireServer(v690, true)
                        end)
                        waitForRepairing(v690, 0.5)
                    end
                    v683.Anchored = false
                    task.wait(0.05)
                end
            end
        end)
        pcall(function()
            if v683 and v683.Parent then
                v683.Anchored = false
                v683.CFrame = v684
            end
        end)
        task.wait(0.1)
        if _G.Ox.BypassGenMode == "Manual Repair" then
            pcall(function()
                v626:FireServer(a68, false)
            end)
        elseif _G.Ox.BypassGenMode == "Auto Repair" then
            _G.Ox.AutoRepairEnabled = true
            _G.Ox.StartAutoRepairLoop(v680)
        end
    end
    _G.Ox.BypassButton.MouseButton1Click:Connect(function()
        if not _G.Ox.BypassGenEnabled then
            return
        end
        local v691 = v4.Character
        local v692 = v691 and v691:FindFirstChild("HumanoidRootPart")
        if not v692 then
            return
        end
        local v693 = nil
        local v694 = math.huge
        local v695, v696, v697 = pairs(GetAllGenerators())
        local v698 = v697
        local v699 = v695
        local v700 = v696
        while true do
            local v701, v702 = v699(v700, v698)
            if v701 == nil then
                break
            end
            for v709, v710 in pairs(GetGeneratorPoints(v702)) do
                local v711 = (v692.Position - v710.Position).Magnitude
                if v711 < v694 then
                    v694 = v711
                    v693 = v710
                end
            end
            v698 = v701
        end
        if v693 and v694 <= 8 then
            _G.Ox.DoMultiRepairPlain(v693)
        else
            v1:Notify({
                Title = "Gen Boost",
                Description = "Ga deket generator manapun!",
                Duration = 2,
            })
        end
    end)
    isGeneratorPromptVisible = function()
        local v712, v713 = pcall(function()
            return v4.PlayerGui.pcprompts.Frame.GeneratorRepair
        end)
        local v714 = v712 and v713 and v713.Visible
        return v714
    end
    getNearestGenPoint = function()
        local v715 = v4.Character
        local v716 = v715 and v715:FindFirstChild("HumanoidRootPart")
        if not v716 then
            return nil
        end
        local v717 = nil
        local v718 = math.huge
        local v719, v720, v721 = pairs(GetAllGenerators())
        local v722 = v721
        local v723 = v719
        local v724 = v720
        while true do
            local v725, v726 = v723(v724, v722)
            if v725 == nil then
                break
            end
            for v733, v734 in pairs(GetGeneratorPoints(v726)) do
                local v735 = (v716.Position - v734.Position).Magnitude
                if v735 < v718 then
                    v718 = v735
                    v717 = v734
                end
            end
            v722 = v725
        end
        return v717, v718
    end
    v6.InputBegan:Connect(function(a69, a70)
        if a70 then
            return
        end
        if a69.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        if not _G.Ox.BypassGenEnabled then
            return
        end
        if not isGeneratorPromptVisible() then
            return
        end
        local v736, v737 = getNearestGenPoint()
        if not v736 or v737 > 8 then
            return
        end
        if _G.Ox.ProcessedGens[v736.Parent] then
            return
        end
        _G.Ox.DoMultiRepairPlain(v736)
    end)
    startProcessedGensWatcher = function()
        task.spawn(function()
            local v738, v739, v740, v741, v742, v743, v744, v745, v746, v747, v748, v749, v750, v751, v752, v753, v754, v755, v756, v757
            v757 = 1
            while true do
                if v757 == 1 then
                    if _G.Ox.ScriptAlive then
                        v757 = 2
                    else
                        v757 = 16
                    end
                elseif v757 == 2 then
                    task.wait(2)
                    if _G.Ox.ScriptAlive then
                        v757 = 3
                    else
                        v757 = 16
                    end
                elseif v757 == 3 then
                    v738 = v4.Character
                    v739 = v738
                    if v738 then
                        v757 = 4
                    else
                        v757 = 5
                    end
                elseif v757 == 4 then
                    v739 = v738:FindFirstChild("HumanoidRootPart")
                    v757 = 5
                elseif v757 == 5 then
                    if v739 then
                        v757 = 6
                    else
                        v757 = 1
                    end
                elseif v757 == 6 then
                    v740, v741, v742 = pairs(_G.Ox.ProcessedGens)
                    v743 = v742
                    v744 = v740
                    v745 = v741
                    v757 = 7
                elseif v757 == 7 then
                    v746 = v744(v745, v743)
                    if v746 == nil then
                        v757 = 1
                    else
                        v757 = 8
                    end
                elseif v757 == 8 then
                    v743 = v746
                    if v746 and v746.Parent then
                        v757 = 10
                    else
                        v757 = 9
                    end
                elseif v757 == 9 then
                    _G.Ox.ProcessedGens[v746] = nil
                    v757 = 7
                elseif v757 == 10 then
                    v747 = false
                    v748 = GetGeneratorPoints(v746)
                    v749, v750, v751 = pairs(v748)
                    v752 = v744
                    v753 = v745
                    v754 = v751
                    v757 = 11
                elseif v757 == 11 then
                    v755, v756 = v749(v750, v754)
                    if v755 == nil then
                        v757 = 14
                    else
                        v757 = 12
                    end
                elseif v757 == 12 then
                    v754 = v755
                    if v756.Parent and (v739.Position - v756.Position).Magnitude <= 10 then
                        v757 = 13
                    else
                        v757 = 11
                    end
                elseif v757 == 13 then
                    v747 = true
                    v757 = 14
                elseif v757 == 14 then
                    v743 = v746
                    v744 = v752
                    v745 = v753
                    if v747 then
                        v757 = 7
                    else
                        v757 = 15
                    end
                elseif v757 == 15 then
                    _G.Ox.ProcessedGens[v746] = nil
                    v757 = 7
                elseif v757 == 16 then
                    return
                end
            end
        end)
    end
    startProcessedGensWatcher()
    INVIS_URL = "https://script.panduhub.com/invisibility.lua"
    local v758 = nil
    local v759 = false
    local v760 = v6.TouchEnabled
    local v761 = v760
    if v760 then
        if v6.KeyboardEnabled then
            v761 = false
        else
            v761 = true
        end
    end
    local v764 = function()
        if v759 then
            return true
        end
        local v762, v763 = pcall(function()
            return loadstring(game:HttpGet(INVIS_URL))()
        end)
        if not v762 or not v763 then
            return false
        end
        v758 = v763
        v759 = true
        return true
    end
    v765 = function(a71)
        if a71 then
            if not v759 then
                v764()
            end
            if v758 then
                if v761 then
                    v758.ShowGUI()
                else
                    v758.Enable()
                end
            end
        elseif v758 then
            if v761 then
                v758.HideGUI()
            end
            v758.Disable()
        end
    end
    v766 = nil
    local v767 = false
    local v770 = function()
        if v767 then
            return true
        end
        local v768, v769 = pcall(function()
            return loadstring(game:HttpGet("https://script.panduhub.com/BoostBandage.lua"))()
        end)
        if not v768 or not v769 then
            return false
        end
        v766 = v769
        v767 = true
        return true
    end
    v771 = function(a72)
        if a72 then
            if not v767 then
                v770()
            end
            if v766 then
                if v761 then
                    v766.ShowGUI()
                elseif not v766.Start() then
                    _G.Ox.Utility.BandageEnabled = false
                end
            end
        elseif v766 then
            if v761 then
                v766.HideGUI()
            end
            v766.Stop()
        end
    end
    local v772 = nil
    local v773 = false
    local v776 = function()
        if v773 then
            return true
        end
        local v774, v775 = pcall(function()
            return loadstring(game:HttpGet("https://pastefy.app/Pu94U00g/raw"))()
        end)
        if not v774 or not v775 then
            return false
        end
        v772 = v775
        v773 = true
        return true
    end
    v777 = function(a73)
        if a73 then
            if not v773 then
                v776()
            end
            if v772 then
                if v761 then
                    v772.ShowGUI()
                else
                    v772.Enable()
                end
                v1:Notify({
                    Title = "Dash Lock",
                    Description = "AKTIF - Klik kanan untuk lock",
                    Duration = 3,
                })
            end
        elseif v772 then
            if v761 then
                v772.HideGUI()
            end
            v772.Disable()
            v1:Notify({
                Title = "Dash Lock",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    task.spawn(function()
        task.wait(2)
        v776()
    end)
    local v778 = nil
    local v779 = false
    local v782 = function()
        if v779 then
            return true
        end
        local v780, v781 = pcall(function()
            return loadstring(game:HttpGet("https://pastefy.app/NKuKyY5i/raw"))()
        end)
        if not v780 or not v781 then
            return false
        end
        v778 = v781
        v779 = true
        return true
    end
    v791 = function(a74)
        if a74 then
            if not v782() then
                v1:Notify({
                    Title = "Mask GUI",
                    Description = "Gagal load script!",
                    Duration = 3,
                })
                return
            end
            local v783, v784 = v778.Toggle(true)
            if v783 then
                local v785 = v1.Notify
                local v786 = {Title = "Mask GUI"}
                local v787 = v784 or "Dimuat! (Tombol M)"
                v786.Description = v787
                v786.Duration = 3
                v785(v1, v786)
            else
                local v788 = v1.Notify
                local v789 = {Title = "Mask GUI"}
                local v790 = v784 or "Kamu bukan The Masked!"
                v789.Description = v790
                v789.Duration = 3
                v788(v1, v789)
            end
        elseif v779 and v778 then
            v778.Toggle(false)
            v1:Notify({
                Title = "Mask GUI",
                Description = "Disembunyikan",
                Duration = 2,
            })
        end
    end
    task.spawn(function()
        task.wait(2)
        v782()
    end)
    getTargetPartObject = function(a75)
        if _G.Ox.AimConfig.AIM_TargetPart == "Head" then
            return a75:FindFirstChild("Head")
        end
        if _G.Ox.AimConfig.AIM_TargetPart == "Root" or _G.Ox.AimConfig.AIM_TargetPart == "HumanoidRootPart" then
            return a75:FindFirstChild("HumanoidRootPart")
        end
        local v792 = a75:FindFirstChild("Torso")
        local v793 = v792 or a75:FindFirstChild("UpperTorso") or a75:FindFirstChild("HumanoidRootPart")
        return v793
    end
    getClosestSurvivor = function()
        local v794 = v4.Character
        local v795 = v794 and v794:FindFirstChild("HumanoidRootPart")
        if not v795 then
            return nil
        end
        local v796 = _G.Ox.AimConfig.Veil_FOV
        local v797 = nil
        local v798 = workspace.CurrentCamera
        local v799 = Vector2.new(v798.ViewportSize.X / 2, v798.ViewportSize.Y / 2)
        for v804, v805 in ipairs(v3:GetPlayers()) do
            if v805 ~= v4 and v805.Team and v805.Team.Name == "Survivors" and v805.Character then
                local v806 = v805.Character
                local v807 = v806:FindFirstChildOfClass("Humanoid")
                local v808 = getTargetPartObject(v806)
                if v807 and v807.Health > 0 and v808 and (v808.Position - v795.Position).Magnitude <= _G.Ox.AimConfig.SPEAR_MaxDist then
                    local v809, v810 = v798:WorldToViewportPoint(v808.Position)
                    if v810 then
                        local v811 = (Vector2.new(v809.X, v809.Y) - v799).Magnitude
                        if v811 <= v796 then
                            v796 = v811
                            v797 = v808
                        end
                    end
                end
            end
        end
        return v797
    end
    getBestAimbotTarget = function()
        local v812 = nil
        local v813 = GetRole()
        local v814 = _G.Ox.Config.Surv_Aimbot_Radius
        local v815 = math.huge
        local v816 = Vector2.new(v12.ViewportSize.X / 2, v12.ViewportSize.Y / 2)
        for v821, v822 in ipairs(v3:GetPlayers()) do
            if v822 ~= v4 and v822.Character and v822.Character:FindFirstChild("HumanoidRootPart") then
                local v823 = false
                if v813 == "Survivor" and _G.Ox.Config.Surv_Aimbot_Enabled and IsKiller(v822) then
                    v823 = true
                elseif v813 == "Killer" and _G.Ox.Config.Killer_Aimbot_Enabled and not IsKiller(v822) then
                    local v824 = v822.Character:FindFirstChild("Humanoid")
                    if v824 and v824.Health > 0 and not IsDowned(v822.Character) then
                        v823 = true
                    end
                end
                if v823 then
                    local v825 = v822.Character.HumanoidRootPart
                    local v826 = GetDistance(v825.Position)
                    if v813 == "Survivor" and v826 <= _G.Ox.Config.Surv_Aimbot_MaxDist then
                        local v827, v828 = v12:WorldToViewportPoint(v825.Position)
                        if v828 then
                            local v829 = (Vector2.new(v827.X, v827.Y) - v816).Magnitude
                            if v829 < v814 then
                                v814 = v829
                                v812 = v825
                            end
                        end
                    elseif v813 == "Killer" and v826 <= _G.Ox.Config.Killer_Aimbot_MaxDist and v826 < v815 then
                        v815 = v826
                        v812 = v825
                    end
                end
            end
        end
        return v812
    end
    getBestKillerAimbotTarget = function()
        local v830 = nil
        local v831 = math.huge
        local v832 = v4.Character
        local v833 = v832 and v832:FindFirstChild("HumanoidRootPart")
        if not v833 then
            return nil
        end
        for v838, v839 in ipairs(v3:GetPlayers()) do
            if v839 ~= v4 and v839.Team and v839.Team.Name == "Survivors" and v839.Character then
                local v840 = v839.Character:FindFirstChildOfClass("Humanoid")
                local v841 = v839.Character:FindFirstChild("HumanoidRootPart")
                if v840 and v840.Health > 0 and v841 and not IsDowned(v839.Character) then
                    local v842 = (v841.Position - v833.Position).Magnitude
                    if v842 < v831 and v842 <= _G.Ox.Config.Killer_Aimbot_MaxDist then
                        v831 = v842
                        v830 = v841
                    end
                end
            end
        end
        return v830
    end
    getKillerTargetForFlash = function()
        local v843 = nil
        local v844 = math.huge
        local v845 = v4.Character
        local v846 = v845 and v845:FindFirstChild("HumanoidRootPart")
        if not v846 then
            return nil
        end
        for v851, v852 in ipairs(v3:GetPlayers()) do
            if v852 ~= v4 and v852.Team and v852.Team.Name == "Killer" and v852.Character then
                local v853 = v852.Character:FindFirstChildOfClass("Humanoid")
                local v854 = v852.Character:FindFirstChild("HumanoidRootPart")
                if v853 and v853.Health > 0 and v854 and not IsDowned(v852.Character) then
                    local v855 = (v854.Position - v846.Position).Magnitude
                    if v855 < v844 then
                        v844 = v855
                        v843 = v854
                    end
                end
            end
        end
        return v843
    end
    NEX_UpdateCureFlaskLaser = function()
        local v856 = v4.Character
        if not v856 then
            return
        end
        local v857 = nil
        local v858 = nil
        local v859 = nil
        local v860 = math.huge
        local v861 = v856:FindFirstChild("HumanoidRootPart")
        if v861 then
            local v862 = v856:FindFirstChild("LeftHand")
            local v863 = v862 or v856:FindFirstChild("Left Arm")
            local v864 = v863 and v863.Position or v861.Position
            v858 = v864
            for v869, v870 in pairs(v3:GetPlayers()) do
                if v870 ~= v4 and v870.Character and v870.Character:FindFirstChild("HumanoidRootPart") and not IsKiller(v870) then
                    local v871 = (v870.Character.HumanoidRootPart.Position - v861.Position).Magnitude
                    if v871 < v860 then
                        v860 = v871
                        v859 = v870
                    end
                end
            end
        end
        if v859 then
            v857 = v859.Character.HumanoidRootPart.Position
        end
        local v872 = false
        for v877, v878 in pairs(v856:GetChildren()) do
            if v878:IsA("LocalScript") and v878:GetAttribute("action") == true then
                v872 = true
                break
            end
        end
        if v858 and v857 and v872 then
            if not _G.Ox.NEX_CureFlaskLaserPart then
                local v879 = Instance.new("Part")
                v879.Name = "FlaskSilentAimLaser"
                v879.Anchored = true
                v879.CanCollide = false
                v879.CanTouch = false
                v879.CastShadow = false
                v879.Material = Enum.Material.Neon
                v879.Color = Color3.fromRGB(255, 50, 50)
                v879.Transparency = 0
                v879.Parent = workspace
                _G.Ox.NEX_CureFlaskLaserPart = v879
            end
            local v880 = (v857 - v858).Magnitude
            if v880 > 0.1 then
                local v881 = _G.Ox.NEX_CureFlaskLaserPart
                v881.Size = Vector3.new(0.16, 0.16, v880)
                v881.CFrame = CFrame.new((v858 + v857) / 2, v857)
                v881.Transparency = 0
            end
        elseif _G.Ox.NEX_CureFlaskLaserPart then
            _G.Ox.NEX_CureFlaskLaserPart.Transparency = 1
        end
    end
    NEX_StartCureFlaskLaser = function()
        if _G.Ox.NEX_CureFlaskLaserThread then
            return
        end
        _G.Ox.NEX_CureFlaskLaserThread = v5.RenderStepped:Connect(function()
            if not _G.Ox.KILLER_FlaskLaser then
                if _G.Ox.NEX_CureFlaskLaserPart then
                    pcall(function()
                        _G.Ox.NEX_CureFlaskLaserPart:Destroy()
                    end)
                    _G.Ox.NEX_CureFlaskLaserPart = nil
                end
                if _G.Ox.NEX_CureFlaskLaserThread then
                    _G.Ox.NEX_CureFlaskLaserThread:Disconnect()
                    _G.Ox.NEX_CureFlaskLaserThread = nil
                end
                return
            end
            pcall(NEX_UpdateCureFlaskLaser)
        end)
    end
    setupSpearInterceptor = function()
        if v378 then
            return
        end
        if not getrawmetatable or not setreadonly then
            return
        end
        local v882 = nil
        pcall(function()
            v882 = v9.Remotes.Killers.Veil.Spearthrow
        end)
        local v883 = v9:FindFirstChild("Remotes")
        local v884 = v883 and v9.Remotes:FindFirstChild("Mechanics") and v9.Remotes.Mechanics:FindFirstChild("Fall")
        local v891 = function(a76, a77, a78, a79)
            local v885 = math.max(a78, 0.1)
            local v886 = a76 * a76
            local v887 = v886 * v886 - a77 * (a77 * v885 * v885 + 2 * a79 * v886)
            local v888 = v887
            if v887 < 0 then
                v888 = 0
            end
            local v889 = (v886 - math.sqrt(v888)) / (a77 * v885)
            local v890 = math.atan(v889)
            return v890, v885 / (a76 * math.cos(v890))
        end
        local v892 = getrawmetatable(game)
        setreadonly(v892, false)
        local v893 = v892.__namecall
        v892.__namecall = newcclosure(function(a80, ...)
            local v894 = getnamecallmethod()
            local v895 = v894 == "FireServer" or v894 == "fireServer" or v894 == "InvokeServer"
            if v895 and not checkcaller() and typeof(a80) == "Instance" then
                if _G.Ox.NoFall.Enabled and v884 and a80 == v884 then
                    local v896 = {...}
                    v896[1] = 0
                    return v893(a80, unpack(v896))
                end
                if _G.Ox.AntiBlindEnabled and _G.Ox.GotBlindedRemote and a80 == _G.Ox.GotBlindedRemote and v4.Team and v4.Team.Name == "Killer" then
                    return nil
                end
                if _G.Ox.BulletBlockConfig.Enabled and a80.Name == "Fire" then
                    local v897 = a80.Parent
                    if v897 and v897.Name == "Twist of Fate" then
                        return nil
                    end
                end
                if _G.Ox.KILLER_SilentAimFlask and a80.Name == "ThrowFlask" then
                    local v898 = {...}
                    local v899 = nil
                    local v900 = math.huge
                    local v901 = v4.Character
                    local v902 = v901 and v4.Character:FindFirstChild("HumanoidRootPart") and v4.Character.HumanoidRootPart.Position
                    if v902 then
                        for v907, v908 in pairs(v3:GetPlayers()) do
                            if v908 ~= v4 and v908.Character and v908.Character:FindFirstChild("HumanoidRootPart") and not IsKiller(v908) then
                                local v909 = (v908.Character.HumanoidRootPart.Position - v902).Magnitude
                                if v909 < v900 then
                                    v900 = v909
                                    v899 = v908
                                end
                            end
                        end
                    end
                    if v899 and v898[2] and typeof(v898[2]) == "Vector3" then
                        v898[1] = (v899.Character.HumanoidRootPart.Position - v898[2]).Unit
                        setnamecallmethod(v894)
                        return v893(a80, unpack(v898))
                    end
                end
                if v894 == "FireServer" and typeof(a80) == "Instance" and string.lower(tostring(a80.Name)) == "updatecharacterlook" then
                    local v910 = _G.Ox
                    local v911 = v910 and _G.Ox.Utility and _G.Ox.Utility.InvisEnabled
                    if v911 then
                        local v912 = {}
                        for v917, v918 in ipairs({...}) do
                            if typeof(v918) == "CFrame" then
                                v912[v917] = v918 * CFrame.new(0, 5000, 0)
                            else
                                v912[v917] = v918
                            end
                        end
                        return v893(a80, unpack(v912))
                    end
                end
                if a80.ClassName == "RemoteEvent" and a80.Name == "Spearthrow" and _G.Ox.AimConfig.Aim_SilentVeilV2 and not v377 then
                    local v919 = v4.Character
                    local v920 = v919 and v919:FindFirstChild("HumanoidRootPart")
                    local v921 = v919
                    if v919 then
                        local v922 = v919:FindFirstChild("Head")
                        v921 = v922 or v920
                    end
                    local v923 = v919 and v919:GetAttribute("special") == true
                    local v926, v929
                    if v923 then
                        local v924 = _G.Ox.AimConfig.SPEAR_AuraSpeed
                        local v925 = v924 or 165
                        v926 = v925
                        local v927 = _G.Ox.AimConfig.SPEAR_AuraGravity
                        local v928 = v927 or 96.5
                        v929 = v928
                    else
                        local v930 = _G.Ox.AimConfig.SPEAR_Speed
                        local v931 = v930 or 165
                        v926 = v931
                        local v932 = _G.Ox.AimConfig.SPEAR_Gravity
                        local v933 = v932 or 103
                        v929 = v933
                    end
                    local v934 = v926
                    local v935 = (select(3, ...))
                    if not (select(3, ...)) then
                        local v936 = _G.Ox.Config.SpearSmart_enable
                        v935 = v936 and v920 and v920.Position
                    end
                    if not v935 then
                        v935 = v921 and v921.Position
                    end
                    local v937 = v935
                    local v938 = (...)
                    local v939 = getClosestSurvivor()
                    if v939 and v937 then
                        local v940 = v939:IsA("Model")
                        local v941 = v940 and v939:FindFirstChild("HumanoidRootPart") or v939
                        local v942 = v941.Position
                        local v943 = Vector3.new(0, 0, 0)
                        local v944 = v939.Parent
                        local v945 = v944 and v939.Parent:FindFirstChildOfClass("Humanoid")
                        if v945 and v945.MoveDirection.Magnitude > 0 then
                            v943 = v945.MoveDirection * v945.WalkSpeed
                        elseif v941:IsA("BasePart") then
                            v943 = v941.AssemblyLinearVelocity
                        end
                        local v946 = Vector3.new(v943.X, 0, v943.Z)
                        local v947 = v942 - v937
                        local v948 = v947.Magnitude
                        local v949 = Vector3.new(v947.X, 0, v947.Z).Magnitude
                        local v950 = v947.Y
                        if v948 > 0.1 then
                            local v951 = _G.Ox.AimConfig.SPEAR_MaxDist
                            local v952 = v951 or 1000
                            if v948 <= v952 then
                                local v953 = _G.Ox.AimConfig.Veil_LeadMultiplier
                                local v954 = v953 or 1.4
                                local v956, v955 = v891(v926, v929, v949, v950)
                                if _G.Ox.Config.SpearSmart_enable and v946.Magnitude > 0.5 then
                                    local v957 = v946 * (v955 * v954)
                                    local v958 = v957
                                    local v959 = math.clamp(v948 * 0.6, 3, 45)
                                    if v959 < v957.Magnitude then
                                        v958 = v957.Unit * v959
                                    end
                                    local v960 = v942 + v958 - v937
                                    local v961 = Vector3.new(v960.X, 0, v960.Z).Magnitude
                                    local v962 = select(1, v891(v926, v929, math.max(v961, 0.1), v960.Y))
                                    if v961 > 0.001 then
                                        v938 = Vector3.new(v960.X, 0, v960.Z).Unit * math.cos(v962) + Vector3.new(0, math.sin(v962), 0)
                                    else
                                        v938 = v960.Unit
                                    end
                                else
                                    local v963 = select(1, v891(v926, v929, math.max(v949, 0.1), v950))
                                    if v949 > 0.001 then
                                        v938 = Vector3.new(v947.X, 0, v947.Z).Unit * math.cos(v963) + Vector3.new(0, math.sin(v963), 0)
                                    else
                                        v938 = v947.Unit
                                    end
                                end
                            end
                        end
                    end
                    v377 = true
                    pcall(function()
                        if v882 then
                            v882:FireServer(v938, v934, v937)
                        else
                            a80:FireServer(v938, v934, v937)
                        end
                    end)
                    v377 = false
                    return
                end
            end
            return v893(a80, ...)
        end)
        setreadonly(v892, true)
        v378 = true
    end
    local v967 = function()
        local v964 = v9:FindFirstChild("Remotes")
        local v965 = v964 and v9.Remotes:FindFirstChild("Items")
        local v966 = v965 and v965:FindFirstChild("Flashlight")
        if v966 then
            _G.Ox.GotBlindedRemote = v966:FindFirstChild("GotBlinded")
        end
    end
    task.spawn(function()
        task.wait(1)
        v967()
        setupSpearInterceptor()
    end)
    v4.CharacterAdded:Connect(function()
        task.wait(1)
        v967()
    end)
end
local v969, v996, v1003, v1836, v1863, v1876, v1882, v1892, v1910, v1931, v2013, v2067
do
    local v968 = Connections
    v969 = v968 or {}
    v996 = function()
        if v969.LeapBypass then
            task.cancel(v969.LeapBypass)
            v969.LeapBypass = nil
        end
        v969.LeapBypass = task.spawn(function()
            local v970, v971, v972, v973, v974, v975, v976, v977, v978, v979, v980, v981, v982, v983, v984, v985, v986, v987, v988, v989
            local v990, v991, v992, v993, v994, v995
            v995 = 1
            while true do
                if v995 == 1 then
                    v970 = nil
                    v971 = nil
                    v972, v973, v974 = pairs(getgc(true))
                    v975 = v974
                    v995 = 2
                elseif v995 == 2 then
                    v976, v977 = v972(v973, v975)
                    if v976 == nil then
                        v995 = 9
                    else
                        v995 = 3
                    end
                elseif v995 == 3 then
                    v975 = v976
                    if type(v977) == "function" and islclosure(v977) then
                        v995 = 4
                    else
                        v995 = 2
                    end
                elseif v995 == 4 then
                    v978 = debug.getinfo(v977)
                    if v978.name == "tryActivate" then
                        v995 = 5
                    else
                        v995 = 6
                    end
                elseif v995 == 5 then
                    v970 = v977
                    v995 = 6
                elseif v995 == 6 then
                    if v978.name == "playM2Animation" then
                        v995 = 7
                    else
                        v995 = 8
                    end
                elseif v995 == 7 then
                    v971 = v977
                    v995 = 8
                elseif v995 == 8 then
                    if v970 and v971 then
                        v995 = 9
                    else
                        v995 = 2
                    end
                elseif v995 == 9 then
                    if not v970 and not v971 then
                        v995 = 20
                    else
                        v995 = 10
                    end
                elseif v995 == 10 then
                    if task.wait(0.1) and _G.Ox.BypassLeapEnabled then
                        v995 = 12
                    else
                        v995 = 11
                    end
                elseif v995 == 11 then
                    return
                elseif v995 == 12 then
                    v979, v980, v981 = pairs({v970, v971})
                    v982 = v981
                    v983 = v979
                    v984 = v980
                    v995 = 13
                elseif v995 == 13 then
                    v985, v986 = v983(v984, v982)
                    if v985 == nil then
                        v995 = 10
                    else
                        v995 = 14
                    end
                elseif v995 == 14 then
                    v982 = v985
                    if v986 then
                        v995 = 15
                    else
                        v995 = 13
                    end
                elseif v995 == 15 then
                    v987, v988, v989 = pairs(debug.getupvalues(v986))
                    v990 = v983
                    v991 = v984
                    v992 = v989
                    v995 = 16
                elseif v995 == 16 then
                    v993, v994 = v987(v988, v992)
                    if v993 == nil then
                        v995 = 19
                    else
                        v995 = 17
                    end
                elseif v995 == 17 then
                    v992 = v993
                    if type(v994) == "boolean" and v994 == true then
                        v995 = 18
                    else
                        v995 = 16
                    end
                elseif v995 == 18 then
                    debug.setupvalue(v986, v993, false)
                    v995 = 16
                elseif v995 == 19 then
                    v982 = v985
                    v983 = v990
                    v984 = v991
                    v995 = 13
                elseif v995 == 20 then
                    warn("[BypassLeap] Function tidak ditemukan.")
                    return
                end
            end
        end)
    end
    local v997 = false
    local v1001 = function()
        if GetRole() ~= "Killer" then
            return
        end
        local v998 = v4:FindFirstChild("SelectedKiller")
        local v999 = v998 and v998.Value or v4:GetAttribute("SelectedKiller")
        if v999 and string.find(string.lower(tostring(v999)), "abyss") then
            pcall(function()
                local v1000 = v9:FindFirstChild("Remotes"):FindFirstChild("Killers"):FindFirstChild("Abysswalker"):FindFirstChild("corrupt")
                if v1000 then
                    v1000:FireServer()
                end
            end)
        end
    end
    local v1002 = function()
        if v997 then
            return
        end
        v997 = true
        task.spawn(function()
            while v997 and _G.Ox.InfAbyssalEnabled and GetRole() == "Killer" do
                v1001()
                task.wait(0.5)
            end
        end)
    end
    v1003 = function()
        v997 = false
    end
    v6.InputBegan:Connect(function(a81, a82)
        if a82 then
            return
        end
        if _G.Ox.InfAbyssalEnabled and a81.KeyCode == Enum.KeyCode.Q then
            v1002()
        end
    end)
    v6.InputEnded:Connect(function(a83)
        if a83.KeyCode == Enum.KeyCode.Q then
            v1003()
        end
    end)
    task.spawn(function()
        while _G.Ox.ScriptAlive do
            task.wait(0.5)
            if not _G.Ox.ScriptAlive then
                break
            end
            if _G.Ox.InfAbyssalEnabled and GetRole() == "Killer" then
                local v1004 = v4:FindFirstChild("PlayerGui")
                if v1004 then
                    local v1005 = nil
                    for v1010, v1011 in pairs(v1004:GetChildren()) do
                        if string.sub(v1011.Name, -4) == "-mob" and v1011.Name ~= "Survivor-mob" then
                            v1005 = v1011
                            break
                        end
                    end
                    if v1005 then
                        local v1012 = v1005:FindFirstChild("Controls")
                        if v1012 then
                            local v1013 = v1012:FindFirstChild("move2")
                            if v1013 and v1013.Visible then
                                v1002()
                            else
                                v1003()
                            end
                        end
                    end
                end
            else
                v1003()
            end
        end
    end)
    EnableInfiniteLunge = function()
        _G.Ox.InfiniteLungeEnabled = true
        local v1014 = v4.Character
        if v1014 then
            v1014:SetAttribute("lungeboost", 999)
            if _G.Ox.InfLungeAttrConn then
                _G.Ox.InfLungeAttrConn:Disconnect()
            end
            _G.Ox.InfLungeAttrConn = v1014:GetAttributeChangedSignal("lungeboost"):Connect(function()
                if _G.Ox.InfiniteLungeEnabled and v1014:GetAttribute("lungeboost") ~= 999 then
                    v1014:SetAttribute("lungeboost", 999)
                end
            end)
        end
        v1:Notify({
            Title = "Infinite Lunge",
            Description = "AKTIF (999x)",
            Duration = 3,
        })
    end
    DisableInfiniteLunge = function()
        _G.Ox.InfiniteLungeEnabled = false
        if _G.Ox.InfLungeAttrConn then
            _G.Ox.InfLungeAttrConn:Disconnect()
            _G.Ox.InfLungeAttrConn = nil
        end
        local v1015 = v4.Character
        if v1015 then
            v1015:SetAttribute("lungeboost", 1)
        end
        v1:Notify({
            Title = "Infinite Lunge",
            Description = "NONAKTIF",
            Duration = 2,
        })
    end
    v4.CharacterAdded:Connect(function(a84)
        task.wait(0.8)
        if _G.Ox.InfiniteLungeEnabled and a84 then
            a84:SetAttribute("lungeboost", 999)
        end
    end)
    StopCounterParry = function()
        _G.Ox.CounterParry.Enabled = false
        if _G.Ox.CounterParry.Thread then
            task.cancel(_G.Ox.CounterParry.Thread)
            _G.Ox.CounterParry.Thread = nil
        end
        if _G.Ox.CounterParry.Track then
            pcall(function()
                _G.Ox.CounterParry.Track:Stop()
            end)
            _G.Ox.CounterParry.Track = nil
        end
    end
    StartCounterParry = function()
        if _G.Ox.CounterParry.Thread then
            return
        end
        _G.Ox.CounterParry.Thread = task.spawn(function()
            local v1016, v1017, v1018, v1019, v1020, v1021, v1022, v1023, v1024, v1025, v1026, v1027, v1028, v1029, v1030, v1031, v1032, v1033
            v1033 = 1
            while true do
                if v1033 == 1 then
                    if _G.Ox.CounterParry.Enabled and _G.Ox.ScriptAlive then
                        v1033 = 3
                    else
                        v1033 = 2
                    end
                elseif v1033 == 2 then
                    _G.Ox.CounterParry.Thread = nil
                    return
                elseif v1033 == 3 then
                    v1016 = v4.Character
                    if v1016 and v1016.Parent and GetRole() == "Killer" then
                        v1033 = 5
                    else
                        v1033 = 4
                    end
                elseif v1033 == 4 then
                    task.wait(0.4)
                    v1033 = 1
                elseif v1033 == 5 then
                    v1017 = v1016:FindFirstChildOfClass("Humanoid")
                    v1018 = v1017
                    if v1017 then
                        v1033 = 6
                    else
                        v1033 = 7
                    end
                elseif v1033 == 6 then
                    v1018 = v1017:FindFirstChildOfClass("Animator")
                    v1033 = 7
                elseif v1033 == 7 then
                    v1019 = v1016:FindFirstChild("HumanoidRootPart")
                    if v1018 and v1019 then
                        v1033 = 9
                    else
                        v1033 = 8
                    end
                elseif v1033 == 8 then
                    task.wait(0.3)
                    v1033 = 1
                elseif v1033 == 9 then
                    if _G.Ox.CounterParry.Track and _G.Ox.CounterParry.Track.Parent ~= nil then
                        v1033 = 13
                    else
                        v1033 = 10
                    end
                elseif v1033 == 10 then
                    v1020 = Instance.new("Animation")
                    v1020.AnimationId = _G.Ox.CounterParry.AnimId
                    v1021, v1022 = pcall(function()
                        return v1018:LoadAnimation(v1020)
                    end)
                    if v1021 and v1022 then
                        v1033 = 12
                    else
                        v1033 = 11
                    end
                elseif v1033 == 11 then
                    task.wait(0.5)
                    v1033 = 1
                elseif v1033 == 12 then
                    _G.Ox.CounterParry.Track = v1022
                    v1033 = 13
                elseif v1033 == 13 then
                    v1023 = false
                    v1024 = _G.Ox.CounterParry.Distance
                    v1025, v1026, v1027 = ipairs(v3:GetPlayers())
                    v1028 = v1027
                    v1033 = 14
                elseif v1033 == 14 then
                    v1029, v1030 = v1025(v1026, v1028)
                    if v1029 == nil then
                        v1033 = 20
                    else
                        v1033 = 15
                    end
                elseif v1033 == 15 then
                    v1028 = v1029
                    if v1030 ~= v4 and v1030.Team and v1030.Team.Name == "Survivors" then
                        v1033 = 16
                    else
                        v1033 = 14
                    end
                elseif v1033 == 16 then
                    v1031 = v1030.Character
                    v1032 = v1031
                    if v1031 then
                        v1033 = 17
                    else
                        v1033 = 18
                    end
                elseif v1033 == 17 then
                    v1032 = v1030.Character:FindFirstChild("HumanoidRootPart")
                    v1033 = 18
                elseif v1033 == 18 then
                    if v1032 and (v1019.Position - v1032.Position).Magnitude <= v1024 then
                        v1033 = 19
                    else
                        v1033 = 14
                    end
                elseif v1033 == 19 then
                    v1023 = true
                    v1033 = 20
                elseif v1033 == 20 then
                    if v1023 and _G.Ox.CounterParry.Track then
                        v1033 = 21
                    else
                        v1033 = 22
                    end
                elseif v1033 == 21 then
                    pcall(function()
                        _G.Ox.CounterParry.Track:Play()
                        _G.Ox.CounterParry.Track:AdjustWeight(0)
                    end)
                    task.wait(0.05)
                    pcall(function()
                        _G.Ox.CounterParry.Track:Stop()
                    end)
                    v1033 = 22
                elseif v1033 == 22 then
                    task.wait(_G.Ox.CounterParry.Interval)
                    v1033 = 1
                end
            end
        end)
    end
    ToggleCounterParry = function(a85)
        if a85 then
            if GetRole() ~= "Killer" then
                v1:Notify({
                    Title = "Counter Auto Parry",
                    Description = "Khusus Killer!",
                    Duration = 3,
                })
                _G.Ox.CounterParry.Enabled = false
                if CounterParryToggle then
                    v384(CounterParryToggle, false)
                end
                return
            end
            _G.Ox.CounterParry.Enabled = true
            StartCounterParry()
            v1:Notify({
                Title = "Counter Auto Parry",
                Description = "AKTIF",
                Duration = 2,
            })
        else
            StopCounterParry()
            v1:Notify({
                Title = "Counter Auto Parry",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    v4.CharacterAdded:Connect(function()
        _G.Ox.CounterParry.Track = nil
        task.wait(1)
        if _G.Ox.CounterParry.Enabled then
            StartCounterParry()
        end
    end)
    local v1038 = function()
        local v1034 = v9:FindFirstChild("Remotes")
        local v1035 = v1034 and v1034:FindFirstChild("Killers")
        local v1036 = v1035 and v1035:FindFirstChild("Stalker")
        local v1037 = v1036 and v1036:FindFirstChild("StartStalking")
        return v1037
    end
    local v1053 = function()
        local v1039 = v4.Character
        local v1040 = v1039 and v4.Character:FindFirstChild("HumanoidRootPart")
        if not v1040 then
            return nil
        end
        local v1041 = nil
        local v1042 = math.huge
        local v1043 = _G.Ox.AutoStalk.Range
        for v1048, v1049 in ipairs(v3:GetPlayers()) do
            if v1049 ~= v4 and v1049.Character then
                local v1050 = v1049.Character:FindFirstChildOfClass("Humanoid")
                local v1051 = v1049.Character:FindFirstChild("HumanoidRootPart")
                if v1050 and v1051 and v1050.Health > 30 then
                    local v1052 = (v1051.Position - v1040.Position).Magnitude
                    if v1052 <= v1043 and v1052 < v1042 then
                        v1042 = v1052
                        v1041 = v1049
                    end
                end
            end
        end
        return v1041
    end
    StopAutoStalk = function()
        _G.Ox.AutoStalk.Enabled = false
        if _G.Ox.AutoStalk.Conn then
            _G.Ox.AutoStalk.Conn:Disconnect()
            _G.Ox.AutoStalk.Conn = nil
        end
    end
    StartAutoStalk = function()
        if _G.Ox.AutoStalk.Conn then
            return
        end
        _G.Ox.AutoStalk.Conn = v5.Heartbeat:Connect(function()
            if not _G.Ox.AutoStalk.Enabled or not _G.Ox.ScriptAlive then
                return
            end
            if GetRole() ~= "Killer" then
                return
            end
            local v1054 = tick()
            local v1055 = _G.Ox.AutoStalk.LastFire
            local v1056 = v1055 or 0
            if v1054 - v1056 < 0.35 then
                return
            end
            local v1057 = v1053()
            if not v1057 or not v1057.Character then
                return
            end
            local v1058 = v1038()
            if v1058 then
                _G.Ox.AutoStalk.LastFire = v1054
                pcall(function()
                    v1058:FireServer(v1057)
                end)
            end
        end)
    end
    ToggleAutoStalk = function(a86)
        if a86 then
            if GetRole() ~= "Killer" then
                v1:Notify({
                    Title = "Auto Stalk",
                    Description = "Khusus Killer!",
                    Duration = 3,
                })
                _G.Ox.AutoStalk.Enabled = false
                if AutoStalkToggle then
                    v384(AutoStalkToggle, false)
                end
                return
            end
            _G.Ox.AutoStalk.Enabled = true
            StartAutoStalk()
            v1:Notify({Title = "Auto Stalk", Description = "AKTIF", Duration = 2})
        else
            StopAutoStalk()
            v1:Notify({
                Title = "Auto Stalk",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    local v1059 = Instance.new("ScreenGui")
    v1059.Name = "FOVCircleGui_Standalone"
    v1059.ResetOnSpawn = false
    v1059.IgnoreGuiInset = true
    v1059.Parent = v10
    local v1060 = Instance.new("Frame")
    v1060.BackgroundTransparency = 1
    v1060.AnchorPoint = Vector2.new(0.5, 0.5)
    v1060.Position = UDim2.new(0.5, 0, 0.5, 0)
    v1060.Visible = false
    v1060.Parent = v1059
    Instance.new("UICorner", v1060).CornerRadius = UDim.new(1, 0)
    local v1061 = Instance.new("UIStroke", v1060)
    v1061.Color = Color3.fromRGB(255, 255, 255)
    v1061.Thickness = 1.5
    local v1062 = Instance.new("Highlight")
    v1062.Name = "VD_VeilTarget"
    v1062.FillColor = Color3.fromRGB(255, 0, 0)
    v1062.OutlineColor = Color3.fromRGB(255, 255, 255)
    v1062.FillTransparency = 0.5
    v1062.OutlineTransparency = 0
    local v1063 = nil
    local v1064 = function()
        if v1063 then
            pcall(function()
                v1063:Destroy()
            end)
            v1063 = nil
        end
    end
    local v1069 = function(a87, a88)
        if a87 and a88 then
            local v1065 = (a88 - a87).Magnitude
            if v1065 < 0.2 then
                if v1063 then
                    v1063.Transparency = 1
                end
                return
            end
            if not v1063 then
                local v1066 = Instance.new("Part")
                v1066.Name = "VeilTrackerLine"
                v1066.Anchored = true
                v1066.CanCollide = false
                v1066.CanTouch = false
                v1066.CanQuery = false
                v1066.CastShadow = false
                v1066.Material = Enum.Material.Neon
                v1066.Color = Color3.fromRGB(255, 255, 255)
                v1066.Parent = workspace
                v1063 = v1066
            end
            local v1067 = Vector3.new(0.08, 0.08, v1065)
            v1063.Size = v1067
            local v1068 = CFrame.new((a87 + a88) / 2, a88)
            v1063.CFrame = v1068
            v1063.Transparency = 0.15
            return
        end
        if v1063 then
            v1063.Transparency = 1
        end
    end
    _G.Ox.SurvivorFOVGui = Instance.new("ScreenGui")
    _G.Ox.SurvivorFOVGui.Name = "SurvivorAimbotFOV"
    _G.Ox.SurvivorFOVGui.ResetOnSpawn = false
    _G.Ox.SurvivorFOVGui.IgnoreGuiInset = true
    _G.Ox.SurvivorFOVGui.Parent = v10
    _G.Ox.SurvivorFOVFrame = Instance.new("Frame")
    _G.Ox.SurvivorFOVFrame.BackgroundTransparency = 1
    _G.Ox.SurvivorFOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    _G.Ox.SurvivorFOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    _G.Ox.SurvivorFOVFrame.Visible = false
    _G.Ox.SurvivorFOVFrame.Parent = _G.Ox.SurvivorFOVGui
    Instance.new("UICorner", _G.Ox.SurvivorFOVFrame).CornerRadius = UDim.new(1, 0)
    local v1070 = Instance.new("UIStroke", _G.Ox.SurvivorFOVFrame)
    v1070.Color = Color3.fromRGB(255, 255, 255)
    v1070.Thickness = 1.5
    v1070.Transparency = 0.5
    _G.Ox.survivorAimbotHighlight = Instance.new("Highlight")
    _G.Ox.survivorAimbotHighlight.Name = "SurvivorAimbotTarget"
    _G.Ox.survivorAimbotHighlight.FillColor = Color3.fromRGB(255, 0, 0)
    _G.Ox.survivorAimbotHighlight.OutlineColor = Color3.fromRGB(255, 255, 0)
    _G.Ox.survivorAimbotHighlight.FillTransparency = 0.4
    _G.Ox.survivorAimbotHighlight.OutlineTransparency = 0.2
    _G.Ox.killerAimbotHighlight = Instance.new("Highlight")
    _G.Ox.killerAimbotHighlight.Name = "KillerAimbotTarget"
    _G.Ox.killerAimbotHighlight.FillColor = Color3.fromRGB(255, 0, 0)
    _G.Ox.killerAimbotHighlight.OutlineColor = Color3.fromRGB(255, 255, 0)
    _G.Ox.killerAimbotHighlight.FillTransparency = 0.4
    _G.Ox.killerAimbotHighlight.OutlineTransparency = 0.2
    StopMoonwalk = function()
        _G.Ox.Moonwalk.Enabled = false
        local v1071 = v4.Character
        local v1072 = v1071 and v1071:FindFirstChildOfClass("Humanoid")
        if v1072 then
            v1072.AutoRotate = true
        end
    end
    StartMoonwalk = function()
        local v1073 = v4.Character
        local v1074 = v1073 and v1073:FindFirstChild("HumanoidRootPart")
        local v1075 = v1073 and v1073:FindFirstChildOfClass("Humanoid")
        if not v1074 or not v1075 then
            return
        end
        v1075.AutoRotate = false
        _G.Ox.Moonwalk.Enabled = true
    end
    UpdateMoonwalkGUI = function(a89)
        if not _G.Ox.Moonwalk.Gui then
            return
        end
        local v1076 = _G.Ox.Moonwalk.Gui:FindFirstChild("Frame")
        if not v1076 then
            return
        end
        local v1077 = v1076:FindFirstChild("ActionButton")
        local v1078 = v1076:FindFirstChild("UIStroke")
        if a89 then
            if v1077 then
                v1077.Text = "MOON [ON]"
                v1077.TextColor3 = Color3.fromRGB(180, 255, 180)
                v1077.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            end
            if v1078 then
                v1078.Color = Color3.fromRGB(100, 200, 100)
            end
        else
            if v1077 then
                v1077.Text = "MOON [OFF]"
                v1077.TextColor3 = Color3.fromRGB(200, 200, 200)
                v1077.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            end
            if v1078 then
                v1078.Color = Color3.fromRGB(90, 90, 95)
            end
        end
    end
    ToggleMoonwalkStatus = function()
        if _G.Ox.Moonwalk.Enabled then
            StopMoonwalk()
        else
            StartMoonwalk()
        end
        _G.Ox.Moonwalk.IsActive = _G.Ox.Moonwalk.Enabled
        UpdateMoonwalkGUI(_G.Ox.Moonwalk.Enabled)
        if MoonwalkPCToggle then
            v384(MoonwalkPCToggle, _G.Ox.Moonwalk.Enabled)
        end
        local v1079 = v1.Notify
        local v1080 = {Title = "Moonwalk"}
        local v1081 = _G.Ox.Moonwalk.Enabled
        local v1082 = v1081 and "AKTIF" or "NONAKTIF"
        v1080.Description = v1082
        v1080.Duration = 2
        v1079(v1, v1080)
    end
    CreateMoonwalkGUI = function()
        if _G.Ox.Moonwalk.Gui then
            _G.Ox.Moonwalk.Gui:Destroy()
        end
        local v1083 = Instance.new("ScreenGui")
        v1083.Name = "MoonwalkCustomGui"
        v1083.ResetOnSpawn = false
        v1083.IgnoreGuiInset = true
        v1083.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        v1083.Parent = v10
        v1083.Enabled = false
        _G.Ox.Moonwalk.Gui = v1083
        _G.Ox.Moonwalk.GuiVisible = false
        local v1084 = Instance.new("Frame", v1083)
        v1084.Name = "Frame"
        v1084.Size = UDim2.fromOffset(110, 36)
        v1084.Position = UDim2.fromScale(0.85, 0.45)
        v1084.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        v1084.BackgroundTransparency = 0.1
        v1084.Active = true
        v1084.BorderSizePixel = 0
        Instance.new("UICorner", v1084).CornerRadius = UDim.new(0, 8)
        local v1085 = Instance.new("UIStroke", v1084)
        v1085.Name = "UIStroke"
        v1085.Color = Color3.fromRGB(90, 90, 95)
        v1085.Thickness = 1.5
        v1085.Transparency = 0.2
        local v1086 = Instance.new("TextButton", v1084)
        v1086.Name = "ActionButton"
        v1086.Size = UDim2.new(1, 0, 1, 0)
        v1086.Text = "MOON [OFF]"
        v1086.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        v1086.Font = Enum.Font.GothamBold
        v1086.TextSize = 12
        v1086.TextColor3 = Color3.fromRGB(200, 200, 200)
        v1086.BorderSizePixel = 0
        v1086.AutoButtonColor = false
        Instance.new("UICorner", v1086).CornerRadius = UDim.new(0, 8)
        local v1087 = false
        local v1088 = false
        local v1089 = false
        local v1090 = nil
        local v1091 = nil
        local v1092 = nil
        local v1094 = function(a90)
            if not v1087 or not v1089 or not v1090 or not v1091 then
                return
            end
            local v1093 = a90.Position - v1090
            if not v1088 and (math.abs(v1093.X) > 18 or math.abs(v1093.Y) > 18) then
                v1088 = true
            end
            if v1088 then
                v1084.Position = UDim2.new(v1091.X.Scale, v1091.X.Offset + v1093.X, v1091.Y.Scale, v1091.Y.Offset + v1093.Y)
            end
        end
        v1086.InputBegan:Connect(function(a91)
            if a91.UserInputType == Enum.UserInputType.MouseButton1 or a91.UserInputType == Enum.UserInputType.Touch then
                v1087 = true
                v1088 = false
                v1089 = false
                v1090 = a91.Position
                v1091 = v1084.Position
                if v1092 then
                    task.cancel(v1092)
                end
                v1092 = task.delay(0.18, function()
                    if v1087 then
                        v1089 = true
                    end
                end)
            end
        end)
        v1086.InputEnded:Connect(function(a92)
            if a92.UserInputType == Enum.UserInputType.MouseButton1 or a92.UserInputType == Enum.UserInputType.Touch then
                if v1092 then
                    task.cancel(v1092)
                end
                if v1087 and not v1088 then
                    ToggleMoonwalkStatus()
                end
                v1087 = false
                v1088 = false
                v1089 = false
                v1090 = nil
                v1091 = nil
            end
        end)
        v6.InputChanged:Connect(function(a93)
            if v1087 and v1089 and (a93.UserInputType == Enum.UserInputType.MouseMovement or a93.UserInputType == Enum.UserInputType.Touch) then
                v1094(a93)
            end
        end)
        if _G.Ox.Moonwalk._statusConn then
            _G.Ox.Moonwalk._statusConn:Disconnect()
        end
        _G.Ox.Moonwalk._statusConn = v5.Heartbeat:Connect(function()
            if _G.Ox.Moonwalk.Gui and _G.Ox.Moonwalk.Gui.Parent then
                if _G.Ox.Moonwalk.IsActive ~= _G.Ox.Moonwalk.Enabled then
                    _G.Ox.Moonwalk.IsActive = _G.Ox.Moonwalk.Enabled
                    UpdateMoonwalkGUI(_G.Ox.Moonwalk.Enabled)
                end
                return
            end
            if _G.Ox.Moonwalk._statusConn then
                _G.Ox.Moonwalk._statusConn:Disconnect()
            end
        end)
    end
    v4.CharacterAdded:Connect(function()
        task.wait(1)
        if _G.Ox.Moonwalk.Enabled then
            StartMoonwalk()
        end
        if _G.Ox.Moonwalk.GuiVisible and _G.Ox.Moonwalk.Gui then
            _G.Ox.Moonwalk.Gui.Enabled = true
            UpdateMoonwalkGUI(_G.Ox.Moonwalk.Enabled)
        end
    end)
    task.spawn(function()
        task.wait(1.5)
        CreateMoonwalkGUI()
    end)
    v5.RenderStepped:Connect(function(a94)
        if not _G.Ox.Speed.Enabled and not _G.Ox.Moonwalk.Enabled and not _G.Ox.Crosshair.Enabled and not _G.Ox.StretchRes.Enabled and not _G.Ox.Config.Surv_Aimbot_Enabled and (not _G.Ox.Config.Killer_Aimbot_Enabled or not _G.Ox.isKillerAimbotHolding) and not _G.Ox.AimConfig.Aim_SilentVeilV2 and (not v379 or not _G.Ox.AimConfig.Flash_Silent) then
            return
        end
        if _G.Ox.Crosshair.Enabled then
            DrawCrosshair()
        end
        if _G.Ox.Speed.Enabled then
            local v1095 = v4.Character
            if v1095 then
                local v1096 = v1095:FindFirstChildOfClass("Humanoid")
                if v1096 then
                    local v1097 = v1096.MoveDirection
                    if v1097.Magnitude > 0 then
                        local v1098 = v1095:FindFirstChild("HumanoidRootPart")
                        if v1098 then
                            local v1099 = (_G.Ox.Speed.Value - 0.1) * 10
                            if v1099 > 0 then
                                v1098.CFrame = v1098.CFrame + v1097 * v1099 * a94
                            end
                        end
                    end
                end
            end
        end
        if _G.Ox.Moonwalk.Enabled then
            local v1100 = v4.Character
            local v1101 = v1100 and v1100:FindFirstChild("HumanoidRootPart")
            local v1102 = v1100 and v1100:FindFirstChildOfClass("Humanoid")
            local v1103 = workspace.CurrentCamera
            if v1101 and v1102 and v1103 then
                if v1102.AutoRotate ~= false then
                    v1102.AutoRotate = false
                end
                local v1104 = Vector3.new(v1103.CFrame.LookVector.X, 0, v1103.CFrame.LookVector.Z)
                local v1105 = v1104
                local v1106 = Vector3.new(v1103.CFrame.RightVector.X, 0, v1103.CFrame.RightVector.Z)
                local v1107 = v1106
                if v1104.Magnitude > 0.001 then
                    v1105 = v1104.Unit
                end
                if v1106.Magnitude > 0.001 then
                    v1107 = v1106.Unit
                end
                local v1108 = math.sin(tick() * 35)
                local v1109 = CFrame.Angles(0, math.rad(30 * v1108), 0) * v1105
                v1101.CFrame = CFrame.lookAt(v1101.Position, v1101.Position + v1109)
                v1102:Move(-v1105 * 1.2 + v1107 * (v1108 * 1.05), false)
            end
        end
        if _G.Ox.StretchRes.Enabled and v12 then
            v12.CFrame = v12.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, _G.Ox.StretchRes.Amount, 0, 0, 0, 1)
        end
        if v379 and _G.Ox.AimConfig.Flash_Silent then
            local v1110 = getKillerTargetForFlash()
            if v1110 then
                local v1111 = v4.Character
                local v1112 = v1111 and v1111:FindFirstChild("HumanoidRootPart")
                local v1113 = v1110.Position + Vector3.new(0, _G.Ox.AimConfig.Flash_YOffset, 0)
                local v1114 = workspace.CurrentCamera
                v1114.CFrame = v1114.CFrame:Lerp(CFrame.lookAt(v1114.CFrame.Position, v1113), 0.5)
                if v1112 then
                    local v1115 = CFrame.lookAt(v1112.Position, Vector3.new(v1113.X, v1112.Position.Y, v1113.Z))
                    v1112.CFrame = v1112.CFrame:Lerp(v1115, 0.5)
                end
            end
        end
        if _G.Ox.Config.Surv_Aimbot_Enabled then
            if GetRole() == "Survivor" then
                if _G.Ox.Config.Surv_Aimbot_ShowFOV then
                    _G.Ox.SurvivorFOVFrame.Visible = true
                    _G.Ox.SurvivorFOVFrame.Size = UDim2.new(0, _G.Ox.Config.Surv_Aimbot_Radius * 2, 0, _G.Ox.Config.Surv_Aimbot_Radius * 2)
                else
                    _G.Ox.SurvivorFOVFrame.Visible = false
                end
                local v1116 = getBestAimbotTarget()
                if v1116 then
                    _G.Ox.survivorAimbotHighlight.Parent = v1116.Parent
                    local v1117 = v1116.Position
                    local v1118 = v1117
                    local v1119 = GetDistance(v1117)
                    if v1119 < 100 then
                        v1118 = v1117 + v12.CFrame.RightVector * ((100 - v1119) * _G.Ox.Config.Surv_Aimbot_Predict)
                    end
                    local v1120 = CFrame.new(v12.CFrame.Position, v1118)
                    v12.CFrame = v12.CFrame:Lerp(v1120, _G.Ox.Config.Surv_Aimbot_Smoothness)
                    local v1121 = v4.Character
                    local v1122 = v1121 and v1121:FindFirstChild("HumanoidRootPart")
                    if v1122 then
                        local v1123 = CFrame.new(v1122.Position, Vector3.new(v1118.X, v1122.Position.Y, v1118.Z))
                        v1122.CFrame = v1122.CFrame:Lerp(v1123, _G.Ox.Config.Surv_Aimbot_Smoothness)
                    end
                else
                    _G.Ox.survivorAimbotHighlight.Parent = nil
                end
            end
        else
            _G.Ox.SurvivorFOVFrame.Visible = false
            _G.Ox.survivorAimbotHighlight.Parent = nil
        end
        if _G.Ox.Config.Killer_Aimbot_Enabled and _G.Ox.isKillerAimbotHolding then
            if GetRole() == "Killer" then
                if _G.Ox.lockedKillerAimbotTarget then
                    local v1124 = _G.Ox.lockedKillerAimbotTarget.Parent
                    local v1125 = v1124 and v1124:FindFirstChild("Humanoid")
                    if not v1125 or v1125.Health <= 0 or IsDowned(v1124) then
                        _G.Ox.lockedKillerAimbotTarget = getBestKillerAimbotTarget()
                    end
                    if _G.Ox.lockedKillerAimbotTarget then
                        local v1126 = _G.Ox.lockedKillerAimbotTarget.Position
                        local v1127 = GetDistance(v1126)
                        if _G.Ox.Config.Killer_Aimbot_MaxDist < v1127 then
                            _G.Ox.lockedKillerAimbotTarget = getBestKillerAimbotTarget()
                        else
                            _G.Ox.killerAimbotHighlight.Parent = v1124
                            local v1128 = CFrame.new(v12.CFrame.Position, v1126)
                            v12.CFrame = v12.CFrame:Lerp(v1128, _G.Ox.Config.Killer_Aimbot_Smoothness)
                            local v1129 = v4.Character
                            local v1130 = v1129 and v1129:FindFirstChild("HumanoidRootPart")
                            if v1130 then
                                local v1131 = CFrame.new(v1130.Position, Vector3.new(v1126.X, v1130.Position.Y, v1126.Z))
                                v1130.CFrame = v1130.CFrame:Lerp(v1131, _G.Ox.Config.Killer_Aimbot_Smoothness)
                            end
                        end
                    end
                else
                    _G.Ox.lockedKillerAimbotTarget = getBestKillerAimbotTarget()
                end
            end
        elseif _G.Ox.killerAimbotHighlight then
            _G.Ox.killerAimbotHighlight.Parent = nil
        end
        local v1132 = v4.Character
        local v1133 = v1132 and v1132:GetAttribute("spearmode") == true
        local v1134 = _G.Ox.AimConfig.Aim_SilentVeilV2
        local v1135 = v1134 and v1133
        local v1136 = v1135 and _G.Ox.AimConfig.Veil_ShowFOV
        if v1136 then
            v1060.Visible = true
            v1060.Size = UDim2.new(0, _G.Ox.AimConfig.Veil_FOV * 2, 0, _G.Ox.AimConfig.Veil_FOV * 2)
        else
            v1060.Visible = false
        end
        if v1136 then
            local v1137 = getClosestSurvivor()
            if v1137 and v1137.Parent then
                v1062.Parent = v1137.Parent
                local v1138 = v1132 and v1132:FindFirstChild("HumanoidRootPart")
                local v1139 = v1132
                if v1132 then
                    local v1140 = v1132:FindFirstChild("Head")
                    v1139 = v1140 or v1138
                end
                local v1141 = v1139 and v1139.Position
                v1069(v1141, v1137.Position)
            else
                v1062.Parent = nil
                v1069(nil, nil)
            end
        else
            v1062.Parent = nil
            v1069(nil, nil)
            if not v1135 then
                v1064()
            end
        end
    end)
    local v1142 = 0
    v5.Heartbeat:Connect(function()
        if _G.Ox.ParryConfig.ParryCircle and _G.Ox.ParryConfig.AutoParry then
            local v1143 = v4.Character
            local v1144 = v1143 and v1143:FindFirstChild("HumanoidRootPart")
            if v1144 then
                if not _G.Ox.State.AutoParryAdornment or _G.Ox.State.AutoParryAdornment.Parent ~= v1144 then
                    if _G.Ox.State.AutoParryAdornment then
                        _G.Ox.State.AutoParryAdornment:Destroy()
                    end
                    _G.Ox.State.AutoParryAdornment = Instance.new("CylinderHandleAdornment")
                    _G.Ox.State.AutoParryAdornment.Name = "AutoParryCircleESP"
                    _G.Ox.State.AutoParryAdornment.Height = 0.05
                    _G.Ox.State.AutoParryAdornment.Transparency = 0.3
                    _G.Ox.State.AutoParryAdornment.Adornee = v1144
                    _G.Ox.State.AutoParryAdornment.Parent = v1144
                    _G.Ox.State.AutoParryAdornment.ZIndex = 0
                    _G.Ox.State.AutoParryAdornment.AlwaysOnTop = false
                end
                local v1145 = _G.Ox.ParryConfig.ParryRadius
                _G.Ox.State.AutoParryAdornment.Radius = v1145
                _G.Ox.State.AutoParryAdornment.InnerRadius = math.max(0.1, v1145 - 0.15)
                _G.Ox.State.AutoParryAdornment.CFrame = CFrame.new(0, -3, 0) * CFrame.Angles(math.rad(90), 0, 0)
                if _G.Ox.State.ParryCooldown then
                    _G.Ox.State.AutoParryAdornment.Color3 = Color3.fromRGB(255, 128, 0)
                elseif _G.Ox.ParryConfig.ParryAggressive then
                    _G.Ox.State.AutoParryAdornment.Color3 = Color3.fromRGB(255, 0, 0)
                else
                    _G.Ox.State.AutoParryAdornment.Color3 = Color3.fromRGB(255, 255, 255)
                end
            elseif _G.Ox.State.AutoParryAdornment then
                _G.Ox.State.AutoParryAdornment:Destroy()
                _G.Ox.State.AutoParryAdornment = nil
            end
        elseif _G.Ox.State.AutoParryAdornment then
            _G.Ox.State.AutoParryAdornment:Destroy()
            _G.Ox.State.AutoParryAdornment = nil
        end
        if _G.Ox.GodMode then
            local v1146 = v4.Character
            if v1146 then
                local v1147 = v1146:FindFirstChildOfClass("Humanoid")
                if v1147 and v1147.Health < v1147.MaxHealth then
                    v1147.Health = v1147.MaxHealth
                end
            end
        end
        if _G.Ox.AutoPallet.Enabled then
            for v1152 in pairs(_G.Ox.AutoPallet.UsedPallets) do
                if not v1152 or not v1152.Parent then
                    _G.Ox.AutoPallet.UsedPallets[v1152] = nil
                end
            end
        end
        if _G.Ox.CameraFOV.Enabled then
            v12.FieldOfView = _G.Ox.CameraFOV.Value
        end
        if _G.Ox.NoSlowdownEnabled then
            local v1153 = v4.Character
            if v1153 then
                local v1154 = v1153:FindFirstChildOfClass("Humanoid")
                if v1154 and GetRole() == "Killer" and v1154.WalkSpeed < 16 then
                    v1154.WalkSpeed = 16
                end
            end
        end
        if _G.Ox.ESPConfig.Master and tick() - v1142 >= 2 then
            v1142 = tick()
            UpdatePlayerESP()
            UpdateSCPESP()
            UpdateStaticESP()
        end
    end)
    local v1155 = v9:WaitForChild("Items", 5)
    extractAssetId = function(a95)
        return tostring(a95):match("%d+")
    end
    getItemIcon = function(a96)
        if not v1155 then
            return nil
        end
        local v1156 = v1155:FindFirstChild(a96)
        if not v1156 then
            return nil
        end
        local v1157 = nil
        pcall(function()
            local v1158 = v1156.Texture
            local v1159 = v1158 or v1156.Image
            v1157 = v1159
        end)
        if v1157 and v1157 ~= "" then
            local v1160 = extractAssetId(v1157)
            if v1160 then
                return string.format("rbxthumb://type=Asset&id=%s&w=420&h=420", v1160)
            end
        end
        return nil
    end
    CreateModernESP = function(a97, a98, a99)
        if not a97 then
            return
        end
        local v1161 = a99.name
        local v1162 = v1161 or ""
        local v1163 = v1162 ~= ""
        local v1164 = a98 ~= "PE_Text"
        if not v1164 then
            if v1163 then
                v1164 = false
            else
                v1164 = true
            end
        end
        local v1165 = v1164 and "single" or "multi"
        local v1166 = a99.infoRich
        local v1167 = v1166 or ""
        if v1167 == "" then
            local v1168 = {}
            if a99.subtext and a99.subtext ~= "" then
                table.insert(v1168, tostring(a99.subtext))
            end
            if a99.distance then
                table.insert(v1168, tostring(a99.distance) .. "m")
            end
            v1167 = table.concat(v1168, " <font color=\"#888888\">·</font> ")
        end
        local v1169 = a97:FindFirstChild(a98)
        local v1170 = v1169
        if v1169 and v1169:GetAttribute("Layout") ~= v1165 then
            v1169:Destroy()
            v1170 = nil
        end
        if not v1170 then
            local v1171 = Instance.new("BillboardGui")
            v1170 = v1171
            v1171.Name = a98
            v1171.AlwaysOnTop = true
            v1171:SetAttribute("Layout", v1165)
            local v1172 = v1164 and UDim2.new(0, 220, 0, 22) or UDim2.new(0, 220, 0, 34)
            v1171.Size = v1172
            local v1173 = Vector3.new
            local v1174 = a99.offsetY
            local v1175 = v1174 or 4
            v1171.StudsOffset = v1173(0, v1175, 0)
            v1171.Parent = a97
            local v1176 = Instance.new("Frame")
            v1176.Name = "Box"
            v1176.BackgroundTransparency = 1
            v1176.Size = UDim2.new(1, 0, 1, 0)
            v1176.AnchorPoint = Vector2.new(0.5, 0.5)
            v1176.Position = UDim2.new(0.5, 0, 0.5, 0)
            v1176.Parent = v1171
            if a99.noDistScale then
                v1171:SetAttribute("NoDistScale", true)
            else
                local v1177 = Instance.new("UIScale")
                v1177.Name = "DistScale"
                v1177.Scale = 1
                v1177.Parent = v1176
            end
            if v1164 then
                local v1178 = Instance.new("UIListLayout", v1176)
                v1178.FillDirection = Enum.FillDirection.Horizontal
                v1178.HorizontalAlignment = Enum.HorizontalAlignment.Center
                v1178.VerticalAlignment = Enum.VerticalAlignment.Center
                v1178.Padding = UDim.new(0, 4)
                local v1179 = Instance.new("ImageLabel")
                v1179.Name = "Icon"
                v1179.BackgroundTransparency = 1
                v1179.Size = UDim2.new(0, 14, 0, 14)
                v1179.Visible = false
                v1179.Parent = v1176
                local v1180 = Instance.new("TextLabel")
                v1180.Name = "Text"
                v1180.BackgroundTransparency = 1
                v1180.AutomaticSize = Enum.AutomaticSize.XY
                v1180.Font = Enum.Font.GothamBold
                v1180.TextSize = 12
                v1180.TextWrapped = false
                v1180.TextYAlignment = Enum.TextYAlignment.Center
                v1180.RichText = true
                v1180.TextStrokeTransparency = 0
                v1180.TextStrokeColor3 = Color3.new(0, 0, 0)
                v1180.Parent = v1176
            else
                local v1181 = Instance.new("UIListLayout", v1176)
                v1181.FillDirection = Enum.FillDirection.Vertical
                v1181.HorizontalAlignment = Enum.HorizontalAlignment.Center
                v1181.VerticalAlignment = Enum.VerticalAlignment.Center
                v1181.Padding = UDim.new(0, 0)
                local v1182 = Instance.new("Frame")
                v1182.Name = "Row1"
                v1182.BackgroundTransparency = 1
                v1182.AutomaticSize = Enum.AutomaticSize.XY
                v1182.Size = UDim2.new(0, 0, 0, 16)
                v1182.Parent = v1176
                local v1183 = Instance.new("UIListLayout", v1182)
                v1183.FillDirection = Enum.FillDirection.Horizontal
                v1183.HorizontalAlignment = Enum.HorizontalAlignment.Center
                v1183.VerticalAlignment = Enum.VerticalAlignment.Center
                v1183.Padding = UDim.new(0, 4)
                local v1184 = Instance.new("ImageLabel")
                v1184.Name = "Icon"
                v1184.BackgroundTransparency = 1
                v1184.Size = UDim2.new(0, 14, 0, 14)
                v1184.Visible = false
                v1184.Parent = v1182
                local v1185 = Instance.new("TextLabel")
                v1185.Name = "Name"
                v1185.BackgroundTransparency = 1
                v1185.AutomaticSize = Enum.AutomaticSize.XY
                v1185.Font = Enum.Font.GothamBold
                v1185.TextSize = 12
                v1185.TextWrapped = false
                v1185.TextYAlignment = Enum.TextYAlignment.Center
                v1185.TextStrokeTransparency = 0
                v1185.TextStrokeColor3 = Color3.new(0, 0, 0)
                v1185.Parent = v1182
                local v1186 = Instance.new("TextLabel")
                v1186.Name = "Info"
                v1186.BackgroundTransparency = 1
                v1186.AutomaticSize = Enum.AutomaticSize.XY
                v1186.Font = Enum.Font.GothamBold
                v1186.TextSize = 11
                v1186.TextWrapped = false
                v1186.TextYAlignment = Enum.TextYAlignment.Center
                v1186.RichText = true
                v1186.TextStrokeTransparency = 0
                v1186.TextStrokeColor3 = Color3.new(0, 0, 0)
                v1186.Parent = v1176
            end
        end
        local v1187 = v1170:FindFirstChild("Box")
        if v1164 then
            local v1188 = v1187 and v1187:FindFirstChild("Text")
            local v1189 = v1187 and v1187:FindFirstChild("Icon")
            if v1188 then
                local v1190 = "#FFFFFF"
                if a99.color then
                    v1190 = string.format("#%02X%02X%02X", math.floor(a99.color.R * 255), math.floor(a99.color.G * 255), math.floor(a99.color.B * 255))
                end
                local v1191 = tostring
                local v1192 = v1162 or ""
                local v1193 = v1191(v1192):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
                local v1194 = ""
                if v1163 then
                    v1194 = string.format("<font color=\"%s\">%s</font>", v1190, v1193)
                end
                if v1167 ~= "" then
                    if v1194 == "" then
                        v1194 = v1167
                    elseif a99.noSeparator then
                        v1194 = v1194 .. " " .. v1167
                    else
                        v1194 = v1194 .. " <font color=\"#888888\">·</font> " .. v1167
                    end
                end
                v1188.Text = v1194
            end
            if v1189 then
                if a99.icon and a99.icon ~= "" then
                    v1189.Image = a99.icon
                    v1189.Visible = true
                else
                    v1189.Visible = false
                end
            end
        else
            local v1195 = v1187 and v1187:FindFirstChild("Row1")
            local v1196 = v1195 and v1195:FindFirstChild("Name")
            local v1197 = v1195 and v1195:FindFirstChild("Icon")
            local v1198 = v1187 and v1187:FindFirstChild("Info")
            if v1196 then
                v1196.Text = tostring(v1162):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
                local v1199 = a99.color
                local v1200 = v1199 or Color3.new(1, 1, 1)
                v1196.TextColor3 = v1200
            end
            if v1197 then
                if a99.icon and a99.icon ~= "" then
                    v1197.Image = a99.icon
                    v1197.Visible = true
                else
                    v1197.Visible = false
                end
            end
            if v1198 then
                if v1167 == "" then
                    v1198.Visible = false
                else
                    v1198.Visible = true
                    v1198.Text = v1167
                end
            end
        end
    end
    local v1203 = function()
        local v1201 = v4.Team
        local v1202 = v1201 and v4.Team.Name == "Survivors"
        return v1202
    end
    local v1212 = function(a100)
        local v1204 = a100:FindFirstChildOfClass("Humanoid")
        if not v1204 then
            return false
        end
        local v1205 = v1204:FindFirstChildOfClass("Animator")
        if not v1205 then
            return false
        end
        for v1210, v1211 in ipairs(v1205:GetPlayingAnimationTracks()) do
            if v1211.Animation and string.find(tostring(v1211.Animation.AnimationId), "126081405469607") then
                return true
            end
        end
        return false
    end
    local v1214 = function(a101)
        if not _G.Ox.FakePerks.QuickRecoveryEnabled then
            return
        end
        if not v1203() then
            return
        end
        if _G.Ox.FakePerks.boostActive then
            return
        end
        if tick() - _G.Ox.FakePerks.lastQRTime < _G.Ox.FakePerks.PerkCooldown then
            return
        end
        _G.Ox.FakePerks.boostActive = true
        _G.Ox.FakePerks.lastQRTime = tick()
        local v1213 = tick()
        task.spawn(function()
            while _G.Ox.FakePerks.QuickRecoveryEnabled and tick() - v1213 < 3 do
                if a101 and a101.Parent then
                    a101:SetAttribute("speedboost", 1.4)
                end
                task.wait()
            end
            if a101 and a101.Parent then
                a101:SetAttribute("speedboost", 1)
            end
            _G.Ox.FakePerks.boostActive = false
        end)
    end
    local v1217 = function(a102)
        if _G.Ox.FakePerks.qrConnection then
            _G.Ox.FakePerks.qrConnection:Disconnect()
            _G.Ox.FakePerks.qrConnection = nil
        end
        if not a102 then
            return
        end
        _G.Ox.FakePerks.qrConnection = a102:GetAttributeChangedSignal("isvaulting"):Connect(function()
            if a102:GetAttribute("isvaulting") == true then
                task.spawn(function()
                    task.wait(0.05)
                    local v1215 = v1212(a102)
                    local v1216 = v1215
                    if not v1215 then
                        task.wait(0.05)
                        v1216 = v1212(a102)
                    end
                    if not v1216 and a102:GetAttribute("isvaulting") == true then
                        v1214(a102)
                    end
                end)
            end
        end)
    end
    ToggleQuickRecovery = function(a103)
        _G.Ox.FakePerks.QuickRecoveryEnabled = a103
        if a103 and v4.Character then
            v1217(v4.Character)
        elseif not a103 and _G.Ox.FakePerks.qrConnection then
            _G.Ox.FakePerks.qrConnection:Disconnect()
            _G.Ox.FakePerks.qrConnection = nil
        end
        local v1218 = v1.Notify
        local v1219 = {Title = "Fake Quick Recovery"}
        local v1220 = a103 and "AKTIF" or "NONAKTIF"
        v1219.Description = v1220
        v1219.Duration = 2
        v1218(v1, v1219)
    end
    local v1222 = function(a104)
        if not _G.Ox.FakePerks.PerfectLandingEnabled then
            return
        end
        if not v1203() then
            return
        end
        if _G.Ox.FakePerks.perfectLandingBoostActive then
            return
        end
        if tick() - _G.Ox.FakePerks.lastPLTime < _G.Ox.FakePerks.PerkCooldown then
            return
        end
        _G.Ox.FakePerks.perfectLandingBoostActive = true
        _G.Ox.FakePerks.lastPLTime = tick()
        local v1221 = tick()
        task.spawn(function()
            while _G.Ox.FakePerks.perfectLandingBoostActive and tick() - v1221 < 3 do
                if a104 and a104.Parent then
                    a104:SetAttribute("speedboost", 1.4)
                end
                task.wait()
            end
            if a104 and a104.Parent then
                a104:SetAttribute("speedboost", 1)
            end
            _G.Ox.FakePerks.perfectLandingBoostActive = false
        end)
    end
    local v1223 = function(a105)
        if _G.Ox.FakePerks.plConnection then
            _G.Ox.FakePerks.plConnection:Disconnect()
            _G.Ox.FakePerks.plConnection = nil
        end
        if not a105 then
            return
        end
        _G.Ox.FakePerks.plConnection = a105:GetAttributeChangedSignal("speedboost"):Connect(function()
            if not v1203() then
                return
            end
            if a105:GetAttribute("speedboost") == 0.625 then
                v1222(a105)
            end
        end)
    end
    TogglePerfectLanding = function(a106)
        _G.Ox.FakePerks.PerfectLandingEnabled = a106
        if a106 then
            if v4.Character then
                v1223(v4.Character)
            end
        else
            if _G.Ox.FakePerks.plConnection then
                _G.Ox.FakePerks.plConnection:Disconnect()
                _G.Ox.FakePerks.plConnection = nil
            end
            if _G.Ox.FakePerks.perfectLandingBoostActive and v4.Character then
                v4.Character:SetAttribute("speedboost", 1)
                _G.Ox.FakePerks.perfectLandingBoostActive = false
            end
        end
        local v1224 = v1.Notify
        local v1225 = {Title = "Fake Perfect Landing"}
        local v1226 = a106 and "AKTIF" or "NONAKTIF"
        v1225.Description = v1226
        v1225.Duration = 2
        v1224(v1, v1225)
    end
    local v1232 = function(a107)
        if _G.Ox.FakePerks.fsConnection then
            _G.Ox.FakePerks.fsConnection:Disconnect()
            _G.Ox.FakePerks.fsConnection = nil
        end
        if _G.Ox.FakePerks.fsAnimConnection then
            _G.Ox.FakePerks.fsAnimConnection:Disconnect()
            _G.Ox.FakePerks.fsAnimConnection = nil
        end
        if not a107 then
            return
        end
        local v1227 = a107:WaitForChild("Humanoid", 3)
        if not v1227 then
            return
        end
        local v1228 = v1227:WaitForChild("Animator", 3)
        if not v1228 then
            return
        end
        _G.Ox.FakePerks.fsAnimConnection = v1228.AnimationPlayed:Connect(function(a108)
            if not a108.Animation then
                return
            end
            if a108.Animation.AnimationId ~= "rbxassetid://136962284480779" then
                return
            end
            local v1229 = nil
            v1229 = a108.Stopped:Connect(function()
                if v1229 then
                    v1229:Disconnect()
                end
                _G.Ox.FakePerks.lastFSTime = tick()
                _G.Ox.FakePerks.fsOnCooldown = true
                if a107 and a107.Parent then
                    a107:SetAttribute("Flowstate", false)
                end
                task.delay(_G.Ox.FakePerks.PerkCooldown, function()
                    _G.Ox.FakePerks.fsOnCooldown = false
                    if _G.Ox.FakePerks.FlowstateEnabled and a107 and a107.Parent then
                        a107:SetAttribute("Flowstate", true)
                    end
                end)
            end)
        end)
        _G.Ox.FakePerks.fsConnection = a107:GetAttributeChangedSignal("Flowstate"):Connect(function()
            if not _G.Ox.FakePerks.FlowstateEnabled then
                return
            end
            if not v1203() then
                return
            end
            local v1230 = a107:GetAttribute("Flowstate")
            if v1230 == true then
                if _G.Ox.FakePerks.fsOnCooldown or tick() - _G.Ox.FakePerks.lastFSTime < _G.Ox.FakePerks.PerkCooldown then
                    a107:SetAttribute("Flowstate", false)
                end
            elseif v1230 == false and not _G.Ox.FakePerks.fsOnCooldown then
                local v1231 = tick() - _G.Ox.FakePerks.lastFSTime
                if _G.Ox.FakePerks.PerkCooldown <= v1231 then
                    a107:SetAttribute("Flowstate", true)
                end
            end
        end)
        task.wait(0.5)
        if _G.Ox.FakePerks.FlowstateEnabled and a107 and a107.Parent then
            a107:SetAttribute("Flowstate", true)
        end
    end
    ToggleFlowstate = function(a109)
        _G.Ox.FakePerks.FlowstateEnabled = a109
        if a109 then
            if v4.Character then
                v1232(v4.Character)
            end
        else
            if _G.Ox.FakePerks.fsConnection then
                _G.Ox.FakePerks.fsConnection:Disconnect()
                _G.Ox.FakePerks.fsConnection = nil
            end
            if _G.Ox.FakePerks.fsAnimConnection then
                _G.Ox.FakePerks.fsAnimConnection:Disconnect()
                _G.Ox.FakePerks.fsAnimConnection = nil
            end
            if v4.Character then
                v4.Character:SetAttribute("Flowstate", false)
            end
        end
        local v1233 = v1.Notify
        local v1234 = {Title = "Fake Flowstate"}
        local v1235 = a109 and "AKTIF" or "NONAKTIF"
        v1234.Description = v1235
        v1234.Duration = 2
        v1233(v1, v1234)
    end
    local v1243 = function()
        local v1236 = _G.Ox.FakePerks.adrenalineConns
        if not v1236 then
            return
        end
        for v1241, v1242 in ipairs(v1236) do
            pcall(function()
                v1242:Disconnect()
            end)
        end
        _G.Ox.FakePerks.adrenalineConns = {}
    end
    local v1248 = function(a110)
        if not _G.Ox.FakePerks.FakeAdrenalineRush then
            return
        end
        if not v1203() then
            return
        end
        if not a110 or not a110.Parent then
            return
        end
        if _G.Ox.FakePerks.boostActive then
            return
        end
        local v1244 = tick()
        local v1245 = _G.Ox.FakePerks.lastARTime
        local v1246 = v1245 or 0
        if v1244 - v1246 < _G.Ox.FakePerks.PerkCooldown then
            return
        end
        _G.Ox.FakePerks.boostActive = true
        _G.Ox.FakePerks.lastARTime = tick()
        local v1247 = tick()
        task.spawn(function()
            while _G.Ox.FakePerks.FakeAdrenalineRush and tick() - v1247 < 5 do
                if a110 and a110.Parent then
                    a110:SetAttribute("speedboost", 1.4)
                end
                task.wait()
            end
            if a110 and a110.Parent then
                a110:SetAttribute("speedboost", 1)
            end
            _G.Ox.FakePerks.boostActive = false
        end)
    end
    local v1252 = function(a111)
        if not a111 then
            return
        end
        local v1249 = a111:FindFirstChildOfClass("Humanoid")
        local v1250 = v1249 or a111:WaitForChild("Humanoid", 5)
        if not v1250 then
            return
        end
        local v1251 = v1250.Health
        table.insert(_G.Ox.FakePerks.adrenalineConns, v1250.HealthChanged:Connect(function(a112)
            if not _G.Ox.FakePerks.FakeAdrenalineRush then
                return
            end
            if a112 < v1251 and a112 <= 50 and a112 > 0 then
                v1248(a111)
            end
            v1251 = a112
        end))
    end
    SetupFakeAdrenalineRush = function(a113)
        local v1253 = _G.Ox.FakePerks
        local v1254 = a113 == true
        v1253.FakeAdrenalineRush = v1254
        local v1255 = _G.Ox.FakePerks
        local v1256 = a113 == true
        v1255.adrenalineOn = v1256
        v1243()
        if not a113 then
            v1:Notify({
                Title = "Fake Perks",
                Description = "Adrenaline Rush OFF",
                Duration = 2,
            })
            return
        end
        v1252(v4.Character)
        table.insert(_G.Ox.FakePerks.adrenalineConns, v4.CharacterAdded:Connect(function(a114)
            task.wait(0.3)
            if _G.Ox.FakePerks.FakeAdrenalineRush then
                v1252(a114)
            end
        end))
        v1:Notify({
            Title = "Fake Perks",
            Description = "Adrenaline Rush ON",
            Duration = 3,
        })
    end
    local v1257 = function(a115)
        task.wait(0.5)
        if _G.Ox.FakePerks.QuickRecoveryEnabled then
            v1217(a115)
        end
        if _G.Ox.FakePerks.PerfectLandingEnabled then
            v1223(a115)
        end
        if _G.Ox.FakePerks.FlowstateEnabled then
            v1232(a115)
        end
        if _G.Ox.FakePerks.FakeAdrenalineRush then
            v1252(a115)
        end
    end
    if v4.Character then
        v1257(v4.Character)
    end
    v4.CharacterAdded:Connect(v1257)
    local v1289 = function()
        if not _G.Ox.StreamerMode.Enabled then
            return
        end
        local v1258 = v4:FindFirstChild("PlayerGui")
        if not v1258 then
            return
        end
        local v1281 = function(a116)
            if not a116:IsA("TextLabel") and not a116:IsA("TextButton") and not a116:IsA("TextBox") then
                if a116:IsA("ImageLabel") or a116:IsA("ImageButton") then
                    local v1279 = function()
                        if not _G.Ox.StreamerMode.Enabled then
                            return
                        end
                        local v1271 = a116.Image
                        local v1272 = false
                        for v1277, v1278 in ipairs(v3:GetPlayers()) do
                            if string.find(v1271, tostring(v1278.UserId)) then
                                if not a116:GetAttribute("OriginalImage") then
                                    a116:SetAttribute("OriginalImage", v1271)
                                end
                                v1272 = true
                                break
                            end
                            continue
                        end
                        if v1272 and a116.Image ~= "rbxassetid://118755181202304" then
                            a116.Image = "rbxassetid://118755181202304"
                        end
                    end
                    v1279()
                    local v1280 = a116:GetPropertyChangedSignal("Image"):Connect(v1279)
                    table.insert(_G.Ox.StreamerMode.SpooferConns, v1280)
                end
            else
                local v1269 = function()
                    if not _G.Ox.StreamerMode.Enabled then
                        return
                    end
                    local v1259 = a116.Text
                    local v1260 = v1259
                    local v1261 = false
                    if not a116:GetAttribute("OriginalText") then
                        a116:SetAttribute("OriginalText", v1259)
                    end
                    for v1266, v1267 in ipairs(v3:GetPlayers()) do
                        if string.find(v1260, v1267.Name) or string.find(v1260, v1267.DisplayName) then
                            local v1268 = string.gsub(v1260, v1267.Name, "FEBZ")
                            v1260 = string.gsub(v1268, v1267.DisplayName, "FEBZ")
                            v1261 = true
                        end
                    end
                    if v1261 and a116.Text ~= v1260 then
                        a116.Text = v1260
                    end
                end
                v1269()
                local v1270 = a116:GetPropertyChangedSignal("Text"):Connect(v1269)
                table.insert(_G.Ox.StreamerMode.SpooferConns, v1270)
            end
        end
        for v1286, v1287 in ipairs(v1258:GetDescendants()) do
            v1281(v1287)
        end
        local v1288 = v1258.DescendantAdded:Connect(function(a117)
            task.defer(function()
                v1281(a117)
            end)
        end)
        table.insert(_G.Ox.StreamerMode.SpooferConns, v1288)
    end
    local v1305 = function()
        for v1294, v1295 in ipairs(_G.Ox.StreamerMode.SpooferConns) do
            if v1295.Connected then
                v1295:Disconnect()
            end
        end
        table.clear(_G.Ox.StreamerMode.SpooferConns)
        local v1296 = v4:FindFirstChild("PlayerGui")
        if v1296 then
            for v1301, v1302 in ipairs(v1296:GetDescendants()) do
                if not v1302:IsA("TextLabel") and not v1302:IsA("TextButton") and not v1302:IsA("TextBox") then
                    if v1302:IsA("ImageLabel") or v1302:IsA("ImageButton") then
                        local v1304 = v1302:GetAttribute("OriginalImage")
                        if v1304 then
                            v1302.Image = v1304
                            v1302:SetAttribute("OriginalImage", nil)
                        end
                    end
                else
                    local v1303 = v1302:GetAttribute("OriginalText")
                    if v1303 then
                        v1302.Text = v1303
                        v1302:SetAttribute("OriginalText", nil)
                    end
                end
            end
        end
    end
    local v1306 = function(a118)
        _G.Ox.StreamerMode.Enabled = a118
        if a118 then
            v1289()
            v1:Notify({
                Title = "Streamer Mode",
                Description = "AKTIF - Nama player disembunyikan",
                Duration = 3,
            })
        else
            v1305()
            v1:Notify({
                Title = "Streamer Mode",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    v4.CharacterAdded:Connect(function()
        task.wait(1)
        if _G.Ox.StreamerMode.Enabled then
            v1305()
            v1064()
            task.wait(0.5)
            v1289()
        end
    end)
    v11.ChildAdded:Connect(function()
        task.wait(0.5)
        if _G.Ox.StreamerMode.Enabled then
            v1289()
        end
    end)
    local v1310 = function(a119)
        _G.Ox.StretchRes.Enabled = a119
        local v1307 = v1.Notify
        local v1308 = {Title = "Stretch Res"}
        local v1309 = a119 and "AKTIF" or "NONAKTIF"
        v1308.Description = v1309
        v1308.Duration = 2
        v1307(v1, v1308)
    end
    local v1311 = {}
    UpdateHookData = function()
        for v1316, v1317 in pairs(v3:GetPlayers()) do
            if v1317 ~= v4 and v1317.Team and v1317.Team.Name == "Survivors" then
                local v1318 = v1317:GetAttribute("HookCount")
                local v1319 = v1318 or 0
                v1311[v1317.Name] = v1319
            end
        end
    end
    CreateHookESP = function(a120, a121)
        if not _G.Ox.ESPConfig.HookCount then
            return
        end
        local v1320 = "HookESP_" .. a120.Name
        local v1321 = a120:FindFirstChild(v1320)
        if v1321 then
            v1321:Destroy()
        end
        local v1322 = Instance.new("BillboardGui")
        v1322.Name = v1320
        v1322.Parent = a120
        v1322.AlwaysOnTop = true
        v1322.Size = UDim2.new(0, 40, 0, 14)
        v1322.StudsOffset = Vector3.new(0, 5.5, 0)
        local v1323 = Instance.new("TextLabel")
        v1323.Size = UDim2.new(1, 0, 1, 0)
        v1323.BackgroundTransparency = 1
        v1323.Font = Enum.Font.GothamBold
        v1323.TextSize = 11
        v1323.TextScaled = true
        v1323.Text = string.format("Hooked %d", a121)
        v1323.TextXAlignment = Enum.TextXAlignment.Center
        v1323.TextYAlignment = Enum.TextYAlignment.Center
        v1323.Parent = v1322
        if a121 >= 3 then
            v1323.TextColor3 = Color3.fromRGB(255, 50, 50)
        elseif a121 >= 2 then
            v1323.TextColor3 = Color3.fromRGB(255, 200, 50)
        else
            v1323.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        local v1324 = Instance.new("UIStroke")
        v1324.Color = Color3.fromRGB(0, 0, 0)
        v1324.Thickness = 2
        v1324.Transparency = 0.5
        v1324.Parent = v1323
    end
    local v1325 = {
        "rbxassetid://120434965879067",
        "rbxassetid://81511619438196",
        "rbxassetid://130571419892864",
    }
    CreateHookUICounter = function(a122, a123)
        if not a122 then
            return
        end
        local v1326 = tonumber(a123)
        local v1327 = v1326 or 0
        local v1328 = v1327
        local v1329 = a122:FindFirstChild("Febz_HookCounter")
        local v1330 = v1329
        if v1328 <= 0 then
            if v1329 then
                v1329:Destroy()
            end
            return
        end
        local v1331 = v1325[math.clamp(v1328, 1, 3)]
        if not v1331 then
            return
        end
        if not v1329 then
            local v1332 = Instance.new("ImageLabel")
            v1330 = v1332
            v1332.Name = "Febz_HookCounter"
            v1332.BackgroundTransparency = 1
            local v1333 = a122.ZIndex
            local v1334 = v1333 or 1
            v1332.ZIndex = v1334 + 1
            v1332.Parent = a122
        end
        v1330.Size = UDim2.new(0.509, 0, 0.51, 0)
        v1330.Position = UDim2.new(0.91, 0, 0.18, 0)
        v1330.AnchorPoint = Vector2.new(0.5, 0.5)
        v1330.Image = v1331
        v1330.ScaleType = Enum.ScaleType.Fit
    end
    UpdateHookUICounter = function()
        if GetRole() == "Killer" then
            local v1335 = v4:FindFirstChild("PlayerGui")
            if not v1335 then
                return
            end
            local v1336 = function(a124)
                if a124 and type(a124) == "string" then
                    return tonumber(a124:match("id=(%d+)"))
                end
                return nil
            end
            local v1337, v1338, v1339 = ipairs(v1335:GetChildren())
            local v1340 = v1339
            local v1341 = v1337
            local v1342 = v1338
            while true do
                local v1343, v1344 = v1341(v1342, v1340)
                if v1343 == nil then
                    break
                end
                v1340 = v1343
                if typeof(v1344) == "Instance" then
                    local v1345 = v1344:FindFirstChild("Frame")
                    if v1345 and v1345:IsA("Frame") then
                        for v1352, v1353 in ipairs(v1345:GetChildren()) do
                            local v1354 = v1353:FindFirstChild("ImageLabel")
                            if v1354 then
                                local v1355 = v1353:GetAttribute("UserId")
                                local v1356 = v1355 or v1336(v1354.Image)
                                local v1357 = v1356 and v3:GetPlayerByUserId(tonumber(v1356)) or nil
                                if v1357 and v1357 ~= v4 and v1357.Team and v1357.Team.Name == "Survivors" then
                                    local v1358 = v1311[v1357.Name]
                                    local v1359 = v1358 or v1357:GetAttribute("HookCount") or 0
                                    CreateHookUICounter(v1354, v1359)
                                else
                                    local v1360 = v1354:FindFirstChild("Febz_HookCounter")
                                    if v1360 then
                                        v1360:Destroy()
                                    end
                                end
                            end
                        end
                        v1340 = v1343
                    end
                end
            end
            return
        end
        ClearHookUICounter()
    end
    ClearHookUICounter = function()
        local v1361 = v4:FindFirstChild("PlayerGui")
        if not v1361 then
            return
        end
        local v1362, v1363, v1364 = ipairs(v1361:GetChildren())
        local v1365 = v1364
        local v1366 = v1362
        local v1367 = v1363
        while true do
            local v1368, v1369 = v1366(v1367, v1365)
            if v1368 == nil then
                break
            end
            v1365 = v1368
            if typeof(v1369) == "Instance" then
                local v1370 = v1369:FindFirstChild("Frame")
                if v1370 and v1370:IsA("Frame") then
                    for v1377, v1378 in ipairs(v1370:GetChildren()) do
                        local v1379 = v1378:FindFirstChild("ImageLabel")
                        local v1380 = v1379 and v1379:FindFirstChild("Febz_HookCounter")
                        if v1380 then
                            v1380:Destroy()
                        end
                    end
                    v1365 = v1368
                end
            end
        end
    end
    UpdateHookESP = function()
        if not _G.Ox.ESPConfig.HookCount then
            ClearHookESP()
        end
    end
    ClearHookESP = function()
        local v1381, v1382, v1383 = pairs(v3:GetPlayers())
        local v1384 = v1383
        local v1385 = v1381
        local v1386 = v1382
        while true do
            local v1387, v1388 = v1385(v1386, v1384)
            if v1387 == nil then
                break
            end
            v1384 = v1387
            if v1388.Character then
                for v1395, v1396 in pairs(v1388.Character:GetChildren()) do
                    if string.match(v1396.Name, "^HookESP_") then
                        v1396:Destroy()
                    end
                end
                v1384 = v1387
            end
        end
    end
    ClearESP = function(a125)
        if a125 == "Player" then
            for v1443, v1444 in pairs(v3:GetPlayers()) do
                if v1444.Character then
                    if v1444.Character:FindFirstChild("PEH") then
                        v1444.Character.PEH:Destroy()
                    end
                    if v1444.Character:FindFirstChild("PE_Text") then
                        v1444.Character.PE_Text:Destroy()
                    end
                end
            end
        elseif a125 == "Killer" then
            for v1437, v1438 in pairs(v3:GetPlayers()) do
                if v1438.Character then
                    if v1438.Character:FindFirstChild("KEH") then
                        v1438.Character.KEH:Destroy()
                    end
                    if v1438.Character:FindFirstChild("KE_Text") then
                        v1438.Character.KE_Text:Destroy()
                    end
                end
            end
        elseif a125 == "Generator" then
            for v1431, v1432 in pairs(v380.Generators) do
                if v1432.model and v1432.model.Parent and v1432.model:FindFirstChild("GEH") then
                    v1432.model.GEH:Destroy()
                end
                if v1432.part and v1432.part.Parent and v1432.part:FindFirstChild("GE_Text") then
                    v1432.part.GE_Text:Destroy()
                end
            end
        elseif a125 == "Pallet" then
            for v1425, v1426 in pairs(v380.Pallets) do
                if v1426 and v1426.Parent and v1426:FindFirstChild("PalletEH") then
                    v1426.PalletEH:Destroy()
                end
            end
        elseif a125 == "Hook" then
            for v1419, v1420 in pairs(v380.Hooks) do
                if v1420 and v1420.Parent and v1420:FindFirstChild("HookEH") then
                    v1420.HookEH:Destroy()
                end
            end
        elseif a125 == "Window" then
            for v1413, v1414 in pairs(v380.Windows) do
                if v1414 and v1414.Parent and v1414:FindFirstChild("WindowEH") then
                    v1414.WindowEH:Destroy()
                end
            end
        elseif a125 == "Gate" then
            for v1407, v1408 in pairs(v380.Gates) do
                if v1408 and v1408.Parent and v1408:FindFirstChild("GateEH") then
                    v1408.GateEH:Destroy()
                end
            end
        elseif a125 == "SCP" then
            for v1401, v1402 in pairs(v380.SCPs) do
                if v1402 and v1402.Parent and v1402:FindFirstChild("SCPEH") then
                    v1402.SCPEH:Destroy()
                end
            end
        end
    end
    ClearAllESP = function()
        ClearESP("Player")
        ClearESP("Killer")
        ClearESP("Generator")
        ClearESP("Pallet")
        ClearESP("Hook")
        ClearESP("Gate")
        ClearESP("SCP")
        ClearESP("Window")
        ClearHookESP()
    end
    GetSurvivorStatus = function(a126)
        if not a126 then
            return nil, nil
        end
        if a126:GetAttribute("IsHooked") == true then
            return "HOOKED", _G.Ox.ESPColors.Hooked
        end
        if a126:GetAttribute("Knocked") == true then
            return "DOWN", _G.Ox.ESPColors.Downed
        end
        local v1445 = a126:FindFirstChildOfClass("Humanoid")
        if v1445 and v1445.Health > 0 and v1445.Health < v1445.MaxHealth then
            return "INJURED", _G.Ox.ESPColors.Injured
        end
        return nil, nil
    end
    buildInfoRich = function(a127, a128, a129, a130, a131)
        local v1446 = {}
        if a127 and a127 ~= "" then
            local v1447 = "#FFFFFF"
            if a127 == "INJURED" then
                v1447 = "#FF8C00"
            elseif a127 == "DOWN" then
                v1447 = "#FF2828"
            elseif a127 == "HOOKED" then
                v1447 = "#F0F0FF"
            end
            table.insert(v1446, string.format("<font color=\"%s\">%s</font>", v1447, a127))
        end
        if a129 then
            table.insert(v1446, string.format("<font color=\"#FFFFFF\">%dm</font>", a129))
        end
        if not a131 and a130 and a127 ~= "HOOKED" then
            local v1448 = "#C8C8C8"
            if a130 >= 3 then
                v1448 = "#FF3232"
            elseif a130 >= 2 then
                v1448 = "#FFC832"
            end
            table.insert(v1446, string.format("<font color=\"%s\">Hooked %d</font>", v1448, a130))
        end
        return table.concat(v1446, " <font color=\"#888888\">·</font> ")
    end
    UpdatePlayerESP = function()
        if not _G.Ox.ESPConfig.Master then
            return
        end
        local v1449 = v4.Character
        local v1450 = v1449 and v1449:FindFirstChild("HumanoidRootPart")
        if _G.Ox.ESPConfig.KillerWarn and v1450 and GetRole() == "Survivor" then
            local v1451 = v1450:FindFirstChild("KillerWarn")
            local v1452 = v1451
            local v1453 = math.huge
            for v1458, v1459 in pairs(v3:GetPlayers()) do
                if v1459 ~= v4 and v1459.Team and v1459.Team.Name == "Killer" and v1459.Character then
                    local v1460 = v1459.Character:FindFirstChild("HumanoidRootPart")
                    if v1460 then
                        local v1461 = (v1460.Position - v1450.Position).Magnitude
                        if v1461 < v1453 then
                            v1453 = v1461
                        end
                    end
                end
            end
            if v1453 <= 80 then
                if not v1451 then
                    local v1462 = Instance.new("BillboardGui")
                    v1452 = v1462
                    v1462.Name = "KillerWarn"
                    v1462.Size = UDim2.new(0, 30, 0, 30)
                    v1462.AlwaysOnTop = true
                    v1462.StudsOffset = Vector3.new(0, 4, 0)
                    v1462.Parent = v1450
                    local v1463 = Instance.new("TextLabel")
                    v1463.Name = "WarnText"
                    v1463.Size = UDim2.new(1, 0, 1, 0)
                    v1463.BackgroundTransparency = 1
                    v1463.TextScaled = true
                    v1463.TextStrokeTransparency = 0
                    v1463.Font = Enum.Font.GothamBlack
                    v1463.Parent = v1462
                end
                local v1464 = v1452:FindFirstChild("WarnText")
                if v1464 then
                    if v1453 <= 40 then
                        v1464.Text = "!!"
                        v1464.TextColor3 = Color3.fromRGB(255, 0, 0)
                    else
                        v1464.Text = "!"
                        v1464.TextColor3 = Color3.fromRGB(255, 255, 0)
                    end
                end
            elseif v1451 then
                v1451:Destroy()
            end
        else
            local v1465 = v1450 and v1450:FindFirstChild("KillerWarn")
            if v1465 then
                v1465:Destroy()
            end
        end
        local v1466, v1467, v1468 = pairs(v3:GetPlayers())
        local v1469 = v1468
        local v1470 = v1466
        local v1471 = v1467
        while true do
            local v1472, v1473 = v1470(v1471, v1469)
            if v1472 == nil then
                break
            end
            v1469 = v1472
            if v1473 ~= v4 and v1473.Character then
                local v1474 = v1473.Character:FindFirstChild("HumanoidRootPart")
                if v1474 and _G.Ox.ESPConfig.MaxDistance < (v12.CFrame.Position - v1474.Position).Magnitude then
                    for v1481, v1482 in ipairs({"PE_Text", "KE_Text", "PEH", "KEH"}) do
                        local v1483 = v1473.Character:FindFirstChild(v1482)
                        if v1483 then
                            v1483:Destroy()
                        end
                    end
                    v1469 = v1472
                else
                    local v1484 = v1473.Team
                    local v1485 = v1484 and v1473.Team.Name == "Killer"
                    local v1486
                    if v1485 then
                        v1486 = _G.Ox.ESPConfig.Killer
                    else
                        local v1487 = _G.Ox.ESPConfig.Player
                        local v1488 = v1487 or _G.Ox.ESPConfig.HookCount
                        v1486 = v1488
                    end
                    local v1489 = v1485 and "KE_Text" or "PE_Text"
                    local v1490 = v1485 and "KEH" or "PEH"
                    local v1491 = v1485 and _G.Ox.ESPColors.Killer or _G.Ox.ESPColors.Player
                    local v1492 = nil
                    local v1493 = nil
                    if not v1485 and _G.Ox.ESPConfig.Status then
                        local v1494, v1495 = GetSurvivorStatus(v1473.Character)
                        if v1494 then
                            v1492 = v1494
                            v1493 = v1495
                        end
                    end
                    if v1486 then
                        local v1496, v1497, v1498 = ipairs({"PE_Text", "KE_Text"})
                        local v1499 = v1470
                        local v1500 = v1471
                        for v1502, v1503 in v1496, v1497, v1498 do
                            if v1503 ~= v1489 then
                                local v1504 = v1473.Character:FindFirstChild(v1503)
                                if v1504 then
                                    v1504:Destroy()
                                end
                            end
                        end
                        for v1509, v1510 in ipairs({"PEH", "KEH"}) do
                            if v1510 ~= v1490 then
                                local v1511 = v1473.Character:FindFirstChild(v1510)
                                if v1511 then
                                    v1511:Destroy()
                                end
                            end
                        end
                        v1469 = v1472
                        v1470 = v1499
                        v1471 = v1500
                        if v1485 then
                            for v1516, v1517 in ipairs(v1473.Character:GetChildren()) do
                                if string.match(v1517.Name, "^HookESP_") then
                                    v1517:Destroy()
                                end
                            end
                            v1469 = v1472
                            v1470 = v1499
                            v1471 = v1500
                        end
                        local v1518 = v1473.Character:FindFirstChild("HumanoidRootPart")
                        local v1519 = v1518 and math.floor(GetDistance(v1518.Position)) or nil
                        local v1520 = v1473.Character:FindFirstChild(v1490)
                        local v1521 = v1520
                        if not v1520 then
                            local v1522 = Instance.new("Highlight")
                            v1521 = v1522
                            v1522.Name = v1490
                            v1522.Parent = v1473.Character
                        end
                        v1521.FillColor = v1491
                        v1521.OutlineColor = v1491
                        local v1523 = _G.Ox.ESPConfig.Outline
                        local v1524 = v1523 and 1 or 0.5
                        v1521.FillTransparency = v1524
                        v1521.OutlineTransparency = 0
                        local v1525 = nil
                        local v1526 = nil
                        if _G.Ox.ESPConfig.Name then
                            v1525 = v1473.Name
                            if v1485 then
                                local v1527 = v1473:GetAttribute("SelectedKiller")
                                if not v1527 then
                                    local v1528 = v1473:FindFirstChild("SelectedKiller")
                                    if v1528 then
                                        pcall(function()
                                            v1527 = v1528.Value
                                        end)
                                    end
                                end
                                if v1527 and tostring(v1527) ~= "" then
                                    v1525 = tostring(v1527)
                                end
                            end
                            if _G.Ox.ESPConfig.ItemIcon and not v1485 then
                                local v1529 = v1473:GetAttribute("EquippedItem")
                                if v1529 and v1529 ~= "" then
                                    v1526 = getItemIcon(v1529)
                                end
                            end
                        end
                        local v1530 = nil
                        if not v1485 and _G.Ox.ESPConfig.HookCount then
                            local v1531 = v1311[v1473.Name]
                            local v1532 = v1531 or v1473:GetAttribute("HookCount") or 0
                            v1530 = v1532
                        end
                        local v1533 = buildInfoRich
                        local v1534 = _G.Ox.ESPConfig.Distance
                        local v1535 = v1534 and v1519 or nil
                        local v1536 = v1533(v1492, v1493, v1535, v1530, v1485)
                        if not v1525 and v1536 == "" then
                            local v1541 = v1473.Character:FindFirstChild(v1489)
                            if v1541 then
                                v1541:Destroy()
                            end
                        else
                            local v1537 = CreateModernESP
                            local v1538 = v1473.Character
                            local v1539 = {}
                            local v1540 = v1525 or ""
                            v1539.name = v1540
                            v1539.infoRich = v1536
                            v1539.color = v1491
                            v1539.icon = v1526
                            v1539.offsetY = 4
                            v1537(v1538, v1489, v1539)
                        end
                    else
                        local v1542 = v1473.Character:FindFirstChild(v1490)
                        if v1542 then
                            v1542:Destroy()
                        end
                        local v1543 = v1473.Character:FindFirstChild(v1489)
                        if v1543 then
                            v1543:Destroy()
                        end
                    end
                end
            end
        end
    end
    UpdateSCPESP = function()
        if not _G.Ox.ESPConfig.Master then
            return
        end
        if _G.Ox.ESPConfig.SCP then
            for v1548, v1549 in ipairs(v380.SCPs) do
                if v1549 and v1549.Parent then
                    local v1550 = v1549:FindFirstChildOfClass("Humanoid")
                    local v1551 = v1549:FindFirstChild("HumanoidRootPart")
                    local v1552 = v1551 or v1549:FindFirstChild("Torso") or v1549.PrimaryPart
                    if v1552 and _G.Ox.ESPConfig.MaxDistance < (v12.CFrame.Position - v1552.Position).Magnitude then
                        local v1553 = v1549:FindFirstChild("SCPEH")
                        if v1553 then
                            v1553:Destroy()
                        end
                    elseif v1550 and v1552 and v1550.Health > 0 and math.floor(v1550.WalkSpeed) == 9 then
                        local v1554 = _G.Ox.ESPColors.SCP
                        local v1555 = v1549:FindFirstChild("SCPEH")
                        local v1556 = v1555
                        if not v1555 then
                            local v1557 = Instance.new("Highlight")
                            v1556 = v1557
                            v1557.Name = "SCPEH"
                            v1557.Parent = v1549
                        end
                        v1556.FillColor = v1554
                        v1556.OutlineColor = v1554
                        local v1558 = _G.Ox.ESPConfig.Outline
                        local v1559 = v1558 and 1 or 0.5
                        v1556.FillTransparency = v1559
                        v1556.OutlineTransparency = 0
                    else
                        local v1560 = v1549:FindFirstChild("SCPEH")
                        if v1560 then
                            v1560:Destroy()
                        end
                    end
                end
            end
        else
            ClearESP("SCP")
        end
    end
    UpdateStaticESP = function()
        if not _G.Ox.ESPConfig.Master then
            return
        end
        if _G.Ox.ESPConfig.Generator then
            for v1565, v1566 in pairs(v380.Generators) do
                local v1567 = v1566.model
                if v1567 and v1567.Parent then
                    local v1568 = v1566.part
                    local v1569 = v1568 or v1567:FindFirstChildWhichIsA("BasePart")
                    if v1569 and _G.Ox.ESPConfig.MaxDistance < (v12.CFrame.Position - v1569.Position).Magnitude then
                        local v1570 = v1567:FindFirstChild("GEH")
                        if v1570 then
                            v1570:Destroy()
                        end
                        local v1571 = v1567:FindFirstChild("GE_Text")
                        if v1571 then
                            v1571:Destroy()
                        end
                    else
                        local v1572 = math.floor
                        local v1573 = v1567:GetAttribute("RepairProgress")
                        local v1574 = v1573 or 0
                        local v1575 = v1572(v1574)
                        local v1576 = math.clamp(v1575 / 100, 0, 1)
                        local v1577 = _G.Ox.ESPColors.Generator:Lerp(_G.Ox.ESPColors.GeneratorDone, v1576)
                        local v1578 = v1567:FindFirstChild("GEH")
                        local v1579 = v1578
                        if not v1578 then
                            local v1580 = Instance.new("Highlight")
                            v1579 = v1580
                            v1580.Name = "GEH"
                            v1580.Parent = v1567
                        end
                        v1579.FillColor = v1577
                        v1579.OutlineColor = v1577
                        local v1581 = _G.Ox.ESPConfig.Outline
                        local v1582 = v1581 and 1 or 0.5
                        v1579.FillTransparency = v1582
                        v1579.OutlineTransparency = 0
                        if _G.Ox.ESPConfig.GeneratorName then
                            local v1583
                            if v1575 >= 100 then
                                v1583 = "DONE"
                            else
                                v1583 = string.format("%d%%", v1575)
                            end
                            local v1584 = _G.Ox.ESPColors.Generator
                            local v1585 = v1566.part
                            local v1586 = v1585 or v1567
                            local v1587
                            if v1586:IsA("BasePart") then
                                v1587 = v1586.Size.Y / 2 + 1
                            else
                                v1587 = v1567:GetExtentsSize().Y / 2 + 1
                            end
                            CreateModernESP(v1586, "GE_Text", {
                                name = "GEN",
                                infoRich = string.format("<font color=\"%s\">%s</font>", "#FF8000", v1583),
                                color = v1584,
                                icon = nil,
                                offsetY = v1587,
                                noSeparator = true,
                                noDistScale = true,
                            })
                        else
                            local v1588 = v1567:FindFirstChild("GE_Text")
                            if v1588 then
                                v1588:Destroy()
                            end
                        end
                    end
                end
            end
        end
        if _G.Ox.ESPConfig.Pallet then
            for v1593, v1594 in pairs(v380.Pallets) do
                if v1594 and v1594.Parent then
                    local v1595 = v1594:FindFirstChildWhichIsA("BasePart")
                    if v1595 and _G.Ox.ESPConfig.MaxDistance < (v12.CFrame.Position - v1595.Position).Magnitude then
                        local v1596 = v1594:FindFirstChild("PalletEH")
                        if v1596 then
                            v1596:Destroy()
                        end
                    else
                        local v1597 = v1594:FindFirstChild("PalletEH")
                        local v1598 = v1597
                        if not v1597 then
                            local v1599 = Instance.new("Highlight")
                            v1598 = v1599
                            v1599.Name = "PalletEH"
                            v1599.Parent = v1594
                        end
                        v1598.Adornee = v1594
                        v1598.FillColor = _G.Ox.ESPColors.Pallet
                        v1598.OutlineColor = _G.Ox.ESPColors.Pallet
                        local v1600 = _G.Ox.ESPConfig.Outline
                        local v1601 = v1600 and 1 or 0.5
                        v1598.FillTransparency = v1601
                        v1598.OutlineTransparency = 0
                    end
                end
            end
        end
        if _G.Ox.ESPConfig.Window then
            for v1606, v1607 in ipairs(v380.Windows) do
                if v1607 and v1607.Parent then
                    local v1608 = v1607:FindFirstChild("Bottom")
                    local v1609 = v1608 or v1607:FindFirstChildWhichIsA("BasePart")
                    if v1609 and _G.Ox.ESPConfig.MaxDistance < (v12.CFrame.Position - v1609.Position).Magnitude then
                        local v1610 = v1607:FindFirstChild("WindowEH")
                        if v1610 then
                            v1610:Destroy()
                        end
                    elseif v1609 then
                        local v1611 = v1607:FindFirstChild("WindowEH")
                        local v1612 = v1611
                        if not v1611 then
                            local v1613 = Instance.new("BoxHandleAdornment")
                            v1612 = v1613
                            v1613.Name = "WindowEH"
                            v1613.Parent = v1607
                            v1613.AlwaysOnTop = true
                            v1613.ZIndex = 5
                        end
                        v1612.Adornee = v1609
                        v1612.Size = v1609.Size
                        v1612.Color3 = _G.Ox.ESPColors.Window
                        local v1614 = _G.Ox.ESPConfig.Outline
                        local v1615 = v1614 and 0.8 or 0.4
                        v1612.Transparency = v1615
                    end
                end
            end
        end
        if _G.Ox.ESPConfig.Hook then
            for v1620, v1621 in ipairs(v380.Hooks) do
                if v1621 and v1621.Parent then
                    local v1622 = v1621:FindFirstChild("HookPoint")
                    local v1623 = v1622 or v1621:FindFirstChildWhichIsA("BasePart")
                    if v1623 and _G.Ox.ESPConfig.MaxDistance < (v12.CFrame.Position - v1623.Position).Magnitude then
                        local v1624 = v1621:FindFirstChild("HookEH")
                        if v1624 then
                            v1624:Destroy()
                        end
                    else
                        local v1625 = v1621:FindFirstChild("HookEH")
                        local v1626 = v1625
                        if not v1625 then
                            local v1627 = Instance.new("Highlight")
                            v1626 = v1627
                            v1627.Name = "HookEH"
                            v1627.Parent = v1621
                        end
                        v1626.FillColor = _G.Ox.ESPColors.Hook
                        v1626.OutlineColor = _G.Ox.ESPColors.Hook
                        local v1628 = _G.Ox.ESPConfig.Outline
                        local v1629 = v1628 and 1 or 0.5
                        v1626.FillTransparency = v1629
                        v1626.OutlineTransparency = 0
                    end
                end
            end
        end
        if _G.Ox.ESPConfig.Gate then
            for v1634, v1635 in ipairs(v380.Gates) do
                if v1635 and v1635.Parent then
                    local v1636 = v1635:FindFirstChildWhichIsA("BasePart")
                    if v1636 and _G.Ox.ESPConfig.MaxDistance < (v12.CFrame.Position - v1636.Position).Magnitude then
                        local v1637 = v1635:FindFirstChild("GateEH")
                        if v1637 then
                            v1637:Destroy()
                        end
                    else
                        local v1638 = v1635:FindFirstChild("GateEH")
                        local v1639 = v1638
                        if not v1638 then
                            local v1640 = Instance.new("Highlight")
                            v1639 = v1640
                            v1640.Name = "GateEH"
                            v1640.Parent = v1635
                        end
                        v1639.Adornee = v1635
                        v1639.FillColor = _G.Ox.ESPColors.Gate
                        v1639.OutlineColor = _G.Ox.ESPColors.Gate
                        local v1641 = _G.Ox.ESPConfig.Outline
                        local v1642 = v1641 and 1 or 0.5
                        v1639.FillTransparency = v1642
                        v1639.OutlineTransparency = 0
                    end
                end
            end
        end
    end
    task.spawn(function()
        local v1643, v1644, v1645, v1646, v1647, v1648, v1649, v1650, v1651, v1652, v1653, v1654, v1655, v1656, v1657, v1658, v1659, v1660, v1661, v1662
        local v1663, v1664, v1665, v1666, v1667, v1668, v1669, v1670, v1671, v1672, v1673, v1674, v1675, v1676, v1677, v1678, v1679, v1680, v1681
        v1681 = 1
        while true do
            if v1681 == 1 then
                if _G.Ox.ScriptAlive then
                    v1681 = 2
                else
                    v1681 = 26
                end
            elseif v1681 == 2 then
                task.wait(0.1)
                v1643 = workspace.CurrentCamera
                if v1643 then
                    v1681 = 3
                else
                    v1681 = 1
                end
            elseif v1681 == 3 then
                v1644, v1645, v1646 = ipairs(v3:GetPlayers())
                v1647 = v1646
                v1648 = v1644
                v1649 = v1645
                v1681 = 4
            elseif v1681 == 4 then
                v1650, v1651 = v1648(v1649, v1647)
                if v1650 == nil then
                    v1681 = 16
                else
                    v1681 = 5
                end
            elseif v1681 == 5 then
                v1647 = v1650
                if v1651 ~= v4 and v1651.Character then
                    v1681 = 6
                else
                    v1681 = 4
                end
            elseif v1681 == 6 then
                v1652 = v1651.Character:FindFirstChild("HumanoidRootPart")
                if v1652 then
                    v1681 = 7
                else
                    v1681 = 4
                end
            elseif v1681 == 7 then
                v1653 = (v1643.CFrame.Position - v1652.Position).Magnitude
                v1654 = math.clamp(40 / math.max(v1653, 5), 0.8, 1)
                v1655 = 4 + math.clamp((v1653 - 40) * 0.05, 0, 6)
                v1656, v1657, v1658 = ipairs({"PE_Text", "KE_Text"})
                v1659 = v1648
                v1660 = v1649
                v1661 = v1658
                v1681 = 8
            elseif v1681 == 8 then
                v1662, v1663 = v1656(v1657, v1661)
                if v1662 == nil then
                    v1681 = 15
                else
                    v1681 = 9
                end
            elseif v1681 == 9 then
                v1661 = v1662
                v1664 = v1651.Character:FindFirstChild(v1663)
                if v1664 and not v1664:GetAttribute("NoDistScale") then
                    v1681 = 10
                else
                    v1681 = 8
                end
            elseif v1681 == 10 then
                v1665 = v1664:FindFirstChild("Box")
                v1666 = v1665
                if v1665 then
                    v1681 = 11
                else
                    v1681 = 12
                end
            elseif v1681 == 11 then
                v1666 = v1665:FindFirstChild("DistScale")
                v1681 = 12
            elseif v1681 == 12 then
                if v1666 then
                    v1681 = 13
                else
                    v1681 = 14
                end
            elseif v1681 == 13 then
                v1666.Scale = v1654
                v1681 = 14
            elseif v1681 == 14 then
                v1664.StudsOffset = Vector3.new(0, v1655, 0)
                v1681 = 8
            elseif v1681 == 15 then
                v1647 = v1650
                v1648 = v1659
                v1649 = v1660
                v1681 = 4
            elseif v1681 == 16 then
                v1667, v1668, v1669 = pairs(v380.Generators)
                v1670 = v1669
                v1681 = 17
            elseif v1681 == 17 then
                v1671, v1672 = v1667(v1668, v1670)
                if v1671 == nil then
                    v1681 = 1
                else
                    v1681 = 18
                end
            elseif v1681 == 18 then
                v1670 = v1671
                v1673 = v1672.model
                if v1673 and v1673.Parent then
                    v1681 = 19
                else
                    v1681 = 17
                end
            elseif v1681 == 19 then
                v1674 = v1673:FindFirstChildWhichIsA("BasePart")
                if v1674 then
                    v1681 = 20
                else
                    v1681 = 17
                end
            elseif v1681 == 20 then
                v1675 = (v1643.CFrame.Position - v1674.Position).Magnitude
                v1676 = math.clamp(40 / math.max(v1675, 5), 0.8, 1)
                v1677 = 4 + math.clamp((v1675 - 40) * 0.05, 0, 6)
                v1678 = v1673:FindFirstChild("GE_Text")
                if v1678 and not v1678:GetAttribute("NoDistScale") then
                    v1681 = 21
                else
                    v1681 = 17
                end
            elseif v1681 == 21 then
                v1679 = v1678:FindFirstChild("Box")
                v1680 = v1679
                if v1679 then
                    v1681 = 22
                else
                    v1681 = 23
                end
            elseif v1681 == 22 then
                v1680 = v1679:FindFirstChild("DistScale")
                v1681 = 23
            elseif v1681 == 23 then
                if v1680 then
                    v1681 = 24
                else
                    v1681 = 25
                end
            elseif v1681 == 24 then
                v1680.Scale = v1676
                v1681 = 25
            elseif v1681 == 25 then
                v1678.StudsOffset = Vector3.new(0, v1677, 0)
                v1681 = 17
            elseif v1681 == 26 then
                return
            end
        end
    end)
    SetupHookDetection = function()
        for v1686, v1687 in pairs(v3:GetPlayers()) do
            if v1687 ~= v4 then
                v1687:GetAttributeChangedSignal("HookCount"):Connect(function()
                    local v1688 = v1687.Name
                    local v1689 = v1687:GetAttribute("HookCount")
                    local v1690 = v1689 or 0
                    v1311[v1688] = v1690
                    if _G.Ox.ESPConfig.HookCount then
                        UpdateHookESP()
                        UpdateHookUICounter()
                    end
                end)
            end
        end
    end
    v3.PlayerAdded:Connect(function(a132)
        a132:GetAttributeChangedSignal("HookCount"):Connect(function()
            local v1691 = a132.Name
            local v1692 = a132:GetAttribute("HookCount")
            local v1693 = v1692 or 0
            v1311[v1691] = v1693
            if _G.Ox.ESPConfig.HookCount then
                UpdateHookESP()
                UpdateHookUICounter()
            end
        end)
    end)
    task.spawn(function()
        task.wait(2)
        SetupHookDetection()
    end)
    local v1694 = false
    task.spawn(function()
        while _G.Ox.ScriptAlive do
            task.wait(1)
            if _G.Ox.ESPConfig.HookCount then
                v1694 = true
                UpdateHookData()
                UpdatePlayerESP()
                UpdateHookUICounter()
            elseif v1694 then
                ClearHookESP()
                ClearHookUICounter()
                UpdatePlayerESP()
                v1694 = false
            end
        end
    end)
    local v1695 = function(a133)
        _G.Ox.InfinityZoom.Enabled = a133
        if a133 then
            v4.CameraMaxZoomDistance = math.huge
            v4.CameraMinZoomDistance = 0
            v1:Notify({
                Title = "Infinity Zoom",
                Description = "AKTIF - Zoom out tanpa batas",
                Duration = 2,
            })
        else
            v4.CameraMaxZoomDistance = 12
            v4.CameraMinZoomDistance = 0.5
            v1:Notify({
                Title = "Infinity Zoom",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    local v1699 = function(a134)
        _G.Ox.CameraFOV.Enabled = a134
        if not a134 then
            v12.FieldOfView = 70
        end
        local v1696 = v1.Notify
        local v1697 = {Title = "Camera FOV"}
        local v1698 = a134 and "AKTIF" or "NONAKTIF"
        v1697.Description = v1698
        v1697.Duration = 2
        v1696(v1, v1697)
    end
    local v1700 = function(a135)
        _G.Ox.CameraFOV.Value = a135
        if _G.Ox.CameraFOV.Enabled then
            v12.FieldOfView = a135
        end
    end
    v4.CharacterAdded:Connect(function()
        task.wait(0.5)
        if _G.Ox.CameraFOV.Enabled then
            v12.FieldOfView = _G.Ox.CameraFOV.Value
        end
    end)
    workspace.ChildAdded:Connect(function(a136)
        if a136.Name == "Map" then
            task.wait(0.5)
            if _G.Ox.CameraFOV.Enabled then
                v12.FieldOfView = _G.Ox.CameraFOV.Value
            end
        end
    end)
    pcall(function()
        _G.Ox.InstantTPGate.GateClientModule = require(game:GetService("ReplicatedStorage").Modules.Items.GateClient)
    end)
    local v1707 = function(a137)
        for v1705, v1706 in getgc(true) do
            if typeof(v1706) == "table" and rawget(v1706, "gateDuration") and rawget(v1706, "gateRemote") then
                rawset(v1706, "gateDuration", a137)
            end
        end
    end
    local v1711 = function()
        if not _G.Ox.InstantTPGate.GateClientModule then
            return
        end
        if not _G.Ox.InstantTPGate.oldGateNew then
            _G.Ox.InstantTPGate.oldGateNew = _G.Ox.InstantTPGate.GateClientModule.new
            _G.Ox.InstantTPGate.GateClientModule.new = function(...)
                local v1708 = _G.Ox.InstantTPGate.oldGateNew(...)
                if _G.Ox.InstantTPGate.Enabled then
                    v1708.gateDuration = 0
                end
                return v1708
            end
        end
        if not _G.Ox.InstantTPGate.oldGateCanUse then
            _G.Ox.InstantTPGate.oldGateCanUse = _G.Ox.InstantTPGate.GateClientModule.CanUse
            _G.Ox.InstantTPGate.GateClientModule.CanUse = function(a138)
                if not _G.Ox.InstantTPGate.Enabled then
                    return _G.Ox.InstantTPGate.oldGateCanUse(a138)
                end
                if a138.isSilenced or a138.isBuffering then
                    return false
                end
                local v1709 = os.clock() - a138.lastUse
                local v1710 = a138.currentCooldown <= v1709
                return v1710
            end
        end
    end
    local v1712 = function()
        if not _G.Ox.InstantTPGate.GateClientModule then
            return
        end
        if _G.Ox.InstantTPGate.oldGateNew then
            _G.Ox.InstantTPGate.GateClientModule.new = _G.Ox.InstantTPGate.oldGateNew
            _G.Ox.InstantTPGate.oldGateNew = nil
        end
        if _G.Ox.InstantTPGate.oldGateCanUse then
            _G.Ox.InstantTPGate.GateClientModule.CanUse = _G.Ox.InstantTPGate.oldGateCanUse
            _G.Ox.InstantTPGate.oldGateCanUse = nil
        end
    end
    local v1713 = function(a139)
        _G.Ox.InstantTPGate.Enabled = a139
        if a139 then
            v1707(0)
            v1711()
            v1:Notify({
                Title = "Instant TP Gate",
                Description = "AKTIF",
                Duration = 2,
            })
        else
            v1707(1.5)
            v1712()
            v1:Notify({
                Title = "Instant TP Gate",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    v4.CharacterAdded:Connect(function()
        task.wait(0.5)
        if _G.Ox.InstantTPGate.Enabled then
            v1707(0)
            v1711()
        end
    end)
    workspace.ChildAdded:Connect(function(a140)
        if a140.Name == "Map" then
            task.wait(0.5)
            if _G.Ox.InstantTPGate.Enabled then
                v1707(0)
                v1711()
            end
        end
    end)
    ResetAllTransparency = function()
        local v1714, v1715, v1716 = pairs(v12:GetChildren())
        local v1717 = v1716
        local v1718 = v1714
        local v1719 = v1715
        while true do
            local v1720, v1721 = v1718(v1719, v1717)
            if v1720 == nil then
                break
            end
            v1717 = v1720
            if v1721 ~= v4.Character then
                for v1728, v1729 in pairs(v1721:GetDescendants()) do
                    if v1729:IsA("BasePart") or v1729:IsA("Decal") then
                        pcall(function()
                            v1729.LocalTransparencyModifier = 0
                            v1729.Transparency = 0
                        end)
                    end
                end
                v1717 = v1720
            end
        end
    end
    SetWorldTransparency = function(a141)
        local v1730, v1731, v1732 = pairs(v12:GetChildren())
        local v1733 = v1732
        local v1734 = v1730
        local v1735 = v1731
        while true do
            local v1736, v1737 = v1734(v1735, v1733)
            if v1736 == nil then
                break
            end
            v1733 = v1736
            if v1737 ~= v4.Character then
                for v1744, v1745 in pairs(v1737:GetDescendants()) do
                    if v1745:IsA("BasePart") or v1745:IsA("Decal") then
                        pcall(function()
                            v1745.LocalTransparencyModifier = a141
                            v1745.Transparency = a141
                        end)
                    end
                end
                v1733 = v1736
            end
        end
    end
    SetCharacterTransparency = function(a142, a143)
        if not a142 then
            return
        end
        local v1746, v1747, v1748 = pairs(a142:GetChildren())
        local v1749 = v1748
        local v1750 = v1746
        local v1751 = v1747
        while true do
            local v1752, v1753 = v1750(v1751, v1749)
            if v1752 == nil then
                break
            end
            v1749 = v1752
            if v1753.Name == "Hat" then
                for v1760, v1761 in pairs(v1753:GetDescendants()) do
                    if v1761:IsA("BasePart") or v1761:IsA("Decal") then
                        pcall(function()
                            v1761.LocalTransparencyModifier = a143
                            v1761.Transparency = a143
                        end)
                    end
                end
                v1749 = v1752
            end
            if v1753:IsA("BasePart") and v376[v1753.Name] then
                pcall(function()
                    v1753.LocalTransparencyModifier = a143
                    v1753.Transparency = a143
                end)
            end
            if v1753:IsA("Tool") or v1753:IsA("Model") then
                local v1762 = v1753:IsA("BasePart")
                local v1763 = v1762
                if v1762 then
                    local v1764 = {}
                    v1763 = v1764
                    v1764[1] = v1753
                end
                if not v1763 then
                    v1763 = v1753:GetDescendants()
                end
                for v1772, v1773 in pairs(v1763) do
                    if v1773:IsA("BasePart") or v1773:IsA("Decal") then
                        pcall(function()
                            v1773.LocalTransparencyModifier = a143
                            v1773.Transparency = a143
                        end)
                    end
                end
            end
        end
    end
    ResetCharacterTransparency = function(a144)
        if not v4.Character then
            return
        end
        if a144 then
            local v1774, v1775, v1776 = pairs(v4.Character:GetChildren())
            local v1777 = v1776
            local v1778 = v1774
            local v1779 = v1775
            while true do
                local v1780, v1781 = v1778(v1779, v1777)
                if v1780 == nil then
                    break
                end
                v1777 = v1780
                if v1781.Name == "Hat" then
                    for v1788, v1789 in pairs(v1781:GetDescendants()) do
                        if v1789:IsA("BasePart") or v1789:IsA("Decal") then
                            pcall(function()
                                v1789.LocalTransparencyModifier = 1
                                v1789.Transparency = 1
                            end)
                        end
                    end
                    v1777 = v1780
                end
                if v1781:IsA("BasePart") and v376[v1781.Name] then
                    pcall(function()
                        v1781.LocalTransparencyModifier = 1
                        v1781.Transparency = 1
                    end)
                end
                if v1781:IsA("Tool") or v1781:IsA("Model") then
                    local v1790 = v1781:IsA("BasePart")
                    local v1791 = v1790
                    if v1790 then
                        local v1792 = {}
                        v1791 = v1792
                        v1792[1] = v1781
                    end
                    if not v1791 then
                        v1791 = v1781:GetDescendants()
                    end
                    for v1800, v1801 in pairs(v1791) do
                        if v1801:IsA("BasePart") or v1801:IsA("Decal") then
                            pcall(function()
                                v1801.LocalTransparencyModifier = 1
                                v1801.Transparency = 1
                            end)
                        end
                    end
                end
            end
        else
            SetCharacterTransparency(v4.Character, 0)
        end
    end
    local v1802 = function()
        pcall(function()
            v4.CameraMode = Enum.CameraMode.Classic
            if _G.Ox.InfinityZoom and _G.Ox.InfinityZoom.Enabled then
                v4.CameraMinZoomDistance = 0
                v4.CameraMaxZoomDistance = math.huge
            else
                v4.CameraMinZoomDistance = 0.5
                v4.CameraMaxZoomDistance = 128
            end
        end)
        ResetAllTransparency()
        if v4.Character then
            ResetCharacterTransparency(false)
        end
    end
    local v1805 = function(a145)
        local v1803 = v4.Team
        local v1804 = v1803 and v4.Team.Name == "Killer"
        if a145 and not v1804 then
            v1:Notify({
                Title = "Akses Ditolak",
                Description = "Fitur ini khusus Killer!",
                Duration = 3,
            })
            v375.Enabled = false
            v384(ThirdPersonToggle, false)
            return
        end
        v375.Enabled = a145
        if not a145 then
            if _G.Ox.State.ThirdPersonConn then
                _G.Ox.State.ThirdPersonConn:Disconnect()
                _G.Ox.State.ThirdPersonConn = nil
            end
            v1802()
            v1:Notify({
                Title = "Third Person",
                Description = "NONAKTIF",
                Duration = 2,
            })
            return
        end
        v4.CameraMode = Enum.CameraMode.Classic
        v4.CameraMinZoomDistance = 7
        v4.CameraMaxZoomDistance = 128
        SetWorldTransparency(1)
        if _G.Ox.State.ThirdPersonConn then
            _G.Ox.State.ThirdPersonConn:Disconnect()
            _G.Ox.State.ThirdPersonConn = nil
        end
        _G.Ox.State.ThirdPersonConn = v5.RenderStepped:Connect(function()
            if not v375.Enabled then
                return
            end
            if v4.Team and v4.Team.Name == "Killer" then
                v4.CameraMode = Enum.CameraMode.Classic
                v4.CameraMinZoomDistance = 7
                v4.CameraMaxZoomDistance = 128
                if v4.Character then
                    SetCharacterTransparency(v4.Character, 0)
                end
                return
            end
            v375.Enabled = false
            if _G.Ox.State.ThirdPersonConn then
                _G.Ox.State.ThirdPersonConn:Disconnect()
                _G.Ox.State.ThirdPersonConn = nil
            end
            v1802()
            v384(ThirdPersonToggle, false)
        end)
        v1:Notify({
            Title = "Third Person",
            Description = "AKTIF - Khusus Killer",
            Duration = 3,
        })
    end
    v4:GetPropertyChangedSignal("Team"):Connect(function()
        local v1806 = v4.Team
        local v1807 = v1806 and v4.Team.Name
        if v1807 ~= "Killer" then
            if v375.Enabled then
                v1805(false)
                v384(ThirdPersonToggle, false)
            else
                v1802()
            end
        end
    end)
    v4.CharacterAdded:Connect(function()
        task.wait(0.8)
        if v375.Enabled and v4.Team and v4.Team.Name == "Killer" then
            v4.CameraMode = Enum.CameraMode.Classic
            v4.CameraMinZoomDistance = 7
            v4.CameraMaxZoomDistance = 128
        else
            v1802()
        end
    end)
    EnableUnlimitedVault = function()
        if _G.Ox.UnlimitedVaultEnabled then
            return
        end
        _G.Ox.UnlimitedVaultEnabled = true
        if _G.Ox.UnlimitedVaultConn then
            _G.Ox.UnlimitedVaultConn:Disconnect()
            _G.Ox.UnlimitedVaultConn = nil
        end
        for v1812, v1813 in ipairs(v13:GetTagged("Blocked")) do
            v13:RemoveTag(v1813, "Blocked")
        end
        _G.Ox.UnlimitedVaultConn = v13:GetInstanceAddedSignal("Blocked"):Connect(function(a146)
            v13:RemoveTag(a146, "Blocked")
        end)
        v1:Notify({
            Title = "Unlimited Vault",
            Description = "AKTIF",
            Duration = 3,
        })
    end
    DisableUnlimitedVault = function()
        _G.Ox.UnlimitedVaultEnabled = false
        if _G.Ox.UnlimitedVaultConn then
            _G.Ox.UnlimitedVaultConn:Disconnect()
            _G.Ox.UnlimitedVaultConn = nil
        end
        v1:Notify({
            Title = "Unlimited Vault",
            Description = "NONAKTIF",
            Duration = 2,
        })
    end
    local v1814 = function(a147)
        if a147 then
            EnableUnlimitedVault()
        else
            DisableUnlimitedVault()
        end
    end
    v4.CharacterAdded:Connect(function()
        task.wait(1)
        if _G.Ox.UnlimitedVaultEnabled then
            for v1819, v1820 in ipairs(v13:GetTagged("Blocked")) do
                v13:RemoveTag(v1820, "Blocked")
            end
        end
    end)
    task.spawn(function()
        if not game:IsLoaded() then
            game.Loaded:Wait()
        end
        local v1821 = nil
        local v1822 = 0
        while not v1821 and v1822 < 10 do
            v1822 = v1822 + 1
            local v1828, v1829 = pcall(function()
                local v1825 = v9:WaitForChild("Modules", 5)
                if not v1825 then
                    return nil
                end
                local v1826 = v1825:WaitForChild("Survivors", 5)
                if not v1826 then
                    return nil
                end
                local v1827 = v1826:WaitForChild("SurvivorAnimationsController", 5)
                if not v1827 then
                    return nil
                end
                return require(v1827)
            end)
            if v1828 and v1829 then
                v1821 = v1829
            else
                task.wait(1)
            end
        end
        if not v1821 then
            return
        end
        local v1823 = v1821._isFacingStraightEnough
        v1821._isFacingStraightEnough = function(a148, a149, a150, a151)
            if not _G.Ox.Config.Surv_PerfectVault then
                return v1823(a148, a149, a150, a151)
            end
            a148.characterspeed = 20
            return true, 0
        end
        local v1824 = v1821._onVaultAnimation
        v1821._onVaultAnimation = function(a152, a153, a154)
            if not _G.Ox.Config.Surv_PerfectVault then
                return v1824(a152, a153, a154)
            end
            return v1824(a152, a153, true)
        end
    end)
    local v1830 = function(a155)
        if not a155 then
            return
        end
        a155:SetAttribute("Flowstate", true)
        if _G.Ox.FlowstateNoCD.Connection then
            _G.Ox.FlowstateNoCD.Connection:Disconnect()
            _G.Ox.FlowstateNoCD.Connection = nil
        end
        _G.Ox.FlowstateNoCD.Connection = a155:GetAttributeChangedSignal("Flowstate"):Connect(function()
            if not _G.Ox.FlowstateNoCD.Enabled then
                return
            end
            if a155:GetAttribute("Flowstate") == false then
                task.wait(0.05)
                a155:SetAttribute("Flowstate", true)
            end
        end)
    end
    local v1832 = function(a156)
        _G.Ox.FlowstateNoCD.Enabled = a156
        if _G.Ox.FlowstateNoCD.Connection then
            _G.Ox.FlowstateNoCD.Connection:Disconnect()
            _G.Ox.FlowstateNoCD.Connection = nil
        end
        if _G.Ox.FlowstateNoCD.CharAddedConn then
            _G.Ox.FlowstateNoCD.CharAddedConn:Disconnect()
            _G.Ox.FlowstateNoCD.CharAddedConn = nil
        end
        if not a156 then
            local v1831 = v4.Character
            if v1831 then
                v1831:SetAttribute("Flowstate", false)
            end
            v1:Notify({
                Title = "Flowstate No CD",
                Description = "NONAKTIF",
                Duration = 2,
            })
            return
        end
        v1830(v4.Character)
        _G.Ox.FlowstateNoCD.CharAddedConn = v4.CharacterAdded:Connect(function(a157)
            if not _G.Ox.FlowstateNoCD.Enabled then
                return
            end
            task.wait(1)
            v1830(a157)
        end)
        v1:Notify({
            Title = "Flowstate No CD",
            Description = "AKTIF",
            Duration = 2,
        })
    end
    v1836 = function(a158)
        _G.Ox.NoFall.Enabled = a158
        local v1833 = v1.Notify
        local v1834 = {Title = "No Fall Damage"}
        local v1835 = a158 and "AKTIF" or "NONAKTIF"
        v1834.Description = v1835
        v1834.Duration = 2
        v1833(v1, v1834)
    end
    local v1845 = function()
        local v1837 = {}
        local v1838 = workspace:FindFirstChild("Map")
        if not v1838 then
            return v1837
        end
        for v1843, v1844 in pairs(v1838:GetDescendants()) do
            if v1844.Name == "Gate" then
                table.insert(v1837, v1844)
            end
        end
        return v1837
    end
    v1863 = function(a159)
        _G.Ox.BypassGate.Enabled = a159
        local v1846 = v1845()
        for v1851, v1852 in pairs(v1846) do
            local v1853 = v1852:FindFirstChild("LeftGate")
            local v1854 = v1852:FindFirstChild("RightGate")
            local v1855 = v1852:FindFirstChild("LeftGate-end")
            local v1856 = v1855 or v1852:FindFirstChild("LeftGate-end2")
            local v1857 = v1852:FindFirstChild("RightGate-end")
            local v1858 = v1857 or v1852:FindFirstChild("RightGate-end2")
            local v1859 = v1852:FindFirstChild("Box")
            if a159 then
                if v1853 then
                    v1853.Transparency = 1
                    v1853.CanCollide = false
                end
                if v1854 then
                    v1854.Transparency = 1
                    v1854.CanCollide = false
                end
                if v1856 then
                    v1856.Transparency = 0
                end
                if v1858 then
                    v1858.Transparency = 0
                end
                if v1859 then
                    v1859.CanCollide = false
                end
            else
                if v1853 then
                    v1853.Transparency = 0
                    v1853.CanCollide = true
                end
                if v1854 then
                    v1854.Transparency = 0
                    v1854.CanCollide = true
                end
                if v1856 then
                    v1856.Transparency = 1
                end
                if v1858 then
                    v1858.Transparency = 1
                end
                if v1859 then
                    v1859.CanCollide = true
                end
            end
        end
        local v1860 = v1.Notify
        local v1861 = {Title = "Bypass Gate"}
        local v1862 = a159 and "AKTIF" or "NONAKTIF"
        v1861.Description = v1862
        v1861.Duration = 2
        v1860(v1, v1861)
    end
    workspace.ChildAdded:Connect(function(a160)
        if a160.Name == "Map" then
            task.wait(1)
            if _G.Ox.BypassGate.Enabled then
                v1863(true)
            end
        end
    end)
    local v1864 = nil
    local v1868 = function()
        if v1864 then
            return
        end
        local v1865 = v4.Character
        if not v1865 then
            return
        end
        local v1866 = v1865:FindFirstChildOfClass("Humanoid")
        if not v1866 then
            return
        end
        local v1867 = v1866:FindFirstChildOfClass("Animator")
        if not v1867 then
            return
        end
        v1864 = v1867.AnimationPlayed:Connect(function(a161)
            if a161.Animation and a161.Animation.AnimationId:find("95836365038528") then
                a161:Stop(0)
            end
        end)
    end
    local v1869 = function()
        if v1864 then
            pcall(function()
                v1864:Disconnect()
            end)
            v1864 = nil
        end
    end
    task.spawn(function()
        while _G.Ox.ScriptAlive do
            task.wait(3)
            if not _G.Ox.ScriptAlive then
                break
            end
            if _G.Ox.SelfHeal.Enabled and v4.Team and v4.Team.Name ~= "Killer" then
                local v1870 = v4.Character
                if v1870 then
                    local v1871 = v1870:FindFirstChild("CheckInterractable")
                    local v1872 = v1870:FindFirstChild("HumanoidRootPart")
                    local v1873 = v1870:FindFirstChildOfClass("Humanoid")
                    local v1874 = false
                    if v1871 and (v1871:GetAttribute("isVaulting") or v1871:GetAttribute("isRepairing") or v1871:GetAttribute("isUnhooking") or v1871:GetAttribute("isHealing") or v1871:GetAttribute("isSliding")) then
                        v1874 = true
                    end
                    if not v1874 and v1872 and v1873 and v1873.Health < v1873.MaxHealth then
                        pcall(function()
                            local v1875 = v9:FindFirstChild("Remotes")
                            if v1875 and v1875:FindFirstChild("Healing") then
                                v1875.Healing.HealEvent:FireServer(v1872, true)
                            end
                        end)
                    end
                end
            end
        end
    end)
    v4.CharacterRemoving:Connect(function()
        v1869()
    end)
    v4.CharacterAdded:Connect(function()
        task.wait(5)
        if _G.Ox.SelfHeal.Enabled then
            v1868()
        end
    end)
    v1876 = function(a162)
        _G.Ox.SelfHeal.Enabled = a162
        if a162 then
            if v4.Team and v4.Team.Name == "Killer" then
                v1:Notify({
                    Title = "Self Heal",
                    Description = "Kamu harus Survivor!",
                    Duration = 3,
                })
                _G.Ox.SelfHeal.Enabled = false
                if SelfHealToggle then
                    v384(SelfHealToggle, false)
                end
                return
            end
            v1868()
            v1:Notify({
                Title = "Self Heal",
                Description = "AKTIF (Tanpa Animasi)",
                Duration = 2,
            })
        else
            v1869()
            v1:Notify({
                Title = "Self Heal",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    v1882 = function()
        local v1881 = function()
            repeat
                task.wait()
            until v4.Character and v4.Character:FindFirstChild("HumanoidRootPart") and v4.Character:FindFirstChild("Right Leg")
            task.wait(0.1)
            local v1877 = v4.Character
            pcall(function()
                v1877.Head.Transparency = 1
                local v1878 = v1877.Head:FindFirstChild("face")
                if v1878 then
                    v1878:Destroy()
                end
                v1877["Right Leg"].Transparency = 1
                local v1879 = Instance.new("MeshPart")
                v1879.Name = "KorlessHead"
                v1879.Size = Vector3.new(0.85, 0.85, 0.85)
                v1879.CanCollide = false
                v1879.MeshId = "rbxassetid://902942096"
                v1879.TextureID = "rbxassetid://902843398"
                v1879.CFrame = v1877["Right Leg"].CFrame * CFrame.new(0, 0.7, 0)
                v1879.Parent = v1877
                local v1880 = Instance.new("WeldConstraint")
                v1880.Part0 = v1877["Right Leg"]
                v1880.Part1 = v1879
                v1880.Parent = v1879
            end)
        end
        v1881()
        if _G.Ox.KorlessMorph.Connection then
            _G.Ox.KorlessMorph.Connection:Disconnect()
        end
        _G.Ox.KorlessMorph.Connection = v4.CharacterAdded:Connect(function()
            task.wait(1)
            v1881()
        end)
    end
    v1892 = function()
        local v1883 = v4.Character
        local v1884 = v1883 and v4.Character:FindFirstChild("HumanoidRootPart")
        if not v1884 then
            return
        end
        local v1885 = nil
        for v1890, v1891 in ipairs(workspace:GetDescendants()) do
            if string.lower(v1891.Name) == "fininshline" and v1891:IsA("BasePart") then
                v1885 = v1891
                break
            end
        end
        if not v1885 then
            v1:Notify({
                Title = "Instan Escape",
                Description = "Finish line tidak ditemukan!",
                Duration = 2,
            })
            return
        end
        v1884.CFrame = v1885.CFrame + Vector3.new(0, 5, 0)
        v1:Notify({
            Title = "Instan Escape",
            Description = "Berhasil!",
            Duration = 2,
        })
    end
    SetupNextKillerIndicator = function()
        if _G.Ox.NextKiller.IndicatorGui then
            _G.Ox.NextKiller.IndicatorGui:Destroy()
        end
        _G.Ox.NextKiller.IndicatorGui = Instance.new("ScreenGui")
        _G.Ox.NextKiller.IndicatorGui.Name = "NextKillerIndicator"
        _G.Ox.NextKiller.IndicatorGui.ResetOnSpawn = false
        _G.Ox.NextKiller.IndicatorGui.Parent = v4:WaitForChild("PlayerGui")
    end
    StartNextKiller = function()
        if _G.Ox.NextKiller.IndicatorGui then
            return
        end
        SetupNextKillerIndicator()
        task.spawn(function()
            while _G.Ox.NextKiller.Enabled and _G.Ox.NextKiller.IndicatorGui do
                local v1893 = _G.Ox.NextKiller.IndicatorGui:FindFirstChild("NextKillerDisplay")
                local v1894 = v1893
                if not v1893 then
                    local v1895 = Instance.new("TextLabel")
                    v1894 = v1895
                    v1895.Name = "NextKillerDisplay"
                    v1895.Size = UDim2.new(0, 150, 0, 22)
                    v1895.Position = UDim2.new(0.5, 0, 0, 10)
                    v1895.AnchorPoint = Vector2.new(0.5, 0)
                    v1895.BackgroundTransparency = 0.15
                    v1895.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
                    v1895.TextColor3 = Color3.fromRGB(220, 220, 230)
                    v1895.Font = Enum.Font.GothamMedium
                    v1895.TextSize = 11
                    v1895.RichText = true
                    v1895.Parent = _G.Ox.NextKiller.IndicatorGui
                    local v1896 = Instance.new("UICorner")
                    v1896.CornerRadius = UDim.new(0, 6)
                    v1896.Parent = v1895
                    local v1897 = Instance.new("UIStroke")
                    v1897.Thickness = 1
                    v1897.Color = Color3.fromRGB(60, 60, 70)
                    v1897.Transparency = 0.3
                    v1897.Parent = v1895
                end
                local v1898 = v3:GetPlayers()
                table.sort(v1898, function(a163, a164)
                    local v1899 = a163:GetAttribute("AllowKiller")
                    local v1900 = v1899 or false
                    local v1901 = a164:GetAttribute("AllowKiller")
                    local v1902 = v1901 or false
                    if v1900 ~= v1902 then
                        return v1900
                    end
                    local v1903 = a163:GetAttribute("KillerChance")
                    local v1904 = v1903 or 0
                    local v1905 = a164:GetAttribute("KillerChance")
                    local v1906 = v1905 or 0
                    local v1907 = v1906 < v1904
                    return v1907
                end)
                local v1908 = v1898[1]
                if v1908 then
                    local v1909 = v1908 == v4 and "<font color='#ff5555'>KAMU</font>" or v1908.Name
                    v1894.Text = "Next Killer: " .. v1909
                else
                    v1894.Text = "Next Killer: <font color='#888888'>Waiting...</font>"
                end
                task.wait(1.5)
            end
        end)
    end
    StopNextKiller = function()
        if _G.Ox.NextKiller.IndicatorGui then
            _G.Ox.NextKiller.IndicatorGui:Destroy()
            _G.Ox.NextKiller.IndicatorGui = nil
        end
    end
    v1910 = function(a165)
        _G.Ox.NextKiller.Enabled = a165
        if a165 then
            StartNextKiller()
            v1:Notify({
                Title = "Next Killer Display",
                Description = "AKTIF - Menampilkan prediksi killer selanjutnya",
                Duration = 3,
            })
        else
            StopNextKiller()
            v1:Notify({
                Title = "Next Killer Display",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    local v1912 = function()
        local v1911 = v10:FindFirstChild("MapPredictUI")
        if v1911 then
            v1911:Destroy()
        end
    end
    local v1918 = function()
        local v1913 = v10:FindFirstChild("MapPredictUI")
        if v1913 then
            return v1913
        end
        local v1914 = Instance.new("ScreenGui")
        v1914.Name = "MapPredictUI"
        v1914.ResetOnSpawn = false
        v1914.IgnoreGuiInset = true
        v1914.Parent = v10
        local v1915 = Instance.new("TextLabel")
        v1915.Name = "NextMapDisplay"
        v1915.Size = UDim2.new(0, 220, 0, 22)
        v1915.Position = UDim2.new(0.5, 0, 0, 36)
        v1915.AnchorPoint = Vector2.new(0.5, 0)
        v1915.BackgroundTransparency = 0.15
        v1915.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        v1915.TextColor3 = Color3.fromRGB(220, 220, 230)
        v1915.Font = Enum.Font.GothamMedium
        v1915.TextSize = 11
        v1915.RichText = true
        v1915.Text = "Next Map: <font color='#888888'>Waiting...</font>"
        v1915.Parent = v1914
        local v1916 = Instance.new("UICorner")
        v1916.CornerRadius = UDim.new(0, 6)
        v1916.Parent = v1915
        local v1917 = Instance.new("UIStroke")
        v1917.Thickness = 1
        v1917.Color = Color3.fromRGB(60, 60, 70)
        v1917.Transparency = 0.3
        v1917.Parent = v1915
        return v1914
    end
    local v1920 = function()
        local v1919 = workspace:FindFirstChild("Map")
        if not v1919 then
            return nil
        end
        if v1919:FindFirstChild("random shakes") or v1919:FindFirstChild("SCP-173 Room") or v1919:FindFirstChild("SCP-205 Room") then
            return "Site 68"
        end
        if v1919:FindFirstChild("HooksMeat") then
            return "BLOODBATH! Club"
        end
        if v1919:FindFirstChild("Gate") and v1919.Gate:FindFirstChild("vfx") then
            return "Firelink Shrine"
        end
        if v1919:FindFirstChild("Bldg_Addon_RooftopUnit_A") or v1919:FindFirstChild("Rooftop") then
            return "Mercy Hospital Rooftop"
        end
        if v1919:FindFirstChild("White Armored Car") then
            return "Mount Massive Asylum"
        end
        if v1919:FindFirstChild("Dumbster") then
            return "The Bay Harbor"
        end
        if v1919:FindFirstChild("water pump") then
            return "Valdelobos Village"
        end
        if not v1919:FindFirstChild("LargeBoulder01") then
            return nil
        end
        return "Woodview Cabin"
    end
    v1931 = function(a166)
        _G.Ox.MapPredict.Enabled = a166
        if a166 then
            task.spawn(function()
                local v1921 = nil
                local v1922 = false
                while _G.Ox.MapPredict.Enabled do
                    local v1923 = v1918()
                    local v1924 = v1923:FindFirstChild("NextMapDisplay")
                    local v1925 = false
                    pcall(function()
                        local v1926 = v4.Team
                        local v1927 = v1926 and v4.Team.Name == "Spectator"
                        v1925 = v1927
                    end)
                    v1923.Enabled = v1925
                    if v1925 and v1924 then
                        local v1928 = workspace:FindFirstChild("Map") ~= nil
                        local v1929 = v1920()
                        if v1922 and not v1928 then
                            local v1930 = v1921 or "Unknown"
                            v1924.Text = "Next Map: " .. v1930
                        elseif v1928 and v1929 then
                            v1921 = v1929
                            v1924.Text = "Next Map: " .. v1929
                        elseif v1928 and not v1929 then
                            v1924.Text = "Next Map: Unknown"
                        else
                            v1924.Text = "Next Map: <font color='#888888'>Waiting...</font>"
                        end
                        v1922 = v1928
                    end
                    task.wait(0.5)
                end
                v1912()
            end)
            v1:Notify({
                Title = "Next Map Prediction",
                Description = "AKTIF - Menampilkan prediksi map selanjutnya",
                Duration = 3,
            })
        else
            v1912()
            v1:Notify({
                Title = "Next Map Prediction",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    local v1934 = function(a167)
        local v1932 = tostring
        local v1933 = a167 or ""
        return v1932(v1933):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    end
    local v1940 = function(a168)
        local v1935 = tostring
        local v1936 = a168 or ""
        local v1937, v1938 = v1935(v1936):match("^(.+)%s+(%d+)$")
        if not v1937 then
            return nil
        end
        local v1939 = v1937:gsub("^%s+", ""):gsub("%s+$", "")
        if v1939 == "" then
            return nil
        end
        if not ({
            head = true,
            torso = true,
            humanoid = true,
            humanoidrootpart = true,
            ["left arm"] = true,
            ["right arm"] = true,
            ["left leg"] = true,
            ["right leg"] = true,
        })[v1939:lower()] then
            return v1939, v1938
        end
        return nil
    end
    local v1949 = function()
        for v1945, v1946 in ipairs(v3:GetPlayers()) do
            local v1947 = v1946.Team
            local v1948 = v1947 and v1946.Team.Name
            if v1948 and v1948:lower():find("killer") then
                return v1946
            end
        end
        return nil
    end
    local v1963 = function(a169)
        if not a169 then
            return {}
        end
        local v1950 = a169.Character
        local v1951 = v1950 or workspace:FindFirstChild(a169.Name) or workspace:FindFirstChild(a169.DisplayName)
        if not v1951 then
            return {}
        end
        local v1952 = {}
        local v1953 = {}
        for v1958, v1959 in ipairs(v1951:GetChildren()) do
            local v1960, v1961 = v1940(v1959.Name)
            if v1960 and not v1953[v1960] then
                v1953[v1960] = true
                table.insert(v1952, {Name = v1960, Level = v1961})
            end
        end
        table.sort(v1952, function(a170, a171)
            local v1962 = tostring(a170.Name) < tostring(a171.Name)
            return v1962
        end)
        return v1952
    end
    local v1985 = function()
        local v1964 = v1949()
        local v1965 = v1964
        if v1964 then
            local v1966 = v1964.DisplayName
            v1965 = v1966 or v1964.Name
        end
        if not v1965 then
            v1965 = "Unknown"
        end
        local v1967 = v1963(v1964)
        local v1968 = v1967
        if #v1967 == 0 then
            for v1973, v1974 in ipairs(v3:GetPlayers()) do
                local v1975 = v1963(v1974)
                if #v1975 > 0 then
                    local v1976 = v1974.DisplayName
                    local v1977 = v1976 or v1974.Name
                    v1965 = v1977
                    v1968 = v1975
                    break
                end
            end
        end
        local v1978 = {
            "Killer Perks [<font color=\"rgb(255,80,80)\">" .. v1934(v1965) .. "</font>]",
        }
        if #v1968 == 0 then
            table.insert(v1978, "<font color=\"rgb(200,200,200)\">- Waiting for perk data...</font>")
        else
            for v1981 = 1, math.min(#v1968, 4) do
                local v1982 = v1968[v1981]
                local v1983 = v1982.Level
                local v1984 = v1983 and " lvl " .. tostring(v1982.Level) or ""
                table.insert(v1978, "<font color=\"rgb(200,200,200)\">- " .. v1934(v1982.Name .. v1984) .. "</font>")
            end
        end
        return table.concat(v1978, "\n"), #v1968
    end
    local v2012 = function()
        if _G.Ox.KillerPerks.Gui then
            pcall(function()
                _G.Ox.KillerPerks.Gui:Destroy()
            end)
            _G.Ox.KillerPerks.Gui = nil
        end
        if not _G.Ox.KillerPerks.Enabled then
            return
        end
        local v1986 = Instance.new("ScreenGui")
        v1986.Name = "NEX_KillerPerksGui"
        v1986.ResetOnSpawn = false
        v1986.IgnoreGuiInset = true
        v1986.Parent = v10
        local v1987 = Instance.new("Frame")
        v1987.Name = "Holder"
        v1987.Size = UDim2.new(0, 180, 0, 85)
        v1987.Position = UDim2.new(0.08, 0, 0.22, 0)
        v1987.BackgroundTransparency = 1
        v1987.Active = true
        v1987.Parent = v1986
        local v1988 = Instance.new("Frame")
        v1988.Name = "Panel"
        v1988.Size = UDim2.new(1, 0, 1, 0)
        v1988.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        v1988.BackgroundTransparency = 0.15
        v1988.BorderSizePixel = 0
        v1988.Parent = v1987
        Instance.new("UICorner", v1988).CornerRadius = UDim.new(0, 6)
        local v1989 = Instance.new("UIStroke")
        v1989.Color = Color3.fromRGB(60, 60, 70)
        v1989.Thickness = 1
        v1989.Transparency = 0.3
        v1989.Parent = v1988
        local v1990 = Instance.new("Frame")
        v1990.Size = UDim2.new(1, 0, 0, 24)
        v1990.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        v1990.BorderSizePixel = 0
        v1990.Parent = v1988
        Instance.new("UICorner", v1990).CornerRadius = UDim.new(0, 6)
        local v1991 = Instance.new("TextLabel")
        v1991.Size = UDim2.new(1, -60, 1, 0)
        v1991.Position = UDim2.new(0, 8, 0, 0)
        v1991.BackgroundTransparency = 1
        v1991.Font = Enum.Font.GothamSemibold
        v1991.Text = "Killer Perks Info"
        v1991.TextColor3 = Color3.fromRGB(220, 220, 230)
        v1991.TextSize = 11
        v1991.TextXAlignment = Enum.TextXAlignment.Left
        v1991.Parent = v1990
        local v1994 = function(a172, a173, a174)
            local v1992 = Instance.new("TextButton")
            v1992.Size = UDim2.new(0, 26, 0, 16)
            v1992.Position = UDim2.new(1, a173, 0, 4)
            local v1993 = a174 or Color3.fromRGB(25, 25, 30)
            v1992.BackgroundColor3 = v1993
            v1992.BorderSizePixel = 0
            v1992.Font = Enum.Font.GothamMedium
            v1992.Text = a172
            v1992.TextColor3 = Color3.fromRGB(200, 200, 210)
            v1992.TextSize = 9
            v1992.Parent = v1990
            Instance.new("UICorner", v1992).CornerRadius = UDim.new(0, 4)
            return v1992
        end
        local v1995 = v1994("Minimize", -54, Color3.fromRGB(30, 30, 40))
        local v1996 = v1994("Close", -28, Color3.fromRGB(40, 25, 25))
        local v1997 = Instance.new("TextLabel")
        v1997.Name = "KillerPerksText"
        v1997.Size = UDim2.new(1, -14, 1, -32)
        v1997.Position = UDim2.new(0, 8, 0, 28)
        v1997.BackgroundTransparency = 1
        v1997.Font = Enum.Font.GothamMedium
        v1997.RichText = true
        v1997.TextXAlignment = Enum.TextXAlignment.Left
        v1997.TextYAlignment = Enum.TextYAlignment.Top
        v1997.TextColor3 = Color3.fromRGB(220, 220, 230)
        v1997.TextSize = 11
        v1997.TextWrapped = false
        v1997.Parent = v1988
        v1995.MouseButton1Click:Connect(function()
            local v1998 = _G.Ox.KillerPerks
            local v1999
            if _G.Ox.KillerPerks.Minimized then
                v1999 = false
            else
                v1999 = true
            end
            v1998.Minimized = v1999
            local v2000
            if _G.Ox.KillerPerks.Minimized then
                v2000 = false
            else
                v2000 = true
            end
            v1997.Visible = v2000
            local v2001 = _G.Ox.KillerPerks.Minimized
            local v2002 = v2001 and "Show" or "Minimize"
            v1995.Text = v2002
            local v2003 = _G.Ox.KillerPerks.Minimized
            local v2004 = v2003 and UDim2.new(0, 180, 0, 24) or UDim2.new(0, 180, 0, 85)
            v1987.Size = v2004
        end)
        v1996.MouseButton1Click:Connect(function()
            _G.Ox.KillerPerks.Enabled = false
            if _G.Ox.KillerPerks.Gui then
                pcall(function()
                    _G.Ox.KillerPerks.Gui:Destroy()
                end)
                _G.Ox.KillerPerks.Gui = nil
            end
            if KillerPerksToggle then
                v384(KillerPerksToggle, false)
            end
        end)
        local v2005 = false
        local v2006 = nil
        local v2007 = nil
        v1987.InputBegan:Connect(function(a175)
            if a175.UserInputType == Enum.UserInputType.MouseButton1 or a175.UserInputType == Enum.UserInputType.Touch then
                v2005 = true
                v2006 = a175.Position
                v2007 = v1987.Position
                a175.Changed:Connect(function()
                    if a175.UserInputState == Enum.UserInputState.End then
                        v2005 = false
                    end
                end)
            end
        end)
        v6.InputChanged:Connect(function(a176)
            if not v2005 or not v2006 or not v2007 then
                return
            end
            if a176.UserInputType ~= Enum.UserInputType.MouseMovement and a176.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local v2008 = a176.Position - v2006
            v1987.Position = UDim2.new(v2007.X.Scale, v2007.X.Offset + v2008.X, v2007.Y.Scale, v2007.Y.Offset + v2008.Y)
        end)
        v1986.Parent = v10
        _G.Ox.KillerPerks.Gui = v1986
        task.spawn(function()
            while _G.Ox.KillerPerks.Enabled and _G.Ox.KillerPerks.Gui do
                if not _G.Ox.KillerPerks.Minimized then
                    local v2009, v2010 = v1985()
                    v1997.Text = v2009
                    local v2011 = math.max(2, math.min(v2010 + 1, 5))
                    v1987.Size = UDim2.new(0, 180, 0, math.max(65, 28 + v2011 * 15))
                end
                task.wait(1)
            end
        end)
    end
    v2013 = function(a177)
        _G.Ox.KillerPerks.Enabled = a177
        if a177 then
            v2012()
            v1:Notify({
                Title = "Killer Perks Display",
                Description = "AKTIF - Menampilkan perk killer yang digunakan",
                Duration = 3,
            })
        else
            if _G.Ox.KillerPerks.Gui then
                pcall(function()
                    _G.Ox.KillerPerks.Gui:Destroy()
                end)
                _G.Ox.KillerPerks.Gui = nil
            end
            v1:Notify({
                Title = "Killer Perks Display",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    PlayHitSound = function()
        if not _G.Ox.Stun.HitSoundEnabled then
            return
        end
        local v2014 = tick()
        if v2014 - _G.Ox.Stun.HitSoundLastTime < _G.Ox.Stun.HitSoundCooldown then
            return
        end
        _G.Ox.Stun.HitSoundLastTime = v2014
        pcall(function()
            local v2015 = Instance.new("Sound")
            v2015.SoundId = _G.Ox.Stun.HitSoundId
            v2015.Volume = _G.Ox.Stun.HitSoundVolume
            v2015.PlayOnRemove = true
            local v2016 = workspace.CurrentCamera
            local v2017 = v2016 or workspace
            v2015.Parent = v2017
            v2015:Play()
            task.delay(v2015.TimeLength + 0.1, function()
                if v2015 and v2015.Parent then
                    v2015:Destroy()
                end
            end)
        end)
    end
    local v2026 = function(a178)
        local v2018 = a178:FindFirstChild("HumanoidRootPart")
        if not v2018 then
            return nil
        end
        local v2019 = v2018:FindFirstChild("StunRingUI")
        if v2019 then
            v2019:Destroy()
        end
        local v2020 = Instance.new("BillboardGui")
        v2020.Name = "StunRingUI"
        v2020.Adornee = v2018
        v2020.AlwaysOnTop = true
        v2020.Size = UDim2.new(0, 40, 0, 40)
        v2020.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
        v2020.ResetOnSpawn = false
        v2020.LightInfluence = 0
        v2020.Parent = v2018
        local v2021 = Instance.new("ImageLabel", v2020)
        v2021.Size = UDim2.new(1, 0, 1, 0)
        v2021.Position = UDim2.new(0, 0, 0, 0)
        v2021.BackgroundTransparency = 1
        v2021.Image = "rbxassetid://129594563448607"
        v2021.ScaleType = Enum.ScaleType.Fit
        v2020.Enabled = false
        return v2020, task.spawn(function()
            local v2022 = 0
            local v2023 = workspace.CurrentCamera
            while v2020 and v2020.Parent do
                if v2020.Enabled then
                    local v2024 = (v2022 + 6) % 360
                    v2022 = v2024
                    v2021.Rotation = v2024
                    local v2025 = math.clamp(math.floor(600 / (v2023.CFrame.Position - v2018.Position).Magnitude), 22, 44)
                    v2020.Size = UDim2.new(0, v2025, 0, v2025)
                end
                task.wait(0.1)
            end
        end)
    end
    local v2033 = function(a179)
        if not a179 or _G.Ox.Stun.Data[a179] then
            return
        end
        local v2027, v2028 = v2026(a179)
        if not v2027 then
            return
        end
        local v2029 = {
            stunRing = v2027,
            stunSpinThread = v2028,
            _stunTimer = nil,
            extraConns = {},
        }
        _G.Ox.Stun.Data[a179] = v2029
        local v2030 = function(a180)
            if not v2029.stunRing then
                return
            end
            v2029.stunRing.Enabled = true
            if v2029._stunTimer then
                task.cancel(v2029._stunTimer)
            end
            v2029._stunTimer = task.delay(a180, function()
                if v2029.stunRing then
                    v2029.stunRing.Enabled = false
                end
            end)
        end
        local v2031 = a179:GetAttributeChangedSignal("IsStunned"):Connect(function()
            if a179:GetAttribute("IsStunned") == true then
                v2030(2.2)
            end
        end)
        local v2032 = a179:GetAttributeChangedSignal("Immobile"):Connect(function()
            if a179:GetAttribute("Immobile") == true then
                v2030(2.2)
            end
        end)
        table.insert(v2029.extraConns, v2031)
        table.insert(v2029.extraConns, v2032)
    end
    local v2041 = function(a181)
        local v2034 = _G.Ox.Stun.Data[a181]
        if v2034 then
            if v2034._stunTimer then
                task.cancel(v2034._stunTimer)
            end
            if v2034.stunSpinThread then
                task.cancel(v2034.stunSpinThread)
            end
            if v2034.stunRing then
                v2034.stunRing:Destroy()
            end
            if v2034.extraConns then
                for v2039, v2040 in ipairs(v2034.extraConns) do
                    pcall(function()
                        v2040:Disconnect()
                    end)
                end
            end
            _G.Ox.Stun.Data[a181] = nil
        end
    end
    local v2048 = function()
        if not _G.Ox.Stun.Enabled then
            return
        end
        for v2046, v2047 in ipairs(v3:GetPlayers()) do
            if IsKiller(v2047) and v2047.Character then
                v2033(v2047.Character)
            end
        end
    end
    v3.PlayerAdded:Connect(function(a182)
        if not _G.Ox.Stun.Enabled then
            return
        end
        a182.CharacterAdded:Connect(function(a183)
            task.wait(0.5)
            if _G.Ox.Stun.Enabled and IsKiller(a182) then
                v2033(a183)
            end
        end)
        task.wait(0.5)
        if _G.Ox.Stun.Enabled and IsKiller(a182) and a182.Character then
            v2033(a182.Character)
        end
    end)
    v3.PlayerAdded:Connect(function(a184)
        a184:GetPropertyChangedSignal("Team"):Connect(function()
            if not _G.Ox.Stun.Enabled then
                return
            end
            task.wait(0.5)
            if IsKiller(a184) and a184.Character then
                v2041(a184.Character)
                task.wait(0.1)
                v2033(a184.Character)
            end
        end)
    end)
    v3.PlayerAdded:Connect(function(a185)
        task.wait(0.5)
        if _G.Ox.Stun.Enabled then
            v2048()
        end
    end)
    v4.CharacterAdded:Connect(function()
        task.wait(1.5)
        if _G.Ox.Stun.Enabled then
            v2048()
        end
    end)
    task.spawn(function()
        local v2049, v2050, v2051, v2052, v2053, v2054, v2055, v2056
        v2056 = 1
        while true do
            if v2056 == 1 then
                if _G.Ox.ScriptAlive then
                    v2056 = 2
                else
                    v2056 = 9
                end
            elseif v2056 == 2 then
                task.wait(5)
                if _G.Ox.ScriptAlive then
                    v2056 = 3
                else
                    v2056 = 9
                end
            elseif v2056 == 3 then
                if _G.Ox.Stun.Enabled then
                    v2056 = 4
                else
                    v2056 = 1
                end
            elseif v2056 == 4 then
                v2049, v2050, v2051 = ipairs(v3:GetPlayers())
                v2052 = v2051
                v2056 = 5
            elseif v2056 == 5 then
                v2053, v2054 = v2049(v2050, v2052)
                if v2053 == nil then
                    v2056 = 1
                else
                    v2056 = 6
                end
            elseif v2056 == 6 then
                v2052 = v2053
                if IsKiller(v2054) and v2054.Character then
                    v2056 = 7
                else
                    v2056 = 5
                end
            elseif v2056 == 7 then
                v2055 = v2054.Character:FindFirstChild("HumanoidRootPart")
                if v2055 and not v2055:FindFirstChild("StunRingUI") then
                    v2056 = 8
                else
                    v2056 = 5
                end
            elseif v2056 == 8 then
                v2033(v2054.Character)
                v2056 = 5
            elseif v2056 == 9 then
                return
            end
        end
    end)
    v2067 = function(a186)
        _G.Ox.Stun.Enabled = a186
        if a186 then
            for v2061 in pairs(_G.Ox.Stun.Data) do
                v2041(v2061)
            end
            _G.Ox.Stun.Data = {}
            task.wait(0.5)
            v2048()
            v1:Notify({
                Title = "Stun Indicator",
                Description = "AKTIF - Menampilkan stun pada killer",
                Duration = 3,
            })
        else
            for v2066 in pairs(_G.Ox.Stun.Data) do
                v2041(v2066)
            end
            _G.Ox.Stun.Data = {}
            v1:Notify({
                Title = "Stun Indicator",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    AntiHook_GetRemote = function()
        if _G.Ox.AntiHook.Remote and _G.Ox.AntiHook.Remote.Parent then
            return _G.Ox.AntiHook.Remote
        end
        local v2068 = v9:FindFirstChild("Remotes")
        local v2069 = v2068 and v2068:FindFirstChild("Game")
        local v2070 = v2069 and v2069:FindFirstChild("UpdateCharacterLook")
        _G.Ox.AntiHook.Remote = v2070
        return v2070
    end
    AntiHook_SendRemoteUpdate = function()
        if not v4.Character then
            return
        end
        local v2071 = AntiHook_GetRemote()
        if not v2071 then
            return
        end
        local v2072 = CFrame.new(0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        local v2073 = CFrame.new(0, _G.Ox.AntiHook.OffsetY, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        pcall(function()
            v2071:FireServer(v2072, v2073, v2073, v2073, v2073)
            local v2074 = _G.Ox.AntiHook
            v2074.SendCounter = v2074.SendCounter + 1
        end)
    end
    AntiHook_Update = function(a187)
        if not _G.Ox.AntiHook.Enabled then
            return
        end
        local v2075 = v4.Character
        if not v2075 then
            _G.Ox.AntiHook.Accumulator = 0
            return
        end
        if v2075:GetAttribute("IsCarried") == true then
            local v2076 = _G.Ox.AntiHook.Accumulator + a187
            local v2077 = _G.Ox.AntiHook.Interval
            if v2077 <= v2076 then
                local v2078 = v2076 - v2077
                AntiHook_SendRemoteUpdate()
                if v2077 <= v2078 then
                    local v2079 = v2078 - v2077
                    AntiHook_SendRemoteUpdate()
                    if v2077 <= v2079 then
                        AntiHook_SendRemoteUpdate()
                        _G.Ox.AntiHook.Accumulator = v2079 - v2077
                        return
                    end
                    _G.Ox.AntiHook.Accumulator = v2079
                    return
                end
                _G.Ox.AntiHook.Accumulator = v2078
                return
            end
            _G.Ox.AntiHook.Accumulator = v2076
            return
        end
        _G.Ox.AntiHook.Accumulator = 0
    end
    StartAntiHook = function()
        if _G.Ox.AntiHook.Connection then
            return
        end
        _G.Ox.AntiHook.Accumulator = 0
        _G.Ox.AntiHook.Connection = v5.Heartbeat:Connect(AntiHook_Update)
    end
    StopAntiHook = function()
        if _G.Ox.AntiHook.Connection then
            _G.Ox.AntiHook.Connection:Disconnect()
            _G.Ox.AntiHook.Connection = nil
        end
        _G.Ox.AntiHook.Accumulator = 0
    end
    task.spawn(function()
        while true do
            task.wait(1)
            local v2080 = os.clock()
            local v2081 = v2080 - _G.Ox.AntiHook.LastCounterTime
            local v2082 = _G.Ox.AntiHook.SendCounter
            if _G.Ox.AntiHook.Enabled and v2081 > 0 and v2082 > 0 then
                print(string.format("[AntiHook] Actual rate: %.2f Hz (%d sends in %.2fs)", v2082 / v2081, v2082, v2081))
            end
            _G.Ox.AntiHook.SendCounter = 0
            _G.Ox.AntiHook.LastCounterTime = v2080
        end
    end)
    ToggleAntiHook = function(a188)
        _G.Ox.AntiHook.Enabled = a188
        if a188 then
            StartAntiHook()
            v1:Notify({Title = "Anti Hook", Description = "AKTIF", Duration = 2})
        else
            StopAntiHook()
            v1:Notify({
                Title = "Anti Hook",
                Description = "NONAKTIF",
                Duration = 2,
            })
        end
    end
    local v2083 = v2:CreateTab("Main", false, false)
    MainTab = v2083
    local v2084 = MainTab:CreatePage("Main")
    M_Page = v2084
    local v2085 = M_Page:CreateSection("Movement", "move")
    MovementCard = v2085
    local v2089 = MovementCard:AddToggle("Auto Vault", false, function(a189)
        _G.Ox.autoVaultEnabled = a189
        local v2086 = v1.Notify
        local v2087 = {Title = "Auto Vault"}
        local v2088 = a189 and "AKTIF" or "NONAKTIF"
        v2087.Description = v2088
        v2087.Duration = 2
        v2086(v1, v2087)
    end, {Flag = "AutoVault"})
    AutoVaultToggle = v2089
    AutoVaultToggle:AddKeyPicker("None")
    local v2093 = MovementCard:AddToggle("Auto Pallet Slide", false, function(a190)
        _G.Ox.autoPalletSlideEnabled = a190
        local v2090 = v1.Notify
        local v2091 = {Title = "Auto Pallet Slide"}
        local v2092 = a190 and "AKTIF" or "NONAKTIF"
        v2091.Description = v2092
        v2091.Duration = 2
        v2090(v1, v2091)
    end, {Flag = "AutoPalletSlide"})
    AutoSlideToggle = v2093
    AutoSlideToggle:AddKeyPicker("None")
    local v2094 = MovementCard:AddToggle("Auto Run PC", false, function(a191)
        _G.Ox.AutoRun.PC = a191
        if a191 then
            task.spawn(function()
                while _G.Ox.AutoRun.PC do
                    v7:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, v4:GetMouse())
                    task.wait(0.1)
                end
            end)
        else
            v7:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, v4:GetMouse())
        end
    end, {Flag = "AutoRunPc"})
    AutoRunPCToggle = v2094
    local v2095 = MovementCard:AddToggle("Auto Run Mobile", false, function(a192)
        _G.Ox.AutoRun.Mobile = a192
        if a192 then
            v567()
        else
            v568()
        end
    end, {Flag = "AutoRunMobile"})
    AutoRunMobileToggle = v2095
    local v2099 = MovementCard:AddToggle("Enable Speed Boost", false, function(a193)
        _G.Ox.Speed.Enabled = a193
        local v2096 = v1.Notify
        local v2097 = {Title = "Speed Boost"}
        local v2098 = a193 and "AKTIF" or "NONAKTIF"
        v2097.Description = v2098
        v2097.Duration = 2
        v2096(v1, v2097)
    end, {Flag = "SpeedBoost"})
    SpeedToggle = v2099
    SpeedToggle:AddKeyPicker("SpeedBoostKey", {
        Default = "None",
        Text = "Toggle Speed Boost",
        Mode = "Toggle",
        Callback = function(a194)
            _G.Ox.Speed.Enabled = a194
            if SpeedToggle then
                v384(SpeedToggle, a194)
            end
        end,
    })
    MovementCard:AddSlider("SpeedAmount", 0.1, 3, 0.1, function(a195)
        _G.Ox.Speed.Value = a195
    end, {Increment = 0.1, Flag = "SpeedAmount"})
    _G.Ox.SkipEndscreen = false
    local v2100 = M_Page:CreateSection("Server Utility", "server-cog")
    ServerUtilityCard = v2100
    local v2104 = ServerUtilityCard:AddToggle("Skip Endscreen", false, function(a196)
        _G.Ox.SkipEndscreen = a196
        local v2101 = v1.Notify
        local v2102 = {Title = "Skip Endscreen"}
        local v2103 = a196 and "AKTIF - Endscreen otomatis dilewati" or "NONAKTIF"
        v2102.Description = v2103
        v2102.Duration = 2
        v2101(v1, v2102)
    end, {Flag = "SkipEndscreen"})
    SkipEndscreenToggle = v2104
    SkipEndscreenToggle:AddKeyPicker("SkipEndKey", {
        Default = "None",
        Text = "Toggle Skip Endscreen",
        Mode = "Toggle",
        Callback = function(a197)
            _G.Ox.SkipEndscreen = a197
            if SkipEndscreenToggle then
                SkipEndscreenToggle:SetValue(a197)
            end
        end,
    })
    task.spawn(function()
        while _G.Ox.ScriptAlive do
            if _G.Ox.SkipEndscreen then
                pcall(function()
                    local v2105 = workspace:FindFirstChild("Map")
                    if v2105 then
                        local v2106 = v2105:FindFirstChild("endscreen", true)
                        if v2106 then
                            for v2111, v2112 in ipairs(v2106:GetDescendants()) do
                                if v2112:IsA("LocalScript") then
                                    v2112.Disabled = true
                                end
                            end
                            v2106:Destroy()
                        end
                    end
                    local v2113 = v11:FindFirstChild("Results")
                    if v2113 then
                        local v2114 = v2113:FindFirstChild("Frame")
                        if v2114 then
                            local v2115 = v2114:FindFirstChild("Close")
                            if v2115 and v2114.Visible and v2115.Visible then
                                pcall(function()
                                    firesignal(v2115.MouseButton1Click)
                                end)
                            end
                        end
                    end
                end)
            end
            task.wait(1)
        end
    end)
    local v2116 = M_Page:CreateSection("Fake Perks", "sparkles")
    FakePerksCard = v2116
    local v2117 = FakePerksCard:AddToggle("Quick Recovery", false, function(a198)
        ToggleQuickRecovery(a198)
    end, {Flag = "FakeQR"})
    QR_Toggle = v2117
    QR_Toggle:AddKeyPicker("None")
    local v2118 = FakePerksCard:AddToggle("Perfect Landing", false, function(a199)
        TogglePerfectLanding(a199)
    end, {Flag = "FakePL"})
    PL_Toggle = v2118
    PL_Toggle:AddKeyPicker("None")
    local v2119 = FakePerksCard:AddToggle("Flowstate", false, function(a200)
        ToggleFlowstate(a200)
    end, {Flag = "FakeFS"})
    FS_Toggle = v2119
    FS_Toggle:AddKeyPicker("None")
    local v2120 = FakePerksCard:AddToggle("Adrenaline Rush", false, function(a201)
        SetupFakeAdrenalineRush(a201)
    end, {Flag = "FakeAR"})
    AR_Toggle = v2120
    AR_Toggle:AddKeyPicker("None")
    FakePerksCard:AddSlider("Perk Cooldown", 0, 180, 10, function(a202)
        _G.Ox.FakePerks.PerkCooldown = a202
    end, {Increment = 1, Flag = "FakePerkColdown"})
    local v2121 = M_Page:CreateSection("Camera Settings", "camera")
    CameraCard = v2121
    local v2122 = CameraCard:AddToggle("Enable Stretch Res", false, function(a203)
        v1310(a203)
    end, {Flag = "SretchRes"})
    StretchToggle = v2122
    StretchToggle:AddKeyPicker("None")
    CameraCard:AddSlider("Stretch Amount", 0.4, 1, 0.67, function(a204)
        _G.Ox.StretchRes.Amount = a204
    end, {Increment = 0.01, Flag = "StretchAmount"})
    local v2123 = CameraCard:AddToggle("Third Person (Killer)", false, function(a205)
        v1805(a205)
    end, {Flag = "ThirdPerson"})
    ThirdPersonToggle = v2123
    local v2124 = CameraCard:AddToggle("Infinity Zoom Out", false, function(a206)
        v1695(a206)
    end, {Flag = "InfinityZoom"})
    InfinityToggle = v2124
    local v2125 = CameraCard:AddToggle("Camera FOV", false, function(a207)
        v1699(a207)
    end, {Flag = "CameraFov"})
    FOVToggle = v2125
    CameraCard:AddSlider("FOV Value", 60, 120, 90, function(a208)
        v1700(a208)
    end, {Increment = 0, Flag = "FOVValue"})
    local v2126 = M_Page:CreateSection("Camera DBD", "camera")
    DbdCard = v2126
    _G.Ox.DBD = {
        Enabled = false,
        Distance = 13,
        Height = 4.2,
        RunSmooth = 0.1,
        LookSmooth = 0.28,
        Sens = 0.55,
        PitchMin = -0.55,
        PitchMax = 0.45,
        FOV = 70,
        yaw = 0,
        pitch = 0.12,
        lookInput = nil,
        lastPos = nil,
        conn = nil,
        chg = nil,
        beg = nil,
        endc = nil,
        oldFOV = nil,
    }
    DBD_isLookTouch = function(a209)
        local v2127 = v12.ViewportSize.X * 0.22 < a209.X
        return v2127
    end
    DBD_initYaw = function()
        local v2128 = v4.Character
        local v2129 = v2128 and v4.Character:FindFirstChild("HumanoidRootPart")
        if not v2129 then
            return
        end
        local v2130 = v2129.CFrame.LookVector * Vector3.new(1, 0, 1)
        if v2130.Magnitude > 0.05 then
            _G.Ox.DBD.yaw = math.atan2(-v2130.X, -v2130.Z)
        end
    end
    DBD_Stop = function()
        local v2131 = _G.Ox.DBD
        if v2131.conn then
            v2131.conn:Disconnect()
            v2131.conn = nil
        end
        if v2131.chg then
            v2131.chg:Disconnect()
            v2131.chg = nil
        end
        if v2131.beg then
            v2131.beg:Disconnect()
            v2131.beg = nil
        end
        if v2131.endc then
            v2131.endc:Disconnect()
            v2131.endc = nil
        end
        v12.CameraType = Enum.CameraType.Custom
        if v2131.oldFOV then
            v12.FieldOfView = v2131.oldFOV
        end
        v2131.lookInput = nil
        v2131.lastPos = nil
    end
    DBD_Start = function()
        DBD_Stop()
        local v2132 = _G.Ox.DBD
        if not v2132.Enabled then
            return
        end
        DBD_initYaw()
        v2132.oldFOV = v12.FieldOfView
        v12.CameraType = Enum.CameraType.Scriptable
        v12.FieldOfView = v2132.FOV
        local v2133 = v4.Character
        local v2134 = v2133 and v4.Character:FindFirstChildOfClass("Humanoid")
        if v2134 then
            v2134.AutoRotate = true
        end
        v2132.chg = v6.InputChanged:Connect(function(a210)
            if a210.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            if a210 ~= v2132.lookInput then
                return
            end
            local v2135 = a210.Position
            if v2132.lastPos then
                v2132.yaw = v2132.yaw - (v2135.X - v2132.lastPos.X) * 0.011 * v2132.Sens
                v2132.pitch = math.clamp(v2132.pitch - (v2135.Y - v2132.lastPos.Y) * 0.011 * v2132.Sens, v2132.PitchMin, v2132.PitchMax)
            end
            v2132.lastPos = v2135
        end)
        v2132.beg = v6.InputBegan:Connect(function(a211)
            if a211.UserInputType == Enum.UserInputType.Touch and DBD_isLookTouch(a211.Position) then
                v2132.lookInput = a211
                v2132.lastPos = a211.Position
            end
        end)
        v2132.endc = v6.InputEnded:Connect(function(a212)
            if a212 == v2132.lookInput then
                v2132.lookInput = nil
                v2132.lastPos = nil
            end
        end)
        v2132.conn = v5.RenderStepped:Connect(function(a213)
            if not v2132.Enabled then
                return
            end
            local v2136 = v4.Character
            local v2137 = v2136 and v4.Character:FindFirstChild("HumanoidRootPart")
            if not v2137 then
                return
            end
            local v2138 = Vector3.new(math.sin(v2132.yaw) * math.cos(v2132.pitch), math.sin(v2132.pitch), math.cos(v2132.yaw) * math.cos(v2132.pitch))
            local v2139 = v2137.Position + Vector3.new(0, 1.6, 0)
            local v2140 = v2139 - v2138 * v2132.Distance + Vector3.new(0, v2132.Height - 1.6, 0)
            local v2141 = CFrame.lookAt(v2140, v2139)
            local v2142 = v2132.lookInput
            local v2143 = v2142 and v2132.LookSmooth or v2132.RunSmooth
            local v2144 = 1 - math.pow(1 - v2143, a213 * 60)
            v12.CFrame = v12.CFrame:Lerp(v2141, v2144)
        end)
    end
    v4.CharacterAdded:Connect(function()
        task.wait(0.6)
        if _G.Ox.DBD.Enabled then
            DBD_Start()
        end
    end)
    DbdCard:AddToggle("DBD Camera", false, function(a214)
        _G.Ox.DBD.Enabled = a214
        if a214 then
            if _G.Ox.CameraFOV then
                _G.Ox.CameraFOV.Enabled = false
            end
            DBD_Start()
        else
            DBD_Stop()
        end
        local v2145 = v1.Notify
        local v2146 = {Title = "DBD Camera"}
        local v2147 = a214 and "AKTIF" or "NONAKTIF"
        v2146.Description = v2147
        v2146.Duration = 2
        v2145(v1, v2146)
    end, {Flag = "DBDCamera"})
    DbdCard:AddSlider("DBD Distance", 6, 20, 13, function(a215)
        _G.Ox.DBD.Distance = a215
    end, {Increment = 0.1, Flag = "DBDDistance"})
    DbdCard:AddSlider("DBD Height", 1, 8, 4.2, function(a216)
        _G.Ox.DBD.Height = a216
    end, {Increment = 0.1, Flag = "DBDHeight"})
    DbdCard:AddSlider("DBD Run Smooth", 0.03, 0.35, 0.1, function(a217)
        _G.Ox.DBD.RunSmooth = a217
    end, {Increment = 0.01, Flag = "DBDRunSmooth"})
    DbdCard:AddSlider("DBD Look Smooth", 0.08, 0.6, 0.28, function(a218)
        _G.Ox.DBD.LookSmooth = a218
    end, {Increment = 0.01, Flag = "DBDLookSmooth"})
    DbdCard:AddSlider("DBD Sensitivity", 0.15, 1.2, 0.55, function(a219)
        _G.Ox.DBD.Sens = a219
    end, {Increment = 0.01, Flag = "DBDSens"})
    DbdCard:AddSlider("DBD Pitch Min", -1.2, 0, -0.55, function(a220)
        _G.Ox.DBD.PitchMin = a220
    end, {Increment = 0.01, Flag = "DBDPitchMin"})
    DbdCard:AddSlider("DBD Pitch Max", 0, 1.2, 0.45, function(a221)
        _G.Ox.DBD.PitchMax = a221
    end, {Increment = 0.01, Flag = "DBDPitchMax"})
    DbdCard:AddSlider("DBD FOV", 50, 90, 70, function(a222)
        _G.Ox.DBD.FOV = a222
        if _G.Ox.DBD.Enabled then
            v12.FieldOfView = a222
        end
    end, {Increment = 1, Flag = "DBDFOV"})
    local v2148 = M_Page:CreateSection("Streamer Mode", "eye-off")
    StreamerCard = v2148
    local v2149 = StreamerCard:AddToggle("Streamer Mode", false, function(a223)
        v1306(a223)
    end, {Flag = "StreamerMode"})
    StreamerToggle = v2149
    StreamerToggle:AddKeyPicker("None")
    local v2150 = M_Page:CreateSection("Players Utility", "user-cog")
    UtilityCard = v2150
    local v2151 = UtilityCard:AddToggle("Invisibility [OP]", false, function(a224)
        _G.Ox.Utility.InvisEnabled = a224
        v765(a224)
    end, {Locked = false, LockText = "PREMIUM"})
    InvisToggle = v2151
    local v2152 = UtilityCard:AddToggle("Fast Bandage", false, function(a225)
        _G.Ox.Utility.BandageEnabled = a225
        v771(a225)
    end, {Locked = false, LockText = "PREMIUM"})
    BandageToggle = v2152
    UtilityCard:AddSlider("BandageSpeed", 10, 200, 50, function(a226)
        _G.Ox.Utility.BandageSpeed = a226
        if v766 and v766.Config then
            v766.Config.PreClicksCount = a226
        end
    end, {Increment = 1, Flag = "BandageSpeed"})
    local v2153 = UtilityCard:AddToggle("Moonwalk GUI", false, function(a227)
        if a227 then
            if not _G.Ox.Moonwalk.Gui then
                CreateMoonwalkGUI()
            end
            _G.Ox.Moonwalk.Gui.Enabled = true
            _G.Ox.Moonwalk.GuiVisible = true
            UpdateMoonwalkGUI(_G.Ox.Moonwalk.Enabled)
            v1:Notify({
                Title = "Moonwalk GUI",
                Description = "Gui Dimuat",
                Duration = 2,
            })
        else
            if _G.Ox.Moonwalk.Enabled then
                StopMoonwalk()
                if MoonwalkPCToggle then
                    v384(MoonwalkPCToggle, false)
                end
            end
            if _G.Ox.Moonwalk.Gui then
                _G.Ox.Moonwalk.Gui.Enabled = false
                _G.Ox.Moonwalk.GuiVisible = false
            end
            v1:Notify({
                Title = "Moonwalk GUI",
                Description = "Gui Disembunyikan",
                Duration = 2,
            })
        end
    end, {Flag = "MoonwalkGui"})
    MoonwalkGUIToggle = v2153
    local v2157 = UtilityCard:AddToggle("Moonwalk PC", false, function(a228)
        if a228 then
            StartMoonwalk()
        else
            StopMoonwalk()
        end
        UpdateMoonwalkGUI(_G.Ox.Moonwalk.Enabled)
        local v2154 = v1.Notify
        local v2155 = {Title = "Moonwalk PC"}
        local v2156 = a228 and "AKTIF" or "NONAKTIF"
        v2155.Description = v2156
        v2155.Duration = 2
        v2154(v1, v2155)
    end, {Flag = "MoonwalkPC"})
    MoonwalkPCToggle = v2157
    MoonwalkPCToggle:AddKeyPicker("MoonwalkPCKey", {
        Default = "None",
        Text = "Toggle Moonwalk",
        Mode = "Toggle",
        Callback = function(a229)
            if a229 then
                StartMoonwalk()
            else
                StopMoonwalk()
            end
            UpdateMoonwalkGUI(_G.Ox.Moonwalk.Enabled)
            if MoonwalkPCToggle then
                v384(MoonwalkPCToggle, a229)
            end
        end,
    })
    UtilityCard:AddButton("Fly GUI", function()
        local v2158 = false
        for v2163, v2164 in pairs(game.CoreGui:GetChildren()) do
            if v2164.Name:lower():find("fly") then
                v2158 = true
            end
        end
        if v2158 then
            v1:Notify({
                Title = "Fly GUI",
                Description = "Fly GUI sudah terbuka",
                Duration = 2,
            })
        else
            loadstring(game:HttpGet("https://raw.githubusercontent.com/XNEOFF/FlyGuiV3/main/FlyGuiV3.txt"))()
            v1:Notify({
                Title = "Fly GUI",
                Description = "Fly GUI Dimuat",
                Duration = 3,
            })
        end
    end)
    local v2165 = M_Page:CreateSection("Crosshair", "crosshair")
    CrosshairBox = v2165
    local v2169 = CrosshairBox:AddToggle("Enable Crosshair", false, function(a230)
        _G.Ox.Crosshair.Enabled = a230
        if not a230 then
            ClearCrosshair()
        end
        local v2166 = v1.Notify
        local v2167 = {Title = "Crosshair"}
        local v2168 = a230 and "AKTIF" or "NONAKTIF"
        v2167.Description = v2168
        v2167.Duration = 2
        v2166(v1, v2167)
    end, {Flag = "Crosshair"})
    CrosshairToggle = v2169
    CrosshairToggle:AddKeyPicker("CrosshairKey", {
        Default = "None",
        Text = "Toggle Crosshair",
        Mode = "Toggle",
        Callback = function(a231)
            _G.Ox.Crosshair.Enabled = a231
            if not a231 then
                ClearCrosshair()
            end
        end,
    })
    CrosshairToggle:AddColorPicker(_G.Ox.Crosshair.Color, {
        Flag = "Crosshair_Color",
        Title = "Crosshair Color",
        Callback = function(a232)
            _G.Ox.Crosshair.Color = a232
        end,
    })
    CrosshairBox:AddDropdown("Style", {"Plus", "Dot", "Circle"}, false, function(a233)
        _G.Ox.Crosshair.Style = a233
        ClearCrosshair()
        _G.Ox.CrosshairCreated = false
    end, {Flag = "CrosshairStyle"})
    CrosshairBox:AddSlider("Size", 2, 30, 8, function(a234)
        _G.Ox.Crosshair.Size = a234
    end, {Increment = 1, Flag = "CrosshairSize"})
    CrosshairBox:AddSlider("Thickness", 1, 5, 2, function(a235)
        _G.Ox.Crosshair.Thickness = a235
    end, {Increment = 1, Flag = "CrosshairThickness"})
    CrosshairBox:AddSlider("Position X", -100, 100, 0, function(a236)
        _G.Ox.Crosshair.OffsetX = a236
    end, {Increment = 1, Flag = "CrosshairX"})
    CrosshairBox:AddSlider("Position Y", -100, 100, 0, function(a237)
        _G.Ox.Crosshair.OffsetY = a237
    end, {Increment = 1, Flag = "CrosshairY"})
    local v2170 = M_Page:CreateSection("Copy Avatar", "shirt")
    FakeAvatarSection = v2170
    Pandu_RANDOM_IDS = {
        978663613,
        5261700291,
        1846241644,
        4993456331,
        424866237,
        4312175249,
    }
    Pandu_CURRENT_AVATAR = nil
    Pandu_ORIGINAL_ID = v4.UserId
    Pandu_FAVORITES = {}
    Pandu_Applying = false
    Pandu_RespawnConnection = nil
    Pandu_SelectedFav = nil
    Pandu_FakeThumbUserId = nil
    Pandu_ThumbConn = nil
    Pandu_ThumbPropConns = {}
    Pandu_ThumbUrl = function(a238, a239, a240)
        local v2171 = a239 or 150
        local v2172 = v2171
        local v2173 = a240 or 150
        local v2174 = v2173
        local v2175 = string.format
        local v2176 = tonumber(a238)
        local v2177 = v2176 or 0
        return v2175("rbxthumb://type=AvatarHeadShot&id=%d&w=%d&h=%d", v2177, v2172, v2174)
    end
    Pandu_ExtractThumbUserId = function(a241)
        if type(a241) == "string" and a241 ~= "" then
            return tonumber(a241:match("rbxthumb://[^%s]*id=(%d+)"))
        end
        return nil
    end
    Pandu_IsAvatarThumb = function(a242)
        if type(a242) ~= "string" then
            return false
        end
        local v2178 = a242:find("rbxthumb://", 1, true) ~= nil
        if v2178 then
            local v2179 = a242:find("AvatarHeadShot", 1, true)
            v2178 = v2179 or a242:find("AvatarBust", 1, true) or a242:find("type=Avatar", 1, true)
        end
        return v2178
    end
    Pandu_IsOurCurrentThumb = function(a243)
        if not a243:IsA("ImageLabel") and not a243:IsA("ImageButton") then
            return false
        end
        if a243:GetAttribute("PanduFakeThumb") == true then
            return true
        end
        local v2180 = Pandu_ExtractThumbUserId(a243.Image)
        if not v2180 or not Pandu_IsAvatarThumb(a243.Image) then
            return false
        end
        local v2181 = v2180 == Pandu_ORIGINAL_ID
        return v2181
    end
    Pandu_ForceSetThumb = function(a244, a245)
        if not a244 or not a245 then
            return
        end
        if not a244:IsA("ImageLabel") and not a244:IsA("ImageButton") then
            return
        end
        if not Pandu_IsOurCurrentThumb(a244) then
            return
        end
        if not a244:GetAttribute("PanduOrigThumb") then
            a244:SetAttribute("PanduOrigThumb", a244.Image)
        end
        local v2182, v2183 = tostring(a244.Image):match("w=(%d+).*h=(%d+)")
        local v2184 = Pandu_ThumbUrl
        local v2185 = tonumber(v2182)
        local v2186 = v2185 or 150
        local v2187 = tonumber(v2183)
        local v2188 = v2187 or 150
        local v2189 = v2184(a245, v2186, v2188)
        a244:SetAttribute("PanduFakeThumb", true)
        a244:SetAttribute("PanduFakeThumbId", tonumber(a245))
        if a244.Image ~= v2189 then
            a244.Image = v2189
        end
        if Pandu_ThumbPropConns[a244] then
            return
        end
        Pandu_ThumbPropConns[a244] = a244:GetPropertyChangedSignal("Image"):Connect(function()
            if Pandu_FakeThumbUserId and a244.Parent then
                local v2190 = Pandu_ExtractThumbUserId(a244.Image)
                if v2190 and v2190 ~= Pandu_ORIGINAL_ID and v2190 ~= Pandu_FakeThumbUserId then
                    a244:SetAttribute("PanduFakeThumb", nil)
                    a244:SetAttribute("PanduFakeThumbId", nil)
                    a244:SetAttribute("PanduOrigThumb", nil)
                    if Pandu_ThumbPropConns[a244] then
                        Pandu_ThumbPropConns[a244]:Disconnect()
                        Pandu_ThumbPropConns[a244] = nil
                    end
                    return
                end
                local v2191, v2192 = tostring(a244.Image):match("w=(%d+).*h=(%d+)")
                local v2193 = Pandu_ThumbUrl
                local v2194 = Pandu_FakeThumbUserId
                local v2195 = tonumber(v2191)
                local v2196 = v2195 or 150
                local v2197 = tonumber(v2192)
                local v2198 = v2197 or 150
                local v2199 = v2193(v2194, v2196, v2198)
                if a244.Image ~= v2199 then
                    a244.Image = v2199
                end
                return
            end
            if Pandu_ThumbPropConns[a244] then
                Pandu_ThumbPropConns[a244]:Disconnect()
                Pandu_ThumbPropConns[a244] = nil
            end
        end)
    end
    Pandu_RestoreThumb = function(a246)
        if not a246 then
            return
        end
        if not a246:IsA("ImageLabel") and not a246:IsA("ImageButton") then
            return
        end
        if a246:GetAttribute("PanduFakeThumb") ~= true then
            return
        end
        local v2200 = a246:GetAttribute("PanduOrigThumb")
        local v2201 = type(v2200) == "string" and v2200 ~= "" and v2200 or Pandu_ThumbUrl(Pandu_ORIGINAL_ID)
        a246.Image = v2201
        a246:SetAttribute("PanduFakeThumb", nil)
        a246:SetAttribute("PanduFakeThumbId", nil)
        a246:SetAttribute("PanduOrigThumb", nil)
        if Pandu_ThumbPropConns[a246] then
            Pandu_ThumbPropConns[a246]:Disconnect()
            Pandu_ThumbPropConns[a246] = nil
        end
    end
    Pandu_SweepSetThumb = function(a247)
        local v2202 = {v10, v4:FindFirstChild("PlayerGui")}
        local v2203, v2204, v2205 = ipairs(v2202)
        local v2206 = v2205
        local v2207 = v2203
        local v2208 = v2204
        while true do
            local v2209, v2210 = v2207(v2208, v2206)
            if v2209 == nil then
                break
            end
            v2206 = v2209
            if v2210 then
                for v2217, v2218 in ipairs(v2210:GetDescendants()) do
                    if Pandu_IsOurCurrentThumb(v2218) then
                        pcall(Pandu_ForceSetThumb, v2218, a247)
                    end
                end
                v2206 = v2209
            end
        end
    end
    Pandu_SweepRestoreThumb = function()
        local v2219 = {v10, v4:FindFirstChild("PlayerGui")}
        local v2220, v2221, v2222 = ipairs(v2219)
        local v2223 = v2222
        local v2224 = v2220
        local v2225 = v2221
        while true do
            local v2226, v2227 = v2224(v2225, v2223)
            if v2226 == nil then
                break
            end
            v2223 = v2226
            if v2227 then
                for v2234, v2235 in ipairs(v2227:GetDescendants()) do
                    pcall(Pandu_RestoreThumb, v2235)
                end
                v2223 = v2226
            end
        end
    end
    Pandu_SetFakeDisplayPicture = function(a248)
        local v2236 = tonumber(a248)
        if not v2236 then
            return
        end
        Pandu_FakeThumbUserId = v2236
        Pandu_SweepSetThumb(v2236)
        task.delay(0.4, function()
            if Pandu_FakeThumbUserId == v2236 then
                Pandu_SweepSetThumb(v2236)
            end
        end)
        task.delay(1.2, function()
            if Pandu_FakeThumbUserId == v2236 then
                Pandu_SweepSetThumb(v2236)
            end
        end)
        if Pandu_ThumbConn then
            Pandu_ThumbConn:Disconnect()
            Pandu_ThumbConn = nil
        end
        local v2237 = v10.DescendantAdded:Connect(function(a249)
            if not Pandu_FakeThumbUserId then
                return
            end
            task.defer(function()
                if Pandu_IsOurCurrentThumb(a249) then
                    pcall(Pandu_ForceSetThumb, a249, Pandu_FakeThumbUserId)
                end
            end)
        end)
        Pandu_ThumbConn = v2237
    end
    Pandu_ClearFakeDisplayPicture = function()
        Pandu_SweepRestoreThumb()
        task.delay(0.3, Pandu_SweepRestoreThumb)
        Pandu_FakeThumbUserId = nil
        if Pandu_ThumbConn then
            Pandu_ThumbConn:Disconnect()
            Pandu_ThumbConn = nil
        end
        for v2242, v2243 in pairs(Pandu_ThumbPropConns) do
            pcall(function()
                v2243:Disconnect()
            end)
            Pandu_ThumbPropConns[v2242] = nil
        end
    end
    Pandu_FakeDisplayName = nil
    Pandu_OriginalDisplayName = v4.DisplayName
    Pandu_NameCharConn = nil
    Pandu_SetCharacterDisplayName = function(a250)
        local v2244 = v4.Character
        local v2245 = v2244 and v2244:FindFirstChildOfClass("Humanoid")
        if v2245 and a250 then
            v2245.DisplayName = a250
        end
    end
    Pandu_LooksLikeOurName = function(a251)
        if type(a251) ~= "string" or a251 == "" then
            return false
        end
        local v2246 = a251 == v4.Name or a251 == v4.DisplayName or a251 == Pandu_OriginalDisplayName
        return v2246
    end
    Pandu_ApplyNameToLabel = function(a252, a253)
        if not a252 or not a253 then
            return
        end
        if not a252:IsA("TextLabel") and not a252:IsA("TextButton") then
            return
        end
        if a252:GetAttribute("PanduFakeName") == true or Pandu_LooksLikeOurName(a252.Text) then
            if not a252:GetAttribute("PanduOrigName") then
                a252:SetAttribute("PanduOrigName", a252.Text)
            end
            a252:SetAttribute("PanduFakeName", true)
            a252.Text = a253
        end
    end
    Pandu_RestoreNameLabel = function(a254)
        if not a254 then
            return
        end
        if not a254:IsA("TextLabel") and not a254:IsA("TextButton") then
            return
        end
        if a254:GetAttribute("PanduFakeName") ~= true then
            return
        end
        local v2247 = a254:GetAttribute("PanduOrigName")
        if type(v2247) == "string" and v2247 ~= "" then
            a254.Text = v2247
        else
            a254.Text = Pandu_OriginalDisplayName
        end
        a254:SetAttribute("PanduFakeName", nil)
        a254:SetAttribute("PanduOrigName", nil)
    end
    Pandu_SweepNames = function(a255)
        if not a255 then
            return
        end
        local v2248 = {v10, v4:FindFirstChild("PlayerGui")}
        local v2249, v2250, v2251 = ipairs(v2248)
        local v2252 = v2251
        local v2253 = v2249
        local v2254 = v2250
        while true do
            local v2255, v2256 = v2253(v2254, v2252)
            if v2255 == nil then
                break
            end
            v2252 = v2255
            if v2256 then
                for v2263, v2264 in ipairs(v2256:GetDescendants()) do
                    pcall(Pandu_ApplyNameToLabel, v2264, a255)
                end
                v2252 = v2255
            end
        end
    end
    Pandu_SweepRestoreNames = function()
        local v2265 = {v10, v4:FindFirstChild("PlayerGui")}
        local v2266, v2267, v2268 = ipairs(v2265)
        local v2269 = v2268
        local v2270 = v2266
        local v2271 = v2267
        while true do
            local v2272, v2273 = v2270(v2271, v2269)
            if v2272 == nil then
                break
            end
            v2269 = v2272
            if v2273 then
                for v2280, v2281 in ipairs(v2273:GetDescendants()) do
                    pcall(Pandu_RestoreNameLabel, v2281)
                end
                v2269 = v2272
            end
        end
    end
    Pandu_SetFakeDisplayName = function(a256)
        if not a256 or a256 == "" then
            return
        end
        Pandu_FakeDisplayName = a256
        Pandu_SetCharacterDisplayName(a256)
        Pandu_SweepNames(a256)
        task.delay(0.3, function()
            if Pandu_FakeDisplayName == a256 then
                Pandu_SetCharacterDisplayName(a256)
                Pandu_SweepNames(a256)
            end
        end)
        task.delay(1, function()
            if Pandu_FakeDisplayName == a256 then
                Pandu_SetCharacterDisplayName(a256)
                Pandu_SweepNames(a256)
            end
        end)
        if Pandu_NameCharConn then
            Pandu_NameCharConn:Disconnect()
            Pandu_NameCharConn = nil
        end
        local v2283 = v4.CharacterAdded:Connect(function(a257)
            task.wait(0.5)
            if Pandu_FakeDisplayName then
                local v2282 = a257:WaitForChild("Humanoid", 5)
                if v2282 then
                    v2282.DisplayName = Pandu_FakeDisplayName
                end
            end
        end)
        Pandu_NameCharConn = v2283
    end
    Pandu_ClearFakeDisplayName = function()
        Pandu_FakeDisplayName = nil
        Pandu_SetCharacterDisplayName(Pandu_OriginalDisplayName)
        Pandu_SweepRestoreNames()
        task.delay(0.3, Pandu_SweepRestoreNames)
        if Pandu_NameCharConn then
            Pandu_NameCharConn:Disconnect()
            Pandu_NameCharConn = nil
        end
    end
    Pandu_LoadAssetKeKarakter = function(a258, a259, a260)
        local v2284 = {}
        local v2285 = nil
        local v2286 = nil
        local v2287 = nil
        local v2288 = nil
        local v2289 = {};
        (function(a261)
            for v2294, v2295 in pairs(a261:GetChildren()) do
                if v2295:IsA("CharacterMesh") then
                    table.insert(v2284, v2295)
                elseif v2295:IsA("BodyColors") then
                    v2285 = v2295
                elseif v2295:IsA("Shirt") then
                    v2286 = v2295
                elseif v2295:IsA("Pants") then
                    v2287 = v2295
                elseif v2295:IsA("ShirtGraphic") then
                    v2288 = v2295
                elseif v2295:IsA("Accessory") then
                    table.insert(v2289, v2295)
                elseif v2295:IsA("SpecialMesh") then
                    table.insert(v2284, v2295)
                elseif v2295:IsA("Decal") and v2295.Name == "face" then
                    table.insert(v2284, v2295)
                elseif v2295:IsA("Folder") or v2295:IsA("Model") then
                    (nil)(v2295)
                end
            end
        end)(a258)
        if v2285 then
            local v2296 = a259:FindFirstChildOfClass("BodyColors")
            local v2297 = v2296 or a259:FindFirstChild("Body Colors")
            if v2297 then
                v2297:Destroy()
            end
            v2285:Clone().Parent = a259
        end
        if v2286 then
            local v2298 = a259:FindFirstChildOfClass("Shirt")
            if v2298 then
                v2298:Destroy()
            end
            v2286:Clone().Parent = a259
        end
        if v2287 then
            local v2299 = a259:FindFirstChildOfClass("Pants")
            if v2299 then
                v2299:Destroy()
            end
            v2287:Clone().Parent = a259
        end
        if v2288 then
            local v2300 = a259:FindFirstChildOfClass("ShirtGraphic")
            if v2300 then
                v2300:Destroy()
            end
            v2288:Clone().Parent = a259
        end
        for v2305, v2306 in pairs(v2284) do
            if v2306:IsA("CharacterMesh") then
                pcall(function()
                    v2306:Clone().Parent = a259
                end)
            end
        end
        if a260 then
            for v2311, v2312 in pairs(v2284) do
                if v2312:IsA("SpecialMesh") then
                    pcall(function()
                        local v2313 = a260:FindFirstChildOfClass("SpecialMesh")
                        if v2313 then
                            v2313:Destroy()
                        end
                        v2312:Clone().Parent = a260
                    end)
                elseif v2312:IsA("Decal") and v2312.Name == "face" then
                    pcall(function()
                        local v2314 = a260:FindFirstChild("face")
                        if v2314 then
                            v2314:Destroy()
                        end
                        v2312:Clone().Parent = a260
                    end)
                end
            end
        end
        if #v2289 > 0 then
            task.spawn(function()
                for v2319, v2320 in pairs(v2289) do
                    pcall(function()
                        local v2321 = v2320:Clone()
                        local v2322 = v2321:FindFirstChild("Handle")
                        if v2322 then
                            v2322.CanCollide = false
                            v2322.Massless = true
                            local v2323 = v2322:FindFirstChildOfClass("Attachment")
                            if v2323 then
                                local v2324 = a259:FindFirstChild(v2323.Name, true)
                                if v2324 and v2324.Parent then
                                    local v2325 = Instance.new("Weld")
                                    v2325.Part0 = v2322
                                    v2325.Part1 = v2324.Parent
                                    v2325.C0 = v2323.CFrame
                                    v2325.C1 = v2324.CFrame
                                    v2325.Parent = v2322
                                end
                            end
                            v2321.Parent = a259
                        else
                            v2321.Parent = a259
                        end
                    end)
                end
            end)
        end
    end
    Pandu_ApplyFakeAvaAppearance = function(a262)
        local v2326 = v4.Character
        if not v2326 or not a262 then
            return false
        end
        local v2327 = v2326:FindFirstChildOfClass("Humanoid")
        if not v2327 then
            return false
        end
        local v2328, v2329 = pcall(function()
            return v3:GetCharacterAppearanceAsync(a262)
        end)
        if v2328 and v2329 then
            for v2334, v2335 in pairs(v2326:GetChildren()) do
                if v2335:IsA("Accessory") or v2335:IsA("Shirt") or v2335:IsA("Pants") or v2335:IsA("ShirtGraphic") or v2335:IsA("BodyColors") or v2335:IsA("CharacterMesh") or v2335.Name == "Body Colors" then
                    v2335:Destroy()
                end
            end
            local v2336 = v2326:FindFirstChild("Head")
            if v2336 then
                local v2337 = v2336:FindFirstChildOfClass("SpecialMesh")
                if v2337 then
                    v2337:Destroy()
                end
                local v2338 = v2336:FindFirstChild("face")
                if v2338 then
                    v2338:Destroy()
                end
            end
            local v2339 = nil
            local v2340, v2341 = pcall(function()
                return v3:GetCharacterAppearanceInfoAsync(a262)
            end)
            if v2340 and v2341 then
                v2339 = v2341
            end
            if v2339 and v2339.scales then
                for v2346, v2347 in pairs(v2339.scales) do
                    local v2348 = v2327:FindFirstChild(v2346)
                    local v2349 = v2348
                    if not v2348 then
                        local v2350 = Instance.new("NumberValue")
                        v2349 = v2350
                        v2350.Name = v2346
                        v2350.Parent = v2327
                    end
                    v2349.Value = v2347
                end
            end
            task.wait(0.2)
            Pandu_LoadAssetKeKarakter(v2329, v2326, v2336)
            if v2339 and v2339.assets and v2336 then
                task.spawn(function()
                    for v2355, v2356 in pairs(v2339.assets) do
                        if v2356.assetType and v2356.assetType.name == "Face" then
                            local v2357 = v2336:FindFirstChild("face")
                            if v2357 then
                                v2357:Destroy()
                            end
                            pcall(function()
                                local v2358 = Instance.new("Decal")
                                v2358.Name = "face"
                                v2358.Texture = "rbxassetid://" .. v2356.id
                                v2358.Face = Enum.NormalId.Front
                                v2358.Parent = v2336
                            end)
                            break
                        end
                    end
                end)
            end
            pcall(function()
                v2329:Destroy()
            end)
            return true
        end
        v1:Notify({
            Title = "Error",
            Description = "Gagal load appearance",
            Duration = 3,
        })
        return false
    end
    Pandu_ResolveUser = function(a263)
        local v2359 = tostring(a263):gsub("%s+", ""):gsub("^@", "")
        local v2360 = tonumber(v2359)
        if v2360 then
            local v2361, v2362 = pcall(function()
                return v3:GetNameFromUserIdAsync(v2360)
            end)
            if v2361 and v2362 then
                return v2360, v2362
            end
        else
            local v2363, v2364 = pcall(function()
                return v3:GetUserIdFromNameAsync(v2359)
            end)
            if v2363 and v2364 then
                local v2365, v2366 = pcall(function()
                    return v3:GetNameFromUserIdAsync(v2364)
                end)
                if v2365 and v2366 then
                    return v2364, v2366
                end
            end
        end
        return nil, nil
    end
    Pandu_ApplyAvatar = function(a264)
        if Pandu_Applying then
            return
        end
        Pandu_Applying = true
        task.spawn(function()
            local v2367, v2368 = Pandu_ResolveUser(a264)
            if not v2367 then
                v1:Notify({
                    Title = "Error",
                    Description = "User tidak ditemukan",
                    Duration = 3,
                })
                Pandu_Applying = false
                return
            end
            Pandu_CURRENT_AVATAR = {id = v2367, name = v2368}
            if Pandu_RespawnConnection then
                Pandu_RespawnConnection:Disconnect()
                Pandu_RespawnConnection = nil
            end
            local v2369 = false
            if v4.Character then
                v2369 = Pandu_ApplyFakeAvaAppearance(v2367)
            end
            Pandu_SetFakeDisplayPicture(v2367)
            Pandu_SetFakeDisplayName(v2368)
            local v2370 = v4.CharacterAdded:Connect(function()
                task.wait(1)
                if Pandu_CURRENT_AVATAR then
                    Pandu_ApplyFakeAvaAppearance(Pandu_CURRENT_AVATAR.id)
                    Pandu_SetFakeDisplayPicture(Pandu_CURRENT_AVATAR.id)
                    Pandu_SetFakeDisplayName(Pandu_CURRENT_AVATAR.name)
                end
            end)
            Pandu_RespawnConnection = v2370
            local v2371 = v1.Notify
            local v2372 = {Title = "Copy Avatar"}
            local v2373 = v2369 and "Berhasil copy " .. v2368 or "Gagal apply " .. v2368
            v2372.Description = v2373
            v2372.Duration = 3
            v2371(v1, v2372)
            Pandu_Applying = false
        end)
    end
    Pandu_LoadFavorites = function()
        Pandu_FAVORITES = {}
        pcall(function()
            if not isfolder("PanduCopyAvatar") then
                makefolder("PanduCopyAvatar")
            end
            if isfile("PanduCopyAvatar/favorites.json") then
                local v2374 = v14:JSONDecode(readfile("PanduCopyAvatar/favorites.json"))
                Pandu_FAVORITES = v2374
            end
        end)
    end
    Pandu_SaveFavorites = function()
        pcall(function()
            if not isfolder("PanduCopyAvatar") then
                makefolder("PanduCopyAvatar")
            end
            writefile("PanduCopyAvatar/favorites.json", v14:JSONEncode(Pandu_FAVORITES))
        end)
    end
    Pandu_LoadFavorites()
    Pandu_ResetAvatar = function()
        Pandu_CURRENT_AVATAR = nil
        if Pandu_RespawnConnection then
            Pandu_RespawnConnection:Disconnect()
            Pandu_RespawnConnection = nil
        end
        Pandu_ClearFakeDisplayPicture()
        Pandu_ClearFakeDisplayName()
        task.spawn(function()
            local v2375 = Pandu_ApplyFakeAvaAppearance(Pandu_ORIGINAL_ID)
            local v2376 = v1.Notify
            local v2377 = {Title = "Reset Avatar"}
            local v2378 = v2375 and "Avatar direset" or "Gagal reset"
            v2377.Description = v2378
            v2377.Duration = 3
            v2376(v1, v2377)
        end)
    end
    Pandu_AvatarList = {
        "Self Avatar",
        "Random 1",
        "Random 2",
        "Random 3",
        "Random 4",
        "Random 5",
        "Random 6",
        "Random 7",
        "WoozyNate",
        "Nicholas",
        "yvlyf",
        "traevp",
        "J0LLY",
        "LucashDev",
        "CEOofIsaac",
        "Stealthy",
        "Wildes",
        "Talon",
        "Relukt",
        "Sammy",
        "Diesel",
        "S4ans03",
        "Aura",
        "iJava",
        "White Guy",
        "Purple King",
        "Mpruyyy",
    }
    Pandu_AvatarIDs = {
        ["Self Avatar"] = v4.UserId,
        ["Random 1"] = 2888298851,
        ["Random 2"] = 10074747755,
        ["Random 3"] = 5209567453,
        ["Random 4"] = 8991982843,
        ["Random 5"] = 5796319029,
        ["Random 6"] = 9744452117,
        ["Random 7"] = 8476755006,
        WoozyNate = 146089324,
        Nicholas = 909635,
        yvlyf = 181751703,
        traevp = 471607078,
        J0LLY = 1073847038,
        LucashDev = 2525651744,
        CEOofIsaac = 63238912,
        Stealthy = 56602747,
        Wildes = 40397833,
        Talon = 75974130,
        Relukt = 65042011,
        Sammy = 2678001507,
        Diesel = 9123921576,
        S4ans03 = 35439794,
        Aura = 2275806428,
        iJava = 276557820,
        ["White Guy"] = 8843268357,
        ["Purple King"] = 9070758608,
        Mpruyyy = 8340163775,
    }
    Pandu_GetFavoritesList = function()
        local v2379 = {}
        for v2384, v2385 in ipairs(Pandu_FAVORITES) do
            table.insert(v2379, v2385.name)
        end
        return v2379
    end
    Pandu_SelectedAvatarOption = "Self Avatar"
    FakeAvatarSection:AddDropdown("Pilih Avatar", Pandu_AvatarList, false, function(a265)
        Pandu_SelectedAvatarOption = a265
    end)
    Pandu_UsernameInput = ""
    FakeAvatarSection:AddTextbox("Username / ID", "Masukkan username atau ID...", function(a266)
        local v2386 = a266:gsub("^@", "")
        Pandu_UsernameInput = v2386
    end)
    FakeAvatarSection:AddButton("Apply Avatar", function()
        if Pandu_UsernameInput == "" then
            if Pandu_SelectedAvatarOption and Pandu_SelectedAvatarOption ~= "" then
                local v2387 = Pandu_AvatarIDs[Pandu_SelectedAvatarOption]
                if v2387 then
                    Pandu_ApplyAvatar(v2387)
                else
                    v1:Notify({
                        Title = "Error",
                        Description = "Pilih avatar atau masukkan username!",
                        Duration = 3,
                    })
                end
            else
                v1:Notify({
                    Title = "Error",
                    Description = "Pilih avatar atau masukkan username!",
                    Duration = 3,
                })
            end
        else
            Pandu_ApplyAvatar(Pandu_UsernameInput)
        end
    end)
    FakeAvatarSection:AddButton("Random Avatar", function()
        Pandu_ApplyAvatar(Pandu_RANDOM_IDS[math.random(1, #Pandu_RANDOM_IDS)])
    end)
    FakeAvatarSection:AddButton("Reset Avatar", function()
        Pandu_ResetAvatar()
    end)
    FakeAvatarSection:AddButton("Add to Favorite", function()
        if not Pandu_CURRENT_AVATAR then
            v1:Notify({
                Title = "Error",
                Description = "Tidak ada avatar",
                Duration = 3,
            })
            return
        end
        for v2392, v2393 in ipairs(Pandu_FAVORITES) do
            if tonumber(v2393.id) == tonumber(Pandu_CURRENT_AVATAR.id) then
                v1:Notify({
                    Title = "Info",
                    Description = "Sudah ada di favorite",
                    Duration = 2,
                })
                return
            end
        end
        table.insert(Pandu_FAVORITES, {
            id = Pandu_CURRENT_AVATAR.id,
            name = Pandu_CURRENT_AVATAR.name,
        })
        Pandu_SaveFavorites()
        Pandu_FavDropdown.SetValues(Pandu_GetFavoritesList())
        v1:Notify({
            Title = "Favorite",
            Description = "Ditambahkan ke favorite",
            Duration = 2,
        })
    end)
    local v2400 = FakeAvatarSection:AddDropdown("Favorites", Pandu_GetFavoritesList(), false, function(a267)
        for v2398, v2399 in ipairs(Pandu_FAVORITES) do
            if v2399.name == a267 then
                Pandu_SelectedFav = v2399.id
                Pandu_ApplyAvatar(v2399.id)
                break
            end
        end
    end)
    Pandu_FavDropdown = v2400
    FakeAvatarSection:AddButton("Delete Favorite", function()
        if not Pandu_SelectedFav then
            v1:Notify({
                Title = "Error",
                Description = "Pilih favorite dulu",
                Duration = 3,
            })
            return
        end
        for v2405, v2406 in ipairs(Pandu_FAVORITES) do
            if tonumber(v2406.id) == tonumber(Pandu_SelectedFav) then
                table.remove(Pandu_FAVORITES, v2405)
                break
            end
        end
        Pandu_SaveFavorites()
        Pandu_FavDropdown.SetValues(Pandu_GetFavoritesList())
        Pandu_SelectedFav = nil
        v1:Notify({
            Title = "Favorite",
            Description = "Favorite dihapus",
            Duration = 2,
        })
    end)
    v4.CharacterAdded:Connect(function(a268)
        task.wait(1)
        if Pandu_CURRENT_AVATAR then
            Pandu_ApplyFakeAvaAppearance(Pandu_CURRENT_AVATAR.id)
            Pandu_SetFakeDisplayPicture(Pandu_CURRENT_AVATAR.id)
            Pandu_SetFakeDisplayName(Pandu_CURRENT_AVATAR.name)
        end
    end)
    local v2407 = v2:CreateTab("Survivor", false, false)
    SurvivorTab = v2407
    local v2408 = SurvivorTab:CreatePage("Survivor")
    S_Page = v2408
    local v2409 = S_Page:CreateSection("Generator Settings", "plug-zap")
    GenCard = v2409
    local v2410 = GenCard:AddToggle("Auto Skill Check", false, function(a269)
        _G.Ox.Auto.SkillCheck = a269
        if a269 then
            v625()
        elseif _G.Ox.Connections.SkillHeartbeat then
            _G.Ox.Connections.SkillHeartbeat:Disconnect()
            _G.Ox.Connections.SkillHeartbeat = nil
        end
    end, {Flag = "AutoSkillCheck"})
    SkillCheckToggle = v2410
    SkillCheckToggle:AddKeyPicker("None")
    GenCard:AddDropdown("Skill Check Mode", {"Legit", "Instant", "Normal", "Random"}, false, function(a270)
        _G.Ox.Auto.SkillCheckMode = a270
        _G.Ox.State.RandomMode_IsNormal = false
    end, {Flag = "SkillCheckMode"})
    GenCard:AddDropdown("Gen Boost Mode", {"Manual Repair", "Auto Repair"}, false, function(a271)
        _G.Ox.BypassGenMode = a271
    end, {Flag = "GenBoostMode"})
    local v2413 = GenCard:AddToggle("Gen Boost (Multi-Repair)", false, function(a272)
        _G.Ox.BypassToggleValue = a272
        _G.Ox.BypassGenEnabled = a272
        local v2411 = _G.Ox.BypassButton
        local v2412 = a272 and v6.TouchEnabled
        if v2412 then
            if v6.KeyboardEnabled then
                v2412 = false
            else
                v2412 = true
            end
        end
        v2411.Visible = v2412
        if not a272 then
            _G.Ox.ProcessedGens = {}
            _G.Ox.AutoRepairEnabled = false
            _G.Ox.AutoCurrentGenModel = nil
            if _G.Ox.AutoRepairThread then
                task.cancel(_G.Ox.AutoRepairThread)
                _G.Ox.AutoRepairThread = nil
            end
            _G.Ox.StopAutoRepair()
        end
    end, {Locked = false, LockText = "PREMIUM"})
    GenBoostToggle = v2413
    local v2414 = v9:WaitForChild("Remotes"):WaitForChild("Items")["Twist of Fate"].Fire
    local v2415 = false
    local v2416 = false
    local v2417 = true
    local v2418 = false
    local v2419 = false
    local v2420 = nil
    local v2421 = nil
    local v2422 = "Killer"
    UDim2.new(0.5, -120, 0, 110)
    local v2423 = {}
    local v2424 = {
        PredictionEfficiency = 0.85,
        LerpSmoothness = 0.4,
        EnableJitter = false,
        MaxJitterStuds = 0,
    }
    getGunObject = function()
        local v2425 = v4.Character
        if not v2425 then
            return nil
        end
        local v2426 = v2425:FindFirstChild("Twist of Fate", true)
        if not v2426 then
            return nil
        end
        local v2427 = v2426:FindFirstChild("Right Arm")
        if v2427 then
            local v2428 = v2427:FindFirstChild("gun")
            if v2428 then
                return v2428
            end
            local v2429 = v2427:FindFirstChild("EmperorGun")
            if v2429 then
                return v2429
            end
        end
        return v2426
    end
    isTargetVisible = function(a273, a274, a275)
        local v2430 = a274 - a273
        local v2431 = v2430.Magnitude
        if v2431 < 0.1 then
            return true
        end
        local v2432 = RaycastParams.new()
        v2432.FilterType = Enum.RaycastFilterType.Exclude
        local v2433 = {}
        local v2434 = v4.Character
        if v2434 then
            table.insert(v2433, v2434)
        end
        if a275 and a275 ~= v2434 then
            table.insert(v2433, a275)
        end
        if v2421 then
            table.insert(v2433, v2421)
        end
        v2432.FilterDescendantsInstances = v2433
        local v2435 = workspace:Raycast(a273, v2430.Unit * v2431, v2432) == nil
        return v2435
    end
    local v2436 = {}
    local v2437 = 0
    GetSCPs = function()
        if tick() - v2437 < 0.5 then
            return v2436
        end
        local v2438 = {}
        local v2439 = workspace:FindFirstChild("Map")
        if v2439 then
            for v2444, v2445 in pairs(v2439:GetDescendants()) do
                if v2445:IsA("Model") then
                    local v2446 = v2445:GetAttributes()
                    if v2445:GetAttribute("CorpseCreated0492") or next(v2446) ~= nil then
                        local v2447 = v2445:FindFirstChild("HumanoidRootPart")
                        if v2447 then
                            table.insert(v2438, v2447)
                        end
                    end
                end
            end
        end
        v2436 = v2438
        v2437 = tick()
        return v2436
    end
    local v2455 = function(a276)
        local v2448 = a276:FindFirstChild("HumanoidRootPart")
        if not v2448 then
            return Vector3.zero
        end
        local v2449 = v2448.Position
        local v2450 = v2423[a276]
        if v2450 then
            local v2451 = tick() - v2450.time
            if v2451 > 0.001 and v2451 < 0.1 then
                local v2452 = v2450.vel:Lerp((v2449 - v2450.pos) / v2451, v2424.LerpSmoothness)
                local v2453 = {pos = v2449, vel = v2452, time = tick()}
                v2423[a276] = v2453
                return v2452
            end
        end
        local v2454 = {pos = v2449, vel = v2448.Velocity, time = tick()}
        v2423[a276] = v2454
        return v2448.Velocity
    end
    local v2471 = function(a277, a278, a279, a280)
        local v2456 = a280 or 500
        local v2457 = v2456
        local v2458 = a278.Position
        if (v2458 - a277).Magnitude < 8 then
            return v2458
        end
        local v2459 = v2455(a279)
        local v2460 = v2458 - a277
        local v2461 = v2459:Dot(v2459) - v2457 * v2457
        local v2462 = 2 * v2460:Dot(v2459)
        local v2463 = v2460:Dot(v2460)
        local v2464 = nil
        if math.abs(v2461) < 0.01 then
            if math.abs(v2462) > 0.01 then
                v2464 = -v2463 / v2462
            end
        else
            local v2465 = v2462 * v2462 - 4 * v2461 * v2463
            if v2465 >= 0 then
                local v2466 = math.sqrt(v2465)
                local v2467 = (-v2462 - v2466) / (2 * v2461)
                local v2468 = (-v2462 + v2466) / (2 * v2461)
                if v2467 > 0.001 then
                    v2464 = v2467
                elseif v2468 > 0.001 then
                    v2464 = v2468
                end
            end
        end
        local v2469 = v2458
        if v2464 then
            local v2470 = v2458 + v2459 * v2424.PredictionEfficiency * v2464
            v2469 = v2470
            if v2424.EnableJitter then
                v2469 = v2470 + Vector3.new((math.random() - 0.5) * v2424.MaxJitterStuds, (math.random() - 0.5) * (v2424.MaxJitterStuds / 2), (math.random() - 0.5) * v2424.MaxJitterStuds)
            end
        end
        return v2469
    end
    getTargetPosition = function()
        local v2472 = workspace.CurrentCamera
        local v2473 = getGunObject()
        local v2474 = v4.Character
        if not v2473 or not v2474 then
            return nil, nil, nil, nil
        end
        local v2475 = v2474:FindFirstChild("HumanoidRootPart")
        if not v2475 then
            return nil, nil, nil, nil
        end
        local v2476 = v2475.Position
        local v2477 = nil
        if v2474:GetAttribute("IsCarried") then
            v2477 = v2474.HumanoidRootPart.Position + v2474.HumanoidRootPart.CFrame.LookVector * 2
        else
            pcall(function()
                local v2478 = v2473:IsA("BasePart")
                local v2479 = v2478 and v2473.Position
                if not v2479 then
                    local v2480 = v2473:FindFirstChildOfClass("BasePart")
                    v2479 = v2480 and v2473:FindFirstChildOfClass("BasePart").Position
                end
                v2477 = v2479
            end)
            local v2481 = v2477 or Vector3.new(v2476.X, v2476.Y + 1.5, v2476.Z)
            v2477 = v2481
        end
        local v2487 = function(a281, a282)
            local v2482 = a281.Position
            if v2418 and not isTargetVisible(v2477, v2482, a282) then
                return nil, nil, nil, nil
            end
            local v2483 = getGunObject()
            local v2484 = v2477
            pcall(function()
                if v2483 and v2483:IsA("BasePart") then
                    v2484 = v2483.Position
                elseif v2483 then
                    local v2485 = v2483:FindFirstChildOfClass("BasePart")
                    if v2485 then
                        v2484 = v2485.Position
                    end
                end
            end)
            if (v2482 - v2484).Magnitude < 8 then
                return (v2482 - v2484).Unit, v2483, v2484, v2482
            end
            if not v2416 then
                return (v2482 - v2484).Unit, v2483, v2484, v2482
            end
            local v2486 = v2471(v2484, a281, a282, 500)
            return (v2486 - v2484).Unit, v2483, v2484, v2486
        end
        if v2422 == "Killer" then
            local v2513 = nil
            local v2514 = nil
            local v2515 = math.huge
            for v2520, v2521 in ipairs(v3:GetPlayers()) do
                if v2521 ~= v4 then
                    local v2522 = v2521.Team
                    local v2523 = v2522 and v2521.Team.Name == "Killer"
                    if v2523 and v2521.Character then
                        local v2524 = v2521.Character:FindFirstChild("Torso")
                        if v2524 then
                            local v2525 = (v2476 - v2524.Position).Magnitude
                            if v2525 < v2515 then
                                v2515 = v2525
                                v2513 = v2524
                                v2514 = v2521.Character
                            end
                        end
                    end
                end
            end
            if not v2513 then
                return nil, nil, nil, nil
            end
            return v2487(v2513, v2514)
        end
        if v2422 == "Survivors" then
            local v2500 = nil
            local v2501 = nil
            local v2502 = -math.huge
            local v2503 = workspace.CurrentCamera
            local v2504 = v2503.CFrame.LookVector
            for v2509, v2510 in ipairs(v3:GetPlayers()) do
                if v2510 ~= v4 and v2510.Team and v2510.Team.Name == "Survivors" and v2510.Character then
                    local v2511 = v2510.Character:FindFirstChild("Torso")
                    if v2511 then
                        local v2512 = v2504:Dot((v2511.Position - v2503.CFrame.Position).Unit)
                        if v2512 > 0.5 and v2502 < v2512 then
                            v2502 = v2512
                            v2500 = v2511
                            v2501 = v2510.Character
                        end
                    end
                end
            end
            if not v2500 then
                return nil, nil, nil, nil
            end
            return v2487(v2500, v2501)
        end
        if v2422 ~= "Zombie" then
            return nil, nil, nil, nil
        end
        local v2488 = nil
        local v2489 = GetSCPs()
        local v2490 = -math.huge
        local v2491 = workspace.CurrentCamera
        local v2492 = v2491.CFrame.LookVector
        for v2497, v2498 in ipairs(v2489) do
            if v2498 and v2498.Parent then
                local v2499 = v2492:Dot((v2498.Position - v2491.CFrame.Position).Unit)
                if v2499 > 0.5 and v2490 < v2499 then
                    v2490 = v2499
                    v2488 = v2498
                end
            end
        end
        if not v2488 then
            return nil, nil, nil, nil
        end
        return v2487(v2488, v2488.Parent)
    end
    updateLaser = function(a283, a284)
        if not v2421 then
            v2421 = Instance.new("Part")
            v2421.Name = "ToFLaser"
            v2421.Anchored = true
            v2421.CanCollide = false
            v2421.CanTouch = false
            v2421.CastShadow = false
            v2421.Material = Enum.Material.Neon
            local v2526 = Color3.fromRGB(255, 50, 50)
            v2421.Color = v2526
            v2421.Parent = workspace
        end
        local v2527 = Vector3.new(0.05, 0.05, (a284 - a283).Magnitude)
        v2421.Size = v2527
        local v2528 = CFrame.new((a283 + a284) / 2, a284)
        v2421.CFrame = v2528
        v2421.Transparency = 0
    end
    clearLaser = function()
        if v2421 then
            v2421:Destroy()
            v2421 = nil
        end
    end
    local v2529 = {}
    local v2532 = function()
        local v2530 = v4:GetAttribute("EquippedSkin_Twist_of_Fate")
        local v2531 = v2530 or ""
        if v2531:find("AWP") or v2531:find("Awp") or v2531:find("awp") then
            return "rbxassetid://119691839016468"
        end
        if not v2531:find("SCP") and not v2531:find("3108") then
            return "rbxassetid://124735239320776"
        end
        return "rbxassetid://116394362601423"
    end
    local v2561 = function()
        for v2537, v2538 in ipairs(v2529) do
            v2538:Disconnect()
        end
        v2529 = {}
        local v2539 = v4.Character
        if not v2539 then
            return
        end
        local v2540 = v2539:FindFirstChildOfClass("Humanoid")
        local v2541 = v2540 and v2540:FindFirstChildOfClass("Animator")
        if not v2541 then
            return
        end
        local v2544 = function()
            local v2542 = v2539:GetAttribute("IsCarried")
            local v2543 = v2542 or v2539:GetAttribute("Knocked")
            return v2543
        end
        local v2546 = function()
            local v2545 = {}
            v2545[v2532()] = true
            v2545["rbxassetid://111824163160605"] = true
            v2545["rbxassetid://72749744367268"] = true
            return v2545
        end
        table.insert(v2529, v2541.AnimationPlayed:Connect(function(a285)
            if not v2544() then
                return
            end
            if not a285.Animation then
                return
            end
            if v2546()[a285.Animation.AnimationId] then
                a285:Stop(0)
            end
        end))
        table.insert(v2529, v2539:GetAttributeChangedSignal("IsCarried"):Connect(function()
            if not v2544() then
                return
            end
            local v2547 = v2546()
            for v2552, v2553 in ipairs(v2541:GetPlayingAnimationTracks()) do
                if v2553.Animation and v2547[v2553.Animation.AnimationId] then
                    v2553:Stop(0)
                end
            end
        end))
        table.insert(v2529, v2539:GetAttributeChangedSignal("Knocked"):Connect(function()
            if not v2544() then
                return
            end
            local v2554 = v2546()
            for v2559, v2560 in ipairs(v2541:GetPlayingAnimationTracks()) do
                if v2560.Animation and v2554[v2560.Animation.AnimationId] then
                    v2560:Stop(0)
                end
            end
        end))
    end
    task.defer(v2561)
    v4.CharacterAdded:Connect(function()
        task.defer(function()
            task.wait(0.25)
            v2561()
        end)
    end)
    doShoot = function()
        if not v2415 or not v2419 then
            return
        end
        local v2562 = v4.Character
        if v2562 and _G.Ox.AimConfig.Pistol_BlockKnocked and IsDowned(v2562) then
            return
        end
        local v2563, v2564, v2565, v2566 = getTargetPosition()
        if not v2563 or not v2564 or not v2566 or not v2565 then
            return
        end
        local v2567 = (v2566 - v2565).Unit
        pcall(function()
            v2414:FireServer(v2564, v2567)
        end)
    end
    startConnection = function()
        if v2420 then
            return
        end
        v2420 = v5.Heartbeat:Connect(function()
            if v2419 and v2415 then
                local v2568, v2569, v2570, v2571 = getTargetPosition()
                if v2568 and v2569 and v2571 then
                    pcall(function()
                        local v2572 = v4.Character
                        local v2573 = v2572 and v2572:FindFirstChild("HumanoidRootPart")
                        if v2573 and not v2572:GetAttribute("IsCarried") then
                            v2573.CFrame = CFrame.new(v2573.Position, Vector3.new(v2571.X, v2573.Position.Y, v2571.Z))
                        end
                    end)
                    if _G.Ox.AimConfig.LockAim then
                        local v2574 = CFrame.lookAt(v12.CFrame.Position, v2571)
                        v12.CFrame = v12.CFrame:Lerp(v2574, 0.15)
                    end
                    if v2417 and v2570 and v2571 then
                        updateLaser(v2570, v2571)
                    end
                elseif v2421 then
                    v2421.Transparency = 1
                end
            elseif v2421 then
                v2421.Transparency = 1
            end
        end)
    end
    stopConnection = function()
        if v2420 then
            v2420:Disconnect()
            v2420 = nil
        end
        clearLaser()
    end
    local v2575 = UDim2.new(0.5, -82, 0, 30)
    local v2576 = nil
    local v2577 = nil
    local v2578 = {
        {
            internal = "Killer",
            display = "Killer (K)",
            activeColor = Color3.fromRGB(180, 45, 45),
            activeTxt = Color3.fromRGB(255, 180, 180),
        },
        {
            internal = "Survivors",
            display = "Survivors (J)",
            activeColor = Color3.fromRGB(25, 80, 150),
            activeTxt = Color3.fromRGB(160, 210, 255),
        },
        {
            internal = "Zombie",
            display = "Zombie (L)",
            activeColor = Color3.fromRGB(120, 80, 10),
            activeTxt = Color3.fromRGB(255, 210, 100),
        },
    }
    createTargetSelectorUI = function()
        if not v10 then
            return
        end
        if v2576 and v2576.Parent then
            return
        end
        local v2579 = v10:FindFirstChild("ToFTargetSelector")
        if v2579 then
            v2579:Destroy()
        end
        local v2580 = Instance.new("ScreenGui")
        v2580.Name = "ToFTargetSelector"
        v2580.ResetOnSpawn = false
        v2580.IgnoreGuiInset = true
        v2580.Parent = v10
        local v2581 = Instance.new("Frame")
        v2581.Name = "Main"
        v2581.Size = UDim2.new(0, 165, 0, 32)
        v2581.Position = v2575
        v2581.BackgroundTransparency = 1
        v2581.Active = true
        v2581.Parent = v2580
        local v2582 = false
        local v2583 = Instance.new("TextButton")
        v2583.Size = UDim2.new(1, 0, 1, 0)
        v2583.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        v2583.BackgroundTransparency = 0.25
        v2583.BorderSizePixel = 0
        v2583.Font = Enum.Font.GothamBold
        v2583.TextSize = 11
        v2583.TextColor3 = Color3.fromRGB(240, 240, 240)
        v2583.Parent = v2581
        Instance.new("UICorner", v2583).CornerRadius = UDim.new(0, 8)
        local v2584 = Instance.new("UIStroke", v2583)
        v2584.Color = Color3.fromRGB(100, 100, 110)
        v2584.Thickness = 1.2
        v2584.Transparency = 0.3
        local v2585 = Instance.new("Frame")
        v2585.Size = UDim2.new(1, 0, 0, 0)
        v2585.Position = UDim2.new(0, 0, 1, 5)
        v2585.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        v2585.BackgroundTransparency = 0.25
        v2585.BorderSizePixel = 0
        v2585.ClipsDescendants = true
        v2585.Visible = false
        v2585.AutomaticSize = Enum.AutomaticSize.Y
        v2585.Parent = v2581
        Instance.new("UICorner", v2585).CornerRadius = UDim.new(0, 8)
        local v2586 = Instance.new("UIStroke", v2585)
        v2586.Color = Color3.fromRGB(80, 80, 90)
        v2586.Thickness = 1.2
        v2586.Transparency = 0.4
        local v2587 = Instance.new("UIListLayout", v2585)
        v2587.FillDirection = Enum.FillDirection.Vertical
        v2587.SortOrder = Enum.SortOrder.LayoutOrder
        v2587.Padding = UDim.new(0, 4)
        local v2588 = Instance.new("UIPadding", v2585)
        v2588.PaddingTop = UDim.new(0, 4)
        v2588.PaddingBottom = UDim.new(0, 4)
        v2588.PaddingLeft = UDim.new(0, 4)
        v2588.PaddingRight = UDim.new(0, 4)
        local v2589 = {}
        local v2606 = function()
            local v2590 = "Unknown"
            for v2595, v2596 in ipairs(v2578) do
                if v2596.internal == v2422 then
                    v2590 = v2596.internal
                    break
                end
            end
            local v2597 = v2582
            local v2598 = v2597 and "v" or ">"
            v2583.Text = string.format("Target: %s   %s", v2590, v2598)
            v2585.Visible = v2582
            for v2603, v2604 in ipairs(v2578) do
                local v2605 = v2589[v2604.internal]
                if v2605 then
                    if v2604.internal == v2422 then
                        v2605.BackgroundColor3 = v2604.activeColor
                        v2605.TextColor3 = v2604.activeTxt
                    else
                        v2605.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
                        v2605.TextColor3 = Color3.fromRGB(150, 150, 150)
                    end
                end
            end
        end
        for v2611, v2612 in ipairs(v2578) do
            local v2613 = Instance.new("TextButton")
            v2613.Size = UDim2.new(1, 0, 0, 26)
            v2613.BorderSizePixel = 0
            v2613.Font = Enum.Font.GothamBold
            v2613.TextSize = 10
            v2613.Text = v2612.display
            v2613.LayoutOrder = v2611
            v2613.Parent = v2585
            Instance.new("UICorner", v2613).CornerRadius = UDim.new(0, 6)
            local v2614 = function()
                v2422 = v2612.internal
                v2582 = false
                v2606()
            end
            v2613.MouseButton1Click:Connect(v2614)
            v2613.InputEnded:Connect(function(a286)
                if a286.UserInputType == Enum.UserInputType.Touch then
                    v2614()
                end
            end)
            v2589[v2612.internal] = v2613
        end
        v2606()
        local v2615 = false
        local v2616 = false
        local v2617 = nil
        local v2618 = nil
        local v2619 = nil
        v2583.InputBegan:Connect(function(a287)
            if a287.UserInputType == Enum.UserInputType.MouseButton1 or a287.UserInputType == Enum.UserInputType.Touch then
                v2615 = true
                v2616 = false
                v2617 = a287
                v2618 = a287.Position
                v2619 = v2581.Position
            end
        end)
        v2583.InputEnded:Connect(function(a288)
            if a288 == v2617 then
                v2615 = false
                if not v2616 then
                    local v2620
                    if v2582 then
                        v2620 = false
                    else
                        v2620 = true
                    end
                    v2582 = v2620
                    v2606()
                end
                v2617 = nil
            end
        end)
        v6.InputChanged:Connect(function(a289)
            if not v2615 then
                return
            end
            local v2621 = false
            if a289.UserInputType == Enum.UserInputType.Touch and a289 == v2617 then
                v2621 = true
            elseif a289.UserInputType == Enum.UserInputType.MouseMovement and v2617.UserInputType == Enum.UserInputType.MouseButton1 then
                v2621 = true
            end
            if v2621 then
                local v2622 = a289.Position - v2618
                if math.abs(v2622.X) > 4 or math.abs(v2622.Y) > 4 then
                    v2616 = true
                end
                if v2616 then
                    local v2623 = UDim2.new(v2619.X.Scale, v2619.X.Offset + v2622.X, v2619.Y.Scale, v2619.Y.Offset + v2622.Y)
                    v2581.Position = v2623
                    v2575 = v2623
                end
            end
        end)
        if v2577 then
            v2577:Disconnect()
            v2577 = nil
        end
        v2577 = v6.InputBegan:Connect(function(a290, a291)
            if not v2415 then
                return
            end
            if a291 or a290.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end
            local v2624 = nil
            if a290.KeyCode == Enum.KeyCode.K then
                v2624 = "Killer"
                v1:Notify({Title = "Target Mode", Description = "Killer", Time = 1})
            elseif a290.KeyCode == Enum.KeyCode.J then
                v2624 = "Survivors"
                v1:Notify({Title = "Target Mode", Description = "Survivors", Time = 1})
            elseif a290.KeyCode == Enum.KeyCode.L then
                v2624 = "Zombie"
                v1:Notify({Title = "Target Mode", Description = "Zombie", Time = 1})
            end
            if v2624 and v2624 ~= v2422 then
                v2422 = v2624
                v2606()
            end
        end)
        v2576 = v2580
    end
    destroyTargetSelectorUI = function()
        if v2577 then
            v2577:Disconnect()
            v2577 = nil
        end
        if v2576 then
            v2576:Destroy()
            v2576 = nil
        end
    end
    local v2625 = S_Page:CreateSection("Silent Aim (Pistol)", "crosshair")
    PistolSection = v2625
    local v2626 = PistolSection:AddToggle("Silent Aim Twist Of Fate", false, function(a292)
        v2415 = a292
        if a292 then
            createTargetSelectorUI()
            startConnection()
        else
            destroyTargetSelectorUI()
            stopConnection()
        end
    end, {Locked = false, LockText = "PREMIUM"})
    SilentAimToggle = v2626
    local v2630 = PistolSection:AddToggle("Predict Aim ToF", false, function(a293)
        v2416 = a293
        local v2627 = v1.Notify
        local v2628 = {Title = "Predict Aim"}
        local v2629 = a293 and "Enabled" or "Disabled"
        v2628.Description = v2629
        v2628.Duration = 2
        v2627(v1, v2628)
    end, {Flag = "Pistol_Predict"})
    PredictToggle = v2630
    local v2631 = PistolSection:AddCheckbox("Block aim Knocked", false, function(a294)
        _G.Ox.AimConfig.Pistol_BlockKnocked = a294
    end, {Flag = "Pistol_BlockKnocked"})
    BlockKnockedToggle = v2631
    local v2635 = PistolSection:AddToggle("Block Peluru (TOF)", false, function(a295)
        _G.Ox.BulletBlockConfig.Enabled = a295
        local v2632 = v1.Notify
        local v2633 = {Title = "Block Peluru"}
        local v2634 = a295 and "AKTIF - Peluru tidak keluar" or "NONAKTIF"
        v2633.Description = v2634
        v2633.Duration = 3
        v2632(v1, v2633)
    end, {Flag = "Pistol_BlockPeluru"})
    BulletBlockToggle = v2635
    local v2636 = PistolSection:AddToggle("Lock Aim (Twist Of Fate)", false, function(a296)
        _G.Ox.AimConfig.LockAim = a296
    end, {Flag = "Pistol_LockAim"})
    LockAimToggle = v2636
    local v2637 = PistolSection:AddToggle("Wallcheck", false, function(a297)
        v2418 = a297
    end, {Flag = "Pistol_Wallcheck"})
    WallCheckToggle = v2637
    local v2638 = PistolSection:AddToggle("Enable Laser Effect", true, function(a298)
        v2417 = a298
        if not a298 then
            clearLaser()
        end
    end, {Flag = "Pistol_Laser"})
    LaserToggle = v2638
    v6.InputBegan:Connect(function(a299, a300)
        local v2639 = a299.UserInputType == Enum.UserInputType.Touch
        if a300 and not v2639 then
            return
        end
        if a299.UserInputType == Enum.UserInputType.MouseButton2 then
            v2419 = true
            if _G.Ox.AimConfig.Flash_Silent then
                v379 = true
            end
        elseif a299.UserInputType == Enum.UserInputType.MouseButton1 then
            doShoot()
        end
    end)
    PistolSection:AddToggle("Silent Aim Flashlight", false, function(a301)
        _G.Ox.AimConfig.Flash_Silent = a301
        local v2640 = v1.Notify
        local v2641 = {Title = "Flash Silent Aim"}
        local v2642 = a301 and "AKTIF" or "NONAKTIF"
        v2641.Description = v2642
        v2641.Duration = 2
        v2640(v1, v2641)
    end, {Locked = false, LockText = "PREMIUM"})
    PistolSection:AddSlider("FlashHeadOffset", 0, 15, 1.5, function(a302)
        _G.Ox.AimConfig.Flash_YOffset = a302
    end, {Increment = 0.1, Flag = "Flash_YOffset"})
    v6.InputEnded:Connect(function(a303)
        if a303.UserInputType == Enum.UserInputType.MouseButton2 then
            v2419 = false
            v379 = false
            if v2421 then
                v2421.Transparency = 1
            end
        end
    end)
    local v2643 = nil
    hookMobileButtons = function(a304)
        task.wait(0.5)
        local v2644 = a304:WaitForChild("Controls", 10)
        if not v2644 then
            return
        end
        local v2645 = v2644:WaitForChild("Gui-mob", 5)
        if not v2645 then
            return
        end
        v2645.InputBegan:Connect(function(a305)
            if a305.UserInputType == Enum.UserInputType.Touch or a305.UserInputType == Enum.UserInputType.MouseButton1 then
                v2419 = true
                if _G.Ox.AimConfig.Flash_Silent then
                    v379 = true
                end
            end
        end)
        v2645.InputEnded:Connect(function(a306)
            if a306.UserInputType == Enum.UserInputType.Touch or a306.UserInputType == Enum.UserInputType.MouseButton1 then
                doShoot()
                v2419 = false
                v379 = false
                if v2421 then
                    v2421.Transparency = 1
                end
            end
        end)
    end
    setupMobileButton = function()
        local v2646 = v4:WaitForChild("PlayerGui", 10)
        if not v2646 then
            return
        end
        local v2647 = v2646:FindFirstChild("Survivor-mob")
        if v2647 then
            task.spawn(hookMobileButtons, v2647)
        end
        if v2643 then
            v2643:Disconnect()
            v2643 = nil
        end
        v2643 = v2646.ChildAdded:Connect(function(a307)
            if a307.Name == "Survivor-mob" then
                task.spawn(hookMobileButtons, a307)
            end
        end)
    end
    setupMobileButton()
    v4.CharacterAdded:Connect(function(a308)
        clearLaser()
        v2423 = {}
        v2436 = {}
        v2437 = 0
        v2419 = false
        a308:WaitForChild("HumanoidRootPart", 5)
        setupMobileButton()
        if v2415 then
            stopConnection()
            task.wait(0.2)
            startConnection()
            createTargetSelectorUI()
        end
    end)
    v11.ChildRemoved:Connect(function(a309)
        if not v2415 then
            return
        end
        task.wait(0.5)
        if not v2415 then
            return
        end
        if a309.Name == "ToFTargetSelector" then
            createTargetSelectorUI()
        end
    end)
    local v2648 = S_Page:CreateSection("Anti Hook", "shield")
    AntiHookCard = v2648
    local v2649 = AntiHookCard:AddToggle("Anti Hook", false, function(a310)
        ToggleAntiHook(a310)
    end, {Locked = false, LockText = "PREMIUM"})
    AntiHookToggle = v2649
    AntiHookCard:AddSlider("Offset", 50, 1000, 250, function(a311)
        _G.Ox.AntiHook.OffsetY = -a311
    end, {Increment = 50, Flag = "AntiHookOffsetY"})
    AntiHookCard:AddSlider("Send HZ", 1, 60, 44, function(a312)
        _G.Ox.AntiHook.Hz = a312
        _G.Ox.AntiHook.Interval = 1 / a312
    end, {Increment = 1, Flag = "AntiHookHz"})
    local v2650 = S_Page:CreateSection("Survivor Ability", "zap")
    AbilityCard = v2650
    local v2651 = AbilityCard:AddToggle("Instant TP Gate", false, function(a313)
        v1713(a313)
    end, {Flag = "InstanTPGate"})
    InstantTPToggle = v2651
    InstantTPToggle:AddKeyPicker("None")
    AbilityCard:AddToggle("Auto Crouch (Dodge S1)", false, function(a314)
        _G.Ox.ParryConfig.AutoCrouch = a314
    end, {Flag = "AutoCrouch"})
    local v2652 = AbilityCard:AddToggle("Unlimited Vault", false, function(a315)
        v1814(a315)
    end, {Flag = "UnlimitedVault"})
    UnlimitedVaultToggle = v2652
    UnlimitedVaultToggle:AddKeyPicker("None")
    local v2656 = AbilityCard:AddToggle("Anti Slow Vault", false, function(a316)
        _G.Ox.Config.Surv_PerfectVault = a316
        local v2653 = v1.Notify
        local v2654 = {Title = "Anti Slow Vault"}
        local v2655 = a316 and "AKTIF" or "NONAKTIF"
        v2654.Description = v2655
        v2654.Duration = 2
        v2653(v1, v2654)
    end, {Flag = "AntiSlowVault"})
    AntiSlowVaultToggle = v2656
    AntiSlowVaultToggle:AddKeyPicker("None")
    local v2657 = AbilityCard:AddToggle("Flowstate No CD", false, function(a317)
        v1832(a317)
    end, {Flag = "FlowstateNoCD"})
    FlowstateToggle = v2657
    FlowstateToggle:AddKeyPicker("None")
end
local v2658 = AbilityCard:AddToggle("No Fall Damage", false, function(a318)
    v1836(a318)
end, {Flag = "NoFallDamage"})
NoFallToggle = v2658
NoFallToggle:AddKeyPicker("None")
local v2659 = AbilityCard:AddToggle("Bypass Exit Gate", false, function(a319)
    v1863(a319)
end, {Flag = "BypassExiteGate"})
BypassGateToggle = v2659
local v2660 = AbilityCard:AddToggle("Self Heal", false, function(a320)
    v1876(a320)
end, {Flag = "SelfHeal"})
SelfHealToggle = v2660
SelfHealToggle:AddKeyPicker("None")
local v2664 = AbilityCard:AddToggle("God Mode (Anti Knockdown)", false, function(a321)
    _G.Ox.GodMode = a321
    local v2661 = v1.Notify
    local v2662 = {Title = "God Mode"}
    local v2663 = a321 and "AKTIF - HP tidak akan berkurang" or "NONAKTIF"
    v2662.Description = v2663
    v2662.Duration = 3
    v2661(v1, v2662)
end, {Flag = "GodMode"})
GodModeToggle = v2664
GodModeToggle:AddKeyPicker("GodModeKey", {
    Default = "None",
    Text = "Toggle God Mode",
    Mode = "Toggle",
    Callback = function(a322)
        _G.Ox.GodMode = a322
    end,
})
AbilityCard:AddButton("Apply Korless", function()
    v1882()
    v1:Notify({
        Title = "Korless",
        Description = "Korless Morph Applied!",
        Duration = 3,
    })
end)
AbilityCard:AddButton("Instan Escape", function()
    v1892()
end)
local v2665 = S_Page:CreateSection("Survivor Aimbot", "crosshair")
AimbotCard = v2665
local v2669 = AimbotCard:AddToggle("Enable Aimbot", false, function(a323)
    _G.Ox.Config.Surv_Aimbot_Enabled = a323
    if not a323 then
        if _G.Ox.survivorAimbotHighlight then
            _G.Ox.survivorAimbotHighlight.Parent = nil
        end
        if _G.Ox.SurvivorFOVFrame then
            _G.Ox.SurvivorFOVFrame.Visible = false
        end
    end
    local v2666 = v1.Notify
    local v2667 = {Title = "Survivor Aimbot"}
    local v2668 = a323 and "AKTIF" or "NONAKTIF"
    v2667.Description = v2668
    v2667.Duration = 2
    v2666(v1, v2667)
end, {Flag = "SurvAimbot"})
AimbotToggle = v2669
AimbotToggle:AddKeyPicker("SurvivorAimbotKey", {
    Default = "None",
    Text = "Toggle Aimbot",
    Mode = "Toggle",
    Callback = function(a324)
        _G.Ox.Config.Surv_Aimbot_Enabled = a324
        if not a324 then
            if _G.Ox.survivorAimbotHighlight then
                _G.Ox.survivorAimbotHighlight.Parent = nil
            end
            if _G.Ox.SurvivorFOVFrame then
                _G.Ox.SurvivorFOVFrame.Visible = false
            end
        end
    end,
})
AimbotCard:AddToggle("Show FOV Circle", true, function(a325)
    _G.Ox.Config.Surv_Aimbot_ShowFOV = a325
    if not a325 and _G.Ox.SurvivorFOVFrame then
        _G.Ox.SurvivorFOVFrame.Visible = false
    end
end, {Flag = "SurvAimbotFOV"})
AimbotCard:AddSlider("FOV Radius", 30, 500, 150, function(a326)
    _G.Ox.Config.Surv_Aimbot_Radius = a326
end, {Increment = 1, Flag = "SurvAimbotRadius"})
AimbotCard:AddSlider("Max Distance", 50, 1000, 300, function(a327)
    _G.Ox.Config.Surv_Aimbot_MaxDist = a327
end, {Increment = 10, Flag = "SurvAimbotMaxDist"})
AimbotCard:AddSlider("Smoothness", 0.1, 1, 0.5, function(a328)
    _G.Ox.Config.Surv_Aimbot_Smoothness = a328
end, {Increment = 0.05, Flag = "SurvAimbotSmoot"})
AimbotCard:AddSlider("Predict Offset", 0, 0.1, 0.01, function(a329)
    _G.Ox.Config.Surv_Aimbot_Predict = a329
end, {Increment = 0.001, Flag = "SurvAimbotPredict"})
AimbotCard:AddDropdown("Target Part", {"Torso", "Head", "Root"}, false, function(a330)
    _G.Ox.Config.Surv_Aimbot_TargetPart = a330
end, {Flag = "SurvAimbotTarget"})
local v2670 = S_Page:CreateSection("Auto Parry V1", "sword")
ParryCardV1 = v2670
local v2674 = ParryCardV1:AddToggle("Auto Parry V1", false, function(a331)
    _G.Ox.ParryConfig.AutoParry = a331
    if not a331 then
        _G.Ox.State.ParryCooldown = false
        if _G.Ox.State.ParryCooldownThread then
            task.cancel(_G.Ox.State.ParryCooldownThread)
            _G.Ox.State.ParryCooldownThread = nil
        end
        if ParryHUD and ParryHUD.Reset then
            ParryHUD.Reset()
        end
    end
    local v2671 = v1.Notify
    local v2672 = {Title = "Auto Parry V1"}
    local v2673 = a331 and "AKTIF" or "NONAKTIF"
    v2672.Description = v2673
    v2672.Duration = 2
    v2671(v1, v2672)
end, {Flag = "AutoParryV1"})
AutoParryToggle = v2674
AutoParryToggle:AddKeyPicker("None")
local v2675 = ParryCardV1:AddToggle("Custom GUI (V1)", false, function(a332)
    if a332 then
        if not _G.Ox.AutoParryCustom.Gui then
            CreateCustomParryGUI()
        end
        _G.Ox.AutoParryCustom.Gui.Enabled = true
        _G.Ox.AutoParryCustom.GuiVisible = true
        UpdateCustomParryGUI(_G.Ox.ParryConfig.AutoParry)
        v1:Notify({
            Title = "Auto Parry GUI",
            Description = "Gui Dimuat",
            Duration = 2,
        })
    else
        if _G.Ox.ParryConfig.AutoParry then
            _G.Ox.ParryConfig.AutoParry = false
            _G.Ox.AutoParryCustom.IsActive = false
            v384(AutoParryToggle, false)
        end
        if _G.Ox.AutoParryCustom.Gui then
            _G.Ox.AutoParryCustom.Gui.Enabled = false
            _G.Ox.AutoParryCustom.GuiVisible = false
        end
        v1:Notify({
            Title = "Auto Parry GUI",
            Description = "Gui Disembunyikan",
            Duration = 2,
        })
    end
end, {Flag = "AutoParryGuiV1"})
CustomParryToggle = v2675
ParryCardV1:AddCheckbox("Safety Parry", false, function(a333)
    _G.Ox.ParryConfig.ParrySafety = a333
end, {Flag = "ParrySafetyV1"})
ParryCardV1:AddToggle("Aggressive Mode", false, function(a334)
    _G.Ox.ParryConfig.ParryAggressive = a334
end, {Flag = "ParryAggressiveV1"})
ParryCardV1:AddToggle("Show Range Circle", true, function(a335)
    _G.Ox.ParryConfig.ParryCircle = a335
end, {Flag = "ParryCircleV1"})
ParryCardV1:AddSlider("Parry Radius", 5, 25, 15, function(a336)
    _G.Ox.ParryConfig.ParryRadius = a336
end, {Increment = 1, Flag = "ParryRadiusV1"})
ParryCardV1:AddSlider("Face Sensitivity", -10, 10, 7, function(a337)
    _G.Ox.ParryConfig.ParryFace = a337 / 10
end, {Increment = 1, Flag = "ParryFaceV1"})
local v2676 = S_Page:CreateSection("Auto Parry V2", "sword")
ParryCardV2 = v2676
local v2680 = ParryCardV2:AddToggle("Auto Parry V2", false, function(a338)
    _G.Ox.ParryV2.Enabled = a338
    if not a338 then
        V2_ResetCooldown()
        _G.Ox._V2ParryLastRoot = nil
        _G.Ox._V2ParryLastRadius = -1
        if _G.Ox.ParryV2.RangeAdornment then
            _G.Ox.ParryV2.RangeAdornment.Transparency = 1
        end
    end
    local v2677 = v1.Notify
    local v2678 = {Title = "Auto Parry V2"}
    local v2679 = a338 and "AKTIF" or "NONAKTIF"
    v2678.Description = v2679
    v2678.Duration = 2
    v2677(v1, v2678)
end, {Flag = "AutoParryV2"})
ParryV2Toggle = v2680
ParryV2Toggle:AddKeyPicker("None")
ParryCardV2:AddCheckbox("Safety Parry", false, function(a339)
    _G.Ox.ParryV2.SafetyParry = a339
end, {Flag = "ParrySafetyV2"})
ParryCardV2:AddDropdown("Mode", {"Legit", "Strict", "Aggressive"}, false, function(a340)
    local v2681 = _G.Ox.ParryV2
    local v2682 = a340 or "Legit"
    v2681.Mode = v2682
end, {Flag = "ParryModeV2"})
ParryCardV2:AddDropdown("Trigger", {"Remote", "Button"}, false, function(a341)
    local v2683 = _G.Ox.ParryV2
    local v2684 = a341 or "Remote"
    v2683.Trigger = v2684
end, {Flag = "ParryTriggerV2"})
ParryCardV2:AddSlider("Killer Face", -1, 1, 0.6, function(a342)
    _G.Ox.ParryV2.KillerFace = a342
end, {Increment = 0.1, Flag = "ParryKillerFaceV2"})
ParryCardV2:AddToggle("Show Range Circle", true, function(a343)
    _G.Ox.ParryV2.ShowCircle = a343
    if not a343 and _G.Ox.ParryV2.RangeAdornment then
        _G.Ox.ParryV2.RangeAdornment.Transparency = 1
    end
end, {Flag = "ParryCircleV2"})
ParryCardV2:AddSlider("Parry Radius", 2, 20, 12, function(a344)
    _G.Ox.ParryV2.Range = a344
    _G.Ox._V2ParryLastRadius = -1
    if _G.Ox.ParryV2.RangeAdornment then
        _G.Ox.ParryV2.RangeAdornment.Radius = a344
        _G.Ox.ParryV2.RangeAdornment.InnerRadius = math.max(0.1, a344 - 0.15)
    end
end, {Increment = 0.5, Flag = "ParryRadiusV2"})
local v2685 = S_Page:CreateSection("Auto Drop Pallet", "fence")
PalletCard = v2685
local v2686 = PalletCard:AddToggle("Auto Drop Pallet", false, function(a345)
    ToggleAutoPallet(a345)
end, {Flag = "AutoDropPallet"})
AutoPalletToggle = v2686
AutoPalletToggle:AddKeyPicker("AutoPalletKey", {
    Default = "None",
    Text = "Toggle Auto Drop Pallet",
    Mode = "Toggle",
    Callback = function(a346)
        ToggleAutoPallet(a346)
    end,
})
PalletCard:AddCheckbox("Safety", true, function(a347)
    _G.Ox.AutoPallet.Safety = a347
end, {Flag = "PalletSafety"})
PalletCard:AddSlider("Trigger Distance", 5, 30, 10, function(a348)
    _G.Ox.AutoPallet.Distance = a348
end, {Increment = 1, Flag = "PalletDistance"})
PalletCard:AddButton("Drop All Pallets", function()
    DropAllPallets()
end)
local v2687 = v2:CreateTab("Killer", false, false)
KillerTab = v2687
local v2688 = KillerTab:CreatePage("Killer")
K_Page = v2688
local v2689 = K_Page:CreateSection("Killer Aimbot", "swords")
KillerAimbotCard = v2689
local v2693 = KillerAimbotCard:AddToggle("Enable Aimbot (Melee)", false, function(a349)
    _G.Ox.Config.Killer_Aimbot_Enabled = a349
    if not a349 and _G.Ox.killerAimbotHighlight then
        _G.Ox.killerAimbotHighlight.Parent = nil
    end
    local v2690 = v1.Notify
    local v2691 = {Title = "Killer Aimbot"}
    local v2692 = a349 and "AKTIF" or "NONAKTIF"
    v2691.Description = v2692
    v2691.Duration = 2
    v2690(v1, v2691)
end, {Locked = false, LockText = "PREMIUM"})
KillerAimbotToggle = v2693
KillerAimbotCard:AddSlider("Max Distance", 5, 30, 12, function(a350)
    _G.Ox.Config.Killer_Aimbot_MaxDist = a350
end, {Increment = 1, Flag = "AimbotKillerMaxDist"})
KillerAimbotCard:AddSlider("Smoothness", 0.1, 1, 0.5, function(a351)
    _G.Ox.Config.Killer_Aimbot_Smoothness = a351
end, {Increment = 0.05, Flag = "AimbotKillerSmoothness"})
local v2694 = K_Page:CreateSection("Silent Veil", "arrow-up-right")
VeilCard = v2694
local v2698 = VeilCard:AddToggle("Silent Veil", false, function(a352)
    _G.Ox.AimConfig.Aim_SilentVeilV2 = a352
    local v2695 = v1.Notify
    local v2696 = {Title = "Silent Veil"}
    local v2697 = a352 and "ON" or "OFF"
    v2696.Description = v2697
    v2696.Duration = 2
    v2695(v1, v2696)
end, {Locked = false, LockText = "PREMIUM"})
VeilTog = v2698
VeilCard:AddToggle("Auto Predict", false, function(a353)
    _G.Ox.Config.SpearSmart_enable = a353
end, {Flag = "SpearSmartVeil"})
VeilCard:AddToggle("Show FOV", true, function(a354)
    _G.Ox.AimConfig.Veil_ShowFOV = a354
end, {Flag = "VeilShowFOV"})
VeilCard:AddSlider("Lead", 0.5, 5, 1.4, function(a355)
    _G.Ox.AimConfig.Veil_LeadMultiplier = a355
end, {Increment = 0.1, Flag = "VeilLeadMulti"})
VeilCard:AddSlider("Spear Speed", 50, 200, 165, function(a356)
    _G.Ox.AimConfig.SPEAR_Speed = a356
end, {Increment = 1, Flag = "VeilSpearSpeed"})
VeilCard:AddSlider("Spear Gravity", 10, 200, 103, function(a357)
    _G.Ox.AimConfig.SPEAR_Gravity = a357
end, {Increment = 1, Flag = "VeilSpearGravity"})
VeilCard:AddSlider("Aura Speed", 50, 200, 165, function(a358)
    _G.Ox.AimConfig.SPEAR_AuraSpeed = a358
end, {Increment = 1, Flag = "VeilSpearAuraSpeed"})
VeilCard:AddSlider("Aura Gravity", 10, 200, 96.5, function(a359)
    _G.Ox.AimConfig.SPEAR_AuraGravity = a359
end, {Increment = 1, Flag = "VeilSpearAuraGravity"})
VeilCard:AddSlider("FOV", 50, 500, 150, function(a360)
    _G.Ox.AimConfig.Veil_FOV = a360
end, {Increment = 1, Flag = "VeilFOV"})
VeilCard:AddSlider("Max Dist", 50, 1000, 500, function(a361)
    _G.Ox.AimConfig.SPEAR_MaxDist = a361
end, {Increment = 10, Flag = "SpearMaxDist"})
local v2699 = K_Page:CreateSection("Killer Ability", "zap")
AntiBlindSection = v2699
local v2703 = AntiBlindSection:AddToggle("Anti Blind (Flashlight)", false, function(a362)
    _G.Ox.AntiBlindEnabled = a362
    local v2700 = v1.Notify
    local v2701 = {Title = "Anti Blind"}
    local v2702 = a362 and "AKTIF - Immune dari flashlight" or "NONAKTIF"
    v2701.Description = v2702
    v2701.Duration = 3
    v2700(v1, v2701)
end, {Flag = "AntiBlind"})
AntiBlindToggle = v2703
AntiBlindToggle:AddKeyPicker("AntiBlindKey", {
    Default = "None",
    Text = "Toggle Anti Blind",
    Mode = "Toggle",
    Callback = function(a363)
        _G.Ox.AntiBlindEnabled = a363
    end,
})
local v2704 = AntiBlindSection:AddToggle("Anti Parry", false, function(a364)
    ToggleCounterParry(a364)
end, {Locked = false, LockText = "PREMIUM"})
CounterParryToggle = v2704
local v2705 = AntiBlindSection:AddToggle("Infinite Lunge", false, function(a365)
    if a365 then
        EnableInfiniteLunge()
    else
        DisableInfiniteLunge()
    end
end, {Flag = "InfiniteLunge"})
InfLungeToggle = v2705
InfLungeToggle:AddKeyPicker("InfLungeKey", {
    Default = "None",
    Text = "Toggle Infinite Lunge",
    Mode = "Toggle",
    Callback = function(a366)
        if a366 then
            EnableInfiniteLunge()
        else
            DisableInfiniteLunge()
        end
    end,
})
local v2706 = AntiBlindSection:AddToggle("Auto Stalk", false, function(a367)
    ToggleAutoStalk(a367)
end, {Flag = "AutoStalk"})
AutoStalkToggle = v2706
AutoStalkToggle:AddKeyPicker("AutoStalkKey", {
    Default = "None",
    Text = "Toggle Auto Stalk",
    Mode = "Toggle",
    Callback = function(a368)
        ToggleAutoStalk(a368)
    end,
})
local v2709 = AntiBlindSection:AddToggle("No Slowdown Killer", false, function(a369)
    _G.Ox.NoSlowdownEnabled = a369
    if a369 then
        local v2707 = v4.Character
        if v2707 then
            local v2708 = v2707:FindFirstChildOfClass("Humanoid")
            if v2708 then
                v2708.WalkSpeed = 16
            end
        end
        v1:Notify({
            Title = "No Slowdown Killer",
            Description = "AKTIF - WalkSpeed dikunci 16",
            Duration = 3,
        })
    else
        v1:Notify({
            Title = "No Slowdown Killer",
            Description = "NONAKTIF",
            Duration = 2,
        })
    end
end, {Flag = "NoSlowdown"})
AntiSlowdownToggle = v2709
AntiSlowdownToggle:AddKeyPicker("NoSlowdownKey", {
    Default = "None",
    Text = "Toggle No Slowdown",
    Mode = "Toggle",
    Callback = function(a370)
        _G.Ox.NoSlowdownEnabled = a370
        if a370 then
            local v2710 = v4.Character
            if v2710 then
                local v2711 = v2710:FindFirstChildOfClass("Humanoid")
                if v2711 then
                    v2711.WalkSpeed = 16
                end
            end
        end
    end,
})
local v2712 = AntiBlindSection:AddToggle("Skill Hidden No CD", false, function(a371)
    _G.Ox.BypassLeapEnabled = a371
    if a371 then
        v996()
        v1:Notify({
            Title = "Skill Hidden No CD",
            Description = "AKTIF - Cooldown skill Hidden dihilangkan",
            Duration = 3,
        })
    else
        if v969.LeapBypass then
            task.cancel(v969.LeapBypass)
            v969.LeapBypass = nil
        end
        v1:Notify({
            Title = "Skill Hidden No CD",
            Description = "NONAKTIF",
            Duration = 2,
        })
    end
end, {Flag = "BypassSkilHidden"})
BypassLeapToggle = v2712
BypassLeapToggle:AddKeyPicker("BypassLeapKey", {
    Default = "None",
    Text = "Toggle Hidden No CD",
    Mode = "Toggle",
    Callback = function(a372)
        _G.Ox.BypassLeapEnabled = a372
        if a372 then
            v996()
        elseif v969.LeapBypass then
            task.cancel(v969.LeapBypass)
            v969.LeapBypass = nil
        end
    end,
})
local v2716 = AntiBlindSection:AddToggle("Infinite Corrupt (Abyssal)", false, function(a373)
    _G.Ox.InfAbyssalEnabled = a373
    if not a373 then
        v1003()
    end
    local v2713 = v1.Notify
    local v2714 = {Title = "Infinite Corrupt"}
    local v2715 = a373 and "AKTIF - Tekan Q (PC) atau tombol skill (Mobile)" or "NONAKTIF"
    v2714.Description = v2715
    v2714.Duration = 3
    v2713(v1, v2714)
end, {Flag = "InfinityCorrupt"})
InfAbyssalToggle = v2716
InfAbyssalToggle:AddKeyPicker("InfAbyssalKey", {
    Default = "None",
    Text = "Toggle Infinite Corrupt",
    Mode = "Toggle",
    Callback = function(a374)
        _G.Ox.InfAbyssalEnabled = a374
        if not a374 then
            v1003()
        end
    end,
})
local v2717 = AntiBlindSection:AddToggle("Dash Lock (Hidden)", false, function(a375)
    v777(a375)
end, {Flag = "DashLockHidden"})
DashLockToggle = v2717
DashLockToggle:AddKeyPicker("DashKey", {
    Default = "V",
    Text = "Toggle Dash Lock",
    Mode = "Toggle",
    Callback = function(a376)
        v777(a376)
    end,
})
local v2718 = AntiBlindSection:AddToggle("Mask Selection GUI", false, function(a377)
    v791(a377)
end, {Flag = "MaskSelectGui"})
MaskToggle = v2718
MaskToggle:AddKeyPicker("None")
AntiBlindSection:AddButton("Aim Lock Toggle", function()
    if pcall(function()
        loadstring(game:HttpGet("https://pastefy.app/5zsm8N7G/raw"))()
    end) then
        v1:Notify({
            Title = "Aim Lock",
            Description = "Aim Lock berhasil dimuat!",
            Duration = 3,
        })
    else
        v1:Notify({
            Title = "Error",
            Description = "Gagal memuat Aim Lock!",
            Duration = 3,
        })
    end
end)
local v2719 = K_Page:CreateSection("Silent Aim Flask (Cure)", "flask-conical")
FlaskCard = v2719
local v2723 = FlaskCard:AddToggle("Silent Aim Flask", false, function(a378)
    _G.Ox.KILLER_SilentAimFlask = a378
    local v2720 = v1.Notify
    local v2721 = {Title = "Silent Aim Flask"}
    local v2722 = a378 and "AKTIF" or "NONAKTIF"
    v2721.Description = v2722
    v2721.Duration = 2
    v2720(v1, v2721)
end, {Locked = false, LockText = "PREMIUM"})
FlaskToggle = v2723
local v2724 = FlaskCard:AddToggle("Flask Laser", false, function(a379)
    _G.Ox.KILLER_FlaskLaser = a379
    if a379 then
        pcall(NEX_StartCureFlaskLaser)
        v1:Notify({
            Title = "Flask Laser",
            Description = "AKTIF - Laser merah muncul",
            Duration = 2,
        })
    else
        if _G.Ox.NEX_CureFlaskLaserThread then
            _G.Ox.NEX_CureFlaskLaserThread:Disconnect()
            _G.Ox.NEX_CureFlaskLaserThread = nil
        end
        if _G.Ox.NEX_CureFlaskLaserPart then
            pcall(function()
                _G.Ox.NEX_CureFlaskLaserPart:Destroy()
            end)
            _G.Ox.NEX_CureFlaskLaserPart = nil
        end
        v1:Notify({
            Title = "Flask Laser",
            Description = "NONAKTIF",
            Duration = 2,
        })
    end
end, {Flag = "LaserFlask"})
FlaskLaserToggle = v2724
FlaskLaserToggle:AddKeyPicker("FlaskLaserKey", {
    Default = "None",
    Text = "Toggle Flask Laser",
    Mode = "Toggle",
    Callback = function(a380)
        _G.Ox.KILLER_FlaskLaser = a380
        if a380 then
            pcall(NEX_StartCureFlaskLaser)
        else
            if _G.Ox.NEX_CureFlaskLaserThread then
                _G.Ox.NEX_CureFlaskLaserThread:Disconnect()
                _G.Ox.NEX_CureFlaskLaserThread = nil
            end
            if _G.Ox.NEX_CureFlaskLaserPart then
                pcall(function()
                    _G.Ox.NEX_CureFlaskLaserPart:Destroy()
                end)
                _G.Ox.NEX_CureFlaskLaserPart = nil
            end
        end
    end,
})
local v2725 = K_Page:CreateSection("Anti Looping", "repeat")
AntiLoopingSection = v2725
local v2760 = AntiLoopingSection:AddToggle("Block Vault & Pallets", false, function(a381)
    _G.Ox.BlockPalletEnabled = a381
    if not a381 then
        local v2751 = game:GetService("ReplicatedStorage").Remotes.Window.VaultCompleteEvent
        local v2752 = game:GetService("ReplicatedStorage").Remotes.Pallet.PalletSlideCompleteEvent
        local v2753 = workspace:FindFirstChild("Map")
        if v2753 then
            for v2758, v2759 in pairs(v2753:GetDescendants()) do
                if v2759.Name == "VaultPointInUse" then
                    pcall(function()
                        v2751:FireServer(v2759.Parent, false)
                    end)
                elseif v2759.Name == "PalletPointSlideInUse" then
                    pcall(function()
                        v2752:FireServer(v2759.Parent, false)
                    end)
                end
            end
        end
        return
    end
    local v2726 = game:GetService("ReplicatedStorage").Remotes.Window.VaultEvent
    local v2727 = game:GetService("ReplicatedStorage").Remotes.Pallet.PalletSlideEvent
    local v2728 = workspace:FindFirstChild("Map")
    if v2728 then
        for v2733, v2734 in pairs(v2728:GetDescendants()) do
            if v2734.Name == "VaultTrigger" then
                pcall(function()
                    v2726:FireServer(v2734, true)
                end)
            end
            if v2734.Name == "PalletPointSlide" and v2734:IsA("BasePart") then
                pcall(function()
                    v2727:FireServer(v2734, true)
                end)
            end
        end
    end
    task.spawn(function()
        local v2735 = workspace:FindFirstChild("Map")
        if not v2735 then
            return
        end
        local v2736 = {}
        watchPallet = function(a382)
            if a382:IsA("BasePart") and a382.Name == "PalletPoint" then
                local v2737 = a382:GetPropertyChangedSignal("Name"):Connect(function()
                    if not _G.Ox.BlockPalletEnabled then
                        return
                    end
                    if a382.Name == "PalletPointSlide" then
                        task.wait(0.1)
                        pcall(function()
                            v2727:FireServer(a382, true)
                        end)
                    end
                end)
                table.insert(v2736, v2737)
            end
        end
        for v2742, v2743 in pairs(v2735:GetDescendants()) do
            watchPallet(v2743)
        end
        local v2744 = v2735.DescendantAdded:Connect(function(a383)
            watchPallet(a383)
        end)
        table.insert(v2736, v2744)
        while _G.Ox.BlockPalletEnabled do
            task.wait(0.5)
        end
        for v2749, v2750 in pairs(v2736) do
            v2750:Disconnect()
        end
        v2736 = {}
    end)
    v1:Notify({
        Title = "Anti Looping",
        Description = "✅ Aktif!",
        Duration = 2,
    })
end, {Locked = false, LockText = "PREMIUM"})
AntiLoopingToggle = v2760
local v2761 = v2:CreateTab("Visual", false, false)
EspTab = v2761
local v2762 = EspTab:CreatePage("ESP")
EspPage = v2762
local v2763 = EspPage:CreateSection("ESP Settings", "eye")
EspMasterCard = v2763
local v2764 = EspMasterCard:AddToggle("Enable ESP", false, function(a384)
    _G.Ox.ESPConfig.Master = a384
    if a384 then
        ForceRefreshMap()
        v1:Notify({Title = "ESP", Description = "AKTIF", Duration = 2})
    else
        ClearAllESP()
        v1:Notify({Title = "ESP", Description = "NONAKTIF", Duration = 2})
    end
end, {Flag = "EnableEspMaster"})
EspMasterToggle = v2764
EspMasterToggle:AddKeyPicker("EspKey", {Default = "None", Text = "ESP Key", Mode = "Toggle"})
EspMasterCard:AddSlider("ESP Max Distance", 100, 5000, 1000, function(a385)
    _G.Ox.ESPConfig.MaxDistance = a385
end, {Increment = 100, Flag = "EspMaxDistance"})
local v2765 = EspMasterCard:AddCheckbox("Player ESP", false, function(a386)
    _G.Ox.ESPConfig.Player = a386
    if _G.Ox.ESPConfig.Master then
        if a386 then
            ScanMapESP()
        else
            ClearESP("Player")
        end
    end
end, {Flag = "PlayerEsp"})
PlayerToggle = v2765
PlayerToggle:AddColorPicker(_G.Ox.ESPColors.Player, {
    Flag = "EspPlayer_Color",
    Title = "Warna Player ESP",
    Callback = function(a387)
        _G.Ox.ESPColors.Player = a387
        if _G.Ox.ESPConfig.Master then
            UpdatePlayerESP()
        end
    end,
})
local v2766 = EspMasterCard:AddCheckbox("Killer ESP", false, function(a388)
    _G.Ox.ESPConfig.Killer = a388
    if _G.Ox.ESPConfig.Master then
        if a388 then
            ScanMapESP()
        else
            ClearESP("Killer")
        end
    end
end, {Flag = "KillerEsp"})
KillerToggle = v2766
KillerToggle:AddColorPicker(_G.Ox.ESPColors.Killer, {
    Flag = "EspKiller_Color",
    Title = "Warna Killer ESP",
    Callback = function(a389)
        _G.Ox.ESPColors.Killer = a389
        if _G.Ox.ESPConfig.Master then
            UpdatePlayerESP()
        end
    end,
})
local v2767 = EspMasterCard:AddCheckbox("ESP Name", false, function(a390)
    _G.Ox.ESPConfig.Name = a390
    if _G.Ox.ESPConfig.Master then
        ScanMapESP()
    else
        ClearAllESP()
    end
end, {Flag = "EspName"})
NameToggle = v2767
local v2768 = EspMasterCard:AddCheckbox("ESP Distance", false, function(a391)
    _G.Ox.ESPConfig.Distance = a391
    if _G.Ox.ESPConfig.Master then
        UpdatePlayerESP()
    end
end, {Flag = "EspDistancw"})
DistToggle = v2768
local v2769 = EspMasterCard:AddCheckbox("ESP Status survivors", false, function(a392)
    _G.Ox.ESPConfig.Status = a392
    if _G.Ox.ESPConfig.Master then
        UpdatePlayerESP()
    end
end, {Flag = "EspStatus"})
StatusToggle = v2769
local v2770 = EspMasterCard:AddCheckbox("ESP Item Icon", false, function(a393)
    _G.Ox.ESPConfig.ItemIcon = a393
    if _G.Ox.ESPConfig.Master then
        UpdatePlayerESP()
    end
end, {Flag = "EspItemIcon"})
IconToggle = v2770
local v2773 = EspMasterCard:AddCheckbox("ESP Killer Warn", false, function(a394)
    _G.Ox.ESPConfig.KillerWarn = a394
    if not a394 then
        local v2771 = v4.Character
        local v2772 = v2771 and v4.Character:FindFirstChild("HumanoidRootPart")
        if v2772 and v2772:FindFirstChild("KillerWarn") then
            v2772.KillerWarn:Destroy()
        end
    end
end, {Flag = "KillerWarn"})
WarnToggle = v2773
local v2774 = EspMasterCard:AddCheckbox("ESP Outline Mode", false, function(a395)
    _G.Ox.ESPConfig.Outline = a395
end, {Flag = "EspOutlineMode"})
OutlineToggle = v2774
local v2775 = EspMasterCard:AddCheckbox("ESP Hook Count", false, function(a396)
    _G.Ox.ESPConfig.HookCount = a396
    if a396 then
        UpdateHookData()
        UpdatePlayerESP()
        UpdateHookUICounter()
        v1:Notify({Title = "Hook ESP", Description = "AKTIF", Duration = 2})
    else
        ClearHookESP()
        ClearHookUICounter()
        UpdatePlayerESP()
        v1:Notify({Title = "Hook ESP", Description = "NONAKTIF", Duration = 2})
    end
end, {Flag = "EspHookCount"})
HookCountToggle = v2775
local v2776 = EspPage:CreateSection("World Effects", "flashlight")
PerfCard = v2776
local v2778 = PerfCard:AddToggle("Full Bright", false, function(a397)
    _G.Ox.FullBright = a397
    local v2777 = game:GetService("Lighting")
    if not v2777 then
        return
    end
    if a397 then
        StartLightingGuard()
        ReapplyPerformanceDelayed()
        v1:Notify({Title = "Full Bright", Description = "AKTIF", Duration = 2})
    else
        v2777.Brightness = 1
        v2777.ClockTime = 14
        v2777.FogEnd = 1000
        v2777.Ambient = Color3.fromRGB(128, 128, 128)
        v2777.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        StopLightingGuard()
        v1:Notify({
            Title = "Full Bright",
            Description = "NONAKTIF",
            Duration = 2,
        })
    end
end, {Flag = "FullBright"})
FullBrightToggle = v2778
PerfCard:AddSlider("Time Of Day", 0, 24, 14, function(a398)
    _G.Ox.TimeOfDayValue = a398
    if _G.Ox.FullBright then
        local v2779 = game:GetService("Lighting")
        if v2779 then
            v2779.ClockTime = a398
        end
    end
end, {Increment = 1, Flag = "TimeOfDay"})
local v2782 = PerfCard:AddToggle("No Fog", false, function(a399)
    _G.Ox.NoFog = a399
    if a399 then
        StartLightingGuard()
        ApplyNoFog()
        v1:Notify({
            Title = "No Fog",
            Description = "AKTIF - Kabut hilang",
            Duration = 3,
        })
    else
        local v2780 = game:GetService("Lighting")
        if v2780 then
            v2780.FogStart = 0
            v2780.FogEnd = 1000
            local v2781 = v2780:FindFirstChildOfClass("Atmosphere")
            if v2781 then
                v2781.Density = 0.35
            end
        end
        StopLightingGuard()
        v1:Notify({Title = "No Fog", Description = "NONAKTIF", Duration = 2})
    end
end, {Flag = "NoFog"})
NoFogToggle = v2782
local v2783 = PerfCard:AddToggle("No Shadow", false, function(a400)
    _G.Ox.NoShadow = a400
    if a400 then
        StartLightingGuard()
        ApplyNoShadow()
        v1:Notify({
            Title = "No Shadow",
            Description = "AKTIF - Shadow hilang",
            Duration = 2,
        })
    else
        ApplyNoShadow()
        StopLightingGuard()
        v1:Notify({
            Title = "No Shadow",
            Description = "NONAKTIF",
            Duration = 2,
        })
    end
end, {Flag = "NoShadow"})
NoShadowToggle = v2783
local v2784 = PerfCard:AddToggle("Remove Texture (Low GFX)", false, function(a401)
    ToggleLowGFX(a401)
end, {Flag = "RemoveTexture"})
LowGFXToggle = v2784
LowGFXToggle:AddKeyPicker("None")
local v2785 = EspPage:CreateSection("Map ESP", "map")
MapCard = v2785
local v2786 = MapCard:AddCheckbox("Generator ESP", false, function(a402)
    _G.Ox.ESPConfig.Generator = a402
    if _G.Ox.ESPConfig.Master then
        if a402 then
            ScanMapESP()
        else
            ClearESP("Generator")
        end
    end
end, {Flag = "GeneratorEsp"})
GenToggle = v2786
GenToggle:AddColorPicker(_G.Ox.ESPColors.Generator, {
    Flag = "Generator_Color",
    Title = "Warna Generator",
    Callback = function(a403)
        _G.Ox.ESPColors.Generator = a403
        if _G.Ox.ESPConfig.Master then
            UpdateStaticESP()
        end
    end,
})
local v2787 = MapCard:AddCheckbox("Generator Name & Progress", true, function(a404)
    _G.Ox.ESPConfig.GeneratorName = a404
    if _G.Ox.ESPConfig.Master then
        ScanMapESP()
    end
end, {Flag = "GeneratorName"})
GenNameToggle = v2787
MapCard:AddColorPicker("Gen Done Color", _G.Ox.ESPColors.GeneratorDone, {
    Flag = "GeneratorDone_Color",
    Title = "Warna Generator Selesai",
    Callback = function(a405)
        _G.Ox.ESPColors.GeneratorDone = a405
        if _G.Ox.ESPConfig.Master then
            UpdateStaticESP()
        end
    end,
})
local v2788 = MapCard:AddCheckbox("Pallet ESP", false, function(a406)
    _G.Ox.ESPConfig.Pallet = a406
    if _G.Ox.ESPConfig.Master then
        if a406 then
            ScanMapESP()
        else
            ClearESP("Pallet")
        end
    end
end, {Flag = "EspPallet"})
PalletToggle = v2788
PalletToggle:AddColorPicker(_G.Ox.ESPColors.Pallet, {
    Flag = "Pallet_Color",
    Title = "Warna Pallet",
    Callback = function(a407)
        _G.Ox.ESPColors.Pallet = a407
        if _G.Ox.ESPConfig.Master then
            UpdateStaticESP()
        end
    end,
})
local v2789 = MapCard:AddCheckbox("Window ESP", false, function(a408)
    _G.Ox.ESPConfig.Window = a408
    if _G.Ox.ESPConfig.Master then
        if a408 then
            ScanMapESP()
        else
            ClearESP("Window")
        end
    end
end, {Flag = "EspWindow"})
WindowToggle = v2789
WindowToggle:AddColorPicker(_G.Ox.ESPColors.Window, {
    Flag = "Window_Color",
    Title = "Warna Window",
    Callback = function(a409)
        _G.Ox.ESPColors.Window = a409
        if _G.Ox.ESPConfig.Master then
            UpdateStaticESP()
        end
    end,
})
local v2790 = MapCard:AddCheckbox("Hook ESP", false, function(a410)
    _G.Ox.ESPConfig.Hook = a410
    if _G.Ox.ESPConfig.Master then
        if a410 then
            ScanMapESP()
        else
            ClearESP("Hook")
        end
    end
end, {Flag = "HookEsp"})
HookToggle = v2790
HookToggle:AddColorPicker(_G.Ox.ESPColors.Hook, {
    Flag = "Hook_Color",
    Title = "Warna Hook",
    Callback = function(a411)
        _G.Ox.ESPColors.Hook = a411
        if _G.Ox.ESPConfig.Master then
            UpdateStaticESP()
        end
    end,
})
local v2791 = MapCard:AddCheckbox("Gate ESP", false, function(a412)
    _G.Ox.ESPConfig.Gate = a412
    if _G.Ox.ESPConfig.Master then
        if a412 then
            ScanMapESP()
        else
            ClearESP("Gate")
        end
    end
end, {Flag = "GateEsp"})
GateToggle = v2791
GateToggle:AddColorPicker(_G.Ox.ESPColors.Gate, {
    Flag = "Gate_Color",
    Title = "Warna Gate",
    Callback = function(a413)
        _G.Ox.ESPColors.Gate = a413
        if _G.Ox.ESPConfig.Master then
            UpdateStaticESP()
        end
    end,
})
local v2792 = MapCard:AddCheckbox("SCP ESP", false, function(a414)
    _G.Ox.ESPConfig.SCP = a414
    if _G.Ox.ESPConfig.Master then
        if a414 then
            ScanMapESP()
        else
            ClearESP("SCP")
        end
    end
end, {Flag = "EspScp"})
SCPToggle = v2792
SCPToggle:AddColorPicker(_G.Ox.ESPColors.SCP, {
    Flag = "ScpEsp_Color",
    Title = "Warna SCP",
    Callback = function(a415)
        _G.Ox.ESPColors.SCP = a415
        if _G.Ox.ESPConfig.Master then
            UpdateSCPESP()
        end
    end,
})
MapCard:AddButton("Refresh Map", function()
    ForceRefreshMap()
    v1:Notify({Title = "Map", Description = "Refreshed!", Duration = 2})
end)
local v2793 = EspPage:CreateSection("Information", "info")
NextKillerCard = v2793
local v2794 = NextKillerCard:AddToggle("Next Killer Display", false, function(a416)
    v1910(a416)
end, {Flag = "NextKillerDisplay"})
NextKillerToggle = v2794
local v2795 = NextKillerCard:AddToggle("Next Map Prediction", false, function(a417)
    v1931(a417)
end, {Flag = "NextMapPredict"})
MapPredictToggle = v2795
local v2796 = NextKillerCard:AddToggle("Killer Perks Display", false, function(a418)
    v2013(a418)
end, {Flag = "KillerPerkDisplay"})
KillerPerksToggle = v2796
local v2797 = NextKillerCard:AddToggle("Killer Stun Indicator", false, function(a419)
    v2067(a419)
end, {Flag = "KillerStunIndicator"})
StunToggle = v2797
local v2798 = NextKillerCard:AddToggle("Spectator info", false, function(a420)
    v539(a420)
end, {Flag = "SpectatorInfo"})
SpectatorToggle = v2798
local v2799 = v2:CreateTab("Teleport", false, false)
TeleportTab = v2799
local v2800 = TeleportTab:CreatePage("Teleport")
T_Page = v2800
local v2801 = T_Page:CreateSection("Teleport Map", "map")
TeleportMapCard = v2801
TeleportMapCard:AddButton("Refresh Map Cache", function()
    v482()
    _G.Ox.Teleport.GenIndex = 1
    _G.Ox.Teleport.HookIndex = 1
    _G.Ox.Teleport.GateIndex = 1
    _G.Ox.Teleport.PalletIndex = 1
    _G.Ox.Teleport.WindowIndex = 1
    v1:Notify({
        Title = "Refresh",
        Description = "Cache map di-refresh!",
        Duration = 2,
    })
end)
TeleportMapCard:AddButton("Teleport ke Generator", function()
    if #v374.Generators == 0 then
        v482()
    end
    if #v374.Generators < _G.Ox.Teleport.GenIndex then
        _G.Ox.Teleport.GenIndex = 1
    end
    local v2802 = v374.Generators[_G.Ox.Teleport.GenIndex]
    if v2802 and v2802.part then
        v487(v2802.part)
        v1:Notify({
            Title = "TP Generator",
            Description = "Generator " .. _G.Ox.Teleport.GenIndex,
            Duration = 1.2,
        })
    else
        v1:Notify({
            Title = "TP Generator",
            Description = "Generator tidak ditemukan!",
            Duration = 2,
        })
    end
    _G.Ox.Teleport.GenIndex = _G.Ox.Teleport.GenIndex + 1
end)
TeleportMapCard:AddButton("Teleport ke Hook", function()
    if #v374.Hooks == 0 then
        v482()
    end
    if #v374.Hooks < _G.Ox.Teleport.HookIndex then
        _G.Ox.Teleport.HookIndex = 1
    end
    local v2803 = v374.Hooks[_G.Ox.Teleport.HookIndex]
    local v2804 = v2803
    if v2803 then
        local v2805 = v2803:FindFirstChild("HookPoint")
        v2804 = v2805 or v2803:FindFirstChildWhichIsA("BasePart")
    end
    if v2804 then
        v487(v2804)
        v1:Notify({
            Title = "TP Hook",
            Description = "Hook " .. _G.Ox.Teleport.HookIndex,
            Duration = 1.2,
        })
    end
    _G.Ox.Teleport.HookIndex = _G.Ox.Teleport.HookIndex + 1
end)
TeleportMapCard:AddButton("Teleport ke Gate", function()
    if #v374.Gates == 0 then
        v482()
    end
    if #v374.Gates < _G.Ox.Teleport.GateIndex then
        _G.Ox.Teleport.GateIndex = 1
    end
    local v2806 = v374.Gates[_G.Ox.Teleport.GateIndex]
    local v2807 = v2806 and v2806:FindFirstChildWhichIsA("BasePart")
    if v2807 then
        v487(v2807)
        v1:Notify({
            Title = "TP Gate",
            Description = "Gate " .. _G.Ox.Teleport.GateIndex,
            Duration = 1.2,
        })
    end
    _G.Ox.Teleport.GateIndex = _G.Ox.Teleport.GateIndex + 1
end)
TeleportMapCard:AddButton("Teleport ke Pallet", function()
    if #v374.Pallets == 0 then
        v482()
    end
    if #v374.Pallets < _G.Ox.Teleport.PalletIndex then
        _G.Ox.Teleport.PalletIndex = 1
    end
    local v2808 = v374.Pallets[_G.Ox.Teleport.PalletIndex]
    local v2809 = v2808
    if v2808 then
        local v2810 = v2808:FindFirstChild("PrimaryPartPallet")
        v2809 = v2810 or v2808:FindFirstChildWhichIsA("BasePart")
    end
    if v2809 then
        v487(v2809)
        v1:Notify({
            Title = "TP Pallet",
            Description = "Pallet " .. _G.Ox.Teleport.PalletIndex,
            Duration = 1.2,
        })
    end
    _G.Ox.Teleport.PalletIndex = _G.Ox.Teleport.PalletIndex + 1
end)
TeleportMapCard:AddButton("Teleport ke Window", function()
    if #v374.Windows == 0 then
        v482()
    end
    if #v374.Windows < _G.Ox.Teleport.WindowIndex then
        _G.Ox.Teleport.WindowIndex = 1
    end
    local v2811 = v374.Windows[_G.Ox.Teleport.WindowIndex]
    local v2812 = v2811
    if v2811 then
        local v2813 = v2811:FindFirstChild("Bottom")
        v2812 = v2813 or v2811:FindFirstChildWhichIsA("BasePart")
    end
    if v2812 then
        v487(v2812)
        v1:Notify({
            Title = "TP Window",
            Description = "Window " .. _G.Ox.Teleport.WindowIndex,
            Duration = 1.2,
        })
    end
    _G.Ox.Teleport.WindowIndex = _G.Ox.Teleport.WindowIndex + 1
end)
local v2814 = T_Page:CreateSection("Teleport Player", "users")
PlayerCard = v2814
local v2815 = nil
local v2816 = {}
local v2823 = function()
    v2816 = {}
    for v2821, v2822 in pairs(v3:GetPlayers()) do
        if v2822 ~= v4 and v2822.Character then
            table.insert(v2816, v2822.Name)
        end
    end
    table.sort(v2816)
end
v2823()
local v2824 = PlayerCard:AddDropdown("Pilih Player", v2816, false, function(a421)
    v2815 = a421
end)
PlayerDropdown = v2824
PlayerCard:AddButton("Refresh Player List", function()
    v2823()
    pcall(function()
        if PlayerDropdown.Refresh then
            PlayerDropdown:Refresh(v2816)
        elseif PlayerDropdown.SetValues then
            PlayerDropdown:SetValues(v2816)
        elseif PlayerDropdown.SetOptions then
            PlayerDropdown:SetOptions(v2816)
        elseif PlayerDropdown.Update then
            PlayerDropdown:Update(v2816)
        end
    end)
    v1:Notify({
        Title = "Refresh",
        Description = "List player di-refresh! (" .. #v2816 .. " player)",
        Duration = 2,
    })
end)
v3.PlayerAdded:Connect(function()
    task.wait(0.3)
    v2823()
    pcall(function()
        if PlayerDropdown.Refresh then
            PlayerDropdown:Refresh(v2816)
        end
    end)
end)
v3.PlayerRemoving:Connect(function()
    task.wait(0.1)
    v2823()
    pcall(function()
        if PlayerDropdown.Refresh then
            PlayerDropdown:Refresh(v2816)
        end
    end)
end)
PlayerCard:AddButton("Teleport ke Player", function()
    if v2815 and v2815 ~= "" then
        local v2825 = v3:FindFirstChild(v2815)
        if v2825 and v2825.Character and v2825.Character:FindFirstChild("HumanoidRootPart") then
            local v2826 = v4.Character
            if v2826 and v2826:FindFirstChild("HumanoidRootPart") then
                v2826.HumanoidRootPart.CFrame = v2825.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                v1:Notify({
                    Title = "Teleport",
                    Description = "Ke " .. v2815,
                    Duration = 2,
                })
            end
        else
            v1:Notify({
                Title = "Error",
                Description = "Target tidak valid!",
                Duration = 2,
            })
        end
        return
    end
    v1:Notify({
        Title = "Error",
        Description = "Pilih pemain terlebih dulu!",
        Duration = 3,
    })
end)
local v2827 = v2:CreateTab("Settings", false, false)
SettingsTab = v2827
local v2828 = SettingsTab:CreatePage("Settings")
S_Page1 = v2828
local v2829 = S_Page1:CreateSection("UI Config", "sliders-vertical")
AppearanceCard = v2829
AppearanceCard:AddKeybind("Menu Keybind", "RightShift", function(a422)
    v2:SetMenuKey(a422)
end, {Flag = "MenuKeybing"})
AppearanceCard:AddToggle("Transparency Toggle", false, function(a423)
    local v2830 = v2.SetTransparency
    local v2831 = a423 and 0.2 or 0
    v2830(v2, v2831)
end, {Flag = "ToggleTransparancy"})
AppearanceCard:AddToggle("Lock GUI", false, function(a424)
    v2:SetLocked(a424)
end, {Flag = "LockGui"})
AppearanceCard:AddToggle("Watermark", true, function(a425)
    v1:SetWatermark({Enabled = a425})
end, {Flag = "Watermark"})
local v2832 = S_Page1:CreateSection("Config", "sliders-vertical")
SavesCard = v2832
SavesCard:AddConfigManager("FebzHub/Configs")
task.spawn(function()
    task.wait(2)
    v482()
end)
v4.CharacterAdded:Connect(function()
    _G.Ox.State.busy = false
    _G.Ox.State.RandomMode_IsNormal = false
    if _G.Ox.Auto.SkillCheck then
        task.wait(1)
        v625()
    end
end)
v4.CharacterAdded:Connect(function()
    task.wait(1.5)
    if _G.Ox.NoSlowdownEnabled then
        local v2833 = v4.Character
        if v2833 then
            local v2834 = v2833:FindFirstChildOfClass("Humanoid")
            if v2834 then
                v2834.WalkSpeed = 16
            end
        end
    end
end)
v4.CharacterAdded:Connect(function()
    task.wait(1.5)
    if _G.Ox.BypassLeapEnabled then
        v996()
    end
end)
v6.InputBegan:Connect(function(a426, a427)
    if a427 then
        return
    end
    if a426.UserInputType == Enum.UserInputType.MouseButton2 and _G.Ox.Config.Surv_Aimbot_Enabled and GetRole() == "Survivor" then
        _G.Ox.isAimbotHolding = true
        _G.Ox.lockedAimbotTarget = getBestAimbotTarget()
    end
end)
v6.InputEnded:Connect(function(a428)
    if a428.UserInputType == Enum.UserInputType.MouseButton2 then
        _G.Ox.isAimbotHolding = false
        _G.Ox.lockedAimbotTarget = nil
        if _G.Ox.survivorAimbotHighlight then
            _G.Ox.survivorAimbotHighlight.Parent = nil
        end
    end
end)
task.spawn(function()
    while _G.Ox.ScriptAlive do
        task.wait(1)
        if not _G.Ox.ScriptAlive then
            break
        end
        if _G.Ox.Config.Surv_Aimbot_Enabled and GetRole() == "Survivor" and v6.TouchEnabled then
            local v2835 = v4:FindFirstChild("PlayerGui")
            if v2835 then
                local v2836 = v2835:FindFirstChild("Survivor-mob")
                if v2836 then
                    local v2837 = v2836:FindFirstChild("Controls")
                    if v2837 then
                        local v2838 = v2837:FindFirstChild("attack")
                        local v2839 = v2838 or v2837:FindFirstChild("Gui-mob")
                        if v2839 and v2839.Visible then
                            if not _G.Ox.isAimbotHolding then
                                _G.Ox.isAimbotHolding = true
                                _G.Ox.lockedAimbotTarget = getBestAimbotTarget()
                            end
                        elseif _G.Ox.isAimbotHolding then
                            _G.Ox.isAimbotHolding = false
                            _G.Ox.lockedAimbotTarget = nil
                            if _G.Ox.survivorAimbotHighlight then
                                _G.Ox.survivorAimbotHighlight.Parent = nil
                            end
                        end
                    end
                end
            end
        elseif _G.Ox.isAimbotHolding and v6.TouchEnabled then
            _G.Ox.isAimbotHolding = false
            _G.Ox.lockedAimbotTarget = nil
            if _G.Ox.survivorAimbotHighlight then
                _G.Ox.survivorAimbotHighlight.Parent = nil
            end
        end
    end
end)
local v2840 = nil
v6.InputBegan:Connect(function(a429, a430)
    local v2841 = a429.UserInputType == Enum.UserInputType.Touch
    local v2842 = GetRole()
    if a429.UserInputType == Enum.UserInputType.MouseButton1 then
        if a430 then
            return
        end
        if v2842 == "Killer" and _G.Ox.Config.Killer_Aimbot_Enabled then
            _G.Ox.lockedKillerAimbotTarget = getBestKillerAimbotTarget()
            if _G.Ox.lockedKillerAimbotTarget then
                _G.Ox.isKillerAimbotHolding = true
            end
        end
    end
    if v2841 and v2842 == "Killer" and _G.Ox.Config.Killer_Aimbot_Enabled then
        local v2843 = v4:FindFirstChild("PlayerGui")
        local v2844 = nil
        if v2843 then
            for v2849, v2850 in pairs(v2843:GetChildren()) do
                if string.sub(v2850.Name, -4) == "-mob" and v2850.Name ~= "Survivor-mob" then
                    v2844 = v2850
                    break
                end
            end
        end
        local v2851 = v2844 and v2844:FindFirstChild("Controls") and v2844.Controls:FindFirstChild("attack")
        if v2851 and v2851.Visible then
            local v2852 = a429.Position
            local v2853 = v2851.AbsolutePosition
            local v2854 = v2851.AbsoluteSize
            if v2853.X <= v2852.X and v2852.X <= v2853.X + v2854.X and v2853.Y <= v2852.Y and v2852.Y <= v2853.Y + v2854.Y then
                _G.Ox.lockedKillerAimbotTarget = getBestKillerAimbotTarget()
                if _G.Ox.lockedKillerAimbotTarget then
                    _G.Ox.isKillerAimbotHolding = true
                    v2840 = a429
                end
            end
        end
    end
end)
v6.InputEnded:Connect(function(a431)
    if a431.UserInputType == Enum.UserInputType.MouseButton1 then
        _G.Ox.isKillerAimbotHolding = false
        _G.Ox.lockedKillerAimbotTarget = nil
        if _G.Ox.killerAimbotHighlight then
            _G.Ox.killerAimbotHighlight.Parent = nil
        end
    end
    if a431.UserInputType == Enum.UserInputType.Touch and a431 == v2840 then
        _G.Ox.isKillerAimbotHolding = false
        _G.Ox.lockedKillerAimbotTarget = nil
        v2840 = nil
        if _G.Ox.killerAimbotHighlight then
            _G.Ox.killerAimbotHighlight.Parent = nil
        end
    end
end)
v4.CharacterAdded:Connect(function()
    task.wait(1.5)
    ReapplyPerformanceDelayed()
end)
workspace.ChildAdded:Connect(function(a432)
    if a432.Name == "Map" then
        task.wait(1)
        ReapplyPerformanceDelayed()
    end
end)
task.spawn(function()
    task.wait(2)
    ReapplyPerformanceDelayed()
end)
v1:Notify({Title = "Febz Hub", Description = "Loaded", Duration = 3})

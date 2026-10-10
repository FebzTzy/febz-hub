-- language: Luau, file: loader.lua
-- Febz Hub — Loader with remote key validation

local CFG = {
    KEYS_URL   = "https://raw.githubusercontent.com/FebzTzy/febz-hub/main/keys.json",
    SCRIPT_URL = "https://raw.githubusercontent.com/FebzTzy/febz-hub/main/febz-hub-obf.lua",
    CACHE_FILE = "FebzHub/keycache.json",
    LOCAL_FILE = "FebzHub/keydata.json",
    BIND_FILE  = "FebzHub/keybind.json",
    CACHE_TTL  = 300,
    HWID_REQ   = true,
}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local function ensure_folder(p) pcall(function() if not isfolder(p) then makefolder(p) end end) end
local function read_json(p)
    local ok, d = pcall(function() if isfile(p) then return HttpService:JSONDecode(readfile(p)) end return nil end)
    return ok and d or nil
end
local function write_json(p, d) pcall(function() writefile(p, HttpService:JSONEncode(d)) end) end
local function rm_file(p) pcall(function() if isfile(p) then delfile(p) end end) end

local function get_hwid()
    local ok, h = pcall(function()
        if gethwid then return gethwid() end
        if syn and syn.get_hwid then return syn.get_hwid() end
        if get_hwid then return get_hwid() end
        return nil
    end)
    return ok and h or nil
end

local function notify(title, desc, color)
    local gui = Instance.new("ScreenGui")
    gui.Name = "FebzLoaderNotify"
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
    t.Size = UDim2.new(1, -20, 0, 26); t.Position = UDim2.new(0, 10, 0, 8)
    t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextSize = 14
    t.TextColor3 = color or Color3.fromRGB(240, 240, 240); t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = title
    local d = Instance.new("TextLabel", frame)
    d.Size = UDim2.new(1, -20, 0, 50); d.Position = UDim2.new(0, 10, 0, 34)
    d.BackgroundTransparency = 1; d.Font = Enum.Font.GothamMedium; d.TextSize = 12
    d.TextColor3 = Color3.fromRGB(220, 220, 230); d.TextWrapped = true
    d.TextXAlignment = Enum.TextXAlignment.Left; d.TextYAlignment = Enum.TextYAlignment.Top
    d.Text = desc
    task.delay(7, function() if gui and gui.Parent then gui:Destroy() end end)
end

-- fetch keys.json dengan cache
local function fetch_keys_remote()
    local ok, body = pcall(function() return game:HttpGet(CFG.KEYS_URL, true) end)
    if not ok or not body or body == "" then return nil, "fetch_failed" end
    local dok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not dok or type(data) ~= "table" then return nil, "decode_failed" end
    ensure_folder("FebzHub")
    write_json(CFG.CACHE_FILE, { fetched_at = os.time(), data = data })
    return data, "ok"
end

local function load_cache()
    local cache = read_json(CFG.CACHE_FILE)
    if not cache or not cache.data or not cache.fetched_at then return nil end
    if os.time() - cache.fetched_at > 86400 then return nil end
    return cache.data
end

local function get_keys_config()
    local cache = read_json(CFG.CACHE_FILE)
    local age = cache and cache.fetched_at and (os.time() - cache.fetched_at) or math.huge
    if age >= CFG.CACHE_TTL then
        local data = fetch_keys_remote()
        if data then return data end
        local cached = load_cache()
        if cached then return cached end
        return nil
    end
    return cache.data
end

local function duration_to_seconds(dur, unit)
    dur = tonumber(dur) or 0
    if dur <= 0 then return 0 end
    unit = string.lower(tostring(unit or "minute"))
    local mult = ({
        second=1, minute=60, hour=3600, day=86400, week=604800,
        month=2592000, year=31536000, permanent=0, perm=0,
    })[unit] or 60
    if mult == 0 then return 0 end
    return dur * mult
end

local function compute_expiry(entry, key, hwid)
    if not entry then return 0 end
    if entry.expires ~= nil then return tonumber(entry.expires) or 0 end
    local unit = entry.unit or "permanent"
    local dur = tonumber(entry.duration) or 0
    if unit == "permanent" or dur <= 0 then return 0 end
    local secs = duration_to_seconds(dur, unit)
    if secs <= 0 then return 0 end
    ensure_folder("FebzHub")
    local bind = read_json(CFG.BIND_FILE) or {}
    local rec = bind[key]
    if type(rec) == "string" then
        rec = { hwid = rec, first_use = os.time() }
        bind[key] = rec
        write_json(CFG.BIND_FILE, bind)
    end
    if not rec then
        rec = { hwid = hwid, first_use = os.time() }
        bind[key] = rec
        write_json(CFG.BIND_FILE, bind)
    end
    return (tonumber(rec.first_use) or os.time()) + secs
end

local function format_remaining(ts)
    if not ts or ts <= 0 then return "permanent" end
    local rem = ts - os.time()
    if rem <= 0 then return "expired" end
    local d = math.floor(rem / 86400)
    local h = math.floor((rem % 86400) / 3600)
    local m = math.floor((rem % 3600) / 60)
    local parts = {}
    if d > 0 then table.insert(parts, d .. "d") end
    if h > 0 then table.insert(parts, h .. "h") end
    if m > 0 then table.insert(parts, m .. "m") end
    if #parts == 0 then table.insert(parts, (rem % 60) .. "s") end
    return table.concat(parts, " ")
end

local function validate(key, hwid, config)
    if not key or key == "" then return false, "empty" end
    if not config or not config.keys then return false, "no_config" end
    if config.maintenance == true then return false, "maintenance" end
    if hwid and type(config.blacklist_hwid) == "table" then
        for _, b in ipairs(config.blacklist_hwid) do
            if b == hwid then return false, "hwid_banned" end
        end
    end
    local entry = config.keys[key]
    if not entry then return false, "invalid" end
    if CFG.HWID_REQ and hwid then
        ensure_folder("FebzHub")
        local bind = read_json(CFG.BIND_FILE) or {}
        local rec = bind[key]
        local existing = type(rec) == "string" and rec or (type(rec) == "table" and rec.hwid)
        if existing and existing ~= hwid then return false, "bound_elsewhere" end
    end
    local exp = compute_expiry(entry, key, hwid)
    if exp > 0 and os.time() > exp then return false, "expired", exp end
    return true, "ok", exp
end

local function prompt_key()
    local gui = Instance.new("ScreenGui")
    gui.Name = "FebzLoaderPrompt"
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
    bs.Color = Color3.fromRGB(100, 100, 110); bs.Thickness = 1.2

    local title = Instance.new("TextLabel", box)
    title.Size = UDim2.new(1, 0, 0, 30); title.Position = UDim2.new(0, 0, 0, 12)
    title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold
    title.TextSize = 16; title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.Text = "Febz Hub — Key Required"

    local sub = Instance.new("TextLabel", box)
    sub.Size = UDim2.new(1, -40, 0, 34); sub.Position = UDim2.new(0, 20, 0, 46)
    sub.BackgroundTransparency = 1; sub.Font = Enum.Font.GothamMedium
    sub.TextSize = 12; sub.TextColor3 = Color3.fromRGB(160, 160, 170)
    sub.TextWrapped = true
    sub.Text = "Masukin key lu. Hubungi owner kalau belum punya."

    local input = Instance.new("TextBox", box)
    input.Size = UDim2.new(1, -40, 0, 38); input.Position = UDim2.new(0, 20, 0, 92)
    input.BackgroundColor3 = Color3.fromRGB(25, 25, 30); input.BorderSizePixel = 0
    input.Font = Enum.Font.Code; input.TextSize = 13
    input.TextColor3 = Color3.fromRGB(235, 235, 240)
    input.PlaceholderText = "XXXX-XXXX-XXXX-XXXX"
    input.PlaceholderColor3 = Color3.fromRGB(90, 90, 100)
    input.Text = ""; input.ClearTextOnFocus = false
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)

    local status = Instance.new("TextLabel", box)
    status.Size = UDim2.new(1, -40, 0, 40); status.Position = UDim2.new(0, 20, 0, 134)
    status.BackgroundTransparency = 1; status.Font = Enum.Font.GothamMedium
    status.TextSize = 11; status.TextColor3 = Color3.fromRGB(255, 100, 100)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.TextWrapped = true; status.Text = ""

    local submit = Instance.new("TextButton", box)
    submit.Size = UDim2.new(1, -40, 0, 32); submit.Position = UDim2.new(0, 20, 0, 178)
    submit.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
    submit.BorderSizePixel = 0; submit.Font = Enum.Font.GothamBold
    submit.TextSize = 13; submit.TextColor3 = Color3.fromRGB(235, 235, 240)
    submit.Text = "Verify"
    Instance.new("UICorner", submit).CornerRadius = UDim.new(0, 6)

    local done = false

    local function verify(k)
        status.TextColor3 = Color3.fromRGB(180, 180, 190)
        status.Text = "memverifikasi..."
        local cfg = get_keys_config()
        if not cfg then
            status.TextColor3 = Color3.fromRGB(255, 100, 100)
            status.Text = "gagal fetch keys — coba lagi"
            return
        end
        local ok, reason, exp = validate(k, get_hwid(), cfg)
        if ok then
            ensure_folder("FebzHub")
            write_json(CFG.LOCAL_FILE, { key = k, saved_at = os.time(), hwid = get_hwid() })
            status.TextColor3 = Color3.fromRGB(120, 255, 120)
            status.Text = "berhasil — sisa: " .. format_remaining(exp)
            done = true
            task.wait(0.6)
            gui:Destroy()
        else
            local msg = ({
                empty="key kosong", invalid="key salah / nggak terdaftar",
                expired="key udah expired", bound_elsewhere="key ke-lock device lain",
                hwid_banned="device lu di-ban", maintenance="hub maintenance",
                no_config="config kosong",
            })[reason] or ("gagal: " .. tostring(reason))
            status.TextColor3 = Color3.fromRGB(255, 100, 100)
            status.Text = msg
        end
    end

    submit.MouseButton1Click:Connect(function()
        verify((input.Text or ""):gsub("%s+", ""):upper())
    end)
    input.FocusLost:Connect(function(enter)
        if enter then verify((input.Text or ""):gsub("%s+", ""):upper()) end
    end)

    while not done do task.wait(0.1) end
end

-- ===== MAIN =====
local function gate()
    local stored = read_json(CFG.LOCAL_FILE)
    if stored and stored.key then
        local cfg = get_keys_config()
        if cfg then
            local ok, reason, exp = validate(stored.key, get_hwid(), cfg)
            if ok then
                notify("Febz Hub", "Key valid. Sisa: " .. format_remaining(exp), Color3.fromRGB(120, 255, 120))
                return true
            end
            rm_file(CFG.LOCAL_FILE)
            if reason == "maintenance" then
                notify("Maintenance", "Script lagi maintenance.", Color3.fromRGB(255, 200, 100))
                return false
            end
        else
            notify("Connection", "Gagal fetch config.", Color3.fromRGB(255, 100, 100))
            return false
        end
    end
    prompt_key()
    local after = read_json(CFG.LOCAL_FILE)
    if after and after.key then
        local cfg = get_keys_config()
        if cfg then
            local ok = validate(after.key, get_hwid(), cfg)
            if ok then return true end
        end
    end
    return false
end

if not gate() then
    return
end

-- fetch script utama (obfuscated)
local ok, body = pcall(function() return game:HttpGet(CFG.SCRIPT_URL, true) end)
if not ok or not body or body == "" then
    notify("Error", "Gagal ambil script dari server.", Color3.fromRGB(255, 100, 100))
    return
end

local load_ok, err = pcall(function()
    local fn = loadstring(body)
    if fn then fn() end
end)
if not load_ok then
    notify("Error", "Script error: " .. tostring(err), Color3.fromRGB(255, 100, 100))
end

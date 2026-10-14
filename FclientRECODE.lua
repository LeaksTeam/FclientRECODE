--================================================================
-- LOLHAX LITE v1.8 + Abysall Speed/PositionSpoof
-- + Fluent UI
-- + Tracers / Door Reach / оптимизированный мониторинг (Watcher)
-- + Watermark (FPS / ping / ник / аватар + Blur/Acrylic)
-- + Arrows (стрелки на Rush и пропущенные предметы)
-- + Crosshair (5 прицелов как в CS2 + Rainbow)
-- + Third Person Head Fix (голова теперь есть)
-- + Keybinds: фиолетовый текст во всех темах
--================================================================
--============================================================
-- STATE
--============================================================
local STATE = {
    GameReady = false,
    Connections = {},
    GlobalOffset = 0,
    States = { manip = false, airlock = false, pos = false },
    lockedY = 0,
    FLY_HEIGHT = 5,
    haltWarned = false,
    LastPadlockFire = 0,
    PADLOCK_COOLDOWN = 0.6,
    PadlockAttempts = 0,
    AutoInteractDebug = false,
    PROMPT_COOLDOWN = 0.05,
    LastPromptFire = {},
    NotifyCooldown = {},
    PadlockCode = nil,
    PadlockCode_N = nil,
    PadlockBruteforceQueue = {},
    DisablerMode = "Ladder",
    ChairState = { Conn1 = nil, Conn2 = nil, Frozen = false, LastSeat = 0, SeatPart = nil },
    HighlightConn = nil,
    HighlightRegistry = {},
    NameCache = {},
    SpecificCache = {},
    MonsterCache = {},
    EspQueue = {},
    NotifyQueue = {},
    PetalRegistry = {},
    SpeedBoostValue = 0,
    OldJump = false,
    OldSlide = false,
    VelocityManipEnabled = false,
    ManipulateBody = nil,
    GlitchActive = false,
    SelfKilled = false,
}
--============================================================
-- SERVICES
--============================================================
local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local Workspace            = game:GetService("Workspace")
local Lighting             = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService         = game:GetService("TweenService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local UserInputService     = game:GetService("UserInputService")
local Camera               = Workspace.CurrentCamera
local LocalPlayer          = Players.LocalPlayer
--============================================================
-- SHARED FUNCTIONS
--============================================================
local function TrackConnection(conn)
    table.insert(STATE.Connections, conn)
    return conn
end
local function DisconnectAll()
    for _, conn in ipairs(STATE.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(STATE.Connections)
end
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[LOLHAX] safe call failed:", err) end
    return ok
end
local function CallIfReady(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[LOLHAX] deferred call failed:", err) end
    return ok
end
--============================================================
-- GAME READY
--============================================================
task.spawn(function()
    pcall(function()
        game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 30)
    end)
    task.wait(5)
    STATE.GameReady = true
    print("[LOLHAX] GameReady = true")
end)
--============================================================
-- SPLASH SCREEN  (F -> FCLIENT -> улетает вверх -> появляется GUI)
--============================================================
-- Оптимизации против лагов:
--  * без BlurEffect (размытие всего экрана очень дорогое на слабых ПК);
--  * без UIGradient / UIStroke на крупном тексте;
--  * логотип лежит в CanvasGroup: он рендерится один раз, а движение и
--    прозрачность работают как с готовой картинкой;
--  * анимация стартует только ПОСЛЕ того, как библиотека загружена и меню
--    собрано (пока идёт загрузка, показывается статичное затемнение).
STATE.SplashReady = false
STATE.UIBuilt = false
STATE.SplashDone = false   -- true только когда заставка ПОЛНОСТЬЮ закончилась (до этого конфиг не грузится)
STATE.SplashGui = nil
-- Скорость заставки: больше число = медленнее (1 = быстро, 1.8 = спокойно, 2.5 = очень медленно)
local SPLASH_SPEED = 1.2
local function PlaySplash()
    local TextService = game:GetService("TextService")
    local ACCENT = Color3.fromRGB(160, 100, 220)
    local function D(t) return t * SPLASH_SPEED end
    local FONT = Enum.Font.GothamBlack
    pcall(function() FONT = Enum.Font.Michroma end)
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "_LOLHAX_Splash"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local okParent = pcall(function() gui.Parent = parent end)
    if not okParent or not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    STATE.SplashGui = gui
    local function tw(obj, t, props, style, dir)
        local tween = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
        tween:Play()
        return tween
    end
    -- затемнение экрана
    local dim = Instance.new("Frame")
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 1
    dim.BorderSizePixel = 0
    dim.Parent = gui
    tw(dim, 0.6, { BackgroundTransparency = 0.3 }, Enum.EasingStyle.Sine)
    local loading = Instance.new("TextLabel")
    loading.AnchorPoint = Vector2.new(0.5, 1)
    loading.Position = UDim2.new(0.5, 0, 1, -40)
    loading.Size = UDim2.fromOffset(300, 20)
    loading.BackgroundTransparency = 1
    loading.Font = Enum.Font.GothamMedium
    loading.Text = "LOADING..."
    loading.TextSize = 14
    loading.TextColor3 = ACCENT
    loading.TextTransparency = 0.2
    loading.Parent = gui
    -- ждём, пока скрипт загрузит библиотеку и соберёт меню (тяжёлая часть)
    local t0 = tick()
    while not STATE.UIBuilt and tick() - t0 < 40 do task.wait(0.05) end
    for _ = 1, 12 do RunService.Heartbeat:Wait() end
    task.wait(0.6)
    loading:Destroy()
    -- Размеры
    local vp = (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
    local textSize = math.clamp(math.floor(vp.Y * 0.12), 48, 110)
    local H = textSize + 16
    local fW = TextService:GetTextSize("F", textSize, FONT, Vector2.new(2000, 2000)).X + 6
    local cW = TextService:GetTextSize("CLIENT", textSize, FONT, Vector2.new(4000, 2000)).X + 6
    local total = fW + cW
    local PAD = 20
    local groupH = H + 56 + PAD
    -- логотип целиком в CanvasGroup (рендерится один раз)
    local group = Instance.new("CanvasGroup")
    group.AnchorPoint = Vector2.new(0.5, 0.5)
    group.Position = UDim2.new(0.5, 0, 0.5, 0)
    group.Size = UDim2.fromOffset(total + PAD * 2, groupH)
    group.BackgroundTransparency = 1
    group.GroupTransparency = 0
    group.Parent = gui
    -- буква F: клип-фрейм раскрывается слева направо ("пишется")
    local fStartX = PAD + (total - fW) / 2
    local fClip = Instance.new("Frame")
    fClip.Position = UDim2.fromOffset(fStartX, PAD / 2)
    fClip.Size = UDim2.fromOffset(0, H)
    fClip.BackgroundTransparency = 1
    fClip.ClipsDescendants = true
    fClip.Parent = group
    local fLabel = Instance.new("TextLabel")
    fLabel.Position = UDim2.fromOffset(0, 0)
    fLabel.Size = UDim2.fromOffset(fW, H)
    fLabel.BackgroundTransparency = 1
    fLabel.Font = FONT
    fLabel.Text = "F"
    fLabel.TextSize = textSize
    fLabel.TextColor3 = ACCENT
    fLabel.TextXAlignment = Enum.TextXAlignment.Left
    fLabel.Parent = fClip
    -- слово CLIENT: вырастает из буквы F
    local clip = Instance.new("Frame")
    clip.Position = UDim2.fromOffset(PAD + fW, PAD / 2)
    clip.Size = UDim2.fromOffset(0, H)
    clip.BackgroundTransparency = 1
    clip.ClipsDescendants = true
    clip.Parent = group
    local cLabel = Instance.new("TextLabel")
    cLabel.Position = UDim2.fromOffset(0, 0)
    cLabel.Size = UDim2.fromOffset(cW, H)
    cLabel.BackgroundTransparency = 1
    cLabel.Font = FONT
    cLabel.Text = "CLIENT"
    cLabel.TextSize = textSize
    cLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    cLabel.TextXAlignment = Enum.TextXAlignment.Left
    cLabel.TextTransparency = 1
    cLabel.Parent = clip
    local sub = Instance.new("TextLabel")
    sub.Position = UDim2.fromOffset(PAD, PAD / 2 + H + 6)
    sub.Size = UDim2.fromOffset(total, 22)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.GothamMedium
    sub.Text = "LITE  v1.8"
    sub.TextSize = math.clamp(math.floor(textSize * 0.2), 12, 24)
    sub.TextColor3 = ACCENT
    sub.TextTransparency = 1
    sub.Parent = group
    local line = Instance.new("Frame")
    line.AnchorPoint = Vector2.new(0.5, 0)
    line.Position = UDim2.fromOffset(PAD + total / 2, PAD / 2 + H + 36)
    line.Size = UDim2.fromOffset(0, 2)
    line.BackgroundColor3 = ACCENT
    line.BackgroundTransparency = 0.2
    line.BorderSizePixel = 0
    line.Parent = group
    -- Анимация
    -- 1) F "пишется"
    tw(fClip, D(1.4), { Size = UDim2.fromOffset(fW, H) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    task.wait(D(1.7))
    -- 2) F уезжает влево, из неё вырастает CLIENT
    tw(fClip, D(1.0), { Position = UDim2.fromOffset(PAD, PAD / 2) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    task.wait(D(0.4))
    tw(clip, D(1.2), { Size = UDim2.fromOffset(cW, H) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tw(cLabel, D(1.0), { TextTransparency = 0 }, Enum.EasingStyle.Sine)
    task.wait(D(1.0))
    -- 3) подпись и линия
    tw(sub, D(0.8), { TextTransparency = 0.1 }, Enum.EasingStyle.Sine)
    tw(line, D(1.0), { Size = UDim2.fromOffset(total, 2) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    task.wait(D(1.7))
    -- 4) FCLIENT улетает вверх, экран светлеет, появляется GUI
    STATE.SplashReady = true
    tw(group, D(0.95), { Position = UDim2.new(0.5, 0, -0.35, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    tw(group, D(0.8), { GroupTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
    tw(dim, D(0.95), { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
    task.wait(D(1.0))
    pcall(function() gui:Destroy() end)
    STATE.SplashGui = nil
    STATE.SplashDone = true
end
task.spawn(function()
    local ok, err = pcall(PlaySplash)
    if not ok then
        warn("[LOLHAX] splash failed:", err)
        if STATE.SplashGui then pcall(function() STATE.SplashGui:Destroy() end) STATE.SplashGui = nil end
    end
    STATE.SplashReady = true -- что бы ни случилось, GUI не должен остаться скрытым
    STATE.SplashDone = true
end)
--============================================================
-- LIBRARY (Fluent)
--============================================================
local Fluent           = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager      = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
-- В Fluent все элементы лежат в одной таблице Options.
-- Toggles = Options, чтобы старый код (Toggles.X.Value) работал без правок.
local Options = Fluent.Options
local Toggles = Fluent.Options
-- Шим: весь остальной код использует Library.Unloaded
local Library = { Unloaded = false }
--============================================================
-- STATIC DATABASE
--============================================================
local StaticDB
task.spawn(function()
    StaticDB = {
        MiscPickups = {
            ["Glowsticks"]="Glowstick", ["StarJug"]="Barrel of Starlight", ["Lockpick"]="Lock-Pick",
            ["Bandage"]="Bandage", ["StarVial"]="Vial of Starlight", ["SkeletonKey"]="Skeleton Key",
            ["Crucifix"]="Crucifix", ["CrucifixWall"]="Crucifix", ["Flashlight"]="Flashlight",
            ["Candle"]="Candle", ["Straplight"]="Straplight", ["Vitamins"]="Vitamins",
            ["Lighter"]="Lighter", ["Shears"]="Shears", ["BatteryPack"]="Battery Pack",
            ["BandagePack"]="Bandage Pack", ["LaserPointer"]="Laser Pointer", ["Bulklight"]="Bulk Light",
            ["Battery"]="Battery", ["Candy"]="Candy", ["Pizza"]="Pizza", ["Cheese"]="Cheese",
            ["Bread"]="Bread", ["Smoothie"]="Smoothie", ["RiftSmoothie"]="Moonlight Smoothie",
            ["GweenSoda"]="Gween Soda", ["Donut"]="Donut", ["AloeVera"]="Aloe Vera",
            ["GoldPile"]="Gold Pile",
        },
        BACKDOOR_LEVERS = { TimerLever = "Timer Lever", StairwellFireAlarm = "Stairwell Fire Alarm" },
        LIBRARY_BOOKS = { LiveHintBook = "Book" },
        BREAKER_NAMES = { BreakerSwitch="Breaker", BreakerPole="Breaker", CircuitBreakerSwitch="Breaker", LiveBreakerPolePickup="Breaker Pole" },
        FUSE_NAMES = { FuseObtain="Fuse", FuseHolder="Fuse Holder" },
        BASEMENT_LEVERS = { ["Lever"]="Basement Lever", ["LeverForGate"]="Gate Lever" },
        HIDE_BOX_NAMES = {
            ["HonchoBox"]="Honcho Box", ["HonchoBox1"]="Honcho Box 1", ["HonchoBox2"]="Honcho Box 2",
            ["HonchoBox3"]="Honcho Box 3", ["HonchoBox4"]="Honcho Box 4", ["HonchoBox5"]="Honcho Box 5",
            ["HonchoBox6"]="Honcho Box 6", ["HonchoBox7"]="Honcho Box 7", ["HonchoBox8"]="Honcho Box 8",
            ["HonchoBox9"]="Honcho Box 9", ["HonchoBox10"]="Honcho Box 10", ["HideBox"]="Hide Box",
            ["ArchiveBox"]="Archive Box", ["SortBox"]="Sort Box", ["BoxSort"]="Box Sort",
            ["CardboardBox"]="Cardboard Box", ["HonchoCrate"]="Honcho Crate", ["Crate"]="Crate",
        },
        MONSTER_NAMES = {
            FigureRig="Figure", Figure="Figure", FigureRagdoll="Figure",
            RushMoving="Rush", AmbushMoving="Ambush", A60="A-60", A120="A-120",
            Eyes="Eyes", BackdoorLookman="Lookman", Lookman="Lookman", Dread="Dread",
            BackdoorRush="Blitz", GrumbleRig="Grumble", GiggleCeiling="Giggle",
            SeekMoving="Seek", SeekMovingNewClone="Seek", Halt="Halt", Hide="Hide",
            Screech="Screech", Dupe="Dupe", DoorFake="Dupe", FakeDoor="Dupe",
            Snare="Snare", JeffTheKiller="Jeff the Killer", GloomPile="Gloombat Eggs",
            GloombatSwarm="Gloombat Swarm", SallyMoving="Sally", Groundskeeper="Groundskeeper",
            MonumentEntity="Monument", Shadow="Shadow", Glitch="Glitch",
            Timothy="Timothy", SpiderJumpscare="Timothy", CustomEntity="Custom Entity",
            FrozenAmbush="Frozen Ambush", GlitchRush="RNIUSHCG==", GlitchAmbush="AR0xMBUSH",
        },
        LightSources = { "Flashlight", "Candle", "Straplight", "Lighter", "LaserPointer", "Bulklight", "Glowsticks" },
        INFINITE_ITEM_NAMES = {
            ["Lockpick"]=true, ["SkeletonKey"]=true, ["Shears"]=true, ["Multitool"]=true,
            ["Key"]=true, ["KeyBackdoor"]=true, ["KeyElectrical"]=true, ["KeyIron"]=true, ["GeneratorFuse"]=true,
        },
        EntityDistances = {
            ["RushMoving"]=85, ["AmbushMoving"]=150, ["A60"]=125, ["A120"]=85,
            ["GlitchRush"]=90, ["GlitchAmbush"]=175, ["BackdoorRush"]=85, ["CustomEntity"]=85,
        },
        CutsceneNames = {
            "Figure","FigureEnd","FigureHotelEnd","FigureHotelFire","SeekIntroFools","SeekIntroHotel",
            "SeekIntroMines","SeekIntroMines2","SerewSeekDrain","SewerSeekLower","GrumbleNestEnd","EyestalkIntro",
        },
        CONTAINER_NAMES = {
            ["Drawer"]=true, ["Nightstand"]=true, ["Dresser"]=true, ["Desk"]=true,
            ["Cabinet"]=true, ["Locker"]=true, ["Chest"]=true, ["Table"]=true,
            ["Toolbox"]=true, ["ChestBox"]=true, ["Toolshed_Small"]=true, ["Locker_Small"]=true,
            ["Chest_Vine"]=true, ["ChestBoxLocked"]=true, ["Modular_Bookshelf"]=true,
            ["LootHolder"]=true, ["ArchiveBox"]=true, ["CardboardBox"]=true,
            ["Crate"]=true, ["HonchoCrate"]=true,
        },
        ARCHIVE_MONSTER_KEYWORDS = {
            "monster","entity","npc","archive","ransom","chaser","killer","beast",
            "ghost","demon","figure","rush","ambush","seek","halt","hide","screech",
            "dupe","snare","grumble","giggle","eyes","lookman","dread","blitz",
        },
        SPECIFIC_ENTITIES = {
            ["Scribbles"] = { keywords = {"scribble","scribbles"}, color = Color3.fromRGB(180, 100, 255) },
            ["Alma"]      = { keywords = {"alma"},                  color = Color3.fromRGB(255, 100, 200) },
            ["Teller"]    = { keywords = {"teller"},                color = Color3.fromRGB(255, 200, 0)   },
            ["Bash"]      = { keywords = {"bash"},                  color = Color3.fromRGB(255, 120, 0)   },
            ["Honcho"]    = { keywords = {"honcho"},                color = Color3.fromRGB(0, 200, 100)   },
            ["Drones"]    = { keywords = {"drone","drones"},        color = Color3.fromRGB(0, 220, 220)   },
        },
        FURNITURE_KEYWORDS = {
            "box","crate","chair","stool","locker","cabinet","drawer","desk",
            "table","shelf","bed","sofa","couch","bench","hidebox","nightstand","dresser",
        },
        LOTUS_PETAL_KEYWORDS = {
            "lotus","petal","lotuspetal","lotus_petal",
        },
    }
end)
--============================================================
-- KEYWORD CHECKS
--============================================================
local IsFurnitureName, GetSpecificEntityType, IsMonsterEntity,
      IsArchiveKeywordEntity, IsArchiveMonster, IsLotusPetal
task.spawn(function()
    -- ОПТИМИЗАЦИЯ: кэш по ИМЕНИ объекта.
    -- В комнатах тысячи объектов с одинаковыми именами ("Part", "Wall", "Light"...),
    -- поэтому поиск ключевых слов (string.find в циклах) выполняется один раз на имя,
    -- а не на каждый новый объект. Для "пустых" объектов больше не создаются записи
    -- в покомпонентных кэшах (меньше мусора и работы при загрузке большой комнаты).
    local FurnitureNameCache = {}
    local SpecificNameCache  = {}
    local ArchiveNameCache   = {}
    local LotusNameCache     = {}
    IsFurnitureName = function(lower)
        local c = FurnitureNameCache[lower]
        if c ~= nil then return c end
        local res = false
        for _, kw in ipairs(StaticDB.FURNITURE_KEYWORDS) do
            if lower:find(kw, 1, true) then res = true break end
        end
        FurnitureNameCache[lower] = res
        return res
    end
    -- имя -> displayName | "Honcho" | false
    local function MatchSpecificName(name)
        local m = SpecificNameCache[name]
        if m ~= nil then return m end
        m = false
        local lower = name:lower()
        if not IsFurnitureName(lower) then
            if lower:find("honcho", 1, true) then
                m = "Honcho"
            else
                for displayName, data in pairs(StaticDB.SPECIFIC_ENTITIES) do
                    if displayName ~= "Honcho" then
                        for _, kw in ipairs(data.keywords) do
                            if lower:find(kw, 1, true) then m = displayName break end
                        end
                        if m then break end
                    end
                end
            end
        end
        SpecificNameCache[name] = m
        return m
    end
    GetSpecificEntityType = function(obj)
        if not obj then return nil end
        local cached = STATE.SpecificCache[obj]
        if cached ~= nil then
            if cached == false then return nil end
            return cached.name, cached.color
        end
        if not (obj:IsA("Model") or obj:IsA("BasePart")) then
            return nil
        end
        local matched = MatchSpecificName(obj.Name)
        if not matched then return nil end
        if matched == "Honcho" then
            if obj:IsA("Model") and (obj:FindFirstChildOfClass("Humanoid") or obj.PrimaryPart) then
                local data = StaticDB.SPECIFIC_ENTITIES["Honcho"]
                local entry = { name = "Honcho", color = data.color }
                STATE.SpecificCache[obj] = entry
                return "Honcho", data.color
            end
            STATE.SpecificCache[obj] = false
            return nil
        end
        local data = StaticDB.SPECIFIC_ENTITIES[matched]
        local entry = { name = matched, color = data.color }
        STATE.SpecificCache[obj] = entry
        return matched, data.color
    end
    IsMonsterEntity = function(obj)
        if not obj then return nil end
        local cached = STATE.MonsterCache[obj]
        if cached ~= nil then
            if cached == false then return nil end
            return cached
        end
        -- прямой поиск в таблице по имени: дешевле любого кэша, поэтому false не запоминаем
        local disp = StaticDB.MONSTER_NAMES[obj.Name]
        if not disp then return nil end
        if not (obj:IsA("Model") or obj:IsA("BasePart")) then return nil end
        STATE.MonsterCache[obj] = disp
        return disp
    end
    local function MatchArchiveName(name)
        local m = ArchiveNameCache[name]
        if m ~= nil then return m end
        m = false
        local lower = name:lower()
        if not IsFurnitureName(lower) then
            for _, kw in ipairs(StaticDB.ARCHIVE_MONSTER_KEYWORDS) do
                if lower:find(kw, 1, true) then m = true break end
            end
        end
        ArchiveNameCache[name] = m
        return m
    end
    IsArchiveKeywordEntity = function(obj)
        if not obj then return false end
        local cached = STATE.NameCache[obj]
        if cached ~= nil then
            if cached == false then return false end
            return cached.archive
        end
        if not MatchArchiveName(obj.Name) then return false end
        local entry = { archive = false }
        if obj:IsA("Model") then
            if obj:FindFirstChildOfClass("Humanoid") or obj.PrimaryPart then
                entry.archive = true
            end
        elseif obj:IsA("BasePart") then
            entry.archive = true
        end
        STATE.NameCache[obj] = entry
        return entry.archive
    end
    IsArchiveMonster = function(obj)
        if not obj then return false end
        if IsMonsterEntity(obj) then return true end
        if GetSpecificEntityType(obj) then return true end
        return IsArchiveKeywordEntity(obj)
    end
    IsLotusPetal = function(obj)
        if not obj then return false end
        local name = obj.Name
        local m = LotusNameCache[name]
        if m == nil then
            m = false
            local lower = name:lower()
            for _, kw in ipairs(StaticDB.LOTUS_PETAL_KEYWORDS) do
                if lower:find(kw, 1, true) then m = true break end
            end
            LotusNameCache[name] = m
        end
        if not m then return false end
        return obj:IsA("Model") or obj:IsA("BasePart")
    end
end)
--============================================================
-- NOTIFICATION SYSTEM
--============================================================
local Notify
local NotificationHolder
local LXNotifications
task.spawn(function()
    local NOTIFY_MAIN_COLOR = Color3.fromRGB(160, 100, 220)
    local NOTIFY_BG_COLOR   = Color3.fromRGB(35, 20, 50)
    LXNotifications = Instance.new("ScreenGui", game.CoreGui)
    LXNotifications.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    LXNotifications.ScreenInsets = Enum.ScreenInsets.None
    LXNotifications.Name = "_LXNotifications"
    NotificationHolder = Instance.new("Frame", LXNotifications)
    NotificationHolder.Size = UDim2.fromScale(1, 1)
    NotificationHolder.Transparency = 1
    NotificationHolder.BackgroundTransparency = 1
    Notify = function(TitleText, SubText, Duration, Force)
        if not Force then
            if Toggles and Toggles.GN_Enabled and not Toggles.GN_Enabled.Value then return end
        end
        local DPISize = (Options and Options.GN_NotificationDPISize and Options.GN_NotificationDPISize.Value) or 1
        local Offset = STATE.GlobalOffset
        STATE.GlobalOffset += 0.05 * DPISize
        local MainColor = NOTIFY_MAIN_COLOR
        local Alignment = 0.5
        if Options and Options.GN_NotificationAlignment then
            if Options.GN_NotificationAlignment.Value == "Left" then Alignment = 1
            elseif Options.GN_NotificationAlignment.Value == "Right" then Alignment = 0 end
        end
        local Main = Instance.new("Frame", NotificationHolder)
        Main.AnchorPoint = Vector2.new(Alignment, 0.5)
        Main.Size = UDim2.fromScale(0.19 * DPISize, 0.045 * DPISize)
        Main.Position = UDim2.fromScale(0.5, 0.5)
        Main.Transparency = 1
        Main.BackgroundColor3 = NOTIFY_BG_COLOR
        Main.BorderSizePixel = 0
        local Line = Instance.new("Frame", Main)
        Line.AnchorPoint = Vector2.new(0, 1)
        Line.BorderSizePixel = 0
        Line.Position = UDim2.fromScale(0, 1)
        Line.Size = UDim2.fromScale(0, 0.03)
        Line.Transparency = 1
        local LXLogo = Instance.new("ImageLabel", Main)
        LXLogo.AnchorPoint = Vector2.new(0.5, 0.5)
        LXLogo.Position = UDim2.fromScale(0.067, 0.5)
        LXLogo.Size = UDim2.fromScale(0.121, 0.9)
        LXLogo.Image = "rbxassetid://90305907167101"
        LXLogo.ScaleType = Enum.ScaleType.Fit
        LXLogo.Transparency = 1
        LXLogo.BackgroundTransparency = 1
        local Title = Instance.new("TextLabel", Main)
        Title.AnchorPoint = Vector2.new(0, 0.5)
        Title.Position = UDim2.fromScale(0.135, 0.35)
        Title.Size = UDim2.fromScale(100, 0.35)
        Title.Font = Enum.Font.SourceSans
        Title.Text = "[LOLHAX] " .. tostring(TitleText)
        Title.TextScaled = true
        Title.TextSize = 1
        Title.TextStrokeTransparency = 0.5
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Transparency = 1
        Title.BackgroundTransparency = 1
        local Description = Instance.new("TextLabel", Main)
        Description.AnchorPoint = Vector2.new(0, 0.5)
        Description.Position = UDim2.fromScale(0.135, 0.667)
        Description.Size = UDim2.fromScale(100, 0.29)
        Description.Font = Enum.Font.SourceSans
        Description.Text = tostring(SubText)
        Description.TextScaled = true
        Description.TextSize = 1
        Description.TextStrokeTransparency = 0.5
        Description.TextXAlignment = Enum.TextXAlignment.Left
        Description.Transparency = 1
        Description.BackgroundTransparency = 1
        local Number = math.max(Title.TextBounds.X, Description.TextBounds.X) * 1.125
        local FinalOffset = math.clamp(Number - 265, 0, 9e9)
        Main.Size += UDim2.fromOffset(FinalOffset, 0)
        if Toggles and Toggles.GN_NotificationSound and Toggles.GN_NotificationSound.Value then
            local Sound = Instance.new("Sound", game.CoreGui)
            Sound.SoundId = "rbxassetid://3318713980"
            Sound.Volume = (Options and Options.GN_NotificationSound_Volume and Options.GN_NotificationSound_Volume.Value) or 2
            Sound.PlayOnRemove = true
            Sound:Destroy()
        end
        local Timer = Duration or (10 / 3)
        local LockColor = RunService.RenderStepped:Connect(function()
            MainColor = NOTIFY_MAIN_COLOR
            Main.BackgroundColor3 = NOTIFY_BG_COLOR
            Main.BorderColor3 = MainColor:Lerp(Color3.new(0, 0, 0), 0.4)
            Line.BackgroundColor3 = MainColor
            LXLogo.ImageColor3 = MainColor
            Title.TextColor3 = MainColor
            Title.TextStrokeColor3 = MainColor:Lerp(Color3.new(0, 0, 0), 0.8)
            Description.TextColor3 = MainColor:Lerp(Color3.new(0, 0, 0), 0.15)
            Description.TextStrokeColor3 = MainColor:Lerp(Color3.new(0, 0, 0), 0.8)
        end)
        local Info = TweenInfo.new(4 / 3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        TweenService:Create(Main, Info, {Position = UDim2.fromScale(0.5, 0.6 + Offset)}):Play()
        TweenService:Create(Main, Info, {Transparency = 0.35}):Play()
        TweenService:Create(Line, Info, {Transparency = 0}):Play()
        TweenService:Create(LXLogo, Info, {ImageTransparency = 0}):Play()
        TweenService:Create(Title, Info, {TextTransparency = 0}):Play()
        TweenService:Create(Description, Info, {TextTransparency = 0}):Play()
        Line:TweenSize(UDim2.fromScale(1, 0.03), "Out", "Linear", Timer)
        task.delay(Timer + 0.1, function()
            local Info2 = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            local MainTween = TweenService:Create(Main, Info2, {Position = UDim2.fromScale(0.5, 0.525)})
            MainTween:Play()
            TweenService:Create(Main, Info2, {Transparency = 1}):Play()
            TweenService:Create(Line, Info2, {Transparency = 1}):Play()
            TweenService:Create(LXLogo, Info2, {ImageTransparency = 1}):Play()
            TweenService:Create(Title, Info2, {TextTransparency = 1}):Play()
            TweenService:Create(Description, Info2, {TextTransparency = 1}):Play()
            STATE.GlobalOffset -= 0.05 * DPISize
            MainTween.Completed:Once(function()
                LockColor:Disconnect()
                Main:Destroy()
            end)
        end)
    end
end)
--============================================================
-- CHARACTER
--============================================================
STATE.Character = nil
STATE.HumanoidRootPart = nil
STATE.Humanoid = nil
task.spawn(function()
    STATE.Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    STATE.HumanoidRootPart = STATE.Character:WaitForChild("HumanoidRootPart")
    STATE.Humanoid = STATE.Character:WaitForChild("Humanoid")
end)
--============================================================
-- FLOOR / GAME DATA
--============================================================
local GameData = ReplicatedStorage:FindFirstChild("GameData")
local FloorValue = GameData and GameData:FindFirstChild("Floor")
local LatestRoom = GameData and GameData:FindFirstChild("LatestRoom")
local function IsOldFloor()
    if not FloorValue then return false end
    local val = FloorValue.Value
    return val == "Fools" or val == "OldHotel"
end
local function GetFloorName()
    if not FloorValue then return "?" end
    return FloorValue.Value or "?"
end
local function FloorHasEyes()
    local f = GetFloorName()
    return f == "Backdoor" or f == "Hotel" or f == "OldHotel" or f == "Retro"
end
local function FloorHasDupe()
    local f = GetFloorName()
    return f == "Hotel" or f == "OldHotel" or f == "Retro" or f == "Backdoor" or f == "Rooms"
end
local function IsOutdoors()
    local f = GetFloorName()
    return f == "Outdoors" or f == "TheOutdoors" or f:lower():find("outdoor")
end
--============================================================
-- LIVE MODIFIERS
--============================================================
local LiveModifiers = ReplicatedStorage:FindFirstChild("LiveModifiers")
--============================================================
-- WORLD WATCHER  (единый оптимизированный мониторинг Workspace.DescendantAdded)
--============================================================
-- Раньше каждая функция вешала СВОЙ Workspace.DescendantAdded и на КАЖДЫЙ новый объект
-- создавала task.defer / task.delay. Когда подгружается большая комната (тысячи объектов),
-- за один кадр создавались тысячи потоков -> сильный лаг.
-- Теперь:
--  * одно подключение DescendantAdded, которое только кладёт объект в очередь (почти бесплатно);
--  * если ни одна функция не включена, объекты вообще не попадают в очередь;
--  * очередь разбирается в Heartbeat с лимитом времени на кадр (Budget), поэтому большая
--    комната обрабатывается за несколько кадров без фризов;
--  * объект обрабатывается не раньше, чем через Delay сек после появления (успевают
--    подгрузиться дочерние части модели) — вместо отдельного task.delay на каждый объект;
--  * при ВКЛЮЧЕНИИ функции запускается полный скан уже существующих объектов
--    (Watcher.Scan, тоже по бюджету), а не только ожидание новых объектов.
local Watcher = {
    Handlers = {},       -- name -> handler
    Order = {},          -- обработчики в порядке регистрации
    AnyActive = false,
    Queue = {}, Times = {}, Head = 1, Tail = 0,
    Delay = 0.2,         -- задержка перед обработкой нового объекта
    Budget = 0.0025,     -- сек на кадр для очереди новых объектов
    ScanBudget = 0.002,  -- сек на кадр для полного скана
    ScanGen = {},
}
do
    local function HandlerEnabled(h)
        local ok, on = pcall(h.IsEnabled)
        return (ok and on) and true or false
    end
    local function RunHandler(h, obj)
        if h.Filter(obj) then h.Handle(obj) end
    end
    -- Пересчитать, какие обработчики сейчас активны
    function Watcher.Refresh()
        local any = false
        for _, h in ipairs(Watcher.Order) do
            h.Active = HandlerEnabled(h)
            if h.Active then any = true end
        end
        Watcher.AnyActive = any
        if not any then
            -- никому не нужно: очищаем очередь, чтобы не держать ссылки на объекты
            Watcher.Queue, Watcher.Times = {}, {}
            Watcher.Head, Watcher.Tail = 1, 0
        end
        return any
    end
    -- def = { IsEnabled = fn() -> bool, Filter = fn(obj) -> bool (дешёвая проверка), Handle = fn(obj) }
    function Watcher.Register(name, def)
        def.Name = name
        def.Active = false
        local old = Watcher.Handlers[name]
        if old then
            for i, h in ipairs(Watcher.Order) do
                if h == old then Watcher.Order[i] = def break end
            end
        else
            table.insert(Watcher.Order, def)
        end
        Watcher.Handlers[name] = def
        Watcher.Refresh()
        return def
    end
    local function Dispatch(obj)
        if not obj.Parent then return end
        for _, h in ipairs(Watcher.Order) do
            if h.Active then
                local ok, err = pcall(RunHandler, h, obj)
                if not ok and STATE.AutoInteractDebug then
                    warn("[LOLHAX] watcher '" .. tostring(h.Name) .. "':", err)
                end
            end
        end
    end
    -- Полный скан уже существующих объектов для одного обработчика.
    -- Идёт по детям Workspace по очереди и делит работу на кадры, чтобы не было фриза.
    -- Повторный вызов для того же обработчика отменяет предыдущий скан.
    function Watcher.Scan(name, roots)
        local h = Watcher.Handlers[name]
        if not h then return end
        Watcher.Refresh()
        if not HandlerEnabled(h) then return end
        Watcher.ScanGen[name] = (Watcher.ScanGen[name] or 0) + 1
        local gen = Watcher.ScanGen[name]
        task.spawn(function()
            local rootList = roots or Workspace:GetChildren()
            local start = os.clock()
            local function Step()
                if os.clock() - start > Watcher.ScanBudget then
                    RunService.Heartbeat:Wait()
                    start = os.clock()
                    if Watcher.ScanGen[name] ~= gen or Library.Unloaded or not HandlerEnabled(h) then return false end
                end
                return true
            end
            for _, root in ipairs(rootList) do
                if Watcher.ScanGen[name] ~= gen or Library.Unloaded then return end
                if root and root.Parent then
                    pcall(RunHandler, h, root)
                    local okD, desc = pcall(function() return root:GetDescendants() end)
                    if okD then
                        for i = 1, #desc do
                            local obj = desc[i]
                            if obj.Parent then pcall(RunHandler, h, obj) end
                            if i % 64 == 0 and not Step() then return end
                        end
                    end
                end
                if not Step() then return end
            end
        end)
    end
    -- Скан всего для всех активных обработчиков
    function Watcher.ScanAll()
        Watcher.Refresh()
        for _, h in ipairs(Watcher.Order) do
            if h.Active then Watcher.Scan(h.Name) end
        end
    end
    -- Единственное подключение DescendantAdded: только запись в очередь
    TrackConnection(Workspace.DescendantAdded:Connect(function(obj)
        if not Watcher.AnyActive then return end
        local t = Watcher.Tail + 1
        Watcher.Tail = t
        Watcher.Queue[t] = obj
        Watcher.Times[t] = os.clock()
    end))
    -- Разбор очереди с лимитом времени на кадр
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Watcher.Head > Watcher.Tail then return end
        if Library.Unloaded then return end
        local start = os.clock()
        local q, tm = Watcher.Queue, Watcher.Times
        local head = Watcher.Head
        local delay, budget = Watcher.Delay, Watcher.Budget
        local n = 0
        while head <= Watcher.Tail do
            local stamp = tm[head]
            if stamp and start - stamp < delay then break end
            local obj = q[head]
            q[head] = nil
            tm[head] = nil
            head += 1
            if obj then Dispatch(obj) end
            n += 1
            if n % 16 == 0 and os.clock() - start > budget then break end
        end
        Watcher.Head = head
        if head > Watcher.Tail then
            Watcher.Head, Watcher.Tail = 1, 0
        end
    end))
    -- Периодически обновляем флаги активности (если тумблер переключили без Refresh)
    task.spawn(function()
        while not Library.Unloaded do
            task.wait(0.5)
            pcall(Watcher.Refresh)
        end
    end)
end
--============================================================
-- FULLBRIGHT / NO FOG
--============================================================
local ApplyFullbrightLock, RemoveFullbrightLock, EnforceFullbright,
      ApplyNoFogLock, RemoveNoFogLock
local Locks, OldFog, OldFogEnd, OldGlobalShadows, OldOutdoorAmbient, Atmosphere
task.spawn(function()
    Atmosphere = Lighting:FindFirstChildWhichIsA("Atmosphere")
    OldFog = Atmosphere and Atmosphere.Density or 0
    OldFogEnd = Lighting.FogEnd
    OldGlobalShadows = Lighting.GlobalShadows
    OldOutdoorAmbient = Lighting.OutdoorAmbient
    Locks = {
        Fullbright = { conns = {}, active = false, targetAmbient = nil },
        NoFog      = { conns = {}, active = false },
    }
    local function ClearLock(lock)
        for _, c in ipairs(lock.conns) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(lock.conns)
        lock.active = false
    end
    EnforceFullbright = function()
        if not Locks.Fullbright.active then return end
        if Library.Unloaded then return end
        if Lighting.GlobalShadows ~= false then Lighting.GlobalShadows = false end
        local target = Locks.Fullbright.targetAmbient or (Options and Options.VW_Ambience_C.Value)
        if target and Lighting.OutdoorAmbient ~= target then Lighting.OutdoorAmbient = target end
    end
    ApplyFullbrightLock = function()
        ClearLock(Locks.Fullbright)
        Locks.Fullbright.active = true
        Locks.Fullbright.targetAmbient = Options and Options.VW_Ambience_C.Value
        EnforceFullbright()
        table.insert(Locks.Fullbright.conns, TrackConnection(Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(EnforceFullbright)))
        table.insert(Locks.Fullbright.conns, TrackConnection(Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(EnforceFullbright)))
        table.insert(Locks.Fullbright.conns, TrackConnection(Lighting:GetPropertyChangedSignal("Ambient"):Connect(EnforceFullbright)))
        table.insert(Locks.Fullbright.conns, TrackConnection(RunService.Heartbeat:Connect(function()
            if Library.Unloaded then return end
            if not Locks.Fullbright.active then return end
            if Lighting.GlobalShadows ~= false then Lighting.GlobalShadows = false end
            local target = Locks.Fullbright.targetAmbient
            if target and Lighting.OutdoorAmbient ~= target then Lighting.OutdoorAmbient = target end
        end)))
    end
    RemoveFullbrightLock = function() ClearLock(Locks.Fullbright) end
    local function EnforceNoFog()
        if not Locks.NoFog.active then return end
        if Library.Unloaded then return end
        if Lighting.FogEnd ~= 9999 then Lighting.FogEnd = 9999 end
        if Atmosphere and Atmosphere.Density ~= 0 then Atmosphere.Density = 0 end
        if Lighting.FogStart ~= 0 then Lighting.FogStart = 0 end
    end
    ApplyNoFogLock = function()
        ClearLock(Locks.NoFog)
        Locks.NoFog.active = true
        EnforceNoFog()
        table.insert(Locks.NoFog.conns, TrackConnection(Lighting:GetPropertyChangedSignal("FogEnd"):Connect(EnforceNoFog)))
        table.insert(Locks.NoFog.conns, TrackConnection(Lighting:GetPropertyChangedSignal("FogStart"):Connect(EnforceNoFog)))
        if Atmosphere then
            table.insert(Locks.NoFog.conns, TrackConnection(Atmosphere:GetPropertyChangedSignal("Density"):Connect(EnforceNoFog)))
        end
        table.insert(Locks.NoFog.conns, TrackConnection(RunService.Heartbeat:Connect(function()
            if Library.Unloaded then return end
            if not Locks.NoFog.active then return end
            if Lighting.FogEnd ~= 9999 then Lighting.FogEnd = 9999 end
            if Lighting.FogStart ~= 0 then Lighting.FogStart = 0 end
            if Atmosphere and Atmosphere.Density ~= 0 then Atmosphere.Density = 0 end
        end)))
    end
    RemoveNoFogLock = function() ClearLock(Locks.NoFog) end
end)
--============================================================
-- FAKE EVENTS
--============================================================
local FakeEvents = { Registry = {} }
local function SwapRemoteObject(remote, enabled)
    if not remote then return false end
    local key = remote:GetFullName()
    local entry = FakeEvents.Registry[key]
    if not entry then
        entry = { fake = nil, real = nil, active = false, parent = remote.Parent, origName = remote.Name }
        FakeEvents.Registry[key] = entry
    end
    if enabled then
        if entry.active then return true end
        entry.real = remote
        local fake = Instance.new(remote.ClassName)
        fake.Name = remote.Name
        fake.Parent = remote.Parent
        entry.fake = fake
        entry.active = true
        remote.Name = remote.Name .. "_Disabled"
        remote.Parent = nil
        return true
    else
        if entry.fake then pcall(function() entry.fake:Destroy() end) entry.fake = nil end
        if entry.real then
            pcall(function()
                entry.real.Name = entry.origName
                entry.real.Parent = entry.parent
            end)
        end
        entry.active = false
        return true
    end
end
--============================================================
-- MONSTER HIGHLIGHT
--============================================================
local MonsterHighlight = { Enabled = false }
local AddMonsterHighlight, RemoveMonsterHighlight
local StartMonsterHighlight, StopMonsterHighlight
task.spawn(function()
    AddMonsterHighlight = function(obj)
        if not obj or not obj.Parent then return end
        if STATE.HighlightRegistry[obj] then return end
        local specificName, specificColor = GetSpecificEntityType(obj)
        local monsterName = IsMonsterEntity(obj)
        local fillColor = specificColor or Color3.fromRGB(255, 0, 0)
        local outlineColor = specificColor and specificColor:Lerp(Color3.new(1,1,1), 0.3) or Color3.fromRGB(255, 255, 0)
        local tagText
        if specificName then
            tagText = "[ENTITY] " .. specificName
        elseif monsterName then
            tagText = "[MONSTER] " .. monsterName
        else
            tagText = "[MONSTER] " .. obj.Name
        end
        local tagColor = specificColor or Color3.fromRGB(255, 60, 60)
        local hl = Instance.new("Highlight")
        hl.Name = "_LOLHAX_MonsterHL"
        hl.FillColor = fillColor
        hl.OutlineColor = outlineColor
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = obj
        hl.Parent = obj
        local bb = Instance.new("BillboardGui")
        bb.Name = "_LOLHAX_MonsterTag"
        bb.Size = UDim2.new(0, 220, 0, 50)
        bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = obj
        bb.Parent = obj
        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = tagText
        txt.TextColor3 = tagColor
        txt.TextStrokeTransparency = 0
        txt.TextScaled = true
        txt.Font = Enum.Font.GothamBold
        txt.Parent = bb
        STATE.HighlightRegistry[obj] = { hl = hl, bb = bb }
    end
    RemoveMonsterHighlight = function(obj)
        local entry = STATE.HighlightRegistry[obj]
        if not entry then return end
        if entry.hl then pcall(function() entry.hl:Destroy() end) end
        if entry.bb then pcall(function() entry.bb:Destroy() end) end
        STATE.HighlightRegistry[obj] = nil
    end
    -- мониторинг новых объектов через общий Watcher (без task.defer на каждый объект)
    Watcher.Register("MonsterHighlight", {
        IsEnabled = function() return MonsterHighlight.Enabled end,
        Filter = function(obj) return IsArchiveMonster(obj) end,
        Handle = function(obj)
            if obj.Parent and MonsterHighlight.Enabled then AddMonsterHighlight(obj) end
        end,
    })
    TrackConnection(Workspace.DescendantRemoving:Connect(function(obj)
        RemoveMonsterHighlight(obj)
        STATE.NameCache[obj] = nil
        STATE.MonsterCache[obj] = nil
        STATE.SpecificCache[obj] = nil
    end))
    StartMonsterHighlight = function()
        MonsterHighlight.Enabled = true
        -- сразу сканируем уже существующие объекты, а не только ждём новые
        Watcher.Scan("MonsterHighlight")
        print("[LOLHAX] Monster Highlight: ON")
    end
    StopMonsterHighlight = function()
        MonsterHighlight.Enabled = false
        Watcher.Refresh()
        for obj, _ in pairs(STATE.HighlightRegistry) do
            RemoveMonsterHighlight(obj)
        end
        STATE.HighlightRegistry = {}
        print("[LOLHAX] Monster Highlight: OFF")
    end
end)
--============================================================
-- LOTUS PETAL HIGHLIGHT
--============================================================
local LotusPetalHighlight = { Enabled = false }
local AddLotusPetalHighlight, RemoveLotusPetalHighlight
local StartLotusPetalHighlight, StopLotusPetalHighlight
task.spawn(function()
    AddLotusPetalHighlight = function(obj)
        if not obj or not obj.Parent then return end
        if STATE.PetalRegistry[obj] then return end
        local hl = Instance.new("Highlight")
        hl.Name = "_LOLHAX_PetalHL"
        hl.FillColor = Color3.fromRGB(255, 105, 180)
        hl.OutlineColor = Color3.fromRGB(255, 255, 0)
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = obj
        hl.Parent = obj
        local bb = Instance.new("BillboardGui")
        bb.Name = "_LOLHAX_PetalTag"
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = obj
        bb.Parent = obj
        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = "🌸 LOTUS PETAL"
        txt.TextColor3 = Color3.fromRGB(255, 105, 180)
        txt.TextStrokeTransparency = 0
        txt.TextScaled = true
        txt.Font = Enum.Font.GothamBold
        txt.Parent = bb
        STATE.PetalRegistry[obj] = { hl = hl, bb = bb }
    end
    RemoveLotusPetalHighlight = function(obj)
        local entry = STATE.PetalRegistry[obj]
        if not entry then return end
        if entry.hl then pcall(function() entry.hl:Destroy() end) end
        if entry.bb then pcall(function() entry.bb:Destroy() end) end
        STATE.PetalRegistry[obj] = nil
    end
    Watcher.Register("LotusPetalHighlight", {
        IsEnabled = function() return LotusPetalHighlight.Enabled end,
        Filter = function(obj) return IsLotusPetal(obj) end,
        Handle = function(obj)
            if obj.Parent and LotusPetalHighlight.Enabled then AddLotusPetalHighlight(obj) end
        end,
    })
    TrackConnection(Workspace.DescendantRemoving:Connect(function(obj)
        RemoveLotusPetalHighlight(obj)
    end))
    StartLotusPetalHighlight = function()
        LotusPetalHighlight.Enabled = true
        -- полный скан по бюджету (без фриза на больших картах)
        Watcher.Scan("LotusPetalHighlight")
        print("[LOLHAX] Lotus Petal Highlight: ON")
    end
    StopLotusPetalHighlight = function()
        LotusPetalHighlight.Enabled = false
        Watcher.Refresh()
        for obj, _ in pairs(STATE.PetalRegistry) do
            RemoveLotusPetalHighlight(obj)
        end
        STATE.PetalRegistry = {}
        print("[LOLHAX] Lotus Petal Highlight: OFF")
    end
end)
--============================================================
-- DISABLER
--============================================================
local Disabler = { Enabled = false, Disabled = false, Conn1 = nil, Conn2 = nil, Conn3 = nil, Hook = nil, OnUnlock = nil }
local StartDisabler, StopDisabler
task.spawn(function()
    local function InstallLadderDisabler()
        local char = LocalPlayer.Character
        if not char then return end
        if Disabler.Conn1 then pcall(function() Disabler.Conn1:Disconnect() end) end
        Disabler.Conn1 = char:GetAttributeChangedSignal("Climbing"):Connect(function()
            if not Disabler.Enabled then return end
            if char:GetAttribute("Climbing") == true and not Disabler.Disabled then
                task.wait(0.25)
                char:SetAttribute("Climbing", false)
                Notify("Ladder Disabler active.", "Interact with a ladder to re-disable after cutscene.", 6)
                Disabler.Disabled = true
            end
        end)
        TrackConnection(Disabler.Conn1)
    end
    local function GetSeatComponents(seat)
        if not seat then return nil, nil end
        local seatModel = seat.Parent and seat.Parent:IsA("Model") and seat.Parent or seat
        local collider = seatModel:FindFirstChild("Collider", true) or seatModel:FindFirstChild("Collider")
        local seatAttachment
        if collider then
            seatAttachment = collider:FindFirstChild("SeatAttachment") or collider:FindFirstChildWhichIsA("Attachment", true)
        end
        if not seatAttachment then seatAttachment = seatModel:FindFirstChild("SeatAttachment", true) end
        if not collider and seatAttachment then collider = seatAttachment.Parent end
        return collider, seatAttachment
    end
    local function FireSeatControl(seat)
        if not seat then return end
        local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
        if not rf then return end
        local seatRemote = rf:FindFirstChild("SeatControl")
        if not seatRemote then return end
        local collider, seatAttachment = GetSeatComponents(seat)
        if collider and seatAttachment then
            pcall(function() seatRemote:FireServer(collider, seatAttachment, {}) end)
        elseif collider then
            pcall(function() seatRemote:FireServer(collider, nil, {}) end)
        end
    end
    local function FireCartControl(seat)
        if not seat then return end
        local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
        if not rf then return end
        local cartRemote = rf:FindFirstChild("CartControl")
        if not cartRemote then return end
        pcall(function() cartRemote:FireServer(seat, {}, Vector3.zero, 0) end)
    end
    local function InstallChairDisabler()
        local char = LocalPlayer.Character
        if not char then return end
        if STATE.ChairState.Conn1 then pcall(function() STATE.ChairState.Conn1:Disconnect() end) end
        if STATE.ChairState.Conn2 then pcall(function() STATE.ChairState.Conn2:Disconnect() end) end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            STATE.ChairState.Conn1 = hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
                if not Disabler.Enabled then return end
                if STATE.DisablerMode ~= "Chair" then return end
                local seat = hum.SeatPart
                if seat then
                    STATE.ChairState.Frozen = true
                    STATE.ChairState.LastSeat = tick()
                    STATE.ChairState.SeatPart = seat
                    Notify("Chair Disabler active.", "Seated state frozen. Anti-cheat bypassed.", 6)
                    FireSeatControl(seat)
                    FireCartControl(seat)
                else
                    STATE.ChairState.Frozen = false
                    STATE.ChairState.SeatPart = nil
                end
            end)
        end
        STATE.ChairState.Conn2 = RunService.Heartbeat:Connect(function()
            if not Disabler.Enabled or STATE.DisablerMode ~= "Chair" then return end
            if not STATE.ChairState.Frozen then return end
            local c = LocalPlayer.Character
            if not c then return end
            local h = c:FindFirstChildOfClass("Humanoid")
            if not h then return end
            if not h.SeatPart and STATE.ChairState.SeatPart then
                if STATE.ChairState.SeatPart.Parent then
                    pcall(function() h.Sit = true end)
                else
                    STATE.ChairState.Frozen = false
                    STATE.ChairState.SeatPart = nil
                end
            end
            if tick() - STATE.ChairState.LastSeat > 1.5 then
                STATE.ChairState.LastSeat = tick()
                if STATE.ChairState.SeatPart then
                    FireSeatControl(STATE.ChairState.SeatPart)
                    FireCartControl(STATE.ChairState.SeatPart)
                end
            end
        end)
        TrackConnection(STATE.ChairState.Conn1)
        TrackConnection(STATE.ChairState.Conn2)
    end
    local function UninstallChairDisabler()
        if STATE.ChairState.Conn1 then pcall(function() STATE.ChairState.Conn1:Disconnect() end) STATE.ChairState.Conn1 = nil end
        if STATE.ChairState.Conn2 then pcall(function() STATE.ChairState.Conn2:Disconnect() end) STATE.ChairState.Conn2 = nil end
        STATE.ChairState.Frozen = false
        STATE.ChairState.SeatPart = nil
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.SeatPart then pcall(function() hum.Sit = false end) end
        end
    end
    local function InstallCutsceneDetector()
        local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
        if not rf then return end
        local cutscene = rf:FindFirstChild("Cutscene")
        if not cutscene then return end
        if Disabler.Conn2 then pcall(function() Disabler.Conn2:Disconnect() end) end
        Disabler.Conn2 = cutscene.OnClientEvent:Connect(function(CutsceneName)
            if not Disabler.Enabled then return end
            if Disabler.Disabled and not tostring(CutsceneName):find("SewerSeek") then
                Disabler.Disabled = false
                Notify("Disabler re-enabled.", "Interact with a ladder/chair to disable again.", 6)
            end
        end)
        TrackConnection(Disabler.Conn2)
    end
    local function InstallEnemyModuleDetector()
        local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
        if not rf then return end
        local useEnemy = rf:FindFirstChild("UseEnemyModule")
        if not useEnemy then return end
        if Disabler.Conn3 then pcall(function() Disabler.Conn3:Disconnect() end) end
        Disabler.Conn3 = useEnemy.OnClientEvent:Connect(function(ModuleName)
            if not Disabler.Enabled then return end
            if ModuleName == "Void" or ModuleName == "Glitch" then
                if Disabler.Disabled then
                    Disabler.Disabled = false
                    Notify("Disabler re-enabled.", "Interact with a ladder/chair to disable again.", 6)
                end
                if LatestRoom then LocalPlayer:SetAttribute("CurrentRoom", LatestRoom.Value) end
            end
        end)
        TrackConnection(Disabler.Conn3)
    end
    local function InstallNamecallHook()
        if not hookmetamethod or not newcclosure or not getnamecallmethod then return end
        if Disabler.Hook then return end
        local original
        original = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }
            if Disabler.Enabled then
                if (self.Name == "ClutchHeartbeat" or self.Name == "HideMonster") and method == "FireServer" then
                    if Toggles.AHB_Enabled and Toggles.AHB_Enabled.Value then return end
                end
                if self.Name == "MotorReplication" and method == "FireServer" then
                    local doBypass = (Toggles.ES_AntiEyes and Toggles.ES_AntiEyes.Value) or (Toggles.ES_AntiLookman and Toggles.ES_AntiLookman.Value)
                    if doBypass then args[1] = -650 end
                end
            end
            return original(self, table.unpack(args))
        end))
        Disabler.Hook = original
    end
    local function UninstallNamecallHook()
        if Disabler.Hook then
            pcall(function() hookmetamethod(game, "__namecall", Disabler.Hook) end)
            Disabler.Hook = nil
        end
    end
    StartDisabler = function()
        Disabler.Enabled = true
        if STATE.DisablerMode == "Ladder" then InstallLadderDisabler() else InstallChairDisabler() end
        InstallCutsceneDetector()
        InstallEnemyModuleDetector()
        InstallNamecallHook()
        print("[LOLHAX] Disabler: ON | Mode =", STATE.DisablerMode)
        if Disabler.OnUnlock then Disabler.OnUnlock(true) end
    end
    StopDisabler = function()
        Disabler.Enabled = false
        if Disabler.Conn1 then pcall(function() Disabler.Conn1:Disconnect() end) Disabler.Conn1 = nil end
        if Disabler.Conn2 then pcall(function() Disabler.Conn2:Disconnect() end) Disabler.Conn2 = nil end
        if Disabler.Conn3 then pcall(function() Disabler.Conn3:Disconnect() end) Disabler.Conn3 = nil end
        UninstallChairDisabler()
        UninstallNamecallHook()
        if Disabler.Disabled then
            Disabler.Disabled = false
            local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
            if rf and rf:FindFirstChild("ClimbLadder") then pcall(function() rf.ClimbLadder:FireServer() end) end
        end
        print("[LOLHAX] Disabler: OFF")
        if Disabler.OnUnlock then Disabler.OnUnlock(false) end
    end
end)
--============================================================
-- FLY
--============================================================
local Fly = {
    Enabled = false, Unlocked = false, Speed = 50, MaxSpeed = 50,
    BodyVelocity = nil, BodyGyro = nil, Connection = nil,
    Ctrl = {f = 0, b = 0, l = 0, r = 0}, LastCtrl = {f = 0, b = 0, l = 0, r = 0}, CurSpeed = 0,
}
local StartFly, StopFly
task.spawn(function()
    local function GetFlyBodyPart()
        local char = LocalPlayer.Character
        if not char then return nil end
        if char:FindFirstChild("UpperTorso") then return char.UpperTorso end
        if char:FindFirstChild("Torso") then return char.Torso end
        return char:FindFirstChild("HumanoidRootPart")
    end
    local function CreateFlyBody()
        local char = LocalPlayer.Character
        if not char then return end
        local body = GetFlyBodyPart()
        if not body then return end
        if Fly.BodyVelocity then Fly.BodyVelocity:Destroy() end
        if Fly.BodyGyro then Fly.BodyGyro:Destroy() end
        Fly.BodyVelocity = Instance.new("BodyVelocity")
        Fly.BodyVelocity.Name = "_LOLHAX_FlyVel"
        Fly.BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        Fly.BodyVelocity.Velocity = Vector3.zero
        Fly.BodyVelocity.Parent = body
        Fly.BodyGyro = Instance.new("BodyGyro")
        Fly.BodyGyro.Name = "_LOLHAX_FlyGyro"
        Fly.BodyGyro.P = 9e4
        Fly.BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        Fly.BodyGyro.CFrame = body.CFrame
        Fly.BodyGyro.Parent = body
    end
    local function UpdateFlyInput()
        local ctrl = {f = 0, b = 0, l = 0, r = 0}
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then ctrl.f = 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then ctrl.b = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then ctrl.l = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then ctrl.r = 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then ctrl.f = ctrl.f + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then ctrl.b = ctrl.b - 1 end
        Fly.Ctrl = ctrl
    end
    StartFly = function()
        if Fly.Enabled then return end
        if not Fly.Unlocked then
            Notify("Fly is locked!", "Enable Disabler first to unlock Fly.", 5)
            return
        end
        Fly.Enabled = true
        Fly.MaxSpeed = Fly.Speed
        Fly.CurSpeed = 0
        Fly.Ctrl = {f = 0, b = 0, l = 0, r = 0}
        Fly.LastCtrl = {f = 0, b = 0, l = 0, r = 0}
        local char = LocalPlayer.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.PlatformStand = true end
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = true end
        CreateFlyBody()
        Fly.Connection = RunService.RenderStepped:Connect(function()
            if not Fly.Enabled then return end
            local c = LocalPlayer.Character
            if not c then return end
            local body = GetFlyBodyPart()
            if not body then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            if not Fly.BodyVelocity or not Fly.BodyVelocity.Parent then CreateFlyBody() end
            UpdateFlyInput()
            local ctrl = Fly.Ctrl
            if ctrl.l + ctrl.r ~= 0 or ctrl.f + ctrl.b ~= 0 then
                Fly.CurSpeed = Fly.CurSpeed + 0.5 + (Fly.CurSpeed / Fly.MaxSpeed)
                if Fly.CurSpeed > Fly.MaxSpeed then Fly.CurSpeed = Fly.MaxSpeed end
            elseif Fly.CurSpeed ~= 0 then
                Fly.CurSpeed = Fly.CurSpeed - 1
                if Fly.CurSpeed < 0 then Fly.CurSpeed = 0 end
            end
            local cam = Workspace.CurrentCamera
            if not cam then return end
            if (ctrl.l + ctrl.r) ~= 0 or (ctrl.f + ctrl.b) ~= 0 then
                Fly.BodyVelocity.Velocity = ((cam.CFrame.LookVector * (ctrl.f + ctrl.b)) + ((cam.CFrame * CFrame.new(ctrl.l + ctrl.r, (ctrl.f + ctrl.b) * 0.2, 0).p) - cam.CFrame.p)) * Fly.CurSpeed
                Fly.LastCtrl = {f = ctrl.f, b = ctrl.b, l = ctrl.l, r = ctrl.r}
            elseif (ctrl.l + ctrl.r) == 0 and (ctrl.f + ctrl.b) == 0 and Fly.CurSpeed ~= 0 then
                Fly.BodyVelocity.Velocity = ((cam.CFrame.LookVector * (Fly.LastCtrl.f + Fly.LastCtrl.b)) + ((cam.CFrame * CFrame.new(Fly.LastCtrl.l + Fly.LastCtrl.r, (Fly.LastCtrl.f + Fly.LastCtrl.b) * 0.2, 0).p) - cam.CFrame.p)) * Fly.CurSpeed
            else
                Fly.BodyVelocity.Velocity = Vector3.zero
            end
            Fly.BodyGyro.CFrame = cam.CFrame * CFrame.Angles(-math.rad((ctrl.f + ctrl.b) * 50 * Fly.CurSpeed / Fly.MaxSpeed), 0, 0)
        end)
        TrackConnection(Fly.Connection)
    end
    StopFly = function()
        if not Fly.Enabled then return end
        Fly.Enabled = false
        if Fly.Connection then Fly.Connection:Disconnect() Fly.Connection = nil end
        if Fly.BodyVelocity then Fly.BodyVelocity:Destroy() Fly.BodyVelocity = nil end
        if Fly.BodyGyro then Fly.BodyGyro:Destroy() Fly.BodyGyro = nil end
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.PlatformStand = false end
            local animate = char:FindFirstChild("Animate")
            if animate then animate.Disabled = false end
        end
        Fly.CurSpeed = 0
    end
end)
--============================================================
-- NOCLIP
--============================================================
local Noclip = { Enabled = false, Unlocked = false, Connection = nil, Clip = true, FloatName = "HumanoidRootPart" }
local StartNoclip, StopNoclip
task.spawn(function()
    local function NoclipLoop()
        if Noclip.Clip == false and LocalPlayer.Character ~= nil then
            for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                if v:IsA('BasePart') and v.CanCollide and v.Name ~= Noclip.FloatName then
                    v.CanCollide = false
                end
            end
        end
        task.wait(0.21)
    end
    StartNoclip = function()
        if Noclip.Enabled then return end
        if not Noclip.Unlocked then
            Notify("Noclip is locked!", "Enable Disabler first to unlock Noclip.", 5)
            return
        end
        Noclip.Enabled = true
        Noclip.Clip = false
        Noclip.Connection = RunService.Stepped:Connect(NoclipLoop)
        TrackConnection(Noclip.Connection)
    end
    StopNoclip = function()
        if not Noclip.Enabled then return end
        Noclip.Enabled = false
        Noclip.Clip = true
        if Noclip.Connection then Noclip.Connection:Disconnect() Noclip.Connection = nil end
    end
    TrackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if Library.Unloaded then return end
        if input.KeyCode == Enum.KeyCode.O then
            if not Noclip.Unlocked then
                Notify("Noclip is locked!", "Enable Disabler first to unlock Noclip.", 5)
                return
            end
            if Noclip.Enabled then StopNoclip() Notify("Noclip OFF", "Collision restored.", 3)
            else StartNoclip() Notify("Noclip ON", "You can pass through walls.", 3) end
        end
    end))
end)
--============================================================
-- UNLOCK CALLBACK
--============================================================
local function SetToggleTitle(t, text)
    if not t then return end
    -- в разных версиях Fluent SetTitle вызывается либо через ":", либо через "."
    local ok = pcall(function() t:SetTitle(text) end)
    if not ok then pcall(function() t.SetTitle(text) end) end
end
Disabler.OnUnlock = function(unlocked)
    Fly.Unlocked = unlocked
    Noclip.Unlocked = unlocked
    if not unlocked then
        if Fly.Enabled then StopFly() end
        if Noclip.Enabled then StopNoclip() end
    end
    task.spawn(function()
        local lockIcon   = unlocked and "◆ " or "🔒 "
        local lockStatus = unlocked and "  ◆ UNLOCKED" or "  🔒 LOCKED"
        pcall(function() SetToggleTitle(Toggles.FLY_Enabled,    lockIcon .. "Fly" .. lockStatus) end)
        pcall(function() SetToggleTitle(Toggles.NOCLIP_Enabled, lockIcon .. "Noclip (bind O)" .. lockStatus) end)
    end)
end
--============================================================
-- [ABYSALL] SPEED BOOST
--============================================================
local SpeedBoostState = { Enabled = false, Connection = nil }
local StartSpeedBoostAbysall, StopSpeedBoostAbysall
task.spawn(function()
    local GameData = ReplicatedStorage:WaitForChild("GameData")
    local Floor = GameData:WaitForChild("Floor").Value
    local LiveModifiers = ReplicatedStorage:FindFirstChild("LiveModifiers")
    if not LiveModifiers then
        LiveModifiers = Instance.new("Folder")
        LiveModifiers.Name = "LiveModifiers"
        LiveModifiers.Parent = ReplicatedStorage
    end
    local function IsCrouching()
        if Floor == "Fools" or Floor == "OldHotel" then
            return LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Crouching")
        end
        local cp = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("CollisionPart") or LocalPlayer.Character:FindFirstChild("Collision"))
        if cp then return cp.CollisionGroup == "PlayerCrouching" end
        return LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Crouching")
    end
    local function GetInjuriesSpeed()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return 0 end
        return 0.075 * (hum.MaxHealth - hum.Health)
    end
    -- Точная копия Functions.GetCurrentSpeed из Abysall
    local function GetCurrentSpeed()
        local char = LocalPlayer.Character
        if not char then return 15 end
        local Speed = 15
        Speed += char:GetAttribute("SpeedBoost") or 0
        Speed += char:GetAttribute("SpeedBoostBehind") or 0
        Speed += char:GetAttribute("SpeedBoostExtra") or 0
        Speed += (Floor == "Party" and 10 or 0)
        Speed += (LiveModifiers:FindFirstChild("PlayerFast") and 3 or 0)
        Speed += (LiveModifiers:FindFirstChild("PlayerFaster") and 6 or 0)
        Speed += (LiveModifiers:FindFirstChild("PlayerFastest") and 20 or 0)
        Speed -= (LiveModifiers:FindFirstChild("PlayerSlow") and 3 or 0)
        Speed -= (LiveModifiers:FindFirstChild("PlayerSlowHealth") and GetInjuriesSpeed() or 0)
        if IsCrouching() then
            if LiveModifiers:FindFirstChild("PlayerCrouchSlow") then
                Speed -= 8
            elseif LiveModifiers:FindFirstChild("PlayerSlow") then
                Speed -= 8
            else
                Speed -= 5
            end
        end
        return Speed
    end
    StartSpeedBoostAbysall = function()
        if SpeedBoostState.Enabled then return end
        SpeedBoostState.Enabled = true
        STATE.SpeedBoostValue = Options.MY_SpeedBoost_Slider and Options.MY_SpeedBoost_Slider.Value or 0
        local char = LocalPlayer.Character
        if char then
            char:SetAttribute("SpeedBoost", 0)
            char:SetAttribute("SpeedBoostBehind", 0)
            char:SetAttribute("SpeedBoostExtra", 0)
        end
        SpeedBoostState.Connection = RunService.RenderStepped:Connect(function()
            if Library.Unloaded or not SpeedBoostState.Enabled then return end
            local character = LocalPlayer.Character
            if not character then return end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then return end
            humanoid.WalkSpeed = GetCurrentSpeed() + (STATE.SpeedBoostValue or 0)
        end)
        TrackConnection(SpeedBoostState.Connection)
    end
    StopSpeedBoostAbysall = function()
        if not SpeedBoostState.Enabled then return end
        SpeedBoostState.Enabled = false
        if SpeedBoostState.Connection then
            SpeedBoostState.Connection:Disconnect()
            SpeedBoostState.Connection = nil
        end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = GetCurrentSpeed() end
    end
end)
--============================================================
-- REMOVE ACCELERATION
--============================================================
local RemoveAccelState = {
    Enabled = false,
    PartProperties = {},
    CustomPhysics = nil,
    DescConn = nil,
    CharConn = nil,
}
local StartRemoveAcceleration, StopRemoveAcceleration
task.spawn(function()
    local function BuildCustomPhysics(rootPart)
        local old = rootPart.CustomPhysicalProperties
        if not old then
            old = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
        end
        return PhysicalProperties.new(100, old.Friction, old.Elasticity, old.FrictionWeight, old.ElasticityWeight)
    end
    local function CaptureAndApply(character)
        if not character then return end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        RemoveAccelState.CustomPhysics = BuildCustomPhysics(rootPart)
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if not RemoveAccelState.PartProperties[part] then
                    RemoveAccelState.PartProperties[part] = part.CustomPhysicalProperties
                end
                pcall(function()
                    part.CustomPhysicalProperties = RemoveAccelState.CustomPhysics
                end)
            end
        end
    end
    local function RestoreAll()
        for part, oldPhysics in pairs(RemoveAccelState.PartProperties) do
            if part and part.Parent then
                pcall(function() part.CustomPhysicalProperties = oldPhysics end)
            end
        end
        RemoveAccelState.PartProperties = {}
        RemoveAccelState.CustomPhysics = nil
    end
    -- ОПТИМИЗАЦИЯ: раньше слушался весь Workspace.DescendantAdded (каждая деталь новой комнаты
    -- проверялась через IsDescendantOf). Теперь слушаем только своего персонажа.
    local function HookCharacterParts(character)
        if RemoveAccelState.DescConn then
            pcall(function() RemoveAccelState.DescConn:Disconnect() end)
            RemoveAccelState.DescConn = nil
        end
        if not character then return end
        RemoveAccelState.DescConn = character.DescendantAdded:Connect(function(obj)
            if not RemoveAccelState.Enabled then return end
            if obj:IsA("BasePart") then
                if not RemoveAccelState.PartProperties[obj] then
                    RemoveAccelState.PartProperties[obj] = obj.CustomPhysicalProperties
                end
                if RemoveAccelState.CustomPhysics then
                    pcall(function() obj.CustomPhysicalProperties = RemoveAccelState.CustomPhysics end)
                end
            end
        end)
        TrackConnection(RemoveAccelState.DescConn)
    end
    StartRemoveAcceleration = function()
        if RemoveAccelState.Enabled then return end
        RemoveAccelState.Enabled = true
        CaptureAndApply(LocalPlayer.Character)
        HookCharacterParts(LocalPlayer.Character)
        RemoveAccelState.CharConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
            if not RemoveAccelState.Enabled then return end
            task.wait(0.5)
            if not RemoveAccelState.Enabled then return end
            HookCharacterParts(newChar)
            CaptureAndApply(newChar)
        end)
        TrackConnection(RemoveAccelState.CharConn)
        print("[LOLHAX] Remove Acceleration: ON")
    end
    StopRemoveAcceleration = function()
        if not RemoveAccelState.Enabled then return end
        RemoveAccelState.Enabled = false
        if RemoveAccelState.DescConn then
            pcall(function() RemoveAccelState.DescConn:Disconnect() end)
            RemoveAccelState.DescConn = nil
        end
        if RemoveAccelState.CharConn then
            pcall(function() RemoveAccelState.CharConn:Disconnect() end)
            RemoveAccelState.CharConn = nil
        end
        RestoreAll()
        print("[LOLHAX] Remove Acceleration: OFF")
    end
end)
--============================================================
-- ANTI EYES / ANTI LOOKMAN
--============================================================
local AntiEyes = { Enabled = false }
local AntiLookman = { Enabled = false }
local StartAntiEyes, StopAntiEyes, StartAntiLookman, StopAntiLookman
task.spawn(function()
    local function FireMotorReplicationSpoof()
        local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
        if not rf then return end
        local motor = rf:FindFirstChild("MotorReplication")
        if not motor then return end
        SafeCall(function() motor:FireServer(-650) end)
    end
    TrackConnection(RunService.RenderStepped:Connect(function()
        if Library.Unloaded then return end
        local char = LocalPlayer.Character
        if not char then return end
        if char:GetAttribute("Hiding") then return end
        if not char:FindFirstChild("HumanoidRootPart") then return end
        if AntiEyes.Enabled and Toggles.ES_AntiEyes and Toggles.ES_AntiEyes.Value then
            local eyes = Workspace:FindFirstChild("Eyes")
            if eyes and eyes:FindFirstChild("Core") and eyes.Core:FindFirstChild("Ambience") and eyes.Core.Ambience.Playing then
                FireMotorReplicationSpoof()
            end
        end
        if AntiLookman.Enabled and Toggles.ES_AntiLookman and Toggles.ES_AntiLookman.Value then
            local lookman = Workspace:FindFirstChild("BackdoorLookman")
            if lookman and lookman:FindFirstChild("Core") and lookman.Core:FindFirstChild("Ambience") and lookman.Core.Ambience.Playing then
                FireMotorReplicationSpoof()
            end
        end
    end))
    StartAntiEyes = function() AntiEyes.Enabled = true end
    StopAntiEyes = function() AntiEyes.Enabled = false end
    StartAntiLookman = function() AntiLookman.Enabled = true end
    StopAntiLookman = function() AntiLookman.Enabled = false end
end)
--============================================================
-- [ABYSALL] NO SCREECH DAMAGE
--============================================================
local NoScreechState = { Enabled = false, Real = nil, Fake = nil, ModuleDisabled = false }
local EnableNoScreechDamage, DisableNoScreechDamage
task.spawn(function()
    local RemotesFolder = ReplicatedStorage:FindFirstChild("RemotesFolder")
    if not RemotesFolder then
        RemotesFolder = ReplicatedStorage:WaitForChild("RemotesFolder", 30)
    end
    if not RemotesFolder then
        warn("[LOLHAX] RemotesFolder not found — NoScreechDamage disabled")
        return
    end
    local function CreateFakeScreech()
        if NoScreechState.Fake then return NoScreechState.Fake end
        local fake = Instance.new("RemoteEvent")
        fake.Name = "Screech"
        NoScreechState.Fake = fake
        return fake
    end
    local function GetRealScreech()
        if NoScreechState.Real and NoScreechState.Real.Parent then
            return NoScreechState.Real
        end
        local real = RemotesFolder:FindFirstChild("Screech")
            or RemotesFolder:FindFirstChild("Screech_Disabled")
        if real then
            NoScreechState.Real = real
        end
        return real
    end
    local function GetScreechModule()
        local mc = ReplicatedStorage:FindFirstChild("ModulesClient")
            or ReplicatedStorage:FindFirstChild("ClientModules")
        if not mc then return nil end
        local em = mc:FindFirstChild("EntityModules")
        if not em then return nil end
        return em:FindFirstChild("Screech")
            or em:FindFirstChild("Screech_Disabled")
            or em:FindFirstChild("GlitchScreech")
            or em:FindFirstChild("GlitchScreech_Disabled")
    end
    EnableNoScreechDamage = function()
        if NoScreechState.Enabled then return end
        NoScreechState.Enabled = true
        local real = GetRealScreech()
        if not real then
            warn("[LOLHAX] NoScreechDamage: real Screech remote not found")
            NoScreechState.Enabled = false
            return
        end
        local fake = CreateFakeScreech()
        fake.Parent = RemotesFolder
        real.Name = "Screech_Disabled"
        real.Parent = nil
        local mod = GetScreechModule()
        if mod then
            if not mod:GetAttribute("OriginalName") then
                mod:SetAttribute("OriginalName", mod.Name)
            end
            if mod.Name ~= "Screech_Disabled" then
                mod.Name = "Screech_Disabled"
            end
            NoScreechState.ModuleDisabled = true
        end
        for _, v in ipairs(Workspace:GetChildren()) do
            if v.Name == "Screech" then pcall(function() v:Destroy() end) end
        end
        local cam = Workspace.CurrentCamera
        if cam then
            for _, v in ipairs(cam:GetChildren()) do
                if v.Name == "Screech" then pcall(function() v:Destroy() end) end
            end
        end
        print("[LOLHAX] No Screech Damage: ON")
    end
    DisableNoScreechDamage = function()
        if not NoScreechState.Enabled then return end
        NoScreechState.Enabled = false
        local real = GetRealScreech()
        if real then
            real.Name = "Screech"
            real.Parent = RemotesFolder
        end
        if NoScreechState.Fake then
            pcall(function() NoScreechState.Fake:Destroy() end)
            NoScreechState.Fake = nil
        end
        local mod = GetScreechModule()
        if mod then
            local orig = mod:GetAttribute("OriginalName") or "Screech"
            if mod.Name ~= orig then mod.Name = orig end
        end
        NoScreechState.ModuleDisabled = false
        print("[LOLHAX] No Screech Damage: OFF")
    end
end)
--============================================================
-- ANTI RANSOM
--============================================================
local RansomOverlay = { Enabled = false, Conn1 = nil, Conn2 = nil }
local RansomDamage = { Enabled = false, BlockedObjects = {}, Conn1 = nil, Conn2 = nil, LoopTask = nil, WipeLoopTask = nil }
local StartRansomOverlayRemover, StopRansomOverlayRemover
local StartRansomDamageBlocker, StopRansomDamageBlocker
task.spawn(function()
    local function KillRansomVignette()
        local cam = Workspace.CurrentCamera
        if cam then
            for _, v in ipairs(cam:GetChildren()) do
                if v.Name == "RansomVignette" then pcall(function() v:Destroy() end) end
            end
        end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, v in ipairs(pg:GetChildren()) do
                if v.Name == "RansomVignette" then pcall(function() v:Destroy() end) end
            end
        end
    end
    StartRansomOverlayRemover = function()
        RansomOverlay.Enabled = true
        KillRansomVignette()
        local cam = Workspace.CurrentCamera
        if cam then
            RansomOverlay.Conn1 = cam.ChildAdded:Connect(function(child)
                if not RansomOverlay.Enabled then return end
                if child.Name == "RansomVignette" then
                    task.defer(function() if child and child.Parent then pcall(function() child:Destroy() end) end end)
                end
            end)
            TrackConnection(RansomOverlay.Conn1)
        end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            RansomOverlay.Conn2 = pg.DescendantAdded:Connect(function(child)
                if not RansomOverlay.Enabled then return end
                if child.Name == "RansomVignette" then
                    task.defer(function() if child and child.Parent then pcall(function() child:Destroy() end) end end)
                end
            end)
            TrackConnection(RansomOverlay.Conn2)
        end
    end
    StopRansomOverlayRemover = function()
        RansomOverlay.Enabled = false
        if RansomOverlay.Conn1 then pcall(function() RansomOverlay.Conn1:Disconnect() end) RansomOverlay.Conn1 = nil end
        if RansomOverlay.Conn2 then pcall(function() RansomOverlay.Conn2:Disconnect() end) RansomOverlay.Conn2 = nil end
    end
    local function IsRansomAttack(name)
        local lower = name:lower()
        return lower:find("ransomattack") or lower:find("noransomdamage")
            or lower:find("no ransom damage") or lower:find("no_ransom_damage") or lower:find("noransom")
    end
    local function WipeNoRansomDamage()
        for _, obj in ipairs(Workspace:GetChildren()) do
            local n = obj.Name:lower()
            if n:find("no.?ransom.?damage") or n:find("noransomdamage") then
                pcall(function() obj:Destroy() end)
            end
        end
    end
    local function BlockOneRemote(remote)
        if not remote or not remote.Parent then return false end
        if not IsRansomAttack(remote.Name) then return false end
        local fullName = remote:GetFullName()
        if RansomDamage.BlockedObjects[fullName] then return false end
        local ok = SwapRemoteObject(remote, true)
        if ok then
            RansomDamage.BlockedObjects[fullName] = true
            return true
        end
        return false
    end
    local function BlockWSRansomChildren(wsRansom)
        if not wsRansom then wsRansom = Workspace:FindFirstChild("Ransom") end
        if not wsRansom then return end
        for _, v in ipairs(wsRansom:GetChildren()) do
            if v:IsA("RemoteEvent") or v:IsA("BindableEvent") or v:IsA("RemoteFunction") or v:IsA("BindableFunction") then
                BlockOneRemote(v)
            end
        end
    end
    local function HookWSRansom(wsRansom)
        if not wsRansom then return end
        BlockWSRansomChildren(wsRansom)
        if RansomDamage.Conn1 then pcall(function() RansomDamage.Conn1:Disconnect() end) end
        RansomDamage.Conn1 = wsRansom.ChildAdded:Connect(function(child)
            if not RansomDamage.Enabled then return end
            if child:IsA("RemoteEvent") or child:IsA("BindableEvent") or child:IsA("RemoteFunction") or child:IsA("BindableFunction") then
                task.defer(function() if child and child.Parent then BlockOneRemote(child) end end)
            end
        end)
        TrackConnection(RansomDamage.Conn1)
    end
    StartRansomDamageBlocker = function()
        RansomDamage.Enabled = true
        WipeNoRansomDamage()
        BlockWSRansomChildren()
        local existing = Workspace:FindFirstChild("Ransom")
        if existing then HookWSRansom(existing) end
        if RansomDamage.Conn2 then pcall(function() RansomDamage.Conn2:Disconnect() end) end
        RansomDamage.Conn2 = Workspace.ChildAdded:Connect(function(child)
            if not RansomDamage.Enabled then return end
            if child.Name == "Ransom" then
                task.defer(function() if RansomDamage.Enabled then HookWSRansom(child) end end)
            end
        end)
        TrackConnection(RansomDamage.Conn2)
        if RansomDamage.LoopTask then task.cancel(RansomDamage.LoopTask) end
        RansomDamage.LoopTask = task.spawn(function()
            while RansomDamage.Enabled and not Library.Unloaded do
                task.wait(0.3)
                if not RansomDamage.Enabled then break end
                local wsRansom = Workspace:FindFirstChild("Ransom")
                if wsRansom then BlockWSRansomChildren(wsRansom) end
            end
        end)
        if RansomDamage.WipeLoopTask then task.cancel(RansomDamage.WipeLoopTask) end
        RansomDamage.WipeLoopTask = task.spawn(function()
            while RansomDamage.Enabled and not Library.Unloaded do
                task.wait(1)
                if not RansomDamage.Enabled then break end
                WipeNoRansomDamage()
            end
        end)
    end
    StopRansomDamageBlocker = function()
        RansomDamage.Enabled = false
        if RansomDamage.Conn1 then pcall(function() RansomDamage.Conn1:Disconnect() end) RansomDamage.Conn1 = nil end
        if RansomDamage.Conn2 then pcall(function() RansomDamage.Conn2:Disconnect() end) RansomDamage.Conn2 = nil end
        if RansomDamage.LoopTask then pcall(function() task.cancel(RansomDamage.LoopTask) end) RansomDamage.LoopTask = nil end
        if RansomDamage.WipeLoopTask then pcall(function() task.cancel(RansomDamage.WipeLoopTask) end) RansomDamage.WipeLoopTask = nil end
        for fullName, _ in pairs(RansomDamage.BlockedObjects) do
            local entry = FakeEvents.Registry[fullName]
            if entry and entry.real then SwapRemoteObject(entry.real, false) end
        end
        RansomDamage.BlockedObjects = {}
    end
end)
--============================================================
-- DROP / CROUCH
--============================================================
local DROP_REMOTE = nil
do
    local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
    if rf then
        for _, name in ipairs({ "DropItem", "Drop", "DropTool", "ItemDrop", "DropItemRemote" }) do
            local r = rf:FindFirstChild(name)
            if r and r:IsA("RemoteEvent") then DROP_REMOTE = r break end
        end
    end
end
local CrouchRemote
do
    local rf = ReplicatedStorage:WaitForChild("RemotesFolder", 10)
    if rf then CrouchRemote = rf:WaitForChild("Crouch", 10) end
end
local function isCrouching()
    local c = LocalPlayer.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    if c:GetAttribute("Crouching") == true then return true end
    if c:GetAttribute("IsCrouching") == true then return true end
    if h.WalkSpeed <= 8 then return true end
    return false
end
--============================================================
-- MANIPULATION
--============================================================
local function getRandomFarPosition(center)
    local angle = math.random() * 2 * math.pi
    local distance = 1000000
    return center + Vector3.new(math.cos(angle) * distance, math.random(-500, 500), math.sin(angle) * distance)
end
local function startManipulationLoop()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local savedPosition = root.Position
    while STATE.States.manip and root and root.Parent do
        local farPos = getRandomFarPosition(savedPosition)
        root.CFrame = CFrame.new(farPos)
        root.Velocity = Vector3.new(0, 0, 0)
        task.wait(0.00001)
        if not STATE.States.manip then break end
        root.CFrame = CFrame.new(savedPosition)
        root.Velocity = Vector3.new(0, 0, 0)
        task.wait(0.00001)
    end
end
--============================================================
-- AIR LOCK
--============================================================
local function setAirLockState(state)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    STATE.States.airlock = state
    if state then
        local newY = root.Position.Y + STATE.FLY_HEIGHT
        root.CFrame = CFrame.new(root.Position.X, newY, root.Position.Z) * (root.CFrame - root.CFrame.Position)
        STATE.lockedY = newY
    end
end
TrackConnection(RunService.RenderStepped:Connect(function()
    if not STATE.States.airlock then return end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local position = root.Position
    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
    if math.abs(position.Y - STATE.lockedY) > 0.05 then
        root.CFrame = CFrame.new(position.X, STATE.lockedY, position.Z) * (root.CFrame - root.CFrame.Position)
    end
end))
--============================================================
-- FOV
--============================================================
local function ApplyFOV()
    if Library.Unloaded then return end
    if not Options or not Options.MY_FOV then return end
    local v = Options.MY_FOV.Value
    if v and v >= 70 then Camera.FieldOfView = v end
end
RunService:BindToRenderStep("LOLHAX_FOV", Enum.RenderPriority.Camera.Value - 1, ApplyFOV)
--============================================================
-- THIRD PERSON
--============================================================
local ThirdPerson = { Enabled = false, WallCheck = false, ShowHead = true, Offset = Vector3.new(1.5, 1, 5) }
-- держатель "спрятанных" частей тела в третьем лице (голова и аксессуары)
local ThirdPersonHidden = {}
-- снапшот оригинальных значений видимости головы за текущую сессию ThirdPerson
local ThirdPersonSession = nil
local function RestoreThirdPersonSession()
    if not ThirdPersonSession then return end
    -- восстанавливаем ТОЧНО ТЕ ЖЕ instance, которые были захвачены при старте сессии
    -- (не ищем через LocalPlayer.Character — он может быть уже заменён после респауна)
    local s = ThirdPersonSession
    if s.head and s.head.Parent then
        pcall(function()
            s.head.LocalTransparencyModifier = s.headLtm or 0
            s.head.Transparency = s.headTr or 0
            if s.face and s.face.Parent and s.faceTr ~= nil then
                s.face.Transparency = s.faceTr
            end
        end)
    end
    for handle, props in pairs(s.accessories or {}) do
        if handle and handle.Parent then
            pcall(function()
                if props.ltm ~= nil then handle.LocalTransparencyModifier = props.ltm end
                if props.tr ~= nil then handle.Transparency = props.tr end
            end)
        end
    end
    ThirdPersonSession = nil
end
local function RestoreThirdPersonHead()
    for inst, props in pairs(ThirdPersonHidden) do
        if inst and inst.Parent then
            pcall(function()
                if props.ltm ~= nil then inst.LocalTransparencyModifier = props.ltm end
                if props.tr ~= nil then inst.Transparency = props.tr end
            end)
        end
    end
    table.clear(ThirdPersonHidden)
end
local function HideThirdPersonHead(char)
    local head = char and char:FindFirstChild("Head")
    if head then
        if not ThirdPersonHidden[head] then
            ThirdPersonHidden[head] = { ltm = head.LocalTransparencyModifier, tr = head.Transparency }
        end
        head.LocalTransparencyModifier = 1
        head.Transparency = 1
    end
    -- волосы / шляпы / всё, что на голове
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle") or acc:FindFirstChildWhichIsA("BasePart", true)
            if handle and handle:IsA("BasePart") then
                if not ThirdPersonHidden[handle] then
                    ThirdPersonHidden[handle] = { ltm = handle.LocalTransparencyModifier, tr = handle.Transparency }
                end
                handle.LocalTransparencyModifier = 1
                handle.Transparency = 1
            end
        end
    end
    local face = head and head:FindFirstChild("face")
    if face and face:IsA("Decal") then
        if not ThirdPersonHidden[face] then ThirdPersonHidden[face] = { tr = face.Transparency } end
        face.Transparency = 1
    end
end
task.spawn(function()
    local ThirdPersonRayParams = RaycastParams.new()
    ThirdPersonRayParams.FilterType = Enum.RaycastFilterType.Exclude
    -- BindToRenderStep с приоритетом AFTER Camera, чтобы голова и камера
    -- обновлялись синхронно (без дерганья при быстром повороте камеры).
    local conn = nil
    local bindOk = pcall(function()
        RunService:BindToRenderStep("_LOLHAX_ThirdPerson", Enum.RenderPriority.Camera.Value + 1, function()
            if Library.Unloaded or not ThirdPerson.Enabled then
                if next(ThirdPersonHidden) ~= nil then RestoreThirdPersonHead() end
                RestoreThirdPersonSession()
                return
            end
            local char = LocalPlayer.Character
            if not char then return end
            local head = char:FindFirstChild("Head")
            if not head then return end
            local cam = Workspace.CurrentCamera
            if not cam then return end
        if ThirdPerson.ShowHead then
            -- ФИКС "нет башки": Roblox сам прячет голову через LocalTransparencyModifier
            -- когда камера приближается. Мы сохраняем оригинальные значения ОДИН РАЗ за сессию
            -- (ThirdPersonSession), жёстко возвращаем видимость каждый кадр,
            -- и восстанавливаем только при выключении ThirdPerson.
            if not ThirdPersonSession then
                -- сохраняем ССЫЛКИ на instance (не текущий character), чтобы
                -- восстановление работало корректно даже после respawn
                ThirdPersonSession = {
                    head = head,
                    face = head:FindFirstChild("face") and head.face:IsA("Decal") and head.face or nil,
                    headLtm = head.LocalTransparencyModifier,
                    headTr = head.Transparency,
                    faceTr = (head:FindFirstChild("face") and head.face:IsA("Decal")) and head.face.Transparency or nil,
                    accessories = {},
                }
                -- только ГОЛОВНЫЕ аксессуары (проверяем через Weld/Attachment к Head)
                for _, acc in ipairs(char:GetChildren()) do
                    if acc:IsA("Accessory") then
                        local handle = acc:FindFirstChild("Handle") or acc:FindFirstChildWhichIsA("BasePart", true)
                        if handle and handle:IsA("BasePart") then
                            -- ПРОВЕРКА: handle приварен к Head через Weld или Attachment
                            local isHeadAcc = false
                            for _, child in ipairs(handle:GetChildren()) do
                                if child:IsA("Attachment") then
                                    local attParent = child.Parent
                                    -- Attachment может быть на handle, но ссылается на Head attachment
                                    if child.Name:find("HatAttachment") or child.Name:find("HairAttachment") or child.Name:find("FaceFrontAttachment") or child.Name:find("FaceCenterAttachment") then
                                        isHeadAcc = true
                                    end
                                end
                            end
                            -- проверяем Weld к Head
                            for _, w in ipairs(acc:GetChildren()) do
                                if w:IsA("Weld") and w.Part1 == head then isHeadAcc = true end
                                if w:IsA("Weld") and w.Part0 == head then isHeadAcc = true end
                            end
                            if isHeadAcc then
                                ThirdPersonSession.accessories[handle] = {
                                    ltm = handle.LocalTransparencyModifier,
                                    tr = handle.Transparency,
                                }
                            end
                        end
                    end
                end
            end
            head.LocalTransparencyModifier = 0
            head.Transparency = 0
            if head:FindFirstChild("face") and head.face:IsA("Decal") then
                head.face.Transparency = 0
            end
            for handle, _ in pairs(ThirdPersonSession.accessories) do
                if handle and handle.Parent then
                    handle.LocalTransparencyModifier = 0
                    handle.Transparency = 0
                end
            end
        else
            HideThirdPersonHead(char)
        end
        ThirdPersonRayParams.FilterDescendantsInstances = { char }
        local offset = CFrame.new(ThirdPerson.Offset)
        local desiredPos = (cam.CFrame * offset).Position
        local direction = desiredPos - cam.CFrame.Position
        if ThirdPerson.WallCheck then
            local result = Workspace:Spherecast(cam.CFrame.Position, 0.2, direction, ThirdPersonRayParams)
            if result and result.Instance and result.Instance.CanCollide then
                local newPos = cam.CFrame.Position + direction.Unit * (result.Distance - 0.1)
                cam.CFrame = CFrame.new(newPos, newPos + cam.CFrame.LookVector)
                return
            end
        end
        cam.CFrame = cam.CFrame * offset
        end)
        conn = true -- флаг, что рендер-степ подключён
    end)
    if not conn then
        -- fallback: обычный RenderStepped (если BindToRenderStep недоступен)
        TrackConnection(RunService.RenderStepped:Connect(function()
            if Library.Unloaded or not ThirdPerson.Enabled then
                if next(ThirdPersonHidden) ~= nil then RestoreThirdPersonHead() end
                RestoreThirdPersonSession()
                return
            end
            local char = LocalPlayer.Character
            if not char then return end
            local head = char:FindFirstChild("Head")
            if not head then return end
            local cam = Workspace.CurrentCamera
            if not cam then return end
            if ThirdPerson.ShowHead then
                if next(ThirdPersonHidden) ~= nil then RestoreThirdPersonHead() end
                if not ThirdPersonSession then
                    -- снапшот (как выше)
                    ThirdPersonSession = {
                        head = head,
                        face = head:FindFirstChild("face") and head.face:IsA("Decal") and head.face or nil,
                        headLtm = head.LocalTransparencyModifier,
                        headTr = head.Transparency,
                        faceTr = (head:FindFirstChild("face") and head.face:IsA("Decal")) and head.face.Transparency or nil,
                        accessories = {},
                    }
                end
                head.LocalTransparencyModifier = 0
                head.Transparency = 0
                if head:FindFirstChild("face") and head.face:IsA("Decal") then
                    head.face.Transparency = 0
                end
            else
                HideThirdPersonHead(char)
            end
            ThirdPersonRayParams.FilterDescendantsInstances = { char }
            local offset = CFrame.new(ThirdPerson.Offset)
            local desiredPos = (cam.CFrame * offset).Position
            local direction = desiredPos - cam.CFrame.Position
            if ThirdPerson.WallCheck then
                local result = Workspace:Spherecast(cam.CFrame.Position, 0.2, direction, ThirdPersonRayParams)
                if result and result.Instance and result.Instance.CanCollide then
                    local newPos = cam.CFrame.Position + direction.Unit * (result.Distance - 0.1)
                    cam.CFrame = CFrame.new(newPos, newPos + cam.CFrame.LookVector)
                    return
                end
            end
            cam.CFrame = cam.CFrame * offset
        end))
    end
end)
--============================================================
-- NO SHAKING
--============================================================
local NoShaking = { Enabled = false }
task.spawn(function()
    local function IsInCutscene()
        local cutsceneAttr = LocalPlayer:GetAttribute("Cutscene")
        if cutsceneAttr ~= nil and cutsceneAttr ~= false then return true end
        local char = LocalPlayer.Character
        if char then
            local charCutscene = char:GetAttribute("Cutscene")
            if charCutscene ~= nil and charCutscene ~= false then return true end
        end
        if Camera and Camera.CameraType == Enum.CameraType.Scriptable then return true end
        return false
    end
    TrackConnection(RunService.RenderStepped:Connect(function()
        if Library.Unloaded or not NoShaking.Enabled then return end
        if IsInCutscene() then return end
        local char = LocalPlayer.Character
        if not char or char:GetAttribute("Hiding") then return end
        local cam = Workspace.CurrentCamera
        if not cam or cam.CameraType ~= Enum.CameraType.Custom then return end
        local head = char:FindFirstChild("Head")
        if not head then return end
        if (cam.CFrame.Position - head.Position).Magnitude > 5 then
            cam.CFrame = cam.CFrame:Lerp(CFrame.new(head.Position, head.Position + cam.CFrame.LookVector), 0.15)
        end
    end))
end)
--============================================================
-- REMOVE HALT
--============================================================
local SetHaltDisabled, SetHaltDamageBlocked
task.spawn(function()
    local function FindShadeModule()
        local mc = ReplicatedStorage:FindFirstChild("ModulesClient") or ReplicatedStorage:FindFirstChild("ClientModules")
        if not mc then return nil end
        local em = mc:FindFirstChild("EntityModules")
        if not em then return nil end
        return em:FindFirstChild("Shade") or em:FindFirstChild("Shade_Disabled")
    end
    SetHaltDisabled = function(State)
        local module = FindShadeModule()
        if not module then return end
        if State then
            if not module:GetAttribute("OriginalName") then module:SetAttribute("OriginalName", module.Name) end
            if module.Name ~= "Shade_Disabled" then module.Name = "Shade_Disabled" end
        else
            local orig = module:GetAttribute("OriginalName")
            if orig and module.Name ~= orig then module.Name = orig end
        end
    end
    SetHaltDamageBlocked = function(State)
        SwapRemoteObject(ReplicatedStorage:FindFirstChild("ShadeResult"), State)
    end
    TrackConnection(ReplicatedStorage.DescendantAdded:Connect(function(v)
        if Library.Unloaded then return end
        if v.Name == "Shade" and v:IsA("ModuleScript") then
            task.wait(0.1)
            if Toggles.ER_RemoveHalt and Toggles.ER_RemoveHalt.Value then SetHaltDisabled(true) end
            if Toggles.ER_NoHaltDamage and Toggles.ER_NoHaltDamage.Value then SetHaltDamageBlocked(true) end
        end
    end))
end)
--============================================================
-- INSTANT INTERACT
--============================================================
local InstantInteract = { Enabled = false, Connection = nil }
local StartInstantInteract
task.spawn(function()
    StartInstantInteract = function()
        if InstantInteract.Connection then InstantInteract.Connection:Disconnect() end
        InstantInteract.Connection = ProximityPromptService.PromptShown:Connect(function(prompt)
            if not InstantInteract.Enabled then return end
            if not STATE.GameReady then return end
            if not prompt or not prompt.Parent then return end
            local n = prompt.Name
            if n:find("Achievement") or n:find("Badge") or n:find("Trophy") or n:find("Cutscene") then return end
            if not prompt:GetAttribute("LOLHAX_OrigHold") then
                prompt:SetAttribute("LOLHAX_OrigHold", prompt.HoldDuration)
            end
            prompt.HoldDuration = 0
        end)
        TrackConnection(InstantInteract.Connection)
    end
end)
--============================================================
-- INFINITE ITEMS
--============================================================
local InfiniteItems = { Enabled = false, List = {}, FakePrompts = {}, Container = nil, LastTrigger = 0 }
local InstallFakePrompt, ForceFirePrompt
task.spawn(function()
    local gui = Instance.new("Folder")
    gui.Name = "_LOLHAX_PromptContainer"
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    gui.Parent = parent
    InfiniteItems.Container = gui
    local function GetPickupPrompt(item)
        return item:FindFirstChild("ModulePrompt")
            or item:FindFirstChild("Prompt")
            or item:FindFirstChild("PickupPrompt")
            or item:FindFirstChildWhichIsA("ProximityPrompt", true)
    end
    InstallFakePrompt = function(original)
        if not original or not original.Parent then return end
        if original:GetAttribute("LOLHAX_Fake") then return end
        if original:GetAttribute("LOLHAX_HasFake") then return end
        if not original:IsA("ProximityPrompt") then return end
        local parentModel = original.Parent
        if not parentModel or not StaticDB.INFINITE_ITEM_NAMES[parentModel.Name] then return end
        local fake = original:Clone()
        fake:SetAttribute("LOLHAX_Fake", true)
        fake.Name = original.Name
        fake.Parent = original.Parent
        fake:SetAttribute("LOLHAX_Hold", original.HoldDuration)
        fake:SetAttribute("LOLHAX_LOS", original.RequiresLineOfSight)
        fake:SetAttribute("LOLHAX_Max", original.MaxActivationDistance)
        InfiniteItems.FakePrompts[fake] = original
        original:SetAttribute("LOLHAX_HasFake", true)
        pcall(function() original.Parent = InfiniteItems.Container end)
        local conn = original:GetPropertyChangedSignal("Enabled"):Connect(function()
            if fake and fake.Parent then fake.Enabled = original.Enabled end
        end)
        TrackConnection(conn)
        original.Destroying:Once(function()
            if fake then fake:Destroy() end
            conn:Disconnect()
        end)
        fake.Enabled = original.Enabled
    end
    Watcher.Register("InfiniteItems", {
        IsEnabled = function() return InfiniteItems.Enabled and not Library.Unloaded end,
        Filter = function(v) return v:IsA("ProximityPrompt") end,
        Handle = function(v) InstallFakePrompt(v) end,
    })
    local function AutoDropTool(tool)
        if not DROP_REMOTE or not tool or not tool.Parent then return false end
        local ok = pcall(function() DROP_REMOTE:FireServer(tool) end)
        if ok then return true end
        ok = pcall(function() DROP_REMOTE:FireServer() end)
        return ok
    end
    ForceFirePrompt = function(prompt)
        if not prompt or not prompt.Parent then return false end
        if fireproximityprompt then
            local ok = pcall(fireproximityprompt, prompt)
            if ok then return true end
        end
        local oldDist, oldEnable, oldHold, oldLOS = prompt.MaxActivationDistance, prompt.Enabled, prompt.HoldDuration, prompt.RequiresLineOfSight
        prompt.MaxActivationDistance = 99999
        prompt.Enabled = true
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        local ok = pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.05)
            prompt:InputHoldEnd()
        end)
        prompt.MaxActivationDistance = oldDist
        prompt.Enabled = oldEnable
        prompt.HoldDuration = oldHold
        prompt.RequiresLineOfSight = oldLOS
        return ok
    end
    local function HandleInfiniteUse(fakePrompt)
        if Library.Unloaded or not InfiniteItems.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool or not InfiniteItems.List[tool.Name] then return end
        local now = tick()
        if now - InfiniteItems.LastTrigger < 0.15 then return end
        InfiniteItems.LastTrigger = now
        local drops = Workspace:FindFirstChild("Drops")
        if not drops then return end
        local toolName = tool.Name
        local real = InfiniteItems.FakePrompts[fakePrompt]
        local dropHandled = false
        local dropConn
        dropConn = drops.ChildAdded:Connect(function(dropped)
            if dropHandled then return end
            if dropped.Name ~= toolName then return end
            dropHandled = true
            dropConn:Disconnect()
            local prompt2 = GetPickupPrompt(dropped)
            if prompt2 then
                task.wait(0.05); ForceFirePrompt(prompt2)
                task.wait(0.05); ForceFirePrompt(prompt2)
            end
            if real then task.wait(0.05) ForceFirePrompt(real) end
        end)
        TrackConnection(dropConn)
        task.delay(0.4, function()
            if dropHandled then return end
            if not tool or tool.Parent ~= char then return end
            AutoDropTool(tool)
        end)
        task.delay(3, function()
            if dropConn then pcall(function() dropConn:Disconnect() end) end
        end)
    end
    TrackConnection(ProximityPromptService.PromptTriggered:Connect(function(prompt)
        if Library.Unloaded or not InfiniteItems.Enabled then return end
        if not prompt:GetAttribute("LOLHAX_Fake") then return end
        HandleInfiniteUse(prompt)
    end))
end)
--============================================================
-- AUTO INTERACT
--============================================================
local AutoInteract = {
    Enabled = false,
    Options = {},
    Range = 1,
    LastFire = {},
    Cooldown = 0.05,
    PromptCache = {},
    CacheLifetime = 1.5,
    CacheVersion = 0,
}
task.spawn(function()
    local function HasItemAI(Item)
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if char and char:FindFirstChild(Item) then return char:FindFirstChild(Item) end
        if backpack and backpack:FindFirstChild(Item) then return backpack:FindFirstChild(Item) end
        return nil
    end
    local function SafeFirePromptAI(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end
        local now = tick()
        if AutoInteract.LastFire[prompt] and (now - AutoInteract.LastFire[prompt]) < AutoInteract.Cooldown then
            return false
        end
        local ok = pcall(function()
            prompt:InputHoldBegin()
            task.wait(math.min(prompt.HoldDuration, 0.05) + 0.01)
            prompt:InputHoldEnd()
        end)
        if ok then
            AutoInteract.LastFire[prompt] = tick()
            return true
        end
        return false
    end
    local function GetObjPosAI(obj)
        if not obj then return nil end
        if obj:IsA("BasePart") then return obj.Position end
        if obj:IsA("Model") then
            local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if p then return p.Position end
            local ok, pivot = pcall(function() return obj:GetPivot().Position end)
            if ok then return pivot end
        end
        return nil
    end
    local function FindAnyPromptCached(obj)
        if not obj or not obj.Parent then return nil end
        local cached = AutoInteract.PromptCache[obj]
        local now = tick()
        if cached and cached.version == AutoInteract.CacheVersion
            and (now - cached.stamp) < AutoInteract.CacheLifetime then
            for _, p in ipairs(cached.prompts) do
                if p.Parent and p.Enabled then return p end
            end
        end
        local prompts = {}
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                local n = d.Name
                if not (n:find("Achievement") or n:find("Badge") or n:find("Trophy") or n:find("Cutscene") or n:find("Hint")) then
                    table.insert(prompts, d)
                end
            end
        end
        AutoInteract.PromptCache[obj] = { prompts = prompts, stamp = now, version = AutoInteract.CacheVersion }
        if #prompts > 0 then return prompts[1] end
        return nil
    end
    local function GetPromptPos(prompt)
        if not prompt then return nil end
        local parent = prompt.Parent
        if parent and parent:IsA("BasePart") then return parent.Position end
        if parent and parent:IsA("Attachment") then return parent.WorldPosition end
        if parent and parent:IsA("Model") then
            return GetObjPosAI(parent)
        end
        return nil
    end
    local function TryInteractPrompt(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end
        local char = LocalPlayer.Character
        if not char then return false end
        local myPos = (char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position)
                   or (char:FindFirstChild("Collision") and char.Collision.Position)
        if not myPos then return false end
        local promptPos = GetPromptPos(prompt) or myPos
        local maxDist = (prompt.MaxActivationDistance or 10) * AutoInteract.Range
        if (promptPos - myPos).Magnitude >= maxDist then return false end
        return SafeFirePromptAI(prompt)
    end
    local function IsContainerAI(v)
        if not v:IsA("Model") then return false end
        local n = v.Name
        if StaticDB.CONTAINER_NAMES and StaticDB.CONTAINER_NAMES[n] then return true end
        if n:find("Drawer") or n:find("Nightstand") or n:find("Dresser")
            or n:find("Desk") or n:find("Cabinet") or n:find("Locker")
            or n:find("Chest") or n:find("Table") or n:find("Box")
            or n:find("Crate") or n:find("Shelf") or n:find("Wardrobe") then
            return true
        end
        return false
    end
    local function IsGoldAI(v)
        if not v then return false end
        local n = v.Name
        if n == "GoldPile" or n:find("Gold") or n:find("Coin") then return true end
        if v:GetAttribute("GoldValue") then return true end
        return false
    end
    local LootNames = {
        ["Glowsticks"]=true, ["GoldPile"]=true, ["Bandage"]=true, ["Candy"]=true,
        ["Battery"]=true, ["KeyObtain"]=true, ["FuseObtain"]=true,
        ["StarJug"]=true, ["Lockpick"]=true, ["StarVial"]=true,
        ["SkeletonKey"]=true, ["Crucifix"]=true, ["CrucifixWall"]=true,
        ["Flashlight"]=true, ["Candle"]=true, ["Straplight"]=true,
        ["Vitamins"]=true, ["Lighter"]=true, ["Shears"]=true,
        ["BatteryPack"]=true, ["BandagePack"]=true, ["LaserPointer"]=true,
        ["Bulklight"]=true,
    }
    local function FindLootAI(Origin)
        if not Origin then return end
        local cached = AutoInteract.PromptCache[Origin]
        local now = tick()
        local lootList
        if cached and cached.version == AutoInteract.CacheVersion
            and (now - cached.stamp) < AutoInteract.CacheLifetime and cached.lootList then
            lootList = cached.lootList
        else
            lootList = {}
            for _, d in ipairs(Origin:GetDescendants()) do
                if LootNames[d.Name] then
                    table.insert(lootList, d)
                end
            end
            if cached then
                cached.lootList = lootList
                cached.stamp = now
                cached.version = AutoInteract.CacheVersion
            else
                AutoInteract.PromptCache[Origin] = {
                    prompts = {}, stamp = now, version = AutoInteract.CacheVersion, lootList = lootList
                }
            end
        end
        for _, Loot in ipairs(lootList) do
            if not Loot.Parent then continue end
            local n = Loot.Name
            if n == "KeyObtain" and (HasItemAI("Key") or HasItemAI("KeyBackdoor")) then
                continue
            end
            local prompt = FindAnyPromptCached(Loot)
            if prompt then TryInteractPrompt(prompt) end
        end
    end
    local function ProcessRootAI(Root, char)
        local rn = Root.Name
        if rn == "Door" and Root:FindFirstChild("Lock") then
            local Item = HasItemAI("Lockpick") or HasItemAI("Key") or HasItemAI("KeyBackdoor")
            if Item then
                local prompt = Root.Lock:FindFirstChild("UnlockPrompt") or FindAnyPromptCached(Root.Lock)
                if prompt then TryInteractPrompt(prompt) end
            end
        elseif IsContainerAI(Root) then
            local prompt = FindAnyPromptCached(Root)
            if prompt then TryInteractPrompt(prompt) end
            FindLootAI(Root)
        elseif IsGoldAI(Root) then
            local prompt = FindAnyPromptCached(Root)
            if prompt then TryInteractPrompt(prompt) end
            FindLootAI(Root)
        elseif rn == "AlarmClock" then
            local prompt = FindAnyPromptCached(Root)
            if prompt then TryInteractPrompt(prompt) end
        elseif rn == "PickupItem" and not HasItemAI("LibraryHintPaper") then
            local prompt = FindAnyPromptCached(Root)
            if prompt then TryInteractPrompt(prompt) end
        elseif rn == "LiveBreakerPolePickup" then
            for _, p in ipairs(Root:GetChildren()) do
                if p:IsA("ProximityPrompt") and p.Enabled then
                    TryInteractPrompt(p)
                    break
                end
            end
        elseif rn == "Wax_Door" and HasItemAI("SkeletonKey") then
            local prompt = FindAnyPromptCached(Root)
            if prompt then TryInteractPrompt(prompt) end
        elseif rn == "Green_Herb" and not char:GetAttribute("HerbGreenEffect") then
            local prompt = FindAnyPromptCached(Root)
            if prompt then TryInteractPrompt(prompt) end
        elseif (rn == "KeyObtain" or rn == "ElectricalKeyObtain")
            and not (HasItemAI("Key") or HasItemAI("KeyBackdoor") or HasItemAI("KeyElectrical")) then
            local prompt = FindAnyPromptCached(Root)
            if prompt then TryInteractPrompt(prompt) end
        elseif rn == "LeverForGate" then
            local prompt = Root:FindFirstChild("ActivateEventPrompt") or FindAnyPromptCached(Root)
            if prompt and prompt.Enabled and not prompt:GetAttribute("Interactions") then
                TryInteractPrompt(prompt)
            end
        elseif rn == "MinesGenerator" then
            local fuse = HasItemAI("GeneratorFuse")
            if fuse and Root:FindFirstChild("Fuses") then
                for _, FuseInput in ipairs(Root.Fuses:GetChildren()) do
                    local prompt = FuseInput:FindFirstChild("FusesPrompt") or FindAnyPromptCached(FuseInput)
                    if prompt and prompt.Enabled then
                        TryInteractPrompt(prompt)
                        break
                    end
                end
            end
            if Root:FindFirstChild("Lever") then
                local prompt = Root.Lever:FindFirstChild("LeverPrompt") or FindAnyPromptCached(Root.Lever)
                if prompt and prompt.Enabled then TryInteractPrompt(prompt) end
            end
        elseif rn == "MinesGateButton" then
            if Root:FindFirstChild("Light") and Root.Light.Transparency < 1 then
                local prompt = Root:FindFirstChild("Button") and Root.Button:FindFirstChild("ActivateEventPrompt")
                if prompt and prompt.Enabled then TryInteractPrompt(prompt) end
            end
        elseif rn == "TimerLever" then
            local prompt = Root:FindFirstChild("ActivateEventPrompt") or FindAnyPromptCached(Root)
            if prompt and prompt.Enabled and not prompt:GetAttribute("Interactions") then
                TryInteractPrompt(prompt)
            end
        elseif rn == "VentGrate" then
            local prompt = Root:FindFirstChild("AwesomePrompt")
            if prompt and prompt.Enabled then TryInteractPrompt(prompt) end
        elseif rn == "Modular_Bookshelf" and Root:FindFirstChild("LiveHintBook") then
            local prompt = Root.LiveHintBook:FindFirstChild("ActivateEventPrompt") or FindAnyPromptCached(Root.LiveHintBook)
            if prompt and prompt.Enabled then TryInteractPrompt(prompt) end
        elseif rn == "RoomsLootItem" or rn == "CrucifixOnTheWall" then
            FindLootAI(Root)
        elseif StaticDB.MiscPickups[rn] then
            local prompt = FindAnyPromptCached(Root)
            if prompt then TryInteractPrompt(prompt) end
        end
    end
    local function ScanRoomAI(CurrentRoom)
        local char = LocalPlayer.Character
        if not char then return end
        local assets = CurrentRoom:FindFirstChild("Assets")
        if assets then
            for _, Root in ipairs(assets:GetChildren()) do
                pcall(ProcessRootAI, Root, char)
            end
            local blockage = assets:FindFirstChild("Blockage")
            if blockage then
                for _, Root in ipairs(blockage:GetChildren()) do
                    pcall(ProcessRootAI, Root, char)
                end
            end
            local decorFolder = assets:FindFirstChild("Decor") and assets.Decor:FindFirstChild("Folder")
            if decorFolder then
                for _, Root in ipairs(decorFolder:GetChildren()) do
                    pcall(ProcessRootAI, Root, char)
                end
            end
            local alternate = assets:FindFirstChild("Alternate")
            if alternate then
                for _, Root in ipairs(alternate:GetChildren()) do
                    pcall(ProcessRootAI, Root, char)
                end
            end
            local standardDecor = assets:FindFirstChild("StandardDecor")
            if standardDecor then
                for _, Root in ipairs(standardDecor:GetChildren()) do
                    pcall(ProcessRootAI, Root, char)
                end
            end
        end
        local sideroom = CurrentRoom:FindFirstChild("Sideroom")
        if sideroom and sideroom:IsA("Model") then
            local sAssets = sideroom:FindFirstChild("Assets")
            if sAssets then
                for _, Root in ipairs(sAssets:GetChildren()) do
                    pcall(ProcessRootAI, Root, char)
                end
                local sBlockage = sAssets:FindFirstChild("Blockage")
                if sBlockage then
                    for _, Root in ipairs(sBlockage:GetChildren()) do
                        pcall(ProcessRootAI, Root, char)
                    end
                end
                local sDecor = sAssets:FindFirstChild("Decor") and sAssets.Decor:FindFirstChild("Folder")
                if sDecor then
                    for _, Root in ipairs(sDecor:GetChildren()) do
                        pcall(ProcessRootAI, Root, char)
                    end
                end
            end
        end
        for _, v in ipairs(CurrentRoom:GetChildren()) do
            if v:IsA("Model") and v ~= sideroom then
                pcall(ProcessRootAI, v, char)
                local vAssets = v:FindFirstChild("Assets")
                if vAssets then
                    for _, Root in ipairs(vAssets:GetChildren()) do
                        pcall(ProcessRootAI, Root, char)
                    end
                end
            end
        end
        local dam = CurrentRoom:FindFirstChild("_DamHandler")
        if dam then
            for _, Flood in ipairs(dam:GetChildren()) do
                if Flood.Name:sub(1, 5) == "Flood" and Flood:FindFirstChild("Pumps") then
                    for _, WaterPump in ipairs(Flood.Pumps:GetChildren()) do
                        local wheel = WaterPump:FindFirstChild("Wheel")
                        if wheel then
                            local prompt = wheel:FindFirstChild("ValvePrompt")
                            if prompt and prompt.Enabled then TryInteractPrompt(prompt) end
                        end
                    end
                end
            end
        end
        local ed = CurrentRoom:FindFirstChild("ElectricalDoor")
        if ed and ed:FindFirstChild("Door") and ed.Door:FindFirstChild("Lock") then
            if HasItemAI("KeyElectrical") then
                local prompt = ed.Door.Lock:FindFirstChild("UnlockPrompt")
                if prompt and prompt.Enabled then TryInteractPrompt(prompt) end
            end
        end
        local rde = CurrentRoom:FindFirstChild("RoomsDoor_Entrance")
        if rde then
            local Lockpick = HasItemAI("Lockpick")
            local SkeletonKey = HasItemAI("SkeletonKey")
            if rde:FindFirstChild("Chain1") and rde.Chain1:FindFirstChild("Lock1") then
                local l1 = rde.Chain1.Lock1
                if l1:FindFirstChild("ThingToEnable") and l1.ThingToEnable.Enabled and Lockpick then
                    TryInteractPrompt(l1.ThingToEnable)
                end
            end
            if rde:FindFirstChild("Chain2") and rde.Chain2:FindFirstChild("Lock2") then
                local l2 = rde.Chain2.Lock2
                if l2:FindFirstChild("LockPrompt") and l2.LockPrompt.Enabled and Lockpick then
                    TryInteractPrompt(l2.LockPrompt)
                end
            end
            if rde:FindFirstChild("SkullLock") and rde.SkullLock:FindFirstChild("SkullPrompt") then
                if rde.SkullLock.SkullPrompt.Enabled and SkeletonKey then
                    TryInteractPrompt(rde.SkullLock.SkullPrompt)
                end
            end
            if rde:FindFirstChild("Door") and rde.Door:FindFirstChild("EnterPrompt") then
                if rde.Door.EnterPrompt.Enabled then
                    TryInteractPrompt(rde.Door.EnterPrompt)
                end
            end
        end
        local DoorExit = CurrentRoom:FindFirstChild("Backdoors_Exit") or CurrentRoom:FindFirstChild("RoomsDoor_Exit")
        if DoorExit and DoorExit:FindFirstChild("Door") and DoorExit.Door:FindFirstChild("EnterPrompt") then
            if DoorExit.Door.EnterPrompt.Enabled then
                TryInteractPrompt(DoorExit.Door.EnterPrompt)
            end
        end
        local drops = Workspace:FindFirstChild("Drops")
        if drops then FindLootAI(drops) end
    end
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded or not STATE.GameReady then return end
        if not AutoInteract.Enabled then return end
        if not Options.GA_AutoInteract_K or not Options.GA_AutoInteract_K:GetState() then return end
        -- ОПТИМИЗАЦИЯ: скан комнаты ~30 раз в секунду вместо каждого кадра
        -- (у промптов и так кулдаун 0.05 сек, поэтому скорость не падает)
        local nowClock = os.clock()
        if nowClock - (AutoInteract.LastScan or 0) < 0.033 then return end
        AutoInteract.LastScan = nowClock
        local char = LocalPlayer.Character
        if not char then return end
        if not char:FindFirstChild("Collision") then return end
        local rooms = Workspace:FindFirstChild("CurrentRooms")
        if not rooms then return end
        local roomId = LocalPlayer:GetAttribute("CurrentRoom")
        if not roomId then return end
        local CurrentRoom = rooms:FindFirstChild(tostring(roomId))
        if not CurrentRoom then return end
        pcall(ScanRoomAI, CurrentRoom)
    end))
    -- сброс кэша промптов при появлении нового ProximityPrompt (через общий Watcher и только когда функция включена)
    Watcher.Register("AutoInteractCache", {
        IsEnabled = function() return AutoInteract.Enabled end,
        Filter = function(obj) return obj:IsA("ProximityPrompt") end,
        Handle = function() AutoInteract.CacheVersion = AutoInteract.CacheVersion + 1 end,
    })
    TrackConnection(Workspace.DescendantRemoving:Connect(function(obj)
        if obj.ClassName == "ProximityPrompt" then
            AutoInteract.CacheVersion = AutoInteract.CacheVersion + 1
        end
        AutoInteract.PromptCache[obj] = nil
    end))
end)
--============================================================
-- ENTITY NOTIFIER
--============================================================
task.spawn(function()
    local NOTIFY_COOLDOWN_DEFAULT = 5
    local NOTIFY_COOLDOWN_DUPE = 30
    local NOTIFY_COOLDOWN_EYES = 15
    local NOTIFY_COOLDOWN_SPECIFIC = 10
    local NOTIFY_COOLDOWN_PETAL = 3
    local function IsRealDupe(instance)
        if instance.Name ~= "Dupe" and instance.Name ~= "DoorFake" and instance.Name ~= "FakeDoor" then return false end
        if instance:FindFirstChild("Hidden") then return true end
        if instance:FindFirstChild("LockPart") then return true end
        if instance:FindFirstChild("HiddenDoor") then return true end
        return false
    end
    local function TryNotifyEntity(instance)
        if Library.Unloaded then return end
        if not Toggles.GN_Enabled or not Toggles.GN_Enabled.Value then return end
        if not instance or not instance.Parent then return end
        if Toggles.GN_LotusPetal and Toggles.GN_LotusPetal.Value then
            if IsLotusPetal(instance) then
                local now = tick()
                if STATE.NotifyCooldown["LotusPetal"] and (now - STATE.NotifyCooldown["LotusPetal"]) < NOTIFY_COOLDOWN_PETAL then return end
                STATE.NotifyCooldown["LotusPetal"] = now
                Notify("Lotus Petal detected!", "Pink petal nearby. Collect for Lotus flower.", 5)
                return
            end
        end
        local specificName = GetSpecificEntityType(instance)
        if specificName then
            local now = tick()
            if STATE.NotifyCooldown[specificName] and (now - STATE.NotifyCooldown[specificName]) < NOTIFY_COOLDOWN_SPECIFIC then return end
            STATE.NotifyCooldown[specificName] = now
            Notify("Entity '" .. specificName .. "' detected!", "Specific entity nearby. Stay alert.", 6)
            return
        end
        local displayName = IsMonsterEntity(instance)
        if not displayName then return end
        if displayName == "Eyes" and not FloorHasEyes() then return end
        if displayName == "Dupe" then
            if not FloorHasDupe() then return end
            if not IsRealDupe(instance) then return end
        end
        local cd = NOTIFY_COOLDOWN_DEFAULT
        if displayName == "Dupe" then cd = NOTIFY_COOLDOWN_DUPE
        elseif displayName == "Eyes" or displayName == "Lookman" then cd = NOTIFY_COOLDOWN_EYES end
        local now = tick()
        if STATE.NotifyCooldown[displayName] and (now - STATE.NotifyCooldown[displayName]) < cd then return end
        STATE.NotifyCooldown[displayName] = now
        local msg
        if displayName == "Screech" then msg = "Look around and look at it quickly!"
        elseif displayName == "Halt" then msg = "Turn around and run back!"
        elseif displayName == "Rush" then msg = "Hide in a closet or behind a wall!"
        elseif displayName == "Ambush" then msg = "It rebounds! Stay hidden!"
        elseif displayName == "Eyes" then msg = "Do NOT look at it. Look away!"
        elseif displayName == "Lookman" then msg = "Do NOT look at it. Look away!"
        elseif displayName == "Figure" then msg = "Stay quiet. Do not run."
        elseif displayName == "Seek" then msg = "Run! Follow the path."
        elseif displayName == "Dupe" then msg = "Fake door. Do not enter."
        elseif displayName == "Snare" then msg = "Avoid the grass. Walk around."
        elseif displayName == "Hide" then msg = "It hides in closets. Check before entering."
        elseif displayName == "Grumble" then msg = "Stay away from it."
        elseif displayName == "Giggle" then msg = "Listen for the giggle. Stay away."
        else msg = "Entity spawned nearby!" end
        Notify("Entity '" .. displayName .. "' spawned!", msg, 6)
    end
    -- Раньше здесь на КАЖДЫЙ новый объект создавались 2 потока (task.delay + task.defer) —
    -- именно это давало самый сильный лаг при появлении большой комнаты. Теперь через Watcher.
    Watcher.Register("EntityNotifier", {
        IsEnabled = function()
            return not Library.Unloaded and Toggles.GN_Enabled and Toggles.GN_Enabled.Value
        end,
        Filter = function(v)
            return v:IsA("Model") or v:IsA("BasePart")
        end,
        Handle = function(v)
            TryNotifyEntity(v)
        end,
    })
end)
--============================================================
-- HALT WARNING
--============================================================
task.spawn(function()
    local function IsHaltRoom(room)
        if not room then return false end
        local raw = room:GetAttribute("RawName")
        if not raw then return false end
        raw = string.lower(raw)
        return raw:find("halt") ~= nil or raw:find("shade") ~= nil
    end
    local function HandleHaltRoomCheck(room)
        if Library.Unloaded then return end
        if not Toggles.GN_HaltWarning or not Toggles.GN_HaltWarning.Value then return end
        if STATE.haltWarned then return end
        task.wait(0.3)
        if STATE.haltWarned then return end
        if IsHaltRoom(room) then
            STATE.haltWarned = true
            Notify("HALT ROOM AHEAD!", "Next room is a Halt hallway - be ready to TURN AROUND!", 6)
        end
    end
    do
        local roomsFolder = Workspace:FindFirstChild("CurrentRooms")
        if roomsFolder then
            TrackConnection(roomsFolder.ChildAdded:Connect(HandleHaltRoomCheck))
        else
            TrackConnection(Workspace.ChildAdded:Connect(function(child)
                if child.Name == "CurrentRooms" then
                    TrackConnection(child.ChildAdded:Connect(HandleHaltRoomCheck))
                end
            end))
        end
    end
    TrackConnection(LocalPlayer.CharacterAdded:Connect(function()
        STATE.haltWarned = false
        STATE.NotifyCooldown = {}
        STATE.SpecificCache = {}
        STATE.MonsterCache = {}
        STATE.NameCache = {}
    end))
end)
--============================================================
-- [ABYSALL] AUTO SOLVE ANCHORS
--============================================================
local AutoSolveAnchorsState = { Enabled = false, LastFire = 0, Connection = nil }
local function GetCurrentAnchor()
    local MainUI = LocalPlayer.PlayerGui:FindFirstChild("MainUI")
    if not MainUI then return nil end
    local HintFrame = MainUI:FindFirstChild("AnchorHintFrame")
    if not HintFrame then return nil end
    local AnchorCode = HintFrame:FindFirstChild("AnchorCode")
    if not AnchorCode then return nil end
    local Code = AnchorCode.Text
    local Rooms = Workspace:FindFirstChild("CurrentRooms")
    if not Rooms then return nil end
    for _, Room in ipairs(Rooms:GetChildren()) do
        for _, Obj in ipairs(Room:GetDescendants()) do
            if Obj.Name == "MinesAnchor" and Obj:FindFirstChild("Sign") then
                local Sign = Obj.Sign
                if Sign:FindFirstChild("TextLabel") and Sign.TextLabel.Text == Code then
                    return Obj
                end
            end
        end
    end
    return nil
end
local function SolveAnchor()
    if not AutoSolveAnchorsState.Enabled then return end
    if tick() - AutoSolveAnchorsState.LastFire < 0.1 then return end
    -- ОПТИМИЗАЦИЯ: GetCurrentAnchor перебирает GetDescendants() всех комнат —
    -- делаем это не каждый кадр, а не чаще чем раз в 0.15 сек
    if tick() - (AutoSolveAnchorsState.LastCheck or 0) < 0.15 then return end
    AutoSolveAnchorsState.LastCheck = tick()
    local MainUI = LocalPlayer.PlayerGui:FindFirstChild("MainUI")
    if not MainUI then return end
    local HintFrame = MainUI:FindFirstChild("AnchorHintFrame")
    if not HintFrame then return end
    local CodeLabel = HintFrame:FindFirstChild("Code")
    if not CodeLabel then return end
    local Anchor = GetCurrentAnchor()
    if not Anchor or not Anchor.PrimaryPart then return end
    if Anchor:GetAttribute("Activated") then return end
    local Prompt = Anchor:FindFirstChild("ActivateEventPrompt")
    if not Prompt then return end
    local Distance = LocalPlayer:DistanceFromCharacter(Anchor.PrimaryPart.Position)
    if Distance > Prompt.MaxActivationDistance then return end
    local Remote = Anchor:FindFirstChild("AnchorRemote")
    if Remote then
        pcall(function()
            Remote:InvokeServer(CodeLabel.Text)
        end)
        AutoSolveAnchorsState.LastFire = tick()
    end
end
AutoSolveAnchorsState.Connection = RunService.Heartbeat:Connect(function()
    if Library.Unloaded then return end
    pcall(SolveAnchor)
end)
TrackConnection(AutoSolveAnchorsState.Connection)
local StartAutoSolveAnchors = function()
    AutoSolveAnchorsState.Enabled = true
    print("[LOLHAX] Auto Solve Anchors: ON")
end
local StopAutoSolveAnchors = function()
    AutoSolveAnchorsState.Enabled = false
    print("[LOLHAX] Auto Solve Anchors: OFF")
end
--============================================================
-- [ABYSALL] EXTENDED ANTI ENTITY (WATCHDOG)
--============================================================
local AntiEntityState = {
    BypassGiggle = false,
    BypassDupe = false,
    BypassGloombatEggs = false,
    BypassSeekObstructions = false,
    BypassVacuum = false,
    BypassKillbricks = false,
    BypassSeekingWall = false,
    BypassSnare = false,
    BypassBanana = false,
    BypassJeff = false,
}
local WATCHED_NAMES = {
    GiggleCeiling = true,
    DoorFake = true,
    FakeDoor = true,
    GloomPile = true,
    Seek_Arm = true,
    ChandelierObstruction = true,
    SeekFloodline = true,
    SideroomSpace = true,
    Lava = true,
    ScaryWall = true,
    Snare = true,
    BananaPeel = true,
    JeffTheKiller = true,
}
-- Применяет bypass к ОДНОМУ объекту. БЕЗ проверки "уже применено" —
-- пусть перезаписывает каждый раз, это дешево и защищает от revert'а.
local function ProcessOneObject(Object)
    if not Object or not Object.Parent then return end
    local Name = Object.Name
    if AntiEntityState.BypassGiggle and Name == "GiggleCeiling" then
        local Hitbox = Object:FindFirstChild("Hitbox")
        if Hitbox and Hitbox.CanTouch then Hitbox.CanTouch = false end
    end
    if AntiEntityState.BypassDupe and (Name == "DoorFake" or Name == "FakeDoor") then
        local Hidden = Object:FindFirstChild("Hidden")
        if Hidden and Hidden.CanTouch then Hidden.CanTouch = false end
        local Lock = Object:FindFirstChild("Lock")
        if Lock and Lock:FindFirstChild("UnlockPrompt") then
            local P = Lock.UnlockPrompt
            if P.Enabled then P.Enabled = false end
        end
    end
    if AntiEntityState.BypassGloombatEggs and Name == "GloomPile" then
        for _, Part in ipairs(Object:GetChildren()) do
            if Part:IsA("BasePart") and Part.CanTouch then Part.CanTouch = false end
        end
    end
    if AntiEntityState.BypassSeekObstructions then
        if Name == "Seek_Arm" or Name == "ChandelierObstruction" then
            for _, Part in ipairs(Object:GetChildren()) do
                if Part:IsA("BasePart") and Part.CanTouch then Part.CanTouch = false end
            end
        elseif Name == "SeekFloodline" then
            if not Object.CanCollide then Object.CanCollide = true end
        end
    end
    if AntiEntityState.BypassVacuum and Name == "SideroomSpace" then
        local Collision = Object:FindFirstChild("Collision")
        if Collision then
            if not Collision.CanCollide then Collision.CanCollide = true end
            if Collision.CanTouch then Collision.CanTouch = false end
        end
    end
    if AntiEntityState.BypassKillbricks and Name == "Lava" then
        if Object.CanTouch then Object.CanTouch = false end
    end
    if AntiEntityState.BypassSeekingWall and Name == "ScaryWall" then
        for _, Part in ipairs(Object:GetChildren()) do
            if Part:IsA("BasePart") then
                if Part.CanTouch then Part.CanTouch = false end
                if Part.CanCollide then Part.CanCollide = false end
            end
        end
    end
    if AntiEntityState.BypassSnare and Name == "Snare" then
        for _, Part in ipairs(Object:GetChildren()) do
            if Part:IsA("BasePart") and Part.CanTouch then Part.CanTouch = false end
        end
    end
    if AntiEntityState.BypassBanana and Name == "BananaPeel" then
        if Object.CanTouch then Object.CanTouch = false end
    end
    if AntiEntityState.BypassJeff and Name == "JeffTheKiller" then
        for _, Part in ipairs(Object:GetChildren()) do
            if Part:IsA("BasePart") then
                if Part.CanCollide then Part.CanCollide = false end
                if Part.CanTouch then Part.CanTouch = false end
            end
        end
        local Hum = Object:FindFirstChild("Humanoid")
        if Hum and Hum.Health > 0 then Hum.Health = 0 end
    end
end
-- Рекурсивный сбор кандидатов (1-3 уровня, дешево)
local function CollectCandidates(root, out)
    for _, obj in ipairs(root:GetChildren()) do
        if WATCHED_NAMES[obj.Name] then
            table.insert(out, obj)
        end
        -- спускаемся в контейнеры, где обычно прячутся entity-объекты
        local n = obj.Name
        if n == "Assets" or n == "Blockage" or n == "Decor"
           or n == "Folder" or n == "Alternate" or n == "StandardDecor" then
            CollectCandidates(obj, out)
        end
    end
end
local function ScanAll()
    local candidates = {}
    local CurrentRooms = Workspace:FindFirstChild("CurrentRooms")
    if CurrentRooms then
        CollectCandidates(CurrentRooms, candidates)
    end
    -- прямые дети Workspace (Snare, Lava, Jeff и т.п.)
    for _, obj in ipairs(Workspace:GetChildren()) do
        if WATCHED_NAMES[obj.Name] then
            table.insert(candidates, obj)
        end
    end
    for _, obj in ipairs(candidates) do
        pcall(ProcessOneObject, obj)
    end
end
-- Реакция на добавление (через общий Watcher; работает только когда включён хотя бы один bypass)
local function AnyAntiEntityBypass()
    return AntiEntityState.BypassGiggle or AntiEntityState.BypassDupe
        or AntiEntityState.BypassGloombatEggs or AntiEntityState.BypassSeekObstructions
        or AntiEntityState.BypassVacuum or AntiEntityState.BypassKillbricks
        or AntiEntityState.BypassSeekingWall or AntiEntityState.BypassSnare
        or AntiEntityState.BypassBanana or AntiEntityState.BypassJeff
end
Watcher.Register("AntiEntity", {
    IsEnabled = function() return AnyAntiEntityBypass() and true or false end,
    Filter = function(Object) return WATCHED_NAMES[Object.Name] == true end,
    Handle = function(Object)
        if Object and Object.Parent then ProcessOneObject(Object) end
    end,
})
-- Реакция на смену свойств: если игра ревертит CanTouch/CanCollide — вернём обратно
local watchedParts = setmetatable({}, { __mode = "k" })  -- weak keys, чтобы не течь
local function WatchPart(part)
    if watchedParts[part] then return end
    watchedParts[part] = true
    TrackConnection(part:GetPropertyChangedSignal("CanTouch"):Connect(function()
        if part.Parent then pcall(ProcessOneObject, part.Parent) end
    end))
    TrackConnection(part:GetPropertyChangedSignal("CanCollide"):Connect(function()
        if part.Parent then pcall(ProcessOneObject, part.Parent) end
    end))
end
-- Расширим ProcessOneObject обёрткой, чтобы вешать watch на дочерние части
local _ProcessOneObject = ProcessOneObject
ProcessOneObject = function(Object)
    _ProcessOneObject(Object)
    if Object:IsA("BasePart") then
        WatchPart(Object)
    else
        for _, d in ipairs(Object:GetChildren()) do
            if d:IsA("BasePart") then WatchPart(d) end
        end
    end
end
-- Watchdog: раз в 1.5 сек пробегаемся по комнатам и переприменяем bypass
task.spawn(function()
    while not Library.Unloaded do
        task.wait(1.5)
        if Library.Unloaded then break end
        local any = AntiEntityState.BypassGiggle or AntiEntityState.BypassDupe
            or AntiEntityState.BypassGloombatEggs or AntiEntityState.BypassSeekObstructions
            or AntiEntityState.BypassVacuum or AntiEntityState.BypassKillbricks
            or AntiEntityState.BypassSeekingWall or AntiEntityState.BypassSnare
            or AntiEntityState.BypassBanana or AntiEntityState.BypassJeff
        if any then
            pcall(ScanAll)
        end
    end
end)
-- Экспорт для вызова при включении тумблера (сразу скан всего + включение мониторинга)
ScanAntiEntities = function()
    Watcher.Refresh()
    pcall(ScanAll)
end
--============================================================
-- AUTO PADLOCK
--============================================================
task.spawn(function()
    local function BuildKnownDigits()
        local Paper = nil
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if char and char:FindFirstChild("LibraryHintPaper") then Paper = char:FindFirstChild("LibraryHintPaper")
        elseif backpack and backpack:FindFirstChild("LibraryHintPaper") then Paper = backpack:FindFirstChild("LibraryHintPaper") end
        if not Paper then
            for _, Player in ipairs(Players:GetPlayers()) do
                if Player ~= LocalPlayer then
                    local c = Player.Character
                    local bp = Player:FindFirstChildOfClass("Backpack")
                    if c and c:FindFirstChild("LibraryHintPaper") then Paper = c:FindFirstChild("LibraryHintPaper") break
                    elseif bp and bp:FindFirstChild("LibraryHintPaper") then Paper = bp:FindFirstChild("LibraryHintPaper") break end
                end
            end
        end
        if not Paper or not Paper:FindFirstChild("UI") then return nil end
        local permUI = LocalPlayer.PlayerGui:FindFirstChild("PermUI")
        if not permUI then return nil end
        local hints = permUI:FindFirstChild("Hints")
        if not hints then return nil end
        local digits = { "", "", "", "", "_" }
        for _, x in ipairs(Paper.UI:GetChildren()) do
            if tonumber(x.Name) then
                local idx = tonumber(x.Name)
                if idx >= 1 and idx <= 5 then
                    for _, y in ipairs(hints:GetChildren()) do
                        if y.Name == "Icon" and y:FindFirstChild("TextLabel") then
                            if y.ImageRectOffset == x.ImageRectOffset then digits[idx] = y.TextLabel.Text end
                        end
                    end
                end
            end
        end
        return digits
    end
    local function CountKnownDigits(digits)
        if not digits then return 0 end
        local n = 0
        for i = 1, 5 do if digits[i] ~= "_" then n += 1 end end
        return n
    end
    local function BuildBruteforceQueue(known, missingCount)
        local queue = {}
        local unknown = {}
        for i = 1, 5 do if known[i] == "_" then table.insert(unknown, i) end end
        if missingCount == 1 then
            local pos = unknown[1]
            if not pos then return queue end
            for d = 0, 9 do
                local code = table.clone(known)
                code[pos] = tostring(d)
                table.insert(queue, table.concat(code))
            end
        elseif missingCount == 2 then
            local p1, p2 = unknown[1], unknown[2]
            if not p1 or not p2 then return queue end
            for d1 = 0, 9 do
                for d2 = 0, 9 do
                    local code = table.clone(known)
                    code[p1] = tostring(d1)
                    code[p2] = tostring(d2)
                    table.insert(queue, table.concat(code))
                end
            end
        end
        return queue
    end
    local function SendPadlockCode(code)
        local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
        if not rf then return false end
        local pl = rf:FindFirstChild("PL")
        if not pl then return false end
        SafeCall(function() pl:FireServer(code) end)
        return true
    end
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end
        if not Toggles.MY_AutoPadlock or not Toggles.MY_AutoPadlock.Value then return end
        local char = LocalPlayer.Character
        if not char then return end
        local collision = char:FindFirstChild("Collision")
        if not collision then return end
        local rooms = Workspace:FindFirstChild("CurrentRooms")
        if not rooms then return end
        local Room50 = rooms:FindFirstChild("50")
        if not Room50 then return end
        local Door = Room50:FindFirstChild("Door")
        if not Door then return end
        local Padlock = Door:FindFirstChild("Padlock")
        if not Padlock or not Padlock:FindFirstChild("Main") then return end
        if (collision.Position - Padlock.Main.Position).Magnitude > Options.MY_AutoPadlock_Dist.Value then return end
        if tick() - STATE.LastPadlockFire < STATE.PADLOCK_COOLDOWN then return end
        if not STATE.PadlockCode_N then
            local digits = BuildKnownDigits()
            if digits then
                local knownCount = CountKnownDigits(digits)
                if knownCount == 5 then
                    STATE.PadlockCode = table.concat(digits)
                    STATE.PadlockCode_N = STATE.PadlockCode
                    STATE.PadlockBruteforceQueue = {}
                    Notify("Padlock code found!", "The code is: '" .. STATE.PadlockCode .. "'", 10)
                elseif knownCount >= 3 and #STATE.PadlockBruteforceQueue == 0 then
                    STATE.PadlockBruteforceQueue = BuildBruteforceQueue(digits, 5 - knownCount)
                end
            end
        end
        if STATE.PadlockCode_N then
            STATE.LastPadlockFire = tick()
            SendPadlockCode(STATE.PadlockCode_N)
            return
        end
        if #STATE.PadlockBruteforceQueue > 0 then
            local nextCode = table.remove(STATE.PadlockBruteforceQueue, 1)
            if not nextCode then return end
            STATE.PadlockAttempts += 1
            STATE.LastPadlockFire = tick()
            SendPadlockCode(nextCode)
        end
    end))
end)
--============================================================
-- [ABYSALL] POSITION SPOOF
--============================================================
local PositionSpoof = {
    Enabled = false,
    OldC1 = nil,
    OldHipHeight = nil,
    LastFire = 0,
    OldFloor = false,
    SpoofOffset = 0,
    SpoofOffsetApplied = nil,
    LastCrouchState = nil,
}
local SetPositionSpoofState
task.spawn(function()
    local function GetNearestEntity(CheckDisabled)
        local Nearest = { Distance = math.huge, Object = nil }
        for _, Entity in ipairs(Workspace:GetChildren()) do
            if Entity and StaticDB.EntityDistances[Entity.Name] and Entity.PrimaryPart then
                local Distance = LocalPlayer:DistanceFromCharacter(Entity.PrimaryPart.Position)
                if Distance < StaticDB.EntityDistances[Entity.Name] and Distance < Nearest.Distance then
                    if not CheckDisabled or Entity:GetAttribute("Inactive") ~= true then
                        Nearest.Distance = Distance
                        Nearest.Object = Entity
                    end
                end
            end
        end
        return Nearest.Object
    end
    local function GetNearestFigure()
        local FigureNames = { FigureRig = true, FigureRagdoll = true, Figure = true }
        for _, Object in ipairs(Workspace:GetChildren()) do
            if Object:IsA("Model") and Object.PrimaryPart and FigureNames[Object.Name] then
                local Distance = LocalPlayer:DistanceFromCharacter(Object.PrimaryPart.Position)
                if Distance < 25 then return Object end
            end
        end
        return nil
    end
    local function ApplyPositionSpoof()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        local collision = char:FindFirstChild("Collision")
        if not hrp or not hum or not collision then return end
        local collisionPart = char:FindFirstChild("CollisionPart") or collision
        local collisionClone = char:FindFirstChild("CollisionClone")
        local collisionCrouch = collision:FindFirstChild("CollisionCrouch")
        local cloneCrouch = collisionClone and collisionClone:FindFirstChild("CollisionCrouch")
        local nearestRush = GetNearestEntity(true)
        local nearestFigure = (Toggles.MY_FigureGodmode and Toggles.MY_FigureGodmode.Value) and GetNearestFigure() or nil
        local SpoofOffset =
            (PositionSpoof.Enabled and nearestRush and 200)
            or (nearestFigure and 200)
            or 0
        PositionSpoof.SpoofOffset = SpoofOffset
        if IsOldFloor() then
            collision.Position = hrp.Position + Vector3.new(0, SpoofOffset, 0)
            collision.CanCollide = false
            if collisionCrouch then collisionCrouch.CanCollide = false end
            if collisionClone and cloneCrouch then cloneCrouch.CanCollide = false end
            return
        end
        if collisionClone and cloneCrouch then
            local IsCrouch = (char:GetAttribute("Crouching") == true)
            collisionClone.CanCollide = not (IsCrouch)
            cloneCrouch.CanCollide = not (IsCrouch == false)
        else
            hrp.CanCollide = false
        end
        if char:FindFirstChild("LowerTorso") and char.LowerTorso:FindFirstChild("Root") then
            if not PositionSpoof.OldC1 then PositionSpoof.OldC1 = char.LowerTorso.Root.C1 end
            char.LowerTorso.Root.C1 = PositionSpoof.OldC1 * CFrame.new(0, PositionSpoof.Enabled and -2.346 or 0, 0)
        end
        local SpoofY = PositionSpoof.Enabled and 2.328 or 0.18
        collision.Position     = hrp.Position + Vector3.new(0, SpoofY, 0)
        collisionPart.Position = hrp.Position + Vector3.new(0, SpoofY, 0)
        if collisionCrouch and cloneCrouch then
            local CrouchY = PositionSpoof.Enabled and 1.328 or -0.982
            collisionCrouch.Position = hrp.Position + Vector3.new(0, CrouchY, 0)
            cloneCrouch.CollisionGroup = collisionCrouch.CollisionGroup
        end
        if cloneCrouch then
            cloneCrouch.Position = hrp.Position + Vector3.new(0, PositionSpoof.Enabled and 0.75 or -0.982, 0)
        end
        if collisionClone then
            collisionClone.CollisionGroup = collision.CollisionGroup
            collisionClone.Position = hrp.Position + Vector3.new(0, PositionSpoof.Enabled and 1.75 or 0.18, 0)
        end
        -- ФИКС "приседание меняет что Rush может убить": Position Spoof работает так,
        -- что скрипт ЭМИТИТРует спуф-позицию каждый кадр через collision-объекты.
        -- Если мы отправляем Crouch remote только при смене Crouching, то при активном
        -- приседании Doors НЕ получает постоянный crouch-сигнал и спооф-состояние
        -- ("на подземной высоте") сбрасывается → Rush может добраться и убить.
        -- Решение: спамим FireServer(true, true) КАЖДЫЙ кадр, но НЕ мешаем физике
        -- приседания — мы не трогаем hrp.CFrame, а только collision-объекты.
        -- Чтобы не ломать физику приседания, отправляем с фиксированным интервалом
        -- (0.1 сек), и НЕ перезапускаем анимацию — только споофим дистанцию.
        -- Это восстанавливает защиту от Rush даже при активном приседании.
        local now = tick()
        if now - PositionSpoof.LastFire > 0.1 then
            local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
            if rf and rf:FindFirstChild("Crouch") then
                SafeCall(function() rf.Crouch:FireServer(true, true) end)
            end
            PositionSpoof.LastFire = now
        end
        -- при смене Crouching тоже отправляем сразу (чтобы спооф-состояние
        -- не сбрасывалось при начале/конце приседания)
        local charCrouch = (char:GetAttribute("Crouching") == true)
        if charCrouch ~= PositionSpoof.LastCrouchState then
            PositionSpoof.LastCrouchState = charCrouch
            local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
            if rf and rf:FindFirstChild("Crouch") then
                SafeCall(function() rf.Crouch:FireServer(true, true) end)
            end
            PositionSpoof.LastFire = now
        end
    end
    SetPositionSpoofState = function(state)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hrp or not hum then return end
        PositionSpoof.OldFloor = IsOldFloor()
        if state then
            if not PositionSpoof.OldHipHeight then
                PositionSpoof.OldHipHeight = hum.HipHeight
            end
            if not PositionSpoof.OldFloor then
                -- телепорт ПО ОДНОМУ КОРРЕКТНОМУ CFrame, без накопления смещения:
                -- раньше включение позиционировало персонажа под землёй,
                -- но приседание снова сдвигало его и он начинал "летать в воздухе".
                -- Новый метод: сдвигаем root только один раз, физику держит collision-спуф.
                if not PositionSpoof.SpoofOffsetApplied then
                    hrp.CFrame = hrp.CFrame * CFrame.new(0, -2.346, 0)
                    PositionSpoof.SpoofOffsetApplied = true
                    hum.HipHeight = 0.05
                    local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
                    if rf and rf:FindFirstChild("Crouch") then
                        SafeCall(function() rf.Crouch:FireServer(true, true) end)
                    end
                    PositionSpoof.LastFire = tick()
                end
            end
            PositionSpoof.Enabled = true
        else
            if not PositionSpoof.OldFloor then
                if PositionSpoof.SpoofOffsetApplied then
                    hrp.CFrame = hrp.CFrame * CFrame.new(0, 2.346, 0)
                end
                hum.HipHeight = PositionSpoof.OldHipHeight or 2.396
            end
            if char:FindFirstChild("LowerTorso") and char.LowerTorso:FindFirstChild("Root") and PositionSpoof.OldC1 then
                char.LowerTorso.Root.C1 = PositionSpoof.OldC1
            end
            PositionSpoof.SpoofOffsetApplied = nil
            PositionSpoof.LastCrouchState = nil
            PositionSpoof.Enabled = false
            local collision = char:FindFirstChild("Collision")
            if collision then
                collision.Position = hrp.Position + Vector3.new(0, 0.18, 0)
                collision.CanCollide = true
                if collision:FindFirstChild("CollisionCrouch") then
                    collision.CollisionCrouch.Position = hrp.Position + Vector3.new(0, -0.982, 0)
                    collision.CollisionCrouch.CanCollide = true
                end
            end
        end
    end
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded or not PositionSpoof.Enabled then return end
        local char = LocalPlayer.Character
        if char and char:GetAttribute("Hiding") then return end
        -- ФИКС ЛАГОВ ПРИСЕДАНИЯ: при включённом Position Spoof разблокируем физику
        -- корневой части персонажа и убираем зависание в воздухе.
        -- Причина бага: раньше скрипт каждый кадр двигал collision-объекты
        -- и это конфликтовало с приседанием (персонаж висел в воздухе / лагал).
        -- Теперь: если персонаж приседает, не мешаем физике приседания двигать его,
        -- а просто держим collision на нужной высоте один раз за кадр.
        ApplyPositionSpoof()
    end))
end)
--============================================================
-- RESPAWN
--============================================================
TrackConnection(LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    STATE.Character = newCharacter
    STATE.HumanoidRootPart = newCharacter:WaitForChild("HumanoidRootPart")
    STATE.Humanoid = newCharacter:WaitForChild("Humanoid")
    STATE.GlitchActive = false
    STATE.States.manip = false
    STATE.States.airlock = false
    PositionSpoof.Enabled = false
    PositionSpoof.OldC1 = nil
    PositionSpoof.OldHipHeight = nil
    PositionSpoof.SpoofOffsetApplied = nil
    PositionSpoof.LastCrouchState = nil
    -- сброс снапшота ThirdPerson головы (старый персонаж уничтожен, instance-ссылки недействительны)
    ThirdPersonSession = nil
    table.clear(ThirdPersonHidden)
    STATE.SpecificCache = {}
    STATE.MonsterCache = {}
    STATE.NameCache = {}
    if Fly.Enabled then task.delay(0.5, function() if Fly.Enabled then CallIfReady(StartFly) end end) end
    if Disabler.Enabled then
        task.delay(1, function()
            if not Disabler.Enabled then return end
            CallIfReady(StopDisabler)
            task.wait(0.1)
            CallIfReady(StartDisabler)
        end)
    end
    if RemoveAccelState.Enabled then
        task.delay(0.5, function()
            if RemoveAccelState.Enabled then
                CallIfReady(StopRemoveAcceleration)
                task.wait(0.1)
                CallIfReady(StartRemoveAcceleration)
            end
        end)
    end
end))
--============================================================
-- VELOCITY MANIPULATION
--============================================================
local VelocityManip = { Body = nil, Enabled = false }
task.spawn(function()
    VelocityManip.Body = Instance.new("BodyVelocity")
    VelocityManip.Body.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    VelocityManip.Body.Velocity = Vector3.zero
    TrackConnection(RunService.RenderStepped:Connect(function()
        if Library.Unloaded then return end
        local toggle = Toggles.MY_VelocityManip
        local picker = Options.MY_VelocityManip_K
        if not toggle or not picker then return end
        local wantState = toggle.Value and picker:GetState()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            VelocityManip.Body.Parent = nil
            return
        end
        local mode = Options.MY_VelocityManip_Mode and Options.MY_VelocityManip_Mode.Value or "Velocity"
        if wantState then
            if not IsOldFloor() and not Camera:FindFirstChild("MinecartRig") then
                hrp.CanCollide = false
            end
            for _, Part in ipairs(char:GetChildren()) do
                if Part:IsA("BasePart") then
                    Part.CanCollide = false
                end
            end
            if mode == "Velocity" then
                VelocityManip.Body.Parent = hrp
                VelocityManip.Body.Velocity = hrp.CFrame.LookVector * 2.25
            elseif mode == "Pivot" and not IsOldFloor() then
                char:PivotTo(Camera:GetPivot() * CFrame.new(0, 0, 2560))
            end
        else
            VelocityManip.Body.Parent = nil
            VelocityManip.Body.Velocity = Vector3.zero
        end
    end))
end)
--============================================================
-- ESP
--============================================================
local ESP = {
    Enabled=false, Name=true, Distance=true, TeamCheck=true,
    MaxDistance=1000, TextSize=20,
    NameColor=Color3.fromRGB(255,255,255),
    MonsterColor=Color3.fromRGB(255,80,80),
    PlayerColor=Color3.fromRGB(255,255,255),
    ItemColor=Color3.fromRGB(255,215,0),
    LeverColor=Color3.fromRGB(0,200,255),
    DoorColor=Color3.fromRGB(160,100,255),
    BookColor=Color3.fromRGB(0,255,255),
    BreakerColor=Color3.fromRGB(255,140,0),
    FuseColor=Color3.fromRGB(255,220,0),
    PizzaColor=Color3.fromRGB(255,180,60),
    BasementLeverColor=Color3.fromRGB(255,100,0),
    HideBoxColor=Color3.fromRGB(0,255,0),
    GoldColor=Color3.fromRGB(255,215,0),
    KeyColor=Color3.fromRGB(0,255,120),
    PetalColor=Color3.fromRGB(255,105,180),
    SpecificColor=Color3.fromRGB(180,100,255),
}
-- Категории ESP: id тумблера -> категория (используется ESP и Tracers)
local ESP_TOGGLE_CATEGORY = {
    ESP_Doors = "Door", ESP_Keys = "Key", ESP_Monsters = "Monster", ESP_Players = "Player",
    ESP_Items = "Item", ESP_Books = "Book", ESP_Breakers = "Breaker", ESP_Fuses = "Fuse",
    ESP_Pizza = "Pizza", ESP_BasementLevers = "BasementLever", ESP_Levers = "Lever",
    ESP_HideBoxes = "HideBox", ESP_GoldPiles = "Gold", ESP_LotusPetal = "Petal",
    ESP_SpecificEntities = "Specific",
}
local ESPRegistry = {}
local Esp, RemoveEsp, HasEsp, scanExistingPlayers, clearAllEsp, RemoveEspCategory, RescanEsp
task.spawn(function()
    -- Category: "Door", "Key", "Monster", ... (нужно для Tracers и для быстрого выключения категории)
    Esp = function(Adornee, TextAdornee, Text, Color, OutlineColor, Category)
        if not Adornee or not Adornee.Parent then return end
        if Adornee:FindFirstChild("_LOLHAXHL") then return end
        local Highlight = Instance.new("Highlight")
        Highlight.Name = "_LOLHAXHL"
        Highlight.Adornee = Adornee
        Highlight.FillColor = Color
        Highlight.OutlineColor = OutlineColor or Color
        Highlight.FillTransparency = 0.7
        Highlight.OutlineTransparency = 0.2
        Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        Highlight.Parent = Adornee
        local BillboardGui = Instance.new("BillboardGui")
        BillboardGui.Name = "_LOLHAXBG"
        BillboardGui.Adornee = TextAdornee or Adornee
        BillboardGui.AlwaysOnTop = true
        BillboardGui.Size = UDim2.fromScale(1, 1)
        BillboardGui.Parent = Adornee
        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.fromScale(1, 1)
        TextLabel.BackgroundTransparency = 1
        TextLabel.TextStrokeTransparency = 0
        TextLabel.TextColor3 = ESP.NameColor
        TextLabel.TextSize = ESP.TextSize
        TextLabel.Font = Enum.Font.SourceSansBold
        TextLabel.Text = Text
        TextLabel.Parent = BillboardGui
        ESPRegistry[Adornee] = {
            base = Text, label = TextLabel,
            category = Category or "Other",
            color = Color,
            target = TextAdornee or Adornee,
            hl = Highlight, bg = BillboardGui,
        }
    end
    -- Обновление текста дистанции ~10 раз в секунду (раньше — каждый кадр для каждого объекта)
    local lastEspUpdate = 0
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded or not ESP.Enabled then return end
        local nowClock = os.clock()
        if nowClock - lastEspUpdate < 0.1 then return end
        lastEspUpdate = nowClock
        local char = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local myPos = myRoot.Position
        for adornee, data in pairs(ESPRegistry) do
            if not adornee or not adornee.Parent then ESPRegistry[adornee] = nil continue end
            local label = data.label
            if not label or not label.Parent then ESPRegistry[adornee] = nil continue end
            local pos
            local ok, res = pcall(function()
                if adornee:IsA("BasePart") then return adornee.Position
                elseif adornee:IsA("Model") then return adornee:GetPivot().Position end
            end)
            if ok then pos = res end
            if pos then
                local dist = (myPos - pos).Magnitude
                data.dist = dist
                if ESP.MaxDistance and dist > ESP.MaxDistance then label.Visible = false
                else
                    label.Visible = true
                    local newText
                    if ESP.Distance then newText = data.base .. "\n[ " .. string.format("%.0f", dist) .. " ]"
                    else newText = data.base end
                    if label.Text ~= newText then label.Text = newText end
                end
            end
        end
    end))
    RemoveEsp = function(parent)
        if not parent then return end
        ESPRegistry[parent] = nil
        for _, x in parent:GetChildren() do
            if x.Name == "_LOLHAXBG" or x.Name == "_LOLHAXHL" then x:Destroy() end
        end
    end
    HasEsp = function(parent) return parent and parent:FindFirstChild("_LOLHAXHL") ~= nil end
    -- Убрать ESP всех объектов одной категории (при выключении тумблера категории)
    RemoveEspCategory = function(category)
        for adornee, data in pairs(ESPRegistry) do
            if data.category == category then
                if adornee and adornee.Parent then
                    RemoveEsp(adornee)
                else
                    ESPRegistry[adornee] = nil
                end
            end
        end
    end
    scanExistingPlayers = function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                if ESP.TeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
                    RemoveEsp(plr.Character)
                elseif not HasEsp(plr.Character) then
                    Esp(plr.Character, plr.Character, plr.Name, ESP.PlayerColor, ESP.PlayerColor, "Player")
                end
            end
        end
    end
    clearAllEsp = function()
        -- сначала всё, что зарегистрировано (в т.ч. объекты глубоко внутри комнат)
        for adornee, data in pairs(ESPRegistry) do
            if data.hl then pcall(function() data.hl:Destroy() end) end
            if data.bg then pcall(function() data.bg:Destroy() end) end
        end
        ESPRegistry = {}
        for _, obj in ipairs(Workspace:GetChildren()) do
            for _, x in ipairs(obj:GetChildren()) do
                if x.Name == "_LOLHAXHL" or x.Name == "_LOLHAXBG" then x:Destroy() end
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then RemoveEsp(plr.Character) end
        end
    end
end)
-- ESP handler для новых объектов
task.spawn(function()
    local function HandleEspDescendant(v)
        if not ESP.Enabled or not v:IsA("Model") then return end
        if Toggles.ESP_LotusPetal and Toggles.ESP_LotusPetal.Value then
            if IsLotusPetal(v) then
                task.delay(0.3, function()
                    if v.Parent and ESP.Enabled and Toggles.ESP_LotusPetal.Value and not HasEsp(v) then
                        Esp(v, v, "🌸 LOTUS PETAL", ESP.PetalColor, Color3.fromRGB(255, 255, 0), "Petal")
                    end
                end)
                return
            end
        end
        if Toggles.ESP_SpecificEntities and Toggles.ESP_SpecificEntities.Value then
            local specificName, specificColor = GetSpecificEntityType(v)
            if specificName then
                task.delay(0.3, function()
                    if v.Parent and ESP.Enabled and Toggles.ESP_SpecificEntities.Value and not HasEsp(v) then
                        Esp(v, v, "[ENTITY] " .. specificName, specificColor, specificColor, "Specific")
                    end
                end)
                return
            end
        end
        if Toggles.ESP_Monsters and Toggles.ESP_Monsters.Value then
            local disp = IsMonsterEntity(v)
            if disp then
                task.delay(0.5, function()
                    if v.Parent and ESP.Enabled and Toggles.ESP_Monsters.Value and not HasEsp(v) then
                        Esp(v, v, disp, ESP.MonsterColor, ESP.MonsterColor, "Monster")
                    end
                end)
                return
            end
        end
        if v.Name == "Door" and v:GetAttribute("RoomID") and Toggles.ESP_Doors and Toggles.ESP_Doors.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_Doors.Value and not HasEsp(v) then
                    local adorn = v:FindFirstChild("Door") or v.PrimaryPart or v
                    Esp(v, adorn, "Door [" .. tostring(v:GetAttribute("RoomID")) .. "]", ESP.DoorColor, ESP.DoorColor, "Door")
                end
            end)
            return
        end
        if v.Name == "KeyObtain" and Toggles.ESP_Keys and Toggles.ESP_Keys.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_Keys.Value and not HasEsp(v) then
                    Esp(v, v, "Key", ESP.KeyColor, ESP.KeyColor, "Key")
                end
            end)
            return
        end
        if v.Name == "GoldPile" and Toggles.ESP_GoldPiles and Toggles.ESP_GoldPiles.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_GoldPiles.Value and not HasEsp(v) then
                    local adorn = v:FindFirstChild("Hitbox") or v.PrimaryPart or v
                    local goldValue = v:GetAttribute("GoldValue")
                    local label = goldValue and ("Gold Pile [" .. tostring(goldValue) .. "]") or "Gold Pile"
                    Esp(v, adorn, label, ESP.GoldColor, ESP.GoldColor, "Gold")
                end
            end)
            return
        end
        -- Pizza теперь управляется своим тумблером "Esp Pizza" (раньше тумблер ничего не делал)
        if v.Name == "Pizza" and StaticDB.MiscPickups[v.Name] then
            if Toggles.ESP_Pizza and Toggles.ESP_Pizza.Value then
                task.delay(0.5, function()
                    if v.Parent and ESP.Enabled and Toggles.ESP_Pizza.Value and not HasEsp(v) then
                        Esp(v, v.PrimaryPart or v, StaticDB.MiscPickups[v.Name], ESP.PizzaColor, ESP.PizzaColor, "Pizza")
                    end
                end)
            end
            return
        end
        if StaticDB.MiscPickups[v.Name] and Toggles.ESP_Items and Toggles.ESP_Items.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_Items.Value and not HasEsp(v) then
                    local adorn = v.PrimaryPart or v
                    local color = (v.Name == "Pizza") and ESP.PizzaColor or ESP.ItemColor
                    Esp(v, adorn, StaticDB.MiscPickups[v.Name], color, color, "Item")
                end
            end)
            return
        end
        if StaticDB.LIBRARY_BOOKS[v.Name] and Toggles.ESP_Books and Toggles.ESP_Books.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_Books.Value and not HasEsp(v) then
                    Esp(v, v, StaticDB.LIBRARY_BOOKS[v.Name], ESP.BookColor, ESP.BookColor, "Book")
                end
            end)
            return
        end
        if StaticDB.BREAKER_NAMES[v.Name] and Toggles.ESP_Breakers and Toggles.ESP_Breakers.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_Breakers.Value and not HasEsp(v) then
                    Esp(v, v.PrimaryPart or v, StaticDB.BREAKER_NAMES[v.Name], ESP.BreakerColor, ESP.BreakerColor, "Breaker")
                end
            end)
            return
        end
        if StaticDB.FUSE_NAMES[v.Name] and Toggles.ESP_Fuses and Toggles.ESP_Fuses.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_Fuses.Value and not HasEsp(v) then
                    Esp(v, v.PrimaryPart or v:FindFirstChild("Hitbox") or v, StaticDB.FUSE_NAMES[v.Name], ESP.FuseColor, ESP.FuseColor, "Fuse")
                end
            end)
            return
        end
        if StaticDB.BASEMENT_LEVERS[v.Name] and Toggles.ESP_BasementLevers and Toggles.ESP_BasementLevers.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_BasementLevers.Value and not HasEsp(v) then
                    Esp(v, v.PrimaryPart or v:FindFirstChild("Main") or v:FindFirstChild("Hitbox") or v, StaticDB.BASEMENT_LEVERS[v.Name], ESP.BasementLeverColor, ESP.BasementLeverColor, "BasementLever")
                end
            end)
            return
        end
        if StaticDB.BACKDOOR_LEVERS[v.Name] and Toggles.ESP_Levers and Toggles.ESP_Levers.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_Levers.Value and not HasEsp(v) then
                    Esp(v, v:FindFirstChild("Hitbox") or v.PrimaryPart or v, StaticDB.BACKDOOR_LEVERS[v.Name], ESP.LeverColor, ESP.LeverColor, "Lever")
                end
            end)
            return
        end
        if StaticDB.HIDE_BOX_NAMES[v.Name] and Toggles.ESP_HideBoxes and Toggles.ESP_HideBoxes.Value then
            task.delay(0.5, function()
                if v.Parent and ESP.Enabled and Toggles.ESP_HideBoxes.Value and not HasEsp(v) then
                    Esp(v, v.PrimaryPart or v, StaticDB.HIDE_BOX_NAMES[v.Name], ESP.HideBoxColor, ESP.HideBoxColor, "HideBox")
                end
            end)
            return
        end
    end
    -- Новые объекты — через общий Watcher (очередь + бюджет на кадр, без task.delay на каждый объект)
    Watcher.Register("ESP", {
        IsEnabled = function() return ESP.Enabled and not Library.Unloaded end,
        Filter = function(v) return v:IsA("Model") end,
        Handle = HandleEspDescendant,
    })
    -- Полный пересканирование: вызывается при включении ESP или любой его категории
    RescanEsp = function()
        if not ESP.Enabled then return end
        Watcher.Scan("ESP")
        if Toggles.ESP_Players and Toggles.ESP_Players.Value then scanExistingPlayers() end
    end
    -- Игроки: и новые, и уже находящиеся на сервере (раньше после респавна старых игроков ESP пропадал)
    local function HookPlayer(plr)
        if plr == LocalPlayer then return end
        TrackConnection(plr.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            if ESP.Enabled and Toggles.ESP_Players and Toggles.ESP_Players.Value and not HasEsp(char) then
                if ESP.TeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then return end
                Esp(char, char, plr.Name, ESP.PlayerColor, ESP.PlayerColor, "Player")
            end
        end))
    end
    for _, plr in ipairs(Players:GetPlayers()) do HookPlayer(plr) end
    TrackConnection(Players.PlayerAdded:Connect(HookPlayer))
end)
--============================================================
-- TRACERS  (линии от прицела к объектам из ESP)
--============================================================
-- Берут данные напрямую из ESPRegistry (то, что подсвечивает ESP), поэтому работают,
-- когда включён ESP и нужная категория ESP. Для каждой категории можно включить/выключить
-- трейсер и задать свой цвет. Рисуются через Drawing API (если экзекутор его поддерживает),
-- иначе — через обычные GUI-линии (Frame с поворотом).
local Tracers = {
    Enabled = false,
    Origin = "Crosshair",
    Thickness = 1.5,
    Transparency = 0,
    MaxDistance = 1000,
    UseESPColor = false,
    ShowOffscreen = true,
    Targets = {},       -- category -> true
    Colors = {},        -- category -> Color3
    Pool = {},          -- adornee -> line
    Free = {},          -- свободные линии для повторного использования
    Frame = 0,
    Gui = nil,
    UseDrawing = false,
    Bound = false,
}
local TRACER_CATEGORIES = {
    { key = "Door",          title = "Doors",             color = ESP.DoorColor },
    { key = "Key",           title = "Keys",              color = ESP.KeyColor },
    { key = "Monster",       title = "Monsters",          color = ESP.MonsterColor },
    { key = "Specific",      title = "Specific Entities", color = ESP.SpecificColor },
    { key = "Player",        title = "Players",           color = ESP.PlayerColor },
    { key = "Item",          title = "Items",             color = ESP.ItemColor },
    { key = "Pizza",         title = "Pizza",             color = ESP.PizzaColor },
    { key = "Book",          title = "Books",             color = ESP.BookColor },
    { key = "Breaker",       title = "Breakers",          color = ESP.BreakerColor },
    { key = "Fuse",          title = "Fuses",             color = ESP.FuseColor },
    { key = "BasementLever", title = "Basement Levers",   color = ESP.BasementLeverColor },
    { key = "Lever",         title = "Levers",            color = ESP.LeverColor },
    { key = "HideBox",       title = "Honcho Boxes",      color = ESP.HideBoxColor },
    { key = "Gold",          title = "Gold Piles",        color = ESP.GoldColor },
    { key = "Petal",         title = "Lotus Petals",      color = ESP.PetalColor },
}
local TRACER_TITLE_TO_KEY = {}
for _, c in ipairs(TRACER_CATEGORIES) do
    TRACER_TITLE_TO_KEY[c.title] = c.key
    Tracers.Colors[c.key] = c.color
    Tracers.Targets[c.key] = true
end
--============================================================
-- ARROWS  (стрелки к Rush/предметам когда отвернулся)
--============================================================
-- Показывает стрелки по краям экрана к объектам из ESP:
--  * Rush/близкие монстры — красная стрелка "спасайся"
--  * Пропущенные предметы (когда ты отвернулся) — стрелка в сторону
-- Полностью гибкая настройка: вкл/выкл, что показывать, размер, расстояние.
local Arrows = {
    Enabled = false,
    ShowRush = true,          -- стрелки на Rush/Ambush/близких монстров
    ShowMissedItems = true,   -- стрелки на предметы, которые ты пропустил
    MaxDistance = 85,         -- макс. дистанция для Rush-стрелки
    ItemDistance = 30,        -- макс. дистанция для предмета
    ArrowSize = 24,           -- размер стрелки (px)
    MaxArrows = 5,            -- максимум стрелок одновременно
    RushColor = Color3.fromRGB(255, 60, 60),
    ItemColor = Color3.fromRGB(255, 215, 0),
    EdgePadding = 60,         -- отступ от края экрана (px)
    TickInterval = 0.1,       -- интервал пересборки кандидатов (сек, 10 раз/сек достаточно)
    LastTick = 0,             -- timestamp последней пересборки
    CachedCandidates = {},    -- кэш кандидатов между пересборками
}
local ArrowRegistry = {}
local BuildArrow, RemoveAllArrows
local ArrowConn = nil
local function GetArrowAngle(worldPos, cam)
    -- угол между направлением камеры и объектом
    -- ФИКС СТРЕЛКА СЗАДИ: rel.Z > 0 означает объект ЗА КАМЕРОЙ.
    -- Для объекта сзади корректно вычисляем угол как atan2(X, -Z),
    -- но с rel.Z > 0 мы получаем -Z отрицательный, что даёт угол с |deg| > 90,
    -- что корректно поворачивает шеврон в сторону объекта (включая назад).
    -- Пример: объект прямо сзади → X=0, Z=+1 → atan2(0, -1) = 180° → шеврон вниз.
    -- Пример: объект сзади-слева → X<0, Z>0 → угол ~ -135° → шеврон влево-вниз.
    local cf = cam.CFrame
    local rel = cf:PointToObjectSpace(worldPos)
    return math.atan2(rel.X, -rel.Z)
end
-- Возвра щает true если объект на экране (в Frustrum камеры и не за спиной)
local function IsOnScreen(worldPos, cam)
    local sp, onScreen = cam:WorldToViewportPoint(worldPos)
    return onScreen and sp.Z > 0
end
local function ArrowsTick()
    if Library.Unloaded or not Arrows.Enabled then
        if next(ArrowRegistry) ~= nil then RemoveAllArrows() end
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- THROTTLE: пересобираем кандидатов не чаще TickInterval (антилаг).
    -- Сама отрисовка стрелок всё равно каждый кадр (позиции обновляются быстро),
    -- но сортировка/поиск объектов — только 10 раз/сек.
    local now = tick()
    if now - Arrows.LastTick < Arrows.TickInterval then
        -- используем кэш
        local candidates = Arrows.CachedCandidates
        if candidates then
            local shown = math.min(#candidates, Arrows.MaxArrows)
            -- Пул стрелок
            local currentCount = 0
            for _, arrow in pairs(ArrowRegistry) do
                if arrow and arrow.Parent then currentCount += 1 end
            end
            while currentCount > shown do
                local maxIdx = 0
                for idx in pairs(ArrowRegistry) do
                    if idx > maxIdx then maxIdx = idx end
                end
                if maxIdx > 0 and ArrowRegistry[maxIdx] then
                    pcall(function() ArrowRegistry[maxIdx]:Destroy() end)
                    ArrowRegistry[maxIdx] = nil
                end
                currentCount -= 1
            end
            for i = 1, shown do
                local c = candidates[i]
                -- получаем ТЕКУЩУЮ позицию и дистанцию каждый кадр (по ссылке)
                local pos = (c.ref and c.ref.Parent and ((c.ref:IsA("BasePart") and c.ref.Position)
                    or (c.ref:IsA("Model") and c.ref.PrimaryPart and c.ref.PrimaryPart.Position))) or nil
                if pos then
                    local dist = LocalPlayer:DistanceFromCharacter(pos)
                    -- ФИКС: предмет подобран → дистанция ~0 или parent nil → стрелка ПРОПАДАЕТ
                    -- (раньше `not onScreen` вызывало "стрелка исчезает" — но для подобранного
                    -- предмета ESPRegistry обновляется и объект удаляется, поэтому стрелка
                    -- просто не рисуется если позиция nil)
                    local shouldRender = false
                    if c.isRush then
                        shouldRender = (dist <= Arrows.MaxDistance and c.ref:GetAttribute("Inactive") ~= true)
                    else
                        -- предмет считается "пропущенным" если он ЗА ЭКРАНОМ (не onScreen)
                        local _, onScreen = cam:WorldToScreenPoint(pos)
                        shouldRender = (dist <= Arrows.ItemDistance and not onScreen)
                    end
                    if shouldRender then
                        local angle = GetArrowAngle(pos, cam)
                        local deg = math.deg(angle)
                        BuildArrow(i, deg, c.color, dist, c.isRush, c.name)
                    end
                end
            end
        end
        return
    end
    Arrows.LastTick = now

    -- Собираем кандидатов — Rush ВСЕГДА приоритетнее предметов
    -- Allowlist предметов: только реальные подбираемые предметы (НЕ HideBox — это укрытие)
    local ALLOWED_ITEM_CATEGORIES = {
        ["Item"] = true, ["Key"] = true, ["Book"] = true, ["Gold"] = true, ["Petal"] = true,
        ["Pizza"] = true, ["Fuse"] = true, ["Breaker"] = true,
    }
    local rushCandidates = {}
    local itemCandidates = {}
    if Arrows.ShowRush then
        for _, Entity in ipairs(Workspace:GetChildren()) do
            if Entity and StaticDB.EntityDistances[Entity.Name] and Entity.PrimaryPart then
                -- храним ССЫЛКУ на Entity, а не снимок позиции (чтобы обновлялась каждый кадр)
                table.insert(rushCandidates, {
                    ref = Entity,
                    color = Arrows.RushColor,
                    isRush = true,
                    name = StaticDB.MONSTER_NAMES[Entity.Name] or Entity.Name,
                })
            end
        end
    end
    if Arrows.ShowMissedItems then
        for adornee, data in pairs(ESPRegistry) do
            if adornee and adornee.Parent then
                local cat = data.category
                if cat and ALLOWED_ITEM_CATEGORIES[cat] then
                    -- храним ССЫЛКУ на adornee (BasePart/Model), позиция обновляется каждый кадр
                    table.insert(itemCandidates, {
                        ref = adornee,
                        color = Arrows.ItemColor,
                        isRush = false,
                        name = data.displayName or adornee.Name,
                    })
                end
            end
        end
    end

    -- Rush приоритет: сначала все Rush (сортировка по дистанции), затем предметы
    -- ВАЖНО: сортируем по ТЕКУЩЕЙ дистанции (не снимку) — чтобы приоритет обновлялся
    table.sort(rushCandidates, function(a, b)
        local ap = a.ref.PrimaryPart and a.ref.PrimaryPart.Position or Vector3.zero
        local bp = b.ref.PrimaryPart and b.ref.PrimaryPart.Position or Vector3.zero
        local ad = LocalPlayer:DistanceFromCharacter(ap)
        local bd = LocalPlayer:DistanceFromCharacter(bp)
        return ad < bd
    end)
    table.sort(itemCandidates, function(a, b)
        local ap = (a.ref:IsA("BasePart") and a.ref.Position) or (a.ref:IsA("Model") and a.ref.PrimaryPart and a.ref.PrimaryPart.Position) or Vector3.zero
        local bp = (b.ref:IsA("BasePart") and b.ref.Position) or (b.ref:IsA("Model") and b.ref.PrimaryPart and b.ref.PrimaryPart.Position) or Vector3.zero
        local ad = LocalPlayer:DistanceFromCharacter(ap)
        local bd = LocalPlayer:DistanceFromCharacter(bp)
        return ad < bd
    end)
    local candidates = {}
    for _, c in ipairs(rushCandidates) do table.insert(candidates, c) end
    for _, c in ipairs(itemCandidates) do table.insert(candidates, c) end
    -- сохраняем в кэш для следующего кадра
    Arrows.CachedCandidates = candidates
    local shown = math.min(#candidates, Arrows.MaxArrows)

    -- ПУЛ СТРЕЛОК: создаём/убираем только разницу, не пересоздаём каждый кадр (антилаг)
    -- Скрываем лишние стрелки, которые больше не нужны
    local currentCount = 0
    for _, arrow in pairs(ArrowRegistry) do
        if arrow and arrow.Parent then currentCount += 1 end
    end
    while currentCount > shown do
        -- удаляем самую последнюю
        local maxIdx = 0
        for idx in pairs(ArrowRegistry) do
            if idx > maxIdx then maxIdx = idx end
        end
        if maxIdx > 0 and ArrowRegistry[maxIdx] then
            pcall(function() ArrowRegistry[maxIdx]:Destroy() end)
            ArrowRegistry[maxIdx] = nil
        end
        currentCount -= 1
    end
    -- Создаём/обновляем только нужное количество стрелок
    for i = 1, shown do
        local c = candidates[i]
        -- получаем ТЕКУЩУЮ позицию и дистанцию каждый кадр (по ссылке)
        local pos = (c.ref and c.ref.Parent and ((c.ref:IsA("BasePart") and c.ref.Position)
            or (c.ref:IsA("Model") and c.ref.PrimaryPart and c.ref.PrimaryPart.Position))) or nil
        if pos then
            local dist = LocalPlayer:DistanceFromCharacter(pos)
            -- rush: проверяем дистанцию каждый кадр
            if c.isRush then
                if dist <= Arrows.MaxDistance and c.ref:GetAttribute("Inactive") ~= true then
                    local angle = GetArrowAngle(pos, cam)
                    local deg = math.deg(angle)
                    BuildArrow(i, deg, c.color, dist, c.isRush, c.name)
                end
            else
                -- ФИКС: предмет подобран → стрелка пропадает (ESPRegistry удалит adornee
                -- при подборе, позиция станет nil → `if pos then` уже не рисует стрелку).
                -- Для подобранного предмета дистанция ~0 (в руке) → тоже не рисуем.
                if dist <= Arrows.ItemDistance and dist > 3 then
                    local _, onScreen = cam:WorldToScreenPoint(pos)
                    if not onScreen then
                        local angle = GetArrowAngle(pos, cam)
                        local deg = math.deg(angle)
                        BuildArrow(i, deg, c.color, dist, c.isRush, c.name)
                    end
                end
            end
        end
    end
end
-- Функции создания/удаления стрелок — инициализируются ниже (нужен доступ к GUI)
local ArrowGui = nil
local function GetArrowGui()
    if ArrowGui then return ArrowGui end
    local gui = Instance.new("ScreenGui")
    gui.Name = "_LOLHAX_Arrows"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 996
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local okp = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not okp or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    ArrowGui = gui
    return gui
end
BuildArrow = function(index, deg, color, dist, isRush, name)
    -- ФИКС СТРЕЛКА СЗАДИ: для объекта за спиной (deg > 90 или deg < -90)
    -- шеврон должен указывать В СТОРОНУ объекта, в том числе "назад" по экрану.
    -- Позиция контейнера остаётся на окружности, glyph.Rotation = deg —
    -- шеврон поворачивается в сторону объекта, включая объекты за спиной.
    local gui = GetArrowGui()
    local arrow = gui:FindFirstChild("Arrow" .. index)
    if not arrow then
        arrow = Instance.new("Frame")
        arrow.Name = "Arrow" .. index
        arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        arrow.Size = UDim2.fromOffset(Arrows.ArrowSize, Arrows.ArrowSize)
        arrow.BackgroundTransparency = 1
        arrow.BorderSizePixel = 0
        arrow.Parent = gui
        -- ГЛИФ (контейнер шеврона): вращается вместе со стрелкой,
        -- но НЕ содержит label (текст всегда горизонтален)
        local glyph = Instance.new("Frame")
        glyph.Name = "Glyph"
        glyph.AnchorPoint = Vector2.new(0.5, 0.5)
        glyph.Position = UDim2.new(0.5, 0, 0.5, 0)
        glyph.Size = UDim2.fromScale(1, 1)
        glyph.BackgroundTransparency = 1
        glyph.BorderSizePixel = 0
        glyph.Parent = arrow
        -- шеврон из двух повернутых линий
        local wing1 = Instance.new("Frame")
        wing1.Name = "Wing1"
        wing1.AnchorPoint = Vector2.new(0.5, 0.5)
        wing1.Position = UDim2.new(0.5, 0, 0.5, -Arrows.ArrowSize * 0.2)
        wing1.Size = UDim2.fromOffset(math.max(2, math.floor(Arrows.ArrowSize * 0.08)), math.floor(Arrows.ArrowSize * 0.45))
        wing1.BorderSizePixel = 0
        wing1.Rotation = 35
        wing1.Parent = glyph
        local w1c = Instance.new("UICorner")
        w1c.CornerRadius = UDim.new(1, 0)
        w1c.Parent = wing1
        local wing2 = Instance.new("Frame")
        wing2.Name = "Wing2"
        wing2.AnchorPoint = Vector2.new(0.5, 0.5)
        wing2.Position = UDim2.new(0.5, 0, 0.5, Arrows.ArrowSize * 0.2)
        wing2.Size = UDim2.fromOffset(math.max(2, math.floor(Arrows.ArrowSize * 0.08)), math.floor(Arrows.ArrowSize * 0.45))
        wing2.BorderSizePixel = 0
        wing2.Rotation = -35
        wing2.Parent = glyph
        local w2c = Instance.new("UICorner")
        w2c.CornerRadius = UDim.new(1, 0)
        w2c.Parent = wing2
        local label = Instance.new("TextLabel")
        label.Name = "Dist"
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, 0, 1, 4)
        label.Size = UDim2.fromOffset(100, 16)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextColor3 = color
        label.TextStrokeTransparency = 0.5
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = arrow
        ArrowRegistry[index] = arrow
    end
    -- Обновляем позицию контейнера (стрелка указывает в сторону объекта)
    local cam = Workspace.CurrentCamera
    local vs = cam.ViewportSize
    local cx, cy = vs.X / 2, vs.Y / 2
    local rad = math.rad(deg)
    local radius = math.min(vs.X, vs.Y) / 2 - Arrows.EdgePadding
    local x = cx + math.sin(rad) * radius
    local y = cy - math.cos(rad) * radius
    arrow.Position = UDim2.new(0, x, 0, y)
    arrow.Size = UDim2.fromOffset(Arrows.ArrowSize, Arrows.ArrowSize)
    -- вращаем ГЛИФ (шеврон), а label остаётся горизонтальным
    -- deg напрямую задаёт направление шеврона: 0 = вверх, 90 = вправо,
    -- 180 = вниз (объект прямо сзади), -90 = влево.
    -- Для объекта ЗА СПИНОЙ (deg > 90 / < -90) шеврон поворачивается
    -- в сторону объекта, включая направление "назад" по экрану.
    local glyph = arrow:FindFirstChild("Glyph")
    if glyph then glyph.Rotation = deg end
    -- обновляем позиции крыльев (AR_Size)
    for _, wingName in ipairs({"Wing1", "Wing2"}) do
        local wing = glyph and glyph:FindFirstChild(wingName)
        if wing then
            wing.Size = UDim2.fromOffset(math.max(2, math.floor(Arrows.ArrowSize * 0.08)), math.floor(Arrows.ArrowSize * 0.45))
            if wingName == "Wing1" then
                wing.Position = UDim2.new(0.5, 0, 0.5, -Arrows.ArrowSize * 0.2)
            else
                wing.Position = UDim2.new(0.5, 0, 0.5, Arrows.ArrowSize * 0.2)
            end
        end
    end
    -- цвет и текст (теперь с именем объекта) + обновляем размеры крыльев (AR_Size)
    if glyph then
        for _, wingName in ipairs({"Wing1", "Wing2"}) do
            local wing = glyph:FindFirstChild(wingName)
            if wing then
                wing.BackgroundColor3 = color
                local stroke = wing:FindFirstChild("UIStroke")
                if stroke then stroke.Color = color end
            end
        end
    end
    local label = arrow:FindFirstChild("Dist")
    if label then
        label.Text = tostring(math.floor(dist + 0.5)) .. "m " .. (name or "")
        label.TextColor3 = color
    end
end
RemoveAllArrows = function()
    for i, arrow in pairs(ArrowRegistry) do
        if arrow and arrow.Parent then arrow:Destroy() end
        ArrowRegistry[i] = nil
    end
end
local StartArrows, StopArrows
StartArrows = function()
    if ArrowConn then return end
    GetArrowGui()
    -- BindToRenderStep с приоритетом AFTER Camera, чтобы не было дерганья UI
    -- при быстром повороте камеры (RenderStepped отстаёт от камеры).
    pcall(function()
        RunService:BindToRenderStep("_LOLHAX_ArrowsTick", Enum.RenderPriority.Camera.Value + 1, function()
            pcall(ArrowsTick)
        end)
        ArrowConn = true -- флаг, что рендер-степ подключён
    end)
    if not ArrowConn then
        -- fallback: обычный RenderStepped (если BindToRenderStep недоступен)
        ArrowConn = RunService.RenderStepped:Connect(function()
            pcall(ArrowsTick)
        end)
        TrackConnection(ArrowConn)
    end
end
StopArrows = function()
    if ArrowConn then
        pcall(function()
            if ArrowConn == true then
                RunService:UnbindFromRenderStep("_LOLHAX_ArrowsTick")
            else
                ArrowConn:Disconnect()
            end
        end)
        ArrowConn = nil
    end
    RemoveAllArrows()
    if ArrowGui then
        pcall(function() ArrowGui:Destroy() end)
        ArrowGui = nil
    end
end
--============================================================
-- CROSSHAIR  (рендер: 5 стилей как в CS2 + обычный перекрестие)
--============================================================
local Crosshair = {
    Enabled = false,
    Style = "Default",     -- Default | Square | Circle | HVH | Quadrant
    Color = Color3.fromRGB(170, 110, 255),
    Rainbow = false,
    Size = 10,             -- длина линий / радиус
    Thickness = 2,
    Gap = 4,
    DotSize = 0,
    Transparency = 0,
    Outline = 1,
    OutlineColor = Color3.fromRGB(0, 0, 0),
    CircleRadius = 15,      -- отдельный радиус для Circle (не конфликтует с Size)
}
local CrosshairGui, CrosshairRoot, CrosshairParts = nil, nil, {}
local RainbowHue = 0
local function RemoveCrosshair()
    for _, p in ipairs(CrosshairParts) do
        if p and p.Parent then p:Destroy() end
    end
    CrosshairParts = {}
    CrosshairRoot = nil
    if CrosshairGui then
        pcall(function() CrosshairGui:Destroy() end)
        CrosshairGui = nil
    end
end
local function GetCrosshairGui()
    if CrosshairGui then return CrosshairGui end
    local gui = Instance.new("ScreenGui")
    gui.Name = "_LOLHAX_Crosshair"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 995
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local okp = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not okp or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    -- КОРНЕВОЙ ФРЕЙМ по центру экрана: позиции всех частей задаются как ЛОКАЛЬНЫЕ
    -- оффсеты от центра, поэтому автоматически реагируют на изменение размера вьюпорта.
    local root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Size = UDim2.fromOffset(0, 0)
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Parent = gui
    CrosshairGui = gui
    CrosshairRoot = root
    return gui
end
local function NewPart(name)
    local p = Instance.new("Frame")
    p.Name = name
    p.AnchorPoint = Vector2.new(0.5, 0.5)
    p.BackgroundTransparency = Crosshair.Transparency
    p.BorderSizePixel = 0
    p.BackgroundColor3 = Crosshair.Color
    p.Parent = (CrosshairRoot or GetCrosshairGui():FindFirstChild("Root"))
    table.insert(CrosshairParts, p)
    return p
end
local function NewStroke(p, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Crosshair.OutlineColor
    stroke.Thickness = thickness or Crosshair.Outline
    stroke.Transparency = 0
    stroke.Parent = p
    return stroke
end
local function UpdateCrosshairColor(dt)
    if Crosshair.Rainbow then
        -- rainbow: плавный перелив, скорость НЕ зависит от FPS (используем dt)
        RainbowHue = (RainbowHue + (dt or 1/60) * 0.3) % 1
        Crosshair.RainbowColor = Color3.fromHSV(RainbowHue, 1, 1)
    end
end
local function RenderCrosshair(dt)
    if Library.Unloaded or not Crosshair.Enabled then
        if #CrosshairParts > 0 then RemoveCrosshair() end
        return
    end
    -- скрываем стандартный прицел Doors КАЖДЫЙ КАДР (он может появиться позже)
    pcall(HideDefaultCrosshair)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vs = cam.ViewportSize
    local cx, cy = vs.X / 2, vs.Y / 2
    UpdateCrosshairColor(dt)
    local color = Crosshair.Rainbow and (Crosshair.RainbowColor or Crosshair.Color) or Crosshair.Color
    -- BuildKey теперь включает ВСЕ геометрические параметры (Gap, Size, Thickness, DotSize, Outline, Style)
    -- КРИТИЧЕСКИЙ ФИКС: раньше Gap не было в ключе, поэтому изменение Gap не обновляло геометрию.
    local buildKey = string.format("%s|%d|%d|%d|%d|%d|%d",
        Crosshair.Style, Crosshair.DotSize, Crosshair.Outline,
        Crosshair.Size, Crosshair.Thickness, Crosshair.Gap,
        Crosshair.CircleRadius or Crosshair.Size)
    if CrosshairParts.BuildKey ~= buildKey then
        RemoveCrosshair()
        CrosshairParts.BuildKey = buildKey
    end
    local S = Crosshair.Size
    local T = Crosshair.Thickness
    local G = Crosshair.Gap
    local style = Crosshair.Style
    -- создаем части один раз (только если ещё не созданы)
    if #CrosshairParts == 0 then
    -- Позиции задаются как ЛОКАЛЬНЫЕ оффсеты от центра экрана (Root).
    -- cx/cy больше не используются — всё автоматически центрируется при изменении вьюпорта.
    -- Common center dot (для всех стилей, не только Circle/HVH)
    local dotPart = nil
    if Crosshair.DotSize > 0 then
        dotPart = NewPart("Dot")
        dotPart.Position = UDim2.fromOffset(0, 0)
        dotPart.Size = UDim2.fromOffset(Crosshair.DotSize, Crosshair.DotSize)
        dotPart.BackgroundColor3 = color
        if Crosshair.Outline > 0 then NewStroke(dotPart) end
    end
    if style == "Default" then
        -- 4 линии вверх/вниз/влево/вправо с зазором (локальные оффсеты)
        local up = NewPart("Up"); up.Position = UDim2.fromOffset(0, -(G + S/2)); up.Size = UDim2.fromOffset(T, S)
        local down = NewPart("Down"); down.Position = UDim2.fromOffset(0, G + S/2); down.Size = UDim2.fromOffset(T, S)
        local left = NewPart("Left"); left.Position = UDim2.fromOffset(-(G + S/2), 0); left.Size = UDim2.fromOffset(S, T)
        local right = NewPart("Right"); right.Position = UDim2.fromOffset(G + S/2, 0); right.Size = UDim2.fromOffset(S, T)
        if Crosshair.Outline > 0 then NewStroke(up); NewStroke(down); NewStroke(left); NewStroke(right) end
    elseif style == "Square" then
        -- квадрат: 4 линии образуют квадрат с зазором внутри
        local w = S * 2 + G * 2
        local h = S * 2 + G * 2
        local top = NewPart("Top"); top.Position = UDim2.fromOffset(0, -(G + S)); top.Size = UDim2.fromOffset(w, T)
        local bottom = NewPart("Bottom"); bottom.Position = UDim2.fromOffset(0, G + S); bottom.Size = UDim2.fromOffset(w, T)
        local leftS = NewPart("LeftS"); leftS.Position = UDim2.fromOffset(-(G + S), 0); leftS.Size = UDim2.fromOffset(T, h)
        local rightS = NewPart("RightS"); rightS.Position = UDim2.fromOffset(G + S, 0); rightS.Size = UDim2.fromOffset(T, h)
        if Crosshair.Outline > 0 then NewStroke(top); NewStroke(bottom); NewStroke(leftS); NewStroke(rightS) end
    elseif style == "Circle" then
        -- круг: ДВА СЛОЯ. Outline — нижний (шире), цветной ring — верхний.
        -- Это даёт корректный контур, а не два stroke на одном контуре.
        local R = Crosshair.CircleRadius
        if Crosshair.Outline > 0 then
            -- нижний слой: outline (шире на 2*Outline, рисуется OutlineColor)
            local o = NewPart("CircleOutline")
            o.Position = UDim2.fromOffset(0, 0)
            o.Size = UDim2.fromOffset(R * 2, R * 2)
            o.BackgroundTransparency = 1
            o.BorderSizePixel = 0
            local oc = Instance.new("UICorner")
            oc.CornerRadius = UDim.new(1, 0)
            oc.Parent = o
            local oStroke = Instance.new("UIStroke")
            oStroke.Name = "CircleOutlineStroke"
            oStroke.Color = Crosshair.OutlineColor
            oStroke.Thickness = Crosshair.Thickness + 2 * Crosshair.Outline
            oStroke.Transparency = Crosshair.Transparency
            oStroke.Parent = o
        end
        -- верхний слой: цветной ring
        local c = NewPart("Circle")
        c.Position = UDim2.fromOffset(0, 0)
        c.Size = UDim2.fromOffset(R * 2, R * 2)
        c.BackgroundTransparency = 1
        c.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = c
        local stroke = Instance.new("UIStroke")
        stroke.Name = "CircleStroke"
        stroke.Color = color
        stroke.Thickness = Crosshair.Thickness
        stroke.Transparency = Crosshair.Transparency
        stroke.Parent = c
    elseif style == "HVH" then
        -- HVH: крест без зазора в центре
        local hLine = NewPart("H"); hLine.Position = UDim2.fromOffset(0, 0); hLine.Size = UDim2.fromOffset(S * 2, T)
        local vLine = NewPart("V"); vLine.Position = UDim2.fromOffset(0, 0); vLine.Size = UDim2.fromOffset(T, S * 2)
        if Crosshair.Outline > 0 then NewStroke(hLine); NewStroke(vLine) end
    elseif style == "Quadrant" then
        -- Quadrant: 4 угла (скобки)
        local q = S / 2
        -- верх-лево
        local tlH = NewPart("TL_H"); tlH.Position = UDim2.fromOffset(-(G + q/2), -(G + q)); tlH.Size = UDim2.fromOffset(q, T)
        local tlV = NewPart("TL_V"); tlV.Position = UDim2.fromOffset(-(G + q), -(G + q/2)); tlV.Size = UDim2.fromOffset(T, q)
        -- верх-право
        local trH = NewPart("TR_H"); trH.Position = UDim2.fromOffset(G + q/2, -(G + q)); trH.Size = UDim2.fromOffset(q, T)
        local trV = NewPart("TR_V"); trV.Position = UDim2.fromOffset(G + q, -(G + q/2)); trV.Size = UDim2.fromOffset(T, q)
        -- низ-лево
        local blH = NewPart("BL_H"); blH.Position = UDim2.fromOffset(-(G + q/2), G + q); blH.Size = UDim2.fromOffset(q, T)
        local blV = NewPart("BL_V"); blV.Position = UDim2.fromOffset(-(G + q), G + q/2); blV.Size = UDim2.fromOffset(T, q)
        -- низ-право
        local brH = NewPart("BR_H"); brH.Position = UDim2.fromOffset(G + q/2, G + q); brH.Size = UDim2.fromOffset(q, T)
        local brV = NewPart("BR_V"); brV.Position = UDim2.fromOffset(G + q, G + q/2); brV.Size = UDim2.fromOffset(T, q)
        if Crosshair.Outline > 0 then
            for _, p in ipairs({tlH, tlV, trH, trV, blH, blV, brH, brV}) do NewStroke(p) end
        end
    end
    end
    -- применяем цвет ко всем частям — ОТДЕЛЬНО outline (не перекрашиваем OutlineColor)
    for _, p in ipairs(CrosshairParts) do
        if p and p.Parent then
            if p.Name == "Circle" then
                -- Circle: цветной ring (stroke в цвет прицела)
                local stroke = p:FindFirstChild("CircleStroke")
                if stroke then stroke.Color = color end
            elseif p.Name == "CircleOutline" then
                -- CircleOutline: рисуется OutlineColor (не перекрашивается)
                local oStroke = p:FindFirstChild("CircleOutlineStroke")
                if oStroke then oStroke.Color = Crosshair.OutlineColor end
            else
                -- остальные: только заливка (outline остаётся OutlineColor)
                if p:IsA("Frame") then p.BackgroundColor3 = color end
                local stroke = p:FindFirstChild("UIStroke")
                if stroke then stroke.Color = Crosshair.OutlineColor end
            end
        end
    end
    -- обновляем прозрачность динамически (не только при создании) — ЕДИНООБРАЗНО
    for _, p in ipairs(CrosshairParts) do
        if p and p.Parent and p:IsA("Frame") then
            local stroke = p:FindFirstChild("UIStroke")
                or p:FindFirstChild("CircleStroke")
                or p:FindFirstChild("CircleOutlineStroke")
            if p.Name == "Circle" or p.Name == "CircleOutline" then
                if stroke then stroke.Transparency = Crosshair.Transparency end
            else
                p.BackgroundTransparency = Crosshair.Transparency
                if stroke then stroke.Transparency = Crosshair.Transparency end
            end
        end
    end
end
-- рендерим прицел только при изменении опций (не каждый кадр, чтобы не лагало)
local CrosshairRenderConn = nil
--========================================
-- СКРЫТИЕ СТАНДАРТНОГО ПРИЦЕЛА DOORS (если он есть в PlayerGui)
--========================================
-- Doors рисует прицел через обычный ImageLabel/GUI в PlayerGui. Когда включён наш Crosshair,
-- мы скрываем ВСЕ его элементы (ImageLabel с центрированным размером, Name ~= наши).
-- Не трогаем остальные GUI игрока, только прицелы.
local HiddenDefaultCrosshairs = {}
-- ФИКС СТАНДАРТНОГО ПРИЦЕЛА DOORS: прицел лежит по пути
-- Players.(Игрок).PlayerGui.MainUI.MainFrame.Crosshair (или похожем).
-- Ищем именно в MainUI.MainFrame и скрываем ВСЁ дерево Crosshair.
local function HideDefaultCrosshair()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    local mainUI = pg:FindFirstChild("MainUI")
    if not mainUI then return end
    local mainFrame = mainUI:FindFirstChild("MainFrame")
    if not mainFrame then return end
    local crosshair = mainFrame:FindFirstChild("Crosshair")
    if crosshair then
        if HiddenDefaultCrosshairs[crosshair] == nil then
            HiddenDefaultCrosshairs[crosshair] = true
        end
        crosshair.Visible = false
        -- дополнительно: все дочерние ImageLabel внутри Crosshair тоже скрыть
        for _, child in ipairs(crosshair:GetDescendants()) do
            if child:IsA("ImageLabel") then
                if HiddenDefaultCrosshairs[child] == nil then
                    HiddenDefaultCrosshairs[child] = true
                end
                child.Visible = false
            end
        end
    end
    -- fallback: если не нашли по точному пути, ищем все ImageLabel с центрированной позицией
    local function scan(instance, seen)
        seen = seen or {}
        if seen[instance] then return end
        seen[instance] = true
        if instance:IsA("ImageLabel") then
            local ap = instance.AnchorPoint
            local pos = instance.Position
            local size = instance.Size
            local isCenter = (ap.X == 0.5 and ap.Y == 0.5)
                or (pos.X.Scale == 0.5 and pos.Y.Scale == 0.5)
            local isSmall = size.X.Scale <= 0.1 and size.Y.Scale <= 0.1
            local isPixel = size.X.Offset <= 80 and size.Y.Offset <= 80
            if isCenter and (isSmall or isPixel) then
                if HiddenDefaultCrosshairs[instance] == nil then
                    HiddenDefaultCrosshairs[instance] = true
                end
                instance.Visible = false
            end
        end
        if instance:IsA("GuiObject") then
            for _, child in ipairs(instance:GetChildren()) do
                scan(child, seen)
            end
        end
    end
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            scan(gui)
        end
    end
end
local function RestoreDefaultCrosshair()
    for instance, _ in pairs(HiddenDefaultCrosshairs) do
        if instance and instance.Parent then
            pcall(function()
                instance.Visible = true
            end)
        end
    end
    table.clear(HiddenDefaultCrosshairs)
end
local function StartCrosshair()
    if CrosshairRenderConn then return end
    -- СКРЫВАЕМ стандартный прицел Doors (как только включается наш Crosshair)
    pcall(HideDefaultCrosshair)
    -- BindToRenderStep с приоритетом AFTER Camera, чтобы не было дерганья UI
    -- при быстром повороте камеры (RenderStepped отстаёт от камеры).
    pcall(function()
        RunService:BindToRenderStep("_LOLHAX_CrosshairRender", Enum.RenderPriority.Camera.Value + 1, function(dt)
            pcall(RenderCrosshair, dt)
        end)
        CrosshairRenderConn = true -- флаг, что рендер-степ подключён
    end)
    if not CrosshairRenderConn then
        -- fallback: обычный RenderStepped
        CrosshairRenderConn = RunService.RenderStepped:Connect(function(dt)
            pcall(RenderCrosshair, dt)
        end)
        TrackConnection(CrosshairRenderConn)
    end
end
local function StopCrosshair()
    if CrosshairRenderConn then
        pcall(function()
            if CrosshairRenderConn == true then
                RunService:UnbindFromRenderStep("_LOLHAX_CrosshairRender")
            else
                CrosshairRenderConn:Disconnect()
            end
        end)
        CrosshairRenderConn = nil
    end
    RemoveCrosshair()
    -- ВОССТАНАВЛИВАЕМ стандартный прицел Doors (выключили наш Crosshair)
    pcall(RestoreDefaultCrosshair)
end
task.spawn(function()
    -- Проверяем, есть ли Drawing API
    pcall(function()
        if Drawing and Drawing.new then
            local test = Drawing.new("Line")
            if test then
                Tracers.UseDrawing = true
                pcall(function() test:Remove() end)
            end
        end
    end)
    local function EnsureGui()
        if Tracers.Gui and Tracers.Gui.Parent then return Tracers.Gui end
        local gui = Instance.new("ScreenGui")
        gui.Name = "_LOLHAX_Tracers"
        gui.IgnoreGuiInset = true          -- координаты совпадают с WorldToViewportPoint
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 5
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local okp = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        if not okp or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
        Tracers.Gui = gui
        return gui
    end
    local function NewLine()
        local line = table.remove(Tracers.Free)
        if line then return line end
        line = { stamp = 0, visible = false }
        if Tracers.UseDrawing then
            local ok, d = pcall(function() return Drawing.new("Line") end)
            if ok and d then
                d.Visible = false
                line.d = d
                return line
            end
            Tracers.UseDrawing = false
        end
        local f = Instance.new("Frame")
        f.Name = "Tracer"
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BorderSizePixel = 0
        f.Visible = false
        f.Parent = EnsureGui()
        line.f = f
        return line
    end
    local function HideLine(line)
        if not line.visible then return end
        line.visible = false
        if line.d then pcall(function() line.d.Visible = false end) end
        if line.f then line.f.Visible = false end
    end
    local function SetLine(line, from, to, color)
        local thickness = Tracers.Thickness
        local transp = Tracers.Transparency
        if line.d then
            local d = line.d
            d.From = from
            d.To = to
            d.Color = color
            d.Thickness = thickness
            d.Transparency = 1 - transp   -- в Drawing API Transparency = непрозрачность
            if not line.visible then d.Visible = true end
        elseif line.f then
            local f = line.f
            local delta = to - from
            local len = delta.Magnitude
            f.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
            f.Size = UDim2.fromOffset(len, thickness)
            f.Rotation = math.deg(math.atan2(delta.Y, delta.X))
            f.BackgroundColor3 = color
            f.BackgroundTransparency = transp
            if not line.visible then f.Visible = true end
        end
        line.visible = true
    end
    local function ReleaseLine(adornee)
        local line = Tracers.Pool[adornee]
        if not line then return end
        Tracers.Pool[adornee] = nil
        HideLine(line)
        if #Tracers.Free < 64 then
            table.insert(Tracers.Free, line)
        else
            if line.d then pcall(function() line.d:Remove() end) end
            if line.f then pcall(function() line.f:Destroy() end) end
        end
    end
    Tracers.HideAll = function()
        for adornee in pairs(Tracers.Pool) do ReleaseLine(adornee) end
    end
    Tracers.DestroyAll = function()
        Tracers.HideAll()
        for _, line in ipairs(Tracers.Free) do
            if line.d then pcall(function() line.d:Remove() end) end
            if line.f then pcall(function() line.f:Destroy() end) end
        end
        Tracers.Free = {}
        if Tracers.Gui then pcall(function() Tracers.Gui:Destroy() end) Tracers.Gui = nil end
    end
    -- Точка цели в мире для записи ESP
    local function GetTargetPosition(adornee, data)
        local cat = data.category
        if cat == "Player" and adornee:IsA("Model") then
            local hrp = adornee:FindFirstChild("HumanoidRootPart")
            if hrp then return hrp.Position end
        end
        local t = data.target
        if t and t.Parent then
            if t:IsA("BasePart") then return t.Position end
            if t:IsA("Attachment") then return t.WorldPosition end
        end
        if adornee:IsA("BasePart") then return adornee.Position end
        if adornee:IsA("Model") then
            local part = data.tpart
            if not part or not part.Parent then
                part = adornee.PrimaryPart or adornee:FindFirstChildWhichIsA("BasePart", true)
                data.tpart = part
            end
            if part then return part.Position end
            local ok, piv = pcall(function() return adornee:GetPivot().Position end)
            if ok then return piv end
        end
        return nil
    end
    local function GetOrigin(cam)
        local vs = cam.ViewportSize
        local mode = Tracers.Origin
        if mode == "Bottom" then return Vector2.new(vs.X / 2, vs.Y - 2)
        elseif mode == "Top" then return Vector2.new(vs.X / 2, 2)
        elseif mode == "Mouse" then return UserInputService:GetMouseLocation()
        end
        return Vector2.new(vs.X / 2, vs.Y / 2) -- Crosshair (центр экрана = прицел)
    end
    -- Если объект за спиной — рисуем линию к краю экрана в его сторону
    local function ProjectOffscreen(origin, sp, vs)
        local dir = Vector2.new(sp.X, sp.Y) - origin
        if sp.Z < 0 then dir = -dir end
        if dir.Magnitude < 1 then dir = Vector2.new(0, 1) end
        dir = dir.Unit
        local margin = 6
        local tx = math.huge
        local ty = math.huge
        if dir.X > 0 then tx = (vs.X - margin - origin.X) / dir.X elseif dir.X < 0 then tx = (margin - origin.X) / dir.X end
        if dir.Y > 0 then ty = (vs.Y - margin - origin.Y) / dir.Y elseif dir.Y < 0 then ty = (margin - origin.Y) / dir.Y end
        local tmin = math.min(tx, ty)
        if tmin == math.huge or tmin < 0 then tmin = 0 end
        return origin + dir * tmin
    end
    local function Step()
        if Library.Unloaded then return end
        if not Tracers.Enabled or not ESP.Enabled then
            if next(Tracers.Pool) then Tracers.HideAll() end
            return
        end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local vs = cam.ViewportSize
        local origin = GetOrigin(cam)
        local char = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        local myPos = (myRoot and myRoot.Position) or cam.CFrame.Position
        Tracers.Frame += 1
        local frame = Tracers.Frame
        local maxDist = Tracers.MaxDistance or 1000
        for adornee, data in pairs(ESPRegistry) do
            local cat = data.category
            if Tracers.Targets[cat] and adornee.Parent then
                local pos = GetTargetPosition(adornee, data)
                if pos and (pos - myPos).Magnitude <= maxDist then
                    local sp, onScreen = cam:WorldToViewportPoint(pos)
                    local target
                    if sp.Z > 0 then
                        target = Vector2.new(sp.X, sp.Y)
                    elseif Tracers.ShowOffscreen then
                        target = ProjectOffscreen(origin, sp, vs)
                    end
                    if target then
                        local line = Tracers.Pool[adornee]
                        if not line then
                            line = NewLine()
                            Tracers.Pool[adornee] = line
                        end
                        line.stamp = frame
                        local color = Tracers.UseESPColor and data.color or Tracers.Colors[cat] or data.color or Color3.new(1, 1, 1)
                        SetLine(line, origin, target, color)
                    end
                end
            end
        end
        for adornee, line in pairs(Tracers.Pool) do
            if line.stamp ~= frame then
                if not adornee.Parent or not ESPRegistry[adornee] then
                    ReleaseLine(adornee)
                else
                    HideLine(line)
                end
            end
        end
    end
    Tracers.Start = function()
        Tracers.Enabled = true
        if Tracers.Bound then return end
        Tracers.Bound = true
        -- сразу после обновления камеры, чтобы линии не "отставали" от поворота
        local ok = pcall(function()
            RunService:BindToRenderStep("LOLHAX_Tracers", Enum.RenderPriority.Camera.Value + 1, function()
                local s, err = pcall(Step)
                if not s and STATE.AutoInteractDebug then warn("[LOLHAX] tracers:", err) end
            end)
        end)
        if not ok then
            Tracers.Conn = RunService.RenderStepped:Connect(function() pcall(Step) end)
            TrackConnection(Tracers.Conn)
        end
    end
    Tracers.Stop = function()
        Tracers.Enabled = false
        Tracers.Bound = false
        pcall(function() RunService:UnbindFromRenderStep("LOLHAX_Tracers") end)
        if Tracers.Conn then pcall(function() Tracers.Conn:Disconnect() end) Tracers.Conn = nil end
        Tracers.HideAll()
    end
end)
--============================================================
-- DOOR REACH  (открытие дверей на расстоянии)
--============================================================
-- Логика как у Abysall: пока дверь не открылась (звук Door.Open не проигрался),
-- и игрок ближе Distance — шлём ClientOpen:FireServer() не чаще 1 раза в 0.1 сек.
-- Вместо отдельного Heartbeat на каждую дверь — один общий цикл ~10 раз в секунду
-- по дверям загруженных комнат (их всего несколько), поэтому нагрузки почти нет.
local DoorReach = {
    Enabled = false,
    Distance = 75,
    LastFire = setmetatable({}, { __mode = "k" }),
    Opened = setmetatable({}, { __mode = "k" }),
    Hooked = setmetatable({}, { __mode = "k" }),
    LastTick = 0,
}
task.spawn(function()
    local function HookDoorOpened(doorModel, doorPart)
        if DoorReach.Hooked[doorModel] then return end
        local snd = doorPart:FindFirstChild("Open")
        if snd and snd:IsA("Sound") then
            DoorReach.Hooked[doorModel] = true
            snd.Played:Once(function() DoorReach.Opened[doorModel] = true end)
        end
    end
    local function TryDoor(doorModel, myRoot, now)
        if not doorModel or DoorReach.Opened[doorModel] then return end
        local doorPart = doorModel:FindFirstChild("Door")
        local remote = doorModel:FindFirstChild("ClientOpen")
        if not doorPart or not remote or not doorPart:IsA("BasePart") then return end
        HookDoorOpened(doorModel, doorPart)
        if (doorPart.Position - myRoot.Position).Magnitude >= DoorReach.Distance then return end
        if now - (DoorReach.LastFire[doorModel] or 0) <= 0.1 then return end
        DoorReach.LastFire[doorModel] = now
        pcall(function() remote:FireServer() end)
    end
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded or not DoorReach.Enabled then return end
        local now = tick()
        if now - DoorReach.LastTick < 0.1 then return end
        DoorReach.LastTick = now
        local char = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local rooms = Workspace:FindFirstChild("CurrentRooms")
        if not rooms then return end
        for _, room in ipairs(rooms:GetChildren()) do
            local door = room:FindFirstChild("Door")
            if door then pcall(TryDoor, door, myRoot, now) end
        end
    end))
end)
--============================================================
-- MISC FUNCTIONS  (кнопки: GLITCH / LOBBY / PLAY AGAIN / KILL)
--============================================================
local MiscFuncs = {}
do
    local function GetRemotes()
        return ReplicatedStorage:FindFirstChild("RemotesFolder")
    end
    local function SetAnchored(value)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then pcall(function() hrp.Anchored = value end) end
    end
    -- KILL
    MiscFuncs.Kill = function()
        STATE.SelfKilled = true
        local done = false
        if type(replicatesignal) == "function" then
            done = pcall(function() replicatesignal(LocalPlayer.Kill) end)
        end
        if not done then
            local rf = GetRemotes()
            if rf and rf:FindFirstChild("Underwater") then
                rf.Underwater:FireServer(true)
            else
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum.Health = 0 end
            end
        end
    end
    -- PLAY AGAIN
    MiscFuncs.PlayAgain = function()
        local rf = GetRemotes()
        local remote = rf and rf:FindFirstChild("PlayAgain")
        if not remote then
            Notify("Play Again", "Remote 'PlayAgain' not found.", 4, true)
            return
        end
        SafeCall(function() remote:FireServer() end)
    end
    -- LOBBY
    MiscFuncs.Lobby = function()
        local rf = GetRemotes()
        local remote = rf and rf:FindFirstChild("Lobby")
        if not remote then
            Notify("Lobby", "Remote 'Lobby' not found.", 4, true)
            return
        end
        SafeCall(function() remote:FireServer() end)
    end
    -- GLITCH: телепорт на 100 studs назад от направления взгляда, затем каждые 0.2 c
    -- HumanoidRootPart.Anchored = true, через 0.2 c = false (повтор, пока не нажать снова)
    MiscFuncs.StopGlitch = function()
        if not STATE.GlitchActive then return end
        STATE.GlitchActive = false
        SetAnchored(false)
    end
    MiscFuncs.StartGlitch = function()
        if STATE.GlitchActive then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        if not hrp or not cam then
            Notify("Glitch", "Character not found.", 3, true)
            return
        end
        -- "назад от прицела": против направления камеры, по горизонтали (чтобы не улететь вверх/под землю)
        local look = cam.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude < 0.01 then
            local hl = hrp.CFrame.LookVector
            flat = Vector3.new(hl.X, 0, hl.Z)
        end
        hrp.CFrame = hrp.CFrame - flat.Unit * 100
        STATE.GlitchActive = true
        SetAnchored(true)
        -- смещение за один телепорт: 100 studs назад от прицела и 1000 studs вниз
        local offset = flat.Unit * 100000 + Vector3.new(0, 1000000, 0)
        task.spawn(function()
            while STATE.GlitchActive and not Library.Unloaded do
                hrp.CFrame = hrp.CFrame + offset
                task.wait(0.1)
                SetAnchored(false)
                hrp.CFrame = hrp.CFrame + offset
                task.wait(0.1)
            end
            SetAnchored(false)
        end)
    end
    MiscFuncs.ToggleGlitch = function()
        if STATE.GlitchActive then
            MiscFuncs.StopGlitch()
            Notify("Glitch OFF", "Anchor pulse stopped.", 3, true)
        else
            MiscFuncs.StartGlitch()
            if STATE.GlitchActive then
                Notify("Glitch ON", "Press GLITCH again to stop.", 4, true)
            end
        end
    end
end
--============================================================
-- UI
--============================================================
local UI = {}
task.spawn(function()
    local Window = Fluent:CreateWindow({
        Title = "LOLHAX LITE",
        SubTitle = LocalPlayer.Name,
        TabWidth = 150,
        Size = UDim2.fromOffset(620, 520),
        Acrylic = false,          -- true = блюр, на части экзекуторов глючит
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.RightShift,
    })
    -- GUI скрыт, пока играет заставка; затем появляется с анимацией
    pcall(function() if Fluent.GUI then Fluent.GUI.Enabled = false end end)
    task.spawn(function()
        while not STATE.SplashReady and not Library.Unloaded do task.wait() end
        if Library.Unloaded then return end
        pcall(function() if Fluent.GUI then Fluent.GUI.Enabled = true end end)
        pcall(function()
            local root = Window.Root
            local sc = Instance.new("UIScale")
            sc.Scale = 0.8
            sc.Parent = root
            local t = TweenService:Create(sc, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
            t:Play()
            t.Completed:Once(function() pcall(function() sc:Destroy() end) end)
        end)
    end)
    local Tabs = {
        Main     = Window:AddTab({ Title = "Main",        Icon = "user" }),
        Interact = Window:AddTab({ Title = "Interact",    Icon = "hand" }),
        Anti     = Window:AddTab({ Title = "Anti Entity", Icon = "shield" }),
        Visuals  = Window:AddTab({ Title = "Visuals",     Icon = "eye" }),
        ESP      = Window:AddTab({ Title = "ESP",         Icon = "crosshair" }),
        Misc     = Window:AddTab({ Title = "Misc",        Icon = "wrench" }),
        Settings = Window:AddTab({ Title = "Settings",    Icon = "settings" }),
    }
    -- Хелперы
    -- Fluent вызывает OnChanged сразу при регистрации. Этот враппер пропускает
    -- первый (холостой) вызов, как это было в Linoria.
    local function Bind(element, fn)
        local first = true
        element:OnChanged(function(...)
            if first then return end
            fn(...)
        end)
        first = false
    end
    -- Секции регистрируются по вкладкам (нужно для плавного появления функций при смене вкладки)
    local TabSections = {}
    local function Sec(tabKey, title)
        local section = Tabs[tabKey]:AddSection(title)
        TabSections[tabKey] = TabSections[tabKey] or {}
        table.insert(TabSections[tabKey], section)
        return section
    end
    local KeybindRegistry = {}
    -- Замена AddToggle + AddKeyPicker(SyncToggleState = true).
    -- Toggle-режим: клавиша переключает тумблер, GetState() = toggle.Value.
    -- Hold-режим:   тумблер "взводит" функцию, GetState() = клавиша зажата.
    local function AddToggleKey(section, id, cfg, keyId, keyCfg)
        local toggle = section:AddToggle(id, cfg)
        local mode = keyCfg.Mode or "Toggle"
        local kb = section:AddKeybind(keyId, {
            Title = keyCfg.Title or cfg.Title,
            Mode = mode,
            Default = keyCfg.Default,
            Callback = function()
                if mode == "Toggle" then
                    toggle:SetValue(not toggle.Value)
                end
            end,
        })
        if mode == "Toggle" then
            kb.GetState = function() return toggle.Value end
        end
        table.insert(KeybindRegistry, {
            toggleId = id,
            keyId = keyId,
            name = (tostring(keyCfg.Title or cfg.Title):gsub(" key.*$", "")),
            mode = mode,
        })
        return toggle, kb
    end
    -- Небольшая пауза между секциями меню: сборка не забивает один кадр целиком
    local function Yield() RunService.Heartbeat:Wait() end
    --============================================================
    -- KEYBIND LIST  (замена "Show Keybinds" из Linoria; цвета следуют теме Fluent)
    --============================================================
    local KeybindList = {
        Gui = nil, Frame = nil, Stroke = nil, Title = nil,
        Rows = {}, Visible = false, Last = 0, Theme = nil, Palette = nil,
    }
    -- Палитры под встроенные темы Fluent (подтверждено в исходнике Fluent):
    --   Dark, Darker, Light, Aqua, Amethyst, Rose
    -- Текст списка биндов ВСЕГДА фиолетовый (активные — яркий, неактивные — приглушённый),
    -- от темы зависит только фон.
    local KB_PURPLE     = Color3.fromRGB(170, 110, 255)
    local KB_PURPLE_OFF = Color3.fromRGB(120, 90, 170)
    local KB_PALETTES = {
        Dark     = { bg = Color3.fromRGB(22, 22, 22),    accent = KB_PURPLE, off = KB_PURPLE_OFF },
        Darker   = { bg = Color3.fromRGB(7, 7, 7),       accent = KB_PURPLE, off = KB_PURPLE_OFF },
        Light    = { bg = Color3.fromRGB(236, 236, 236), accent = KB_PURPLE, off = KB_PURPLE_OFF },
        Aqua     = { bg = Color3.fromRGB(12, 30, 32),    accent = KB_PURPLE, off = KB_PURPLE_OFF },
        Amethyst = { bg = Color3.fromRGB(24, 12, 38),    accent = KB_PURPLE, off = KB_PURPLE_OFF },
        Rose     = { bg = Color3.fromRGB(38, 12, 20),    accent = KB_PURPLE, off = KB_PURPLE_OFF },
    }
    local function GetKBPalette()
        local name = Fluent.Theme
        if type(name) ~= "string" then
            local opt = Options.InterfaceTheme
            name = opt and opt.Value
        end
        return KB_PALETTES[name] or KB_PALETTES.Dark, name
    end
    local function ApplyKBTheme()
        if not KeybindList.Gui then return end
        local pal, name = GetKBPalette()
        KeybindList.Theme = name
        KeybindList.Palette = pal
        KeybindList.Frame.BackgroundColor3 = pal.bg
        KeybindList.Stroke.Color = pal.accent
        KeybindList.Title.TextColor3 = pal.accent
    end
    local function UpdateKeybindList()
        if not KeybindList.Gui then return end
        local pal = KeybindList.Palette or KB_PALETTES.Dark
        for _, row in ipairs(KeybindList.Rows) do
            local e = row.entry
            local toggle, kb = Options[e.toggleId], Options[e.keyId]
            if toggle and kb then
                local active = false
                local okState, st = pcall(function() return toggle.Value and kb:GetState() end)
                if okState then active = st and true or false end
                row.label.Text = string.format("[%s]  %s  (%s)", tostring(kb.Value or "None"), e.name, e.mode)
                row.label.TextColor3 = active and pal.accent or pal.off
            end
        end
    end
    local function BuildKeybindList()
        if KeybindList.Gui then return end
        local pal = GetKBPalette()
        local gui = Instance.new("ScreenGui")
        gui.Name = "_LOLHAX_Keybinds"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 998
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local okp = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        if not okp or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
        local frame = Instance.new("Frame")
        frame.Name = "List"
        frame.Position = UDim2.new(0, 14, 0.4, 0)
        frame.Size = UDim2.fromOffset(250, 0)
        frame.AutomaticSize = Enum.AutomaticSize.Y
        frame.BackgroundColor3 = pal.bg
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame
        local stroke = Instance.new("UIStroke")
        stroke.Color = pal.accent
        stroke.Thickness = 1
        stroke.Transparency = 0.4
        stroke.Parent = frame
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 6)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = frame
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 2)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = frame
        local title = Instance.new("TextLabel")
        title.Active = true
        title.LayoutOrder = 0
        title.Size = UDim2.new(1, 0, 0, 22)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "Keybinds  (drag)"
        title.TextSize = 14
        title.TextColor3 = pal.accent
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = frame
        for i, entry in ipairs(KeybindRegistry) do
            local lbl = Instance.new("TextLabel")
            lbl.LayoutOrder = i
            lbl.Size = UDim2.new(1, 0, 0, 18)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Gotham
            lbl.Text = entry.name
            lbl.TextSize = 13
            lbl.TextColor3 = pal.off
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = frame
            table.insert(KeybindList.Rows, { entry = entry, label = lbl })
        end
        -- перетаскивание за заголовок
        local dragging, dragStart, startPos = false, nil, nil
        title.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        TrackConnection(UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end))
        KeybindList.Gui = gui
        KeybindList.Frame = frame
        KeybindList.Stroke = stroke
        KeybindList.Title = title
        ApplyKBTheme()
    end
    -- обновление ~7 раз в секунду и только пока список виден; заодно следим за сменой темы
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded or not KeybindList.Visible then return end
        if tick() - KeybindList.Last < 0.15 then return end
        KeybindList.Last = tick()
        local _, name = GetKBPalette()
        if name ~= KeybindList.Theme then pcall(ApplyKBTheme) end
        pcall(UpdateKeybindList)
    end))
    --============================================================
    -- WATERMARK  (плашка: FPS | пинг | LOLHAX | ник | аватар)
    --============================================================
    -- Лёгкая плашка в стиле оверлея: обновляется 2 раза в секунду и меняет текст,
    -- только если значение изменилось. FPS считается по кадрам за полсекунды (RenderStepped),
    -- пинг берётся из Stats (Data Ping), а если он недоступен — из GetNetworkPing().
    local Watermark = {
        Gui = nil, Frame = nil, FrameStroke = nil, Visible = false,
        Frames = 0, Acc = 0, Fps = 0, Ping = 0,
        Labels = {}, Bars = {}, PingDot = nil, NameItems = {}, Avatar = nil,
        Dragged = false,
    }
    local WM_ACCENT = Color3.fromRGB(170, 110, 255)
    local WM_BG     = Color3.fromRGB(18, 18, 22)
    local WM_TEXT   = Color3.fromRGB(235, 235, 240)
    local WM_DIM    = Color3.fromRGB(70, 70, 80)
    local WM_GOOD   = Color3.fromRGB(90, 220, 120)
    local WM_MID    = Color3.fromRGB(240, 200, 70)
    local WM_BAD    = Color3.fromRGB(240, 80, 80)
    local WM_POSITIONS = {
        ["Top Right"]    = { anchor = Vector2.new(1, 0), pos = UDim2.new(1, -10, 0, 8) },
        ["Top Left"]     = { anchor = Vector2.new(0, 0), pos = UDim2.new(0, 10, 0, 8) },
        ["Bottom Right"] = { anchor = Vector2.new(1, 1), pos = UDim2.new(1, -10, 1, -10) },
        ["Bottom Left"]  = { anchor = Vector2.new(0, 1), pos = UDim2.new(0, 10, 1, -10) },
    }
    local function WMGetPing()
        local ms
        pcall(function()
            local item = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
            ms = item:GetValue()
        end)
        if not ms or ms <= 0 then
            pcall(function() ms = LocalPlayer:GetNetworkPing() * 1000 end)
        end
        return math.floor((ms or 0) + 0.5)
    end
    local function WMApplyPosition()
        if not Watermark.Frame then return end
        local key = (Options.WM_Position and Options.WM_Position.Value) or "Top Right"
        local p = WM_POSITIONS[key] or WM_POSITIONS["Top Right"]
        Watermark.Frame.AnchorPoint = p.anchor
        Watermark.Frame.Position = p.pos
        Watermark.Dragged = false
    end
    local function WMApplyOptions()
        if not Watermark.Frame then return end
        local showName = not (Toggles.WM_ShowName and Toggles.WM_ShowName.Value == false)
        local showAvatar = not (Toggles.WM_ShowAvatar and Toggles.WM_ShowAvatar.Value == false)
        for _, it in ipairs(Watermark.NameItems) do it.Visible = showName end
        if Watermark.Avatar then Watermark.Avatar.Visible = showAvatar end
    end
    local function BuildWatermark()
        if Watermark.Gui then return end
        local gui = Instance.new("ScreenGui")
        gui.Name = "_LOLHAX_Watermark"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = false
        gui.DisplayOrder = 997
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local okp = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        if not okp or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
        -- BLUR / ACRYLIC: визуальный эффект ПРЯМО НА ПЛАШКЕ (не глобальный!).
        -- ПРОБЛЕМА: Lighting.BlurEffect размывает ВЕСЬ ЭКРАН, а не только область плашки.
        -- РЕШЕНИЕ: НЕ создаём BlurEffect в Lighting вообще.
        -- Вместо этого, визуальный acrylic-стиль на самой плашке:
        --   * полупрозрачный фон плашки (BackgroundTransparency уже стоит)
        --   * полупрозрачный UIStroke с цветом фиолетового акцента (уже есть)
        --   * UIStroke с толстым бордюром с акцентным цветом (можно "blur" имитировать)
        -- УБРАНО: BlurEffect (было "весь экран блюрит но не Watermark").
        local frame = Instance.new("Frame")
        frame.Name = "Pill"
        frame.Active = true
        frame.Size = UDim2.fromOffset(0, 28)
        frame.AutomaticSize = Enum.AutomaticSize.X
        frame.BackgroundColor3 = WM_BG
        frame.BackgroundTransparency = 0.15
        frame.BorderSizePixel = 0
        frame.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = frame
        -- ГЛОБАЛЬНЫЙ BLUR УБРАН: больше не создаём BlurEffect в Lighting.
        -- Вместо него: acrylic-стиль на самой плашке через UIStroke с акцентным цветом
        -- + полупрозрачный фон. Опция WM_Blur / WM_BlurSize больше ничего не размывает
        -- глобально, поэтому "весь экран блюрит но не Watermark" больше не происходит.
        local stroke = Instance.new("UIStroke")
        stroke.Color = WM_ACCENT
        stroke.Transparency = 0.6
        stroke.Thickness = 1
        stroke.Parent = frame
        Watermark.FrameStroke = stroke -- храним ссылку для WMApplyEffectState
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.PaddingRight = UDim.new(0, 5)
        pad.Parent = frame
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 7)
        layout.Parent = frame
        local order = 0
        local function NextOrder() order += 1 return order end
        local function Label(text, color, bold)
            local l = Instance.new("TextLabel")
            l.LayoutOrder = NextOrder()
            l.BackgroundTransparency = 1
            l.AutomaticSize = Enum.AutomaticSize.X
            l.Size = UDim2.fromOffset(0, 18)
            l.Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold
            l.TextSize = 13
            l.TextColor3 = color or WM_TEXT
            l.Text = text
            l.Parent = frame
            return l
        end
        local function Separator()
            local s = Instance.new("Frame")
            s.LayoutOrder = NextOrder()
            s.Size = UDim2.fromOffset(1, 14)
            s.BackgroundColor3 = WM_DIM
            s.BorderSizePixel = 0
            s.Parent = frame
            return s
        end
        -- значок FPS: 3 полоски, как у сигнала
        local bars = Instance.new("Frame")
        bars.LayoutOrder = NextOrder()
        bars.Size = UDim2.fromOffset(13, 12)
        bars.BackgroundTransparency = 1
        bars.Parent = frame
        for i = 1, 3 do
            local b = Instance.new("Frame")
            b.AnchorPoint = Vector2.new(0, 1)
            b.Position = UDim2.new(0, (i - 1) * 5, 1, 0)
            b.Size = UDim2.fromOffset(3, 4 * i)
            b.BackgroundColor3 = WM_ACCENT
            b.BorderSizePixel = 0
            b.Parent = bars
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0, 1)
            bc.Parent = b
            Watermark.Bars[i] = b
        end
        Watermark.Labels.Fps = Label("-- FPS")
        Separator()
        -- значок пинга: цветная точка (зелёная / жёлтая / красная)
        local dot = Instance.new("Frame")
        dot.LayoutOrder = NextOrder()
        dot.Size = UDim2.fromOffset(8, 8)
        dot.BackgroundColor3 = WM_GOOD
        dot.BorderSizePixel = 0
        dot.Parent = frame
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = dot
        Watermark.PingDot = dot
        Watermark.Labels.Ping = Label("-- ms")
        Separator()
        Label("", WM_ACCENT, true)
        local nameSep = Separator()
        local nameLabel = Label(LocalPlayer.Name, WM_TEXT)
        Watermark.NameItems = { nameSep, nameLabel }
        -- аватар игрока (круглый)
        local avatar = Instance.new("ImageLabel")
        avatar.LayoutOrder = NextOrder()
        avatar.Size = UDim2.fromOffset(20, 20)
        avatar.BackgroundColor3 = WM_DIM
        avatar.BorderSizePixel = 0
        avatar.Image = ""
        avatar.Parent = frame
        local ac = Instance.new("UICorner")
        ac.CornerRadius = UDim.new(1, 0)
        ac.Parent = avatar
        local as = Instance.new("UIStroke")
        as.Color = WM_ACCENT
        as.Thickness = 1
        as.Transparency = 0.3
        as.Parent = avatar
        Watermark.Avatar = avatar
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if ok and img and avatar.Parent then avatar.Image = img end
        end)
        -- перетаскивание мышью/пальцем
        local dragging, dragStart, startPos = false, nil, nil
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        TrackConnection(UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
                Watermark.Dragged = true
            end
        end))
        Watermark.Gui = gui
        Watermark.Frame = frame
        WMApplyPosition()
        WMApplyOptions()
    end
    -- ЕДИНАЯ ФУНКЦИЯ СОСТОЯНИЯ ВИЗУАЛЬНОГО ACRYLIC ЭФФЕКТА НА ПЛАШКЕ.
    -- Все точки изменения (build, SetWatermarkVisible, WM_Blur, WM_BlurSize, config load)
    -- вызывают ЭТУ функцию, поэтому нет конфликтов, когда эффект включается при скрытом watermark.
    -- ГЛОБАЛЬНЫЙ BlurEffect УБРАН: больше не размываем весь экран. Вместо него
    -- acrylic-стиль — это уже цвет фона плашки + акцентный UIStroke. Опции WM_Blur /
    -- WM_BlurSize теперь управляют ТОЛЬКО визуальным эффектом плашки (не глобально).
    local function WMApplyEffectState()
        local active = Watermark.Visible
            and (Toggles.WM_Blur and Toggles.WM_Blur.Value)
            and ((Options.WM_BlurSize and Options.WM_BlurSize.Value or 12) > 0)
        -- Управляем acrylic-стилем плашки: меняем фон (потемнее при active) и толщину stroke.
        if Watermark.Frame then
            if active then
                -- «акриловый» вид: чуть более непрозрачный фон + толще бордюр
                Watermark.Frame.BackgroundTransparency = 0.05
                if Watermark.FrameStroke then
                    Watermark.FrameStroke.Transparency = 0.35
                    local size = (Options.WM_BlurSize and Options.WM_BlurSize.Value) or 12
                    Watermark.FrameStroke.Thickness = math.clamp(size / 8, 1, 3)
                end
            else
                -- обычный вид
                Watermark.Frame.BackgroundTransparency = 0.15
                if Watermark.FrameStroke then
                    Watermark.FrameStroke.Transparency = 0.6
                    Watermark.FrameStroke.Thickness = 1
                end
            end
        end
    end
    local function UpdateWatermark()
        -- Акриловый эффект управляется ЕДИНОЙ функцией состояния (не каждый кадр).
        -- BlurEffect — глобальный постпроцессинг, поэтому достаточно включить/выключить
        -- при изменении состояния (WMApplyEffectState вызывается из всех точек).
        local fps, ping = Watermark.Fps, Watermark.Ping
        local fpsText = tostring(fps) .. " FPS"
        if Watermark.Labels.Fps.Text ~= fpsText then Watermark.Labels.Fps.Text = fpsText end
        local pingText = tostring(ping) .. " ms"
        if Watermark.Labels.Ping.Text ~= pingText then Watermark.Labels.Ping.Text = pingText end
        -- полоски FPS: 3 = 55+, 2 = 30+, 1 = ниже
        local lit = (fps >= 55 and 3) or (fps >= 30 and 2) or 1
        for i, b in ipairs(Watermark.Bars) do
            b.BackgroundTransparency = (i <= lit) and 0 or 0.7
        end
        Watermark.PingDot.BackgroundColor3 = (ping <= 120 and WM_GOOD) or (ping <= 250 and WM_MID) or WM_BAD
    end
    -- счётчик кадров + обновление плашки 2 раза в секунду (только пока она видна)
    TrackConnection(RunService.RenderStepped:Connect(function(dt)
        if Library.Unloaded or not Watermark.Visible then return end
        Watermark.Frames += 1
        Watermark.Acc += dt
        if Watermark.Acc < 0.5 then return end
        Watermark.Fps = math.floor(Watermark.Frames / Watermark.Acc + 0.5)
        Watermark.Frames, Watermark.Acc = 0, 0
        Watermark.Ping = WMGetPing()
        pcall(UpdateWatermark)
    end))
    local function SetWatermarkVisible(v)
        Watermark.Visible = v
        if v then
            BuildWatermark()
            Watermark.Gui.Enabled = true
            Watermark.Frames, Watermark.Acc = 0, 0
            WMApplyEffectState() -- применяем acrylic-стиль при включении
        elseif Watermark.Gui then
            Watermark.Gui.Enabled = false
            WMApplyEffectState() -- сбрасываем acrylic-стиль при выключении
        end
    end
    --============================================================
    -- MAIN TAB
    --============================================================
    local Character = Sec("Main", "Character")
    Character:AddSlider("MY_SpeedBoost_Slider", {
        Title = "Speed Boost", Min = 0, Max = 100, Default = 0, Rounding = 0,
    })
    AddToggleKey(Character, "MY_SpeedBoost", {
        Title = "Enable Speed Boost", Default = false,
        Description = "Increases your walkspeed by the specified amount.",
    }, "MY_SpeedBoost_K", { Title = "Speed Boost key", Default = "H", Mode = "Toggle" })
    AddToggleKey(Character, "MY_PositionSpoof", {
        Title = "Position Spoof", Default = false,
        Description = "Makes your character appear underground on the server, protecting you from rush-like entities.",
    }, "MY_PositionSpoof_K", { Title = "Position Spoof key", Default = "B", Mode = "Toggle" })
    Character:AddToggle("MY_FigureGodmode", {
        Title = "Figure Godmode", Default = false,
        Description = "Prevents 'Figure' from hurting you.",
    })
    Character:AddToggle("MY_RemoveAcceleration", {
        Title = "Remove Acceleration", Default = false,
        Description = "Prevents your character from sliding while moving.",
    })
    Character:AddSlider("MY_FOV", {
        Title = "Field of View", Min = 70, Max = 120, Default = 70, Rounding = 0,
    })
    local ExtraChar = Sec("Main", "Character Extra")
    AddToggleKey(ExtraChar, "MY_AirLock", { Title = "Air Lock", Default = false },
        "MY_AirLock_K", { Title = "Air Lock key", Default = "F", Mode = "Toggle" })
    ExtraChar:AddSlider("MY_AirLock_Height", {
        Title = "Fly Height", Min = 1, Max = 50, Default = 5, Rounding = 0,
    })
    ExtraChar:AddToggle("EB_CrouchSpoof", { Title = "Crouch Spoof", Default = false })
    AddToggleKey(ExtraChar, "EB_ACManipulate", { Title = "Anti-Cheat Manipulation", Default = false },
        "EB_ACManipulate_K", { Title = "Anti-Cheat Manipulate key (hold)", Default = "T", Mode = "Hold" })
    AddToggleKey(ExtraChar, "MY_VelocityManip", { Title = "Velocity Manipulation", Default = false },
        "MY_VelocityManip_K", { Title = "Velocity Manipulation key", Default = "C", Mode = "Toggle" })
    ExtraChar:AddDropdown("MY_VelocityManip_Mode", {
        Title = "Manipulation Mode", Values = { "Velocity", "Pivot" }, Default = "Velocity", Multi = false,
    })
    local DoorReachSec = Sec("Main", "Door Reach")
    DoorReachSec:AddToggle("MY_DoorReach", {
        Title = "Door Reach", Default = false,
        Description = "Открывает двери на расстоянии (дальность — Distance).",
    })
    DoorReachSec:AddSlider("MY_DoorReach_Dist", {
        Title = "Distance", Min = 5, Max = 100, Default = 75, Rounding = 0,
    })
    Yield()
    --============================================================
    -- INTERACT TAB
    --============================================================
    local InteractSec = Sec("Interact", "Interact")
    InteractSec:AddToggle("GA_InstantInteract", { Title = "Instant Interact", Default = false })
    InteractSec:AddToggle("GA_InfiniteItems", { Title = "Infinite Items", Default = false })
    InteractSec:AddDropdown("GA_InfiniteItems_List", {
        Title = "Item List",
        Values = { "Lockpick", "SkeletonKey", "Shears", "Multitool", "Key", "KeyBackdoor", "KeyElectrical", "KeyIron", "GeneratorFuse" },
        Default = { "Lockpick", "SkeletonKey", "Shears", "Multitool" },
        Multi = true,
    })
    AddToggleKey(InteractSec, "GA_AutoInteract", { Title = "Automatic Interact", Default = false },
        "GA_AutoInteract_K", { Title = "Auto Interact key (hold)", Default = "R", Mode = "Hold" })
    InteractSec:AddToggle("AS_Anchor", { Title = "Auto Solve Anchors", Default = false })
    InteractSec:AddDropdown("GA_AutoInteract_Options", {
        Title = "Automatic Interact Options",
        Values = { "Use Lockpick ( Doors )", "Use Lockpick ( Other )", "Ignore Light Sources", "Ignore Can-Die" },
        Default = { "Ignore Light Sources" },
        Multi = true,
    })
    InteractSec:AddSlider("GA_AutoInteract_Range", {
        Title = "Range Multiplier", Min = 1, Max = 2, Default = 1, Rounding = 1,
    })
    InteractSec:AddToggle("GA_AutoInteract_Debug", { Title = "Auto Interact Debug (Console)", Default = false })
    local NotifySec = Sec("Interact", "Notifying")
    NotifySec:AddToggle("GN_Enabled", { Title = "Enabled", Default = false })
    NotifySec:AddToggle("GN_NotificationSound", { Title = "Play Sound", Default = false })
    NotifySec:AddSlider("GN_NotificationSound_Volume", {
        Title = "Sound Volume", Min = 1, Max = 10, Default = 2, Rounding = 1,
    })
    NotifySec:AddToggle("GN_HaltWarning", { Title = "Halt Warning", Default = false })
    NotifySec:AddToggle("GN_Entities", { Title = "Entity Notifying", Default = false })
    NotifySec:AddToggle("GN_LotusPetal", { Title = "Lotus Petal Notify", Default = false })
    NotifySec:AddDropdown("GN_NotificationAlignment", {
        Title = "Horizontal Alignment", Values = { "Left", "Center", "Right" }, Default = "Center", Multi = false,
    })
    NotifySec:AddSlider("GN_NotificationDPISize", {
        Title = "Size Multiplier", Min = 0.8, Max = 3, Default = 1, Rounding = 1,
    })
    NotifySec:AddButton({
        Title = "Test Notify",
        Callback = function()
            Notify("This is a test notification.", "Lorem ipsum dolor sit amet.", 2.5, true)
        end,
    })
    Yield()
    --============================================================
    -- ANTI ENTITY TAB
    --============================================================
    local AntiSec = Sec("Anti", "Anti Entity")
    AntiSec:AddToggle("ES_AntiEyes", { Title = "Anti Eyes", Default = false })
    AntiSec:AddToggle("ES_AntiLookman", { Title = "Anti Lookman", Default = false })
    AntiSec:AddToggle("ES_NoScreechDamage", {
        Title = "No Screech Damage", Default = false,
        Description = "Prevents 'Screech' from hurting you.",
    })
    local BypassSec = Sec("Anti", "Bypass")
    BypassSec:AddToggle("AE_BypassDupe",            { Title = "Bypass Dupe", Default = false })
    BypassSec:AddToggle("AE_BypassGloombatEggs",    { Title = "Bypass Gloombat Eggs", Default = false })
    BypassSec:AddToggle("AE_BypassGiggle",          { Title = "Bypass Giggle", Default = false })
    BypassSec:AddToggle("AE_BypassSeekObstructions",{ Title = "Bypass Seek Obstructions", Default = false })
    BypassSec:AddToggle("AE_BypassVacuum",          { Title = "Bypass Vacuum", Default = false })
    BypassSec:AddToggle("AE_BypassKillbricks",      { Title = "Bypass Killbricks", Default = false })
    BypassSec:AddToggle("AE_BypassSeekingWall",     { Title = "Bypass Seeking Wall", Default = false })
    BypassSec:AddToggle("AE_BypassSnare",           { Title = "Bypass Snare", Default = false })
    BypassSec:AddToggle("AE_BypassBanana",          { Title = "Bypass Banana", Default = false })
    BypassSec:AddToggle("AE_BypassJeff",            { Title = "Bypass Jeff", Default = false })
    local HaltRansomSec = Sec("Anti", "Halt / Ransom / Highlight")
    HaltRansomSec:AddToggle("ER_RemoveHalt",      { Title = "Remove Halt", Default = false })
    HaltRansomSec:AddToggle("ER_NoHaltDamage",    { Title = "No Halt Damage", Default = false })
    HaltRansomSec:AddToggle("VR_NoRansomOverlays",{ Title = "No Ransom Overlays", Default = false })
    HaltRansomSec:AddToggle("ER_NoRansomDamage",  { Title = "Anti Ransom Damage [Full Wipe]", Default = false })
    HaltRansomSec:AddToggle("MH_Enabled",         { Title = "Monster Highlight (Archives)", Default = false })
    local DisablerSec = Sec("Anti", "Disabler / Fly / Noclip")
    DisablerSec:AddToggle("AC_Bypass", { Title = "Disabler", Default = false })
    DisablerSec:AddDropdown("AC_Bypass_Mode", {
        Title = "Disabler Mode", Values = { "Ladder", "Chair" }, Default = "Ladder", Multi = false,
    })
    DisablerSec:AddToggle("AHB_Enabled", { Title = "AutoHeartbeatMinigame", Default = false })
    AddToggleKey(DisablerSec, "FLY_Enabled", { Title = "🔒 Fly  🔒 LOCKED", Default = false },
        "FLY_Enabled_K", { Title = "Fly key", Default = "G", Mode = "Toggle" })
    DisablerSec:AddSlider("FLY_Speed", {
        Title = "Fly Speed", Min = 10, Max = 200, Default = 50, Rounding = 0,
    })
    AddToggleKey(DisablerSec, "NOCLIP_Enabled", { Title = "🔒 Noclip (bind O)  🔒 LOCKED", Default = false },
        "NOCLIP_Enabled_K", { Title = "Noclip key", Default = "O", Mode = "Toggle" })
    Yield()
    --============================================================
    -- VISUALS TAB
    --============================================================
    local VisualsWorld = Sec("Visuals", "World")
    VisualsWorld:AddToggle("VW_Ambience", { Title = "Fullbright", Default = false })
    VisualsWorld:AddColorpicker("VW_Ambience_C", {
        Title = "Ambience Color", Default = Color3.fromRGB(255, 255, 255),
    })
        VisualsWorld:AddToggle("VW_NoFog", { Title = "No Fog", Default = false })
    VisualsWorld:AddToggle("VW_NoShaking", { Title = "No Shaking", Default = false })
    --============================================================
    -- ARROWS  (гибкие настройки, см. выше в разделе ARROWS)
    --============================================================
    local ArrowSec = Sec("Visuals", "Arrows")
    ArrowSec:AddToggle("AR_Enabled", {
        Title = "Arrows", Default = false,
        Description = "Стрелки к Rush/близким монстрам и пропущенным предметам за экраном.",
    })
    ArrowSec:AddToggle("AR_ShowRush", { Title = "Show Rush/Monsters", Default = true })
    ArrowSec:AddToggle("AR_ShowMissed", { Title = "Show Missed Items", Default = true })
    ArrowSec:AddSlider("AR_MaxDistance", {
        Title = "Rush Max Distance", Min = 10, Max = 500, Default = 85, Rounding = 0,
    })
    ArrowSec:AddSlider("AR_ItemDistance", {
        Title = "Item Max Distance", Min = 5, Max = 200, Default = 30, Rounding = 0,
    })
    ArrowSec:AddSlider("AR_Size", {
        Title = "Arrow Size", Min = 10, Max = 60, Default = 24, Rounding = 0,
    })
    ArrowSec:AddSlider("AR_MaxArrows", {
        Title = "Max Arrows", Min = 1, Max = 15, Default = 5, Rounding = 0,
    })
    ArrowSec:AddColorpicker("AR_RushColor", {
        Title = "Rush/Monster Color", Default = Color3.fromRGB(255, 60, 60),
    })
    ArrowSec:AddColorpicker("AR_ItemColor", {
        Title = "Missed Item Color", Default = Color3.fromRGB(255, 215, 0),
    })
    --============================================================
    -- CROSSHAIR  (5 прицелов как в CS2 + обычный)
    --============================================================
    local CrosshairSec = Sec("Visuals", "Crosshair")
    CrosshairSec:AddToggle("CH_Enabled", { Title = "Crosshair", Default = false })
    CrosshairSec:AddDropdown("CH_Style", {
        Title = "Crosshair Style",
        Values = { "Default", "Square", "Circle", "HVH", "Quadrant" },
        Default = "Default", Multi = false,
    })
    CrosshairSec:AddColorpicker("CH_Color", {
        Title = "Crosshair Color", Default = Color3.fromRGB(170, 110, 255),
    })
    CrosshairSec:AddToggle("CH_Rainbow", {
        Title = "Rainbow Color", Default = false,
        Description = "Прицел переливается всеми цветами (для любого стиля).",
    })
    CrosshairSec:AddSlider("CH_Size", {
        Title = "Size", Min = 2, Max = 50, Default = 10, Rounding = 0,
    })
    CrosshairSec:AddSlider("CH_Thickness", {
        Title = "Thickness", Min = 1, Max = 10, Default = 2, Rounding = 0,
    })
    CrosshairSec:AddSlider("CH_Gap", {
        Title = "Gap (расстояние от центра)", Min = 0, Max = 20, Default = 4, Rounding = 0,
    })
    CrosshairSec:AddSlider("CH_DotSize", {
        Title = "Center Dot Size", Min = 0, Max = 10, Default = 0, Rounding = 0,
    })
    CrosshairSec:AddSlider("CH_Transparency", {
        Title = "Transparency", Min = 0, Max = 0.9, Default = 0, Rounding = 1,
    })
    CrosshairSec:AddSlider("CH_CircleRadius", {
        Title = "Circle Radius (только для Circle)", Min = 5, Max = 50, Default = 15, Rounding = 0,
    })
    CrosshairSec:AddSlider("CH_Outline", {
        Title = "Outline Thickness", Min = 0, Max = 5, Default = 1, Rounding = 0,
    })
    CrosshairSec:AddColorpicker("CH_OutlineColor", {
        Title = "Outline Color", Default = Color3.fromRGB(0, 0, 0),
    })
    Yield()
    local VisualsTP = Sec("Visuals", "Third Person")
    AddToggleKey(VisualsTP, "VW_ThirdPerson", { Title = "Third Person", Default = false },
        "VW_ThirdPerson_K", { Title = "Third Person key", Default = "T", Mode = "Toggle" })
    VisualsTP:AddToggle("VW_ThirdPerson_WallCheck", { Title = "Third Person Wall Check", Default = false })
    VisualsTP:AddToggle("VW_ThirdPerson_ShowHead", {
        Title = "Show Head (Fix: у персонажа нет башки)",
        Description = "Вкл: голова видна в третьем лице (исправлено). Выкл: голова скрыта.",
        Default = true,
    })
    VisualsTP:AddSlider("VW_ThirdPerson_X", { Title = "X Offset", Min = -10, Max = 10, Default = 1.5, Rounding = 1 })
    VisualsTP:AddSlider("VW_ThirdPerson_Y", { Title = "Y Offset", Min = -10, Max = 10, Default = 1,   Rounding = 1 })
    VisualsTP:AddSlider("VW_ThirdPerson_Z", { Title = "Z Offset", Min = -10, Max = 10, Default = 5,   Rounding = 1 })
    -- (Auto Padlock Solver перенесён во вкладку Misc)
    Yield()
    --============================================================
    -- ESP TAB
    --============================================================
    local ESPGroup       = Sec("ESP", "ESP Features")
    local ESPFilterGroup = Sec("ESP", "ESP Filters")
    ESPGroup:AddToggle("ESP_Enabled",        { Title = "ESP Enabled", Default = false })
    ESPGroup:AddToggle("ESP_Doors",          { Title = "Esp Doors", Default = true })
    ESPGroup:AddToggle("ESP_Keys",           { Title = "Esp Keys", Default = true })
    ESPGroup:AddToggle("ESP_Monsters",       { Title = "Esp Monsters", Default = true })
    ESPGroup:AddToggle("ESP_Players",        { Title = "Esp Players", Default = true })
    ESPGroup:AddToggle("ESP_Items",          { Title = "Esp Items", Default = true })
    ESPGroup:AddToggle("ESP_Books",          { Title = "Esp Books", Default = true })
    ESPGroup:AddToggle("ESP_Breakers",       { Title = "Esp Breakers", Default = true })
    ESPGroup:AddToggle("ESP_Fuses",          { Title = "Esp Fuses", Default = true })
    ESPGroup:AddToggle("ESP_Pizza",          { Title = "Esp Pizza", Default = true })
    ESPGroup:AddToggle("ESP_BasementLevers", { Title = "Esp Basement Levers", Default = true })
    ESPGroup:AddToggle("ESP_Levers",         { Title = "Esp Levers", Default = true })
    ESPGroup:AddToggle("ESP_HideBoxes",      { Title = "Esp Honcho Boxes", Default = true })
    ESPGroup:AddToggle("ESP_GoldPiles",      { Title = "Esp Gold Piles", Default = true })
    ESPGroup:AddToggle("ESP_LotusPetal",     { Title = "Esp Lotus Petals (The Outdoors)", Default = true })
    ESPGroup:AddToggle("ESP_SpecificEntities", {
        Title = "Esp Specific Entities",
        Description = "Scribbles, Alma, Teller, Bash, Honcho, Drones",
        Default = true,
    })
    ESPGroup:AddToggle("ESP_Name",           { Title = "Esp Name", Default = true })
    ESPGroup:AddToggle("ESP_Distance",       { Title = "Esp Distance", Default = true })
    ESPFilterGroup:AddToggle("ESP_TeamCheck", { Title = "Esp Team Check", Default = true })
    ESPFilterGroup:AddSlider("ESP_TextSize", {
        Title = "Esp Text Size", Min = 10, Max = 32, Default = 20, Rounding = 0,
    })
    ESPFilterGroup:AddSlider("ESP_MaxDistance", {
        Title = "Esp Max Distance", Min = 50, Max = 5000, Default = 1000, Rounding = 0,
    })
    Yield()
    -- TRACERS
    local TracerSec = Sec("ESP", "Tracers")
    TracerSec:AddToggle("TR_Enabled", {
        Title = "Tracers", Default = false,
        Description = "Линии от прицела к объектам из ESP. Работает, когда включён ESP и нужная категория ESP.",
    })
    do
        local titles, defaults = {}, {}
        for _, c in ipairs(TRACER_CATEGORIES) do
            table.insert(titles, c.title)
            table.insert(defaults, c.title)
        end
        TracerSec:AddDropdown("TR_Targets", {
            Title = "Tracer Targets",
            Description = "К каким объектам рисовать линии.",
            Values = titles, Default = defaults, Multi = true,
        })
    end
    TracerSec:AddDropdown("TR_Origin", {
        Title = "Tracer Origin", Values = { "Crosshair", "Bottom", "Top", "Mouse" }, Default = "Crosshair", Multi = false,
    })
    TracerSec:AddSlider("TR_Thickness", {
        Title = "Thickness", Min = 1, Max = 5, Default = 1.5, Rounding = 1,
    })
    TracerSec:AddSlider("TR_Transparency", {
        Title = "Transparency", Min = 0, Max = 0.9, Default = 0, Rounding = 1,
    })
    TracerSec:AddSlider("TR_MaxDistance", {
        Title = "Tracer Max Distance", Min = 50, Max = 5000, Default = 1000, Rounding = 0,
    })
    TracerSec:AddToggle("TR_Offscreen", {
        Title = "Off-screen Tracers", Default = true,
        Description = "Если объект за спиной — линия идёт к краю экрана в его сторону.",
    })
    TracerSec:AddToggle("TR_UseESPColor", {
        Title = "Use ESP Colors", Default = false,
        Description = "Вкл: цвет как у ESP. Выкл: цвета из раздела Tracer Colors.",
    })
    local TracerColorSec = Sec("ESP", "Tracer Colors")
    for _, c in ipairs(TRACER_CATEGORIES) do
        TracerColorSec:AddColorpicker("TR_Color_" .. c.key, { Title = c.title, Default = c.color })
    end
    --============================================================
    -- MISC TAB  (простые кнопки, без биндов)
    --============================================================
    local MiscSec = Sec("Misc", "Functions")
    MiscSec:AddButton({
        Title = "Glitch Exploit",
        Description = "Телепорт на 100 studs назад от прицела, затем Anchored вкл/выкл каждые 0.2 c. Повторное нажатие останавливает.",
        Callback = function() MiscFuncs.ToggleGlitch() end,
    })
    MiscSec:AddButton({
        Title = "Back to Lobby",
        Description = "Вернуться в лобби.",
        Callback = function() MiscFuncs.Lobby() end,
    })
    MiscSec:AddButton({
        Title = "Play Again",
        Description = "Начать игру заново.",
        Callback = function() MiscFuncs.PlayAgain() end,
    })
    MiscSec:AddButton({
        Title = "Kill Character",
        Description = "Убить своего персонажа.",
        Callback = function() MiscFuncs.Kill() end,
    })
    -- Auto Padlock Solver (перенесён из Visuals; id те же, поэтому сохранённые конфиги работают)
    local PadlockSec = Sec("Misc", "Auto Padlock")
    PadlockSec:AddToggle("MY_AutoPadlock", { Title = "Auto Padlock Solver", Default = false })
    PadlockSec:AddSlider("MY_AutoPadlock_Dist", {
        Title = "Auto Padlock Distance", Min = 10, Max = 50, Default = 25, Rounding = 0,
    })
    Yield()
    --============================================================
    -- CALLBACKS  (логика та же, :OnChanged -> Bind)
    --============================================================
    Bind(Toggles.EB_CrouchSpoof, function()
        task.spawn(function()
            while Toggles.EB_CrouchSpoof.Value and not Library.Unloaded do
                if CrouchRemote and not isCrouching() then
                    SafeCall(function() CrouchRemote:FireServer(true) end)
                end
                task.wait(0.2)
            end
        end)
    end)
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end
        local toggle = Toggles.EB_ACManipulate
        local picker = Options.EB_ACManipulate_K
        if not toggle or not picker then return end
        local wantState = toggle.Value and picker:GetState()
        if wantState and not STATE.States.manip then
            STATE.States.manip = true
            task.spawn(startManipulationLoop)
        elseif not wantState and STATE.States.manip then
            STATE.States.manip = false
        end
    end))
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end
        local toggle = Toggles.MY_AirLock
        local picker = Options.MY_AirLock_K
        if not toggle or not picker then return end
        local wantState = toggle.Value and picker:GetState()
        if wantState ~= STATE.States.airlock then setAirLockState(wantState) end
    end))
    Bind(Options.MY_AirLock_Height, function(value)
        STATE.FLY_HEIGHT = value
        if STATE.States.airlock then
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then STATE.lockedY = root.Position.Y end
        end
    end)
    -- Speed Boost
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end
        local toggle = Toggles.MY_SpeedBoost
        local picker = Options.MY_SpeedBoost_K
        if not toggle or not picker then return end
        local wantState = toggle.Value and picker:GetState()
        if wantState ~= SpeedBoostState.Enabled then
            if wantState then CallIfReady(StartSpeedBoostAbysall) else CallIfReady(StopSpeedBoostAbysall) end
        end
    end))
    Bind(Options.MY_SpeedBoost_Slider, function(value)
        STATE.SpeedBoostValue = value
    end)
    -- начальное значение слайдера (Bind пропускает первый вызов)
    STATE.SpeedBoostValue = Options.MY_SpeedBoost_Slider.Value
    Bind(Toggles.MY_RemoveAcceleration, function(v)
        if v then CallIfReady(StartRemoveAcceleration) else CallIfReady(StopRemoveAcceleration) end
    end)
    Bind(Toggles.ES_AntiEyes,    function(v) if v then CallIfReady(StartAntiEyes)    else CallIfReady(StopAntiEyes)    end end)
    Bind(Toggles.ES_AntiLookman, function(v) if v then CallIfReady(StartAntiLookman) else CallIfReady(StopAntiLookman) end end)
    Bind(Toggles.ES_NoScreechDamage, function(v)
        if v then CallIfReady(EnableNoScreechDamage) else CallIfReady(DisableNoScreechDamage) end
    end)
    Bind(Toggles.ER_RemoveHalt,   function(v) CallIfReady(SetHaltDisabled, v) end)
    Bind(Toggles.ER_NoHaltDamage, function(v) CallIfReady(SetHaltDamageBlocked, v) end)
    Bind(Toggles.VR_NoRansomOverlays, function(v) if v then CallIfReady(StartRansomOverlayRemover) else CallIfReady(StopRansomOverlayRemover) end end)
    Bind(Toggles.ER_NoRansomDamage,   function(v) if v then CallIfReady(StartRansomDamageBlocker)  else CallIfReady(StopRansomDamageBlocker)  end end)
    Bind(Toggles.AE_BypassDupe,            function(v) AntiEntityState.BypassDupe = v;            if v then ScanAntiEntities() end end)
    Bind(Toggles.AE_BypassGloombatEggs,    function(v) AntiEntityState.BypassGloombatEggs = v;    if v then ScanAntiEntities() end end)
    Bind(Toggles.AE_BypassGiggle,          function(v) AntiEntityState.BypassGiggle = v;          if v then ScanAntiEntities() end end)
    Bind(Toggles.AE_BypassSeekObstructions,function(v) AntiEntityState.BypassSeekObstructions = v;if v then ScanAntiEntities() end end)
    Bind(Toggles.AE_BypassVacuum,          function(v) AntiEntityState.BypassVacuum = v;          if v then ScanAntiEntities() end end)
    Bind(Toggles.AE_BypassKillbricks,      function(v) AntiEntityState.BypassKillbricks = v;      if v then ScanAntiEntities() end end)
    Bind(Toggles.AE_BypassSeekingWall,     function(v) AntiEntityState.BypassSeekingWall = v;     if v then ScanAntiEntities() end end)
    Bind(Toggles.AE_BypassSnare,           function(v) AntiEntityState.BypassSnare = v;           if v then ScanAntiEntities() end end)
    Bind(Toggles.AE_BypassBanana,          function(v) AntiEntityState.BypassBanana = v;          if v then ScanAntiEntities() end end)
    Bind(Toggles.AE_BypassJeff,            function(v) AntiEntityState.BypassJeff = v;            if v then ScanAntiEntities() end end)
    Bind(Toggles.MH_Enabled, function(v)
        if v then CallIfReady(StartMonsterHighlight) else CallIfReady(StopMonsterHighlight) end
    end)
    Bind(Toggles.AS_Anchor, function(v)
        if v then CallIfReady(StartAutoSolveAnchors) else CallIfReady(StopAutoSolveAnchors) end
    end)
    Bind(Toggles.AC_Bypass, function(v)
        if v then
            STATE.DisablerMode = Options.AC_Bypass_Mode.Value or "Ladder"
            CallIfReady(StartDisabler)
        else
            CallIfReady(StopDisabler)
        end
    end)
    Bind(Options.AC_Bypass_Mode, function(v)
        STATE.DisablerMode = v
        if not Disabler.Enabled then return end
        CallIfReady(StopDisabler)
        task.wait(0.1)
        CallIfReady(StartDisabler)
    end)
    Bind(Toggles.FLY_Enabled, function(v)
        if v then
            if not Fly.Unlocked then
                task.defer(function() Toggles.FLY_Enabled:SetValue(false) end)
                Notify("Fly is locked!", "Enable Disabler first to unlock Fly.", 5)
                return
            end
            Fly.Speed = Options.FLY_Speed.Value
            CallIfReady(StartFly)
        else
            CallIfReady(StopFly)
        end
    end)
    Bind(Options.FLY_Speed, function(v)
        Fly.Speed = v
        Fly.MaxSpeed = v
    end)
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end
        local toggle = Toggles.FLY_Enabled
        local picker = Options.FLY_Enabled_K
        if not toggle or not picker then return end
        local wantState = toggle.Value and picker:GetState()
        if wantState and not Fly.Enabled then
            if not Fly.Unlocked then
                Notify("Fly is locked!", "Enable Disabler first to unlock Fly.", 5)
                task.defer(function() Toggles.FLY_Enabled:SetValue(false) end)
                return
            end
            Fly.Speed = Options.FLY_Speed.Value
            CallIfReady(StartFly)
        elseif not wantState and Fly.Enabled then
            CallIfReady(StopFly)
        end
    end))
    Bind(Toggles.NOCLIP_Enabled, function(v)
        if v then
            if not Noclip.Unlocked then
                task.defer(function() Toggles.NOCLIP_Enabled:SetValue(false) end)
                Notify("Noclip is locked!", "Enable Disabler first to unlock Noclip.", 5)
                return
            end
            if not Noclip.Enabled then CallIfReady(StartNoclip) end
        else
            if Noclip.Enabled then CallIfReady(StopNoclip) end
        end
    end)
    -- (применение сохранённых состояний теперь выполняется ПОСЛЕ заставки и загрузки конфига — см. конец UI)
    Bind(Toggles.VW_Ambience, function()
        if Toggles.VW_Ambience.Value then
            Locks.Fullbright.targetAmbient = Options.VW_Ambience_C.Value
            ApplyFullbrightLock()
        else
            RemoveFullbrightLock()
            Lighting.GlobalShadows = OldGlobalShadows
            Lighting.OutdoorAmbient = OldOutdoorAmbient
        end
    end)
    Bind(Options.VW_Ambience_C, function()
        if Toggles.VW_Ambience.Value then
            Locks.Fullbright.targetAmbient = Options.VW_Ambience_C.Value
            EnforceFullbright()
        end
    end)
    Bind(Toggles.VW_NoFog, function()
        if Toggles.VW_NoFog.Value then ApplyNoFogLock()
        else
            RemoveNoFogLock()
            if Atmosphere then Atmosphere.Density = OldFog end
            Lighting.FogEnd = OldFogEnd
        end
    end)
    Bind(Toggles.VW_NoShaking, function(v) NoShaking.Enabled = v end)
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end
        local toggle = Toggles.VW_ThirdPerson
        local picker = Options.VW_ThirdPerson_K
        if not toggle or not picker then return end
        local wantState = toggle.Value and picker:GetState()
        if wantState ~= ThirdPerson.Enabled then ThirdPerson.Enabled = wantState end
    end))
    Bind(Toggles.VW_ThirdPerson_WallCheck, function(v) ThirdPerson.WallCheck = v end)
    Bind(Toggles.VW_ThirdPerson_ShowHead, function(v)
        ThirdPerson.ShowHead = v
        if v then
            RestoreThirdPersonHead()
            RestoreThirdPersonSession()
        else
            local char = LocalPlayer.Character
            if char and ThirdPerson.Enabled then HideThirdPersonHead(char) end
        end
    end)
    -- ARROWS
    Bind(Toggles.AR_Enabled, function(v)
        Arrows.Enabled = v
        if v then CallIfReady(StartArrows) else CallIfReady(StopArrows) end
    end)
    Bind(Toggles.AR_ShowRush, function(v) Arrows.ShowRush = v end)
    Bind(Toggles.AR_ShowMissed, function(v) Arrows.ShowMissedItems = v end)
    Bind(Options.AR_MaxDistance, function(v) Arrows.MaxDistance = v end)
    Bind(Options.AR_ItemDistance, function(v) Arrows.ItemDistance = v end)
    Bind(Options.AR_Size, function(v) Arrows.ArrowSize = v end)
    Bind(Options.AR_MaxArrows, function(v) Arrows.MaxArrows = v end)
    Bind(Options.AR_RushColor, function(v) Arrows.RushColor = v end)
    Bind(Options.AR_ItemColor, function(v) Arrows.ItemColor = v end)
    -- CROSSHAIR
    Bind(Toggles.CH_Enabled, function(v)
        Crosshair.Enabled = v
        if v then CallIfReady(StartCrosshair) else CallIfReady(StopCrosshair) end
    end)
    Bind(Options.CH_Style, function(v) Crosshair.Style = v end)
    Bind(Options.CH_Color, function(v) Crosshair.Color = v end)
    Bind(Toggles.CH_Rainbow, function(v) Crosshair.Rainbow = v end)
    Bind(Options.CH_Size, function(v) Crosshair.Size = v end)
    Bind(Options.CH_Thickness, function(v) Crosshair.Thickness = v end)
    Bind(Options.CH_Gap, function(v) Crosshair.Gap = v end)
    Bind(Options.CH_DotSize, function(v) Crosshair.DotSize = v end)
    Bind(Options.CH_Transparency, function(v) Crosshair.Transparency = v end)
    Bind(Options.CH_CircleRadius, function(v) Crosshair.CircleRadius = v end)
    Bind(Options.CH_Outline, function(v) Crosshair.Outline = v end)
    Bind(Options.CH_OutlineColor, function(v) Crosshair.OutlineColor = v end)
    Bind(Options.VW_ThirdPerson_X, function(v) ThirdPerson.Offset = Vector3.new(v, ThirdPerson.Offset.Y, ThirdPerson.Offset.Z) end)
    Bind(Options.VW_ThirdPerson_Y, function(v) ThirdPerson.Offset = Vector3.new(ThirdPerson.Offset.X, v, ThirdPerson.Offset.Z) end)
    Bind(Options.VW_ThirdPerson_Z, function(v) ThirdPerson.Offset = Vector3.new(ThirdPerson.Offset.X, ThirdPerson.Offset.Y, v) end)
    -- начальные значения оффсета из слайдеров
    ThirdPerson.Offset = Vector3.new(Options.VW_ThirdPerson_X.Value, Options.VW_ThirdPerson_Y.Value, Options.VW_ThirdPerson_Z.Value)
    Bind(Toggles.GA_InstantInteract, function(v)
        InstantInteract.Enabled = v
        if v then CallIfReady(StartInstantInteract)
        else
            if InstantInteract.Connection then
                InstantInteract.Connection:Disconnect()
                InstantInteract.Connection = nil
            end
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") and obj:GetAttribute("LOLHAX_OrigHold") ~= nil then
                    pcall(function()
                        obj.HoldDuration = obj:GetAttribute("LOLHAX_OrigHold")
                        obj:SetAttribute("LOLHAX_OrigHold", nil)
                    end)
                end
            end
        end
    end)
    Bind(Toggles.GA_InfiniteItems, function(v)
        InfiniteItems.Enabled = v
        if v then
            -- сразу скан всех существующих промптов (по бюджету, без фриза) + мониторинг новых
            Watcher.Scan("InfiniteItems")
        else
            Watcher.Refresh()
            for fake, real in pairs(InfiniteItems.FakePrompts) do
                if real and real.Parent == InfiniteItems.Container then
                    pcall(function() real.Parent = fake.Parent end)
                end
                if fake then fake:Destroy() end
            end
            InfiniteItems.FakePrompts = {}
        end
    end)
    Bind(Options.GA_InfiniteItems_List, function(list)
        InfiniteItems.List = {}
        for name, enabled in pairs(list) do
            if enabled then InfiniteItems.List[name] = true end
        end
    end)
    do
        local defaultList = { "Lockpick", "SkeletonKey", "Shears", "Multitool" }
        for _, name in ipairs(defaultList) do InfiniteItems.List[name] = true end
    end
    -- Position Spoof
    TrackConnection(RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end
        local toggle = Toggles.MY_PositionSpoof
        local picker = Options.MY_PositionSpoof_K
        if not toggle or not picker then return end
        local wantState = toggle.Value and picker:GetState()
        if wantState ~= STATE.States.pos then
            CallIfReady(SetPositionSpoofState, wantState)
            STATE.States.pos = wantState
        end
    end))
    Bind(Toggles.GA_AutoInteract, function(v)
        AutoInteract.Enabled = v
        -- при включении сбрасываем кэш, чтобы сразу учитывались все уже существующие промпты
        if v then AutoInteract.CacheVersion = AutoInteract.CacheVersion + 1 end
        Watcher.Refresh()
    end)
    Bind(Options.GA_AutoInteract_Range, function(v) AutoInteract.Range = v end)
    Bind(Options.GA_AutoInteract_Options, function(opts) AutoInteract.Options = opts end)
    Bind(Toggles.GA_AutoInteract_Debug, function(v) STATE.AutoInteractDebug = v end)
    AutoInteract.Range = Options.GA_AutoInteract_Range.Value
    -- ESP: при включении сразу полный скан карты (раньше подсвечивалось только то,
    -- что появилось после включения) + мониторинг новых объектов через Watcher.
    Bind(Toggles.ESP_Enabled, function(v)
        ESP.Enabled = v
        if not v then
            Watcher.Refresh()
            clearAllEsp()
            ESPRegistry = {}
            CallIfReady(Tracers.HideAll)
        else
            CallIfReady(RescanEsp)
        end
    end)
    -- Категории ESP: вкл -> сразу перескан, выкл -> убрать подсветку этой категории
    for toggleId, category in pairs(ESP_TOGGLE_CATEGORY) do
        if Toggles[toggleId] then
            Bind(Toggles[toggleId], function(v)
                if v then
                    if not ESP.Enabled then return end
                    if category == "Player" then
                        CallIfReady(scanExistingPlayers)
                    else
                        CallIfReady(RescanEsp)
                    end
                else
                    CallIfReady(RemoveEspCategory, category)
                end
            end)
        end
    end
    Bind(Toggles.ESP_Name,      function(v) ESP.Name = v end)
    Bind(Toggles.ESP_Distance,  function(v) ESP.Distance = v end)
    Bind(Toggles.ESP_TeamCheck, function(v)
        ESP.TeamCheck = v
        if ESP.Enabled and Toggles.ESP_Players and Toggles.ESP_Players.Value then CallIfReady(scanExistingPlayers) end
    end)
    Bind(Options.ESP_TextSize, function(v)
        ESP.TextSize = v
        -- ОПТИМИЗАЦИЯ: перебираем только свои ESP-метки, а не все объекты Workspace
        for _, data in pairs(ESPRegistry) do
            if data.label and data.label.Parent then data.label.TextSize = v end
        end
    end)
    -- TRACERS
    local function SyncTracerOptions()
        Tracers.Origin = (Options.TR_Origin and Options.TR_Origin.Value) or "Crosshair"
        Tracers.Thickness = (Options.TR_Thickness and Options.TR_Thickness.Value) or 1.5
        Tracers.Transparency = (Options.TR_Transparency and Options.TR_Transparency.Value) or 0
        Tracers.MaxDistance = (Options.TR_MaxDistance and Options.TR_MaxDistance.Value) or 1000
        Tracers.ShowOffscreen = not (Toggles.TR_Offscreen and Toggles.TR_Offscreen.Value == false)
        Tracers.UseESPColor = (Toggles.TR_UseESPColor and Toggles.TR_UseESPColor.Value) and true or false
        local targets = {}
        local list = Options.TR_Targets and Options.TR_Targets.Value
        if type(list) == "table" then
            for title, on in pairs(list) do
                local key = TRACER_TITLE_TO_KEY[title]
                if on and key then targets[key] = true end
            end
        end
        Tracers.Targets = targets
        for _, c in ipairs(TRACER_CATEGORIES) do
            local opt = Options["TR_Color_" .. c.key]
            Tracers.Colors[c.key] = (opt and opt.Value) or c.color
        end
    end
    SyncTracerOptions()
    Bind(Toggles.TR_Enabled, function(v)
        SyncTracerOptions()
        if v then
            CallIfReady(Tracers.Start)
            if not ESP.Enabled then
                Notify("Tracers", "Tracers use ESP objects - turn on 'ESP Enabled'.", 4)
            end
        else
            CallIfReady(Tracers.Stop)
        end
    end)
    for _, id in ipairs({ "TR_Targets", "TR_Origin", "TR_Thickness", "TR_Transparency", "TR_MaxDistance", "TR_Offscreen", "TR_UseESPColor" }) do
        if Options[id] then Bind(Options[id], function() SyncTracerOptions() end) end
    end
    for _, c in ipairs(TRACER_CATEGORIES) do
        local opt = Options["TR_Color_" .. c.key]
        if opt then Bind(opt, function() SyncTracerOptions() end) end
    end
    -- DOOR REACH
    Bind(Toggles.MY_DoorReach, function(v)
        DoorReach.Enabled = v
        DoorReach.Distance = Options.MY_DoorReach_Dist.Value or 75
    end)
    Bind(Options.MY_DoorReach_Dist, function(v) DoorReach.Distance = v end)
    DoorReach.Distance = Options.MY_DoorReach_Dist.Value or 75
    -- NOTIFIER: при включении сразу проверяем уже существующие объекты, а не только новые
    Bind(Toggles.GN_Enabled, function(v)
        if v then Watcher.Scan("EntityNotifier") else Watcher.Refresh() end
    end)
    Bind(Toggles.GN_LotusPetal, function(v)
        if v and Toggles.GN_Enabled.Value then Watcher.Scan("EntityNotifier") end
    end)
    Bind(Options.ESP_MaxDistance, function(v) ESP.MaxDistance = v end)
    Bind(Options.GN_NotificationAlignment, function()
        for _, v in ipairs(NotificationHolder:GetChildren()) do
            local Alignment = 0.5
            if Options.GN_NotificationAlignment.Value == "Left" then Alignment = 1
            elseif Options.GN_NotificationAlignment.Value == "Right" then Alignment = 0 end
            v.AnchorPoint = Vector2.new(Alignment, 0.5)
        end
    end)
    Yield()
    --============================================================
    -- SETTINGS TAB
    --============================================================
    local KBSec = Sec("Settings", "Keybinds")
    KBSec:AddToggle("KB_ShowList", {
        Title = "Show Keybinds",
        Description = "Окно со списком биндов (подсвечены активные). Окно можно перетаскивать.",
        Default = false,
    })
    Bind(Options.KB_ShowList, function(v)
        KeybindList.Visible = v
        if v then
            BuildKeybindList()
            KeybindList.Gui.Enabled = true
            UpdateKeybindList()
        elseif KeybindList.Gui then
            KeybindList.Gui.Enabled = false
        end
    end)
    local WMSec = Sec("Settings", "Watermark")
    WMSec:AddToggle("WM_Enabled", {
        Title = "Watermark",
        Description = "Плашка с FPS, пингом, ником и аватаром. Можно перетаскивать мышью.",
        Default = true,
    })
    WMSec:AddToggle("WM_Blur", {
        Title = "Acrylic Style",
        Description = "Вкл = плашка чуть плотнее + акцентный бордюр (акриловый вид).",
        Default = true,
    })
    WMSec:AddSlider("WM_BlurSize", {
        Title = "Acrylic Border Size",
        Description = "Толщина бордюра плашки (акриловый эффект). 0 = выключено.",
        Min = 0, Max = 24, Default = 12, Rounding = 0,
    })
    WMSec:AddToggle("WM_ShowName", { Title = "Show Nickname", Default = true })
    WMSec:AddToggle("WM_ShowAvatar", { Title = "Show Avatar", Default = true })
    WMSec:AddDropdown("WM_Position", {
        Title = "Watermark Position",
        Values = { "Top Right", "Top Left", "Bottom Right", "Bottom Left" },
        Default = "Top Right", Multi = false,
    })
    Bind(Toggles.WM_Enabled, function(v)
        if v and not STATE.SplashReady then return end -- покажется после заставки
        SetWatermarkVisible(v)
    end)
    Bind(Toggles.WM_ShowName, function() WMApplyOptions() end)
    Bind(Toggles.WM_ShowAvatar, function() WMApplyOptions() end)
    Bind(Options.WM_Position, function() WMApplyPosition() end)
    Bind(Toggles.WM_Blur, function(v)
        -- акриловый эффект управляется ЕДИНОЙ функцией состояния
        WMApplyEffectState()
    end)
    Bind(Options.WM_BlurSize, function(v)
        -- акриловый эффект управляется ЕДИНОЙ функцией состояния
        WMApplyEffectState()
    end)
    -- первое появление — после заставки (Bind пропускает стартовый вызов)
    task.spawn(function()
        while not STATE.SplashReady and not Library.Unloaded do task.wait(0.1) end
        if Library.Unloaded then return end
        if Toggles.WM_Enabled and Toggles.WM_Enabled.Value then SetWatermarkVisible(true) end
    end)
    local MenuSec = Sec("Settings", "Menu")
    -- Полная очистка. Вызывается один раз: и из кнопки Unload, и при закрытии окна крестиком.
    local function DoUnload()
        if STATE.Unloading then return end
        STATE.Unloading = true
        Library.Unloaded = true
        STATE.States.manip = false
        DisconnectAll()
        STATE.States.manip = false
        STATE.States.airlock = false
        STATE.PadlockCode = nil
        STATE.PadlockCode_N = nil
        NoShaking.Enabled = false
        InstantInteract.Enabled = false
        InfiniteItems.Enabled = false
        AutoInteract.Enabled = false
        ThirdPerson.Enabled = false
        CallIfReady(StopRansomOverlayRemover)
        CallIfReady(StopRansomDamageBlocker)
        CallIfReady(StopMonsterHighlight)
        CallIfReady(StopLotusPetalHighlight)
        CallIfReady(StopDisabler)
        CallIfReady(StopFly)
        CallIfReady(StopNoclip)
        CallIfReady(StopAutoSolveAnchors)
        CallIfReady(StopAntiEyes)
        CallIfReady(StopAntiLookman)
        CallIfReady(StopSpeedBoostAbysall)
        CallIfReady(StopRemoveAcceleration)
        CallIfReady(DisableNoScreechDamage)
        if InstantInteract.Connection then
            InstantInteract.Connection:Disconnect()
            InstantInteract.Connection = nil
        end
        for fake, real in pairs(InfiniteItems.FakePrompts) do
            if real and real.Parent == InfiniteItems.Container then
                pcall(function() real.Parent = fake.Parent end)
            end
            if fake then fake:Destroy() end
        end
        InfiniteItems.FakePrompts = {}
        CallIfReady(SetHaltDisabled, false)
        for name, entry in pairs(FakeEvents.Registry) do
            if entry.real then
                pcall(function() SwapRemoteObject(entry.real, false) end)
            end
            if entry.fake then pcall(function() entry.fake:Destroy() end) end
        end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp then hrp.Anchored = false end
        if hum then hum.HipHeight = PositionSpoof.OldHipHeight or 2.396 end
        if char and char:FindFirstChild("LowerTorso") and char.LowerTorso:FindFirstChild("Root") and PositionSpoof.OldC1 then
            char.LowerTorso.Root.C1 = PositionSpoof.OldC1
        end
        if char and hrp and PositionSpoof.Enabled and not PositionSpoof.OldFloor then
            hrp.CFrame = hrp.CFrame * CFrame.new(0, 2.346, 0)
        end
        PositionSpoof.Enabled = false
        if VelocityManip.Body then VelocityManip.Body.Parent = nil end
        pcall(function() RunService:UnbindFromRenderStep("LOLHAX_FOV") end)
        Camera.FieldOfView = 70
        Lighting.GlobalShadows = OldGlobalShadows
        Lighting.OutdoorAmbient = OldOutdoorAmbient
        Lighting.FogEnd = OldFogEnd
        if Atmosphere then Atmosphere.Density = OldFog end
        if InfiniteItems.Container then InfiniteItems.Container:Destroy() end
        if LXNotifications then LXNotifications:Destroy() end
        clearAllEsp()
        CallIfReady(Tracers.Stop)
        CallIfReady(Tracers.DestroyAll)
        DoorReach.Enabled = false
        pcall(Watcher.Refresh)
        pcall(MiscFuncs.StopGlitch)
        if KeybindList.Gui then pcall(function() KeybindList.Gui:Destroy() end) end
        if Watermark.Gui then pcall(function() Watermark.Gui:Destroy() end) end
        Watermark.Visible = false
        -- выгрузка визуального acrylic-эффекта (просто сбрасываем stroke на плашке)
        if Watermark.FrameStroke then
            pcall(function()
                Watermark.FrameStroke.Transparency = 0.6
                Watermark.FrameStroke.Thickness = 1
            end)
        end
        -- выгрузка Arrows и Crosshair (GUI + эффекты)
        CallIfReady(StopArrows)
        CallIfReady(StopCrosshair)
        -- восстановление стандартного прицела Doors (если мы его скрывали)
        pcall(RestoreDefaultCrosshair)
        -- восстановление головы (если ThirdPerson прятал её)
        if next(ThirdPersonHidden) ~= nil then RestoreThirdPersonHead() end
        pcall(RestoreThirdPersonSession)
        if STATE.SplashGui then pcall(function() STATE.SplashGui:Destroy() end) end
    end
    -- Закрытие крестиком: Fluent сам показывает окно подтверждения и уничтожает GUI,
    -- а мы по факту уничтожения GUI выполняем очистку.
    pcall(function()
        if Fluent.GUI then Fluent.GUI.Destroying:Connect(DoUnload) end
    end)
    MenuSec:AddButton({
        Title = "Unload",
        Description = "Отключает все функции и закрывает меню",
        Callback = function()
            -- То же окно подтверждения, что и при закрытии крестиком
            Window:Dialog({
                Title = "Close",
                Content = "Are you sure you want to unload the interface?",
                Buttons = {
                    {
                        Title = "Confirm",
                        Callback = function()
                            DoUnload()
                            pcall(function() Fluent:Destroy() end)
                        end,
                    },
                    {
                        Title = "Cancel",
                        Callback = function() end,
                    },
                },
            })
        end,
    })
    -- Тема, прозрачность и бинд сворачивания меню (RightShift по умолчанию)
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    -- Любая загрузка конфига (автозагрузка и кнопка "Load config") блокируется, пока идёт заставка
    do
        local _SM_Load = SaveManager.Load
        SaveManager.Load = function(self, ...)
            if not STATE.SplashDone then
                return false, "wait until the intro finishes"
            end
            return _SM_Load(self, ...)
        end
    end
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("lolhax")
    SaveManager:SetFolder("lolhax/MyScripts")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
    Window:SelectTab(1)
    --============================================================
    -- ПЛАВНОЕ ПОЯВЛЕНИЕ ФУНКЦИЙ ПРИ ПЕРЕКЛЮЧЕНИИ ВКЛАДОК
    --============================================================
    -- Почему раньше было 10-20 FPS:
    --  * каждый элемент скрывался/показывался через Visible по одному за кадр. Каждое изменение
    --    Visible заставляло Fluent пересчитывать раскладку всей вкладки (AutomaticSize у элементов,
    --    размер секции, CanvasSize у ScrollingFrame) — много перерасчётов каждый кадр;
    --  * появление начиналось, пока Fluent ещё держит вкладку внутри CanvasGroup (своя анимация
    --    смены вкладки), и CanvasGroup перерисовывал весь холст на каждое изменение.
    -- Новая версия:
    --  * ничего не скрывается и размеры не меняются -> никаких перерасчётов раскладки;
    --  * каждая секция плавно "въезжает" сбоку с небольшой задержкой друг за другом (каскад)
    --    через UIPadding: PaddingLeft = +x и PaddingRight = -x, т.е. ширина секции остаётся
    --    прежней (текст не переносится, высота не пересчитывается);
    --  * анимацию ведёт TweenService на стороне движка (C++), а не Lua-цикл по кадрам,
    --    поэтому она плавная при любом FPS; прозрачность даёт штатный fade Fluent.
    local REVEAL_SHIFT   = 22      -- на сколько пикселей секция смещена в начале
    local REVEAL_TIME    = 0.34    -- длительность въезда одной секции
    local REVEAL_STAGGER = 0.05    -- задержка между соседними секциями (каскад)
    local RevealInfo = TweenInfo.new(REVEAL_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local RevealPads, RevealTweens, RevealGen = {}, {}, {}
    local function GetSectionPads(tabKey)
        if RevealPads[tabKey] then return RevealPads[tabKey] end
        local list = {}
        for _, section in ipairs(TabSections[tabKey] or {}) do
            local root = section.Container and section.Container.Parent
            if root and root:IsA("GuiObject") then
                local pad = root:FindFirstChild("_LOLHAX_Reveal") or Instance.new("UIPadding")
                pad.Name = "_LOLHAX_Reveal"
                pad.PaddingLeft = UDim.new(0, 0)
                pad.PaddingRight = UDim.new(0, 0)
                pad.Parent = root
                table.insert(list, pad)
            end
        end
        RevealPads[tabKey] = list
        return list
    end
    local function ResetPads(pads)
        for _, p in ipairs(pads) do
            local tw = RevealTweens[p]
            if tw then pcall(function() tw:Cancel() end) RevealTweens[p] = nil end
            p.PaddingLeft = UDim.new(0, 0)
            p.PaddingRight = UDim.new(0, 0)
        end
    end
    for tabKey, tab in pairs(Tabs) do
        pcall(function()
            local container = tab.Container
            if not container then return end
            RevealGen[tabKey] = 0
            container:GetPropertyChangedSignal("Visible"):Connect(function()
                if Library.Unloaded then return end
                RevealGen[tabKey] += 1
                local gen = RevealGen[tabKey]
                local pads = GetSectionPads(tabKey)
                if #pads == 0 then return end
                ResetPads(pads)
                if not container.Visible then return end -- вкладку закрыли: всё на месте
                for _, p in ipairs(pads) do
                    p.PaddingLeft = UDim.new(0, REVEAL_SHIFT)
                    p.PaddingRight = UDim.new(0, -REVEAL_SHIFT)
                end
                for i, p in ipairs(pads) do
                    local function Play()
                        if RevealGen[tabKey] ~= gen or Library.Unloaded or not p.Parent then return end
                        local tw = TweenService:Create(p, RevealInfo, {
                            PaddingLeft = UDim.new(0, 0),
                            PaddingRight = UDim.new(0, 0),
                        })
                        RevealTweens[p] = tw
                        tw:Play()
                    end
                    if i == 1 then Play() else task.delay((i - 1) * REVEAL_STAGGER, Play) end
                end
            end)
        end)
    end
    STATE.UIBuilt = true
    -- Конфиг грузится ТОЛЬКО после того, как заставка полностью закончилась
    task.spawn(function()
        while not STATE.SplashDone and not Library.Unloaded do task.wait(0.1) end
        if Library.Unloaded then return end
        task.wait(0.4)
        pcall(function() SaveManager:LoadAutoloadConfig() end)
        task.wait(1)
        if Library.Unloaded then return end
        if Toggles.VW_Ambience and Toggles.VW_Ambience.Value then
            Locks.Fullbright.targetAmbient = Options.VW_Ambience_C.Value
            ApplyFullbrightLock()
        end
        if Toggles.VW_NoFog and Toggles.VW_NoFog.Value then ApplyNoFogLock() end
        if Toggles.GA_InfiniteItems and Toggles.GA_InfiniteItems.Value then
            InfiniteItems.Enabled = true
            Watcher.Scan("InfiniteItems")
        end
        if Toggles.VW_ThirdPerson and Toggles.VW_ThirdPerson.Value then ThirdPerson.Enabled = true end
        if Toggles.VW_ThirdPerson_ShowHead then
            ThirdPerson.ShowHead = not (Toggles.VW_ThirdPerson_ShowHead.Value == false)
        end
        if Toggles.AR_Enabled and Toggles.AR_Enabled.Value then
            Arrows.Enabled = true
            Arrows.ShowRush = not (Toggles.AR_ShowRush and Toggles.AR_ShowRush.Value == false)
            Arrows.ShowMissedItems = not (Toggles.AR_ShowMissed and Toggles.AR_ShowMissed.Value == false)
            Arrows.MaxDistance = (Options.AR_MaxDistance and Options.AR_MaxDistance.Value) or 85
            Arrows.ItemDistance = (Options.AR_ItemDistance and Options.AR_ItemDistance.Value) or 30
            Arrows.ArrowSize = (Options.AR_Size and Options.AR_Size.Value) or 24
            Arrows.MaxArrows = (Options.AR_MaxArrows and Options.AR_MaxArrows.Value) or 5
            if Options.AR_RushColor and Options.AR_RushColor.Value then Arrows.RushColor = Options.AR_RushColor.Value end
            if Options.AR_ItemColor and Options.AR_ItemColor.Value then Arrows.ItemColor = Options.AR_ItemColor.Value end
            CallIfReady(StartArrows)
        end
        if Toggles.CH_Enabled and Toggles.CH_Enabled.Value then
            Crosshair.Enabled = true
            if Options.CH_Style and Options.CH_Style.Value then Crosshair.Style = Options.CH_Style.Value end
            if Options.CH_Color and Options.CH_Color.Value then Crosshair.Color = Options.CH_Color.Value end
            Crosshair.Rainbow = (Toggles.CH_Rainbow and Toggles.CH_Rainbow.Value) and true or false
            if Options.CH_Size and Options.CH_Size.Value then Crosshair.Size = Options.CH_Size.Value end
            if Options.CH_Thickness and Options.CH_Thickness.Value then Crosshair.Thickness = Options.CH_Thickness.Value end
            if Options.CH_Gap and Options.CH_Gap.Value then Crosshair.Gap = Options.CH_Gap.Value end
            if Options.CH_DotSize and Options.CH_DotSize.Value then Crosshair.DotSize = Options.CH_DotSize.Value end
            if Options.CH_Transparency and Options.CH_Transparency.Value then Crosshair.Transparency = Options.CH_Transparency.Value end
            if Options.CH_Outline and Options.CH_Outline.Value then Crosshair.Outline = Options.CH_Outline.Value end
            if Options.CH_OutlineColor and Options.CH_OutlineColor.Value then Crosshair.OutlineColor = Options.CH_OutlineColor.Value end
            CallIfReady(StartCrosshair)
        end
        if Toggles.ES_NoScreechDamage and Toggles.ES_NoScreechDamage.Value then CallIfReady(EnableNoScreechDamage) end
        if Toggles.ES_AntiEyes and Toggles.ES_AntiEyes.Value then CallIfReady(StartAntiEyes) end
        if Toggles.ES_AntiLookman and Toggles.ES_AntiLookman.Value then CallIfReady(StartAntiLookman) end
        if Toggles.MH_Enabled and Toggles.MH_Enabled.Value then CallIfReady(StartMonsterHighlight) end
        if Toggles.AC_Bypass and Toggles.AC_Bypass.Value then CallIfReady(StartDisabler) end
        if Toggles.MY_RemoveAcceleration and Toggles.MY_RemoveAcceleration.Value then CallIfReady(StartRemoveAcceleration) end
        if Toggles.AE_BypassDupe and Toggles.AE_BypassDupe.Value then AntiEntityState.BypassDupe = true; ScanAntiEntities() end
        if Toggles.AE_BypassGloombatEggs and Toggles.AE_BypassGloombatEggs.Value then AntiEntityState.BypassGloombatEggs = true; ScanAntiEntities() end
        if Toggles.AE_BypassGiggle and Toggles.AE_BypassGiggle.Value then AntiEntityState.BypassGiggle = true; ScanAntiEntities() end
        if Toggles.AE_BypassSeekObstructions and Toggles.AE_BypassSeekObstructions.Value then AntiEntityState.BypassSeekObstructions = true; ScanAntiEntities() end
        if Toggles.AE_BypassVacuum and Toggles.AE_BypassVacuum.Value then AntiEntityState.BypassVacuum = true; ScanAntiEntities() end
        if Toggles.AE_BypassKillbricks and Toggles.AE_BypassKillbricks.Value then AntiEntityState.BypassKillbricks = true; ScanAntiEntities() end
        if Toggles.AE_BypassSeekingWall and Toggles.AE_BypassSeekingWall.Value then AntiEntityState.BypassSeekingWall = true; ScanAntiEntities() end
        if Toggles.AE_BypassSnare and Toggles.AE_BypassSnare.Value then AntiEntityState.BypassSnare = true; ScanAntiEntities() end
        if Toggles.AE_BypassBanana and Toggles.AE_BypassBanana.Value then AntiEntityState.BypassBanana = true; ScanAntiEntities() end
        if Toggles.AE_BypassJeff and Toggles.AE_BypassJeff.Value then AntiEntityState.BypassJeff = true; ScanAntiEntities() end
        if Toggles.AS_Anchor and Toggles.AS_Anchor.Value then CallIfReady(StartAutoSolveAnchors) end
        -- новые функции: применяем сохранённые состояния и сразу сканируем то, что уже есть на карте
        if Toggles.MY_DoorReach and Toggles.MY_DoorReach.Value then
            DoorReach.Enabled = true
            DoorReach.Distance = Options.MY_DoorReach_Dist.Value or 75
        end
        if Toggles.ESP_Enabled and Toggles.ESP_Enabled.Value then
            ESP.Enabled = true
            CallIfReady(RescanEsp)
        end
        if Toggles.TR_Enabled and Toggles.TR_Enabled.Value then CallIfReady(Tracers.Start) end
        if Toggles.GN_Enabled and Toggles.GN_Enabled.Value then Watcher.Scan("EntityNotifier") end
        Watcher.Refresh()
    end)
end)
--============================================================
-- START
--============================================================
task.spawn(function()
    while not STATE.SplashReady and not Library.Unloaded do task.wait(0.1) end
    task.wait(1.2)
    if Library.Unloaded then return end
    Notify("Load successful.", "LOLHAX LITE v1.8 + Abysall Speed/PositionSpoof.", 5, true)
end)

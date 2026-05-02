-- =====================================================================
--  Distortionz Hijack · config.lua
-- =====================================================================

Config = {}

-- ─── Script meta ────────────────────────────────────────────────────
Config.Script = {
    name    = 'Distortionz Hijack',
    version = '1.0.5',
}
Config.CurrentVersion = Config.Script.version

-- ─── Version checker ────────────────────────────────────────────────
Config.VersionCheck = {
    enabled      = true,
    checkOnStart = true,
    url          = 'https://raw.githubusercontent.com/Distortionzz/Distortionz_Hijack/main/version.json',
}

-- ─── Notify ─────────────────────────────────────────────────────────
Config.Notify = {
    title         = 'Hijack Contact',
    resource      = 'distortionz_notify',
    defaultLength = 5000,
}

-- ─── Hijack contact ped ─────────────────────────────────────────────
Config.Contact = {
    model     = 's_m_y_dealer_01',
    coords    = vector4(1332.08, -1736.30, 55.25, 17.3),
    scenario  = 'WORLD_HUMAN_SMOKING',
    blip = {
        enabled = true,
        sprite  = 524, -- car icon
        color   = 1,
        scale   = 0.7,
        label   = 'Hijack Contact',
    },
    -- ox_target options
    targetLabel = 'Talk to Hijack Contact',
    targetIcon  = 'fa-solid fa-car-burst',
}

-- ─── Drop-off locations (one is chosen at random per job) ───────────
Config.DropOffs = {
    vector4(489.50, -1314.20, 29.20, 175.0),   -- impound lot, La Mesa
    vector4(1233.10, -3258.30, 5.90, 0.0),     -- LSIA hangar zone
    vector4(-417.50, -2789.40, 6.00, 90.0),    -- elysian island docks
    vector4(2342.00, 3127.55, 47.96, 86.0),    -- sandy shores warehouse
}

Config.DropOffMarker = {
    type      = 1,
    size      = vector3(8.0, 8.0, 1.5),
    color     = { r = 220, g = 60, b = 60, a = 120 },
    blipSprite = 477,
    blipColor  = 1,
    blipLabel  = 'Hijack Drop-off',
}

-- ─── Search zone ────────────────────────────────────────────────────
Config.SearchZone = {
    radius             = 120.0,
    blipAlpha          = 120,
    blipColor          = 1,
    showOnRadar        = true,
}

-- ─── Parking spots (where target vehicles can spawn) ────────────────
-- Server picks the closest spot to the player at job-start time.
-- Add or remove vector4(x, y, z, heading) entries to tune your map.
Config.ParkingSpots = {
    -- Mirror Park / East LS area
    vector4(1149.62, -490.45, 65.78, 280.0),
    vector4(1107.32, -416.58, 67.56, 320.0),
    vector4(1207.00, -610.50, 65.13, 270.0),

    -- Vespucci
    vector4(-1080.10, -1664.00, 4.39, 165.0),
    vector4(-1239.05, -1492.55, 4.34, 30.0),
    vector4(-1437.15, -626.07, 30.52, 30.0),

    -- Strawberry / Davis
    vector4(81.20, -1953.10, 21.10, 320.0),
    vector4(127.90, -1722.30, 29.30, 318.0),
    vector4(-117.00, -1455.50, 32.20, 358.0),

    -- Vinewood / Hawick
    vector4(312.20, 178.20, 103.46, 250.0),
    vector4(-585.40, 290.20, 80.10, 90.0),
    vector4(-225.40, -349.40, 30.09, 250.0),

    -- Sandy / Paleto highway pull-offs
    vector4(1735.50, 3284.50, 41.13, 105.0),
    vector4(-389.50, 6045.00, 31.50, 315.0),
    vector4(127.10, 6620.10, 31.80, 270.0),
}

-- ─── Vehicle tiers ──────────────────────────────────────────────────
-- Each tier defines models that can be the target.
-- 'weight' = chance of this tier being picked when a job starts.
-- 'basePay' = dirty money base before multipliers.
Config.VehicleTiers = {
    common = {
        weight  = 50,
        basePay = 1500,
        models  = { 'sultan', 'premier', 'asea', 'asterope', 'fugitive', 'tailgater' },
    },
    mid = {
        weight  = 30,
        basePay = 3500,
        models  = { 'buffalo', 'schafter2', 'felon', 'oracle', 'sentinel', 'jackal' },
    },
    rare = {
        weight  = 15,
        basePay = 7000,
        models  = { 'comet2', 'carbonizzare', 'jugular', 'feltzer2', 'sultanrs', 'kuruma' },
    },
    premium = {
        weight  = 5,
        basePay = 15000,
        models  = { 'zentorno', 't20', 'adder', 'osiris', 'turismor', 'entityxf' },
    },
}

-- ─── Time limits & damage thresholds (for tier rewards) ─────────────
Config.JobTiming = {
    timeLimitSeconds  = 600,    -- 10 minutes total to deliver
    pristineDamageMax = 100.0,  -- engine health loss must be < this for S tier
}

-- ─── Reward multipliers based on delivery quality ───────────────────
Config.Rewards = {
    tiers = {
        S = { label = 'Pristine Pro', multiplier = 1.5, color = 'success' },
        A = { label = 'Clean Job',    multiplier = 1.25, color = 'success' },
        B = { label = 'Sloppy',       multiplier = 1.0,  color = 'primary' },
        C = { label = 'Late',         multiplier = 0.6,  color = 'warning' },
    },
    failureCooldownMinutes = 15,
    successCooldownMinutes = 5,

    payAccount = 'cash',         -- 'cash', 'bank', or 'dirty' (markedbills item if using ox_inventory)
    dirtyMoneyItem = 'markedbills',
}

-- ─── Police alerts (chance-based, configurable) ─────────────────────
Config.Police = {
    minOnDuty       = 0,        -- only alert if at least this many officers online (0 = always)
    alertOnSteal    = 35,       -- % chance to alert police when player enters the target vehicle
    alertOnCrash    = 60,       -- % chance to alert when vehicle damage spikes badly
    alertOnDelivery = 15,       -- % chance to alert at drop-off
    crashDamageThreshold = 250.0, -- single-tick health loss to count as a "crash"
    blipDuration    = 90,       -- seconds the alert blip stays on cop maps
    jobNames = { 'police', 'sheriff', 'sasp' }, -- considered cops
}

-- ─── Bonus loot drop ────────────────────────────────────────────────
Config.BonusLoot = {
    enabled = true,
    chance  = 15,  -- % chance on successful delivery (tier B or above)
    items = {
        { item = 'lockpick',         weight = 40, amount = { 1, 2 } },
        { item = 'advancedlockpick', weight = 25, amount = { 1, 1 } },
        { item = 'cryptostick',      weight = 20, amount = { 1, 1 } },
        { item = 'goldchain',        weight = 10, amount = { 1, 2 } },
        { item = 'rolex',            weight = 5,  amount = { 1, 1 } },
    }
}

-- ─── Misc ───────────────────────────────────────────────────────────
Config.Debug = false

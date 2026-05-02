-- =====================================================================
--  Distortionz Hijack · server.lua
-- =====================================================================

local QBX = exports.qbx_core
local activeJobs = {}      -- [src] = jobData
local cooldowns  = {}      -- [src] = expiresEpoch

-- ─── Helpers ────────────────────────────────────────────────────────

local function Notify(source, message, notifyType, duration, title)
    if not source or not message then return end

    notifyType = notifyType or 'primary'
    duration   = tonumber(duration) or Config.Notify.defaultLength
    title      = title or Config.Notify.title

    if notifyType == 'inform' then notifyType = 'info' end

    if GetResourceState(Config.Notify.resource) == 'started' then
        TriggerClientEvent('distortionz_notify:client:notify', source, {
            title    = title,
            message  = message,
            type     = notifyType,
            duration = duration,
        })
        return
    end

    if GetResourceState('ox_lib') == 'started' then
        TriggerClientEvent('ox_lib:notify', source, {
            title       = title,
            description = message,
            type        = notifyType,
            duration    = duration,
        })
        return
    end

    TriggerClientEvent('QBCore:Notify', source, message, notifyType, duration)
end

local function Debug(...)
    if Config.Debug then
        print(('^5[distortionz_hijack]^7 %s'):format(table.concat({...}, ' ')))
    end
end

local function GetSecondsLeft(src)
    local expires = cooldowns[src]
    if not expires then return 0 end
    local left = expires - os.time()
    return left > 0 and left or 0
end

local function SetCooldown(src, minutes)
    cooldowns[src] = os.time() + (minutes * 60)
end

-- ─── Vehicle tier roller (weighted) ─────────────────────────────────

local function RollWeighted(entries)
    local total = 0
    for _, e in ipairs(entries) do total = total + (e.weight or 0) end
    if total <= 0 then return entries[1] end

    local roll = math.random(1, total)
    local acc = 0
    for _, e in ipairs(entries) do
        acc = acc + (e.weight or 0)
        if roll <= acc then return e end
    end

    return entries[#entries]
end

local function PickTargetVehicle()
    local tiers = {}
    for tierName, tier in pairs(Config.VehicleTiers) do
        tiers[#tiers + 1] = {
            name    = tierName,
            weight  = tier.weight,
            basePay = tier.basePay,
            models  = tier.models,
        }
    end

    local picked = RollWeighted(tiers)
    local model  = picked.models[math.random(1, #picked.models)]
    return picked.name, model, picked.basePay
end

local function GeneratePlate()
    local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local plate = ''
    for _ = 1, 3 do
        local i = math.random(1, #letters)
        plate = plate .. letters:sub(i, i)
    end
    plate = plate .. tostring(math.random(100, 999))
    local i = math.random(1, #letters)
    plate = plate .. letters:sub(i, i)
    return plate
end

local CAR_COLORS = {
    'Black', 'White', 'Silver', 'Gray', 'Red', 'Dark Red', 'Blue', 'Dark Blue',
    'Green', 'Yellow', 'Orange', 'Purple', 'Bronze', 'Pearl White'
}
local function PickColor()
    return CAR_COLORS[math.random(1, #CAR_COLORS)]
end

-- ─── Bonus loot roller ──────────────────────────────────────────────

local function MaybeRollLoot(src)
    if not Config.BonusLoot.enabled then return nil end
    if math.random(1, 100) > Config.BonusLoot.chance then return nil end

    local pick = RollWeighted(Config.BonusLoot.items)
    if not pick then return nil end

    local amt = pick.amount or { 1, 1 }
    local quantity = math.random(amt[1] or 1, amt[2] or 1)

    local ok = exports.ox_inventory:AddItem(src, pick.item, quantity)
    if ok then
        return { item = pick.item, amount = quantity }
    end
    return nil
end

-- ─── Police alert helper ────────────────────────────────────────────

local function CountActiveCops()
    local count = 0
    local players = QBX:GetPlayers()
    for _, playerId in ipairs(players) do
        local p = QBX:GetPlayer(playerId)
        if p and p.PlayerData and p.PlayerData.job then
            for _, jobName in ipairs(Config.Police.jobNames) do
                if p.PlayerData.job.name == jobName and p.PlayerData.job.onduty then
                    count = count + 1
                    break
                end
            end
        end
    end
    return count
end

local function MaybeAlertPolice(coords, chancePercent, reason)
    if math.random(1, 100) > chancePercent then return false end

    local cops = CountActiveCops()
    if cops < Config.Police.minOnDuty then return false end

    TriggerClientEvent('distortionz_hijack:client:policeAlert', -1, {
        coords   = coords,
        reason   = reason or 'Vehicle theft in progress',
        duration = Config.Police.blipDuration,
    })
    return true
end

-- ─── Reward calculator ──────────────────────────────────────────────

local function ComputeRewardTier(jobData, deliveredAtEpoch, finalDamage)
    local elapsed = deliveredAtEpoch - jobData.startedAt
    local onTime  = elapsed <= Config.JobTiming.timeLimitSeconds
    local clean   = finalDamage <= Config.JobTiming.pristineDamageMax

    if onTime and clean then return 'S' end
    if onTime then return 'A' end
    if elapsed <= (Config.JobTiming.timeLimitSeconds * 1.5) then return 'B' end
    return 'C'
end

local function PayPlayer(src, amount)
    local payAccount = Config.Rewards.payAccount

    if payAccount == 'dirty' then
        local ok = exports.ox_inventory:AddItem(src, Config.Rewards.dirtyMoneyItem, amount)
        return ok and true or false
    end

    local Player = QBX:GetPlayer(src)
    if not Player then return false end
    Player.Functions.AddMoney(payAccount, amount, 'distortionz-hijack-payout')
    return true
end

-- ─── Job lifecycle ──────────────────────────────────────────────────

lib.callback.register('distortionz_hijack:server:requestJob', function(source, playerCoords)
    local src = source

    if activeJobs[src] then
        return { success = false, reason = 'You already have an active hijack contract.' }
    end

    local cdLeft = GetSecondsLeft(src)
    if cdLeft > 0 then
        local mins = math.ceil(cdLeft / 60)
        return { success = false, reason = ('Lay low. Try again in %d minute(s).'):format(mins) }
    end

    if type(playerCoords) ~= 'vector3' then
        return { success = false, reason = 'Invalid request.' }
    end

    local tier, model, basePay = PickTargetVehicle()
    local plate = GeneratePlate()
    local color = PickColor()

    if not Config.ParkingSpots or #Config.ParkingSpots == 0 then
        return { success = false, reason = 'No parking spots configured.' }
    end

    -- Pick a parking spot at random from the pool
    local parkingSpot = Config.ParkingSpots[math.random(1, #Config.ParkingSpots)]

    -- Pick a drop-off
    local dropoff = Config.DropOffs[math.random(1, #Config.DropOffs)]

    activeJobs[src] = {
        tier        = tier,
        model       = model,
        basePay     = basePay,
        plate       = plate,
        color       = color,
        dropoff     = dropoff,
        parkingSpot = parkingSpot,
        startedAt   = os.time(),
        confirmed   = false,
        targetNetId = nil,
    }

    Debug(('Job assigned to %s: tier=%s model=%s plate=%s spot=(%.1f, %.1f)'):format(
        src, tier, model, plate, parkingSpot.x, parkingSpot.y
    ))

    return {
        success = true,
        job = {
            tier         = tier,
            model        = model,
            basePay      = basePay,
            plate        = plate,
            color        = color,
            dropoff      = { x = dropoff.x, y = dropoff.y, z = dropoff.z, w = dropoff.w },
            parkingSpot  = { x = parkingSpot.x, y = parkingSpot.y, z = parkingSpot.z, w = parkingSpot.w },
            timeLimit    = Config.JobTiming.timeLimitSeconds,
            searchZoneRadius = Config.SearchZone.radius,
        }
    }
end)

RegisterNetEvent('distortionz_hijack:server:targetEntered', function(netId)
    local src = source
    local job = activeJobs[src]
    if not job then return end
    if job.confirmed then return end

    job.confirmed = true
    job.targetNetId = netId

    local entity = NetworkGetEntityFromNetworkId(netId)

    -- Give the player keys so they can drive (qbx_vehiclekeys integration)
    if entity and entity ~= 0 and GetResourceState('qbx_vehiclekeys') == 'started' then
        local ok, err = pcall(function()
            exports.qbx_vehiclekeys:GiveKeys(src, entity)
        end)
        if not ok then
            Debug(('GiveKeys failed: %s'):format(tostring(err)))
        end
    end

    -- Roll for steal alert
    local alerted = false
    if entity and entity ~= 0 then
        local coords = GetEntityCoords(entity)
        alerted = MaybeAlertPolice(coords, Config.Police.alertOnSteal, 'Vehicle theft reported')
    end

    Notify(src,
        alerted and 'You\'ve been spotted! Get to the drop-off fast.' or 'Keys obtained. Get to the drop-off.',
        alerted and 'warning' or 'success',
        6000
    )
end)

RegisterNetEvent('distortionz_hijack:server:crashSpike', function(coords)
    local src = source
    local job = activeJobs[src]
    if not job or not job.confirmed then return end
    if type(coords) ~= 'vector3' then return end

    MaybeAlertPolice(coords, Config.Police.alertOnCrash, 'Reckless driver, possible stolen vehicle')
end)

lib.callback.register('distortionz_hijack:server:deliver', function(source, payload)
    local src = source
    local job = activeJobs[src]

    if not job then
        return { success = false, reason = 'You do not have an active contract.' }
    end
    if not job.confirmed then
        return { success = false, reason = 'You haven\'t taken the vehicle yet.' }
    end
    if type(payload) ~= 'table' then
        return { success = false, reason = 'Invalid delivery payload.' }
    end

    local pCoords      = payload.coords
    local engineHealth = tonumber(payload.engineHealth) or 1000.0
    local plateClient  = payload.plate or ''

    -- Validate proximity to drop-off
    if type(pCoords) ~= 'vector3' then
        return { success = false, reason = 'Invalid coordinates.' }
    end
    local dx = pCoords.x - job.dropoff.x
    local dy = pCoords.y - job.dropoff.y
    local dz = pCoords.z - job.dropoff.z
    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
    if dist > 12.0 then
        return { success = false, reason = 'You are too far from the drop-off.' }
    end

    -- Validate the plate matches what we issued
    if plateClient:gsub('%s+', '') ~= job.plate:gsub('%s+', '') then
        return { success = false, reason = 'This isn\'t the right vehicle.' }
    end

    -- Damage = how much engine health was lost from full (1000)
    local damageTaken = math.max(0, 1000.0 - engineHealth)

    -- Compute tier
    local now = os.time()
    local tier = ComputeRewardTier(job, now, damageTaken)
    local tierData = Config.Rewards.tiers[tier]
    local finalPay = math.floor(job.basePay * (tierData.multiplier or 1))

    -- Pay
    local paid = PayPlayer(src, finalPay)
    if not paid then
        activeJobs[src] = nil
        SetCooldown(src, Config.Rewards.failureCooldownMinutes)
        return { success = false, reason = 'Payout failed. Contract void.' }
    end

    -- Bonus loot only on B or higher (reward consistent jobs, not late ones)
    local lootDropped = nil
    if tier ~= 'C' then
        lootDropped = MaybeRollLoot(src)
    end

    -- Maybe alert police on delivery
    MaybeAlertPolice(pCoords, Config.Police.alertOnDelivery, 'Suspicious activity at impound zone')

    -- Remove keys from the player (qbx_vehiclekeys integration)
    if job.targetNetId and GetResourceState('qbx_vehiclekeys') == 'started' then
        local entity = NetworkGetEntityFromNetworkId(job.targetNetId)
        if entity and entity ~= 0 then
            local ok, err = pcall(function()
                exports.qbx_vehiclekeys:RemoveKeys(src, entity, true)
            end)
            if not ok then
                Debug(('RemoveKeys failed: %s'):format(tostring(err)))
            end
        end
    end

    -- Cleanup
    activeJobs[src] = nil
    SetCooldown(src, Config.Rewards.successCooldownMinutes)

    Debug(('Delivered: src=%s tier=%s pay=%s loot=%s'):format(src, tier, finalPay, lootDropped and lootDropped.item or 'none'))

    return {
        success     = true,
        tier        = tier,
        tierLabel   = tierData.label,
        tierColor   = tierData.color,
        payout      = finalPay,
        lootDropped = lootDropped,
    }
end)

RegisterNetEvent('distortionz_hijack:server:cancelJob', function(reason)
    local src = source
    if not activeJobs[src] then return end

    activeJobs[src] = nil
    SetCooldown(src, Config.Rewards.failureCooldownMinutes)

    Notify(src, reason or 'Contract failed.', 'error', 6000)
end)

-- ─── Cleanup on disconnect ──────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source
    activeJobs[src] = nil
    cooldowns[src]  = nil
end)

-- ─── Resource start banner ──────────────────────────────────────────

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    print(('^5[%s]^7 Started successfully. Version: ^2%s^7'):format(
        resourceName, Config.Script.version or '1.0.0'
    ))
end)

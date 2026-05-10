-- =====================================================================
--  Distortionz Hijack · client.lua
-- =====================================================================

local contactPed   = nil
local contactBlip  = nil

local activeJob    = nil
local searchBlip   = nil
local targetBlip   = nil
local dropoffBlip  = nil
local jobEndsAt    = 0

local lastEngineHealth = 1000.0

-- ─── Notify wrapper ─────────────────────────────────────────────────

local function Notify(message, notifyType, duration, title)
    if not message then return end

    notifyType = notifyType or 'primary'
    duration   = tonumber(duration) or Config.Notify.defaultLength
    title      = title or Config.Notify.title

    if notifyType == 'inform' then notifyType = 'info' end

    if GetResourceState(Config.Notify.resource) == 'started' then
        exports[Config.Notify.resource]:Notify(message, notifyType, duration, title)
        return
    end

    lib.notify({
        title       = title,
        description = message,
        type        = notifyType,
        duration    = duration,
    })
end

-- ─── NUI panel control ──────────────────────────────────────────────

local function GetStageKey()
    if not activeJob then return 'searching' end
    if activeJob.confirmed then return 'driving' end
    -- "found" stage triggers when player gets within 80m of the parked car
    if activeJob.targetVehicle and DoesEntityExist(activeJob.targetVehicle) then
        local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(activeJob.targetVehicle))
        if dist <= 80.0 then return 'found' end
    end
    return 'searching'
end

local function PanelShow()
    if not activeJob then return end
    SendNUIMessage({
        action      = 'show',
        stage       = GetStageKey(),
        tier        = activeJob.tier or 'common',
        secondsLeft = math.max(0, math.floor((jobEndsAt - GetGameTimer()) / 1000)),
        vehicle     = activeJob.modelLabel or activeJob.model or '—',
        color       = activeJob.color or '—',
        plate       = activeJob.plate or '—',
        payout      = activeJob.basePay or 0,
    })
end

local function PanelHide()
    SendNUIMessage({ action = 'hide' })
end

-- Live update loop (fires once per second while a job is active)
CreateThread(function()
    while true do
        if activeJob then
            local secondsLeft = math.max(0, math.floor((jobEndsAt - GetGameTimer()) / 1000))
            SendNUIMessage({
                action      = 'update',
                stage       = GetStageKey(),
                tier        = activeJob.tier or 'common',
                secondsLeft = secondsLeft,
                vehicle     = activeJob.modelLabel or activeJob.model or '—',
                color       = activeJob.color or '—',
                plate       = activeJob.plate or '—',
                payout      = activeJob.basePay or 0,
            })
            Wait(1000)
        else
            Wait(500)
        end
    end
end)

-- ─── v1.1.0 — Damage sampler (Engine + Body health, live penalty) ───
-- Samples the target vehicle's engine + body health while the player
-- is driving it (post-confirm), pushes percentages to the HUD with a
-- live penalty preview. Server is the source of truth for the FINAL
-- penalty at delivery; this loop is purely visual/preview.
CreateThread(function()
    local interval = (Config.DamagePenalty and Config.DamagePenalty.snapshotIntervalMs) or 500
    local dollarsPerHp = (Config.DamagePenalty and Config.DamagePenalty.dollarsPerHp) or 0
    local enabled = Config.DamagePenalty and Config.DamagePenalty.enabled

    while true do
        local sleep = interval

        if enabled and activeJob and activeJob.confirmed and DoesEntityExist(activeJob.targetVehicle) then
            local veh = activeJob.targetVehicle
            local ped = PlayerPedId()
            -- Only sample while the player is in the target vehicle
            if GetVehiclePedIsIn(ped, false) == veh then
                local engHp  = GetVehicleEngineHealth(veh) or 1000.0   -- 0..1000
                local bodyHp = GetVehicleBodyHealth(veh)   or 1000.0   -- 0..1000

                -- Clamp to sane range (engine can go negative when burning)
                if engHp  < 0    then engHp  = 0 end
                if engHp  > 1000 then engHp  = 1000 end
                if bodyHp < 0    then bodyHp = 0 end
                if bodyHp > 1000 then bodyHp = 1000 end

                local engineLost = 1000.0 - engHp
                local bodyLost   = 1000.0 - bodyHp
                local penalty    = math.floor((engineLost + bodyLost) * dollarsPerHp)

                SendNUIMessage({
                    action    = 'health',
                    show      = true,
                    enginePct = (engHp  / 1000.0) * 100.0,
                    bodyPct   = (bodyHp / 1000.0) * 100.0,
                    penalty   = penalty,
                })
            end
        elseif activeJob and not activeJob.confirmed then
            -- Hide health block during searching/found stages
            SendNUIMessage({ action = 'health', show = false })
            sleep = 1000
        else
            sleep = 1000
        end

        Wait(sleep)
    end
end)


-- ─── Contact ped spawn / cleanup ────────────────────────────────────

local function SpawnContactPed()
    if contactPed and DoesEntityExist(contactPed) then return end

    local modelHash = joaat(Config.Contact.model)
    lib.requestModel(modelHash, 10000)

    contactPed = CreatePed(0, modelHash, Config.Contact.coords.x, Config.Contact.coords.y, Config.Contact.coords.z, Config.Contact.coords.w, false, true)
    SetEntityInvincible(contactPed, true)
    SetBlockingOfNonTemporaryEvents(contactPed, true)
    FreezeEntityPosition(contactPed, true)
    SetPedFleeAttributes(contactPed, 0, false)
    SetPedDiesWhenInjured(contactPed, false)

    -- v1.1.3 — Distortionz convention: flag as protected so other scripts
    -- (distortionz_robped, etc.) skip this ped for player interactions.
    Entity(contactPed).state:set('distortionz_protected_ped', true, true)
    Entity(contactPed).state:set('distortionz_contact_ped',   true, true)
    Entity(contactPed).state:set('distortionz_hijack_ped',    true, true)

    if Config.Contact.scenario then
        TaskStartScenarioInPlace(contactPed, Config.Contact.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(modelHash)

    exports.ox_target:addLocalEntity(contactPed, {
        {
            name        = 'distortionz_hijack_contact',
            label       = Config.Contact.targetLabel,
            icon        = Config.Contact.targetIcon,
            distance    = 2.5,
            onSelect    = function()
                TriggerEvent('distortionz_hijack:client:requestJob')
            end,
        }
    })
end

local function CreateContactBlip()
    if not Config.Contact.blip or not Config.Contact.blip.enabled then return end
    if contactBlip then return end

    contactBlip = AddBlipForCoord(Config.Contact.coords.x, Config.Contact.coords.y, Config.Contact.coords.z)
    SetBlipSprite(contactBlip, Config.Contact.blip.sprite)
    SetBlipColour(contactBlip, Config.Contact.blip.color)
    SetBlipScale(contactBlip, Config.Contact.blip.scale)
    SetBlipAsShortRange(contactBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Contact.blip.label)
    EndTextCommandSetBlipName(contactBlip)
end

local function RemoveContactPed()
    if contactPed and DoesEntityExist(contactPed) then
        exports.ox_target:removeLocalEntity(contactPed, 'distortionz_hijack_contact')
        DeletePed(contactPed)
    end
    contactPed = nil

    if contactBlip and DoesBlipExist(contactBlip) then
        RemoveBlip(contactBlip)
    end
    contactBlip = nil
end

-- ─── Job state cleanup ──────────────────────────────────────────────

local function ClearJobBlips()
    if searchBlip and DoesBlipExist(searchBlip) then RemoveBlip(searchBlip) end
    if targetBlip and DoesBlipExist(targetBlip) then RemoveBlip(targetBlip) end
    if dropoffBlip and DoesBlipExist(dropoffBlip) then RemoveBlip(dropoffBlip) end
    searchBlip, targetBlip, dropoffBlip = nil, nil, nil
end

local function EndJob(reason, notifyType)
    if not activeJob then return end

    -- Despawn the target vehicle if it still exists and we're not driving it
    if activeJob.targetVehicle and DoesEntityExist(activeJob.targetVehicle) then
        local ped = PlayerPedId()
        local currentVeh = GetVehiclePedIsIn(ped, false)
        if currentVeh ~= activeJob.targetVehicle then
            SetEntityAsMissionEntity(activeJob.targetVehicle, true, true)
            DeleteVehicle(activeJob.targetVehicle)
        end
    end

    activeJob = nil
    ClearJobBlips()
    PanelHide()
    jobEndsAt = 0
    lastEngineHealth = 1000.0

    if reason then
        Notify(reason, notifyType or 'error', 7000)
    end
end

-- ─── Spawn the target vehicle at the designated parking spot ───────

local CAR_COLOR_MAP = {
    ['Black']        = 0,
    ['White']        = 111,
    ['Silver']       = 4,
    ['Gray']         = 5,
    ['Red']          = 27,
    ['Dark Red']     = 28,
    ['Blue']         = 64,
    ['Dark Blue']    = 62,
    ['Green']        = 53,
    ['Yellow']       = 88,
    ['Orange']       = 38,
    ['Purple']       = 145,
    ['Bronze']       = 90,
    ['Pearl White']  = 134,
}

local function SpawnTargetVehicle()
    if not activeJob or not activeJob.parkingSpot then return end

    local modelHash = joaat(activeJob.model)
    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        Notify('Target model is invalid. Contract void.', 'error', 6000)
        TriggerServerEvent('distortionz_hijack:server:cancelJob', 'Invalid model')
        EndJob(nil, nil)
        return
    end

    lib.requestModel(modelHash, 10000)

    local spot = activeJob.parkingSpot
    local veh = CreateVehicle(modelHash, spot.x, spot.y, spot.z, spot.w, true, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(veh) then
        Notify('Failed to spawn target vehicle. Try again later.', 'error', 6000)
        TriggerServerEvent('distortionz_hijack:server:cancelJob', 'Spawn failed')
        EndJob(nil, nil)
        return
    end

    -- Apply plate + color
    SetVehicleNumberPlateText(veh, activeJob.plate)
    local colorId = CAR_COLOR_MAP[activeJob.color] or 0
    SetVehicleColours(veh, colorId, colorId)

    -- Lock and let it settle
    SetVehicleOnGroundProperly(veh)
    SetVehicleDoorsLocked(veh, 1) -- unlocked — keys granted on entry
    -- v1.1.4 — pre-set the doorslockstate statebag so qbx_vehiclekeys' enter-attempt
    -- handler skips its spawnLockedIfParked roll (which was re-locking our targets).
    Entity(veh).state:set('doorslockstate', 1, true)
    SetVehicleEngineOn(veh, false, true, true)
    SetEntityAsMissionEntity(veh, true, true)

    activeJob.targetVehicle = veh
    -- Note: search blip and target blip stay as-is for now.
    -- Target blip / "Found" notification fire when player gets close.
end

-- ─── Drop-off blip ──────────────────────────────────────────────────

local function ShowDropoffBlip()
    if dropoffBlip and DoesBlipExist(dropoffBlip) then return end
    if not activeJob or not activeJob.dropoff then return end

    dropoffBlip = AddBlipForCoord(activeJob.dropoff.x, activeJob.dropoff.y, activeJob.dropoff.z)
    SetBlipSprite(dropoffBlip, Config.DropOffMarker.blipSprite)
    SetBlipColour(dropoffBlip, Config.DropOffMarker.blipColor)
    SetBlipScale(dropoffBlip, 0.9)
    SetBlipRoute(dropoffBlip, true)
    SetBlipRouteColour(dropoffBlip, Config.DropOffMarker.blipColor)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.DropOffMarker.blipLabel)
    EndTextCommandSetBlipName(dropoffBlip)
end

-- ─── Main loops ─────────────────────────────────────────────────────

-- Proximity thread: when player gets within 80m of the parked target,
-- swap the search-radius blip for a precise vehicle blip and notify once.
CreateThread(function()
    while true do
        if activeJob and activeJob.targetVehicle and DoesEntityExist(activeJob.targetVehicle) and not activeJob.foundAnnounced then
            local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(activeJob.targetVehicle))
            if dist <= 80.0 then
                activeJob.foundAnnounced = true

                if searchBlip and DoesBlipExist(searchBlip) then
                    RemoveBlip(searchBlip); searchBlip = nil
                end

                targetBlip = AddBlipForEntity(activeJob.targetVehicle)
                SetBlipSprite(targetBlip, 225)
                SetBlipColour(targetBlip, 1)
                SetBlipScale(targetBlip, 0.9)
                SetBlipAsShortRange(targetBlip, false)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString('Hijack Target')
                EndTextCommandSetBlipName(targetBlip)

                Notify(('Target spotted nearby. %s · %s · plate %s'):format(
                    activeJob.color, activeJob.modelLabel or activeJob.model, activeJob.plate
                ), 'success', 6000)
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000

        if activeJob and activeJob.targetVehicle and DoesEntityExist(activeJob.targetVehicle) then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and veh == activeJob.targetVehicle and not activeJob.confirmed then
                activeJob.confirmed = true
                ShowDropoffBlip()

                local netId = NetworkGetNetworkIdFromEntity(veh)
                TriggerServerEvent('distortionz_hijack:server:targetEntered', netId)

                Notify(('You got the %s. Drop it at the marked location.'):format(activeJob.modelLabel or activeJob.model), 'success', 6000)
            end

            if activeJob.confirmed and veh == activeJob.targetVehicle then
                local engHealth = GetVehicleEngineHealth(veh)
                local lost = lastEngineHealth - engHealth
                if lost >= Config.Police.crashDamageThreshold then
                    TriggerServerEvent('distortionz_hijack:server:crashSpike', GetEntityCoords(veh))
                end
                lastEngineHealth = engHealth

                if engHealth <= 0 or IsEntityDead(veh) then
                    TriggerServerEvent('distortionz_hijack:server:cancelJob', 'The vehicle was destroyed. Contract failed.')
                    EndJob(nil, nil)
                end
            end

            if activeJob and activeJob.confirmed and veh == activeJob.targetVehicle then
                local pCoords = GetEntityCoords(ped)
                local dDist = #(pCoords - vector3(activeJob.dropoff.x, activeJob.dropoff.y, activeJob.dropoff.z))

                if dDist <= 8.0 then
                    sleep = 0
                    DrawMarker(
                        Config.DropOffMarker.type,
                        activeJob.dropoff.x, activeJob.dropoff.y, activeJob.dropoff.z - 0.9,
                        0, 0, 0, 0, 0, 0,
                        Config.DropOffMarker.size.x, Config.DropOffMarker.size.y, Config.DropOffMarker.size.z,
                        Config.DropOffMarker.color.r, Config.DropOffMarker.color.g, Config.DropOffMarker.color.b, Config.DropOffMarker.color.a,
                        false, false, 2, false, nil, nil, false
                    )

                    if dDist <= 4.0 then
                        lib.showTextUI('[E] Drop off vehicle', { position = 'right-center' })

                        if IsControlJustPressed(0, 38) then
                            lib.hideTextUI()

                            local engineHealth = GetVehicleEngineHealth(veh)
                            local bodyHealth   = GetVehicleBodyHealth(veh)  -- v1.1.0
                            local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')

                            local result = lib.callback.await('distortionz_hijack:server:deliver', false, {
                                coords       = pCoords,
                                engineHealth = engineHealth,
                                bodyHealth   = bodyHealth,  -- v1.1.0
                                plate        = plate,
                            })

                            if result and result.success then
                                TaskLeaveVehicle(ped, veh, 0)
                                Wait(1000)
                                if DoesEntityExist(veh) then
                                    SetEntityAsMissionEntity(veh, true, true)
                                    DeleteVehicle(veh)
                                end

                                local payoutLine = ('Tier %s — %s · $%s'):format(result.tier, result.tierLabel, result.payout)
                                Notify(payoutLine, result.tierColor or 'success', 8000)

                                -- v1.1.0 — surface damage penalty if it took a chunk
                                if result.penalty and result.penalty > 0 then
                                    Wait(600)
                                    Notify(('Damage cost you $%s'):format(result.penalty), 'error', 5000)
                                end

                                if result.lootDropped then
                                    Wait(800)
                                    Notify(('Bonus: %sx %s'):format(result.lootDropped.amount, result.lootDropped.item), 'cash', 6000)
                                end

                                EndJob(nil, nil)
                            elseif result and result.reason then
                                Notify(result.reason, 'error', 5000)
                            end
                        end
                    else
                        lib.hideTextUI()
                    end
                else
                    lib.hideTextUI()
                end
            end

            if jobEndsAt > 0 and GetGameTimer() > (jobEndsAt + (Config.JobTiming.timeLimitSeconds * 500)) then
                TriggerServerEvent('distortionz_hijack:server:cancelJob', 'Time ran out. Contract failed.')
                EndJob(nil, nil)
            end
        end

        Wait(sleep)
    end
end)

-- ─── Job request handler ────────────────────────────────────────────

RegisterNetEvent('distortionz_hijack:client:requestJob', function()
    if activeJob then
        Notify('You already have an active contract.', 'warning', 5000)
        return
    end

    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)

    local result = lib.callback.await('distortionz_hijack:server:requestJob', false, pCoords)
    if not result or not result.success then
        Notify(result and result.reason or 'Could not start contract.', 'error', 6000)
        return
    end

    local job = result.job

    activeJob = {
        tier             = job.tier,
        model            = job.model,
        modelLabel       = GetLabelText(GetDisplayNameFromVehicleModel(joaat(job.model))) or job.model,
        basePay          = job.basePay,
        plate            = job.plate,
        color            = job.color,
        dropoff          = job.dropoff,
        parkingSpot      = job.parkingSpot,
        searchZoneRadius = job.searchZoneRadius,
        confirmed        = false,
        found            = false,
        targetVehicle    = nil,
    }
    jobEndsAt        = GetGameTimer() + (job.timeLimit * 1000)
    lastEngineHealth = 1000.0

    -- Search zone centered on the parking spot
    searchBlip = AddBlipForRadius(job.parkingSpot.x, job.parkingSpot.y, job.parkingSpot.z, Config.SearchZone.radius)
    SetBlipColour(searchBlip, Config.SearchZone.blipColor)
    SetBlipAlpha(searchBlip, Config.SearchZone.blipAlpha)
    SetBlipHighDetail(searchBlip, Config.SearchZone.showOnRadar)

    PanelShow()

    Notify(('Target: %s · %s · plate %s'):format(activeJob.color, activeJob.modelLabel, activeJob.plate), 'primary', 8000)
    Wait(800)
    Notify('Search the marked area on your map.', 'info', 6000)

    -- Spawn the target vehicle at the parking spot
    Wait(500)
    SpawnTargetVehicle()
end)

-- ─── Police alert receiver ──────────────────────────────────────────

RegisterNetEvent('distortionz_hijack:client:policeAlert', function(payload)
    if not payload or not payload.coords then return end

    local PlayerData = exports.qbx_core:GetPlayerData()
    if not PlayerData or not PlayerData.job then return end

    local isCop = false
    for _, j in ipairs(Config.Police.jobNames) do
        if PlayerData.job.name == j and PlayerData.job.onduty then
            isCop = true; break
        end
    end
    if not isCop then return end

    local coords = payload.coords
    if type(coords) == 'table' then
        coords = vector3(coords.x or 0, coords.y or 0, coords.z or 0)
    end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 225)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('10-31 ' .. (payload.reason or 'Vehicle theft'))
    EndTextCommandSetBlipName(blip)

    Notify(payload.reason or 'Vehicle theft reported', 'police', 8000, 'Dispatch')

    SetTimeout((payload.duration or 90) * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

-- ─── Spawn ped on resource start ────────────────────────────────────

CreateThread(function()
    Wait(1500)
    SpawnContactPed()
    CreateContactBlip()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveContactPed()
    ClearJobBlips()
    PanelHide()
    if lib and lib.hideTextUI then lib.hideTextUI() end
end)

local config = require 'config.client'
local sharedConfig = require 'config.shared'
local vehicles = require 'client.vehicles'

---@param station table
local function createBlip(station)
    if not station then return end

    local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
    SetBlipSprite(blip, station.sprite or 60)
    SetBlipAsShortRange(blip, true)
    SetBlipScale(blip, station.scale or 0.8)
    SetBlipColour(blip, station.color or 29)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(station.label or 'Police Station')
    EndTextCommandSetBlipName(blip)
end

---@param job string
---@param station table
local function createDuty(job, station)
    if not job or not station then return end

    for i = 1, #station do
        local location = station[i]

        exports.ox_target:addSphereZone({
            coords = location.coords,
            radius = location.radius or 1.5,
            debug = config.debugPoly,
            options = {
                {
                    name = ('%s-Duty'):format(job),
                    icon = 'fa-solid fa-clipboard-user',
                    label = 'Clock In/Out',
                    serverEvent = 'QBCore:ToggleDuty',
                    groups = location.groups,
                    distance = 1.5,
                },
            }
        })
    end
end

---@param job string
---@param station table
local function createManagement(job, station)
    if not job or not station then return end

    for i = 1, #station do
        local location = station[i]

        exports.ox_target:addSphereZone({
            coords = location.coords,
            radius = location.radius or 1.5,
            debug = config.debugPoly,
            options = {
                {
                    name = ('%s-BossMenu'):format(job),
                    icon = 'fa-solid fa-people-roof',
                    label = 'Open Job Management',
                    canInteract = function()
                        return QBX.PlayerData.job.isboss and QBX.PlayerData.job.onduty
                    end,
                    onSelect = function()
                        exports.qbx_management:OpenBossMenu('job')
                    end,
                    groups = location.groups,
                    distance = 1.5,
                },
            }
        })
    end
end

---@param job string
---@param station table
local function createPersonalStash(job, station)
    if not job or not station then return end

    for i = 1, #station do
        local stash = station.personalStash[i]
        local stashName = ('%s-%s-PersonalStash'):format(i, QBX.PlayerData.job.name)

        exports.ox_target:addSphereZone({
            coords = stash.coords,
            radius = stash.radius,
            debug = config.debugPoly,
            options = {
                {
                    name = stashName,
                    icon = 'fa-solid fa-box-archive',
                    label = 'Open Personal Stash',
                    canInteract = function()
                        return QBX.PlayerData.job.onduty
                    end,
                    onSelect = function()
                        exports.ox_inventory:openInventory('stash', stashName)
                    end,
                    groups = stash.groups,
                    distance = 1.5,
                },
            }
        })
    end
end

---@param job string
---@param station table
local function createEvidence(job, station)
    if not job or not station then return end

    for i = 1, #station do
        local evidence = station[i]

        exports.ox_target:addSphereZone({
            coords = evidence.coords,
            radius = evidence.radius,
            debug = config.debugPoly,
            options = {
                {
                    name = ('%s-EvidenceDrawers'):format(job),
                    icon = 'fa-solid fa-box-archive',
                    label = 'Open the Evidence Drawers',
                    canInteract = function()
                        return QBX.PlayerData.job.onduty
                    end,
                    onSelect = function()
                        exports.ox_inventory:openInventory('policeevidence')
                    end,
                    groups = evidence.groups,
                    distance = 1.5,
                },
            }
        })
    end
end

---@param job string
---@param station table
local function createGarage(job, station)
    if not job or not station then return end

    for i = 1, #station do
        local garage = station[i]

        exports.ox_target:addSphereZone({
            coords = garage.coords,
            radius = garage.radius,
            debug = config.debugPoly,
            options = {
                {
                    name = ('%s-Garage'):format(job),
                    icon = 'fa-solid fa-warehouse',
                    label = 'Open Garage',
                    canInteract = function()
                        return not cache.vehicle and QBX.PlayerData.job.onduty
                    end,
                    onSelect = function()
                        vehicles.openGarage(garage)
                    end,
                    groups = garage.groups,
                    distance = 1.5,
                },
                {
                    name = ('%s-GarageStore'):format(job),
                    icon = 'fa-solid fa-square-parking',
                    label = 'Store Vehicle',
                    canInteract = function()
                        return cache.vehicle and QBX.PlayerData.job.onduty
                    end,
                    onSelect = function()
                        vehicles.store(cache.vehicle)
                    end,
                    groups = garage.groups,
                    distance = 1.5,
                },
            }
        })
    end
end

---@param job string
---@param station table
local function createHelipad(job, station)
    if not job or not station then return end

    for i = 1, #station do
        local helipad = station[i]

        exports.ox_target:addSphereZone({
            coords = helipad.coords,
            radius = helipad.radius,
            debug = config.debugPoly,
            options = {
                {
                    name = ('%s-Helipad'):format(job),
                    icon = 'fa-solid fa-helicopter-symbol',
                    label = 'Open Helipad',
                    canInteract = function()
                        return not cache.vehicle and QBX.PlayerData.job.onduty
                    end,
                    onSelect = function()
                        vehicles.openHelipad(helipad)
                    end,
                    groups = helipad.groups,
                    distance = 1.5,
                },
                {
                    name = ('%s-HelipadStore'):format(job),
                    icon = 'fa-solid fa-square-parking',
                    label = 'Store Helicopter',
                    canInteract = function()
                        return cache.vehicle and QBX.PlayerData.job.onduty
                    end,
                    onSelect = function()
                        vehicles.store(cache.vehicle)
                    end,
                    groups = helipad.groups,
                    distance = 1.5,
                },
            }
        })
    end
end

local function registerAliveRadial()
    lib.registerRadial({
        id = 'policeMenu',
        items = {
            {
                icon = 'lock',
                label = 'Cuff',
                onSelect = function()
                end,
            },
            {
                icon = 'lock-open',
                label = 'Uncuff',
                onSelect = function()
                end,
            },
            {
                icon = 'magnifying-glass',
                label = 'Search',
                onSelect = function()
                    exports.ox_inventory:openNearbyInventory()
                end,
            },
            {
                icon = 'heart-crack',
                label = '10-99A',
                onSelect = function()
                end,
            },
            {
                icon = 'heart-pulse',
                label = '10-99B',
                onSelect = function()
                end,
            },
            {
                icon = 'truck-fast',
                label = 'Impound',
                onSelect = function()
                end,
            },
            {
                icon = 'truck-ramp-box',
                label = 'Confiscate',
                onSelect = function()
                end,
            },
        }
    })
end

local function registerDeadRadial()
    lib.registerRadial({
        id = 'policeMenu',
        items = {
            {
                icon = 'heart-crack',
                label = '10-99A',
                onSelect = function()
                end,
            },
            {
                icon = 'heart-pulse',
                label = '10-99B',
                onSelect = function()
                end,
            },
        }
    })
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    if QBX.PlayerData.job.type ~= 'leo' then return end

    if QBX.PlayerData.metadata.isdead then
        registerDeadRadial()
    else
        registerAliveRadial()
    end

    lib.addRadialItem({
        id = 'leo',
        icon = 'shield-halved',
        label = 'Police',
        menu = 'policeMenu'
    })
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    lib.removeRadialItem('leo')

    if QBX.PlayerData.job.type ~= 'leo' then return end

    lib.addRadialItem({
        id = 'leo',
        icon = 'shield-halved',
        label = 'Police',
        menu = 'policeMenu'
    })
end)

AddStateBagChangeHandler('DEATH_STATE_STATE_BAG', nil, function(bagName, _, dead)
    local player = GetPlayerFromStateBagName(bagName)

    if player ~= cache.playerId or QBX.PlayerData?.job?.type ~= 'leo' then return end

    lib.removeRadialItem('leo')

    if dead then
        registerDeadRadial()
    else
        registerAliveRadial()
    end

    lib.addRadialItem({
        id = 'leo',
        icon = 'shield-halved',
        label = 'Police',
        menu = 'policeMenu'
    })
end)

CreateThread(function()
    Wait(150)

    for job, data in pairs(sharedConfig.departments) do
        createBlip(data.blip)
        createDuty(job, data.duty)
        createManagement(job, data.management)
        createPersonalStash(job, data.personalStash)
        createEvidence(job, data.evidence)
        createGarage(job, data.garage)
        createHelipad(job, data.helipad)
    end
end)
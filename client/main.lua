-- Variables
QBCore = exports['qb-core']:GetCoreObject()
isHandcuffed = false
cuffType = 1
isEscorted = false
PlayerJob = QBCore.Functions.GetPlayerData()?.job or {}
onDuty = PlayerJob?.onduty or false
local DutyBlips = {}

-- Functions
local function CreateDutyBlips(playerId, playerLabel, playerJob, playerLocation)
    local ped = GetPlayerPed(playerId)
    local blip = GetBlipFromEntity(ped)

    if not DoesBlipExist(blip) then
        if NetworkIsPlayerActive(playerId) then
            blip = AddBlipForEntity(ped)
        else
            blip = AddBlipForCoord(playerLocation.x, playerLocation.y, playerLocation.z)
        end

        SetBlipSprite(blip, 1)
        ShowHeadingIndicatorOnBlip(blip, true)
        SetBlipRotation(blip, math.ceil(playerLocation.w))
        SetBlipScale(blip, 1.0)

        if playerJob == 'police' then
            SetBlipColour(blip, 38)
        else
            SetBlipColour(blip, 5)
        end

        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(playerLabel)
        EndTextCommandSetBlipName(blip)

        DutyBlips[#DutyBlips + 1] = blip
    end

    if GetBlipFromEntity(cache.ped) == blip then
        -- Ensure we remove our own blip.
        RemoveBlip(blip)
    end
end

-- Events
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local player = QBCore.Functions.GetPlayerData()

    PlayerJob = player.job
    onDuty = player.job.onduty
    isHandcuffed = false

    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    TriggerServerEvent('police:server:UpdateCurrentCops')

    local trackerClothingData = {}

    if player.metadata.tracker then
        trackerClothingData.outfitData = {
            ['accessory'] = {
                item = 13,
                texture = 0
            }
        }
    else
        trackerClothingData.outfitData = {
            ['accessory'] = {
                item = -1,
                texture = 0
            }
        }
    end

    TriggerEvent('qb-clothing:client:loadOutfit', trackerClothingData)

    if PlayerJob and PlayerJob.type ~= 'leo' then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end

        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    TriggerServerEvent('police:server:UpdateCurrentCops')

    isHandcuffed = false
    isEscorted = false
    onDuty = false

    ClearPedTasks(cache.ped)
    DetachEntity(cache.ped, true, false)

    if DutyBlips then
        for _, v in pairs(DutyBlips) do
            RemoveBlip(v)
        end

        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    if JobInfo.type == 'leo' and PlayerJob.type ~= 'leo' then
        if JobInfo.onduty then
            TriggerServerEvent('QBCore:ToggleDuty')

            onDuty = false
        end
    end

    if JobInfo.type ~= 'leo' then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end

        DutyBlips = {}
    end

    PlayerJob = JobInfo
end)

RegisterNetEvent('police:client:sendBillingMail', function(amount)
    SetTimeout(math.random(2500, 4000), function()
        local gender = Lang:t('info.mr')

        if QBCore.Functions.GetPlayerData().charinfo.gender == 1 then
            gender = Lang:t('info.mrs')
        end

        local charinfo = QBCore.Functions.GetPlayerData().charinfo

        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = Lang:t('email.sender'),
            subject = Lang:t('email.subject'),
            message = Lang:t('email.message', {
                value = gender,
                value2 = charinfo.lastname,
                value3 = amount
            }),
            button = {}
        })
    end)
end)

RegisterNetEvent('police:client:UpdateBlips', function(players)
    if PlayerJob and (PlayerJob.type == 'leo' or PlayerJob.name == 'ambulance') and
        onDuty then

        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end

        DutyBlips = {}

        if players then
            for _, data in pairs(players) do
                local id = GetPlayerFromServerId(data.source)

                CreateDutyBlips(id, data.label, data.job, data.location)
            end
        end
    end
end)

RegisterNetEvent('police:client:policeAlert', function(coords, text)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1name = GetStreetNameFromHashKey(street1)
    local street2name = GetStreetNameFromHashKey(street2)

    lib.notify({
        title = text,
        description = street1name .. ' ' .. street2name
    })

    PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)

    local transG = 250
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blip2 = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blipText = Lang:t('info.blip_text', {
        value = text
    })

    SetBlipSprite(blip, 60)
    SetBlipSprite(blip2, 161)
    SetBlipColour(blip, 1)
    SetBlipColour(blip2, 1)
    SetBlipDisplay(blip, 4)
    SetBlipDisplay(blip2, 8)
    SetBlipAlpha(blip, transG)
    SetBlipAlpha(blip2, transG)
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    SetBlipAsShortRange(blip, false)
    SetBlipAsShortRange(blip2, false)
    PulseBlip(blip2)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blipText)
    EndTextCommandSetBlipName(blip)

    while transG ~= 0 do
        Wait(180 * 4)

        transG = transG - 1

        SetBlipAlpha(blip, transG)
        SetBlipAlpha(blip2, transG)

        if transG == 0 then
            RemoveBlip(blip)
            return
        end
    end
end)

RegisterNetEvent('police:client:SendToJail', function(time)
    TriggerServerEvent('police:server:SetHandcuffStatus', false)

    isHandcuffed = false
    isEscorted = false

    ClearPedTasks(cache.ped)
    DetachEntity(cache.ped, true, false)

    TriggerEvent('prison:client:Enter', time)
end)

RegisterNetEvent('police:client:SendPoliceEmergencyAlert', function()
    local PlayerData = QBCore.Functions.GetPlayerData()

    TriggerServerEvent('police:server:policeAlert', Lang:t('info.officer_down', {
        lastname = PlayerData.charinfo.lastname,
        callsign = PlayerData.metadata.callsign
    }))
    TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.officer_down', {
        lastname = PlayerData.charinfo.lastname,
        callsign = PlayerData.metadata.callsign
    }))
end)

-- Threads
CreateThread(function()
    for _, station in pairs(Config.Locations.stations) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)

        SetBlipSprite(blip, 60)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 29)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)
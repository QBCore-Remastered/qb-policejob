-- Variables
local Plates = {}
local PlayerStatus = {}
local Casings = {}
local BloodDrops = {}
local FingerDrops = {}
local Objects = {}
local QBCore = exports['qbx-core']:GetCoreObject()
local updatingCops = false

-- Functions
local function UpdateBlips()
    local dutyPlayers = {}
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and (v.PlayerData.job.type == "leo" or v.PlayerData.job.name == "ambulance") and v.PlayerData.job.onduty then
            local coords = GetEntityCoords(GetPlayerPed(v.PlayerData.source))
            local heading = GetEntityHeading(GetPlayerPed(v.PlayerData.source))
            dutyPlayers[#dutyPlayers+1] = {
                source = v.PlayerData.source,
                label = v.PlayerData.metadata.callsign,
                job = v.PlayerData.job.name,
                location = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    w = heading
                }
            }
        end
    end
    TriggerClientEvent("police:client:UpdateBlips", -1, dutyPlayers)
end

local function generateId(table)
    local id = math.random(10000, 99999)
    if not table then return id end
    while table[id] do
        id = math.random(10000, 99999)
    end
    return id
end

local function IsVehicleOwned(plate)
    return MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
end

local function DnaHash(s)
    return string.gsub(s, ".", function(c)
        return string.format("%02x", string.byte(c))
    end)
end

-- Commands
QBCore.Commands.Add("spikestrip", Lang:t("commands.place_spike"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or Player.PlayerData.job.type ~= "leo" or not Player.PlayerData.job.onduty then return end

    TriggerClientEvent('police:client:SpawnSpikeStrip', source)
end)

QBCore.Commands.Add("grantlicense", Lang:t("commands.license_grant"), {{name = "id", help = Lang:t('info.player_id')}, {name = "license", help = Lang:t('info.license_type')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type ~= "leo"  or Player.PlayerData.job.grade.level < Config.LicenseRank then
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.error_rank_license"), type = 'error'})
        return
    end
    if args[2] ~= "driver" and args[2] ~= "weapon" then
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.license_type"), type = 'error'})
        return
    end
    local SearchedPlayer = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if not SearchedPlayer then return end
    local licenseTable = SearchedPlayer.PlayerData.metadata.licences
    if licenseTable[args[2]] then
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.license_already"), type = 'error'})
        return
    end
    licenseTable[args[2]] = true
    SearchedPlayer.Functions.SetMetaData("licences", licenseTable)
    TriggerClientEvent('ox_lib:notify', SearchedPlayer.PlayerData.source, {description = Lang:t("success.granted_license"), type = 'success'})
    TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("success.grant_license"), type = 'success'})
end)

QBCore.Commands.Add("revokelicense", Lang:t("commands.license_revoke"), {{name = "id", help = Lang:t('info.player_id')}, {name = "license", help = Lang:t('info.license_type')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type ~= "leo" or Player.PlayerData.job.grade.level < Config.LicenseRank then
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.rank_revoke"), type = "error"})
        return
    end
    if args[2] ~= "driver" and args[2] ~= "weapon" then
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.error_license"), type = "error"})
        return
    end
    local SearchedPlayer = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if not SearchedPlayer then return end
    local licenseTable = SearchedPlayer.PlayerData.metadata.licences
    if not licenseTable[args[2]] then
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.error_license"), type = "error"})
        return
    end
    licenseTable[args[2]] = false
    SearchedPlayer.Functions.SetMetaData("licences", licenseTable)
    TriggerClientEvent('ox_lib:notify', SearchedPlayer.PlayerData.source, {description = Lang:t("error.revoked_license"), type = "error"})
    TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("success.revoke_license"), type = "success"})
end)

QBCore.Commands.Add("pobject", Lang:t("commands.place_object"), {{name = "type",help = Lang:t("info.poobject_object")}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    local type = args[1]:lower()
    if not (Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty) then
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
        return
    end

    if type == 'delete' then
        TriggerClientEvent("police:client:deleteObject", source)
        return
    end

    if Config.Objects[type] then
        TriggerClientEvent("police:client:spawnPObj", source, type)
    end
end)

QBCore.Commands.Add("cuff", Lang:t("commands.cuff_player"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:CuffPlayer", source)
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("escort", Lang:t("commands.escort"), {}, false, function(source)
    TriggerClientEvent("police:client:EscortPlayer", source)
end)

QBCore.Commands.Add("callsign", Lang:t("commands.callsign"), {{name = "name", help = Lang:t('info.callsign_name')}}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    Player.Functions.SetMetaData("callsign", table.concat(args, " "))
end)

QBCore.Commands.Add("clearcasings", Lang:t("commands.clear_casign"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("evidence:client:ClearCasingsInArea", source)
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("jail", Lang:t("commands.jail_player"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:JailPlayer", source)
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("unjail", Lang:t("commands.unjail_player"), {{name = "id", help = Lang:t('info.player_id')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("prison:client:UnjailPerson", tonumber(args[1]) --[[@as number]])
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("clearblood", Lang:t("commands.clearblood"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("evidence:client:ClearBlooddropsInArea", source)
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("seizecash", Lang:t("commands.seizecash"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:SeizeCash", source)
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("sc", Lang:t("commands.softcuff"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:CuffPlayerSoft", source)
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("cam", Lang:t("commands.camera"), {{name = "camid", help = Lang:t('info.camera_id')}}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:ActiveCamera", source, tonumber(args[1]))
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("flagplate", Lang:t("commands.flagplate"), {{name = "plate", help = Lang:t('info.plate_number')}, {name = "reason", help = Lang:t('info.flag_reason')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        local reason = {}
        for i = 2, #args, 1 do
            reason[#reason+1] = args[i]
        end
        Plates[args[1]:upper()] = {
            isflagged = true,
            reason = table.concat(reason, " ")
        }
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("info.vehicle_flagged", {vehicle = args[1]:upper(), reason = table.concat(reason, " ")})})
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("unflagplate", Lang:t("commands.unflagplate"), {{name = "plate", help = Lang:t('info.plate_number')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        if Plates and Plates[args[1]:upper()] then
            if Plates[args[1]:upper()].isflagged then
                Plates[args[1]:upper()].isflagged = false
                TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("info.unflag_vehicle", {vehicle = args[1]:upper()})})
            else
                TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.vehicle_not_flag"), type = 'error'})
            end
        else
            TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.vehicle_not_flag"), type = 'error'})
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("plateinfo", Lang:t("commands.plateinfo"), {{name = "plate", help = Lang:t('info.plate_number')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        if Plates and Plates[args[1]:upper()] then
            if Plates[args[1]:upper()].isflagged then
                TriggerClientEvent('ox_lib:notify', source, {description = Lang:t('success.vehicle_flagged', {plate = args[1]:upper(), reason = Plates[args[1]:upper()].reason}), type = 'success'})
            else
                TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.vehicle_not_flag"), type = 'error'})
            end
        else
            TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.vehicle_not_flag"), type = 'error'})
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("depot", Lang:t("commands.depot"), {{name = "price", help = Lang:t('info.impound_price')}}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:ImpoundVehicle", source, false, tonumber(args[1]))
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("impound", Lang:t("commands.impound"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:ImpoundVehicle", source, true)
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("paytow", Lang:t("commands.paytow"), {{name = "id", help = Lang:t('info.player_id')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        local playerId = tonumber(args[1])
        local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
        if OtherPlayer then
            if OtherPlayer.PlayerData.job.name == "tow" then
                OtherPlayer.Functions.AddMoney("bank", 500, "police-tow-paid")
                TriggerClientEvent('ox_lib:notify', OtherPlayer.PlayerData.source, {description = Lang:t("success.tow_paid"), type = 'success'})
                TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("info.tow_driver_paid")})
            else
                TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.not_towdriver"), type = 'error'})
            end
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("paylawyer", Lang:t("commands.paylawyer"), {{name = "id",help = Lang:t('info.player_id')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" or Player.PlayerData.job.name == "judge" then
        local playerId = tonumber(args[1])
        local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
        if not OtherPlayer then return end
        if OtherPlayer.PlayerData.job.name == "lawyer" then
            OtherPlayer.Functions.AddMoney("bank", 500, "police-lawyer-paid")
            TriggerClientEvent('ox_lib:notify', OtherPlayer.PlayerData.source, {description = Lang:t("success.tow_paid"), type = 'success'})
            TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("info.paid_lawyer")})
        else
            TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.not_lawyer"), type = "error"})
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("anklet", Lang:t("commands.anklet"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:CheckDistance", source)
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("ankletlocation", Lang:t("commands.ankletlocation"), {{name = "cid", help = Lang:t('info.citizen_id')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == "leo" and Player.PlayerData.job.onduty then
        local citizenid = args[1]
        local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if not Target then return end
        if Target.PlayerData.metadata.tracker then
            TriggerClientEvent("police:client:SendTrackerLocation", Target.PlayerData.source, source)
        else
            TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.no_anklet"), type = 'error'})
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.on_duty_police_only"), type = 'error'})
    end
end)

QBCore.Commands.Add("takedna", Lang:t("commands.takedna"), {{name = "id", help = Lang:t('info.player_id')}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    local OtherPlayer = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if not OtherPlayer or Player.PlayerData.job.type ~= "leo" or not Player.PlayerData.job.onduty then return end
    if Player.Functions.RemoveItem("empty_evidence_bag", 1) then
        local info = {
            label = Lang:t('info.dna_sample'),
            type = "dna",
            dnalabel = DnaHash(OtherPlayer.PlayerData.citizenid),
            description = DnaHash(OtherPlayer.PlayerData.citizenid)
        }
        if not Player.Functions.AddItem("filled_evidence_bag", 1, false, info) then return end
        TriggerClientEvent("inventory:client:ItemBox", source, QBCore.Shared.Items.filled_evidence_bag, "add")
    else
        TriggerClientEvent('ox_lib:notify', source, {description = Lang:t("error.have_evidence_bag"), type = "error"})
    end
end)

RegisterNetEvent('police:server:SendTrackerLocation', function(coords, requestId)
    local Target = QBCore.Functions.GetPlayer(source)
    local msg = Lang:t('info.target_location', {firstname = Target.PlayerData.charinfo.firstname, lastname = Target.PlayerData.charinfo.lastname})
    local alertData = {
        title = Lang:t('info.anklet_location'),
        coords = coords,
        description = msg
    }
    TriggerClientEvent("police:client:TrackerMessage", requestId, msg, coords)
    TriggerClientEvent("qb-phone:client:addPoliceAlert", requestId, alertData)
end)

QBCore.Commands.Add('911p', Lang:t("commands.police_report"), {{name='message', help= Lang:t("commands.message_sent")}}, false, function(source, args)
    local message
	if args[1] then message = table.concat(args, " ") else message = Lang:t("commands.civilian_call") end
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            local alertData = {title = Lang:t("commands.emergency_call"), coords = {x = coords.x, y = coords.y, z = coords.z}, description = message}
            TriggerClientEvent("qb-phone:client:addPoliceAlert", v.PlayerData.source, alertData)
            TriggerClientEvent('police:client:policeAlert', v.PlayerData.source, coords, message)
        end
    end
end)

-- Items
QBCore.Functions.CreateUseableItem("handcuffs", function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player.Functions.GetItemByName("handcuffs") then return end
    TriggerClientEvent("police:client:CuffPlayerSoft", source)
end)

QBCore.Functions.CreateUseableItem("moneybag", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not Player.Functions.GetItemByName("moneybag") or not item.info or item.info == "" or Player.PlayerData.job.type == "leo" or not Player.Functions.RemoveItem("moneybag", 1, item.slot) then return end
    Player.Functions.AddMoney("cash", tonumber(item.info.cash), "used-moneybag")
end)

-- Callbacks
lib.callback.register('police:server:isPlayerDead', function(_, playerId)
    local Player = QBCore.Functions.GetPlayer(playerId)
    return Player.PlayerData.metadata.idead
end)

lib.callback.register('police:GetPlayerStatus', function(_, playerId)
    local Player = QBCore.Functions.GetPlayer(playerId)
    local statList = {}
    if Player then
        if PlayerStatus[Player.PlayerData.source] and next(PlayerStatus[Player.PlayerData.source]) then
            for k in pairs(PlayerStatus[Player.PlayerData.source]) do
                statList[#statList + 1] = PlayerStatus[Player.PlayerData.source][k].text
            end
        end
    end
    cb(statList)
end)

lib.callback.register('police:GetImpoundedVehicles', function()
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE state = ?', {2})
    if result[1] then
        return result
    end
end)

local function isPlateFlagged(plate)
    if Plates and Plates[plate] and Plates[plate].isflagged then
        return true
     end
     return false
end

---@deprecated use qbx-police:server:isPlateFlagged
QBCore.Functions.CreateCallback('police:IsPlateFlagged', function(_, cb, plate)
    print(string.format("%s invoked deprecated callback police:IsPlateFlagged. Use police:server:IsPoliceForcePresent instead.", GetInvokingResource()))
    cb(isPlateFlagged(plate))
end)

lib.callback.register('qbx-police:server:isPlateFlagged', function(_, plate)
    return isPlateFlagged(plate)
end)

local function isPoliceForcePresent()
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == "leo" and v.PlayerData.job.grade.level >= 2 then
            return true
        end
    end
    return false
end

---@deprecated
QBCore.Functions.CreateCallback('police:server:IsPoliceForcePresent', function(_, cb)
    print(string.format("%s invoked deprecated callback police:server:IsPoliceForcePresent. Use police:server:isPoliceForcePresent instead.", GetInvokingResource()))
    cb(isPoliceForcePresent())
end)

lib.callback.register('police:server:isPoliceForcePresent', function()
    return isPoliceForcePresent()
end)

-- Events
RegisterNetEvent('police:server:Radar', function(fine)
    local source = source
    local price  = Config.SpeedFines[fine].fine
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player.Functions.RemoveMoney("bank", math.floor(price), "Radar Fine") then return end
    exports['qbx-management']:AddMoney('police', price)
    TriggerClientEvent('QBCore:Notify', source, Lang:t("info.fine_received", {fine = price}))
end)

RegisterNetEvent('police:server:policeAlert', function(text)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = QBCore.Functions.GetQBPlayers()
    for k, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            local alertData = {title = Lang:t('info.new_call'), coords = coords, description = text}
            TriggerClientEvent("qb-phone:client:addPoliceAlert", k, alertData)
            TriggerClientEvent('police:client:policeAlert', k, coords, text)
        end
    end
end)

RegisterNetEvent('police:server:TakeOutImpound', function(plate, garage)
    local src = source
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = Config.Locations.impound[garage]
    if #(playerCoords - targetCoords) > 10.0 then return DropPlayer(src, "Attempted exploit abuse") end

    MySQL.update('UPDATE player_vehicles SET state = ? WHERE plate = ?', {0, plate})
    TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("success.impound_vehicle_removed"), type = 'success'})
end)

RegisterNetEvent('police:server:CuffPlayer', function(playerId, isSoftcuff)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local Player = QBCore.Functions.GetPlayer(src)
    local CuffedPlayer = QBCore.Functions.GetPlayer(playerId)
    if not Player or not CuffedPlayer or (not Player.Functions.GetItemByName("handcuffs") and Player.PlayerData.job.type ~= "leo") then return end

    TriggerClientEvent("police:client:GetCuffed", CuffedPlayer.PlayerData.source, Player.PlayerData.source, isSoftcuff)
end)

RegisterNetEvent('police:server:EscortPlayer', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local Player = QBCore.Functions.GetPlayer(source)
    local EscortPlayer = QBCore.Functions.GetPlayer(playerId)
    if not Player or not EscortPlayer then return end

    if (Player.PlayerData.job.type == "leo" or Player.PlayerData.job.name == "ambulance") or (EscortPlayer.PlayerData.metadata.ishandcuffed or EscortPlayer.PlayerData.metadata.isdead or EscortPlayer.PlayerData.metadata.inlaststand) then
        TriggerClientEvent("police:client:GetEscorted", EscortPlayer.PlayerData.source, Player.PlayerData.source)
    else
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("error.not_cuffed_dead"), type = 'error'})
    end
end)

RegisterNetEvent('police:server:KidnapPlayer', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local Player = QBCore.Functions.GetPlayer(source)
    local EscortPlayer = QBCore.Functions.GetPlayer(playerId)
    if not Player or not EscortPlayer then return end

    if EscortPlayer.PlayerData.metadata.ishandcuffed or EscortPlayer.PlayerData.metadata.isdead or EscortPlayer.PlayerData.metadata.inlaststand then
        TriggerClientEvent("police:client:GetKidnappedTarget", EscortPlayer.PlayerData.source, Player.PlayerData.source)
        TriggerClientEvent("police:client:GetKidnappedDragger", Player.PlayerData.source, EscortPlayer.PlayerData.source)
    else
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("error.not_cuffed_dead"), type = 'error'})
    end
end)

RegisterNetEvent('police:server:SetPlayerOutVehicle', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local EscortPlayer = QBCore.Functions.GetPlayer(playerId)
    if not QBCore.Functions.GetPlayer(src) or not EscortPlayer then return end

    if EscortPlayer.PlayerData.metadata.ishandcuffed or EscortPlayer.PlayerData.metadata.isdead then
        TriggerClientEvent("police:client:SetOutVehicle", EscortPlayer.PlayerData.source)
    else
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("error.not_cuffed_dead"), type = 'error'})
    end
end)

RegisterNetEvent('police:server:PutPlayerInVehicle', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local EscortPlayer = QBCore.Functions.GetPlayer(playerId)
    if not QBCore.Functions.GetPlayer(src) or not EscortPlayer then return end

    if EscortPlayer.PlayerData.metadata.ishandcuffed or EscortPlayer.PlayerData.metadata.isdead then
        TriggerClientEvent("police:client:PutInVehicle", EscortPlayer.PlayerData.source)
    else
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("error.not_cuffed_dead"), type = 'error'})
    end
end)

RegisterNetEvent('police:server:BillPlayer', function(playerId, price)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local Player = QBCore.Functions.GetPlayer(src)
    local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
    if not Player or not OtherPlayer or Player.PlayerData.job.type ~= "leo" then return end

    OtherPlayer.Functions.RemoveMoney("bank", price, "paid-bills")
    exports['qbx-management']:AddMoney("police", price)
    TriggerClientEvent('ox_lib:notify', OtherPlayer.PlayerData.source, {description = Lang:t("info.fine_received", {fine = price})})
end)

RegisterNetEvent('police:server:JailPlayer', function(playerId, time)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local Player = QBCore.Functions.GetPlayer(src)
    local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
    if not Player or not OtherPlayer or Player.PlayerData.job.type ~= "leo" then return end

    local currentDate = os.date("*t")
    if currentDate.day == 31 then
        currentDate.day = 30
    end

    OtherPlayer.Functions.SetMetaData("injail", time)
    OtherPlayer.Functions.SetMetaData("criminalrecord", {
        hasRecord = true,
        date = currentDate
    })
    TriggerClientEvent("police:client:SendToJail", OtherPlayer.PlayerData.source, time)
    TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("info.sent_jail_for", {time = time})})
end)

RegisterNetEvent('police:server:SetHandcuffStatus', function(isHandcuffed)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    Player.Functions.SetMetaData("ishandcuffed", isHandcuffed)
end)

RegisterNetEvent('heli:spotlight', function(state)
    TriggerClientEvent('heli:spotlight', -1, source, state)
end)

RegisterNetEvent('police:server:FlaggedPlateTriggered', function(radar, plate, street)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = QBCore.Functions.GetQBPlayers()
    for k, v in pairs(players) do
        if v and v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            local alertData = {title = Lang:t('info.new_call'), coords = coords, description = Lang:t('info.plate_triggered', {plate = plate, street = street, radar = radar})}
            TriggerClientEvent("qb-phone:client:addPoliceAlert", k, alertData)
            TriggerClientEvent('police:client:policeAlert', k, coords, Lang:t('info.plate_triggered_blip', {radar = radar}))
        end
    end
end)

RegisterNetEvent('police:server:SearchPlayer', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local SearchedPlayer = QBCore.Functions.GetPlayer(playerId)
    if not QBCore.Functions.GetPlayer(src) or not SearchedPlayer then return end

    TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("info.searched_success")})
    TriggerClientEvent('ox_lib:notify', SearchedPlayer.PlayerData.source, {description = Lang:t("info.being_searched")})
end)

RegisterNetEvent('police:server:SeizeCash', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local Player = QBCore.Functions.GetPlayer(src)
    local SearchedPlayer = QBCore.Functions.GetPlayer(playerId)
    if not Player or not SearchedPlayer then return end

    local moneyAmount = SearchedPlayer.PlayerData.money.cash
    local info = { cash = moneyAmount }
    SearchedPlayer.Functions.RemoveMoney("cash", moneyAmount, "police-cash-seized")
    Player.Functions.AddItem("moneybag", 1, false, info)
    TriggerClientEvent('ox_lib:notify', SearchedPlayer.PlayerData.source, {description = Lang:t("info.cash_confiscated")})
end)

RegisterNetEvent('police:server:RobPlayer', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local Player = QBCore.Functions.GetPlayer(src)
    local SearchedPlayer = QBCore.Functions.GetPlayer(playerId)
    if not Player or not SearchedPlayer then return end

    local money = SearchedPlayer.PlayerData.money.cash
    Player.Functions.AddMoney("cash", money, "police-player-robbed")
    SearchedPlayer.Functions.RemoveMoney("cash", money, "police-player-robbed")
    TriggerClientEvent('ox_lib:notify', SearchedPlayer.PlayerData.source, {description = Lang:t("info.cash_robbed", {money = money})})
    TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {description = Lang:t("info.stolen_money", {stolen = money})})
end)

RegisterNetEvent('police:server:spawnObject', function(type)
    local src = source
    local objectId = generateId(Objects)
    Objects[objectId] = type
    TriggerClientEvent("police:client:spawnObject", src, objectId, type)
end)

RegisterNetEvent('police:server:deleteObject', function(objectId)
    TriggerClientEvent('police:client:removeObject', -1, objectId)
end)

RegisterNetEvent('police:server:Impound', function(plate, fullImpound, price, body, engine, fuel)
    local src = source
    price = price and price or 0
    if IsVehicleOwned(plate) then
        if not fullImpound then
            MySQL.query('UPDATE player_vehicles SET state = ?, depotprice = ?, body = ?, engine = ?, fuel = ? WHERE plate = ?', {0, price, body, engine, fuel, plate})
            TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("info.vehicle_taken_depot", {price = price})})
        else
            MySQL.query('UPDATE player_vehicles SET state = ?, body = ?, engine = ?, fuel = ? WHERE plate = ?', {2, body, engine, fuel, plate})
            TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("info.vehicle_seized")})
        end
    end
end)

RegisterNetEvent('evidence:server:UpdateStatus', function(data)
    PlayerStatus[source] = data
end)

RegisterNetEvent('evidence:server:CreateBloodDrop', function(citizenid, bloodtype, coords)
    local bloodId = generateId(BloodDrops)
    BloodDrops[bloodId] = {
        dna = citizenid,
        bloodtype = bloodtype
    }
    TriggerClientEvent("evidence:client:AddBlooddrop", -1, bloodId, citizenid, bloodtype, coords)
end)

RegisterNetEvent('evidence:server:CreateFingerDrop', function(coords)
    local Player = QBCore.Functions.GetPlayer(source)
    local fingerId = generateId(FingerDrops)
    FingerDrops[fingerId] = Player.PlayerData.metadata.fingerprint
    TriggerClientEvent("evidence:client:AddFingerPrint", -1, fingerId, Player.PlayerData.metadata.fingerprint, coords)
end)

RegisterNetEvent('evidence:server:ClearBlooddrops', function(blooddropList)
    if blooddropList and next(blooddropList) then
        for _, v in pairs(blooddropList) do
            TriggerClientEvent("evidence:client:RemoveBlooddrop", -1, v)
            BloodDrops[v] = nil
        end
    end
end)

RegisterNetEvent('evidence:server:AddBlooddropToInventory', function(bloodId, bloodInfo)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local playerName = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname
    local streetName = bloodInfo.street
    local bloodType = bloodInfo.bloodtype
    local bloodDNA = bloodInfo.dnalabe
    local metadata = {}
        metadata.type = 'Blood Evidence'
        metadata.description = "DNA ID: "..bloodDNA
        metadata.description = metadata.description.."\n\nCollected By: "..playerName
        metadata.description = metadata.description.."\n\nCollected At: "..streetName
    if exports.ox_inventory:RemoveItem(src, 'empty_evidence_bag', 1) then
        if exports.ox_inventory:AddItem(src, 'filled_evidence_bag', 1, metadata) then
            TriggerClientEvent("evidence:client:RemoveBlooddrop", -1, bloodId)
            BloodDrops[bloodId] = nil
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("error.have_evidence_bag"), type = "error"})
    end
end)

RegisterNetEvent('evidence:server:AddFingerprintToInventory', function(fingerId, fingerInfo)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local playerName = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname
    local streetName = fingerInfo.street
    local fingerPrint = fingerInfo.fingerprint
    local metadata = {}
        metadata.type = 'Fingerprint Evidence'
        metadata.description = "Fingerprint ID: "..fingerPrint
        metadata.description = metadata.description.."\n\nCollected By: "..playerName
        metadata.description = metadata.description.."\n\nCollected At: "..streetName
    if exports.ox_inventory:RemoveItem(src, 'empty_evidence_bag', 1) then
        if exports.ox_inventory:AddItem(src, 'filled_evidence_bag', 1, metadata) then
            TriggerClientEvent("evidence:client:RemoveFingerprint", -1, fingerId)
            FingerDrops[fingerId] = nil
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("error.have_evidence_bag"), type = "error"})
    end
end)

RegisterNetEvent('evidence:server:CreateCasing', function(weapon, coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local casingId = generateId(Casings)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    local serieNumber = nil
    if weaponData then
        if weaponData.metadata then
            if weaponData.metadata.serial then
                serieNumber = weaponData.metadata.serial
            end
        end
    end
    TriggerClientEvent("evidence:client:AddCasing", -1, casingId, weapon, coords, serieNumber)
end)

RegisterNetEvent('police:server:UpdateCurrentCops', function()
    local amount = 0
    local players = QBCore.Functions.GetQBPlayers()
    if updatingCops then return end
    updatingCops = true
    for _, v in pairs(players) do
        if v and v.PlayerData.job.type == "leo" and v.PlayerData.job.onduty then
            amount += 1
        end
    end
    TriggerClientEvent("police:SetCopCount", -1, amount)
    updatingCops = false
end)

RegisterNetEvent('evidence:server:ClearCasings', function(casingList)
    if casingList and next(casingList) then
        for _, v in pairs(casingList) do
            TriggerClientEvent("evidence:client:RemoveCasing", -1, v)
            Casings[v] = nil
        end
    end
end)

RegisterNetEvent('evidence:server:AddCasingToInventory', function(casingId, casingInfo)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local playerName = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname
    local streetName = casingInfo.street
    local ammoType = casingInfo.ammolabel
    local serialNumber = casingInfo.serie
    local metadata = {}
        metadata.type = 'Casing Evidence'
        metadata.description = "Ammo Type: "..ammoType
        metadata.description = metadata.description.."\n\nSerial #: "..serialNumber
        metadata.description = metadata.description.."\n\nCollected By: "..playerName
        metadata.description = metadata.description.."\n\nCollected At: "..streetName
    if exports.ox_inventory:RemoveItem(src, 'empty_evidence_bag', 1) then
        if exports.ox_inventory:AddItem(src, 'filled_evidence_bag', 1, metadata) then
            TriggerClientEvent("evidence:client:RemoveCasing", -1, casingId)
            Casings[casingId] = nil
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("error.have_evidence_bag"), type = "error"})
    end
end)

RegisterNetEvent('police:server:showFingerprint', function(playerId)
    TriggerClientEvent('police:client:showFingerprint', playerId, source)
    TriggerClientEvent('police:client:showFingerprint', source, playerId)
end)

RegisterNetEvent('police:server:showFingerprintId', function(sessionId)
    local Player = QBCore.Functions.GetPlayer(source)
    local fid = Player.PlayerData.metadata.fingerprint
    TriggerClientEvent('police:client:showFingerprintId', sessionId, fid)
    TriggerClientEvent('police:client:showFingerprintId', source, fid)
end)

RegisterNetEvent('police:server:SetTracker', function(targetId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end

    local Target = QBCore.Functions.GetPlayer(targetId)
    if not QBCore.Functions.GetPlayer(src) or not Target then return end

    local TrackerMeta = Target.PlayerData.metadata.tracker
    if TrackerMeta then
        Target.Functions.SetMetaData("tracker", false)
        TriggerClientEvent('ox_lib:notify', targetId, {description = Lang:t("success.anklet_taken_off"), type = 'success'})
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("success.took_anklet_from", {firstname = Target.PlayerData.charinfo.firstname, lastname = Target.PlayerData.charinfo.lastname}), type = 'success'})
        TriggerClientEvent('police:client:SetTracker', targetId, false)
    else
        Target.Functions.SetMetaData("tracker", true)
        TriggerClientEvent('ox_lib:notify', targetId, {description = Lang:t("success.put_anklet"), type = 'success'})
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("success.put_anklet_on", {firstname = Target.PlayerData.charinfo.firstname, lastname = Target.PlayerData.charinfo.lastname}), type = 'success'})
        TriggerClientEvent('police:client:SetTracker', targetId, true)
    end
end)

RegisterNetEvent('police:server:SyncSpikes', function(table)
    TriggerClientEvent('police:client:SyncSpikes', -1, table)
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= 'ox_inventory' then return end

    local jobs = {}
    for k, v in pairs(QBCore.Shared.Jobs) do
        if v.type == 'leo' then
            jobs[k] = 0
        end
    end

    for i = 1, #Config.Locations.trash do
        exports.ox_inventory:RegisterStash(('policetrash_%s'):format(i), 'Police Trash', 300, 4000000, nil, jobs, Config.Locations.trash[i])
    end
    exports.ox_inventory:RegisterStash('policelocker', 'Police Locker', 30, 100000, true)
end)

-- Threads
CreateThread(function()
    for i = 1, #Config.Locations.trash do
        exports.ox_inventory:ClearInventory(('policetrash_%s'):format(i))
    end
    while true do
        Wait(1000 * 60 * 10)
        local curCops = QBCore.Functions.GetDutyCountType('leo')
        TriggerClientEvent("police:SetCopCount", -1, curCops)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        UpdateBlips()
    end
end)

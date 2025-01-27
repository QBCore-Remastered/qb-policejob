local config = require 'config.server'
local sharedConfig = require 'config.shared'

---if player is not leo or not on duty, notifies them
---@param player Player
---@param minGrade? integer
---@return boolean?
local function checkLeoAndOnDuty(player, minGrade)
    if IsLeoAndOnDuty(player, minGrade) then return true end
    exports.qbx_core:Notify(player.PlayerData.source, locale('error.on_duty_police_only'), 'error')
end

local function dnaHash(s)
    return string.gsub(s, '.', function(c)
        return string.format('%02x', string.byte(c))
    end)
end

lib.addCommand('spikestrip', {help = locale('commands.place_spike')}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('police:client:SpawnSpikeStrip', source)
end)

lib.addCommand('grantlicense', {
    help = locale('commands.license_grant'),
    params = {
        {
            name = 'id',
            type = 'playerId',
            help = locale('info.player_id')
        },
        {
            name = 'license',
            type = 'string',
            help = locale('info.license_type')
        }
    },
 }, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)

    if not checkLeoAndOnDuty(player, config.licenseRank) then
        return exports.qbx_core:Notify(source, locale('error.error_rank_license'), 'error')
    end

    if not config.validLicenses[args.license] then
        return exports.qbx_core:Notify(source, locale('info.license_type'), 'error')
    end

    local searchedPlayer = exports.qbx_core:GetPlayer(args.id)
    if not searchedPlayer then return end
    local licenseTable = searchedPlayer.PlayerData.metadata.licences
    if licenseTable[args.license] then
        return exports.qbx_core:Notify(source, locale('error.license_already'), 'error')
    end
    licenseTable[args.license] = true
    searchedPlayer.Functions.SetMetaData('licences', licenseTable)
    exports.qbx_core:Notify(searchedPlayer.PlayerData.source, locale('success.granted_license'), 'success')
    exports.qbx_core:Notify(source, locale('success.grant_license'), 'success')
end)

lib.addCommand('revokelicense',{
    help = locale('commands.license_revoke'),
    params = {
        {
            name = 'id',
            type = 'playerId',
            help = locale('info.player_id')
        },
        {
            name = 'license',
            type = 'string',
            help = locale('info.license_type')
        }
    },
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player, config.licenseRank) then
        return exports.qbx_core:Notify(source, locale('error.rank_revoke'), 'error')
    end
    if not config.validLicenses[args.license] then
        return exports.qbx_core:Notify(source, locale('error.error_license'), 'error')
    end
    local searchedPlayer = exports.qbx_core:GetPlayer(args.id)
    if not searchedPlayer then return end
    local licenseTable = searchedPlayer.PlayerData.metadata.licences
    if not licenseTable[args.license] then
        return exports.qbx_core:Notify(source, locale('error.error_license'), 'error')
    end
    licenseTable[args.license] = false
    searchedPlayer.Functions.SetMetaData('licences', licenseTable)
    exports.qbx_core:Notify(searchedPlayer.PlayerData.source, locale('error.revoked_license'), 'error')
    exports.qbx_core:Notify(source, locale('success.revoke_license'), 'success')
end)

lib.addCommand('pobject', {
    help = locale('commands.place_object'),
    params = {
        {
            name = 'type',
            type = 'string',
            help = locale('info.poobject_object')
        }
    },
 }, function(source, args)
    local type = args.type:lower()
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end

    if type == 'delete' then
        TriggerClientEvent('police:client:deleteObject', source)
    elseif sharedConfig.objects[type] then
        TriggerClientEvent('police:client:spawnPObj', source, type)
    end
end)

lib.addCommand('cuff', {help = locale('commands.cuff_player')}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('police:client:CuffPlayer', source)
end)

lib.addCommand('escort', {help = locale('commands.escort')}, function(source)
    TriggerClientEvent('police:client:EscortPlayer', source)
end)

lib.addCommand('callsign', {
    help = locale('commands.callsign'),
    params = {{
        name = 'callsign',
        type = 'number',
        help = locale('info.callsign_name')
    }},
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    player.Functions.SetMetaData('callsign', args.callsign)
end)

lib.addCommand('clearcasings', {help = locale('commands.clear_casign')}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('evidence:client:ClearCasingsInArea', source)
end)

if not IsUsingXTPrison then
    lib.addCommand('jail', {help = locale('commands.jail_player')}, function(source)
        local player = exports.qbx_core:GetPlayer(source)
        if not checkLeoAndOnDuty(player) then return end
        TriggerClientEvent('police:client:JailPlayer', source)
    end)

    lib.addCommand('unjail', {
        help = locale('commands.unjail_player'),
        params = {{
            name = 'id',
            type = 'playerId',
            help = locale('info.player_id')
        }}
    }, function(source, args)
        local player = exports.qbx_core:GetPlayer(source)
        if not checkLeoAndOnDuty(player) then return end
        if GetResourceState('qbx_prison') == 'started' then
            exports.qbx_prison:ReleasePlayer(args.id)
        else
            TriggerClientEvent('prison:client:UnjailPerson', args.id)
        end
    end)
end

lib.addCommand('clearblood', {help = locale('commands.clearblood')}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('evidence:client:ClearBlooddropsInArea', source)
end)

lib.addCommand('seizecash', {help = locale('commands.seizecash')}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('police:client:SeizeCash', source)
end)

lib.addCommand('sc', {help = locale('commands.softcuff')}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('police:client:CuffPlayerSoft', source)
end)

lib.addCommand('cam', {
    help = locale('commands.camera'),
    params = {{
        name = 'camid',
        type = 'number',
        help = locale('info.camera_id_help')
    }},
 }, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('police:client:ActiveCamera', source, args.camid)
end)

lib.addCommand('flagplate', {
    help = locale('commands.flagplate'),
    params = {
        {
            name = 'plate',
            type = 'string',
            help = locale('info.plate_number')
        },
        {
            name = 'reason',
            type = 'string',
            help = locale('info.flag_reason'),
            optional = true
        }
    },
 }, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    local reason = {}
    for i = 2, #args, 1 do
        reason[#reason+1] = args[i]
    end
    Plates[args[1]:upper()] = {
        isflagged = true,
        reason = table.concat(reason, ' ')
    }
    exports.qbx_core:Notify(source, locale('info.vehicle_flagged', args[1]:upper(), table.concat(reason, ' ')), 'inform')
end)

lib.addCommand('unflagplate', {
    help = locale('commands.unflagplate'),
    params = {{
        name = 'plate',
        type = 'string',
        help = locale('info.plate_number')
    }},
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    if not Plates or not Plates[args.plate:upper()] then
        return exports.qbx_core:Notify(source, locale('error.vehicle_not_flag'), 'error')
    end

    if not Plates[args.plate:upper()].isflagged then
        return exports.qbx_core:Notify(source, locale('error.vehicle_not_flag'), 'error')
    end

    Plates[args.plate:upper()].isflagged = false
    exports.qbx_core:Notify(source, locale('info.unflag_vehicle', args.plate:upper()), 'inform')
end)

lib.addCommand('plateinfo', {
    help = locale('commands.plateinfo'),
    params = {{
        name = 'plate',
        type = 'string',
        help = locale('info.plate_number')
    }},
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    if not Plates or Plates[args.plate:upper()] then
        return exports.qbx_core:Notify(source, locale('error.vehicle_not_flag'), 'error')
    end
    if Plates[args.plate:upper()].isflagged then
        exports.qbx_core:Notify(source, locale('success.vehicle_flagged', args.plate:upper(), Plates[args.plate:upper()].reason), 'success')
    else
        exports.qbx_core:Notify(source, locale('error.vehicle_not_flag'), 'error')
    end
end)

lib.addCommand('depot', {
    help = locale('commands.depot'),
    params = {{
        name = 'price',
        type = 'number',
        help = locale('info.impound_price')
    }},
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('police:client:ImpoundVehicle', source, false, args.price)
end)

lib.addCommand('impound', {help = locale('commands.impound')}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('police:client:ImpoundVehicle', source, true)
end)

lib.addCommand('paytow', {
    help = locale('commands.paytow'),
    params = {{
        name = 'id',
        type = 'playerId',
        help = locale('info.player_id')
    }},
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    local otherPlayer = exports.qbx_core:GetPlayer(args.id)
    if not otherPlayer then return end
    if not config.towJobs[otherPlayer.PlayerData.job.name] then
        return exports.qbx_core:Notify(source, locale('error.not_towdriver'), 'error')
    end

    otherPlayer.Functions.AddMoney('bank', config.towPay, 'police-tow-paid')
    exports.qbx_core:Notify(otherPlayer.PlayerData.source, locale('success.tow_paid'), 'success')
    exports.qbx_core:Notify(source, locale('info.tow_driver_paid'), 'inform')
end)

lib.addCommand('paylawyer', {
    help = locale('commands.paylawyer'),
    params = {{
        name = 'id',
        type = 'playerId',
        help = locale('info.player_id')
    }},
 }, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if player.PlayerData.job.type ~= 'leo' and player.PlayerData.job.name ~= 'judge' then
        return exports.qbx_core:Notify(source, locale('error.on_duty_police_only'), 'error')
    end

    local otherPlayer = exports.qbx_core:GetPlayer(args.id)
    if not otherPlayer then return end
    if not config.lawyerJobs[otherPlayer.PlayerData.job.name] then
        return exports.qbx_core:Notify(source, locale('error.not_lawyer'), 'error')
    end

    otherPlayer.Functions.AddMoney('bank', config.lawyerPay, 'police-lawyer-paid')
    exports.qbx_core:Notify(otherPlayer.PlayerData.source, locale('success.tow_paid'), 'success')
    exports.qbx_core:Notify(source, locale('info.paid_lawyer'), 'inform')
end)

lib.addCommand('anklet', {help = locale('commands.anklet')}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    TriggerClientEvent('police:client:CheckDistance', source)
end)

lib.addCommand('ankletlocation', {
    help = locale('commands.ankletlocation'),
    params = {{
        name = 'cid',
        type = 'string',
        help = locale('info.citizen_id')
    }},
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if not checkLeoAndOnDuty(player) then return end
    local target = exports.qbx_core:GetPlayerByCitizenId(args.cid)
    if not target then return end
    if not target.PlayerData.metadata.tracker then
        return exports.qbx_core:Notify(source, locale('error.no_anklet'), 'error')
    end
    TriggerClientEvent('police:client:SendTrackerLocation', target.PlayerData.source, source)
end)

lib.addCommand('takedna', {
    help = locale('commands.takedna'),
    params = {{
        name = 'id',
        type = 'playerId',
        help = locale('info.player_id')
    }},
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    local otherPlayer = exports.qbx_core:GetPlayer(args.id)

    if not checkLeoAndOnDuty(player) then return end
    if not player.Functions.RemoveItem('empty_evidence_bag', 1) then
        return exports.qbx_core:Notify(source, locale('error.have_evidence_bag'), 'error')
    end

    local info = {
        label = locale('info.dna_sample'),
        type = 'dna',
        dnalabel = dnaHash(otherPlayer.PlayerData.citizenid),
        description = dnaHash(otherPlayer.PlayerData.citizenid)
    }
    if not player.Functions.AddItem('filled_evidence_bag', 1, false, info) then return end
end)

lib.addCommand('911p', {
    help = locale('commands.police_report'),
    params = {{
        name = 'message',
        type = 'longString',
        help = locale('commands.message_sent')
    }},
}, function(source, args)
    local message = args.message or locale('commands.civilian_call')
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local players = exports.qbx_core:GetQBPlayers()
    for i = 1, #players do
        if IsLeoAndOnDuty(players[i]) then
            local alertData = {title = locale('commands.emergency_call'), coords = {x = coords.x, y = coords.y, z = coords.z}, description = message}
            TriggerClientEvent('qb-phone:client:addPoliceAlert', players[i].PlayerData.source, alertData)
            TriggerClientEvent('police:client:policeAlert', players[i].PlayerData.source, coords, message)
        end
    end
end)

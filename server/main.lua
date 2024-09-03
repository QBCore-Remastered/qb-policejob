local sharedConfig = require 'config.shared'

---@param job? string
---@param department? PersonalStashData
local function registerPersonalStash(job, department)
    if not job or not department then return end

    for i = 1, #department do
        local stash = department[i]
        local stashId = ('%s-PersonalStash'):format(job)

        exports.ox_inventory:RegisterStash(stashId, stash.label, stash.slots or 100, stash.weight or 100000, true, stash.groups, stash.coords)
    end
end

---@param department? ArmoryData
local function registerArmory(department)
    if not department then return end

    for i = 1, #department do
        local armory = department[i]

        exports.ox_inventory:RegisterShop(armory.shopType, armory)
    end
end

---@param source number
---@param model string
---@param spawn vector4
lib.callback.register('qbx_police:server:spawnVehicle', function(source, model, spawn)
    local ped = GetPlayerPed(source)
    local plate = ('LSPD%s'):format(math.random(1000, 9999))
    local netId, _ = qbx.spawnVehicle({
        spawnSource = spawn,
        model = model,
        warp = ped,
        props = {
            plate = plate
        }
    })

    exports.qbx_vehiclekeys:GiveKeys(source, plate)

    return netId
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= cache.resource then return end

    for job, data in pairs(sharedConfig.departments) do
        registerArmory(data.armory)
        registerPersonalStash(job, data.personalStash)
    end
end)
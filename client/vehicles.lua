local VEHICLES = exports.qbx_core:GetVehiclesByName()

---@param vehicle integer
local function store(vehicle)
    DeleteVehicle(vehicle)
end

---@param vehicle string
---@param spawn vector4
local function takeOut(vehicle, spawn)
    if cache.vehicle then
        exports.qbx_core:Notify('You\'re already in a vehicle...', 'error')
        return
    end

    local netId = lib.callback.await('s_police:server:spawnVehicle', false, vehicle, spawn)

    lib.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(netId) then
            return NetToVeh(netId)
        end
    end, 'Something went wrong while attempting to spawn the police vehicle...')
end

---@param garage table
local function openGarage(garage)
    local options = {}

    for _, vehicle in pairs(garage.catalogue) do
        if vehicle.grade <= QBX.PlayerData.job.grade.level then
            local title = ('%s %s'):format(VEHICLES[vehicle.name].brand, VEHICLES[vehicle.name].name)

            options[#options + 1] = {
                title = title,
                arrow = true,
                onSelect = function()
                    takeOut(vehicle.name, garage.spawn)
                end,
            }
        end
    end

    lib.registerContext({
        id = 'garageMenu',
        title = 'PD Garage',
        options = options
    })

    lib.showContext('garageMenu')
end

---@param helipad table
local function openHelipad(helipad)
    local options = {}

    for _, heli in pairs(helipad.catalogue) do
        if heli.grade <= QBX.PlayerData.job.grade.level then
            local title = ('%s %s'):format(VEHICLES[heli.name].brand, VEHICLES[heli.name].name)

            options[#options + 1] = {
                title = title,
                arrow = true,
                onSelect = function()
                    takeOut(heli.name, helipad.spawn)
                end,
            }
        end
    end

    if #options == 0 then
        exports.qbx_core:Notify('You\'re not the appropriate grade to pilot a helicopter yet...', 'error')
        return
    end

    lib.registerContext({
        id = 'helipadMenu',
        title = 'PD Helipad',
        options = options
    })

    lib.showContext('helipadMenu')
end

return {
    openGarage = openGarage,
    openHelipad = openHelipad,
    store = store
}
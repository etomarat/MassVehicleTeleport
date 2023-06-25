if isClient() then return end

local CarTeleport = ETOMARAT.CarTeleport
local MOD_NAME = CarTeleport.MOD_NAME

local Commands = {}

---@type table<string, BaseVehicle[]>
local CacheMap = {}  -- NOTE: Сюда кешируем список транспорта на сервере

---@param player IsoPlayer
---@param vehicleIdList integer[]
Commands.saveCars = function(player, vehicleIdList)
    local username = player:getUsername()
    local vehicleList = {}
    for k,vehicleId in pairs(vehicleIdList) do
        table.insert(vehicleList, getVehicleById(vehicleId))
    end
    CacheMap[username] = vehicleList -- Сохраняем тачки в кеш
end

---@param player IsoPlayer
---@param args moveCarArgs
Commands.moveCars = function(player, args)
    local xDif, yDif = unpack(args)
    local username = player:getUsername()
    local vehicleList = CacheMap[username]
    for k,vehicle in pairs(vehicleList) do
        CarTeleport.moveCar(player, vehicle, xDif, yDif)
    end
    sendServerCommand(MOD_NAME, 'moveCar', args)
end

---@param vehicle BaseVehicle
local getVehicleData = function(vehicle)
    local result = {
        scriptName = vehicle:getScript():getName(),
        dir = vehicle:getDir(),
        skinIdx = vehicle:getSkinIndex(),
        coords = { vehicle:getX(), vehicle:getY(), vehicle:getZ() },
        angles = { vehicle:getAngleX(), vehicle:getAngleY(), vehicle:getAngleZ() },
        rust = vehicle:getRust(),
        blood = { -- NOTE: clockwise from the front
            vehicle:getBloodIntensity("Front"),
            vehicle:getBloodIntensity("Right"),
            vehicle:getBloodIntensity("Rear"),
            vehicle:getBloodIntensity("Left")
        },
        HSV = {
            vehicle:getColorHue(),
            vehicle:getColorSaturation(),
            vehicle:getColorValue(),
        },
        isKeysInIgnition = vehicle:isKeysInIgnition(),
        isHotwired = vehicle:isHotwired(),
        engineFeature = {
            vehicle:getEngineQuality(),
            vehicle:getEngineLoudness(),
            vehicle:getEnginePower(),
        }
    }
    local partData = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local partItem = part:getInventoryItem()
        local partId = part:getId()
        local partCondition = part:getCondition()
        if partItem then
            partData[partId] = {
                condition = partItem:getCondition(),
                item = partItem:getFullType()
            }
            if part:isContainer() and not part:getItemContainer() then
                partData[partId]["content"] = part:getContainerContentAmount()
            end
            if partItem:IsDrainable() then
                partData[partId]["delta"] = partItem:getUsedDelta()
            end
        else
            partData[partId] = {
                condition = partCondition
            }
        end
    end
    result['partData'] = partData
    return result
end

---@param vehicle BaseVehicle
---@param data table
---@param sq IsoGridSquare
local setVehicleData = function(vehicle, data, sq)
    vehicle:setAngles(unpack(data.angles))

    vehicle:setColorHSV(unpack(data.HSV))
    vehicle:transmitColorHSV()

    vehicle:setEngineFeature(unpack(data.engineFeature))
    vehicle:transmitEngine()

    vehicle:setRust(data.rust)
    vehicle:transmitRust()

    local bFront, bRight, bRear, bLeft = unpack(data.blood)
    vehicle:setBloodIntensity("Front", bFront)
    vehicle:setBloodIntensity("Right", bRight)
    vehicle:setBloodIntensity("Rear", bRear)
    vehicle:setBloodIntensity("Left", bLeft)
    vehicle:transmitBlood()

    local newCarKey = nil
    local needToPlaceKey = SandboxVars.CarTeleport.ForceKeySpawn or false
    if data.isKeysInIgnition and not vehicle:isKeysInIgnition() then
        needToPlaceKey = true
        newCarKey = vehicle:createVehicleKey()
    end

    vehicle:setHotwired(data.isHotwired)


    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local partItem = part:getInventoryItem()
        local partId = part:getId()

        local partData = data.partData[partId]

        if partData then
            if partData["item"] then
                if not (partItem and partItem:getFullType() == partData["item"]) then
                    if partItem then
                        part:setInventoryItem(nil)
                        vehicle:transmitPartItem(part)
                    end
    
                    local item = InventoryItemFactory.CreateItem(partData["item"]) 
                    part:setInventoryItem(item) 
                     
                    local install_table = part:getTable("install")
                    if install_table and install_table.complete then
                        VehicleUtils.callLua(install_table.complete, vehicle, part)
                    end                            
                    vehicle:transmitPartItem(part)
                end 
            end

            if partData["condition"] <= 0 then
                part:setInventoryItem(nil)
            else
                part:setCondition(partData["condition"])
                vehicle:transmitPartCondition(part)
            end

            local door = part:getDoor()
            if door then
                door:setLocked(false)
                vehicle:transmitPartDoor(part)
            end

            local container = part:getItemContainer()
            if container then
                if container:getItems():size() ~= 0 then
                    container:removeAllItems()
                end
                if partId == 'GloveBox' and needToPlaceKey then
                    container:addItem(newCarKey)
                    needToPlaceKey = false
                end
            end

            local content = partData["content"]
            if content then
                part:setContainerContentAmount(content)
                local wheelIndex = part:getWheelIndex()
                if wheelIndex ~= -1 then
                    vehicle:setTireInflation(wheelIndex, part:getContainerContentAmount() / part:getContainerCapacity())
                end
            end

            local delta = partData["delta"]
            if delta then
                partItem:setUsedDelta(delta)
                vehicle:transmitPartUsedDelta(part)
            end

            vehicle:transmitPartModData(part)
        else
            part:setInventoryItem(nil)
            local uninstall_table = part:getTable("uninstall")
            if uninstall_table and uninstall_table.complete then
                VehicleUtils.callLua(uninstall_table.complete, vehicle, part)
            end
            vehicle:transmitPartItem(part)
        end
    end

    if needToPlaceKey then
        sq:AddWorldInventoryItem(newCarKey, 0, 0, 0)
    end
end

Commands.spawn = function(player, args)
    local xDif, yDif = unpack(args)
    local username = player:getUsername()
    local vehicleList = CacheMap[username]
    local cell = getCell()

    for k,vehicle in pairs(vehicleList) do
        local vehicleData = getVehicleData(vehicle)
        local x, y, z = unpack(vehicleData.coords)

        local sq = cell:getGridSquare(x-xDif, y-yDif, z)
        local newVehicle = addVehicleDebug(vehicleData.scriptName, vehicleData.dir, vehicleData.skinIdx, sq)
        
        setVehicleData(newVehicle, vehicleData, sq)
    end
end

local OnClientCommand = function(module, command, player, args)
	if module == MOD_NAME and Commands[command] then
		Commands[command](player, args)
	end
end

Events.OnClientCommand.Add(OnClientCommand)
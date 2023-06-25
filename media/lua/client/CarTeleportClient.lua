local CarTeleport = ETOMARAT.CarTeleport
local MOD_NAME = CarTeleport.MOD_NAME

local Commands = {}

---@type table<string, BaseVehicle[]>
local CacheMap = {} -- NOTE: Сюда кешируем список транспорта на клиенте

---@param startPos position
---@param endPos position
---@param zPos number
---@return BaseVehicle[]
local getCarsListByCoord = function(startPos, endPos, zPos)
    local cell = getCell()
    local x1 = math.min(startPos.x, endPos.x)
    local x2 = math.max(startPos.x, endPos.x)
    local y1 = math.min(startPos.y, endPos.y)
    local y2 = math.max(startPos.y, endPos.y)
    local uniqueList = {}
    for x = x1, x2 do
        for y = y1, y2 do
            local sq = cell:getGridSquare(x, y, zPos)
            local vehicleObj = sq:getVehicleContainer()
            if vehicleObj then
                uniqueList[vehicleObj:getId()] = vehicleObj
            end
        end
    end
    local resultList = {}
    for k,v in pairs(uniqueList) do
        table.insert(resultList, v)
    end

    return resultList
end

---@param vehicleList BaseVehicle[]
local removeCars = function(vehicleList)
    for k,v in pairs(vehicleList) do
        if isAdmin() then
            sendClientCommand('vehicle', 'remove', {vehicle = v:getId()})
        end
    end
end

---@param vehicleList BaseVehicle[]
local startMove = function(vehicleList)
    local player = getPlayer()
    local username = player:getUsername()
    CacheMap[username] = vehicleList
    local vehicleIdList = {}
    for k,vehicle in pairs(vehicleList) do
        table.insert(vehicleIdList, vehicle:getId())
    end

    sendClientCommand(MOD_NAME, 'saveCars', vehicleIdList)
end

---@param xDif number
---@param yDif number
local spawnCars = function(xDif, yDif)
    local args = {
        xDif,
        yDif
    }
    if isAdmin() then
        sendClientCommand(MOD_NAME, 'spawn', args)
    end
end

---@param xDif number
---@param yDif number
local moveCars = function(xDif, yDif)
    local args = {
        xDif,
        yDif
    }

    if isAdmin() then
        sendClientCommand(MOD_NAME, 'moveCars', args)
    end
   
    -- NOTE: Перебираем переменные java инстанса и выводим их значения. Оставил здесь чтоб не забыть как это делать
    -- local field_count = getNumClassFields(vehicle)
    -- for i=0, field_count-1 do
    --     local field = getClassField(vehicle, i)
    --     print(tostring(field) .. ' -- ' .. i .. ' val: ', getClassFieldVal(vehicle, field))
    -- end
end

---@param args moveCarArgs
Commands.moveCar = function(args)
    local xDif, yDif = unpack(args)
    local player = getPlayer()
    local username = player:getUsername()
    local vehicleList = CacheMap[username]
    for k,vehicle in pairs(vehicleList) do
        local id = vehicle:getId()
        local keyId = vehicle:getKeyId()
        local thisVehicle = getVehicleById(id)
        if thisVehicle and thisVehicle:getKeyId() == keyId then
            CarTeleport.moveCar(player, vehicle, xDif, yDif)
        end
    end
end

---@param module string
---@param command string
---@param args any
local receiveServerCommand = function(module, command, args)
    if module ~= MOD_NAME then return; end
    if Commands[command] then
        Commands[command](args);
    end
end

Events.OnServerCommand.Add(receiveServerCommand);

local export = {
    getCarsListByCoord = getCarsListByCoord,
    removeCars = removeCars,
    moveCars = moveCars,
    startMove = startMove,
    spawnCars = spawnCars
}

return export

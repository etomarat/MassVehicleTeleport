ETOMARAT = ETOMARAT or {}
ETOMARAT.CarTeleport = ETOMARAT.CarTeleport or {}
ETOMARAT.CarTeleport.MOD_NAME = 'CarTeleport'

---@param player IsoPlayer
---@param vehicle BaseVehicle
---@param xDif number
---@param yDif number
local moveCar = function(player, vehicle, xDif, yDif)
    if not player:isAccessLevel("admin") then
        return
    end
    if not vehicle then
        return
    end

    -- HACK: достаём переменную типа Transfrom из java-инстанса автомобиля
    local field_count = getNumClassFields(vehicle)
    local transform_field = nil
    local jniTransform_fieldName = 'public final zombie.core.physics.Transform zombie.vehicles.BaseVehicle.jniTransform' -- NOTE: название джава переменной в которой хранится трансформ
    -- local tempTransform_fieldName = 'private final zombie.core.physics.Transform zombie.vehicles.BaseVehicle.tempTransform' -- NOTE: вроде тоже подходящее поле
    for i=0, field_count-1 do -- NOTE: Ищем переменную в инстансе
        local field = getClassField(vehicle, i)
        if tostring(field) == jniTransform_fieldName then
            transform_field = field
        end
    end

    if transform_field then -- NOTE: на основе найденого поля, проводим трансформации для телепортации
        local v_transform = getClassFieldVal(vehicle, transform_field)
        local w_transform = vehicle:getWorldTransform(v_transform)
        local origin_field = getClassField(w_transform, 1)
        local origin = getClassFieldVal(w_transform, origin_field)
        origin:set(origin:x() - xDif, origin:y(), origin:z() - yDif)
        vehicle:setWorldTransform(w_transform)
        if isClient() then
            pcall(vehicle.update, vehicle) -- NOTE: pcall нужен т.к. непонятно какие методы есть на клиенте а какие на сервере. Он позволяет вызвать метод если он существует
            pcall(vehicle.updateControls, vehicle)
            pcall(vehicle.updateBulletStats, vehicle)
            pcall(vehicle.updatePhysics, vehicle)
            pcall(vehicle.updatePhysicsNetwork, vehicle)
        end
    end
end

ETOMARAT.CarTeleport.moveCar = moveCar
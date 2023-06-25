local main = require "CarTeleportClient"

local CarTeleport_UI = {}
-- g_CarTeleport_UI = CarTeleport_UI -- TODO: Удалить. Использовалось для дебага

local UI_TITLE = 'CarTeleport_carListTitle'
local UI_COUNTER = 'CarTeleport_carListCounter'
local UI_LIST = 'CarTeleport_carList'
local UI_SELECT = 'CarTeleport_selectAreaBtn'
local UI_RESET = 'CarTeleport_resetBtn'
local UI_CANCEL = 'CarTeleport_cancelBtn'
local UI_COPY = 'CarTeleport_copyBtn'
local UI_PASTE = 'CarTeleport_pasteBtn'
local UI_DEL = 'CarTeleport_deletelBtn'
local UI_DESCRIPTION = 'CarTeleport_descriptionRichText'
local UI_TYPE_LABEL = 'CarTeleport_typeText'
local UI_TYPE = 'CarTeleport_typeComboBox'

local UI_TYPE_EXPERIMENTAL = 'experimental'
local UI_TYPE_STABLE = 'stable'
local UI_TYPE_DICT = {}
UI_TYPE_DICT[getText('IGUI_stable')] = UI_TYPE_STABLE
UI_TYPE_DICT[getText('IGUI_experimental')] = UI_TYPE_EXPERIMENTAL
local UI_DESCRIPTION_DICT = {}
-- UI_DESCRIPTION_DICT[UI_TYPE_STABLE] = 'Stable type info:<BR> The cars will be removed and spawned in a new location. Items in the containers of the cars will be deleted.'
UI_DESCRIPTION_DICT[UI_TYPE_STABLE] = getText('IGUI_Stable_info')
UI_DESCRIPTION_DICT[UI_TYPE_EXPERIMENTAL] = getText('IGUI_Experimental_info')
-- UI_DESCRIPTION_DICT[UI_TYPE_EXPERIMENTAL] = 'Experimental type info:<BR> Teleport distance is limited. Desynchronization may occur <BR>'
-- local UI_DESCRIPTION_INSIDE = '<GREEN>Teleport is allowed'
local UI_DESCRIPTION_INSIDE = getText('IGUI_Teleport_allowed')
-- local UI_DESCRIPTION_OUTSIDE = '<RED>Teleport not allowed. You have left the experimental teleport zone. Get back closer to the cars'
local UI_DESCRIPTION_OUTSIDE = getText('IGUI_Teleport_disallowed')
local UI_COPY_DICT = {}
UI_COPY_DICT[UI_TYPE_STABLE] = getText('IGUI_Teleport_cut_btn')
UI_COPY_DICT[UI_TYPE_EXPERIMENTAL] = getText('IGUI_Teleport_target_btn')
local UI_PASTE_DICT = {}
UI_PASTE_DICT[UI_TYPE_STABLE] = getText('IGUI_Teleport_paste_btn')
UI_PASTE_DICT[UI_TYPE_EXPERIMENTAL] = getText('IGUI_Teleport_teleport_btn')

function CarTeleport_UI.selectArea_btnHandler(button, args)
    local self = args['self'] or {}
    self.selectEnd = false
    self.startPos = nil
    self.endPos = nil
    self.zPos = self.player:getZ()
    self.selectStart = true
end

---@param button any
---@param self CarTeleport_UI
function CarTeleport_UI.cancel_btnHandler(button, self)
    self:close()
end

---@param button any
---@param self CarTeleport_UI
function CarTeleport_UI.reset_btnHandler(button, self)
    self:reset()
end

---@param button any
---@param self CarTeleport_UI
function CarTeleport_UI.copy_btnHandler(button, self)
    self:startMove()
end

---@param button any
---@param self CarTeleport_UI
function CarTeleport_UI.paste_btnHandler(button, self)
    self:endMove()
end

function CarTeleport_UI:experimentalTypeSetter()
    local lastLine = ''
    if self.isExperimentalAllowed ~= nil then
        lastLine = UI_DESCRIPTION_OUTSIDE
        if self.isExperimentalAllowed then
            lastLine = UI_DESCRIPTION_INSIDE
        end
    end

    local text = UI_DESCRIPTION_DICT[UI_TYPE_EXPERIMENTAL] .. lastLine
    self.UI[UI_DESCRIPTION]:setText(text)
end

function CarTeleport_UI:setTypeText()
    if self.type_value == UI_TYPE_EXPERIMENTAL then
        self:experimentalTypeSetter()
    end
    if self.type_value == UI_TYPE_STABLE then
        self.UI[UI_DESCRIPTION]:setText(UI_DESCRIPTION_DICT[UI_TYPE_STABLE])
    end
end

function CarTeleport_UI:typeChange_handler()
    self.type_value = UI_TYPE_DICT[self.UI[UI_TYPE]:getValue()]
    self:setTypeText()
    self.UI[UI_COPY]:setText(UI_COPY_DICT[self.type_value]) 
    self.UI[UI_PASTE]:setText(UI_PASTE_DICT[self.type_value]) 
end

function CarTeleport_UI:delete_confirmHandler(button)
    if button.internal == 'YES' then
        self:delete()
    end
end

---@param button any
---@param self CarTeleport_UI
function CarTeleport_UI.delete_btnHandler(button, self)
    local vehicleList = {table.unpack(self.vehicleList)}
    local modal = ISModalDialog:new(
        0, 0, 250, 150, 
        getText('IGUI_Teleport_delete_confirm_pre').. #vehicleList .. getText('IGUI_Teleport_delete_confirm_post'), 
        true, self, CarTeleport_UI.delete_confirmHandler, self.player:getPlayerNum()
    )
    modal:initialise()
    modal:addToUIManager()
end

---@return boolean
function CarTeleport_UI:isVisible()
    return self.UI.isUIVisible
end

function CarTeleport_UI:close()
    self:reset()
    return self.UI:close()
end

function CarTeleport_UI:render() -- NOTE: украдено из steamapps\common\ProjectZomboid\media\lua\client\DebugUIs\ISRemoveItemTool.lua
    local self = self.CarTeleport_UI_instance -- HACK: достаём наш инстанс обратно из UI инстанса
    self.base_render(self.UI)
    
    if self.selectStart or self.isMove then 
        local xx, yy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), self.zPos)
        self.highlightArea(xx, xx, yy, yy, self.zPos, 'yellow')
    end
        
    if not self.selectStart and self.selectEnd then
        local xx, yy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), self.zPos)
        xx = math.floor(xx)
        yy = math.floor(yy)
        self.preHighlightArea(xx, self.startPos.x, yy, self.startPos.y, self.zPos, 'yellow')
    elseif self.startPos ~= nil and self.endPos ~= nil then
        self.preHighlightArea(self.startPos.x, self.endPos.x, self.startPos.y, self.endPos.y, self.zPos, 'red')
    end

    if self.target then
        self.highlightArea(self.target.x1, self.target.x2, self.target.y1, self.target.y2, self.zPos, 'green')
    end

end

function CarTeleport_UI:onMouseDownOutside(x, y)
    local isOutside = x < 0 or y < 0 or x > self:getWidth() or y > self:getHeight()
    local self = self.CarTeleport_UI_instance -- HACK: достаём наш инстанс обратно из UI инстанса
    self.base_onMouseDownOutside(self.UI, x, y)

    local xx, yy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), self.zPos)
    if self.selectStart then
        self.startPos = { x = math.floor(xx), y = math.floor(yy) }
        self.selectStart = false
        self.selectEnd = true
    elseif self.selectEnd then
        self.endPos = { x = math.floor(xx), y = math.floor(yy) }
        self.selectEnd = false
        self:renderCarsList()
    end
    if self.isMove and isOutside then
        self.xDif = self.origin.x2 - math.floor(xx)
        self.yDif = self.origin.y2 - math.floor(yy)
        self.target = {
            x1 = self.origin.x1 - self.xDif,
            x2 = self.origin.x2 - self.xDif,
            y1 = self.origin.y1 - self.yDif,
            y2 = self.origin.y2 - self.yDif,
        }
        self.UI[UI_PASTE]:setEnable(true)
    end
end

function CarTeleport_UI:checkDistance()
    ---@type IsoPlayer
    local player = self.player
    local isDisallowed = false
    for k,v in pairs(self.vehicleList) do
        local vehicle = getVehicleById(v:getId())
        if not vehicle and self.type_value == UI_TYPE_EXPERIMENTAL then
            player:Say(getText('IGUI_Teleport_player_left_tp_zone'))
            isDisallowed = isDisallowed or true
        end
    end
    self.isExperimentalAllowed = not isDisallowed
    self:setTypeText()
end

function CarTeleport_UI:renderCarsList()
    self.origin = {
        x1 = math.min(self.startPos.x, self.endPos.x),
        x2 = math.max(self.startPos.x, self.endPos.x),
        y1 = math.min(self.startPos.y, self.endPos.y),
        y2 = math.max(self.startPos.y, self.endPos.y),
    }
    local vehicleList = main.getCarsListByCoord(self.startPos, self.endPos, self.zPos)
    local renderedList = {}
    for k,v in pairs(vehicleList) do
        local carName = getText("IGUI_VehicleName" .. v:getScript():getName())
        table.insert(renderedList, carName .. ' | sqlId: ' .. v:getSqlId() .. ', vehicleId: ' .. v:getId() .. ', keyId: ' .. v:getKeyId())
    end
    self.vehicleList = vehicleList
    self.UI[UI_LIST]:setitems(renderedList)
    self.UI[UI_COUNTER]:setText(getText('IGUI_Teleport_car_count') .. #renderedList)
    self.UI[UI_SELECT]:setEnable(false)
    self.UI[UI_RESET]:setEnable(true)
    self.UI[UI_DEL]:setEnable(true)
    self.UI[UI_COPY]:setEnable(true)
    self.UI[UI_TYPE].disabled = true
    self.UI[UI_LIST].selected = -1

    local _self = self
    ---@param square IsoGridSquare
    self.onTick_handler = function(square)
        _self:checkDistance()
    end
    Events.OnTick.Add(self.onTick_handler)

end

function CarTeleport_UI:startMove()
    self.UI[UI_COPY]:setEnable(false)
    self.UI[UI_DEL]:setEnable(false)
    self.isMove = true
    main.startMove(self.vehicleList)

    if self.type_value == UI_TYPE_STABLE then
        main.removeCars(self.vehicleList)
    end
end

function CarTeleport_UI:endMove()
    self.isMove = false
    if self.type_value == UI_TYPE_STABLE then
        main.spawnCars(self.xDif, self.yDif)
    else
        main.moveCars(self.xDif, self.yDif)
    end
    self.UI[UI_PASTE]:setEnable(false)
    self.player:Say(getText('IGUI_Teleport_done'))
end

function CarTeleport_UI:delete()
    main.removeCars(self.vehicleList)
    self:reset()
end

function CarTeleport_UI:reset()
    self.isExperimentalAllowed = nil
    self.vehicleList = {}
    self.selectStart = false
    self.selectEnd = false
    self.isMove = false
    self.startPos = nil
    self.endPos = nil
    self.origin = nil
    self.target = nil
    self.zPos = 0
    self.xDif = 0
    self.yDif = 0
    self.UI[UI_LIST]:setitems({})
    self.UI[UI_COUNTER]:setText()
    self.UI[UI_SELECT]:setEnable(true)
    self.UI[UI_RESET]:setEnable(false)
    self.UI[UI_COPY]:setEnable(false)
    self.UI[UI_PASTE]:setEnable(false)
    self.UI[UI_DEL]:setEnable(false)
    self.UI[UI_TYPE].disabled = false
    self:setTypeText()

    if self.onTick_handler then
        Events.OnTick.Remove(self.onTick_handler)
    end
end

function CarTeleport_UI:createUI()
    local UI = NewUI()
    local marginPx = 15
    -- HACK: Не разобрался как нормально наследоваться, поэтому делаем хуки
    self.base_render = UI.render
    self.base_onMouseDownOutside = UI.onMouseDownOutside
    UI.CarTeleport_UI_instance = self -- Записываем self в UI чтоб потом достать в рендере (см `CarTeleport_UI:render`)
    UI.render = self.render
    UI.onMouseDownOutside = self.onMouseDownOutside

    local addEmpty_helper = function() -- NOTE: просто хелпер чтоб не писать длинную мутатень
        return UI:addEmpty(_,_,_, marginPx)
    end
    
    -- NOTE: формируем UI
    UI:setTitle(getText("IGUI_AdminPanel_CarTeleport_btn"))
    UI:addEmpty()
    UI:nextLine()
    addEmpty_helper()
    UI:addText(UI_TITLE, getText('IGUI_Teleport_car_list'), "Small")
    UI:addEmpty()
    UI:addText(UI_COUNTER, '', "Small", "Right")
    UI:nextLine()
    UI:addEmpty()
    UI:nextLine()
    UI:addScrollList(UI_LIST, {})
    UI:nextLine()
    addEmpty_helper()
    UI:nextLine()
    addEmpty_helper()
    UI:addText(UI_TYPE_LABEL, getText('IGUI_Teleport_teleport_type'))
    UI:addComboBox(UI_TYPE, UI_TYPE_DICT)
    addEmpty_helper()
    UI:nextLine()
    addEmpty_helper()
    UI:nextLine()
    addEmpty_helper()
    UI:addRichText(UI_DESCRIPTION, '')
    addEmpty_helper()
    UI:nextLine()
    addEmpty_helper()
    UI:nextLine()
    addEmpty_helper()
    UI:addButton(UI_SELECT, getText('IGUI_Teleport_select_area_btn'), self.selectArea_btnHandler);
    addEmpty_helper()
    UI:addButton(UI_RESET, getText('IGUI_Teleport_reset_btn'), self.reset_btnHandler);
    addEmpty_helper()
    UI:addButton(UI_CANCEL, getText('IGUI_Teleport_cancel_btn'), self.cancel_btnHandler);
    addEmpty_helper()
    UI:nextLine()
    UI:addEmpty()
    UI:setLineHeightPixel(marginPx)
    UI:nextLine()
    addEmpty_helper()
    UI:addButton(UI_COPY, getText('IGUI_Teleport_cut_btn'), self.copy_btnHandler);
    addEmpty_helper()
    UI:addButton(UI_PASTE, getText('IGUI_Teleport_paste_btn'), self.paste_btnHandler);
    addEmpty_helper()
    UI:addButton(UI_DEL, getText('IGUI_Teleport_remove_btn'), self.delete_btnHandler);
    addEmpty_helper()
    UI:nextLine()
    UI:addEmpty()
    UI:setLineHeightPixel(marginPx)
    UI['backgroundColor'].a = 1 -- NOTE: Убираем прозрачность у ричтекста
    
    UI[UI_SELECT]:addArg('self', self) -- NOTE: стандартный способ передачи аргументов (см `CarTeleport_UI.selectArea_btnHandler`)
    UI[UI_CANCEL].args = self -- NOTE: не задокументировано, но работает. Если нужно передать не key-value таблицу, а один аргумент
    UI[UI_RESET].args = self
    UI[UI_COPY].args = self
    UI[UI_PASTE].args = self
    UI[UI_DEL].args = self
    UI[UI_TYPE].target = self
    UI[UI_TYPE].onChange = self.typeChange_handler
    UI[UI_LIST].onMouseDown = function()
        UI[UI_LIST].selected = -1
    end
    
    UI:saveLayout();
    
    self.UI = UI
    self:reset()
    self:typeChange_handler()
end

function CarTeleport_UI:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    -- o.isCarTeleport_UI = true -- TODO: Удалить. Переменная просто для дебага. Чтоб отличить инстанс UI, от инстанса CarTeleport_UI. Потому что из-за хаков может возникнуть путаница
    o.player = getPlayer()
    if CarTeleport_UI.instance then -- NOTE: Делаем что-то типа синглтона. TODO: разобраться как делать нормальные синглтоны
        CarTeleport_UI.instance:close()
    end
    CarTeleport_UI.instance = o;
    o.onTick_handler = false
    self.createUI(o)
    return o
end

CarTeleport_UI.highlightArea = function(x1, x2, y1, y2, z, color)
    local cell = getCell()
    for x = x1, x2 do
        for y = y1, y2 do
            local sq = cell:getGridSquare(x, y, z)
            if sq then 
                local floor = sq:getFloor()
                if floor then
                    floor:setHighlighted(true) 
                    if color then
                        if color == 'red' then                            
                            floor:setHighlightColor(1,0,0,1); 
                        end
                        if color == 'green' then                            
                            floor:setHighlightColor(0,1,0,1); 
                        end
                        if color == 'blue' then                            
                            floor:setHighlightColor(0,0,1,1); 
                        end
                        if color == 'yellow' then                            
                            floor:setHighlightColor(1,1,0,1); 
                        end
                    end
                end        
            end
        end
    end
end

CarTeleport_UI.preHighlightArea = function (startX, stopX, startY, stopY, z, color)
    local x1 = math.min(startX, stopX)
    local x2 = math.max(startX, stopX)
    local y1 = math.min(startY, stopY)
    local y2 = math.max(startY, stopY)
    CarTeleport_UI.highlightArea(x1, x2, y1, y2, z, color)
end

-- NOTE: добавляем кнопку в админ панель
local base_ISAdminPanelUI_create = ISAdminPanelUI.create
function ISAdminPanelUI:create()
    base_ISAdminPanelUI_create(self)
    local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

    local btnWid = 150
    local btnHgt = math.max(25, FONT_HGT_SMALL + 3 * 2)
    local btnGapY = 5
    
    local last_btn = self.children[self.IDMax - 1]
    if last_btn.internal == "CANCEL" then
        last_btn = self.children[self.IDMax - 2]
    end
    local x = last_btn.x
    local y = last_btn.y + btnHgt + btnGapY
    
    if isAdmin() then
        self.carTeleportBtn = ISButton:new(x, y, btnWid, btnHgt, getText("IGUI_AdminPanel_CarTeleport_btn"), self, ISAdminPanelUI.carTeleport_btnHandler);
        self.carTeleportBtn.internal = "CAR_TELEPORT";
        self.carTeleportBtn:initialise();
        self.carTeleportBtn:instantiate();
        self.carTeleportBtn.borderColor = self.buttonBorderColor;
        self:addChild(self.carTeleportBtn);
    end
end

-- NOTE: хендлер для кнопки в админпанеле
function ISAdminPanelUI:carTeleport_btnHandler()
    CarTeleport_UI:new()
end

-- Events.OnCreateUI.Add(function() -- TODO: Удалить. Нужно для дебага. Чтобы просто открывать окно при старте
--     CarTeleport_UI:new()
-- end) 

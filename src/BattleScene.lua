require "Cocos2d"
require "Helper"
require "Manager"
require "MessageDispatchCenter"

currentLayer = nil
uiLayer = nil
local gameMaster = nil
local specialCamera = {valid = false, position = cc.p(0,0)}
local size = cc.Director:getInstance():getWinSize()
local scheduler = cc.Director:getInstance():getScheduler()
local cameraOffset = {valid = false, position = cc.V3(0, 0, 0)}
local rectKnight = cc.rect(832, 10, 60, 64)
local rectArcher = cc.rect(902, 10, 60, 64)
local rectMage = cc.rect(974, 10, 60, 64)

local function moveCamera(dt)
    --cclog("moveCamera")
    if camera == nil then return end

    local cameraPosition = getPosTable(camera)
    local focusPoint = getFocusPointOfHeros()
    if specialCamera.valid == true then
        --local position = cc.pRotateByAngle(cameraPosition, cc.p(specialCamera.position.x, -size.height/2), -360/60/2*dt)
        local position = cc.pLerp(cameraPosition, cc.p(specialCamera.position.x, -size.height/2), 5*dt)
        
        camera:setPosition(position)
        camera:lookAt(cc.V3(position.x, specialCamera.position.y, 50.0), cc.V3(0.0, 0.0, 1.0))
    elseif List.getSize(HeroManager) > 0 then
        local position = cc.V3(focusPoint.x, focusPoint.y - size.height, size.height/2-100)
        if cameraOffset.valid then
            position = cc.V3Add(position, cameraOffset.position)
            camera:setPosition3D(position)
            camera:lookAt(cc.V3(focusPoint.x, focusPoint.y, 50.0), cc.V3(0.0, 0.0, 1.0))
        else
            local temp = cc.pLerp(cameraPosition, cc.p(position.x, position.y), 2*dt)
            position = cc.V3(temp.x, temp.y, position.z)
            camera:setPosition3D(position)
            camera:lookAt(cc.V3(position.x, focusPoint.y, 50.0), cc.V3(0.0, 0.0, 1.0))
            --cclog("\ncalf %f %f %f \ncalf %f %f 50.000000", position.x, position.y, position.z, focusPoint.x, focusPoint.y)            
        end
    end
end

local function updateParticlePos()
    --cclog("updateParticlePos")
    for val = HeroManager.first, HeroManager.last do
        local sprite = HeroManager[val]
        if sprite._particle ~= nil then        
            sprite._particle:setPosition(getPosTable(sprite))
        end
    end
end

local function createBackground()
    local spriteBg = cc.Sprite3D:create("model/scene1.c3b", "model/zhenghe.png")

    currentLayer:addChild(spriteBg)
    spriteBg:setScale(2.65)
    --spriteBg:setGlobalZOrder(-9)
    spriteBg:setPosition3D(cc.V3(-1000,350,0))
    spriteBg:setRotation3D(cc.V3(90,0,0))
        
    local water = cc.Water:create("shader3D/water.png", "shader3D/wave1.png", "shader3D/18.jpg", {width=5000, height=400}, 0.77, 0.3797, 1.2)
    currentLayer:addChild(water)
    water:setPosition3D(cc.V3(-3500,-400,-35))
    water:setAnchorPoint(0,0)
    water:setGlobalZOrder(0)
    
end

local function setCamera()
    camera = cc.Camera:createPerspective(60.0, size.width/size.height, 10.0, 4000.0)
--    local focusPoint = getFocusPointOfHeros()
--    local position = cc.V3(focusPoint.x, focusPoint.y-size.height, size.height/2-100)
--    camera:setPosition3D(position)
--    camera:lookAt(cc.V3(focusPoint.x, focusPoint.y, 0.0), cc.V3(0.0, 0.0, 1.0))
    camera:setGlobalZOrder(10)
    currentLayer:addChild(camera)

    cameraOffset.valid = false
    cameraOffset.position = cc.V3(0, 0, 0)
    
    for val = HeroManager.first, HeroManager.last do
        local sprite = HeroManager[val]
        if sprite._particle then
            sprite._particle:setCamera(camera)
        end
    end      
    
    camera:addChild(uiLayer)
end

local function gameController(dt)
    collisionDetect(dt)
    solveAttacks(dt)
    moveCamera(dt)
    updateParticlePos()
    gameMaster:update(dt)
end

local function initUILayer()
    uiLayer = require("BattleFieldUI").create()

    uiLayer:setPositionZ(-cc.Director:getInstance():getZEye()/3)
    uiLayer:setScale(0.333)
    uiLayer:ignoreAnchorPointForPosition(false)
    uiLayer:setGlobalZOrder(3000)
end

local BattleScene = class("BattleScene",function()
    return cc.Scene:create()
end)

local function sendDropBlood(heroActor)
    if heroActor._racetype == EnumRaceType.HERO then    
        uiLayer:bloodDrop(heroActor)
    end
end

local function specialPerspective(position)
    if specialCamera.valid == true then return end
    
    specialCamera.valid = true
    specialCamera.position = position
    cc.Director:getInstance():getScheduler():setTimeScale(0.1)

    local function restoreTimeScale()
        specialCamera.valid = false
        cc.Director:getInstance():getScheduler():setTimeScale(1.0)
    end
    delayExecute(currentLayer, restoreTimeScale, 0.5)      
      
end

function BattleScene:enableTouch()
    local function onTouchBegin(touch,event)
        self._prePosition = touch:getLocation()
        --cclog("onTouchBegin: %0.2f, %0.2f", self._prePosition.x, self._prePosition.y)        
        return true
    end
    
    local function onTouchMoved(touch,event)
        cameraOffset.valid = true
        local location = touch:getLocation()
        
        local delta = cc.pSub(location, self._prePosition)
        --cclog("calf delta: %f %f", delta.x, delta.y)
        cameraOffset.position.x = cameraOffset.position.x + delta.x
        cameraOffset.position.y = cameraOffset.position.y + delta.y
        
        self._prePosition = location
    end
    
    local function onTouchEnded(touch,event)
        cameraOffset.valid = false

        local location = touch:getLocation()
        
        if cc.rectContainsPoint(rectKnight, location) then
            --cclog("rectKnight")
            MessageDispatchCenter:dispatchMessage(MessageDispatchCenter.MessageType.SPECIAL_KNIGHT, 1)            
        elseif cc.rectContainsPoint(rectArcher, location) then
            --cclog("rectArcher")
            MessageDispatchCenter:dispatchMessage(MessageDispatchCenter.MessageType.SPECIAL_ARCHER, 1)            
        elseif cc.rectContainsPoint(rectMage, location) then
            --cclog("rectMage")
            MessageDispatchCenter:dispatchMessage(MessageDispatchCenter.MessageType.SPECIAL_MAGE, 1)            
        end        
    end
        
    local touchEventListener = cc.EventListenerTouchOneByOne:create()
    touchEventListener:registerScriptHandler(onTouchBegin,cc.Handler.EVENT_TOUCH_BEGAN)
    touchEventListener:registerScriptHandler(onTouchMoved,cc.Handler.EVENT_TOUCH_MOVED)
    touchEventListener:registerScriptHandler(onTouchEnded,cc.Handler.EVENT_TOUCH_ENDED)
    currentLayer:getEventDispatcher():addEventListenerWithSceneGraphPriority(touchEventListener, currentLayer)        
end

function BattleScene.create()
    local scene = BattleScene:new()
    currentLayer = cc.Layer:create()
    scene:addChild(currentLayer)
    scene:enableTouch()    
 
    createBackground()
    initUILayer()
    gameMaster = require("GameMaster").create()
    setCamera()
    scheduler:scheduleScriptFunc(gameController, 0, false)

    MessageDispatchCenter:registerMessage(MessageDispatchCenter.MessageType.BLOOD_DROP, sendDropBlood)
    MessageDispatchCenter:registerMessage(MessageDispatchCenter.MessageType.SPECIAL_PERSPECTIVE,specialPerspective)

    return scene
end

return BattleScene

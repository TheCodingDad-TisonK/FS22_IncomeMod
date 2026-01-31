-- =========================================================
-- FS22 Income Mod (version 1.2.5.2)
-- =========================================================
-- Hourly or daily income for players
-- =========================================================
-- Author: TisonK
-- =========================================================
-- COPYRIGHT NOTICE:
-- All rights reserved. Unauthorized redistribution, copying,
-- or claiming this code as your own is strictly prohibited.
-- Original author: TisonK
-- =========================================================

Income = {}
Income.modName = "FS22_IncomeMod"
Income.settings = {}
Income.hasRegisteredSettings = false
Income.version = "1.2.5.2"

-- =====================
-- DEFAULT CONFIGURATION
-- =====================
Income.DEFAULT_CONFIG = {
    enabled = true,
    mode = "hourly",
    difficulty = "normal",
    showNotification = true,
    debugLevel = 1,
    useCustomAmount = false,
    customAmount = 2500
}

Income.DIFFICULTY_VALUES = {
    easy = 5000,
    normal = 2400,
    hard = 1100
}

-- =====================
-- INTERNAL STATE
-- =====================
Income.lastHour = -1
Income.lastDay = -1
Income.isLoaded = false
Income.welcomeBannerTimer = nil
Income.welcomeMessageTimer = nil
Income.settingsRetryTimer = nil

-- =====================
-- UTILITY FUNCTIONS
-- =====================
function Income:log(msg, level)
    level = level or 1
    if self.settings.debugLevel >= level then
        print("["..self.modName.."] "..tostring(msg))
    end
end

function Income:printBanner()
    self:log("===================================")
    self:log("Income Mod")
    self:log("Version: "..self.version)
    self:log("Author: TisonK")
    self:log("Mode: "..self.settings.mode)
    self:log("Difficulty: "..self.settings.difficulty)
    self:log("Enabled: "..tostring(self.settings.enabled))
    self:log("Custom Amount: "..(self.settings.useCustomAmount and self.settings.customAmount or "N/A"))
    self:log("Debug Level: "..self.settings.debugLevel)
    self:log("===================================")
end

function Income:isServer()
    return g_currentMission ~= nil and g_currentMission:getIsServer()
end

function Income:getDynamicIncome()
    local baseAmount = self.settings.useCustomAmount and self.settings.customAmount or (Income.DIFFICULTY_VALUES[self.settings.difficulty] or 2400)

    local farmId = g_currentMission.player.farmId
    local playerCount = 0
    for _, player in pairs(g_currentMission.players) do
        if player.farmId == farmId then
            playerCount = playerCount + 1
        end
    end

    local scaledAmount = math.floor(baseAmount * (1 + 0.1 * (playerCount - 1)))

    local farm = g_farmManager.farms[farmId]
    if farm ~= nil and farm.farmLand ~= nil then
        local landFactor = math.min(farm.farmLand.size / 10000, 2)
        scaledAmount = math.floor(scaledAmount * landFactor)
    end

    return scaledAmount
end


function Income:copyTable(t)
    local r = {}
    for k,v in pairs(t) do r[k] = v end
    return r
end

function Income:i18n(key,fallback)
    if g_i18n:hasText(key) then return g_i18n:getText(key) end
    return fallback or key
end

-- =====================
-- SETTINGS SYSTEM
-- =====================
function Income:getSettingsFilePath()
    local baseDir = getUserProfileAppPath().."modSettings"
    local modDir = baseDir.."/FS22_IncomeMod"
    createFolder(baseDir)
    createFolder(modDir)
    return modDir.."/settings.xml"
end

function Income:loadSettingsFromXML()
    local filePath = self:getSettingsFilePath()
    local xmlFile = loadXMLFile("settings", filePath)
    if xmlFile ~= 0 then
        self.settings.enabled = Utils.getNoNil(getXMLBool(xmlFile,"FS22_IncomeMod.enabled"),self.DEFAULT_CONFIG.enabled)
        self.settings.mode = Utils.getNoNil(getXMLString(xmlFile,"FS22_IncomeMod.mode"),self.DEFAULT_CONFIG.mode)
        self.settings.difficulty = Utils.getNoNil(getXMLString(xmlFile,"FS22_IncomeMod.difficulty"),self.DEFAULT_CONFIG.difficulty)
        self.settings.showNotification = Utils.getNoNil(getXMLBool(xmlFile,"FS22_IncomeMod.showNotification"),self.DEFAULT_CONFIG.showNotification)
        self.settings.debugLevel = Utils.getNoNil(getXMLInt(xmlFile,"FS22_IncomeMod.debugLevel"),self.DEFAULT_CONFIG.debugLevel)
        self.settings.useCustomAmount = Utils.getNoNil(getXMLBool(xmlFile,"FS22_IncomeMod.useCustomAmount"),self.DEFAULT_CONFIG.useCustomAmount)
        self.settings.customAmount = Utils.getNoNil(getXMLInt(xmlFile,"FS22_IncomeMod.customAmount"),self.DEFAULT_CONFIG.customAmount)
        self.lastHour = Utils.getNoNil(getXMLInt(xmlFile,"FS22_IncomeMod.lastHour"),g_currentMission.environment.currentHour)
        self.lastDay = Utils.getNoNil(getXMLInt(xmlFile,"FS22_IncomeMod.lastDay"),g_currentMission.environment.currentDay)
        delete(xmlFile)
        self:log("[Income Mod] Settings loaded from XML: "..filePath)
    else
        self.settings = self:copyTable(self.DEFAULT_CONFIG)
        self.lastHour = g_currentMission.environment.currentHour
        self.lastDay = g_currentMission.environment.currentDay
        self:log("[Income Mod] Using default settings")
        self:saveSettingsToXML()
    end
end

function Income:saveSettingsToXML()
    local filePath = self:getSettingsFilePath()
    local xmlFile = createXMLFile("settings", filePath, "FS22_IncomeMod")
    if xmlFile ~= 0 then
        setXMLBool(xmlFile,"FS22_IncomeMod.enabled",self.settings.enabled)
        setXMLString(xmlFile,"FS22_IncomeMod.mode",self.settings.mode)
        setXMLString(xmlFile,"FS22_IncomeMod.difficulty",self.settings.difficulty)
        setXMLBool(xmlFile,"FS22_IncomeMod.showNotification",self.settings.showNotification)
        setXMLInt(xmlFile,"FS22_IncomeMod.debugLevel",self.settings.debugLevel)
        setXMLBool(xmlFile,"FS22_IncomeMod.useCustomAmount",self.settings.useCustomAmount)
        setXMLInt(xmlFile,"FS22_IncomeMod.customAmount",self.settings.customAmount)
        setXMLInt(xmlFile,"FS22_IncomeMod.lastHour",self.lastHour)
        setXMLInt(xmlFile,"FS22_IncomeMod.lastDay",self.lastDay)
        saveXMLFile(xmlFile)
        delete(xmlFile)
        self:log("[Income Mod] Settings saved to XML: "..filePath)
    else
        self:log("Failed to create XML file: "..filePath)
    end
end

-- =====================================================
-- Income Mod Tablet Interface
-- =====================================================
function Income:openFromTablet(action)
    -- Handle enable/disable buttons
    if action == "enable" then
        self.settings.enabled = true
        self:saveSettingsToXML()
        self:log("Income enabled via tablet", 1)
        return {success = true, action = "enabled"}
    elseif action == "disable" then
        self.settings.enabled = false
        self:saveSettingsToXML()
        self:log("Income disabled via tablet", 1)
        return {success = true, action = "disabled"}
    elseif action == "status" or action == nil then
        -- Return status info
        local modeText = (self.settings.mode == "hourly") and "Hourly" or "Daily"
        local amount = self:getDynamicIncome()
        local formattedAmount = g_i18n:formatMoney(amount, 0, true, true) or ("€" .. tostring(amount))
        local statusText = self.settings.enabled and "Enabled" or "Disabled"
        
        return {
            enabled = self.settings.enabled,
            statusText = statusText,
            mode = self.settings.mode,
            modeText = modeText,
            amount = amount,
            formattedAmount = formattedAmount,
            difficulty = self.settings.difficulty,
            useCustomAmount = self.settings.useCustomAmount,
            customAmount = self.settings.customAmount
        }
    end
    
    return {error = "Unknown action"}
end

-- =====================
-- MOD LIFECYCLE
-- =====================
function Income:loadMap()
    if g_currentMission == nil then return end
    if self.isLoaded then return end

    self:loadSettingsFromXML()

    if self.settings.enabled then
        self.welcomeBannerTimer = 0.1
        self.welcomeMessageTimer = nil
    end

    if g_farmTablet and g_farmTablet.registerAsApp then
        g_farmTablet.registerAsApp(self,{
            id="income_mod",
            name="tablet_app_income",
            icon="income_icon",
            developer="TisonK",
            version=self.version,
            enabled=true,
            openFunction=function()
                self:log("Income Mod opened from tablet",2)
            end
        })
    end

    self.isLoaded = true
    addConsoleCommand("income","Configure Income Mod settings","onConsoleCommand",self)
    self:tryRegisterSettings()
end

function Income:update(dt)
    if self.settingsRetryTimer ~= nil then
        self.settingsRetryTimer = self.settingsRetryTimer - dt
        if self.settingsRetryTimer <= 0 then
            self:tryRegisterSettings()
            self.settingsRetryTimer = nil
        end
    end

    if self.welcomeBannerTimer ~= nil then
        self.welcomeBannerTimer = self.welcomeBannerTimer - dt
        if self.welcomeBannerTimer <= 0 then
            self:printBanner()
            self.welcomeMessageTimer = 5
            self.welcomeBannerTimer = nil
        end
    end

    if self.welcomeMessageTimer ~= nil then
        self.welcomeMessageTimer = self.welcomeMessageTimer - dt
        if self.welcomeMessageTimer <= 0 then
            self:log(self:i18n("income_mod_welcome_message","Welcome!"),1)
            self:log(self:i18n("income_mod_help_message","Type 'income' for help."),1)
            if self.settings.enabled and self.settings.showNotification then
                local msg = self:i18n("income_mod_welcome_message","").."\n"..self:i18n("income_mod_help_message","")
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,msg)
            end
            self.welcomeMessageTimer=nil
        end
    end

    if not self.settings.enabled or g_currentMission==nil or not self:isServer() then return end
    if g_currentMission.player==nil or g_currentMission.environment==nil then return end

    local env = g_currentMission.environment
    if self.settings.mode=="hourly" then self:checkHourly(env)
    elseif self.settings.mode=="daily" then self:checkDaily(env)
    end
end

-- =====================
-- PAUSE/LOAD SAFE CHECK
-- =====================
function Income:isGameActive()
    if g_currentMission == nil or g_currentMission.environment == nil then
        return false
    end
    if g_currentMission.missionInfo.isPaused or g_currentMission.player == nil then
        return false
    end
    return true
end

-- =====================
-- HOURLY / DAILY
-- =====================
function Income:checkHourly(env)
    if not self:isGameActive() then return end

    local currentHour = env.currentHour
    local hoursMissed = currentHour - self.lastHour
    if hoursMissed <= 0 then return end

    for i = 1, hoursMissed do
        self.lastHour = self.lastHour + 1
        self:giveMoney("hourly")
    end

    self:saveSettingsToXML()
end

function Income:checkDaily(env)
    if not self:isGameActive() then return end

    local currentDay = env.currentDay
    local daysMissed = currentDay - self.lastDay
    if daysMissed <= 0 then return end

    for i = 1, daysMissed do
        self.lastDay = self.lastDay + 1
        self:giveMoney("daily")
    end

    self:saveSettingsToXML()
end

-- =====================
-- MONEY HANDLER
-- =====================
function Income:getFormattedMessage(type, amount)
    local typeText = ""
    if type == "hourly" then
        typeText = self:i18n("income_mod_type_hourly", "hourly income")
    elseif type == "daily" then
        typeText = self:i18n("income_mod_type_daily", "daily income")
    elseif type == "test" then
        typeText = self:i18n("income_mod_type_test", "test income")
    end
    
    local formattedAmount = g_i18n:formatMoney(amount, 0, true, true)
    return string.format(self:i18n("income_mod_message", "You received %s of %s"), typeText, formattedAmount)
end

function Income:showNotification(type,amount)
    if not self.settings.showNotification then return end
    local title=self:i18n("income_mod_notification_title","Income Received")
    local msg=self:getFormattedMessage(type,amount)
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,string.format("[%s] %s",title,msg))
end

function Income:giveMoney(type)
    local amount = (type=="test") and 1 or self:getDynamicIncome()
    if g_farmManager ~= nil then
        local farmId = g_currentMission.player.farmId
        for _,farm in pairs(g_farmManager.farms) do
            if farm.isPlayerFarm or farm.farmId==farmId then
                g_currentMission:addMoney(amount,farm.farmId,MoneyType.OTHER,true)
                self:log(string.format("%s income given to Farm ID:%d | Amount:€%d",type,farm.farmId,amount),1)
            end
        end
    end
    self:showNotification(type,amount)
end

function Income:setCustomIncome(amount)
    self.settings.useCustomAmount = true
    self.settings.customAmount = amount
    self:saveSettingsToXML()
    self:log("Custom income set to €"..amount)
end

function Income:resetCustomIncome()
    self.settings.useCustomAmount = false
    self:saveSettingsToXML()
    self:log("Custom income reset; using difficulty "..self.settings.difficulty)
end

-- =====================
-- SETTINGS & PAUSE MENU
-- =====================
function Income:tryRegisterSettings()
    if not self.hasRegisteredSettings then
        if g_modSettingsManager ~= nil then
            self:registerModSettings()
            self.hasRegisteredSettings = true
            self:log("Settings registered in pause menu",2)
        else
            self.settingsRetryTimer = 2000
            self:log("Settings page not available yet, use console to configure",1)
        end
    end
end

function Income:registerModSettings()
    if g_modSettingsManager==nil then return false end
    local settings = {
        {
            key="incomeModEnabled",
            name="income_mod_enabled",
            tooltip="income_mod_enabled_tooltip",
            type="checkbox",
            default=self.DEFAULT_CONFIG.enabled,
            current=self.settings.enabled,
            onChange=function(value)
                self.settings.enabled=value
                self:saveSettingsToXML()
            end
        },
        {
            key="incomeModMode",
            name="income_mod_mode",
            tooltip="income_mod_mode_tooltip",
            type="list",
            default=self.DEFAULT_CONFIG.mode,
            current=self.settings.mode,
            values={
                {name="income_mod_mode_hourly",value="hourly"},
                {name="income_mod_mode_daily",value="daily"}
            },
            onChange=function(value)
                self.settings.mode=value
                self:saveSettingsToXML()
            end
        },
        {
            key="incomeModDifficulty",
            name="income_mod_difficulty",
            tooltip="income_mod_difficulty_tooltip",
            type="list",
            default=self.DEFAULT_CONFIG.difficulty,
            current=self.settings.difficulty,
            values={
                {name="income_mod_difficulty_easy",value="easy",additionalText=g_i18n:formatMoney(self.DIFFICULTY_VALUES.easy,0,true,true)},
                {name="income_mod_difficulty_normal",value="normal",additionalText=g_i18n:formatMoney(self.DIFFICULTY_VALUES.normal,0,true,true)},
                {name="income_mod_difficulty_hard",value="hard",additionalText=g_i18n:formatMoney(self.DIFFICULTY_VALUES.hard,0,true,true)}
            },
            onChange=function(value)
                self.settings.difficulty=value
                self:resetCustomIncome()
                self:saveSettingsToXML()
            end
        },
        {
            key="incomeModUseCustomAmount",
            name="Custom Income Amount",
            tooltip="Use a custom income amount",
            type="checkbox",
            default=self.DEFAULT_CONFIG.useCustomAmount,
            current=self.settings.useCustomAmount,
            onChange=function(value)
                self.settings.useCustomAmount=value
                self:saveSettingsToXML()
            end
        },
        {
            key="incomeModCustomAmount",
            name="Custom Amount",
            tooltip="Set the custom income amount",
            type="int",
            default=self.DEFAULT_CONFIG.customAmount,
            current=self.settings.customAmount,
            onChange=function(value)
                self.settings.customAmount=value
                self:saveSettingsToXML()
            end
        },
        {
            key="incomeModNotifications",
            name="income_mod_notifications",
            tooltip="income_mod_notifications_tooltip",
            type="checkbox",
            default=self.DEFAULT_CONFIG.showNotification,
            current=self.settings.showNotification,
            onChange=function(value)
                self.settings.showNotification=value
                self:saveSettingsToXML()
            end
        },
        {
            key="incomeModDebugLevel",
            name="income_mod_debug",
            tooltip="income_mod_debug_tooltip",
            type="list",
            default=self.DEFAULT_CONFIG.debugLevel,
            current=self.settings.debugLevel,
            values={
                {name="OFF",value=0},
                {name="BASIC",value=1},
                {name="VERBOSE",value=2}
            },
            onChange=function(value)
                self.settings.debugLevel=value
                self:saveSettingsToXML()
            end
        }
    }
    g_modSettingsManager:addModSettings(self.modName,settings,self:i18n("income_mod_category","Income Mod"))
    return true
end

-- =====================
-- CONSOLE COMMANDS
-- =====================
function Income:onConsoleCommand(...)
    local args={...}
    if #args==0 then
        print(self:i18n("income_mod_console_help","Income Mod Commands"))
        return true
    end

    local action=args[1]:lower()
    if action=="status" then
        print(self:i18n("income_mod_console_status_header","=== Income Mod Status ==="))
        print(string.format(self:i18n("income_mod_console_status_enabled","Enabled: %s"),self.settings.enabled and self:i18n("income_mod_status_enabled","Enabled") or self:i18n("income_mod_status_disabled","Disabled")))
        print(string.format(self:i18n("income_mod_console_status_mode","Mode: %s"),self.settings.mode))
        print(string.format(self:i18n("income_mod_console_status_difficulty","Difficulty: %s"),self.settings.difficulty))
        print(string.format(self:i18n("income_mod_console_status_amount","Amount: €%d"),self:getMoneyAmount()))
        print(string.format(self:i18n("income_mod_console_status_debug","Debug: %s"),self.settings.debugLevel))
        print(string.format(self:i18n("income_mod_console_status_notifications","Show Notifications: %s"),tostring(self.settings.showNotification)))
        print(string.format(self:i18n("income_mod_console_status_last_hour","Last Hour: %s"),tostring(self.lastHour)))
        print(string.format(self:i18n("income_mod_console_status_last_day","Last Day: %s"),tostring(self.lastDay)))
    elseif action=="enable" then
        self.settings.enabled=true
        self:saveSettingsToXML()
        print(self:i18n("income_mod_console_enabled","Income enabled"))
    elseif action=="disable" then
        self.settings.enabled=false
        self:saveSettingsToXML()
        print(self:i18n("income_mod_console_disabled","Income disabled"))
    elseif action=="mode" and args[2] then
        local mode=args[2]:lower()
        if mode=="hourly" or mode=="daily" then
            self.settings.mode=mode
            self:saveSettingsToXML()
            print(string.format(self:i18n("income_mod_console_mode_set","Income mode set to: %s"),mode))
        else
            print(self:i18n("income_mod_console_invalid_mode","Invalid mode"))
        end
    elseif action=="difficulty" and args[2] then
        local diff=args[2]:lower()
        if Income.DIFFICULTY_VALUES[diff]~=nil then
            self.settings.difficulty=diff
            self:resetCustomIncome()
            self:saveSettingsToXML()
            print(string.format(self:i18n("income_mod_console_difficulty_set","Difficulty set to: %s (€%s)"),diff,self:getMoneyAmount()))
        else
            print(self:i18n("income_mod_console_invalid_difficulty","Invalid difficulty"))
        end
    elseif action=="debug" then
        self.settings.debugLevel=(self.settings.debugLevel==0 and 1) or 0
        self:saveSettingsToXML()
        print(string.format(self:i18n("income_mod_console_debug_toggled","Debug mode: %s"),self.settings.debugLevel))
    elseif action=="test" then
        print(self:i18n("income_mod_console_testing_payment","Testing payment..."))
        self:giveMoney("test")
        print(self:i18n("income_mod_test_complete","Payment test complete"))
    elseif action=="reload" then
        self:loadSettingsFromXML()
        print(self:i18n("income_mod_console_settings_reloaded","Settings reloaded from XML"))
    elseif action=="custom" and args[2] then
        local amount=tonumber(args[2])
        if amount~=nil and amount>0 then
            self:setCustomIncome(amount)
            print(string.format(g_i18n:getText("income_mod_custom_amount_set"),amount))
        else
            print("Invalid amount. Use a positive number.")
        end
    else
        print(self:i18n("income_mod_console_unknown_command","Unknown command"))
    end
    return true
end

-- =====================
-- GLOBAL REGISTRATION
-- =====================
g_IncomeMod = Income

-- =====================
-- HOOKS
-- =====================
addModEventListener(Income)

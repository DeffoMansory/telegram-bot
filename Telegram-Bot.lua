script_author('rvnmph')
script_description('Telegram-Bot for arizona rp')
script_moonloader(0.26)
script_version('1.01')
script_version = 1.01

require("lib.moonloader")
local sampev = require("lib.samp.events")
local vkey = require("vkeys")
local effil = require("effil")
local imgui = require("mimgui")
local ffi = require("ffi")
local str, sizeof = ffi.string, ffi.sizeof
local new = imgui.new
local encoding = require("encoding")
encoding.default = 'CP1251'
u8 = encoding.UTF8

local http = require("socket.http")
local keys = require 'vkeys'
local window          = new.bool()
local windowReconnect = new.bool()
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    styleScript()
end)

ffi.cdef[[
    int system(const char *command);
]]

local updateid
local sendToTelegram = false
local sendToTelegramc = false
local hpSent = false
local isCollectingCheck = false

local connect = {}
local connected = {}
local checkLines = {}

local hiText = {
    '[Telegram-Bot]: {ffffff}Открыть настройки бота: /tbot'
}

local scommands = 
{   
    {'[Telegram-Bot] /connect', 'подключиться к серверу'},
    {'[Telegram-Bot] /disconnect', 'отключиться от сервера'},
    {'[Telegram-Bot] /stats', 'получить статистику персонажа'},
    {'[Telegram-Bot] /skill', 'получить скиллы персонажа'},
    {'[Telegram-Bot] /sendscreen', 'получить скриншот с экрана'},
    {'[Telegram-Bot] /reloadbot', 'перезапустить бота'},
    {'[Telegram-Bot] /reloadlua', 'перезапустить все Lua-скрипты'},
    {'[В игре] /tg', 'отправить тестовое сообщение боту'},
    {'[В игре] /tg.stats', 'отправить статистику своего порсонажа боту'},
    {'[В игре] /tg.reload', 'перезапустить бота'}
}

local directConfig = getWorkingDirectory()..'/config/Telegram-Bot.json'
print(getWorkingDirectory())
local defaultTable =
{
	['settings'] =
	{	
		['token'] = '',
		['chat_id'] = '',
		['activeBot'] = false,
        ['autoReconnect'] = false,
		['connect'] = false,
		['disconnect'] = false,
		['sendStats'] = false,
		['sendScreen'] = false,
		['reloadbot'] = false,
		['reloadlua'] = false,
		['sendPayDay'] = false,
		['sendInventory'] = false,
		['sendSatiety'] = false,
		['sendStorage'] = false,
		['sendConnect'] = false,
        ['autoEat'] = false,
        ['recMaxDelay'] = ''
	}
}
local sconfig = {}

if not doesFileExist(directConfig) then
	conf = assert(io.open(directConfig, 'w'), 'No permission to create file')
	conf:write(encodeJson(defaultTable))
	conf:close()
end
conf = io.open(directConfig, 'r')
local config = decodeJson(conf:read("*a"))
conf:close()
if type(config) ~= 'table' then config = defaultTable 
else
	for i, v in pairs(defaultTable) do
		if type(config[i]) == 'table' then
			for i1, v1 in pairs(defaultTable[i]) do
				if type(config[i][i1]) ~= type(v1) then config[i][i1] = v1 end
			end
		elseif type(config[i]) ~= type(v) then config[i] = v end
	end
end
conf = io.open(directConfig, 'w')
conf:write(encodeJson(config))
conf:close()

local elements =
{
	buffer =
	{
		token         = new.char[128](config['settings']['token']),
		chat_id       = new.char[128](config['settings']['chat_id']),
        recMaxDelay   = new.char[16](config['settings']['recMaxDelay'])
    },
	value =
	{
		activeBot     = new.bool(config['settings']['activeBot']),
        connect       = new.bool(config['settings']['connect']),
        disconnect    = new.bool(config['settings']['disconnect']),
        sendStats     = new.bool(config['settings']['sendStats']),
        sendScreen    = new.bool(config['settings']['sendScreen']),
        reloadbot     = new.bool(config['settings']['reloadbot']),
        reloadlua     = new.bool(config['settings']['reloadlua']),
        sendPayDay    = new.bool(config['settings']['sendPayDay']),
        sendInventory = new.bool(config['settings']['sendInventory']),
        sendSatiety   = new.bool(config['settings']['sendSatiety']),
        sendStorage   = new.bool(config['settings']['sendStorage']),
        sendConnect   = new.bool(config['settings']['sendConnect']),
        autoReconnect = new.bool(config['settings']['autoReconnect']),
        autoEat       = new.bool(config['settings']['autoEat'])
	}
}

local dlstatus = require('moonloader').download_status

function update()
    local raw = 'https://raw.githubusercontent.com/DeffoMansory/telegram-bot/refs/heads/main/update.json'
    local dlstatus = require('moonloader').download_status
    local requests = require('requests')
    local f = {}
    function f:getLastVersion()
        local response = requests.get(raw)
        if response.status_code == 200 then
            return decodeJson(response.text)['last']
        else
            return 'UNKNOWN'
        end
    end
    function f:download()
        local response = requests.get(raw)
        if response.status_code == 200 then
			local data = decodeJson(response.text)
        	local url = data['url']
            downloadUrlToFile(decodeJson(response.text)['url'], thisScript().path, function (id, status, p1, p2)
                print('Скачиваю '..decodeJson(response.text)['url']..' в '..thisScript().path)
                if status == dlstatus.STATUSEX_ENDDOWNLOAD then
					sampAddChatMessage('[Telegram-Bot]: {ffffff}Скрипт был успешно обновлён. Сейчас он будет перезапущен', 0xff6600)
                    thisScript():reload()
                end
            end)
        else
            sampAddChatMessage('[Telegram-Bot]: {ffffff}Ошибка, невозможно установить обновление, код: '..response.status_code, 0xff6600)
        end
    end
    return f
end

function saveConfig()
	conf = io.open(directConfig, 'w')
	conf:write(encodeJson(config))
	conf:close()
end

if script_properties then
	script_properties('work-in-pause', 'forced-reloading-only')
end

function myIP()
    local ip, status = http.request("http://api.ipify.org")
    if status == 200 then
        return ip
    else
        return "Unable to get IP"
    end
end

function threadHandle(runner, url, args, resolve, reject)
    local t = runner(url, args)
    local r = t:get(0)
    while not r do
        r = t:get(0)
        wait(0)
    end
    local status = t:status()
    if status == 'completed' then
        local ok, result = r[1], r[2]
        if ok then resolve(result) else reject(result) end
    elseif err then
        reject(err)
    elseif status == 'canceled' then
        reject(status)
    end
    t:cancel(0)
end

function requestRunner()
    return effil.thread(function(u, a)
        local https = require 'ssl.https'
        local ok, result = pcall(https.request, u, a)
        if ok then
            return {true, result}
        else
            return {false, result}
        end
    end)
end

function async_http_request(url, args, resolve, reject)
    local runner = requestRunner()
    if not reject then reject = function() end end
    lua_thread.create(function()
        threadHandle(runner, url, args, resolve, reject)
    end)
end

function encodeUrl(str)
    str = str:gsub(' ', '%+')
    str = str:gsub('\n', '%%0A')
    return u8:encode(str, 'CP1251')
end

function sendTelegramNotification(msg)
    if not elements.value.activeBot[0] then return end
    local token = ffi.string(elements.buffer.token)
    local chat_id = ffi.string(elements.buffer.chat_id)

    msg = msg:gsub('{......}', '')
    msg = encodeUrl(msg)

    async_http_request(
        'https://api.telegram.org/bot' .. token ..
        '/sendMessage?chat_id=' .. chat_id ..
        '&text=' .. msg,
        '',
        function(result) end
    )
end

function get_telegram_updates()
    while not updateid do wait(1) end

    local runner = requestRunner()
    local reject = function() end
    local args = ''

    local token = ffi.string(elements.buffer.token)
    local chat_id = ffi.string(elements.buffer.chat_id)

    while true do
        local url = 'https://api.telegram.org/bot'..token..
                    '/getUpdates?chat_id='..chat_id..'&offset=-1'

        threadHandle(runner, url, args, processing_telegram_messages, reject)
        wait(500)
    end
end

function statsButton()
    if not elements.value.activeBot[0] then return end
    sendToTelegram = true
    sampSendChat('/stats')
end

function skillstatsButton()
    if not elements.value.activeBot[0] then return end
    sendToTelegram = true
    sampSendChat('/skill')
end

function processing_telegram_messages(result)
    local token = ffi.string(elements.buffer.token)
    local chat_id = ffi.string(elements.buffer.chat_id)
    if result then
        local proc_table = decodeJson(result)
        if proc_table.ok then
            if #proc_table.result > 0 then
                local res_table = proc_table.result[1]
                if res_table then
                    if res_table.update_id ~= updateid then
                        updateid = res_table.update_id
                        local message_from_user = res_table.message.text
                        if message_from_user then
                            local text = u8:decode(message_from_user) .. ' '


                            if text:find('/connect') then
                                if elements.value.connect[0] then
                                local ip, port = sampGetCurrentServerAddress()
                                sampConnectToServer(ip, port)
                                end

                            elseif text:match('/disconnect') then
                                if elements.value.disconnect[0] then
                                sampDisconnectWithReason()
                                end
                            elseif text:match('/skill') then
                                if elements.value.sendStats[0] then 
                                    skillstatsButton()
                                end
                            elseif text:match('/stats') then
                                if elements.value.sendStats[0] then 
                                    statsButton()
                                end


                            elseif text:match('/reloadlua') then
                                if elements.value.reloadlua[0] then
                                reloadScripts()
                                end
                            
                            elseif text:match('/reloadbot') then
                                if elements.value.reloadbot[0] then
                                thisScript():reload()
                                end
                            elseif text:match('/sendscreen') then
                                if elements.value.sendScreen[0] then
                                sendScreenToTelegram()
                                end


                            elseif text:match('/test') then
                                sendTelegramNotification('[Внимание!]\nОтправленные ниже сообщение ТЕСТОВЫЕ')
                            end


                        end
                    end
                end
            end
        end
    end
end

function getLastUpdate()
    local token = ffi.string(elements.buffer.token)
    local chat_id = ffi.string(elements.buffer.chat_id)

    async_http_request(
        'https://api.telegram.org/bot' .. token ..
        '/getUpdates?chat_id=' .. chat_id .. '&offset=-1',
        '',
        function(result)
            if result then
                local proc_table = decodeJson(result)
                if proc_table.ok then
                    if #proc_table.result > 0 then
                        local res_table = proc_table.result[1]
                        if res_table then
                            updateid = res_table.update_id
                        end
                    else
                        updateid = 1
                    end
                end
            end
        end
    )
end

function sendScreenToTelegram()
    if not elements.value.activeBot[0] then return end
    if elements.value.sendScreen[0] then
        local token = ffi.string(elements.buffer.token)
        local chat_id = ffi.string(elements.buffer.chat_id)

        local path = getWorkingDirectory()..'/screen.jpg'
        callFunction(0x5D0820, 2, 0, readMemory(0xC97C28, 4, false), path)
        wait(10)

        local f = io.open(path, "rb")
        if not f then
            sampAddChatMessage('[Telegram] Ошибка: файл screen.jpg не найден', -1)
            return
        end

        local data = f:read("*all")
        f:close()

        local boundary = "----LuaBoundary"..math.random(100000,999999)
        local body = ""

        body = body.."--"..boundary.."\r\n"
        body = body.."Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n"
        body = body..chat_id.."\r\n"

        body = body.."--"..boundary.."\r\n"
        body = body.."Content-Disposition: form-data; name=\"document\"; filename=\"screen.jpg\"\r\n"
        body = body.."Content-Type: application/octet-stream\r\n\r\n"
        body = body..data.."\r\n"

        body = body.."--"..boundary.."--\r\n"

        local https = require("ssl.https")
        local resp = {}

        local headers = {
            ["Content-Type"] = "multipart/form-data; boundary="..boundary,
            ["Content-Length"] = tostring(#body)
        }

        local ok, code = https.request{
            url = "https://api.telegram.org/bot"..token.."/sendDocument",
            method = "POST",
            headers = headers,
            source = ltn12.source.string(body),
            sink = ltn12.sink.table(resp)
        }

        if ok and code == 200 then
            sampAddChatMessage('[Telegram-Bot]: скриншот отправлен', 0x88AA62)
        else
            sampAddChatMessage('[Telegram-Bot]: ошибка отправки ('..tostring(code)..')', 0xFF4444)
        end
    end
end


function getConnectMessage()

    local time = os.date("%H:%M:%S")
    local date = os.date("%d-%m-%Y")

    local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local myName = sampGetPlayerNickname(myId)

    local t = {
        'Дата: ['..date..'] ['..time..']',
        'Никнейм: ['..myName..']',
        'Аккаунт подключен к серверу',
        'Ожидание авторизации',
    }
    return table.concat(t, "\n")
end

function getConnectedMessage()

    local time = os.date("%H:%M:%S")
    local date = os.date("%d-%m-%Y")

    local server = sampGetCurrentServerName()

    local t = {
        'Дата: ['..date..'] ['..time..']',
        'Сервер: ['..server..']',
        'Аккаунт успешно авторизован',
    }
    return table.concat(t, "\n")
end

function isLocalPlayerConnected()
    if not isSampAvailable() then return false end
    if not sampIsLocalPlayerSpawned() then return false end
    return true
end

function sampev.onServerMessage(color, text)
    if not elements.value.activeBot[0] then return end
    -- if not elements.value.activeBot[0] or elements.value.sendStorage[0] or elements.value.sendPayDay[0] or elements.value.sendConnect[0] or elements.value.sendSatiety[0] then return end
    if elements.value.sendPayDay[0] then
        if text:find("Банковский чек") then
            isCollectingCheck = true
            checkLines = {}
            return
        end

        if isCollectingCheck then
            if text:find("^_+$") then
                isCollectingCheck = false
                local final = {"PayDay"}

                for _, line in ipairs(checkLines) do
                    if  line:find("Текущая сумма в банке") or
                        line:find("В данный момент у вас") or
                        line:find("Текущая сумма на депозите") or
                        line:find("Общая заработная плата") or
                        line:find("Баланс на донат%-счет") then
                    table.insert(final, line)
                    end
                end
                sendTelegramNotification(table.concat(final, "\n"))
                return
            end
            if not text:find("^_+$") then
                table.insert(checkLines, text)
            end
        end
    end

    if elements.value.sendConnect[0] then
        if text:find('Добро пожаловать на Arizona Role Play!') then
            local msg = getConnectMessage()
            sendTelegramNotification(msg)
        end
        if text:find('.*На сервере есть инвентарь, используйте клавишу Y для работы с ним') then
            local msg = getConnectedMessage()
            sendTelegramNotification(msg)
        end
        if text:find('Сервер закрыл соединение. Переподключение: /reconnect или /rec') then
            sendTelegramNotification('Сервер закрыл соединение')
        end
    end
    if elements.value.sendInventory[0] then
        if text:find('Вам был добавлен предмет') or
        text:find('Вам удалось улучшить предмет') then
            sendTelegramNotification(text)
        end
    end
    if elements.value.sendStorage[0] then
        if text:find('%[Хранилище предметов%]') then
            sendTelegramNotification(text)
        end
    end
    if elements.value.sendSatiety[0] then 
        if text:find('Ваш уровень сытости ниже 20') then
            sendTelegramNotification('Ваш уровень сытости ниже 20%\nИспользуйте /jmeat для повышения сытости')
        end
    end
    -- if elements.value.autoEat[0] then
        -- if text:find('Ваш уровень сытости ниже 20') then
        --     lua_thread.create(function()
        --         sampSendChat('/eat')
        --         wait(500)
        --         sampCloseCurrentDialogWithButton(1)
        --     end)
        -- end
        -- if text:find('Ваш уровень сытости ниже 20') then
        --     sampSendChat('/eat')
        -- end
        -- if text:find('У вас нет чипсов') then
        --     sendTelegramNotification('Уровень сытости упал к 20%. Чипсы отсутствуют. Авто-еда отключена.')
        --     elements.value.autoEat[0] = false
        -- end
    -- end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if not elements.value.activeBot[0] then return end
     if elements.value.autoEat[0] then
        if title:find('Кушать') then
            lua_thread.create(function ()
                -- sampCloseCurrentDialogWithButton(1)
                wait(500)
            end)
            return false
        end
     end
    if title:find('Статистика') then
        local shouldSend = false
        local keywords = {}

        if sendToTelegram then
            shouldSend = true
            keywords = {
                "Спортивное состояние","Сила", "Выносливость", "Мускулатура", "Энергия"
            }
            sendToTelegram = false
        end

        if shouldSend then
            local lines = {}
            for line in text:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end

            local filteredText = ""
            for _, line in ipairs(lines) do
                for _, kw in ipairs(keywords) do
                    if line:find(kw) then
                        filteredText = filteredText .. line .. "\n"
                        break
                    end
                end
            end

            sendTelegramNotification(filteredText)
            return false
        end

        return true
    end
    if title:find('Основная статистика') then
        local shouldSend = false
        local keywords = {}

        if sendToTelegram then
            shouldSend = true
            keywords = {
                "Имя", "Уровень", "Уважение", "Текущее состояние счета",
                "Наличные деньги", "Деньги в банке", "Деньги на депозите",
                "Евро", "BTC", "Организация", "Должность",
                "Уровень розыска", "Предупреждения"
            }
            sendToTelegram = false

        elseif sendToTelegramc then
            shouldSend = true
            keywords = {
                'Защита', 'Регенерация', 'Урон', 'Макс',
                'Шанс', 'Отражение', 'Блокировка',
                'Скорострельность', 'Отдача'
            }
            sendToTelegramc = false
        end

        if shouldSend then
            local lines = {}
            for line in text:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end

            local filteredText = ""
            for _, line in ipairs(lines) do
                for _, kw in ipairs(keywords) do
                    if line:find(kw) then
                        filteredText = filteredText .. line .. "\n"
                        break
                    end
                end
            end

            sendTelegramNotification(filteredText)
            return false
        end

        return true
    end
end

imgui.OnFrame(function() return window[0] end, function(player)
    local resX, resY = getScreenResolution()
    local sizeX, sizeY = 450, 340
    imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
    if imgui.Begin('Telegram-Bot', window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollWithMouse) then
        local menuPos = imgui.GetWindowPos()
        local menuSize = imgui.GetWindowSize()
        imgui.CenterText(u8'Telegram-Bot')
        imgui.Separator()
        imgui.BeginChild('##3', imgui.ImVec2(435, 300), 0)
        if imgui.InputText(u8'token', elements.buffer.token, 128, imgui.InputTextFlags.Password) then
            config['settings']['token'] = str(elements.buffer.token)
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8'Обновить скрипт') then update():download() end
        if imgui.InputText(u8'chat_id', elements.buffer.chat_id, 128, imgui.InputTextFlags.Password) then
            config['settings']['chat_id'] = str(elements.buffer.chat_id)
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8'Сохранить') then
            saveConfig()
        end
        imgui.Separator()
        if imgui.Checkbox(u8'Включить бота', elements.value.activeBot) then
            config['settings']['activeBot'] = elements.value.activeBot[0]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Checkbox(u8'Auto-reconnect', elements.value.autoReconnect) then -- pizzzda
            -- config['settings']['autoReconnect'] = elements.value.autoReconnect[0]
            elements.value.autoReconnect[0] = false
            sampAddChatMessage('[Telegram-Bot]: {ffffff}недоступно на данный момент', 0xFF6600)
        end
        if elements.value.autoReconnect[0] then imgui.SameLine() if imgui.Button(u8'Настройки авто-реконекта') then windowReconnect[0] = not windowReconnect[0] end end
        if imgui.CollapsingHeader(u8'Команды скрипта') then 
                for i=1, #scommands do
                    imgui.TextWrapped(u8(scommands[i][1] .. " — " .. scommands[i][2]))
                end
            imgui.Separator()
        end
        imgui.BeginChild('##1', imgui.ImVec2(220, 160), 0)
        if imgui.Checkbox(u8'/stats', elements.value.sendStats) then
            config['settings']['sendStats'] = elements.value.sendStats[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'/connect', elements.value.connect) then
            config['settings']['connect'] = elements.value.connect[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'/disconnect', elements.value.disconnect) then
            config['settings']['disconnect'] = elements.value.disconnect[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'/reloadlua', elements.value.reloadlua) then
            config['settings']['reloadlua'] = elements.value.reloadlua[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'/reloadbot', elements.value.reloadbot) then
            config['settings']['reloadbot'] = elements.value.reloadbot[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'/sendscreen', elements.value.sendScreen) then
            config['settings']['sendScreen'] = elements.value.sendScreen[0]
            saveConfig()
        end
        imgui.EndChild()
        imgui.SameLine()
        imgui.BeginChild('##2', imgui.ImVec2(220, 160), 0)
        if imgui.Checkbox(u8'PayDay', elements.value.sendPayDay) then
            config['settings']['sendPayDay'] = elements.value.sendPayDay[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'ПВЗ', elements.value.sendStorage) then
            config['settings']['sendStorage'] = elements.value.sendStorage[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'Новый предмет', elements.value.sendInventory) then
            config['settings']['sendInventory'] = elements.value.sendInventory[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'Состояние голода', elements.value.sendSatiety) then
            config['settings']['sendSatiety'] = elements.value.sendSatiety[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'Подключение/отключение', elements.value.sendConnect) then
            config['settings']['sendConnect'] = elements.value.sendConnect[0]
            saveConfig()
        end
        if imgui.Checkbox(u8'[Запрещённое ПО] Авто-еда', elements.value.autoEat) then
            config['settings']['autoEat'] = elements.value.autoEat[0]
            saveConfig()
        end
        imgui.EndChild()
        imgui.Separator()
        imgui.CenterText(string.format(u8'Автор: rvnmph. Версия: %s', thisScript().version))
        if windowReconnect[0] then
			local farX, farY = 450, 300
			imgui.SetNextWindowPos(imgui.ImVec2(menuPos.x + menuSize.x + 5, menuPos.y), imgui.Cond.Always)
			imgui.SetNextWindowSize(imgui.ImVec2(farX, farY), imgui.Cond.Always)
			imgui.Begin(u8'Настройки авто-реконекта', windowReconnect, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)
            imgui.CenterText(u8'Авто-реконект')
            imgui.Separator()
            imgui.PushItemWidth(100)
            if imgui.InputText(u8'Максимальная задержка', elements.buffer.recMaxDelay, 16) then
                config['settings']['recMaxDelay'] = str(elements.buffer.recMaxDelay)
                saveConfig()
            end
            imgui.PopItemWidth()
            imgui.End()
        end
        imgui.EndChild()
        imgui.End()
    end
end)

function main() 
    while not isSampAvailable() do
        wait(0)
    end
    
    for _, line in ipairs(hiText) do
        sampAddChatMessage(line, 0xFF6600)
    end

    getLastUpdate()

    local lastver = update():getLastVersion()
    if thisScript().version ~= lastver then
        sampAddChatMessage(string.format('[Telegram-Bot]: {ffffff}Дуступно новое обновление: [%s]', lastver), 0xff6600)
        sendTelegramNotification(string.format('Бот успешно загружен.\nДоступно новое обновление: %s', thisScript().version))
    else
        sampAddChatMessage(string.format('[Telegram-Bot]: {ffffff}Версия скрипта актуальная: [%s]', lastver), 0xff6600)
        sendTelegramNotification(string.format('Бот успешно загружен.\nВерсия скрипта актуальная: [%s]', thisScript().version))
    end

    sampRegisterChatCommand('tbot', function()
        window[0] = not window[0]
    end)
    sampRegisterChatCommand('tg.stats', function() statsButton() 
    sampAddChatMessage('[Telegram-Bot]: статисткиа отправлена', 0x88AA62)
    end)
    sampRegisterChatCommand('tg.reload', function() thisScript():reload() end)
    sampRegisterChatCommand('tg',function()
        sampAddChatMessage('Отправлено тестовое сообщение боту', -1)
        sendTelegramNotification('[Внимание!]\nОтправленные ниже сообщение ТЕСТОВЫЕ')
    end)
    lua_thread.create(get_telegram_updates)
    while true do
        wait(0)
        if isKeyJustPressed(vkey.VK_F9) and elements.value.activeBot[0] then
            sendScreenToTelegram()
        end
        if elements.value.autoEat[0] then
            sampAddChatMessage('динах нельзя такое юзать окак', -1)
        end
    end
end

function onWindowMessage(msg, wparam, lparam)
    if msg == 0x100 or msg == 0x101 then
        if (wparam == keys.VK_ESCAPE and window[0]) and not isPauseMenuActive() then
            consumeWindowMessage(true, false)
            if msg == 0x101 then
                window[0] = false
            end
        end
    end
end

function imgui.CenterText(text)
	imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
	imgui.Text(text)
end

function styleScript()
    local style = imgui.GetStyle()
    local colors = style.Colors

    style.Alpha = 1;
    style.WindowPadding = imgui.ImVec2(8.00, 8.00);
    style.WindowRounding = 0;
    style.WindowBorderSize = 0;
    style.WindowMinSize = imgui.ImVec2(32.00, 32.00);
    style.WindowTitleAlign = imgui.ImVec2(0.50, 0.50);
    style.ChildRounding = 0;
    style.ChildBorderSize = 1;
    style.PopupRounding = 0;
    style.PopupBorderSize = 1;
    style.FramePadding = imgui.ImVec2(4.00, 3.00);
    style.FrameRounding = 0;
    style.FrameBorderSize = 0;
    style.ItemSpacing = imgui.ImVec2(8.00, 4.00);
    style.ItemInnerSpacing = imgui.ImVec2(4.00, 4.00);
    style.IndentSpacing = 21;
    style.ScrollbarSize = 14;
    style.ScrollbarRounding = 9;
    style.GrabMinSize = 10;
    style.GrabRounding = 0;
    style.TabRounding = 4;
    style.ButtonTextAlign = imgui.ImVec2(0.50, 0.50);
    style.SelectableTextAlign = imgui.ImVec2(0.00, 0.00);
			

    style.Colors[imgui.Col.Text]                   = imgui.ImVec4(0.90, 0.90, 0.80, 1.00)
    style.Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.60, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    style.Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    style.Colors[imgui.Col.Border]                 = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    style.Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    style.Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
    style.Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    style.Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    style.Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
    style.Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    style.Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.40, 0.40, 0.40, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.CheckMark]              = imgui.ImVec4(0.66, 0.66, 0.66, 1.00)
    style.Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.66, 0.66, 0.66, 1.00)
    style.Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.70, 0.70, 0.73, 1.00)
    style.Colors[imgui.Col.Button]                 = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.40, 0.40, 0.40, 1.00)
    style.Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.Header]                 = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    style.Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    style.Colors[imgui.Col.Separator]              = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.40, 0.40, 0.40, 1.00)
    style.Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(0.40, 0.40, 0.40, 1.00)
    style.Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.70, 0.70, 0.73, 1.00)
    style.Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(0.95, 0.95, 0.70, 1.00)
    style.Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.70, 0.70, 0.73, 1.00)
    style.Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(0.95, 0.95, 0.70, 1.00)
    style.Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(0.25, 0.25, 0.15, 1.00)
    style.Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.10, 0.10, 0.10, 0.80)
    style.Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    style.Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
end
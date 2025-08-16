local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Lib = {}

local _token = nil
local _allowed = {}
local _pollInterval = 2
local _apiBase = nil
local _running = false
local _thread = nil
local _onCommand = nil -- function(chat_id, from_id, text) -> boolean handled, optional response
local function safeJsonDecode(s)
    local ok, res = pcall(function() return HttpService:JSONDecode(s) end)
    if ok then return res end
    return nil
end

local function isAllowed(id)
    if type(id) ~= "number" then return false end
    for _, v in ipairs(_allowed) do
        if v == id then return true end
    end
    return false
end

local function sendMessageSync(chat_id, text)
    if not _token then
        warn("Telegram token not set — cannot send message")
        return false
    end
    local payload = {
        chat_id = chat_id,
        text = tostring(text or ""),
        parse_mode = "HTML"
    }
    local ok, err = pcall(function()
        HttpService:PostAsync(_apiBase .. "/sendMessage", HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
    end)
    if not ok then
        warn("Telegram sendMessage failed:", err)
    end
    return ok
end

local function broadcastInGame(msg)
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = tostring(msg or ""),
            Color = Color3.fromRGB(255, 170, 0),
            Font = Enum.Font.SourceSansBold,
            FontSize = Enum.FontSize.Size24
        })
    end)
end

local function listPlayers()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        t[#t+1] = p.Name
    end
    return table.concat(t, ", ")
end

local function handleUpdate(update)
    if not update or not update.message then return end
    local msg = update.message
    local from = msg.from
    if not from then return end
    local from_id = from.id
    local chat_id = msg.chat and msg.chat.id
    local text = msg.text or msg.caption or ""

    if not chat_id then return end

    if not isAllowed(from_id) then
        sendMessageSync(chat_id, "⛔ You don't have access to this bot")
        return
    end

    if _onCommand then
        local ok, handled, response = pcall(function()
            return _onCommand(chat_id, from_id, tostring(text))
        end)
        if ok then
            if handled then
                if response then sendMessageSync(chat_id, response) end
                return
            end
        else
            warn("onCommand handler error:", handled)
        end
    end

    if tostring(text):match("^/say%s+") then
        local msgtext = tostring(text):sub(6)
        broadcastInGame(msgtext)
        sendMessageSync(chat_id, "✅ Sent to local chat: " .. msgtext)
        return
    end

    if tostring(text) == "/players" then
        local players = listPlayers()
        sendMessageSync(chat_id, "Players online: " .. (players ~= "" and players or "(none)"))
        return
    end

    sendMessageSync(chat_id, "Unknown command. Available: /say <text>, /players")
end

local function pollingLoop()
    local offset = 0
    while _running do
        if not _token then
            wait(_pollInterval)
            goto continue
        end

        local ok, body = pcall(function()
            return HttpService:GetAsync(_apiBase .. "/getUpdates?offset=" .. tostring(offset) .. "&timeout=0")
        end)

        if ok and body then
            local data = safeJsonDecode(body)
            if data and data.result and type(data.result) == "table" then
                for _, upd in ipairs(data.result) do
                    spawn(function()
                        pcall(handleUpdate, upd)
                    end)
                    offset = math.max(offset, (upd.update_id or 0) + 1)
                end
            end
        else
        end

        ::continue::
        wait(_pollInterval)
    end
end

function Lib.setToken(t)
    if not t or t == "" then
        _token = nil
        _apiBase = nil
        return
    end
    _token = tostring(t)
    _apiBase = "https://api.telegram.org/bot" .. _token
end

function Lib.getToken()
    return _token
end

function Lib.setAllowed(tbl)
    if type(tbl) ~= "table" then return end
    _allowed = tbl
end

function Lib.getAllowed()
    return _allowed
end

function Lib.setPollInterval(sec)
    _pollInterval = tonumber(sec) or 2
end

function Lib.onCommand(fn)
    if type(fn) ~= "function" then return end
    _onCommand = fn
end

function Lib.sendMessage(chat_id, text)
    return sendMessageSync(chat_id, text)
end

function Lib.start()
    if _running then return true end
    _running = true
    _thread = spawn(pollingLoop)
    return true
end

function Lib.stop()
    _running = false
    return true
end

function Lib.isRunning()
    return _running
end

function Lib.setCompkillerAutoLoad(enabled)
    _compkillerAutoLoad = not not enabled
end

function Lib.sayToChat(text)
    broadcastInGame(text)
end

return Lib

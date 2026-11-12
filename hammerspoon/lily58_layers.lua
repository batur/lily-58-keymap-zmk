-- Lily58 layer overlay for Hammerspoon.
--
-- The keyboard holds F16 (LOWER), F17 (RAISE) or F18 (MOUSE) while a layer key
-- is down (see config/lily58.keymap). This script swallows those keys and shows
-- the active layer's map on screen until the key is released.
--
-- The label tables below mirror config/lily58.keymap; update both together.

local M = {}

-- Seconds a layer key must be held before the overlay appears, so that quick
-- symbol presses do not flash it. Set to 0 to show immediately.
M.showDelay = 0.3

local KEY, GAP, PAD, TITLE_H = 52, 6, 16, 30
local UNIT = KEY + GAP

local HELD = "\u{25CF}"

local layers = {
    lower = {
        title = "Semboller",
        keys = {
            "`", "!", "@", "#", "$", "%",            "^", "&", "*", "(", ")", "~",
            "~", "|", "\\", "{", "}", "&",           "*", "7", "8", "9", "+", "-",
            "", "<", ">", "(", ")", "=",             "/", "4", "5", "6", "=", "'",
            "", "!", "_", "-", "+", "*", "",     "", "0", "1", "2", "3", ".", "",
            "", "", HELD, "",                        "", "", "Del", "",
        },
    },
    raise = {
        title = "Gezinme",
        keys = {
            "", "", "", "", "", "",                  "", "", "", "", "", "",
            "", "⌃←", "↑", "⌃→", "PgUp", "Üst ½",    "", "⏮", "⏯", "⏭", "", "",
            "", "←", "↓", "→", "PgDn", "Alt ½",      "", "Mute", "Vol−", "Vol+", "", "",
            "", "Sol ½", "Büyüt", "Sağ ½", "Ortala", "Geri al", "Ekran→",   "", "", "Bri−", "Bri+", "", "", "",
            "", "", "", "Raycast",                   "", HELD, "", "",
        },
    },
    adjust = {
        title = "Ayarlar",
        keys = {
            "F1", "F2", "F3", "F4", "F5", "F6",      "F7", "F8", "F9", "F10", "F11", "F12",
            "BT sil", "BT 0", "BT 1", "BT 2", "BT 3", "BT 4",   "", "", "", "", "", "",
            "Tümü sil", "USB/BT", "", "", "", "",    "", "", "", "", "", "",
            "Boot", "Reset", "", "", "", "", "", "", "", "", "", "", "Reset", "Boot",
            "", "", HELD, "",                        "", HELD, "", "",
        },
    },
    mouse = {
        title = "Fare",
        keys = {
            "", "", "", "", "", "",                  "", "", "", "", "", "",
            "", "", "▲", "", "", "",                 "", "Kay ↑", "", "", "", "",
            "", "◀", "▼", "▶", "", "",               "Kay ←", "Kay ↓", "Kay →", "", "", "",
            "", "", "", "", "", "", "",          "", "", "", "", "", "", "",
            "", "", "", "Sol",                       "Sağ", "", "", HELD,
        },
    },
}

-- Grid position (column, row) of each of the 58 keys, in keymap order.
local function keyPositions()
    local p = {}
    for row = 0, 2 do
        for col = 0, 5 do p[#p + 1] = { col, row } end
        for col = 8, 13 do p[#p + 1] = { col + 0.5, row } end
    end
    for col = 0, 6 do p[#p + 1] = { col, 3 } end
    for col = 7, 13 do p[#p + 1] = { col + 0.5, 3 } end
    for col = 3, 6 do p[#p + 1] = { col, 4 } end
    for col = 7, 10 do p[#p + 1] = { col + 0.5, 4 } end
    return p
end

local WIDTH = 14.5 * UNIT - GAP + 2 * PAD
local HEIGHT = TITLE_H + 5 * UNIT - GAP + 2 * PAD

local function buildCanvas(layer)
    local canvas = hs.canvas.new({ x = 0, y = 0, w = WIDTH, h = HEIGHT })
    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:behavior({ "canJoinAllSpaces", "stationary" })
    canvas:clickActivating(false)

    local elements = {
        {
            type = "rectangle",
            action = "fill",
            roundedRectRadii = { xRadius = 14, yRadius = 14 },
            fillColor = { white = 0.07, alpha = 0.9 },
        },
        {
            type = "text",
            text = layer.title,
            textSize = 15,
            textColor = { white = 1, alpha = 0.85 },
            frame = { x = PAD, y = PAD - 4, w = WIDTH - 2 * PAD, h = TITLE_H },
        },
    }

    for i, pos in ipairs(keyPositions()) do
        local label = layer.keys[i]
        local x = PAD + pos[1] * UNIT
        local y = PAD + TITLE_H + pos[2] * UNIT
        local held = label == HELD
        local empty = label == ""

        elements[#elements + 1] = {
            type = "rectangle",
            action = "fill",
            roundedRectRadii = { xRadius = 7, yRadius = 7 },
            fillColor = held and { red = 0.25, green = 0.55, blue = 1, alpha = 0.9 }
                or { white = 1, alpha = empty and 0.05 or 0.16 },
            frame = { x = x, y = y, w = KEY, h = KEY },
        }

        if not empty then
            local chars = utf8.len(label)
            local size = chars > 6 and 10 or (chars > 2 and 12 or 17)
            elements[#elements + 1] = {
                type = "text",
                text = label,
                textSize = size,
                textAlignment = "center",
                textColor = { white = 1, alpha = 0.95 },
                frame = { x = x, y = y + (KEY - size * 1.35) / 2, w = KEY, h = size * 1.5 },
            }
        end
    end

    canvas:replaceElements(elements)
    return canvas
end

local canvases = {}
for name, layer in pairs(layers) do
    assert(#layer.keys == 58, name .. " layer must have 58 labels, has " .. #layer.keys)
    canvases[name] = buildCanvas(layer)
end

local held = { lower = false, raise = false, mouse = false }
local shown = nil
local pending = nil

local function activeLayer()
    if held.mouse then return "mouse" end
    if held.lower and held.raise then return "adjust" end
    if held.lower then return "lower" end
    if held.raise then return "raise" end
    return nil
end

local function show(name)
    local screen = hs.screen.mainScreen():frame()
    canvases[name]:topLeft({
        x = screen.x + (screen.w - WIDTH) / 2,
        y = screen.y + screen.h - HEIGHT - 40,
    })
    canvases[name]:show()
    shown = name
end

local function hide()
    if shown then canvases[shown]:hide() end
    shown = nil
end

local function refresh()
    local want = activeLayer()
    if pending then
        pending:stop()
        pending = nil
    end
    if want == shown then return end
    if want == nil then
        hide()
    elseif shown or M.showDelay <= 0 then
        -- Already visible (switching layers) or no delay configured: swap now.
        hide()
        show(want)
    else
        pending = hs.timer.doAfter(M.showDelay, function()
            pending = nil
            if activeLayer() == want then show(want) end
        end)
    end
end

local signals = {
    [hs.keycodes.map.f16] = "lower",
    [hs.keycodes.map.f17] = "raise",
    [hs.keycodes.map.f18] = "mouse",
}

local types = hs.eventtap.event.types

-- Automatic input source: ABC while typing on the Lily58, Turkish on any other
-- keyboard (the MacBook's own). macOS tags every key event with the type of the
-- keyboard it came from. The Lily58's type is learned from its layer signal keys,
-- which no other keyboard sends, and remembered across reloads.
local function findLayout(patterns)
    for _, pattern in ipairs(patterns) do
        for _, layout in ipairs(hs.keycodes.layouts()) do
            if layout:find(pattern) then return layout end
        end
    end
    return nil
end

local lilyLayout = findLayout({ "^ABC$", "^U%.S%.$", "^ABC", "English" })
local otherLayout = findLayout({ "Turkish", "Türk", "Turk" })
local keyboardTypeProperty = hs.eventtap.event.properties.keyboardEventKeyboardType
local lilyKeyboardType = hs.settings.get("lily58.keyboardType")
local lastWasLily = nil

if not (lilyLayout and otherLayout) then
    print("lily58: automatic layout switching is off; need both an ABC and a Turkish input source")
end

local function trackKeyboard(event, isSignal)
    if not (lilyLayout and otherLayout) then return end
    local keyboardType = event:getProperty(keyboardTypeProperty)
    if isSignal and keyboardType ~= lilyKeyboardType then
        lilyKeyboardType = keyboardType
        hs.settings.set("lily58.keyboardType", keyboardType)
    end
    if lilyKeyboardType == nil then return end
    local isLily = keyboardType == lilyKeyboardType
    if isLily ~= lastWasLily then
        lastWasLily = isLily
        local wanted = isLily and lilyLayout or otherLayout
        if hs.keycodes.currentLayout() ~= wanted then hs.keycodes.setLayout(wanted) end
    end
end

M.tap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(event)
    local name = signals[event:getKeyCode()]
    if event:getType() == types.keyDown then trackKeyboard(event, name ~= nil) end
    if not name then return false end
    local down = event:getType() == types.keyDown
    if held[name] ~= down then
        held[name] = down
        refresh()
    end
    return true
end)
M.tap:start()

-- Battery levels, written every 15 minutes by the LaunchAgent that
-- battery/install.sh sets up. First value is the left half, second the right.
local batteryPath = os.getenv("HOME") .. "/.cache/lily58-battery.json"
local batteryMaxAge = 3600

-- Notify once when a half drops below batteryLow; re-arm after it has been
-- charged back above batteryRearm.
M.batteryLow = 20
M.batteryRearm = 30
local halfNames = { "Sol", "Sağ" }
local lowNotified = {}

local function checkLowBattery(levels)
    for i, level in ipairs(levels) do
        if level < M.batteryLow and not lowNotified[i] then
            lowNotified[i] = true
            hs.notify.new({
                title = "Lily58 pili azaldı",
                informativeText = (halfNames[i] or "?") .. " yarı %" .. level .. " — şarja tak.",
                withdrawAfter = 0,
            }):send()
        elseif level >= M.batteryRearm then
            lowNotified[i] = false
        end
    end
end

local function batteryLevels()
    if not hs.fs.attributes(batteryPath) then return nil end
    local data = hs.json.read(batteryPath)
    if type(data) ~= "table" or type(data.levels) ~= "table" or #data.levels == 0 then return nil end
    if os.time() - (data.time or 0) > batteryMaxAge then return nil end
    return data.levels
end

-- Small keyboard glyph for the menu bar, drawn as a template image so macOS
-- tints it for light and dark menu bars.
local function keyboardIcon()
    local ink = { white = 0, alpha = 1 }
    local elements = {
        {
            type = "rectangle",
            action = "stroke",
            strokeWidth = 1.3,
            strokeColor = ink,
            roundedRectRadii = { xRadius = 3, yRadius = 3 },
            frame = { x = 1, y = 2, w = 20, h = 12 },
        },
        { type = "rectangle", action = "fill", fillColor = ink, frame = { x = 7, y = 10.5, w = 8, h = 1.5 } },
    }
    for row = 0, 1 do
        for col = 0, 4 do
            elements[#elements + 1] = {
                type = "rectangle",
                action = "fill",
                fillColor = ink,
                frame = { x = 4 + col * 3, y = 4.5 + row * 3, w = 2, h = 2 },
            }
        end
    end
    local canvas = hs.canvas.new({ x = 0, y = 0, w = 22, h = 16 })
    canvas:replaceElements(elements)
    local image = canvas:imageFromCanvas()
    canvas:delete()
    return image
end

M.menu = hs.menubar.new()
if M.menu then M.menu:setIcon(keyboardIcon(), true) end

local function updateBattery()
    local levels = batteryLevels()
    local short, long = "–", nil
    if levels then
        checkLowBattery(levels)
        local names = halfNames
        local shortParts, longParts = {}, {}
        for i, level in ipairs(levels) do
            shortParts[#shortParts + 1] = level .. "%"
            longParts[#longParts + 1] = (names[i] or "?") .. " %" .. level
        end
        short = table.concat(shortParts, " · ")
        long = table.concat(longParts, "   ")
    end
    if M.menu then
        M.menu:setTitle(" " .. short)
        M.menu:setTooltip(long and ("Lily58 pil: " .. long) or "Lily58 pil seviyesi bilinmiyor")
    end
    for name, canvas in pairs(canvases) do
        canvas[2].text = layers[name].title .. (long and ("        " .. long) or "")
    end
end

M.batteryTimer = hs.timer.doEvery(60, updateBattery)
updateBattery()

-- A key-up can be lost across sleep or a keyboard disconnect; start clean on wake.
M.wakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
        held = { lower = false, raise = false, mouse = false }
        refresh()
    end
end)
M.wakeWatcher:start()

return M

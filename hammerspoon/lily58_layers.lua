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
            "", "⏮", "⏯", "⏭", "", "",               "⌘←", "↑", "⌘→", "⌃←", "⌃→", "",
            "", "Mute", "Vol−", "Vol+", "", "",      "←", "↓", "→", "PgUp", "Del", "",
            "", "Bri−", "Bri+", "", "", "", "",  "", "⌥←", "⌥→", "", "PgDn", "", "",
            "", "", "", "",                          "", HELD, "", "",
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
            "", "Orta", "Sağ", "Sol",                "", "", "", HELD,
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

M.tap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(event)
    local name = signals[event:getKeyCode()]
    if not name then return false end
    local down = event:getType() == types.keyDown
    if held[name] ~= down then
        held[name] = down
        refresh()
    end
    return true
end)
M.tap:start()

-- A key-up can be lost across sleep or a keyboard disconnect; start clean on wake.
M.wakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
        held = { lower = false, raise = false, mouse = false }
        refresh()
    end
end)
M.wakeWatcher:start()

return M

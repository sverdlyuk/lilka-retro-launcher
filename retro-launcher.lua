-- ============================================================================
--  retro-launcher.lua — лаунчер емуляторів для Лілки (один файл)
--
--  Малює меню у стилі menu.lua (вбудований нижче), а запускає гру так:
--    1) пише /sd/retro-go/config/boot.json (BootName = ядро, BootArgs = ROM);
--    2) викликає util.multiboot(bin, "rg <rom>").
--  retro-core/gwenesis/snes9x/... читають boot.json і стартують потрібне ядро.
-- ============================================================================

-- ============================================================================
--  Вбудований UI (колишній menu.lua)
-- ============================================================================
local menu = {}

menu.PAD_X = 14
menu.PAD_Y = 14

local FONT_BIG = "10x20"
local FONT_SMALL = "6x13"
local CHAR_BIG = 10
local CHAR_SMALL = 6
local ROW_H = 24

local BLACK = display.color565(0, 0, 0)
local WHITE = display.color565(255, 255, 255)
local GRAY = display.color565(130, 130, 130)
local CYAN = display.color565(0, 220, 220)
local DIM = display.color565(120, 120, 130)
local DIM_RIGHT = display.color565(80, 80, 90)
local OK = display.color565(45, 210, 130)
local LINE = display.color565(60, 60, 60)

-- Колір закріплений за літерою, а не за місцем у ряду.
local KEY_COLORS = {
    A = display.color565(45, 210, 130),
    B = display.color565(255, 95, 95),
    C = display.color565(255, 193, 40),
    D = display.color565(90, 165, 255),
}

menu.rows = 6

-- Довжина рядка в символах (українські літери — 2 байти).
local function text_width(text, char_w)
    return (utf8.len(text) or #text) * char_w
end

function menu.init()
    menu.rows = math.floor((display.height - 86) / ROW_H)
    if menu.rows < 3 then menu.rows = 3 end
end

function menu.new_list()
    return {cursor = 1, scroll = 0}
end

function menu.move(list, count, step)
    if count == 0 then return end

    list.cursor = list.cursor + step
    if list.cursor < 1 then list.cursor = count end
    if list.cursor > count then list.cursor = 1 end

    if list.cursor - 1 < list.scroll then
        list.scroll = list.cursor - 1
    elseif list.cursor > list.scroll + menu.rows then
        list.scroll = list.cursor - menu.rows
    end
end

-- items — масив {label = "текст", right = "значення"}
function menu.draw_list(title, hint, items, list, highlight)
    display.fill_screen(BLACK)

    display.set_font(FONT_BIG)
    display.set_text_color(CYAN)
    display.set_cursor(menu.PAD_X, 26)
    display.print(title)

    if hint then
        display.set_font(FONT_SMALL)
        display.set_text_color(GRAY)
        display.set_cursor(display.width - menu.PAD_X - text_width(hint, CHAR_SMALL), 24)
        display.print(hint)
    end

    display.draw_line(menu.PAD_X - 4, 36, display.width - menu.PAD_X + 4, 36, LINE)

    if #items == 0 then
        display.set_font(FONT_SMALL)
        display.set_text_color(GRAY)
        display.set_cursor(menu.PAD_X, 70)
        display.print("Порожньо.")
    end

    for i = 1, menu.rows do
        local item = items[list.scroll + i]
        if item then
            local y = 36 + i * ROW_H
            local selected = (list.scroll + i == list.cursor)

            if selected then
                display.fill_rect(
                    menu.PAD_X - 10, y - 15, 4, ROW_H - 8,
                    highlight and OK or CYAN
                )
                display.set_text_color(WHITE)
            else
                display.set_text_color(DIM)
            end

            display.set_font(FONT_BIG)
            display.set_cursor(menu.PAD_X, y)
            display.print(item.label)

            if item.right then
                display.set_font(FONT_SMALL)
                display.set_text_color(selected and WHITE or DIM_RIGHT)
                display.set_cursor(
                    display.width - menu.PAD_X - text_width(item.right, CHAR_SMALL),
                    y - 2
                )
                display.print(item.right)
            end
        end
    end
end

-- buttons — масив {key = "A", label = "Надіслати"}
function menu.draw_footer(buttons)
    local R = 11
    local GAP = 12
    local KEY_GAP = 5
    local CHAR = 9
    local FONT = "9x15"

    local total = 0
    for i, b in ipairs(buttons) do
        total = total + R * 2 + KEY_GAP + text_width(b.label, CHAR)
        if i < #buttons then total = total + GAP end
    end

    local x = (display.width - total) // 2
    local y = display.height - menu.PAD_Y - R

    display.set_font(FONT)

    for _, b in ipairs(buttons) do
        display.fill_circle(x + R, y, R, KEY_COLORS[b.key] or GRAY)

        display.set_text_color(BLACK)
        display.set_cursor(x + R - CHAR // 2, y + 5)
        display.print(b.key)

        display.set_text_color(WHITE)
        display.set_cursor(x + R * 2 + KEY_GAP, y + 5)
        display.print(b.label)

        x = x + R * 2 + KEY_GAP + text_width(b.label, CHAR) + GAP
    end
end

-- Екран повідомлення у тому ж стилі.
function menu.message(title, lines, footer)
    display.fill_screen(BLACK)

    display.set_font(FONT_BIG)
    display.set_text_color(CYAN)
    display.set_cursor(menu.PAD_X, 26)
    display.print(title)

    display.set_font(FONT_SMALL)
    display.set_text_color(GRAY)
    for i, line in ipairs(lines or {}) do
        display.set_cursor(menu.PAD_X, 56 + (i - 1) * 18)
        display.print(line)
    end

    if footer then menu.draw_footer(footer) end
    display.queue_draw()
end

-- ============================================================================
--  Лаунчер
-- ============================================================================

local BIN_BASE = "https://raw.githubusercontent.com/sverdlyuk/retro-go/lilka-dev/keira-bin"
local BOOT_JSON = "/sd/retro-go/config/boot.json"

-- ns — це configNs для retro-go (яке ядро запускати).
local PLATFORMS = {
    {name = "NES",              ns = "nes",      dir = "/sd/roms/nes",    exts = {"nes"},
     bin = "/sd/apps/retro-core.bin", url = BIN_BASE .. "/retro-core.bin"},
    {name = "PC Engine",        ns = "pce",      dir = "/sd/roms/pce",    exts = {"pce"},
     bin = "/sd/apps/retro-core.bin", url = BIN_BASE .. "/retro-core.bin"},
    {name = "Game Boy / Color", ns = "gbc",      dir = "/sd/roms/gb",     exts = {"gb", "gbc"},
     bin = "/sd/apps/retro-core.bin", url = BIN_BASE .. "/retro-core.bin"},
    {name = "Master System",    ns = "sms",      dir = "/sd/roms/sms",    exts = {"sms"},
     bin = "/sd/apps/retro-core.bin", url = BIN_BASE .. "/retro-core.bin"},
    {name = "Game Gear",        ns = "gg",       dir = "/sd/roms/gg",     exts = {"gg"},
     bin = "/sd/apps/retro-core.bin", url = BIN_BASE .. "/retro-core.bin"},
    {name = "ColecoVision",     ns = "col",      dir = "/sd/roms/col",    exts = {"col"},
     bin = "/sd/apps/retro-core.bin", url = BIN_BASE .. "/retro-core.bin"},
    {name = "Atari Lynx",       ns = "lnx",      dir = "/sd/roms/lnx",    exts = {"lnx"},
     bin = "/sd/apps/retro-core.bin", url = BIN_BASE .. "/retro-core.bin"},
    {name = "Mega Drive",       ns = "gwenesis", dir = "/sd/roms/md",     exts = {"gen", "md"},
     bin = "/sd/apps/gwenesis.bin",   url = BIN_BASE .. "/gwenesis.bin"},
    {name = "SNES",             ns = "snes9x",   dir = "/sd/roms/snes",   exts = {"smc", "sfc"},
     bin = "/sd/apps/snes9x.bin",     url = BIN_BASE .. "/snes9x.bin"},
    {name = "PICO-8",           ns = "pico8",    dir = "/sd/roms/pico8",  exts = {"p8", "png"},
     bin = "/sd/apps/pico8.bin",      url = BIN_BASE .. "/pico8.bin"},
    {name = "Commodore 64",     ns = "frodo",    dir = "/sd/roms/c64",    exts = {"prg", "crt", "t64", "d64", "zip", "x64", "g64"},
     bin = "/sd/apps/frodo.bin",      url = BIN_BASE .. "/frodo.bin"},
    {name = "Duke Nukem 3D",    ns = "duke3d",   dir = "/sd/roms/duke3d", exts = {"grp", "zip"},
     bin = "/sd/apps/duke3d-go.bin",  url = BIN_BASE .. "/duke3d-go.bin"},
}

-- --- Робота з файлами -------------------------------------------------------

local function extension(name)
    return string.lower(name:match("%.([^.]+)$") or "")
end

local function has_extension(name, extensions)
    local value = extension(name)
    for _, expected in ipairs(extensions) do
        if value == expected then return true end
    end
    return false
end

local function file_exists(path)
    local ok, file = pcall(fs.open, path, "r")
    if not ok or not file then return false end
    local exists_ok, exists = pcall(function() return file:exists() end)
    file = nil
    collectgarbage("collect")
    return exists_ok and exists
end

local function list_roms(platform)
    local roms = {}
    local ok, entries = pcall(fs.ls, platform.dir)
    if not ok or not entries then return roms end
    for _, name in ipairs(entries) do
        if type(name) == "string" and has_extension(name, platform.exts) then
            table.insert(roms, name)
        end
    end
    table.sort(roms)
    return roms
end

-- --- boot.json (retro-go зберігає лише плаский вміст "values") ---------------

local function json_escape(str)
    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    return str
end

local function write_boot_config(platform, rom_path)
    pcall(fs.mkpath, "/sd/retro-go/config")

    local json = table.concat({
        "{",
        '  "BootName": "' .. json_escape(platform.ns) .. '",',
        '  "BootArgs": "' .. json_escape(rom_path) .. '",',
        '  "BootFlags": 0,',
        '  "BootSlot": 0',
        "}",
    }, "\n")

    local ok, file = pcall(fs.open, BOOT_JSON, "w")
    if not ok or not file then return false end
    local write_ok = pcall(function() file:write(json) end)
    file = nil
    collectgarbage("collect")
    return write_ok
end

-- --- Меню -------------------------------------------------------------------

local function wait_for_b()
    while true do
        if controller.get_state().b.just_pressed then return end
        util.sleep(0.03)
    end
end

-- items — масив {label=, right=}. Повертає індекс вибраного або nil (B).
local function run_menu(title, hint, items, footer)
    local list = menu.new_list()
    while true do
        menu.draw_list(title, hint, items, list)
        menu.draw_footer(footer)
        display.queue_draw()

        while true do
            local state = controller.get_state()
            if state.up.just_pressed then
                menu.move(list, #items, -1)
                break
            elseif state.down.just_pressed then
                menu.move(list, #items, 1)
                break
            elseif state.a.just_pressed then
                if #items > 0 then return list.cursor end
                break
            elseif state.b.just_pressed then
                return nil
            end
            util.sleep(0.02)
        end
    end
end

-- --- Завантаження ядра ------------------------------------------------------

local function ensure_engine(platform)
    if file_exists(platform.bin) then return true end

    menu.message(platform.name, {"Завантаження ядра...", "Зачекайте"})
    pcall(fs.mkpath, "/sd/apps")
    pcall(fs.remove, platform.bin)

    local ok, result = pcall(http.execute, {
        url = platform.url,
        method = "GET",
        file = platform.bin,
    })

    if ok and result and result.code == 200 and file_exists(platform.bin) then
        return true
    end

    pcall(fs.remove, platform.bin)
    local code = result and result.code or "невідомий"
    menu.message("Помилка завантаження", {
        platform.name,
        "HTTP: " .. tostring(code),
        "Перевірте Wi-Fi",
    }, {{key = "B", label = "Назад"}})
    wait_for_b()
    return false
end

-- --- Головний цикл ----------------------------------------------------------

menu.init()

while true do
    local platform_items = {}
    for _, platform in ipairs(PLATFORMS) do
        table.insert(platform_items, {label = platform.name})
    end

    local platform_index = run_menu(
        "Оберіть платформу", nil, platform_items,
        {{key = "A", label = "Обрати"}, {key = "B", label = "Вихід"}}
    )
    if not platform_index then break end

    local platform = PLATFORMS[platform_index]
    local roms = list_roms(platform)

    if #roms == 0 then
        menu.message(platform.name, {
            "Немає ROM у теці:",
            platform.dir,
        }, {{key = "B", label = "Назад"}})
        wait_for_b()
    else
        local rom_items = {}
        for _, name in ipairs(roms) do
            table.insert(rom_items, {label = name})
        end

        local rom_index = run_menu(
            platform.name, platform.ns, rom_items,
            {{key = "A", label = "Запустити"}, {key = "B", label = "Назад"}}
        )

        if rom_index and ensure_engine(platform) then
            local rom_path = platform.dir .. "/" .. roms[rom_index]

            if not write_boot_config(platform, rom_path) then
                menu.message("Помилка запису", {"boot.json"},
                    {{key = "B", label = "Назад"}})
                wait_for_b()
            else
                menu.message("Запуск...", {roms[rom_index]})
                util.sleep(0.4)
                util.multiboot(platform.bin, "rg " .. rom_path)
            end
        end
    end
end

util.exit()

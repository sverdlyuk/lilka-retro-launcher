-- Перевіряє лише http.execute(). Нічого не запускає і не прошиває.

local URL = "https://raw.githubusercontent.com/sverdlyuk/retro-go/lilka-dev/keira-bin/snes9x.bin"
local EXPECTED_SIZE = 567760
local EXPECTED_MD5 = "25b60519c4f481c343a719d7074d1eac"
local ATTEMPTS = 3

local BLACK = display.color565(0, 0, 0)
local WHITE = display.color565(255, 255, 255)
local CYAN = display.color565(0, 220, 220)
local GREEN = display.color565(40, 220, 120)
local RED = display.color565(255, 80, 80)

local results = {}

local function file_info(path)
    local ok, file = pcall(fs.open, path, "r")
    if not ok or not file then return 0, "" end

    local size_ok, size = pcall(function() return file:size() end)
    local read_ok, data = pcall(function() return file:read(size) end)
    file = nil
    collectgarbage("collect")

    if not size_ok or not read_ok then return 0, "" end
    local md5_ok, hash = pcall(crypto.md5, data)
    data = nil
    collectgarbage("collect")

    if not md5_ok then return size, "" end
    return size, hash
end

local function draw_status(current)
    display.fill_screen(BLACK)
    display.set_font("10x20")
    display.set_text_color(CYAN)
    display.set_cursor(12, 25)
    display.print("HTTP download test")

    display.set_font("6x13")
    display.set_text_color(WHITE)
    display.set_cursor(12, 50)
    display.print("Правильний розмір: " .. EXPECTED_SIZE)

    for i, result in ipairs(results) do
        display.set_text_color(result.ok and GREEN or RED)
        display.set_cursor(12, 50 + i * 22)
        display.print(i .. ": " .. result.size ..
            (result.ok and "  MD5 OK" or "  MD5 ПОМИЛКА"))
    end

    if current then
        display.set_text_color(WHITE)
        display.set_cursor(12, 145)
        display.print("Спроба " .. current .. ": завантаження...")
    else
        display.set_text_color(WHITE)
        display.set_cursor(12, 170)
        display.print("B — вихід")
    end

    display.queue_draw()
end

pcall(fs.mkpath, "/sd/http-test")

for attempt = 1, ATTEMPTS do
    draw_status(attempt)

    local path = "/sd/http-test/snes9x-" .. attempt .. ".bin"
    pcall(fs.remove, path)

    local call_ok, response = pcall(http.execute, {
        url = URL,
        method = "GET",
        file = path,
    })

    local size, hash = file_info(path)
    local complete = call_ok and response and response.code == 200
        and size == EXPECTED_SIZE and hash == EXPECTED_MD5
    table.insert(results, {ok = complete, size = size, md5 = hash})

    console.print(
        "HTTP test " .. attempt ..
        ": code=" .. tostring(response and response.code) ..
        ", size=" .. size ..
        ", expected=" .. EXPECTED_SIZE ..
        ", md5=" .. hash ..
        ", expected_md5=" .. EXPECTED_MD5 ..
        ", result=" .. (complete and "OK" or "INVALID")
    )
end

draw_status(nil)

while true do
    if controller.get_state().b.just_pressed then break end
    util.sleep(0.03)
end

util.exit()

local tool = {}
-- lib

--- 移除前后空白
function tool.trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function tool.format_time(seconds)
    if not seconds then return "00:00:00" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    local ms = math.floor((seconds % 1) * 1000)
    return string.format("%02d:%02d:%02d.%03d", h, m, s, ms)
end

function tool.timestamp_to_number(timestamp)
    local seconds = 0.0
    for part in timestamp:gmatch("[^:]+") do
        local p = tonumber(part)
        if not p then return 0 end
        seconds = seconds * 60 + p
    end
    return seconds
end

function tool.readLines(filename)
    local lines = {}
    local file = io.open(filename, "r")
    if file then
        for line in file:lines() do
            if line:match("%S") then -- 只包含非空白字符的行才加入
                table.insert(lines, tool.trim(line))
            end
        end
        file:close()
    end
    return lines
end

function tool.to_string(t)
    local first = true
    local res = ""
    for k, v in pairs(t) do
        if not first then
            res = res .. ", "
        end
        first = false

        if type(k) == "string" then
            res = res .. k .. " = "
        end

        if type(v) == "table" then
            res = res .. "{" .. tool.to_string(v) .. "}"
        elseif type(v) == "string" then
            res = res .. string.format("%q", v)
        else
            res = res .. tostring(v)
        end
    end
    return res
end

--- return { title = title, time = time } or { title = "", time = 0 }
--- 以不是开头的第一个空格部分为分界，分为 time 和 title
--- 必须有 time
---
--- @param line string
function tool.parse_line(line)
    -- 以第一个空格为分界
    local time, title = tool.trim(line):match("^(%S+)%s*(.*)$")
    -- if time and title then -- (time and title) = if time then return title else return false end
    if time then
        return { title = tool.trim(title), time = tool.timestamp_to_number(time) }
    else
        return { title = "", time = 0 }
    end
end

function tool.is_local_file(path)
    -- 判断是否 NOT 以某种协议开头
    return (path and not path:match("^%a[%w+.-]*://")) or false
end

function tool.is_absolute(path)
    if not path then
        return false
    end
    return path:match("^%a:[/\\]") or path:match("^\\\\") or (path:sub(1, 1) == "/") or (path:sub(1, 1) == "~")
end

-- https://github.com/mpv-player/mpv/blob/dbd7a905b6ed47dd8f0acd09a1f4cc9a08e854a6/player/lua/defaults.lua#L725
-- function to_string


return tool

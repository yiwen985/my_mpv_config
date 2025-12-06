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

function tool.print_table(t)
    local function pt(t)
        if type(t) == "table" then
            for k, v in pairs(t) do
                if type(v) == "table" then
                    print(k .. ":")
                    pt(v)
                else
                    print(k .. ": " .. tostring(v))
                end
            end
        else
            print(tostring(t))
        end
    end

    -- if not prompt then
    --     prompt = ""
    -- end
    print("----- Start ------")
    pt(t)
    print("-----  END  ------")
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
function tool.format_table(t, set)
    if not set then
        set = { [t] = true }
    end
    local res = "{"
    -- pretty expensive but simple way to distinguish array and map parts of t
    local keys = {}
    local vals = {}
    local arr = 0
    for i = 1, #t do
        if t[i] == nil then
            break
        end
        keys[i] = i
        vals[i] = t[i]
        arr = i
    end
    for k, v in pairs(t) do
        if not (type(k) == "number" and k >= 1 and k <= arr and keys[k]) then
            keys[#keys + 1] = k
            vals[#keys] = v
        end
    end
    for i = 1, #keys do
        if #res > 1 then
            res = res .. ", "
        end
        if i > arr then
            res = res .. tool.to_string(keys[i], set) .. " = "
        end
        res = res .. tool.to_string(vals[i], set)
    end
    res = res .. "}"
    return res
end

function tool.to_string(v, set)
    if type(v) == "string" then
        return "\"" .. v .. "\""
    elseif type(v) == "table" then
        if set then
            if set[v] then
                return "[cycle]"
            end
            set[v] = true
        end
        return tool.format_table(v, set)
    else
        return tostring(v)
    end
end

return tool

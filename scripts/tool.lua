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

---时间格式转换成小数。例如 00:01:00.123 -> 60.123, 01:00.123 -> 60.123
---@param timestamp string
---@return number? # 返回小数，不是时间格式返回 nil
function tool.timestamp_to_number(timestamp)
    local seconds = 0.0
    for part in timestamp:gmatch("[^:]+") do
        local p = tonumber(part)
        if not p then return nil end
        seconds = seconds * 60 + p
    end
    return seconds
end

--- @return table? # 返回 lines，文件不存在返回 nil
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
    else
        return nil
    end
    return lines
end

function tool.to_string(t)
    if type(t) ~= "table" then
        return tostring(t)
    end

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
            -- res = res .. "{" .. tool.to_string(v) .. "}"
            res = res .. tool.to_string(v)
        elseif type(v) == "string" then
            res = res .. string.format("%q", v)
        else
            res = res .. tostring(v)
        end
    end
    return "{" .. res .. "}"
end

--- \\\\ 开头 == true
function tool.is_local_path(path)
    -- 是否以某种协议开头
    return path and (not path:match("^%a[%w+.-]*://"))
end

function tool.is_absolute(path)
    local res = path and path:match("^%a:[/\\]") or path:match("^\\\\") or (path:sub(1, 1) == "/") or
        (path:sub(1, 1) == "~")
    return res and true
end

-- https://github.com/mpv-player/mpv/blob/dbd7a905b6ed47dd8f0acd09a1f4cc9a08e854a6/player/lua/defaults.lua#L725
-- function to_string

--- return mp4
--- no point
function tool.getExtension(filename)
    local ext = filename:match("%.([^%./]+)$")
    return ext or ""
end

-- 如果文件存在，自动附加 (1), (2), (3)...
function tool.unique_filename(base)
    local name = base
    local count = 1
    local ext = ""
    local prefix = base

    -- 分离扩展名tostring
    local idx = base:match("^.*()%.")
    if idx then
        prefix = base:sub(1, idx - 1)
        ext = base:sub(idx)
    end

    while tool.file_exists(name) do
        name = string.format("%s (%d)%s", prefix, count, ext)
        count = count + 1
    end
    return name
end

--- 或使用 if not mp.utils.file_info(clips_dir) then print("file not exists.") end
function tool.file_exists(name)
    local f = io.open(name, "r")
    return f ~= nil and io.close(f)
end

--- 去除 table 中的重复项（保持顺序）
--- @param t table 原始列表
--- @return table # 去重后的新列表
function tool.table_unique(t)
    local check = {}
    local n = {}
    for _, v in ipairs(t) do
        if not check[v] then
            n[#n + 1] = v
            check[v] = true
        end
    end
    return n
end

-- 使用string.match获取文件名部分
function tool.get_filestem(filepath)
    local name = filepath:match("([^/\\]+)$") -- 获取文件名部分
    local stem = name:match("^(.+)%.[^.]*$")  -- 去掉扩展名
    return stem or name
end

function tool.escape_str(str)
    return string.format("%q", str)
end

return tool

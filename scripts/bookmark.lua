local input = require("mp.input")
local utils = require("mp.utils")
local script_dir = mp.command_native({ "expand-path", "~~/scripts/" })
package.path = script_dir .. "?.lua;" .. package.path
local tool = require("tool")



-- [{"title":"asdfa","time":0.000000},{"title":"zcvzxcv","time":8.700000}]
local chapters = {}

local function currChapterFile()
    return mp.get_property("path") .. ".chaper.txt"
end

local function writeChaptersToFile(filename, chapters)
    if not next(chapters) then
        local ok, err = os.remove(filename)
        return
    end
    local file = io.open(filename, "w")
    if file then
        for _, item in ipairs(chapters) do
            file:write(tool.format_time(item["time"]) .. " " .. item["title"] .. "\n")
        end
        file:close()
    else
        mp.msg.error("无法打开文件: " .. filename)
    end
end

local function updateChapterList()
    local currFile = currChapterFile()
    writeChaptersToFile(currFile, chapters)
    mp.set_property_native("chapter-list", chapters)
end

local function loadChapterFromVideo()
    local chps = mp.get_property_native("chapter-list")
    for _, item in ipairs(chps) do
        table.insert(chapters, item)
    end
end

local function loadChapterFromFile()
    local file = currChapterFile()
    local lines = tool.readLines(file)
    for _, line in ipairs(lines) do
        local item = tool.parse_line(line)
        if item then
            table.insert(chapters, item)
        end
    end
end

local function loadChapter(event)
    chapters = {}
    loadChapterFromVideo()
    loadChapterFromFile()
    updateChapterList()
end

local function bookmark_add()
    local curr = tool.format_time(mp.get_property_number("time-pos"))
    input.get({
        prompt = "添加书签（时间 标题）: ",
        submit = function(text)
            local line = tool.trim(text)
            if line == "" then
                return
            end
            local item = tool.parse_line(line)
            if item then
                table.insert(chapters, item)
                table.sort(chapters, function(a, b)
                    return a.time < b.time
                end)

                updateChapterList()
            end
        end,
        default_text = curr .. " "
    })
end



local function bookmark_remove(remember_pos)
    if not next(chapters) then
        mp.osd_message("No available chapters.")
        return
    end

    local default_item = remember_pos
    if not remember_pos then
        default_item = mp.get_property_native("chapter")
        default_item = default_item > -1 and default_item + 1
    end
    local chps = {}
    for i, item in ipairs(chapters) do
        chps[i] = tool.format_time(item.time) .. " " .. item.title
    end

    input.select({
        prompt = "删除书签:",
        items = chps,
        default_item = default_item,
        submit = function(option_num)
            if option_num < 1 then
                mp.osd_message("No selected chapter.")
                return
            end
            table.remove(chapters, option_num)
            updateChapterList()
            local pos = math.min(option_num, #chapters)
            -- mp.add_timeout(0, testLoop) 会将 bookmark_remove() 推入事件队列，确保 mpv 有时间处理上一个菜单的关闭，并准备好显示新菜单。
            mp.add_timeout(0, function()
                bookmark_remove(pos)
            end)
        end
    })
end


local function bookmark_modify(default_index)
    if not next(chapters) then
        mp.osd_message("No available chapters.")
        return
    end
    local default_item
    if default_index then
        default_item = default_index
    else
        default_item = mp.get_property_native("chapter")
        default_item = default_item > -1 and default_item + 1
    end

    local chps = {}
    for i, item in ipairs(chapters) do
        chps[i] = tool.format_time(item.time) .. " " .. item.title
    end

    input.select({
        prompt = "修改书签:",
        items = chps,
        default_item = default_item,
        submit = function(option_num)
            -- print("option_num " .. option_num) -- 没有这行，下方无法打印 text
            mp.add_timeout(0.01, function() -- 确保 mpv 有时间处理上一个菜单的关闭，并准备好显示新菜单. 0.01 比 0 好，这样可以注释上面一行
                input.get({
                    prompt = "修改书签（时间 标题）:",
                    submit = function(text)
                        print(text)
                        local line = tool.trim(text)
                        if line == "" then
                            table.remove(chapters, option_num)
                            updateChapterList()
                            mp.add_timeout(0, function()
                                bookmark_modify(option_num)
                            end)
                            return
                        end
                        local item = tool.parse_line(line)
                        local _, original_item = next(chapters, option_num)
                        if original_item and original_item.time == item.time then
                            original_item.title = item.title
                            print("modify title")
                        else
                            table.remove(chapters, option_num)
                            table.insert(chapters, item)
                            table.sort(chapters, function(a, b)
                                return a.time < b.time
                            end)
                            print("modify all")
                        end
                        updateChapterList()

                        mp.add_timeout(0, function()
                            bookmark_modify(option_num)
                        end)
                    end,
                    default_text = chps[option_num] .. " "
                })
            end)
        end
    })
end


local function bookmark_select()
    if not next(chapters) then
        mp.osd_message("No available chapters.")
        return
    end

    -- -1 书签 0 书签 1 书签
    local default_item = mp.get_property_native("chapter")
    local chps = {}
    for i, item in ipairs(chapters) do
        chps[i] = tool.format_time(item.time) .. " " .. item.title
    end

    input.select({
        prompt = "选择书签:",
        items = chps,
        default_item = default_item > -1 and default_item + 1,
        submit = function(chapter)
            mp.set_property("chapter", chapter - 1)
        end,
    })
end

local function bookmark_add_append()
    -- get_property_number("chapter"): nil or -1 chapter 0 chapter 1 ...
    local pos = (mp.get_property_number("chapter") or -1) + 1
    -- if not next(chapters) or pos < 1 then
    --     mp.add_timeout(0, bookmark_add)
    --     return
    -- end

    if not chapters[pos] then
        mp.add_timeout(0, bookmark_add)
        return
    end

    local chapter_start, chapter_end, chapter_title
    chapter_start = tool.format_time(chapters[pos].time)
    chapter_end = tool.format_time(mp.get_property_number("time-pos"))
    local parse_title = tool.parse_line(chapters[pos].title)
    if parse_title.time > 0 then --  or chapters[pos].title:match("^(%d%d:%d%d)(:%d%d)?(%.%d+)?") 以时间格式开头的标题
        chapter_title = parse_title.title
    else
        chapter_title = chapters[pos].title
    end
    local default_text = chapter_start .. " " .. chapter_end .. " " .. chapter_title

    input.get({
        prompt = "添加加书签（时间 标题）: ",
        submit = function(text)
            local line = tool.trim(text)
            if line == "" then
                table.remove(chapters, pos)
                updateChapterList()
                return
            end
            local item = tool.parse_line(line)
            if item then
                table.remove(chapters, pos)
                table.insert(chapters, item)
                table.sort(chapters, function(a, b)
                    return a.time < b.time
                end)

                updateChapterList()
            end
        end,
        default_text = default_text
    })
end

--- jump_to_chapter_start = add chapter -1
local function jump_to_chapter_end()
    if not next(chapters) then
        mp.osd_message("No available chapters.")
        return
    end
    -- get_property_number("chapter"): nil or -1 chapter 0 chapter 1 ...
    local pos = (mp.get_property_number("chapter") or -1) + 1
    if pos == 0 then
        mp.command("add chapter 1")
        return
    end

    local curr_chapter = chapters[pos]
    local time = tool.parse_line(curr_chapter.title).time

    if time then
        mp.commandv("set", "time-pos", time)
        return
    end

    mp.command("add chapter 1")
end

mp.register_event("file-loaded", loadChapter)
mp.add_key_binding("h", "bookmark_select", bookmark_select)
mp.add_key_binding("p", "bookmark_add", bookmark_add)
mp.add_key_binding("shift+p", "bookmark_add_append", bookmark_add_append)
mp.add_key_binding("del", "bookmark_remove", bookmark_remove)
mp.add_key_binding("w", "bookmark_modify", bookmark_modify)
mp.add_key_binding("alt+n", "jump_to_chapter_end", jump_to_chapter_end)
mp.add_key_binding("ctrl+y", "copy_chapters", function()
    if not next(chapters) then
        mp.osd_message("No available chapters.")
        return
    end

    local lines = ""
    local file = io.open(currChapterFile(), "r")
    if file then
        for line in file:lines() do
            if line:match("%S") then -- 只包含非空白字符的行才加入
                lines = lines .. line .. "\n"
            end
        end
        file:close()
    else
        mp.osd_message("No chapters file.")
        return
    end
    print("lines:" .. lines)
    mp.command("set clipboard/text '" .. tool.trim(lines) .. "'")
end)

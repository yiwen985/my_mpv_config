local input = require("mp.input")
local utils = require("mp.utils")
local script_dir = mp.command_native({ "expand-path", "~~/scripts/" })
package.path = script_dir .. "?.lua;" .. package.path
local tool = require("tool")



local function get_file_path()
    return mp.get_property("path")
end

local function get_chapter_file_path()
    return get_file_path() .. ".chapters.txt"
end

--- @return table? chapters # 返回 chapters，如果是空的，返回 nil
local function get_chapter_list()
    local chapters = mp.get_property_native("chapter-list")
    return next(chapters) and chapters or nil
end

--- mpv内部会排序吗？只在 chapters 增加或减少时排序（简单测试后猜测）
local function set_chapter_list(chapters)
    mp.set_property_native("chapter-list", chapters)
end

local function compare_chapter_time(chapter1, chapter2)
    return chapter1.time < chapter2.time
end

--- @return string? plain_text # 返回章节文本字符串，若无数据则返回 nil
local function get_chapters_plain_text()
    local chapters = get_chapter_list()
    if not chapters then
        return nil
    end

    local plain_text = ""
    for _, item in pairs(chapters) do
        plain_text = plain_text .. tool.format_time(item.time) .. " " .. item.title .. "\n"
    end
    return plain_text
end

local function get_current_timestamp()
    return tool.format_time(mp.get_property_number("time-pos"))
end

--- @return number? chapter_pos_of_chapters # 返回当前章节在章节列表中的位置，没有章节或在第一章开始之前，返回 nil
local function get_current_chapter_pos_of_chapters()
    -- 当前章节号。第一章编号为0。值为-1表示当前播放位置在第一章开始之前。没有章节为 nil
    local pos = mp.get_property_number("chapter") or -1
    if pos < 0 then
        return nil
    end

    return pos + 1
end

--- @return table? # 返回当前章节，没有就返回 nil
local function get_current_chapter()
    local chapters = get_chapter_list()
    local pos = get_current_chapter_pos_of_chapters()
    if chapters and pos then
        return chapters[pos]
    else
        return nil
    end
end

--- 以第一个空格为分界
--- @param line string
--- @return table? # 返回 { title = title, time = time } 或 nil
local function parse_line(line)
    local timestamp, title = tool.trim(line):match("^(%S+)%s*(.*)$")
    if not timestamp then
        return nil
    end
    local time = tool.timestamp_to_number(timestamp)
    if time then
        return { title = tool.trim(title), time = time }
    else
        return nil
    end
end

---@param chapter table
---@return string start_time # timestamp_str(chapter.time)
---@return string? end_time # timestamp_str or nil
---@return string chapter_title # title
local function parse_chapter(chapter)
    local start_time, end_time, chapter_title
    start_time = tool.format_time(chapter.time)
    local parse_res = parse_line(chapter.title)
    if parse_res then
        end_time = tool.format_time(parse_res.time)
        chapter_title = parse_res.title
    else
        end_time = nil
        chapter_title = chapter.title
    end

    return start_time, end_time, chapter_title
end

local function write_chapters_to_chapter_file()
    local plain_text = get_chapters_plain_text()
    local chapter_file_path = get_chapter_file_path()

    if not plain_text then
        os.remove(chapter_file_path)
        return
    end

    local chapter_file = io.open(chapter_file_path, "w")
    if chapter_file then
        chapter_file:write(plain_text)
        chapter_file:close()
    else
        mp.msg.error("无法打开文件: " .. chapter_file)
    end
end

---更新 chapters(含文件)
---@param chapters table
local function update_chapters(chapters)
    table.sort(chapters, compare_chapter_time)
    set_chapter_list(chapters)
    write_chapters_to_chapter_file()
end

local function load_chapter_file()
    local chapter_file_path = get_chapter_file_path()
    local lines = tool.readLines(chapter_file_path)
    if not lines then
        return
    end


    local chapters = get_chapter_list() or {}
    for _, line in ipairs(lines) do
        local item = parse_line(line)
        if item then
            table.insert(chapters, item)
        end
    end

    -- TODO: 要排序吗？mpv内部会排序吗？只在 chapters 增加或减少时排序（简单测试后猜测）
    table.sort(chapters, compare_chapter_time)
    tool.table_unique(chapters)
    set_chapter_list(chapters)
end

local function bookmark_select()
    local chapters = get_chapter_list()
    if not chapters then
        mp.osd_message("No available chapters.")
        return
    end
    local default_item = get_current_chapter_pos_of_chapters() or 1
    local chps = {}
    for i, item in ipairs(chapters) do
        chps[i] = tool.format_time(item.time) .. " " .. item.title
    end

    input.select({
        prompt = "选择书签:",
        items = chps,
        default_item = default_item,
        submit = function(chapter)
            mp.set_property("chapter", chapter - 1)
        end,
    })
end

local function bookmark_add()
    local default_text = get_current_timestamp() .. " "
    local chapters = get_chapter_list() or {}
    input.get({
        prompt = "添加书签（时间 标题）: ",
        submit = function(text)
            local item = parse_line(text)
            if item then
                table.insert(chapters, item)
                table.sort(chapters, compare_chapter_time)

                update_chapters(chapters)
            end
        end,
        default_text = default_text
    })
end

local function bookmark_add_append()
    local chapters = get_chapter_list()
    local pos = get_current_chapter_pos_of_chapters()
    if not chapters or not pos then
        mp.add_timeout(0.1, bookmark_add)
        return
    end

    local start_time, _, chapter_title = parse_chapter(chapters[pos])
    local default_text = start_time .. " " .. get_current_timestamp() .. " " .. chapter_title

    input.get({
        prompt = "修改书签（时间 标题）: ",
        submit = function(text)
            local item = parse_line(text)
            table.remove(chapters, pos)
            if item then
                table.insert(chapters, item)
                update_chapters(chapters)
            end
        end,
        default_text = default_text
    })
end

local function jump_to_chapter_end()
    local chapters = get_chapter_list()
    if not chapters then
        mp.osd_message("No available chapters.")
        return
    end

    local pos = get_current_chapter_pos_of_chapters()
    if not pos then
        mp.set_property("time-pos", chapters[1].time)
        return
    end

    local _, end_time, _ = parse_chapter(chapters[pos])
    if end_time then
        mp.set_property("time-pos", end_time)
    else
        mp.osd_message("当前书签没有结束时间")
    end
end

local function bookmark_remove(remember_pos)
    local chapters = get_chapter_list()
    if not chapters then
        mp.osd_message("No available chapters.")
        return
    end

    local default_item = remember_pos or get_current_chapter_pos_of_chapters() or 1

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
            update_chapters(chapters)
            local pos = math.min(option_num, #chapters)
            -- mp.add_timeout(0, testLoop) 会将 bookmark_remove() 推入事件队列，确保 mpv 有时间处理上一个菜单的关闭，并准备好显示新菜单。
            mp.add_timeout(0.1, function()
                bookmark_remove(pos)
            end)
        end
    })
end

local function bookmark_modify(remember_pos)
    local chapters = get_chapter_list()
    if not chapters then
        mp.osd_message("No available chapters.")
        return
    end

    local default_item = remember_pos or get_current_chapter_pos_of_chapters() or 1

    local chps = {}
    for i, item in ipairs(chapters) do
        chps[i] = tool.format_time(item.time) .. " " .. item.title
    end

    input.select({
        prompt = "修改书签:",
        items = chps,
        default_item = default_item,
        submit = function(option_num)
            if option_num < 1 then
                mp.osd_message("No selected chapter.")
                return
            end

            -- print("option_num " .. option_num) -- 没有这行，下方无法打印 text
            mp.add_timeout(0.1, function() -- 确保 mpv 有时间处理上一个菜单的关闭，并准备好显示新菜单. 0.01 比 0 好，这样可以注释上面一行
                input.get({
                    prompt = "修改书签（时间 标题）:",
                    submit = function(text)
                        local item = parse_line(text)
                        table.remove(chapters, option_num)
                        if item then
                            table.insert(chapters, item)
                            update_chapters(chapters)
                        end

                        mp.add_timeout(0.1, function()
                            bookmark_modify(option_num)
                        end)
                    end,
                    default_text = chps[option_num] .. " "
                })
            end)
        end
    })
end

local function copy_chapters()
    local chapters = get_chapter_list()
    if not chapters then
        mp.osd_message("No available chapters.")
        return
    end

    local plain_text = get_chapters_plain_text()
    mp.commandv("set", "clipboard/text", plain_text)
    mp.osd_message("已复制全部章节到剪贴板")
end

local function copy_chapter()
    local chapters = get_chapter_list()
    if not chapters then
        mp.osd_message("No available chapters.")
        return
    end

    local pos = get_current_chapter_pos_of_chapters()
    mp.commandv("set", "clipboard/text", tool.format_time(chapters[pos].time) .. " " .. chapters[pos].title)
    mp.osd_message("已复制当前章节到剪贴板")
end



--- ```
--- callback(result)
---     if result.status == 0 then
---         print("命令运行成功：" .. tool.to_string(command))
---         -- print(result.stdout)
---     else
---         print("命令运行失败：" .. result.stderr)
---     end
--- end
--- ```
---
---@param command table
---@param callback function|nil #
local function run_command(command, callback)
    if type(command) ~= "table" then
        mp.msg.error("command is not table.")
    end
    mp.msg.info("执行命令: " .. table.concat(command, " "))
    return mp.command_native_async({
        name = "subprocess",
        args = command,
        capture_stdout = true, -- 捕获标准输出（可选）
        capture_stderr = true, -- 捕获标准错误输出（可选）
    }, function(success, result, error)
        if success and callback then
            callback(result)
            -- if result.status == 0 then
            --     print("命令运行成功：" .. tool.to_string(command))
            --     -- print(result.stdout)
            -- else
            --     print("命令运行失败：" .. result.stderr)
            -- end
        else
            mp.msg.error("程序发生错误: " .. error)
        end
    end)
end

--- TODO?
local function has_ffmpeg()
    local command = { 'ffmpeg', '-version' }

    run_command(command)
end

---@param video_path string
---@param start_time string
---@param end_time string
---@param out_path string
local function ffmpeg_cut(video_path, start_time, end_time, out_path, title)
    if not video_path or not start_time or not end_time or not out_path then
        mp.msg.error("ffmpeg_cut(video_path, start_time, end_time, out_path) 参数需要非空")
        return
    end

    title = title or tool.get_filestem(out_path)
    local command = { 'ffmpeg', '-ss', start_time, '-to', end_time, '-i', video_path, '-c:a', 'copy',
        '-metadata', string.format("title=%q", title), '-y', out_path }
    run_command(command, function(result)
        if result.status == 0 then
            print("完成 " .. out_path)
            mp.osd_message("完成 " .. out_path)
        else
            print("命令运行失败：" .. result.stderr)
        end
    end)
end

--- 选择一个章节切出来
--- TODO?：dump-cache <start> <end> <filename>
local function bookmark_cut(remember_pos)
    local chapters = get_chapter_list()
    if not chapters then
        mp.osd_message("No available chapters.")
        return
    end

    -- local ext = tool.getExtension(video)
    local ext = "mp4"
    local clips_dir_name = "切片"

    local default_item = remember_pos or get_current_chapter_pos_of_chapters() or 1
    local chps = {}
    for i, item in ipairs(chapters) do
        chps[i] = tool.format_time(item.time) .. " " .. item.title
    end

    input.select({
        prompt = "切片选择:",
        items = chps,
        default_item = default_item,
        submit = function(chapter_num)
            local chapter = chapters[chapter_num]
            local start_time, end_time, title = parse_chapter(chapter)
            if not end_time then
                mp.osd_message("该章节没有结束时间")
                return
            end

            local video_path = get_file_path()
            local parent, _ = utils.split_path(video_path)
            local clips_dir = utils.join_path(parent, clips_dir_name)
            if not utils.file_info(clips_dir) then
                os.execute("mkdir -p " .. clips_dir)
            end
            local out_path = utils.join_path(clips_dir, title .. "." .. ext)

            mp.add_timeout(0, function()
                ffmpeg_cut(video_path, start_time, end_time, out_path, title)
            end)

            mp.add_timeout(0.1, function()
                bookmark_cut(chapter_num)
            end)
        end,
    })
end

mp.add_key_binding("ctrl+z", "test_bookmark", has_ffmpeg)
mp.register_event("file-loaded", load_chapter_file)
mp.add_key_binding(nil, "bookmark_select", bookmark_select)
mp.add_key_binding(nil, "bookmark_add", bookmark_add)
mp.add_key_binding(nil, "bookmark_add_append", bookmark_add_append)
mp.add_key_binding(nil, "jump_to_chapter_end", jump_to_chapter_end)
mp.add_key_binding(nil, "bookmark_remove", bookmark_remove)
mp.add_key_binding(nil, "bookmark_modify", bookmark_modify)
mp.add_key_binding(nil, "copy_chapters", copy_chapters)
mp.add_key_binding(nil, "copy_chapter", copy_chapter)
mp.add_key_binding(nil, "bookmark_cut", bookmark_cut)

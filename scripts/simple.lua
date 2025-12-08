local input = require("mp.input")
local utils = require("mp.utils")
package.path = mp.command_native({ "expand-path", "~~/scripts/?.lua;" }) .. package.path
local tool = require "tool"
local to_string = utils.to_string

-- jump to ab-loop-a or 0
local function jump_to_start()
    local a = mp.get_property_number("ab-loop-a", 0)
    mp.set_property_number("time-pos", a)
end

-- jump to
local function jump_to()
    local curr = mp.get_property_number("time-pos")
    input.get({
        prompt = "跳转时间（00:01:00.123 或 60.123）：",
        submit = function(text)
            local text = tool.trim(text):gsub("：", ":")
            mp.set_property("time-pos", text)
        end
    })
end

--- 设置截图路径，默认 "~/Pictures/mpv-screenshot"
--- 如果视频是网络路径，如果 {screenshot-directory} 绝对路径，保存到 {screenshot-directory}
---                   如果 {screenshot-directory} 相对路径，保存到 ~/Pictures/{screenshot-directory}
--- 如果视频是本地路径，如果 {screenshot-directory} 绝对路径，保存到 {screenshot-directory}
---                   如果 {screenshot-directory} 相对路径，保存到 视频文件夹/{screenshot-directory}
local function set_screenshot_directory()
    local path = mp.get_property("screenshot-directory") or "~/Pictures/mpv-screenshot"
    local video = mp.get_property("path")
    local dir, _ = utils.split_path(video)
    dir = tool.is_local_file(video) and dir or "~/Pictures"
    path = utils.join_path(dir, path)
    mp.set_property("screenshot-directory", path)
end

-- https://github.com/mpv-player/mpv/blob/72dbcf119a9ed5082be2f226593194e20f611eea/player/lua/select.lua#L636
local function system_open(path)
    local platform = mp.get_property("platform")
    local args
    if platform == "windows" then
        args = { "explorer", path }
    elseif platform == "darwin" then
        args = { "open", path }
    else
        args = { "gio", "open", path }
    end

    mp.commandv("run", unpack(args))
end

local function open_folder(path)
    if not path then return end
    local info = utils.file_info(path)
    if not info then
        mp.osd_message("无法打开文件夹" .. path)
        return
    end
    -- print("path: " .. to_string(path))
    -- print("info: " .. to_string(info))
    -- print("split_path: " .. to_string(utils.split_path(path)))
    local folder = info.is_dir and path or utils.split_path(path)
    -- print("folder: " .. to_string(folder))
    system_open(folder)
end

-- print-text ${image-exts}
local image_exts = { ".jpg", ".png", ".gif", ".avif", ".jpeg", ".bmp", ".tif", ".tiff", ".webp", ".heic", ".heif", ".j2k",
    ".jp2", ".jxl", ".qoi", ".svg", ".tga",
}

local video_exts = { ".flv", ".mp4", ".3g2", ".3gp", ".avi", ".ivf", ".m2ts", ".m4v", ".mj2", ".mkv", ".mov", ".mpeg",
    ".mpg", ".mxf", ".ogv", ".rmvb", ".ts", ".webm", ".wmv", ".y4m"
}

local audio_exts = { ".mp3", ".aac", ".m4a", ".wav", ".ogg", ".ac3", ".aiff", ".ape", ".au", ".dts", ".eac3", ".flac",
    ".mka", ".oga", ".ogm", ".opus", ".thd", ".wma", ".wv"
}


-- [
--     {
--         "filename": "\\\\DESKTOP-VV2JEB7\\bililiverecorder\\80397-阿梓从小就很可爱\\2025.12\\01\\录制-80397-20251201-155914-262-我来唱歌！.flv",
--         "current": true,
--         "playing": true,
--         "title": "我来唱歌！",
--         "id": 2,
--         "playlist-path": "\\\\DESKTOP-VV2JEB7\\bililiverecorder\\80397-阿梓从小就很可爱\\2025.12\\01\\录制-80397-20251201-155914-262-我来唱歌！.flv"
--     },
--     {
--         "filename": "\\\\DESKTOP-VV2JEB7\\bililiverecorder\\80397-阿梓从小就很可爱\\2025.12\\01\\录制-80397-20251201-205916-316-看凡人修仙传.flv",
--         "id": 3,
--         "playlist-path": "\\\\DESKTOP-VV2JEB7\\bililiverecorder\\80397-阿梓从小就很可爱\\2025.12\\01\\录制-80397-20251201-155914-262-我来唱 歌！.flv"
--     }
-- ]
-- 至少有一个
local playlist = {}
-- skip images, directory
mp.register_event("file-loaded", function()
    if #playlist > 1 then
        return
    end
    playlist = mp.get_property_native("playlist")
    -- for index, item in ipairs(playlist) do -- BUG
    for index = #playlist, 1, -1 do
        local item = playlist[index]
        local info = utils.file_info(item.filename)
        if not info then return end -- 网络地址

        index = index - 1           -- playlist-remove 下标从 0 开始
        if info.is_dir then
            mp.commandv("playlist-remove", index)
            goto continue
        end

        for _, ext in ipairs(image_exts) do
            if item.filename:lower():sub(- #ext) == ext then
                mp.commandv("playlist-remove", index)
                break
            end
        end

        ::continue::
    end
end)

-- https://github.com/mpv-player/mpv/blob/dbd7a905b6ed47dd8f0acd09a1f4cc9a08e854a6/player/lua/select.lua#L42
-- mp.add_key_binding(nil, "select-playlist", function()

-- clear ab-loop
mp.register_event("file-loaded", function()
    mp.set_property("ab-loop-a", "no")
    mp.set_property("ab-loop-b", "no")

    mp.set_property("contrast", "0")
    mp.set_property("brightness", "0")
    mp.set_property("saturation", "0")
    mp.set_property("hue", "0")
    mp.set_property("sub-pos", "100")
    mp.set_property("panscan", "0")
    mp.set_property("zoom", "0")

    mp.set_property("loop-file", "no")
    mp.set_property("loop-playlist", "no")

    -- 无法设置 working-directory
    -- mp.set_property("working-directory", "~/Videos")

    set_screenshot_directory()
end)

-- mp.register_event("client-message", function(e)
--     print(utils.to_string(e))
-- end)

mp.add_key_binding("bs", "jump_to_start", jump_to_start)
mp.add_key_binding("g", "jump_to", jump_to)
mp.add_key_binding("f", "open_folder", function()
    open_folder(mp.get_property("path"))
end)
mp.add_key_binding("ctrl+f", "open_screenshot", function()
    open_folder(mp.get_property("screenshot-directory"))
end)
mp.add_key_binding(nil, "copy_time_pos", function()
    local time = tool.format_time(mp.get_property_number("time-pos"))
    mp.command("set clipboard/text " .. time)
end)

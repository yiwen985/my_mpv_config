自用

## Features

### default settings

```lua
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
```

### screenshot-directory

默认为 "~/Pictures/mpv-screenshot"。

`mpv.conf`设置`screenshot-directory=dir`。

如果 `dir` 是相对路径，截图到视频文件夹下的 `dir` 文件夹，网络视频就放到 `~/Pictures/dir`。

如果 `dir` 是绝对路径，放到 `dir`。

### bookmark

see `input.conf` `# bookmark 书签`

### Other

- remove images、directory of playlist
- jump_to、jump_to_start(jump to ab-loop-a or 0)

## Usage

1. 安装 mpv
2. 设置环境变量

    e.g. MPV_HOME=D:\program\mpv-x86_64-v3-20251130-git-23f9381\mpv

3. 放入文件

debug

mpv --log-file=mpv.log --msg-level=all=debug video.mp4
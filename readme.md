自用

## 书签、章节（bookmark）

- 说明（description）

  - 配置文件夹：在 `C:\Users\用户名\AppData\Roaming\mpv\` ，或放到 `MPV_HOME` (例如 D:\program\mpv-x86_64-v3-20251130-git-23f9381\mpv)。
  - 视频文件夹：本地视频为本地视频所在文件夹，网络视频在 `~/Videos/mpv`。
  - 书签保存在视频文件夹下，以 `.chapters.txt` 结尾。
  - BUG：如果书签的标题为纯数字，在添加书签结束时间时，会把该数字标题识别为结束时间。

- 安装（install）

  把 `bookmark.lua` 放入 `scripts` 文件夹，该文件夹在配置文件夹，没有就新建一个。

  切片需要安装 ffmpeg 和 yt-dlp

  ```shell
  winget install -e --id Gyan.FFmpeg   # 切片本地视频
  winget install -e --id yt-dlp.yt-dlp # 切片网络视频
  ```

- 设置（config）

  设置快捷键：修改 `input.conf`，在配置文件夹。

  ```conf
  h       script-binding bookmark_select           # 选择书签
  p       script-binding bookmark_add              # 添加书签
  shift+p script-binding bookmark_add_append       # 添加书签结束时间
  del     script-binding bookmark_remove           # 删除书签
  w       script-binding bookmark_modify           # 修改书签
  alt+x   script-binding bookmark_cut              # 切片书签
  shift+x script-binding cut_ab_loop               # 切片ab-loop（默认ab-loop的快捷键为 l）
  alt+n   script-binding jump_to_chapter_end       # 跳转当前书签结束时间
  ctrl+y  script-binding copy_chapters             # 复制全部书签
  shift+y script-binding copy_chapter              # 复制当前书签
  ```

  网络视频播放设置：修改 `mpv.conf`，在配置文件夹。

  ```conf
  ytdl-raw-options=yes-playlist=  # 自动加载网络视频列表
  # ytdl-raw-options=proxy=[http://127.0.0.1:10808],yes-playlist=
  ```

- 使用（usage）

  播放网络视频

  ```shell
  mpv https://www.bilibili.com/video/BV1tFiGBBEJ5
  ```

## 截图文件夹（screenshot-directory）

默认为 "~/Pictures/mpv-screenshot"。

`mpv.conf` 设置 `screenshot-directory=dir`。

如果 `dir` 是相对路径，截图到视频文件夹下的 `dir` 文件夹，网络视频就放到 `~/Pictures/dir`。

如果 `dir` 是绝对路径，放到 `dir`。


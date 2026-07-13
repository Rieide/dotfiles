# tmux 使用与维护指南

这套配置面向 Ubuntu Linux 和 tmux 3.2 以上版本，当前由 GNU Stow 链接到
`~/.config/tmux`。它用 tmux 原生选项实现 Kanagawa Wave 外观，并组合 sesh、
vim-tmux-navigator、resurrect 和 continuum。配置中没有启动时克隆、自动升级或
主题黑箱；工具版本、插件来源和行为都可以在仓库中直接审查。

## 安装

在仓库根目录执行：

```sh
./install.sh --dry-run
./install.sh
```

只安装工具和插件、不运行 Stow：

```sh
./install.sh --install-only
```

`--skip-remote` 禁止 sesh 下载、插件 clone/fetch 以及其他上游安装器。每个项目
都是 preferred：单个网络错误、GitHub 限流或二进制执行失败不会中止其他独立步骤。
安装器以 Ubuntu 26.04 Linux x86_64 为目标假设，不为旧系统添加兼容分支，也不在
下载 sesh 前判断发行版或架构；非目标环境中的失败项留在汇总中供人工处理。
最终表格中的结果含义如下：

| 结果 | 含义 |
| --- | --- |
| `SKIPPED` | 已安装内容的来源、版本/commit 和工作区状态满足策略 |
| `INSTALLED` | 本次已安装、生成 completion 或切换到固定 commit |
| `PLANNED` | dry-run 中会执行的动作 |
| `FAILED` | 该项未达到后置条件；其他项目仍会继续 |

### 固定版本

版本表集中位于仓库根目录的 `install.sh`：

| 项目 | 固定版本或 commit |
| --- | --- |
| sesh | `2.26.2` |
| TPM | `e261deb1b47614eed3400089ce7197dc68acc4eb` |
| tmux-sensible | `25cb91f42d020f675bb0a2ce3fbd3a5d96119efa` |
| tmux-resurrect | `cff343cf9e81983d3da0c8562b01616f12e8d548` |
| tmux-continuum | `0698e8f4b17d6454c71bf5212895ec055c578da0` |
| vim-tmux-navigator | `e41c431a0c7b7388ae7ba341f01a0d217eb3a432` |

sesh 使用官方 `sesh_Linux_x86_64.tar.gz`，安装器在写入
`~/.local/bin/sesh` 前校验 SHA256：

```text
4a5cdd75a38c6e3167ab80d419a9973097b2f7e1b63c8150c4e6db8e40c6d803
```

安装器还会运行 `sesh completion zsh`，写入
`${XDG_DATA_HOME:-~/.local/share}/zsh/site-functions/_sesh`。共享 `.zshrc` 在
`compinit` 前把该目录加入 `fpath`。

### 插件目录安全策略

所有 tmux 插件位于 `~/.config/tmux/plugins`，插件源码不纳入 dotfiles Git：

- 目录缺失时，先 clone 到同一文件系统的临时目录，checkout 固定 commit，成功后
  再原子移动到目标位置。
- origin 是对应官方 GitHub 仓库、工作区干净且 HEAD 正确时跳过。
- origin 正确、工作区干净但 HEAD 不同时，切换到固定 commit；本地已有对象时不需
  联网，否则才 fetch。
- 有 tracked/untracked 修改、origin 不符、目录不是 Git 仓库时均标记 `FAILED`，
  不改 remote、不 stash、不 reset、不删除目录。

TPM 仅负责按声明顺序加载插件。其安装、更新和清理键 `Prefix+I`、`Prefix+U`、
`Prefix+M-u` 会在加载后解除，防止绕开版本表。升级流程只有一种：修改
`install.sh` 中的版本/commit 和 sesh SHA256，审查上游差异，然后重新运行安装器。

## 外观和状态栏

Kanagawa Wave 色板集中在 `tmux.conf` 的 `@kanagawa_*` 用户选项。状态栏、窗口、
pane、消息、command prompt、复制模式、搜索匹配、popup 和 clock 都复用这些颜色，
没有主题插件或 Nerd Font 字符。

状态栏固定在底部：

- 左侧显示 session 名；`PREFIX`、`COPY`、`SYNC`、`ZOOM` 只在对应状态生效时出现。
- 中间由 tmux 原生 window list 填充，格式为编号、名称以及 `A`（activity）、
  `B`（bell）、`Z`（zoom）标志。
- 右侧显示最多 40 字符的当前 pane 完整路径；只有 tmux 环境中存在
  `SSH_CONNECTION` 时才显示主机名；最后是 `YYYY-MM-DD HH:MM`。
- 刷新周期为 60 秒。配置本身不执行 CPU、天气、Git 状态等高频外部命令。

continuum 为实现定时保存，会在运行时向 `status-right` 前置一个轻量、带十分钟
限流的保存检查。这是持久化机制，不是展示模块；不要用主题配置覆盖运行时的
`status-right`，否则 continuum 无法触发。

Pane 使用 heavy border。非活动边框是低对比 Kanagawa 背景色，活动边框为蓝色。
只有活动 pane 的上边框显示截断路径和当前命令，非活动 pane 不显示标题。

## 快捷键

Prefix 是 `Ctrl-a`；下表中的 `Prefix+x` 表示先按 `Ctrl-a`，松开后再按 `x`。

### Window 和 pane

| 快捷键 | 行为 |
| --- | --- |
| `Prefix+Ctrl-a` | 向前台程序发送原始 `Ctrl-a` |
| `Prefix+\` | 在当前目录左右分屏 |
| `Prefix+-` | 在当前目录上下分屏 |
| `Prefix+c` | 在当前目录新建 window |
| `Prefix+h/j/k/l` | 向左/下/上/右选择 pane |
| `Prefix+H/J/K/L` | 向左/下/上/右调整 pane 5 格，可重复 |
| `Prefix+n` / `Prefix+p` | 下一个 / 上一个 window，可重复 |
| `Prefix+Tab` | 回到上次使用的 window |
| `Prefix+S` | 切换 synchronize-panes；开启时显示 `SYNC` |
| `Prefix+r` | 重新加载 `tmux.conf` |

### Popup

| 快捷键 | 行为 |
| --- | --- |
| `Prefix+g` | 在当前目录打开 80% × 80% lazygit |
| `Prefix+Ctrl-p` | 在当前目录打开 70% × 70% 临时 shell |
| `Prefix+Ctrl-f` | 打开 80% × 70% sesh session 选择器 |

sesh popup 只读取现有 tmux sessions 与 zoxide 目录，不含配置 session、目录扫描或
私人项目路径。fzf 保持 sesh 顺序，右侧 55% 用 `sesh preview` 展示预览；Enter
连接或创建 session，Esc 关闭。首版没有 kill/delete session 快捷键。

若 sesh 或 fzf 缺失，popup 会显示明确提示并等待 Enter 关闭。zoxide 缺失时仍列出
现有 tmux sessions，只是不显示目录记录。在目标 Ubuntu 26.04 环境中重新运行
`./install.sh --install-only` 可安装缺项；若汇总仍为 `FAILED`，按日志提示人工处理。

### 复制模式

Vi copy mode 通过 `Prefix+[` 进入（tmux 默认键）：

| 快捷键 | 行为 |
| --- | --- |
| `v` | 开始选择 |
| `Ctrl-v` | 切换矩形选择 |
| `y` / `Enter` | 复制到 X11 clipboard 并退出 copy mode |
| 鼠标拖选后松开 | 复制到 X11 clipboard |
| `Ctrl-h/j/k/l` | 不循环地选择相邻 tmux pane |

复制目前直接调用 `xclip -selection clipboard -in`。因此 X11 下需要 `xclip` 和有效
`DISPLAY`；Wayland、纯 SSH 或没有 xclip 时 copy mode 本身仍工作，但外部剪贴板
命令会失败。`set-clipboard on` 同时允许支持 OSC 52 的应用/终端设置剪贴板。

## Neovim 与 tmux 无缝导航

vim-tmux-navigator 同时由 TPM 和 Neovim lazy.nvim 声明，并在两边固定为同一个
commit。普通模式下直接按 `Ctrl-h/j/k/l`：

1. Neovim 内有相邻 split 时先在 split 间移动。
2. 到达 Neovim 边缘时移动到相邻 tmux pane。
3. 到达最外侧 tmux 边缘时停住，不绕到另一侧。
4. tmux window 已 zoom 时使用 `select-pane -Z`，导航不会取消 zoom。

`g:tmux_navigator_save_on_switch=0`，切换不会自动保存 buffer。`Ctrl-\` 在 Neovim
和 tmux 两边均未映射到 navigator，继续作为终端 SIGQUIT；上一 pane 仍可使用 tmux
自己的带 Prefix 命令。插件缺失时，带 Prefix 的 h/j/k/l 导航始终可用。

排障时可在 Neovim 运行：

```vim
:TmuxNavigatorProcessList
:verbose nmap <C-h>
```

映射应指向 `TmuxNavigateLeft/Down/Up/Right`，而不是直接 `<C-w>`/`wincmd`。

## 保存与恢复

tmux-resurrect 保存 session、window、pane、pane command、布局和工作目录；配置明确
设置 `@resurrect-capture-pane-contents off`，不会保存 pane 当前可见文本、shell 输出
或屏幕内容。

| 快捷键 / 事件 | 行为 |
| --- | --- |
| `Prefix+Ctrl-s` | 立即保存 |
| `Prefix+Ctrl-r` | 手动恢复最近一次保存 |
| 每 10 分钟 | continuum 自动保存一次 |
| 新 tmux server 启动 | continuum 尝试自动恢复 |

自动恢复只发生在新 server 的启动窗口，不等同于每个新 client 都恢复。若插件缺失，
tmux 配置仍能加载，但手动保存/恢复键和自动保存/恢复不可用。安装插件后建议完全退出
旧 server 再启动，或 `Prefix+r` 重新加载后检查绑定。

恢复文件默认位于 resurrect 的用户数据目录。遇到异常时先手动保存，检查可用空间和
目录权限，再确认：

```sh
tmux show-options -g @resurrect-capture-pane-contents
tmux show-options -g @continuum-save-interval
tmux list-keys | grep 'C-s\|C-r'
```

## SSH、终端和故障处理

- 最低 tmux 版本是 3.2；`display-popup`、RGB、heavy border 和当前格式均按此基线。
- 终端应支持 `tmux-256color` 和真彩色。颜色异常时检查本地/远端 terminfo，并运行
  `tmux display-message -p '#{client_termname} #{client_termfeatures}'`。
- 右侧主机名由 tmux server 的 `SSH_CONNECTION` 环境判断，并在 client attach 时
  更新 `@ssh_attached`。复用同一个 server 的多个本地/SSH client 时，这个 server
  级标记以最近 attach 的 client 为准；可用 `tmux show-options -g @ssh_attached` 和
  `tmux show-environment -g SSH_CONNECTION` 检查。
- 非官方 origin 或 dirty 插件目录不会被安装器修复。先在该目录内审查 `git status`
  和 `git remote -v`，自行 commit/stash/迁移后再运行安装器。
- GitHub 网络失败时保持原目录和 HEAD；看安装日志中的具体 clone/fetch/curl 错误，
  网络恢复后重跑即可。
- TPM 缺失不会触发隐式下载，也不会阻止基本 tmux 配置加载。

## 验收清单

自动检查建议：

```sh
bash -n install.sh
bash -n tmux/.config/tmux/scripts/sesh-picker
./install.sh --install-only --dry-run
git diff --check
```

再用独立 socket 启动临时 server，检查 `show-options` 和 `list-keys`，避免影响当前
会话。Neovim 可用 headless 模式确认 lazy spec 与四个映射。

需要在真实终端手动确认：

- [ ] 普通终端和 SSH 中 Kanagawa 真彩色正常，SSH 主机名只在 SSH 时出现。
- [ ] 长路径会截断，活动 pane 标题包含短路径和当前命令。
- [ ] Neovim split 与 tmux pane 四向导航顺畅，边缘不循环，zoom 保持。
- [ ] `Prefix+Ctrl-f` 只显示 tmux 与 zoxide，预览在右侧且能够连接。
- [ ] resurrect 手动保存/恢复和 continuum 自动恢复有效，保存文件无 pane 文本。
- [ ] 当前 X11 环境中 `y`、Enter 和鼠标拖选可通过 xclip 复制。

## 延期项目

- TODO：单独设计不依赖 xclip、能识别 X11/Wayland/OSC 52/SSH 的自适应剪贴板方案。
- which-key、tmux-yank、tmux-open、tmux-fzf 暂不加入，避免快捷键和职责重叠。
- sesh session 删除快捷键、硬编码项目列表和私人目录均不在首版范围内。

# tmux 美化与增强计划

当前配置文件位于 `.config/tmux/tmux.conf`，使用 tmux 3.6。现有配置已经覆盖真彩色、Vi 复制模式、鼠标、pane 边框、popup、TPM，以及会话保存与恢复。

这份文档用于记录可配置范围、候选插件和后续实施顺序。配置调试完成后，再将本分支合并回主分支。

## 当前基础

- `tmux-256color` 和 `terminal-features` 提供 RGB 真彩色支持。
- Prefix 已从 `C-b` 改为 `C-a`。
- 使用 `prefix + h/j/k/l` 切换 pane，`prefix + H/J/K/L` 调整大小。
- 新 window 和 split 继承当前 pane 的工作目录。
- 已配置 lazygit、scratch shell 和 fzf session switcher popup。
- 状态栏当前为简洁的深色风格，活动 pane 使用蓝色边框。
- TPM 管理 `tmux-sensible`、`tmux-resurrect` 和 `tmux-continuum`。

## tmux 的主要可配置项

| 范围 | 常见选项 | 用途 |
| --- | --- | --- |
| 终端能力 | `default-terminal`、`terminal-features` | 真彩色、下划线、剪贴板和终端兼容 |
| 状态栏 | `status-style`、`status-left`、`status-right`、`status-position`、`status-justify` | 状态栏颜色、位置和内容布局 |
| 窗口标签 | `window-status-format`、`window-status-current-format`、对应的 `*-style` | 显示窗口序号、名称和状态 |
| Pane 边框 | `pane-border-style`、`pane-active-border-style`、`pane-border-lines` | 区分活动与非活动 pane |
| Pane 标题 | `pane-border-status`、`pane-border-format` | 在边框显示路径、命令或主机名 |
| 提示与模式 | `message-style`、`mode-style`、`clock-mode-colour` | 命令提示、复制模式和时钟的颜色 |
| 行为 | `mouse`、`history-limit`、`escape-time`、`focus-events` | 鼠标、滚动历史和编辑器响应 |
| 窗口与编号 | `base-index`、`pane-base-index`、`renumber-windows`、`automatic-rename` | 控制编号与窗口命名 |
| 快捷键 | `prefix`、`bind-key`、`unbind-key` 和 key tables | 分屏、导航、复制、popup 等交互 |
| Hooks | `set-hook` | 在创建窗口、切换客户端或主题改变时运行命令 |

样式可以直接使用十六进制颜色：

```tmux
set -g status-style "fg=#dcd7ba,bg=#1f1f28"
setw -g window-status-current-style "fg=#1f1f28,bg=#7e9cd8,bold"
```

状态栏和边框可以使用动态格式：

```tmux
#{session_name}
#{window_index}
#{window_name}
#{window_flags}
#{pane_current_path}
#{pane_current_command}
```

本机可通过以下命令探索当前选项、快捷键和格式值：

```sh
tmux show-options -g
tmux show-options -gw
tmux list-keys
tmux display-message -a
```

完整语法参见 [tmux 官方手册](https://man.openbsd.org/tmux.1)。

## 美化原则

### 1. 与现有工具使用统一色板

Neovim 当前实际启用 Kanagawa，因此首选方案是用 tmux 原生配置实现 Kanagawa 风格。这样可以与 Neovim 和 lualine 保持一致，同时减少主题插件带来的加载顺序和版本问题。

建议语义色：

- 背景：`#1f1f28`
- 普通前景：`#dcd7ba`
- 次要文字：`#727169`
- 当前窗口和活动边框：`#7e9cd8`
- 活动或提示：`#e6c384`
- 错误或响铃：`#e46876`

### 2. 保持清晰的视觉层级

状态栏背景保持低对比度，只重点突出：

- 当前 session 和 window
- 当前 pane 边框
- Prefix、复制模式或同步输入状态
- activity、bell 和 zoom 标记

当前配置开启了 `monitor-activity`，但窗口格式没有显示 `#F`。实施时应保留窗口状态标记，例如：

```tmux
setw -g window-status-format " #I:#W#F "
setw -g window-status-current-format " #I:#W#F "
```

### 3. 状态栏只保留高价值信息

推荐布局：

```text
[session]  1:zsh  2:nvim  3:server              path  host  time
```

不默认加入天气、公网 IP、CPU、内存等频繁执行外部命令的模块。只有确实会被使用的信息才进入状态栏。

### 4. 补齐交互状态的配色

除了 `status-style` 和 pane 边框，还应统一：

```tmux
set -g message-style "..."
set -g mode-style "..."
set -g copy-mode-match-style "..."
set -g copy-mode-current-match-style "..."
```

Powerline 分隔符和图标属于可选增强，需要 Nerd Font。即使缺少图标字体，状态栏文字也应保持可读。

## 主题候选

主题插件只选择一个，避免多个插件同时覆盖状态栏选项。

- [Catppuccin for tmux](https://github.com/catppuccin/tmux)：模块化程度高，提供 Latte、Frappé、Macchiato 和 Mocha；建议固定版本。
- [Dracula for tmux](https://github.com/dracula/tmux)：内置 CPU、内存、Git、网络、电池等大量模块，适合偏完整的状态栏。
- [tmux-powerline](https://github.com/erikw/tmux-powerline)：高度可扩展的分段式状态栏，但配置复杂度和外部命令开销更高。
- 原生 Kanagawa：与当前 Neovim 最协调、依赖最少，是本计划的首选。

## 功能增强候选

### 已安装

- [TPM](https://github.com/tmux-plugins/tpm)：插件管理器。
- [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible)：通用基础设置。
- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)：保存 session、window、pane、布局与工作目录。
- [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)：定时保存并自动恢复 tmux 环境。

### 推荐评估

- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator)：使用 `Ctrl-h/j/k/l` 在 Neovim split 与 tmux pane 之间无缝导航。
- [tmux-sessionx](https://github.com/omerxx/tmux-sessionx)：提供预览和 fuzzy finder 的 session 管理界面。
- [sesh](https://github.com/joshmedeski/sesh)：结合项目目录、Zoxide 和 tmux 管理 session；它是外部工具而不只是 TPM 插件。
- [tmux-which-key](https://github.com/alexwforsythe/tmux-which-key)：以 popup 展示快捷键菜单，适合绑定逐渐增多后的配置。
- [tmux-yank](https://github.com/tmux-plugins/tmux-yank)：跨 Linux 与 macOS 的系统剪贴板支持。当前配置已直接调用 `xclip`，仅在迁移到 Wayland 或需要跨平台时考虑。
- [tmux-open](https://github.com/tmux-plugins/tmux-open)：从复制模式快速打开 URL 或文件。
- [tmux-fzf](https://github.com/sainnhe/tmux-fzf)：通过 fzf 管理 session、window、pane 和 key bindings。

session 管理工具应在 `tmux-sessionx`、`sesh` 和 `tmux-fzf` 之间按实际工作流选择，避免功能重复。

## 实施计划

### 第一阶段：原生 Kanagawa 外观

- [ ] 提取并集中定义 Kanagawa 色板。
- [ ] 调整 status bar、当前窗口和非活动窗口样式。
- [ ] 给窗口格式加入 activity、bell、zoom flags。
- [ ] 统一 pane border、message、copy mode 和搜索匹配样式。
- [ ] 决定是否显示 pane 路径或当前命令。
- [ ] 在没有 Nerd Font 的终端中确认降级显示正常。

### 第二阶段：导航与 session 管理

- [ ] 评估并配置 `vim-tmux-navigator`，确认与 Neovim 快捷键无冲突。
- [ ] 在 `tmux-sessionx` 与 `sesh` 中选择一个。
- [ ] 移除或替换现有重复的 fzf session popup。
- [ ] 快捷键数量增加后再评估 `tmux-which-key`。

### 第三阶段：兼容与性能验证

- [ ] 重新加载配置并检查 tmux 报错信息。
- [ ] 验证真彩色、斜体和下划线显示。
- [ ] 验证 X11/Wayland 剪贴板行为。
- [ ] 验证 Neovim 内外的 pane 导航。
- [ ] 验证 resurrect/continuum 保存和恢复。
- [ ] 检查状态栏刷新是否执行高开销外部命令。
- [ ] 在本机终端和 SSH 环境分别测试。

## 预期最终组合

```text
原生 Kanagawa 状态栏
+ vim-tmux-navigator
+ tmux-sessionx 或 sesh（二选一）
+ 保留 tmux-resurrect / tmux-continuum
```

该组合兼顾一致的视觉风格、Neovim 导航和 session 持久化，同时避免状态栏过载和插件功能重复。

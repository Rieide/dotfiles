# Neovim Practice Notes

这份笔记记录当前配置下最值得优先练习的 Neovim 工作流，以及阅读
Practical Vim 时可以降优先级的内容。

## 优先练习清单

当前已经熟悉的基础：

- VimTutor 范围内的基础移动和编辑
- Telescope 提供的文件、文本、buffer 搜索
- clangd 的 LSP 快速跳转
- `<leader>ch` 在 C/C++ 中切换 source/header
- 多 buffer 和 buffer 切换

接下来优先练这些工作流。

### 1. which-key：当作按键菜单

忘记 keymap 时，先按 `<leader>` 停一下，看 which-key 提示。

当前主要分组：

```text
<leader>b  Buffer
<leader>c  Code
<leader>f  Find
<leader>g  Git
<leader>n  Notifications
<leader>s  Search
<leader>t  Toggle
<leader>x  Diagnostics
<leader>h  Git hunk
```

目标不是死记 keymap，而是先学会通过菜单发现功能。

### 2. Trouble：管理 diagnostics 和 LSP 列表

先练这几个：

```text
<leader>xx  全项目 diagnostics
<leader>xX  当前 buffer diagnostics
<leader>xs  当前文件 symbols
<leader>xl  LSP definitions/references 面板
```

Trouble 比单次跳转更适合查看一组问题、引用、symbols。

### 3. Gitsigns：边写边看改动

先练最常用的几个：

```text
]c          下一个 git hunk
[c          上一个 git hunk
<leader>hp  预览当前 hunk
<leader>hd  diff 当前文件
<leader>hb  blame 当前行
```

之后再练更有风险的操作：

```text
<leader>hs  stage 当前 hunk
<leader>hr  reset 当前 hunk
```

### 4. Conform 和 nvim-lint：代码清理

```text
<leader>cf  format 当前 buffer
<leader>cl  lint 当前 buffer
```

当前 format-on-save 是关闭的，格式化需要手动触发。

Shell 文件已经通过 `nvim-lint` 接入 `shellcheck`。保存、打开文件、离开
insert mode 时会自动 lint，也可以用 `<leader>cl` 手动跑。

### 5. Flash：屏幕内快速跳转

```text
<leader>j  Flash jump
<leader>J  Flash Treesitter jump
```

先只练 `<leader>j`。它适合替代“看得到目标位置，但需要按很多次
`w` / `j` / `k` 才能过去”的场景。

Flash 不是 Telescope 的替代品：

- Telescope：找文件、找文本、找 symbols
- Flash：在当前屏幕内快速移动光标

### 6. Telescope：继续深化

已经在用 Telescope 的基础搜索后，再补这些：

```text
<leader>fb  buffers
<leader>fo  old/recent files
<leader>/   当前 buffer 内 fuzzy search
<leader>fs  document symbols
<leader>fS  workspace symbols
<leader>sd  diagnostics
<leader>sk  keymaps
<leader>sc  commands
<leader>sr  resume 上次搜索
```

Bufferline 顶部显示的是全局位置编号，按这个显示编号跳转，不按当前可见
窗口内的位置跳转。单数字用 `<CR>` 确认，例如 `<leader>2<CR>`；两位数
直接输入，例如 `<leader>21`。`<leader>b2<CR>` / `<leader>b21` 也可用。

### 7. C/C++ LSP 跳转习惯

`<leader>ch` 只是 clangd 的 source/header switch，不适合作为通用跳转。
如果它在 source/header 之间来回切，优先用这些看完整 LSP 结果：

```text
grd          goto definition
grr          references
gri          implementation
grt          type definition
<leader>fd   find definitions
<leader>fr   find references
<leader>xl   Trouble LSP list
```

`<leader>ch` 只作为最后的手动兜底工具。

## Practical Vim 阅读建议

插件替代的是入口和界面，但 Vim 的编辑语法仍然需要学。

### 仍然非常值得认真看的部分

这些内容是 Vim 的核心生产力，插件不能替代：

- Normal mode grammar：`operator + motion`
- `.` 重复命令
- text objects：`iw`、`aw`、`i"`、`a)` 等
- Visual mode 的选择和修改
- registers：`"`、`0`、`+`、`_`
- marks 和 jumplist：`m`、`'`、`` ` ``、`Ctrl-o`、`Ctrl-i`
- macros：`q`、`@`
- search 基础：`/`、`?`、`n`、`N`、`*`
- substitution 基础：`:s`、`:%s`
- global command：`:g/pattern/command`
- undo / redo：`u`、`Ctrl-r`

### 可以降优先级或跳读的部分

#### 文件查找、打开文件、buffer 切换

Practical Vim 中关于 `:edit`、`:find`、`:args`、路径补全、buffer 管理的
许多内容，可以先用 Telescope 和 bufferline 覆盖：

```text
<leader>ff
<leader>fo
<leader>fb
<leader><leader>
<leader>1..9
```

但仍然要知道这些基础命令：

```text
:e
:w
:bd
:ls
```

#### grep / vimgrep / quickfix 搜索流程

项目搜索优先用 Telescope：

```text
<leader>fg
<leader>sg
<leader>fw
<leader>sr
```

Diagnostics / references 优先用 Trouble：

```text
<leader>xx
<leader>xl
```

Quickfix 仍然值得懂一点，但不用优先深学。

#### ctags 跳转

tags、`Ctrl-]`、tag stack 的优先级较低。C/C++ 主要依赖 clangd LSP：

```text
grd
grr
gri
grt
<leader>fd
<leader>fr
```

但跳转历史仍然要学：

```text
Ctrl-o
Ctrl-i
```

#### 插入模式补全

Vim 原生 completion 可以先跳过。当前主要依赖：

- `blink.cmp`
- `LuaSnip`
- `friendly-snippets`
- LSP completion

#### 复杂项目级替换

复杂的 `:argdo`、`:bufdo`、`:cfdo` workflow 可以先降优先级。

当前项目级 search/replace 可以用：

```text
<leader>sR  GrugFar
```

但单文件替换仍然必须掌握：

```text
:%s/foo/bar/g
```

## 建议阅读顺序

先看：

```text
Normal mode
Insert mode basics
Visual mode
Text objects and motions
Registers
Macros
Search
Substitution
Global command
```

后看或跳读：

```text
ctags
vimgrep/grep
quickfix-heavy workflow
native completion
file explorer / file navigation details
复杂 arglist/buffer list 批处理
```

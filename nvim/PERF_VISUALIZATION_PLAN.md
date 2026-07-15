# Neovim 性能剖析可视化实施计划

状态：设计阶段，尚未实现。

本文计划在 Neovim 中加入基于采样数据的源码热度标记、简略热点侧栏和
完整交互式火焰图。它不是 Git Blame 的扩展，也不把性能采样结果当作源码
事实；所有界面都必须明确展示当前加载的是一次离线 profile snapshot。

## 1. 归属与边界

这项能力的主要归属是 `nvim/`，因为用户直接接触的插件、按键、窗口、
高亮、状态管理和文档都属于 Neovim 配置。但生成和查看采样所需的系统工具
不应隐藏在编辑器配置中。

| 位置 | 负责内容 | 不负责内容 |
| --- | --- | --- |
| `nvim/` | PerfAnno 配置、profile session、逐行标记、热点侧栏、Snacks 浮窗、按键、帮助与测试 | 安装系统包、修改内核权限 |
| 根 `install.sh` | 检测并按仓库策略安装或验证 `perf`、`flamelens` 和必要的 stack collapse 工具 | 启动 profiler、替用户选择业务负载 |
| 项目/用户 | 以有代表性的负载生成 `perf.data`，决定采样范围、线程和事件 | 维护 dotfiles 的 UI 实现 |

边界规则：

- Neovim 第一版只加载已有采样，不自动以 `sudo` 启动 `perf`。
- 安装器不得自动修改 `kernel.perf_event_paranoid`、ptrace、capability 或其他
  系统安全设置。
- 不在 dotfiles 工作树内默认生成 `perf.data`、`perf.log`、SVG 或大型缓存。
- 派生缓存写入 `stdpath('cache')/perf-view/`，而不是 `nvim/` 或被分析项目。
- 项目命令必须由用户明确执行；不从不受信任的项目文件自动执行 shell。

## 2. 目标

完成后应支持以下工作流：

1. 显式选择一个 `perf.data` 或规范化 folded-stack 文件。
2. 从同一个 profile session 驱动三个一致的视图：
   - 源码行尾百分比和可选热度背景；
   - 当前文件或整个 workspace 的简略热点侧栏；
   - Lazygit 风格的全屏浮动火焰图。
3. 在事件、线程、范围或 profile snapshot 改变时原子更新全部视图。
4. 从热点项跳回正确的文件和行，并能查看调用者/被调用者。
5. 在二进制、Git HEAD 或源码状态不再匹配时显示 `STALE`；路径或符号无法
   解析时显示 `UNRESOLVED`，不继续展示看似精确但已经失效的数字。
6. `perf`、`flamelens` 或调试符号缺失时给出可操作提示，不影响普通 Neovim
   启动和编辑。

首要场景是带调试信息的 Linux C/C++ 程序；数据层保持 folded stacks
兼容，以便后续接入 Python、LuaJIT 或其他 profiler。

## 3. 非目标

第一版不做以下事情：

- 不替代 Git Blame、Gitsigns、测试覆盖率或 DAP 调试器。
- 不提供生产环境常驻 profiler 或自动 attach 任意进程。
- 不在 Neovim Lua 中重新实现 `perf record`、DWARF unwinding 或 SVG 渲染器。
- 不承诺纳秒级或逐行精确计时；采样结果始终是统计近似。
- 不默认显示实时刷新火焰图。
- 不自动上传、分享或提交可能含私有路径、符号名的 profile 数据。
- 不为获得调用栈而全局更改用户项目的编译参数。

## 4. 选型

### 4.1 源码标记与调用图数据

采用 [`t-troebst/perfanno.nvim`](https://github.com/t-troebst/perfanno.nvim)
作为首选底座：

- 要求 Neovim 0.10 或更新版本；
- 能读取 `perf.data`、完整调用图和 flamegraph folded 格式；
- 能显示逐行虚拟文本和热度高亮；
- 已提供热点行、热点 symbol、caller/callee 选择器；
- 能切换采样事件，并支持聚合或选择多线程数据；
- 已与当前配置使用的 Telescope、Treesitter 和 `vim.ui.select` 对接。

限制必须在实现前验证：

- `:PerfLoadFlameGraph` 只表示加载 folded 格式，不负责渲染完整火焰图。
- 当前逐行和 symbol count 是调用栈包含次数，包含嵌套调用，更接近
  inclusive/stack sample share；在 UI 中不得未经验证就标为 `self` 或 CPU
  utilization。
- README 没有承诺供外部侧栏读取热点列表的稳定 getter API。

只使用上游文档公开的 `setup()`、命令和 `load_traces()`。如果侧栏需要读取
内部 call graph，按以下优先级处理：

1. 先确认固定 commit 是否已有可用公开 API；
2. 没有则向上游增加或请求只读导出接口；
3. 再不行，由本仓库的 adapter 解析规范化 folded 数据，同时把同一份 traces
   传给 `perfanno.load_traces()`；
4. 不直接依赖未文档化的 Lua 模块布局或 monkey patch 插件内部状态。

插件通过 lazy.nvim 声明，并由 `lazy-lock.json` 固定 commit；不得使用浮动
版本绕过仓库已有的可复现策略。

当前上游实现还有两个必须在 spike 中复验的风险：其 `perf` 路径处理对 argv
使用了面向 Ex 命令的 `fnameescape()`，带空格路径可能失败；call graph 解析
使用同步 `vim.system(...):wait()`，大型数据可能冻结 UI。若固定 commit 仍有
这些行为，正式入口必须走本仓库的异步 adapter，不能仅包一层上游命令。

### 4.2 完整火焰图

首选 [`YS-L/flamelens`](https://github.com/YS-L/flamelens)：它接受 folded
stacks，在终端中提供 Vim 风格移动、搜索和缩放。通过现有
`Snacks.terminal` 放入全屏浮窗，不再新增 FTerm、ToggleTerm 或另一套通用
窗口框架。

回退顺序：

1. `flamelens` 终端 TUI；
2. Brendan Gregg FlameGraph 生成的 SVG，在外部浏览器打开；
3. 若两者均不可用，保留 PerfAnno 行标记和 Telescope 热点列表。

在确定安装策略前必须核对上游发布资产、架构、校验和与许可证。若没有可审计
的 Linux 二进制，不应仅为该查看器无条件安装完整 Rust toolchain；Cargo
安装只能作为用户明确选择的路径。

### 4.3 UI 基础设施

复用仓库现有能力：

- `Snacks.terminal`：托管 `flamelens` 及浮窗生命周期；
- `Snacks.win` 或原生 `nvim_open_win()`：必要的只读浮窗；
- Telescope：热点行、函数和 caller/callee 的临时选择器；
- Neovim extmark：行尾虚拟文本、行高亮和可选 sign；
- which-key：新增统一的 `<leader>p` Profile 分组。

不引入新的通用 picker、侧栏框架或终端管理插件。

## 5. 数据模型与处理管线

### 5.1 单一 session

三个视图必须读取同一个不可变 profile session。建议模型至少包含：

```text
source_path       原始 perf.data 或 folded 文件
fingerprint       源文件大小、mtime 和内容摘要组合
loaded_at         加载时间
repo_root         采样关联的项目根目录（若可确定）
git_head          采样时的提交（若有 manifest）
binary_build_ids  perf 数据中的 build-id（若可获得）
event             cycles / instructions / cache-misses / ...
thread_filter     all 或选中的 TID 集合
total_samples     当前过滤后的样本总数
traces            规范化调用栈和计数
line_index        file -> line -> inclusive/(optional self)/count
symbol_index      symbol -> inclusive/(optional self)/callers/callees
state             loading / valid / unknown / stale / unresolved / failed
diagnostics       缺符号、丢样本、路径不匹配等告警
```

加载新数据时先在后台构建新 session；成功后一次性替换旧 session。加载失败
时保留旧 session，但明显提示失败，不能留下半更新的侧栏或 extmark。

### 5.2 Manifest 与 artifact 合约

profile 可以来自当前项目、容器、远程机器或不同源码前缀。为了判断数据是否
仍可信，推荐每次采样形成一个目录：

```text
profile/
├── perf.data                 可选的原始数据
├── stacks.folded             给 flamelens 的普通 folded stacks
├── source-stacks.folded      可选，含 symbol + canonical file:line
└── profile.meta.json         provenance、过滤器和路径映射
```

`profile.meta.json` 至少规划以下字段：

```text
schema_version / profile_id / captured_at
host / kernel / perf_version
event / frequency_or_period / callgraph_mode
pid_tid_filters / cwd
git_root / git_head / git_dirty
binary_paths / DSO build_ids
source_root / explicit path_prefix_maps
referenced_source_hashes
redacted_command
```

普通 flamelens folded frame 可以只有函数名，不能保证 PerfAnno 所需的
`symbol /canonical/file.cpp:line`。因此不得默认“一份 folded 同时服务所有
视图”。加载 source-aware artifact 时先统计可解析 `file:line` 的 frame 和
sample 比例；比例过低时保留函数级火焰图，源码 overlay 标记 `UNRESOLVED`
并解释缺少什么信息。

manifest 是推荐的可信度来源，但第一版仍允许用户显式加载单个 artifact；
这种 session 必须显示 `UNKNOWN`，不能显示成已验证的 `VALID`。

### 5.3 数据流

```text
perf.data
   |
   +--> source-aware parser --> normalized traces --> line annotations
   |                                  |             --> hotspot sidebar
   |                                  +-------------> Telescope pickers
   |
   +--> perf script + collapse --> stacks.folded --> flamelens float
```

如果 PerfAnno 和 flamelens 需要不同派生格式，两者仍必须由同一个
`perf.data`、event 和 thread filter 生成，并共享 session fingerprint。

### 5.4 异步、输入约束与缓存

- 使用 `vim.system()` 的 argv 数组调用外部命令，禁止拼接未转义 shell 字符串。
- 只接受用户显式选择的普通文件；规范化为绝对路径，并对空路径、前导 `-`、
  换行、控制字符、非当前用户文件和 workspace 外源码给出确认或拒绝。
- 加载前检查文件类型、ownership 和大小；超出可配置阈值时先确认，防止损坏或
  恶意 profile 耗尽内存、CPU 或终端。
- frame 名、线程名和错误输出在写入 buffer 前去除终端控制序列。
- 大型 `perf.data` 的解析不得阻塞 UI；提供进度通知和取消旧请求的机制。
- 缓存目录使用 profile fingerprint 分层，缓存只保存可重新生成的派生数据。
- 缓存目录和临时文件按私有数据处理，目标权限分别为 `0700` 和 `0600`；
  不扩大 group/world 读取权限。
- 为缓存设置可配置的大小或年龄上限，并只删除本插件管理的目录。
- 同一路径在解析期间再次加载时去重；新请求到达后废弃旧回调结果。
- 不在启动时自动加载“最近一次”缓存；每个 session 都由用户显式加载。

## 6. UI 与交互规范

### 6.1 按键和命令

当前 `<leader>p` 未被仓库占用，规划为 `[P]rofile` 分组：

| 按键 | 命令 | 行为 |
| --- | --- | --- |
| `<leader>pl` | `:PerfViewLoad [path]` | 选择并加载 profile |
| `<leader>pt` | `:PerfViewToggle` | 切换当前 buffer 的逐行标记 |
| `<leader>ps` | `:PerfViewSidebar` | 切换热点侧栏 |
| `<leader>pf` | `:PerfViewFlame` | 打开完整火焰图浮窗 |
| `<leader>ph` | `:PerfViewHotspots` | 打开热点 Telescope picker |
| `<leader>pe` | `:PerfViewEvent` | 选择事件并统一刷新视图 |
| `<leader>pT` | `:PerfViewThread` | 选择线程或聚合全部线程 |
| `<leader>pj` | `:PerfViewNext` | 跳到下一个热点源码位置 |
| `<leader>pk` | `:PerfViewPrev` | 跳到上一个热点源码位置 |
| `<leader>pc` | `:PerfViewClear` | 清除 session、侧栏和 extmark |
| `<leader>pi` | `:PerfViewInfo` | 显示 snapshot、事件、线程和告警 |

不使用 `[p`/`]p`，因为它们是 Vim 已有的缩进粘贴命令。命令名使用本仓库的
`PerfView` 前缀，避免与 PerfAnno 自带命令混淆。

### 6.2 逐行标记

- 优先用右对齐或 EOL virtual text，避免与 Gitsigns 的 sign column 争用。
- PerfAnno 当前把 virtual text 固定在 EOL；若保留它的原生 overlay，必须验证
  与现有 diagnostic virtual text 同行时的拥挤和优先级。需要 right-align 时
  应实现自有 overlay，而不是假设 `setup()` 支持该位置选项。
- 默认仅显示超过当前范围 `0.5%` 的行，阈值可配置。
- 热度采用 8--10 档、随主题背景计算的渐变；不能假设所有主题都是深色。
- 文本必须明确指标语义。MVP 使用 `stack 12.4%` 或 `incl 12.4%`，表示当前
  event、thread filter 和分母下的样本占比，不称为“CPU 使用率”。
- `self` 只统计叶 frame；`total` 表示该 frame 及其后代。若第一版只能可靠
  得到 inclusive count，就只显示 stack/inclusive；递归和 inline 场景的
  self/total 算法通过单测后才允许增加对应列。
- 默认 `annotate_after_load=false`、`annotate_on_open=false`；加载和校验完成后
  由用户显式标记当前 buffer，避免一次创建过多 extmark。
- 设置每个 buffer 的最大标记数，不在 `CursorMoved` 上重新解析或全量排序。
- 当前 buffer 有未保存修改、文件内容与 snapshot 不匹配或 session stale 时，
  立即隐藏数值并显示一次非阻断告警。
- 标记只应用于普通文件 buffer；忽略 help、terminal、neo-tree、Trouble、
  blame panel、profile sidebar 等特殊 filetype。

### 6.3 简略热点侧栏

侧栏为右侧只读窗口，默认宽度 40 列，并在 36--48 列之间根据屏幕宽度约束。
窄屏下不强行打开，改用 Telescope picker。

默认布局：

```text
CPU HOTSPOTS
cycles | all threads
current file | VALID

 STACK  SYMBOL
  41.8  Process...
  12.1  memcpy
  19.3  Deserialize

<Enter> jump  f flame
e event  t thread  q close
```

功能要求：

- 在 `current file` 和 `workspace` 两种范围间切换；默认当前文件。
- 默认列出前 15 个 symbol，支持滚动，不一次渲染整个调用图。
- `Enter` 跳到最热的可解析源码位置；没有源码位置时只显示详情。
- panel-local `K` 显示完整 symbol、DSO、样本数、分母、百分比、
  caller/callee 摘要和告警；不得覆盖源码 buffer 已有的 LSP hover `K`。
- `e`、`t` 修改共享 session 过滤器；`f` 打开同一 session 的完整火焰图。
- 标题始终包含事件、线程、scope/denominator、采样时间和
  `VALID`/`UNKNOWN`/`STALE`/`UNRESOLVED` 状态。
- MVP 只显示 PerfAnno 能证明的 stack/inclusive count。SELF/TOTAL 双列只有在
  自有 trace 聚合层正确处理 leaf、递归和 inline 且测试通过后才启用。
- 路径只在详情中显示，列表避免泄露或挤占可读空间。
- 打开前计算剩余可用列。右侧 Trouble/Neo-tree 或其他用户窗口使空间不足时，
  不关闭它们，也不挤压源码，直接回退 Telescope；初始建议 `<100` 列视为窄屏，
  最终阈值由布局测试确定。
- 热点排行不与源码逐行对应，侧栏不得复制 Blame 的 `scrollbind` 或
  `cursorbind` 行为。

### 6.4 右侧面板协调

现有 Blame panel 也占右侧。新增一个很薄的 `custom.context_panel` 协调层，只
管理本仓库创建的上下文面板：

- Blame 和 Perf sidebar 互斥；打开一个时安全关闭另一个。
- 不自动关闭 Neo-tree、Trouble、quickfix 或用户手动创建的 split。
- 协调层只记录 owner、窗口 ID 和 owner 提供的 close callback。
- owner 崩溃或窗口被用户关闭时自动释放，不留下失效句柄。
- 复用现有 `custom.blame_column_controller.close()`，让 Blame toggle 也通过同一
  slot 关闭 Perf；不把 perf 逻辑写入其 1,000 多行的控制器。
- Perf split 设置 `winfixwidth`。当前 `init.lua` 会在 `VimResized`、`WinNew` 和
  `WinClosed` 后调度 `wincmd =`，必须验证新侧栏不会被错误拉伸，并在必要时
  让全局 equalize 跳过受管上下文窗口，而不是依靠时序竞争。

### 6.5 全屏浮动火焰图

使用 `Snacks.terminal.open({ 'flamelens', folded_path }, opts)`，命令以 argv
数组传递。建议视觉参数：

```lua
win = {
  position = 'float',
  width = 0.96,
  height = 0.94,
  border = 'rounded',
  backdrop = 60,
  wo = { winblend = 30 },
}
```

`winblend = 30` 表示浮窗约 70% 不透明，与当前 Telescope 风格一致；普通
split 侧栏仍是不透明窗口。`backdrop` 是后方遮罩，不是 panel opacity。两者
必须分别测试。`winblend` 是 UI-dependent 的伪透明，因此需在 TUI、tmux 和
使用中的主题上实测可读性；如果火焰图文字对比不足，允许单独降到 `15` 或
`0`，不能牺牲信息可读性。

行为要求：

- 浮窗随 `VimResized` 调整，关闭后恢复原焦点和窗口布局。
- 使用 flamelens 自带 `hjkl`、`Enter`、`/`、`n`/`N`、`Esc` 和 `q`。
- 不重绑定 flamelens 的 `Esc`，因为它用于退出 zoom；`q` 负责关闭。
- 不存在可用 folded 数据时先生成或明确报错，不打开空终端。
- `flamelens` 缺失时提示安装状态并保留其他两个视图。
- profile 路径含空格、引号或 shell 元字符时仍能安全打开。
- 显式 `open` 新实例或把 profile fingerprint 放入 terminal identity，不能让
  Snacks `toggle` 复用上一次 profile 的旧进程。
- controller 持有 Snacks terminal handle。term-mode 的 `q` 由 flamelens
  退出并触发 `auto_close`；normal-mode 下 Snacks 默认 `q` 只隐藏窗口，因此
  `PerfViewClear` 和真正 close 必须显式终止 job/销毁 buffer，或把产品语义明确
  定义为可恢复的 hide，不能一边隐藏一边宣称“无残留进程”。

## 7. Stale 与可信度规则

任何一个条件满足时 session 或对应文件标记为 stale：

- 当前 buffer 有未保存修改；
- 磁盘文件 mtime/size 或可用摘要与加载时不同；
- manifest 中记录的 Git HEAD 与当前 HEAD 不同；
- manifest 中的 build-id 与 `perf.data` 或当前二进制不一致；
- profile 派生缓存 fingerprint 不匹配；
- 切换 event/thread 的派生过程失败，导致视图可能不同步。

处理策略：

- stale 状态不自动重新采样，也不执行构建命令。
- 行尾数字和背景高亮立即隐藏；侧栏保留结构但加醒目 `STALE`。
- 完整火焰图仍可供历史分析，但标题必须标记 stale。
- 用户可以显式 reload 新数据或清除 session；不提供“忽略并永久信任”。

第一版允许 profile 没有 manifest，此时 UI 显示 `UNKNOWN`，至少执行文件
存在性、buffer modified 和 profile fingerprint 检查。路径映射或源码行无法
解析时使用 `UNRESOLVED`，不要把它混同为数据已经过期。

## 8. 外部工具安装计划

该部分最终修改根 `install.sh`，但由本文记录 Neovim 功能需要的契约。

### 8.1 `perf`

- 先检测 `command -v perf`、`perf version` 和一次非特权能力探测。
- Ubuntu 的 `perf` 必须与运行内核兼容；实现前在 Ubuntu 26.04 和 WSL 基线
  确认正确包名，不能仅假设 `linux-tools-generic` 足够。
- 如果内核对应包不可获得，将该工具标记 `FAILED`/manual action，不修改 sysctl。
- 安装器只验证命令可用；采样权限不足在使用时提供文档指引。

### 8.2 `flamelens` 与 collapse 工具

- 固定具体版本，不跟踪 `latest`。
- 优先采用上游发布的架构匹配二进制及可验证 checksum。
- 若上游没有合适二进制，先评估 Brendan Gregg 的 Perl stack collapse + SVG
  是否足以作为无 Rust 回退，再决定是否引入 Cargo。
- 不使用未经固定版本和校验的 `curl | sh`。
- `flamelens` 是 optional/recommended：失败不应阻止 PerfAnno 行标记工作，但
  安装汇总必须准确显示 full flame view 不可用。

### 8.3 版本契约

实现时在 `install.sh` 的集中数组中登记命令名、provider、最低/固定版本和
版本探测，不在 Neovim Lua 中复制版本真相。Neovim 只检查 executable 并显示
能力状态。

## 9. 预计文件布局

```text
nvim/
├── PERF_VISUALIZATION_PLAN.md
├── README.md
├── PRACTICE.md
├── tests/
│   ├── fixtures/sample.folded
│   ├── perf_profile_spec.lua
│   ├── perf_sidebar_spec.lua
│   └── run-headless.sh
└── .config/nvim/
    └── lua/custom/
        ├── context_panel.lua
        ├── perf/
        │   ├── init.lua
        │   ├── session.lua
        │   ├── adapter.lua
        │   ├── overlay.lua
        │   ├── sidebar.lua
        │   └── flame.lua
        └── plugins/
            └── perfanno.lua
```

同时预计修改：

- `nvim/.stow-local-ignore`：本计划创建时已预先忽略仓库测试目录和计划文件；
- `nvim/.config/nvim/lua/custom/plugins/init.lua`：注册插件 spec；
- `nvim/.config/nvim/init.lua`：注册 which-key Profile 分组；
- `nvim/.config/nvim/lazy-lock.json`：固定 PerfAnno commit；
- `nvim/PRACTICE.md`：记录日常操作和指标解释；
- `nvim/README.md`：记录依赖、数据边界和验证方式；
- 根 `install.sh`/`README.md`/`TODO.md`：只记录外部工具与 bootstrap 状态。

`nvim/tests/` 是仓库测试，不应被 GNU Stow 链接到 `$HOME/tests`；当前
`.stow-local-ignore` 已预先加入 `^/tests(?:/|$)`，实施时仍需以 dry-run
验证。

## 10. 分阶段实施

每阶段应独立可验证、可回滚，不以一个超大提交同时引入安装器、解析器和 UI。

### 阶段 0：兼容性 spike

- 当前开发环境探测基线（2026-07-15）是 Ubuntu 20.04.6、Linux
  5.15.0-139 x86_64、Neovim 0.12.4；PATH 中没有 `perf`、`flamelens`、
  Inferno/FlameGraph collapse 工具、Cargo 或 Rust。它只用于开发期缺依赖和
  UI 测试，不扩大仓库声明的 Ubuntu 26.04 目标支持范围。
- [ ] 记录当前 `/snap/bin/nvim --version`、`perf version` 和终端颜色能力。
- [ ] 在临时目录编译一个带调试信息的小型 C/C++ fixture，并生成短时
      `perf.data`。
- [ ] 验证 PerfAnno 固定 commit 在当前 Neovim 上能加载 flat、call graph 和
      folded 数据。
- [ ] 验证多线程选择、event 切换、完整路径和带空格路径。
- [ ] 复现并决定如何绕过固定 PerfAnno commit 的 `fnameescape()` 路径问题和
      同步 `wait()` 阻塞；没有异步、argv-safe 路径时不得进入正式接入。
- [ ] 统计 source-aware folded 的 file:line 可解析比例，并验证普通 folded
      仍可独立打开 flamelens，而不会产生空白但看似成功的源码 overlay。
- [ ] 确认 PerfAnno 公开的 inclusive 数据和只读热点 API，并判断自有 adapter
      是否能可靠增加 self；记录 API 决策。
- [ ] 验证 flamelens 在 tmux、当前主题和 70% 不透明浮窗中的可读性与 resize。
- [ ] 确定 Ubuntu 26.04/WSL 的 `perf` 包与 flamelens 可审计安装来源。

退出条件：能把一个已知热点映射到 fixture 的预期源码行，且完整火焰图能从
同一份 profile 打开。任何关键项失败时先更新本计划，不进入正式接入。

### 阶段 1：PerfAnno 最小接入

- [ ] 新增 lazy.nvim spec，按命令懒加载并固定 commit。
- [ ] 配置主题自适应的行高亮、virtual text 和最小显示阈值。
- [ ] 设置 `annotate_after_load=false`、`annotate_on_open=false`，只显式标记
      当前 buffer；验证 EOL 标记与 diagnostics 同行时仍可读。
- [ ] 保留上游原生命令用于诊断，同时添加稳定的 `PerfView*` wrapper。
- [ ] 注册 `<leader>p` which-key 分组和 load/toggle/hotspots/clear 基础按键。
- [ ] 确保无 `perf`、无 profile 和普通启动路径零报错。
- [ ] 更新 lockfile、README 和最小实践文档。

退出条件：手动加载 fixture 后可以标记正确行、打开热点 picker、清除所有标记；
不打开 profile 时启动时间和 UI 不发生可感知变化。

### 阶段 2：统一 session 与可信度

- [ ] 实现 immutable session、事件/线程过滤和原子替换。
- [ ] 将外部命令改为异步 argv 调用，支持取消过期请求。
- [ ] 实现受控缓存和 fingerprint。
- [ ] 实现 modified、mtime、Git HEAD/build-id（有数据时）检查。
- [ ] 在 overlay、picker 和状态命令中统一显示
      VALID/UNKNOWN/STALE/UNRESOLVED/FAILED。
- [ ] 增加加载竞争、失败保留旧 session 和清除资源测试。

退出条件：任一过滤器变化不会让三个消费者看到不同 session；修改源码后旧
数字立即消失。

### 阶段 3：热点侧栏

- [ ] 完成公开 API 决策，不依赖 PerfAnno 私有模块。
- [ ] 先实现 current-file/workspace 的 INCL/STACK 排行；只有 leaf/递归/inline
      聚合测试通过后才增加 SELF/TOTAL 双列。
- [ ] 实现跳转、详情、event/thread 切换和窄屏回退。
- [ ] 抽取 `custom.context_panel`，让 Blame/Perf sidebar 安全互斥。
- [ ] 验证不关闭 Neo-tree、Trouble 和用户 split，关闭后恢复焦点。
- [ ] 验证全局 `wincmd =`、`winfixwidth`、窄屏回退，以及 Blame/Perf 双向
      claim/close；热点侧栏不启用 scrollbind/cursorbind。
- [ ] 为窗口被外部关闭、buffer wipeout、tab 切换和 resize 添加测试。

退出条件：侧栏能稳定列出、排序并跳转 fixture 热点，且不破坏现有 Blame
panel 生命周期。

### 阶段 4：全屏火焰图浮窗

- [ ] 确认并实现 `flamelens`/collapse 工具的固定安装策略。
- [ ] 从共享 session 生成带 fingerprint 的 folded 文件。
- [ ] 通过 Snacks terminal 以 argv 数组启动 flamelens。
- [ ] 应用 96% x 94%、圆角边框、backdrop 和 `winblend=30`。
- [ ] 实现缺工具、生成失败、空数据和 stale 标题。
- [ ] 验证搜索、zoom、退出、resize、tmux 导航和 Neovim 焦点恢复。
- [ ] 分别验证 term-mode `q`、normal-mode hide、显式 close/clear 和进程异常；
      明确每条路径是保留 session 还是终止 job。

退出条件：从侧栏按 `f` 能打开同一 event/thread 的完整火焰图，关闭后没有
残留 terminal job、buffer 或窗口。

### 阶段 5：安装器、文档与真实工作负载验收

- [ ] 在根安装器集中登记并验证外部工具；保持 best-effort 汇总语义。
- [ ] 在临时 HOME 和 skip-remote/dry-run 模式验证安装状态机。
- [ ] 补全 `nvim/README.md`、`PRACTICE.md`、根 README/TODO。
- [ ] 用真实 C/C++ 工作负载验证符号、内联、线程和较大 profile 性能。
- [ ] 记录 DWARF 与 frame-pointer 两种采样方式的取舍，不强制项目全局配置。
- [ ] 完成最终回归、独立审查和小提交整理。

退出条件：新机器能够得到清晰的安装汇总；缺任一 optional 工具时配置仍可用；
真实 workload 的热点能在行标记、侧栏和完整图之间一致定位。

## 11. 测试策略

### 11.1 自动化测试

使用一个小型、可读的 checked-in folded fixture，避免把大型二进制
`perf.data` 提交到仓库。覆盖：

- parser 对 symbol、绝对路径、空格路径、未知 frame 和坏行的处理；
- self/total 聚合、排序、阈值和 event/thread filter；
- session 原子切换、取消、失败回滚和 cache fingerprint；
- extmark 创建、更新、清除、特殊 buffer 忽略和 stale 隐藏；
- 侧栏排序、跳转、窄屏回退和上下文面板互斥；
- flamelens 缺失、非零退出和 command argv 安全；
- 普通 folded 与 source-aware folded 的能力降级、可解析比例和状态；
- 文件名包含空格、单引号、分号和 `$()` 文本时不触发 shell 执行；
- frame/thread 文本中的 ANSI/OSC 控制序列不会污染终端或执行链接；
- tab/window/buffer 被用户提前关闭后的幂等清理。

外部命令在单元测试中使用 fake executable，不依赖本机 profiler 权限。

### 11.2 集成测试

- 用小型 C/C++ fixture 生成真实 `perf.data`，热点循环应明显排第一。
- 分别验证 `--call-graph dwarf` 和 frame-pointer 路径。
- 验证单线程、多个命名线程、用户态/内核 frame 和缺 debug symbols。
- 在源码改动、切换 commit、重新编译后验证 stale 状态。
- 在 tmux 内外、至少两种当前可选主题和 80/120/180 列终端宽度下验证 UI。
- 覆盖 Blame、Trouble、Neo-tree、diagnostic virtual text、ColorScheme 和全局
  equalize 的组合；重复打开/关闭至少 20 次后无孤儿 autocmd、timer 或窗口。
- 分别验证 flamelens term-mode/normal-mode 的 `q`、zoom `Esc` 和异常退出。
- 对较大 profile 记录加载耗时、UI 卡顿和缓存命中时间。

### 11.3 仓库回归命令

计划实现后至少执行：

```sh
git diff --check
/snap/bin/nvim --headless '+lua print("nvim-ok")' '+quitall'

XDG_DATA_HOME=/tmp/nvim-perf-test-data \
XDG_CACHE_HOME=/tmp/nvim-perf-test-cache \
XDG_STATE_HOME=/tmp/nvim-perf-test-state \
/snap/bin/nvim --headless -u nvim/.config/nvim/init.lua \
  '+lua dofile("nvim/tests/perf_profile_spec.lua")' '+quitall'

mkdir -p /tmp/dotfiles-stow-perf-check
stow --no --verbose=2 --target=/tmp/dotfiles-stow-perf-check nvim
```

`nvim/tests/run-headless.sh` 必须自行创建、使用并清理独立临时 XDG 目录，不依赖
当前 HOME 的插件、缓存或状态。还需执行隔离 XDG 的 `Lazy! sync`，并确认对空
target 的 Stow dry-run 不会规划链接计划或测试文件。

## 12. 验收标准

全部满足才算完成：

- [ ] 没有 profile 和没有外部工具时，Neovim 正常启动且无错误通知。
- [ ] 同一 profile 的 event/thread/scope/denominator/样本总数在行标记、侧栏和
      火焰图中一致；百分比不被错误称为 CPU utilization。
- [ ] 已知 fixture 热点能定位到预期源码行；无法精确定位时显示告警而非伪精确。
- [ ] 行尾百分比默认明确标注 INCL/STACK；只有聚合算法测试通过后才出现 SELF，
      阈值、diagnostic 共存和颜色在所有启用主题下可读。
- [ ] 侧栏在当前文件和 workspace 范围正确排序，跳转和详情工作。
- [ ] Blame/Perf 面板互斥，但 Neo-tree、Trouble 和普通 split 不被擅自关闭。
- [ ] 全屏浮窗默认约 70% 不透明、可 resize、可搜索/zoom，并能干净退出。
- [ ] 修改源码或切换不匹配构建后视图显示 stale，不保留有效外观的旧数字。
- [ ] 路径和命令参数不经过 shell 拼接；插件不自动提权或修改系统安全配置。
- [ ] 缓存和 profile 数据不进入 Git，不在工作树或 HOME 根目录留下垃圾。
- [ ] headless、fixture、真实 perf、Stow 和 bootstrap 回归均通过。
- [ ] README/PRACTICE/TODO 与实际实现一致，不提前勾选未完成能力。

## 13. 建议提交顺序

```text
docs(nvim): plan profiler visualization workflow
nvim: add pinned PerfAnno baseline
nvim: add profile session and stale-state handling
nvim: add source heat annotations and hotspot navigation
nvim: add coordinated performance sidebar
nvim: open flamelens in a Snacks profile float
bootstrap: manage optional profiling tools
test(nvim): cover profile views and lifecycle
docs(nvim): document profiling practice and limitations
```

每个提交均应保持 headless Neovim 可启动；安装器提交单独验证，避免 UI 回归和
系统包状态机问题混在同一个 diff 中。

## 14. 回滚方案

- 删除 PerfAnno spec 和 `custom/perf/` 模块即可恢复原编辑器功能。
- 删除 which-key Profile 分组和相关 keymap，不触碰原有 Gitsigns/Blame 按键。
- `custom.context_panel` 若已被 Blame 共用，保留其兼容接口或先回退 Blame 调整。
- 从 lockfile 移除插件记录；外部 optional 工具可保留，不影响 Neovim。
- 清理只限 `stdpath('cache')/perf-view/`；绝不自动删除用户提供的 `perf.data`。

## 15. 实现前仍需确认的决策

| 决策 | 默认方向 | 必须取得的证据 |
| --- | --- | --- |
| PerfAnno 侧栏数据接口 | 公开 API 或自有 adapter | 固定 commit 的 API/测试结果 |
| 行尾默认指标 | 明确的 `INCL/STACK`，有证据后再加 `SELF` | fixture 聚合结果 |
| `perf` provider | Ubuntu 内核匹配包 | U26/WSL 实机验证 |
| flamelens provider | 固定二进制优先 | release asset、checksum、架构 |
| 调用栈方式 | 文档同时支持 DWARF/fp | 真实 workload 的准确性和开销 |
| 浮窗透明度 | `winblend=30` | tmux/主题下的可读性 |
| live profiling | 第一版关闭 | 离线流程稳定后再单独评估 |

这些问题是实施阶段的验证闸门，不授权用未经审计的下载方式、私有插件 API 或
自动提权来绕过。

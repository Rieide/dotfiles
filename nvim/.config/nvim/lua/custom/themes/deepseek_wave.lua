local M = {}

M.name = 'deepseek-wave'

-- DeepSeek's cool neutral scale, lowered onto a true xterm-black canvas.
-- Keep these semantic names as the public tuning surface for this theme.
M.palette = {
  black = '#000000',
  ink = '#08080A',
  base = '#0F0F0F',
  surface = '#151517',
  surface_high = '#1B1B1C',
  overlay = '#232324',
  overlay_high = '#2C2C2E',
  cursor_line = '#142442',
  selection = '#283142',
  divider = '#61666B',
  border = '#43454A',

  fg = '#F9FAFB',
  fg_dim = '#CFD3D6',
  muted = '#81858C',
  subtle = '#61666B',

  blue = '#5686FE',
  blue_dim = '#4176E6',
  blue_dark = '#34415B',
  sky = '#74C0FC',
  cyan = '#4DABF7',
  green = '#69DB7C',
  pink = '#FAA2C1',
  orange = '#FFA94D',
  violet = '#B197FC',
  red = '#F25A5A',
  yellow = '#F7AD31',
  punctuation = '#CED4DA',
}

local p = M.palette

local kanagawa_palette = {
  sumiInk0 = p.ink,
  sumiInk1 = p.base,
  sumiInk2 = p.surface,
  sumiInk3 = p.black,
  sumiInk4 = p.surface,
  sumiInk5 = p.surface_high,
  sumiInk6 = p.border,

  waveBlue1 = p.selection,
  waveBlue2 = p.blue_dark,

  winterGreen = '#10261A',
  winterYellow = '#302711',
  winterRed = '#301316',
  winterBlue = '#111A31',
  autumnGreen = p.green,
  autumnRed = p.red,
  autumnYellow = p.yellow,

  samuraiRed = p.red,
  roninYellow = p.yellow,
  waveAqua1 = p.cyan,
  dragonBlue = p.blue,

  oldWhite = p.fg_dim,
  fujiWhite = p.fg,
  fujiGray = p.muted,

  oniViolet = p.pink,
  oniViolet2 = p.orange,
  crystalBlue = p.violet,
  springViolet1 = p.blue,
  springViolet2 = p.punctuation,
  springBlue = p.sky,
  lightBlue = p.sky,
  waveAqua2 = p.cyan,

  springGreen = p.green,
  boatYellow1 = p.yellow,
  boatYellow2 = p.yellow,
  carpYellow = p.orange,
  sakuraPink = p.cyan,
  waveRed = p.pink,
  peachRed = p.red,
  surimiOrange = p.orange,
  katanaGray = p.subtle,
}

local wave = {
  ui = {
    fg = p.fg,
    fg_dim = p.fg_dim,
    fg_reverse = p.black,

    bg_dim = p.ink,
    bg_m3 = p.ink,
    bg_m2 = p.base,
    bg_m1 = p.surface,
    bg = p.black,
    bg_p1 = p.surface,
    bg_p2 = p.surface_high,
    bg_gutter = p.black,

    special = p.blue,
    nontext = p.subtle,
    whitespace = p.border,
    bg_search = p.blue_dark,
    bg_visual = p.selection,

    pmenu = {
      fg = p.fg_dim,
      fg_sel = p.fg,
      bg = p.surface_high,
      bg_sel = p.overlay_high,
      bg_sbar = p.overlay,
      bg_thumb = p.border,
    },
    float = {
      fg = p.fg_dim,
      bg = p.surface_high,
      fg_border = p.divider,
      bg_border = p.surface_high,
    },
  },
  syn = {
    string = p.green,
    variable = 'none',
    number = p.cyan,
    constant = p.cyan,
    identifier = p.fg_dim,
    parameter = p.orange,
    fun = p.violet,
    statement = p.pink,
    keyword = p.pink,
    operator = p.fg_dim,
    preproc = p.sky,
    type = p.cyan,
    regex = p.yellow,
    deprecated = p.subtle,
    comment = p.muted,
    punct = p.punctuation,
    special1 = p.sky,
    special2 = p.red,
    special3 = p.orange,
  },
  vcs = {
    added = p.green,
    removed = p.red,
    changed = p.yellow,
  },
  diff = {
    add = '#10261A',
    delete = '#301316',
    change = '#111A31',
    text = '#1A2B52',
  },
  diag = {
    ok = p.green,
    error = p.red,
    warning = p.yellow,
    info = p.blue,
    hint = p.sky,
  },
}

local function overrides(colors)
  local theme = colors.theme

  return {
    -- Core editor: black canvas with restrained neutral elevation.
    Normal = { fg = p.fg, bg = p.black },
    NormalNC = { fg = p.fg_dim, bg = p.black },
    NormalFloat = { fg = p.fg_dim, bg = p.surface_high },
    FloatBorder = { fg = p.divider, bg = p.surface_high },
    FloatTitle = { fg = p.blue, bg = p.surface_high },
    FloatFooter = { fg = p.muted, bg = p.surface_high },
    Cursor = { reverse = true },
    CursorLine = { bg = p.cursor_line },
    CursorColumn = { bg = p.ink },
    ColorColumn = { bg = p.base },
    Visual = { bg = p.selection },
    Search = { fg = p.fg, bg = p.blue_dark },
    CurSearch = { fg = p.black, bg = p.blue },
    IncSearch = { fg = p.black, bg = p.blue },
    MatchParen = { fg = p.blue, bg = p.surface_high },
    LineNr = { fg = p.subtle, bg = p.black },
    CursorLineNr = { fg = p.blue, bg = p.black },
    SignColumn = { fg = p.muted, bg = p.black },
    FoldColumn = { fg = p.subtle, bg = p.black },
    Folded = { fg = p.muted, bg = p.base },
    WinSeparator = { fg = p.divider, bg = p.black },
    StatusLine = { fg = p.fg_dim, bg = p.base },
    StatusLineNC = { fg = p.subtle, bg = p.ink },
    MsgSeparator = { fg = p.divider, bg = p.black },
    WinBar = { fg = p.fg_dim, bg = p.overlay_high },
    WinBarNC = { fg = p.muted, bg = p.overlay_high },
    TabLine = { fg = p.muted, bg = p.surface },
    TabLineFill = { bg = p.surface },
    TabLineSel = { fg = p.fg, bg = p.surface_high },
    QuickFixLine = { bg = p.surface },
    Pmenu = { fg = p.fg_dim, bg = p.surface_high },
    PmenuSel = { fg = p.fg, bg = p.overlay_high },
    PmenuKind = { fg = p.muted, bg = p.surface_high },
    PmenuKindSel = { fg = p.sky, bg = p.overlay_high },
    PmenuExtra = { fg = p.subtle, bg = p.surface_high },
    PmenuExtraSel = { fg = p.fg_dim, bg = p.overlay_high },
    PmenuSbar = { bg = p.overlay },
    PmenuThumb = { bg = p.border },
    Directory = { fg = p.sky },
    Title = { fg = p.blue },
    Todo = { fg = p.black, bg = p.blue },

    -- Preserve the Kanagawa semantic layout while using DeepSeek's code colors.
    Boolean = { fg = theme.syn.constant },
    ['@variable.builtin'] = { fg = theme.syn.special2 },
    ['@string.escape'] = { fg = theme.syn.regex },
    ['@keyword.operator'] = { fg = theme.syn.operator },
    ['@lsp.typemod.function.readonly'] = { fg = theme.syn.fun },
    ['@markup.strong'] = {},
    ['@markup.italic'] = {},

    -- Completion and pickers use the same three surface levels as the reference UI.
    BlinkCmpMenu = { fg = p.fg_dim, bg = p.surface_high },
    BlinkCmpMenuBorder = { fg = p.divider, bg = p.surface_high },
    BlinkCmpMenuSelection = { fg = p.fg, bg = p.overlay_high },
    BlinkCmpLabel = { fg = p.fg_dim },
    BlinkCmpLabelMatch = { fg = p.blue },
    BlinkCmpLabelDeprecated = { fg = p.subtle, strikethrough = true },
    BlinkCmpDoc = { fg = p.fg_dim, bg = p.surface_high },
    BlinkCmpDocBorder = { fg = p.divider, bg = p.surface_high },
    BlinkCmpSignatureHelp = { fg = p.fg_dim, bg = p.surface_high },
    BlinkCmpSignatureHelpBorder = { fg = p.divider, bg = p.surface_high },

    TelescopeNormal = { fg = p.fg_dim, bg = p.surface_high },
    TelescopeBorder = { fg = p.divider, bg = p.surface_high },
    TelescopePromptNormal = { fg = p.fg, bg = p.surface_high },
    TelescopePromptBorder = { fg = p.divider, bg = p.surface_high },
    TelescopePromptTitle = { fg = p.black, bg = p.blue },
    TelescopePreviewTitle = { fg = p.blue, bg = p.surface_high },
    TelescopeResultsTitle = { fg = p.muted, bg = p.surface_high },
    TelescopeSelection = { fg = p.fg, bg = p.overlay },
    TelescopeSelectionCaret = { fg = p.blue, bg = p.overlay },
    TelescopeMatching = { fg = p.blue },

    -- Sidebar and top-bar layers mirror DeepSeek's dark navigation rail.
    NeoTreeNormal = { fg = p.fg_dim, bg = p.base },
    NeoTreeNormalNC = { fg = p.fg_dim, bg = p.base },
    NeoTreeEndOfBuffer = { fg = p.base, bg = p.base },
    NeoTreeWinSeparator = { fg = p.divider, bg = p.black },
    NeoTreeCursorLine = { bg = p.overlay },
    NeoTreeDirectoryIcon = { fg = p.blue },
    NeoTreeDirectoryName = { fg = p.fg_dim },
    NeoTreeRootName = { fg = p.fg },

    BufferLineFill = { bg = p.surface },
    BufferLineBackground = { fg = p.muted, bg = p.surface },
    BufferLineBufferVisible = { fg = p.fg_dim, bg = p.surface },
    BufferLineBufferSelected = { fg = p.fg, bg = p.surface_high },
    BufferLineIndicatorSelected = { fg = p.blue, bg = p.surface_high },
    BufferLineSeparator = { fg = p.surface, bg = p.surface },
    BufferLineSeparatorVisible = { fg = p.surface, bg = p.surface },
    BufferLineSeparatorSelected = { fg = p.surface, bg = p.surface_high },
    BufferLineModified = { fg = p.yellow, bg = p.surface },
    BufferLineModifiedVisible = { fg = p.yellow, bg = p.surface },
    BufferLineModifiedSelected = { fg = p.yellow, bg = p.surface_high },

    -- Common floating/plugin surfaces.
    LazyNormal = { fg = p.fg_dim, bg = p.surface_high },
    MasonNormal = { fg = p.fg_dim, bg = p.surface_high },
    NoiceCmdlinePopup = { fg = p.fg, bg = p.surface_high },
    NoiceCmdlinePopupBorder = { fg = p.divider, bg = p.surface_high },
    NoiceCmdlineIcon = { fg = p.blue },
    WhichKeyNormal = { fg = p.fg_dim, bg = p.surface_high },
    WhichKeyBorder = { fg = p.divider, bg = p.surface_high },
    WhichKey = { fg = p.blue },
    TroubleNormal = { fg = p.fg_dim, bg = p.base },
    TroubleNormalNC = { fg = p.fg_dim, bg = p.base },
    TroubleCount = { fg = p.blue, bg = p.selection },

    SnacksNormal = { fg = p.fg_dim, bg = p.surface_high },
    SnacksNormalNC = { fg = p.fg_dim, bg = p.surface_high },
    SnacksPickerNormal = { fg = p.fg_dim, bg = p.surface },
    SnacksPickerBorder = { fg = p.divider, bg = p.surface },
    SnacksPickerMatch = { fg = p.blue },
    SnacksPickerCursorLine = { bg = p.overlay },

    GitSignsAdd = { fg = p.green },
    GitSignsChange = { fg = p.yellow },
    GitSignsDelete = { fg = p.red },
    DiffviewStatusAdded = { fg = p.green },
    DiffviewStatusModified = { fg = p.yellow },
    DiffviewStatusDeleted = { fg = p.red },

    FlashLabel = { fg = p.black, bg = p.blue },
    FlashMatch = { fg = p.fg_dim, bg = p.blue_dark },
    FlashCurrent = { fg = p.black, bg = p.sky },
  }
end

function M.setup()
  require('kanagawa').setup {
    compile = false,
    undercurl = true,
    commentStyle = { italic = false, bold = false },
    functionStyle = { italic = false, bold = false },
    keywordStyle = { italic = false, bold = false },
    statementStyle = { italic = false, bold = false },
    typeStyle = { italic = false, bold = false },
    transparent = false,
    dimInactive = false,

    -- Do not replace the host terminal's ANSI palette for :terminal buffers.
    terminalColors = false,
    colors = {
      palette = kanagawa_palette,
      theme = { wave = wave },
    },
    overrides = overrides,
    theme = 'wave',
    background = { dark = 'wave', light = 'wave' },
  }
end

-- Kanagawa has a few intentionally bold/italic groups outside its style options.
-- Removing these attributes after generation guarantees that the terminal remains
-- the only authority over the selected font face and weight.
function M.strip_font_styles()
  if not vim.api.nvim_get_hl then return end

  local attributes = { 'bold', 'italic', 'altfont', 'font' }
  for name, spec in pairs(vim.api.nvim_get_hl(0, { link = true })) do
    local changed = false

    for _, attribute in ipairs(attributes) do
      if spec[attribute] ~= nil then
        spec[attribute] = nil
        changed = true
      end
      if type(spec.cterm) == 'table' and spec.cterm[attribute] ~= nil then
        spec.cterm[attribute] = nil
        changed = true
      end
    end

    if changed then vim.api.nvim_set_hl(0, name, spec) end
  end
end

local function clear_terminal_palette()
  -- Kanagawa defines 0-17, while Nvim's documented ANSI palette is 0-15.
  -- Clear both ranges so switching from another Kanagawa variant is reversible.
  for index = 0, 17 do
    vim.g['terminal_color_' .. index] = nil
  end
end

function M.load()
  vim.o.background = 'dark'
  clear_terminal_palette()
  M.setup()
  require('kanagawa').load 'wave'
  M.strip_font_styles()
  vim.g.colors_name = M.name
end

return M

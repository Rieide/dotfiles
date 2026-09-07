local p = require('custom.themes.deepseek_wave').palette

local function active(accent)
  return {
    a = { fg = p.black, bg = accent },
    b = { fg = accent, bg = p.base },
    c = { fg = p.fg_dim, bg = p.base },
  }
end

return {
  normal = active(p.blue),
  insert = active(p.green),
  visual = active(p.violet),
  replace = active(p.red),
  command = active(p.yellow),
  terminal = active(p.cyan),
  inactive = {
    a = { fg = p.subtle, bg = p.ink },
    b = { fg = p.subtle, bg = p.ink },
    c = { fg = p.muted, bg = p.ink },
  },
}

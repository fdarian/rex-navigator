# rex-navigator

Neovim plugin for seamless `ctrl+h/j/k/l` navigation between Neovim splits and [Rex](https://superlogical.com/rex) panes, like vim-tmux-navigator.

Inside a split the key moves between Neovim windows. At the edge of the window layout it runs `rex focus <direction>`, handing focus to the neighbouring Rex pane. Outside Rex (or inside tmux) it falls back to a plain `:wincmd`.

## Neovim

```lua
{
  dir = "~/code/fdarian/rex-navigator",
  opts = {}, -- mappings = { left = "<C-h>", ... } | false, cli = "/path/to/rex"
}
```

Also defines `:RexNavigateLeft|Down|Up|Right`.

## Rex

Rex must not swallow the keys while Neovim is in the foreground, and must move pane focus otherwise (`~/.config/rex/init.lua`):

```lua
local terminal = "com.superlogical.terminal"

local function foreground_is_nvim()
  local process, err = rex.block.call(terminal, "process", {})
  if not process then error(err, 0) end
  return process.foreground ~= nil and process.foreground.name == "nvim"
end

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+" .. key, function()
    if foreground_is_nvim() then return false end
    local _, err = rex.session.focus_direction{ direction = direction }
    if err then error(err, 0) end
    return true
  end)
end
```

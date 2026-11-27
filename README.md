# rex-navigator

Neovim plugin for seamless `ctrl+h/j/k/l` navigation between Neovim splits and [Rex](https://superlogical.com/rex) panes, like vim-tmux-navigator.

Neovim tells Rex which directions it can still move in by publishing them in the terminal title. Rex passes the key to the pane when Neovim can move that way, and moves its own focus otherwise. Neovim never calls Rex, so this works over `ssh` too: the title crosses the connection and the remote Neovim needs no Rex binary or environment.

## Neovim

```lua
{
  dir = "~/code/fdarian/rex-navigator",
  opts = {}, -- mappings = { left = "<C-h>", ... } | false
}
```

Also defines `:RexNavigateLeft|Down|Up|Right`. At the edge of the window layout they do nothing.

`setup()` turns on `'title'` and sets `'titlestring'` itself, so it replaces any `'titlestring'` you configured. Inside tmux (`$TMUX` set) the title is left alone, since vim-tmux-navigator handles that case.

## Title protocol

```
nvim[<letters>] <file tail>
```

`<letters>` is the subset of `hjkl`, in that order, for which a non-floating window exists in that direction from the current window: `nvim[hl] init.lua`, `nvim[] init.lua`. The title is updated on window enter, resize, close and tab change. While a floating window is current the letters stay as they were.

When Neovim exits or suspends the title no longer starts with `nvim[`: Neovim restores the terminal's previous title through the title stack, and for terminals that ignore the stack it falls back to `'titleold'` (set to the shell name unless you set it) so a stale `nvim[` title cannot outlive Neovim.

## Rex

`~/.config/rex/init.lua`:

```lua
local terminal = "com.superlogical.terminal"

local function pane_handles(letter)
  local result, err = rex.block.call(terminal, "title", {})
  if not result then error(err, 0) end
  -- a stale title from a program that has exited must not hijack the keys
  if result.owner == nil or (result.owner.name ~= "nvim" and result.owner.name ~= "ssh") then
    return false
  end
  local letters = result.title:match("^nvim%[([hjkl]*)%]")
  return letters ~= nil and letters:find(letter, 1, true) ~= nil
end

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+" .. key, function()
    if pane_handles(key) then return false end
    local _, err = rex.session.focus_direction{ direction = direction }
    if err then error(err, 0) end
    return true
  end)
end
```

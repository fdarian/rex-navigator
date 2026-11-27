# rex-navigator

Neovim plugin for seamless `ctrl+h/j/k/l` navigation between Neovim splits and [Rex](https://superlogical.com/rex) panes, like [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator).

Neovim tells Rex which directions it can still move in by publishing them in the terminal title. Rex passes the key to the pane when Neovim can move that way, and moves its own focus otherwise. Neovim never calls Rex, so this works over `ssh` too: the title crosses the connection and the remote Neovim needs no Rex binary or environment.

## Usage

`ctrl+h/j/k/l` move to the split on the left, below, above and right of the current one. At the edge of the window layout Neovim does nothing, and Rex moves focus to the neighbouring pane instead.

The same moves are available as commands, handy for your own mappings or the command line:

```
:RexNavigateLeft
:RexNavigateDown
:RexNavigateUp
:RexNavigateRight
```

### Change the keys

`mappings` takes the key for each direction (normal mode). Directions you leave out keep their defaults.

```lua
opts = {
  mappings = { left = "<A-h>", down = "<A-j>", up = "<A-k>", right = "<A-l>" },
}
```

The default is `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>`. Note that Rex only hands the key to Neovim for `ctrl+h/j/k/l`, so other keys need a matching binding in your Rex config (see [Rex](#rex)).

### Your own mappings

With `mappings = false` no keymaps are defined (the commands still are). Call `navigate` from your own mappings:

```lua
require("rex-navigator").navigate("left") -- "left" | "down" | "up" | "right"
```

### Alongside vim-tmux-navigator

Inside tmux, vim-tmux-navigator should handle the keys. Turn off rex-navigator's mappings and route each key yourself: to `TmuxNavigate*` when `$TMUX` is set, to rex-navigator otherwise.

```lua
{
  "christoomey/vim-tmux-navigator",
  dependencies = {
    { "fdarian/rex-navigator", opts = { mappings = false } },
  },
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
  config = function()
    local function navigate(tmux_cmd, direction)
      return function()
        if vim.env.TMUX then
          vim.cmd(tmux_cmd)
        else
          require("rex-navigator").navigate(direction)
        end
      end
    end

    vim.keymap.set("n", "<C-h>", navigate("TmuxNavigateLeft", "left"))
    vim.keymap.set("n", "<C-j>", navigate("TmuxNavigateDown", "down"))
    vim.keymap.set("n", "<C-k>", navigate("TmuxNavigateUp", "up"))
    vim.keymap.set("n", "<C-l>", navigate("TmuxNavigateRight", "right"))
  end,
}
```

Inside tmux (`$TMUX` set) `setup()` leaves the title alone, since vim-tmux-navigator handles that case. Without the routing above, rex-navigator's own keys inside tmux only move between Neovim splits.

## Install

### Neovim

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "fdarian/rex-navigator",
  opts = {}, -- mappings = { left = "<C-h>", ... } | false
}
```

`setup()` turns on `'title'` and sets `'titlestring'` itself, so it replaces any `'titlestring'` you configured.

### Rex

In `~/.config/rex/init.lua`:

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

## Title protocol

Reference for writing your own Rex binding.

```
nvim[<letters>] <file tail>
```

`<letters>` is the subset of `hjkl`, in that order, for which a non-floating window exists in that direction from the current window: `nvim[hl] init.lua`, `nvim[] init.lua`. It is empty in the command-line window.

The title is updated when a window is entered, created, resized or closed, when the terminal is resized, and on tab change. While a floating window is current the letters stay as they were.

When Neovim exits or suspends the title no longer starts with `nvim[`: Neovim restores the terminal's previous title through the title stack. For terminals that ignore the stack, `'titleold'` (set to the shell name unless you set it) is used instead, so a stale `nvim[` title cannot outlive Neovim. On suspend the plugin sets that title itself, and on resume it publishes the title again.

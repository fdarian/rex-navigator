local M = {}

local directions = {
	left = { key = "h", command = "RexNavigateLeft" },
	down = { key = "j", command = "RexNavigateDown" },
	up = { key = "k", command = "RexNavigateUp" },
	right = { key = "l", command = "RexNavigateRight" },
}

---@class RexNavigatorConfig
---@field mappings table<string, string>|false lhs per direction, or false to define no keymaps
M.config = {
	mappings = { left = "<C-h>", down = "<C-j>", up = "<C-k>", right = "<C-l>" },
}

---Move to the neighbouring nvim window; at the edge, do nothing (Rex moves its own focus, see the README).
---@param direction "left"|"down"|"up"|"right"
function M.navigate(direction)
	local target = directions[direction]
	if not target then
		error("rex-navigator: unknown direction " .. tostring(direction), 0)
	end
	if vim.fn.getcmdwintype() ~= "" then
		return
	end
	vim.cmd.wincmd(target.key)
end

---Letters of `hjkl` for which a non-floating window exists in that direction from the current window.
---@return string
function M.navigable_letters()
	if vim.fn.getcmdwintype() ~= "" then
		return ""
	end
	local letters = ""
	for _, key in ipairs({ "h", "j", "k", "l" }) do
		if vim.fn.winnr(key) ~= vim.fn.winnr() then
			letters = letters .. key
		end
	end
	return letters
end

local function publish_title()
	if vim.api.nvim_win_get_config(0).relative ~= "" then
		return
	end
	local titlestring = "nvim[" .. M.navigable_letters() .. "] %t"
	if vim.o.titlestring ~= titlestring then
		vim.o.titlestring = titlestring
	end
end

local function osc_title(title)
	vim.api.nvim_ui_send("\27]2;" .. title .. "\7")
end

local function setup_title()
	vim.o.title = true
	-- nvim only emits 'titleold' on exit when it is non-empty; without it a terminal that ignores the title stack keeps `nvim[..]`.
	if vim.o.titleold == "" then
		vim.o.titleold = vim.fn.fnamemodify(vim.o.shell, ":t")
	end

	local group = vim.api.nvim_create_augroup("RexNavigatorTitle", { clear = true })
	vim.api.nvim_create_autocmd({ "WinEnter", "WinResized", "VimResized", "TabEnter", "WinNew" }, {
		group = group,
		callback = publish_title,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function()
			-- the window is still in the layout while WinClosed runs
			vim.schedule(publish_title)
		end,
	})
	-- nvim's own suspend only pops the terminal's title stack, which a terminal may ignore.
	vim.api.nvim_create_autocmd("VimSuspend", {
		group = group,
		callback = function()
			osc_title(vim.o.titleold)
		end,
	})
	vim.api.nvim_create_autocmd("VimResume", {
		group = group,
		callback = function()
			publish_title()
			-- nvim may consider the title unchanged and not re-send it after the suspend reset it
			osc_title(vim.api.nvim_eval_statusline(vim.o.titlestring, {}).str)
		end,
	})
	publish_title()
end

---@param opts RexNavigatorConfig|nil
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	for direction, target in pairs(directions) do
		vim.api.nvim_create_user_command(target.command, function()
			M.navigate(direction)
		end, { force = true })
		if M.config.mappings then
			vim.keymap.set("n", M.config.mappings[direction], function()
				M.navigate(direction)
			end, { desc = "Rex navigate " .. direction })
		end
	end
	if vim.env.TMUX == nil then
		setup_title()
	end
end

return M

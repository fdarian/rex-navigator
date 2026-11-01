local M = {}

local directions = {
	left = { key = "h", command = "RexNavigateLeft" },
	down = { key = "j", command = "RexNavigateDown" },
	up = { key = "k", command = "RexNavigateUp" },
	right = { key = "l", command = "RexNavigateRight" },
}

local app_cli = "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"

---@class RexNavigatorConfig
---@field mappings table<string, string>|false lhs per direction, or false to define no keymaps
---@field cli string|nil path to the rex binary; defaults to `rex` on PATH, then the app bundle
M.config = {
	mappings = { left = "<C-h>", down = "<C-j>", up = "<C-k>", right = "<C-l>" },
}

function M.in_rex()
	return vim.env.REX_SESSION ~= nil and vim.env.TMUX == nil
end

local function cli()
	if M.config.cli then
		return M.config.cli
	end
	if vim.fn.executable("rex") == 1 then
		return "rex"
	end
	if vim.fn.executable(app_cli) == 1 then
		return app_cli
	end
	error("rex-navigator: rex binary not found; set `cli` in setup()", 0)
end

---Move to the neighbouring nvim window; at the edge, hand focus to the Rex pane in that direction.
---@param direction "left"|"down"|"up"|"right"
function M.navigate(direction)
	local target = directions[direction]
	if not target then
		error("rex-navigator: unknown direction " .. tostring(direction), 0)
	end
	if vim.fn.getcmdwintype() ~= "" then
		return
	end
	if vim.fn.winnr(target.key) ~= vim.fn.winnr() or not M.in_rex() then
		vim.cmd.wincmd(target.key)
		return
	end
	vim.system({ cli(), "focus", direction }, { text = true }, function(result)
		if result.code ~= 0 then
			vim.schedule(function()
				vim.notify("rex focus " .. direction .. " failed: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
			end)
		end
	end)
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
end

return M

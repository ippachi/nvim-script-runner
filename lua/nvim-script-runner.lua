local M = {}
local progress = require("fidget.progress")
local ScriptRunner = {}

local function table_keys(t)
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, k)
	end
	return keys
end

function ScriptRunner:new(opts)
	local o = opts or {}
	self.runner_bufnr = vim.api.nvim_create_buf(false, true)
	self.runner_channel_id = vim.api.nvim_open_term(self.runner_bufnr, {})
	setmetatable(o, self)
	self.__index = self
	return o
end

function ScriptRunner:set_preset(cb)
	vim.ui.select(table_keys(self.presets), {
		prompt = "Select preset command:",
	}, function(choise)
		self.preset = self.presets[choise]
		if cb then
			cb()
		end
	end)
end

function ScriptRunner:run_preset(preset_command_number)
	if not self.preset then
		self:set_preset(function()
			if not self.preset then
				vim.notify("No preset command found", vim.log.levels.ERROR, {})
				return
			end

      self:run(self:_command_from_preset(preset_command_number))
		end)
	else
    self:run(self:_command_from_preset(preset_command_number))
	end
end

function ScriptRunner:run(command)
	self.last_command = command
  self:_start_job(command)
end

function ScriptRunner:run_last()
	if not self.last_command then
		vim.notify("No last command found", vim.log.levels.ERROR, {})
		return
	end

	self:_start_job(self.last_command)
end

function ScriptRunner:open_output()
	vim.api.nvim_command("buffer " .. self.runner_bufnr)
end

function ScriptRunner:_start_job(command)
  vim.cmd(string.format("TermExec cmd='%s'", command))
end

function ScriptRunner:_command_from_preset(preset_command_number)
	return self.preset[preset_command_number]()
end

function ScriptRunner:_notify_result(code)
	if code == 0 then
		vim.notify("Passed✅", vim.log.levels.INFO, {})
	else
		vim.notify("Failed❌", vim.log.levels.ERROR, {})
	end
end

local script_runner = nil

function M.setup(opts)
	return {
		run = function(command)
			script_runner = script_runner or ScriptRunner:new(opts)
			script_runner:run(command)
		end,
		run_preset = function(preset_command_number)
			script_runner = script_runner or ScriptRunner:new(opts)
			script_runner:run_preset(preset_command_number)
		end,
		run_last = function()
			script_runner = script_runner or ScriptRunner:new(opts)
			script_runner:run_last()
		end,
		open_output = function()
			script_runner = script_runner or ScriptRunner:new(opts)
			if script_runner then
				script_runner:open_output()
			end
		end,
		set_preset = function()
			script_runner = script_runner or ScriptRunner:new(opts)
			if script_runner then
				script_runner:set_preset()
			end
		end,
	}
end

return M

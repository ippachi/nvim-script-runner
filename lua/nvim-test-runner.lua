local M = {}
local progress = require("fidget.progress")
local TestRunner = {}

local function table_keys(t)
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, k)
	end
	return keys
end

function TestRunner:new(opts)
	local o = opts or {}
	self.runner_bufnr = vim.api.nvim_create_buf(false, true)
	self.runner_channel_id = vim.api.nvim_open_term(self.runner_bufnr, {})
	setmetatable(o, self)
	self.__index = self
	return o
end

function TestRunner:set_setting(cb)
	vim.ui.select(table_keys(self.settings), {
		prompt = "Select test command:",
	}, function(choise)
		self.setting = self.settings[choise]
		if cb then
			cb()
		end
	end)
end

function TestRunner:run_test(test_command_number)
	if not self.setting then
		self:set_setting(function()
			if not self.setting then
				vim.notify("No test command found", vim.log.levels.ERROR, {})
				return
			end

			self:_start_test_job(self:_test_command(test_command_number))
		end)
	else
		self:_start_test_job(self:_test_command(test_command_number))
	end
end

function TestRunner:run_last()
	if not self.last_test_command then
		vim.notify("No last test command found", vim.log.levels.ERROR, {})
		return
	end

	self:_start_test_job(self.last_test_command)
end

function TestRunner:open_output()
	vim.api.nvim_command("buffer " .. self.runner_bufnr)
end

function TestRunner:_start_test_job(test_command)
	self:_start_progress(test_command)

	local temp_file_path = os.tmpname()
	local file = io.open(temp_file_path, "w")
	file:write(test_command)
	file:close()

	vim.api.nvim_chan_send(
		self.runner_channel_id,
		"---------------------------------\n"
			.. vim.system({ "tput", "bold" }):wait().stdout
			.. vim.system({ "tput", "setaf", "5" }):wait().stdout
			.. test_command
			.. vim.system({ "tput", "sgr0" }):wait().stdout
			.. "\n"
	)
	vim.system({ "script", "-q", "/dev/null", "sh", temp_file_path }, {
		text = false,
		stdout = function(err, data)
			if data ~= nil then
				vim.schedule(function()
					vim.api.nvim_chan_send(self.runner_channel_id, data)
				end)
			end
		end,
		stderr = function(err, data)
			if data ~= nil then
				vim.schedule(function()
					vim.api.nvim_chan_send(self.runner_channel_id, data)
				end)
			end
		end,
	}, function(result)
		os.remove(temp_file_path)
		self.fidget_handle:finish()
		vim.schedule(function()
			self:_notify_result(result.code)
		end)
	end)
end

function TestRunner:_test_command(test_command_number)
	local result = self.setting[test_command_number]()
	self.last_test_command = result
	return result
end

function TestRunner:_append_to_test_output_new_line(data)
	vim.fn.appendbufline(self.output_bufnr, vim.api.nvim_buf_line_count(self.output_bufnr), data)
	vim.api.nvim_buf_call(self.output_bufnr, function()
		vim.api.nvim_command("keepjumps normal! G")
	end)
end

function TestRunner:_notify_result(code)
	if code == 0 then
		vim.notify("Test Passed✅", vim.log.levels.INFO, {})
	else
		vim.notify("Test Failed❌", vim.log.levels.ERROR, {})
	end
end

function TestRunner:_start_progress(title)
	self.fidget_handle = progress.handle.create({
		title = title,
	})
end

local test_runner = nil

function M.setup(opts)
	return {
		run_test = function(test_command_number)
			test_runner = test_runner or TestRunner:new(opts)
			test_runner:run_test(test_command_number)
		end,
		run_last = function()
			test_runner = test_runner or TestRunner:new(opts)
			test_runner:run_last()
		end,
		open_output = function()
			test_runner = test_runner or TestRunner:new(opts)
			if test_runner then
				test_runner:open_output()
			end
		end,
		set_setting = function()
			test_runner = test_runner or TestRunner:new(opts)
			if test_runner then
				test_runner:set_setting()
			end
		end,
	}
end

return M

local M = {}
local progress = require("fidget.progress")
local TestRunner = {}

local function table_keys(t)
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, 1, k)
	end
	return keys
end

function TestRunner:new(opts)
	local o = opts or {}
	o.output_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = o.output_bufnr })
	setmetatable(o, self)
	self.__index = self
	return o
end

function TestRunner:set_test_command_functions()
	local ft_test_command_functions = self.command_functions_by_ft[vim.bo.filetype]

	local ft_test_command_keys = table_keys(ft_test_command_functions)
	if #ft_test_command_keys == 0 then
		return
	end
	if #ft_test_command_keys == 1 then
		self.test_command_functions = ft_test_command_functions[ft_test_command_keys[1]]
	else
		vim.ui.select(ft_test_command_keys, {
			prompt = "Select test command:",
		}, function(choise)
			self.test_command_functions = ft_test_command_functions[choise]
		end)
	end
end

function TestRunner:run_test(text_command_number)
	if not self.test_command_functions then
		self:set_test_command_functions()
	end

	if not self.test_command_functions then
		vim.notify("No test command found for filetype: " .. vim.bo.filetype, vim.log.levels.ERROR, {})
		return
	end

	self:_start_test_job(self:_test_command(text_command_number))
end

function TestRunner:run_last()
	if not self.last_test_command then
		vim.notify("No last test command found", vim.log.levels.ERROR, {})
		return
	end

	self:_start_test_job(self.last_test_command)
end

function TestRunner:open_output()
	vim.api.nvim_command("buffer " .. self.output_bufnr)
end

function TestRunner:_start_test_job(test_command)
	self:_start_progress(test_command)
	self:_append_to_test_output_new_line({
		"--------------------------------",
		"**" .. test_command .. "**",
		"```",
	})
	vim.fn.jobstart(test_command, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data, _)
			self:_append_to_test_output_new_line(data)
		end,
		on_stderr = function(_, data, _)
			self:_append_to_test_output_new_line(data)
		end,
		on_exit = function(_, code, _)
			self:_append_to_test_output_new_line({
				"```",
				"",
			})
			self.fidget_handle:finish()
			self:_notify_result(code)
		end,
	})
end

function TestRunner:_test_command(test_command_number)
	local result = self.test_command_functions[test_command_number]()
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
		set_test_command_functions = function()
			test_runner = test_runner or TestRunner:new(opts)
			if test_runner then
				test_runner:set_test_command_functions()
			end
		end,
	}
end

return M

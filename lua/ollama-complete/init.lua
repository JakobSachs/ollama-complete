local curl = require("plenary.curl")
local config = require("ollama-complete.config")
local json = vim.json

local M = {}

-- internal helper
local function complete(opts)
	opts = opts or {}
	local prefix = opts.prefix or ""
	local suffix = opts.suffix or ""
	local model = opts.model or config.options.model
	local url = config.options.base_url .. "/api/generate"

	local payload = {
		model = model,
		prompt = prefix,
		suffix = suffix,
		stream = false,
		options = {
			num_predict = config.options.num_predict,
			temp = config.options.temp,
		},
	}

	local res = curl.post(url, {
		headers = { ["Content-Type"] = "application/json" },
		body = json.encode(payload),
	})

	if res.status ~= 200 then
		vim.notify("Ollama request failed: " .. (res.body or ""), vim.log.levels.ERROR)
		return nil
	end

	local ok, data = pcall(json.decode, res.body)
	return ok and data.response or nil
end

-- public API -------------------------------------------------
function M.complete(opts)
	return complete(opts)
end

-- synchronous wrapper that returns the text
function M.complete_text(prefix, suffix, model)
	return complete({ prefix = prefix, suffix = suffix, model = model })
end

-- asynchronous wrapper that calls a callback
function M.complete_async(prefix, suffix, on_done, model)
	vim.schedule(function()
		local text = complete({ prefix = prefix, suffix = suffix, model = model })
		vim.schedule(function()
			on_done(text or "")
		end)
	end)
end

-- debounce utility
local function debounce(fn, delay)
	local timer = vim.loop.new_timer()
	local running = false
	return function(...)
		local args = { ... }
		if running then
			timer:stop()
		end
		running = true
		timer:start(delay, 0, function()
			running = false
			vim.schedule(function()
				fn(unpack(args))
			end)
		end)
	end
end

-- Store the latest suggestion
M.latest_suggestion = nil

-- refactored to accept suggestion and store it
function M.show_suggestion(suggestion)
	suggestion = suggestion and suggestion:gsub("%z", "") or nil
	if suggestion then
		suggestion = suggestion:match("^[^\n]*") -- only the first line
	end
	local api = vim.api
	local bnr = vim.fn.bufnr("%")
	local ns_id = api.nvim_create_namespace("ollama-complete")
	local cursor_pos = api.nvim_win_get_cursor(0)
	local line_num = cursor_pos[1] - 1
	local col_num = cursor_pos[2]
	-- clear previous extmarks
	api.nvim_buf_clear_namespace(bnr, ns_id, 0, -1)
	M.latest_suggestion = suggestion or nil
	if suggestion and suggestion ~= "" then
		local opts = {
			id = 1,
			virt_text = { { suggestion, "Comment" } },
			virt_text_pos = "inline",
		}
		api.nvim_buf_set_extmark(bnr, ns_id, line_num, col_num, opts)
	end
end

-- Accept/apply the suggestion at the cursor
function M.accept_suggestion()
	local suggestion = M.latest_suggestion
	if not suggestion or suggestion == "" then
		return
	end
	vim.schedule(function()
		local api = vim.api
		local bnr = vim.fn.bufnr("%")
		local ns_id = api.nvim_create_namespace("ollama-complete")
		local cursor_pos = api.nvim_win_get_cursor(0)
		local line_num = cursor_pos[1] - 1
		local col_num = cursor_pos[2]
		local line = api.nvim_get_current_line()

		-- Split suggestion into lines
		local suggestion_lines = {}
		for s in (suggestion .. "\n"):gmatch("(.-)\n") do
			table.insert(suggestion_lines, s)
		end

		if #suggestion_lines == 1 then
			-- Single line: simple replacement
			local new_line = line:sub(1, col_num) .. suggestion .. line:sub(col_num + 1)
			api.nvim_set_current_line(new_line)
			api.nvim_win_set_cursor(0, { line_num + 1, col_num + #suggestion })
		else
			-- Multi-line: replace current line and insert new lines
			local first = line:sub(1, col_num) .. suggestion_lines[1]
			local last = suggestion_lines[#suggestion_lines] .. line:sub(col_num + 1)
			local middle = {}
			for i = 2, #suggestion_lines - 1 do
				table.insert(middle, suggestion_lines[i])
			end
			local new_lines = { first }
			vim.list_extend(new_lines, middle)
			table.insert(new_lines, last)
			api.nvim_buf_set_lines(bnr, line_num, line_num + 1, false, new_lines)
			api.nvim_win_set_cursor(0, { line_num + #new_lines, #suggestion_lines[#suggestion_lines] })
		end

		api.nvim_buf_clear_namespace(bnr, ns_id, 0, -1)
		M.latest_suggestion = nil
	end)
end

-- triggers async completion and displays suggestion
function M.trigger_suggestion()
	local api = vim.api
	local cursor_pos = api.nvim_win_get_cursor(0)
	local line = api.nvim_get_current_line()
	local col_num = cursor_pos[2]
	local prefix = line:sub(1, col_num)
	local suffix = line:sub(col_num + 1)
	M.complete_async(prefix, suffix, function(suggestion)
		M.show_suggestion(suggestion)
	end)
end

-- debounced version
local debounced_trigger = debounce(M.trigger_suggestion, 200)

function M.setup(opts)
	config.setup(opts or {})
	vim.api.nvim_create_user_command("OllamaShowSuggestion", function()
		M.trigger_suggestion()
	end, {
		desc = "Show an Ollama virtual text suggestion.",
	})
	-- Autocmd for insert mode text change
	vim.api.nvim_create_autocmd({ "TextChangedI" }, {
		callback = function()
			debounced_trigger()
		end,
	})
	-- Map <Tab> in insert mode to accept suggestion if present
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			vim.keymap.set("i", "<Tab>", function()
				if M.latest_suggestion and M.latest_suggestion ~= "" then
					M.accept_suggestion()
				else
					return "\t"
				end
			end, { expr = true, buffer = true, desc = "Accept Ollama suggestion" })
		end,
	})
end

return M

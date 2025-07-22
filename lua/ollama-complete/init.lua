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
		options = { num_predict = 25 },
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
    if running then timer:stop() end
    running = true
    timer:start(delay, 0, function()
      running = false
      vim.schedule(function()
        fn(unpack(args))
      end)
    end)
  end
end

-- refactored to accept suggestion
function M.show_suggestion(suggestion)
  local api = vim.api
  local bnr = vim.fn.bufnr("%")
  local ns_id = api.nvim_create_namespace("ollama-complete")
  local cursor_pos = api.nvim_win_get_cursor(0)
  local line_num = cursor_pos[1] - 1
  local col_num = cursor_pos[2]
  -- clear previous extmarks
  api.nvim_buf_clear_namespace(bnr, ns_id, 0, -1)
  local opts = {
    id = 1,
    virt_text = { { " " .. (suggestion or ""), "Comment" } },
    virt_text_pos = "inline",
  }
  api.nvim_buf_set_extmark(bnr, ns_id, line_num, col_num, opts)
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
  vim.api.nvim_create_autocmd({"TextChangedI"}, {
    callback = function()
      debounced_trigger()
    end,
  })
end

return M

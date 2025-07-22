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

return M

local M = {}

M.defaults = {
	model = "JetBrains/Mellum-4b-sft-python",
	base_url = vim.env.OLLAMA_API_BASE or "http://localhost:11434",
	num_predict = 25,
	temp = 0.2,
	debug = false, -- Add debug flag
	prefix_window = 40, -- Number of characters before cursor
	suffix_window = 40, -- Number of characters after cursor
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M

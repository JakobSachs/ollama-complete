local M = {}

M.defaults = {
	model = "JetBrains/Mellum-4b-sft-python",
	base_url = vim.env.OLLAMA_API_BASE or "http://localhost:11434",
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M

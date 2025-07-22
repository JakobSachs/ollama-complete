-- Runs once when Neovim starts.
-- Only expose setup() so users can call require("my_ollama").setup{…}
local ok, _ = pcall(require, "plenary")
if not ok then
	vim.notify("ollama-complete.nvim needs plenary.nvim", vim.log.levels.ERROR)
end

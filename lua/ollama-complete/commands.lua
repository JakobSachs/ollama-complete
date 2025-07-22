local ollama = require("ollama-complete")

vim.api.nvim_create_user_command("OllamaShowSuggestion", function()
	ollama.show_suggestion()
end, {
	desc = "Show a static virtual text suggestion for testing.",
}) 
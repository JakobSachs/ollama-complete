# ollama-complete.nvim

A Neovim plugin for text completion using Ollama.

## Features

-   Provides synchronous and asynchronous text completion using Ollama's API.
-   Configurable model and API endpoint.

## Requirements

-   Neovim >= 0.8.0
-   [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
-   Ollama running locally.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "sachs/ollama-complete.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        require("ollama-complete.config").setup({
            -- your configuration options
        })
    end,
}
```

## Configuration

The `setup` function can be called to configure the plugin. The following options are available:

-   `model`: The Ollama model to use for completion (default: `"JetBrains/Mellum-4b-sft-python"`)
-   `base_url`: The base URL for the Ollama API (default: `vim.env.OLLAMA_API_BASE` or `"http://localhost:11434"`)
-   `num_predict`: Number of tokens to predict for each completion (default: `25`)
-   `temp`: Sampling temperature for completions (default: `0.2`)
-   `debug`: Enable debug logging of requests (default: `false`). If true, logs requests to `/tmp/ollama-complete-debug.log` and shows them in `vim.notify`.
-   `prefix_window`: Number of characters of context to include before the cursor (default: `40`).
-   `suffix_window`: Number of characters of context to include after the cursor (default: `40`).

Example configuration:

```lua
require("ollama-complete.config").setup({
    model = "codegemma",
    base_url = "http://127.0.0.1:11434",
    num_predict = 50, -- override default if desired
    temp = 0.5,       -- override default if desired
    debug = true,     -- enable debug logging
    prefix_window = 80, -- more context before cursor
    suffix_window = 80, -- more context after cursor
})
```

## Usage

The plugin provides the following Lua functions:

### `complete(opts)`

This is the main function to get a completion.

-   `opts`: A table with the following keys:
    -   `prefix`: The text before the cursor.
    -   `suffix`: The text after the cursor.
    -   `model`: The model to use (overrides the configured model).

Returns the completion text or `nil` on error.

### `complete_text(prefix, suffix, model)`

A synchronous wrapper around `complete`.

-   `prefix`: The text before the cursor.
-   `suffix`: The text after the cursor.
-   `model`: The model to use (overrides the configured model).

Returns the completion text or `nil` on error.

Example:

```lua
local ollama = require("ollama-complete")
local completion = ollama.complete_text("local function ", " end")
if completion then
    print(completion)
end
```

### `complete_async(prefix, suffix, on_done, model)`

An asynchronous wrapper around `complete`.

-   `prefix`: The text before the cursor.
-   `suffix`: The text after the cursor.
-   `on_done`: A function that will be called with the completion text.
-   `model`: The model to use (overrides the configured model).

Example:

```lua
local ollama = require("ollama-complete")
ollama.complete_async("local function ", " end", function(text)
    print("Completion: " .. text)
end)
```
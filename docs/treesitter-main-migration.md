# nvim-treesitter main migration

This configuration uses `nvim-treesitter` main commit `f603a2f4da48728f80257fb5fbb90145fd1dc173`. It requires Neovim 0.12 or later, `curl`, `tar`, tree-sitter CLI 0.26.1 or later, and a C compiler. The plugin is eager-loaded because main does not support lazy loading.

Before updating parsers, back up the active parser and query directories below `vim.fn.stdpath("data") .. "/site"`, plus legacy `stdpath("data") .. "/lazy/nvim-treesitter/parser"` and `parser-info` directories if present. Run the lazy update, then `:TSUpdate`; parser installation is asynchronous at startup. Check `:checkhealth nvim-treesitter` and open a Lua, C++, Markdown, and TypeScript buffer to confirm parsing and highlighting. After every required parser is installed in `site`, move legacy `parser` and `parser-info` into that backup. Do not leave legacy parsers on `runtimepath`, where they can be selected for a language absent from the new install.

After parser installation, run `NVIM_TREESITTER_RTP=<installed-main-plugin> nvim --headless -u NONE -l tests/test-treesitter-functional.lua`. It opens C++, C#, and shell buffers and verifies each actual parser starts without errors.

Highlighting starts through a `FileType` autocmd that maps Neovim filetypes to parser IDs, including `cs` to `c_sharp` and `sh` to `bash`. When asynchronous installation completes, open buffers retry highlighting. Folding remains owned by `nvim-ufo`; Tree-sitter `foldexpr` is not enabled. Tree-sitter indentation is experimental and remains disabled.

Rollback: restore the backed-up legacy parser/query directories, change the lock entry back to `master` commit `42fc28ba918343ebfd5565147a42a26580579482`, restore the former `nvim-treesitter.configs`.setup configuration, and use Neovim 0.11 only with that master branch.

Primary references: [nvim-treesitter README](https://github.com/nvim-treesitter/nvim-treesitter#quickstart) and [Neovim v0.12.5](https://github.com/neovim/neovim/releases/tag/v0.12.5).

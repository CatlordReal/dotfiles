# Writing tools

`require("writing_tools").setup()` enables spell checking with `en_gb` for Markdown, `text`, and `txt` buffers. Neovim's bundled English spell data supports regional `en_gb` selection.

`:WritingCount` opens a menu for characters, words, paragraphs, and lines. A visual `<leader>wc` counts selected lines; normal `<leader>wc` counts the buffer.

# Swift and xtool

Swift uses the toolchain's SourceKit-LSP with nvim-lspconfig's current root callback. It recognizes Swift packages, Xcode projects/workspaces, and BSP build servers. On macOS the server runs through `xcrun`; on Linux it uses `sourcekit-lsp` from `PATH`. Install the Swift toolchain separately; the dotfiles updater copies configuration and does not install system tools. Use `:checkhealth vim.lsp` to inspect attachment.

On macOS, when `xcode-select` points to Command Line Tools, the LSP and `:Xtool` use `/Applications/Xcode.app` or `Xcode-beta.app` if installed. This affects only those child processes. An explicit `DEVELOPER_DIR` or selected full Xcode always takes precedence; system settings remain unchanged. Linux keeps the toolchain on `PATH`.

Install xtool on macOS with `brew install xtool-org/tap/xtool`. On Linux or WSL, follow the [official Linux installation guide](https://github.com/xtool-org/xtool/blob/main/Documentation/xtool.docc/Installation-Linux.md) for Swift, device prerequisites, the AppImage, and setup.

Run `xtool setup` manually and follow its prompts for Apple authentication and SDK setup. See the [macOS guide](https://github.com/xtool-org/xtool/blob/main/Documentation/xtool.docc/Installation-macOS.md) and [xtool documentation](https://github.com/xtool-org/xtool) for current requirements. Neovim does not manage credentials.

`:Xtool` opens help in a terminal split. `:Xtool dev build` builds without deploying; `:Xtool devices` lists devices; `:Xtool dev` builds and attempts to install and run the project on a device. Arguments are passed directly to xtool. The command runs from the nearest `Package.swift` or Git root above the current file, falling back to Neovim's working directory. Run `:Xtool help dev` for available options.

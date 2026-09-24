#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT
export HOME="$TEST_HOME/home"
mkdir -p "$HOME/.local/bin" "$TEST_HOME/bin"
export TREE_SITTER_BIN="$TEST_HOME/bin/tree-sitter"
export CARGO_LOG="$TEST_HOME/cargo.log"
export PATH="$TEST_HOME/bin:$PATH"

source "$ROOT/nvim/setup.sh"
OS=linux
PACKAGE_MANAGER=apt-get
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

cat >"$TEST_HOME/bin/cargo" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CARGO_LOG"
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/tree-sitter" <<'CLI'
#!/usr/bin/env sh
printf '%s\n' 'tree-sitter 0.26.1'
CLI
chmod +x "$HOME/.local/bin/tree-sitter"
SH
chmod +x "$TEST_HOME/bin/cargo"

cat >"$TREE_SITTER_BIN" <<'SH'
#!/usr/bin/env sh
printf '%s\n' 'tree-sitter 0.26.1'
SH
chmod +x "$TREE_SITTER_BIN"
ensure_tree_sitter_cli >/dev/null
[[ ! -e "$CARGO_LOG" ]] || { echo 'current CLI should skip Cargo' >&2; exit 1; }

cat >"$TREE_SITTER_BIN" <<'SH'
#!/usr/bin/env sh
printf '%s\n' 'tree-sitter 0.25.0'
SH
chmod +x "$TREE_SITTER_BIN"
ensure_tree_sitter_cli >/dev/null
grep -Fxq 'install tree-sitter-cli --version 0.26.1 --locked --root '"$HOME/.local" "$CARGO_LOG"

rm -f "$TREE_SITTER_BIN" "$HOME/.local/bin/tree-sitter" "$TEST_HOME/bin/cargo" "$CARGO_LOG"
install_linux_logical() {
    [[ "$1:$2" == 'rust:required' ]] || { echo "unexpected package request: $1 $2" >&2; return 1; }
    cat >"$TEST_HOME/bin/cargo" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CARGO_LOG"
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/tree-sitter" <<'CLI'
#!/usr/bin/env sh
printf '%s\n' 'tree-sitter 0.26.1'
CLI
chmod +x "$HOME/.local/bin/tree-sitter"
SH
    chmod +x "$TEST_HOME/bin/cargo"
}
PATH="$TEST_HOME/bin:/usr/bin:/bin"
hash -r
ensure_tree_sitter_cli >/dev/null
grep -Fxq 'install tree-sitter-cli --version 0.26.1 --locked --root '"$HOME/.local" "$CARGO_LOG"

echo 'nvim treesitter CLI installer: ok'

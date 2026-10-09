#!/usr/bin/env bash
# Strict type checks every file in src with luau-lsp, using Roblox API types and a Rojo
# sourcemap so requires resolve. Run from the repo root: bash scripts/typecheck.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep this in step with the luau-lsp version in rokit.toml.
LUAU_LSP_VERSION="1.70.1"
DEFS_DIR=".luau-lsp"
DEFS_FILE="$DEFS_DIR/globalTypes.None.$LUAU_LSP_VERSION.d.luau"
DEFS_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$LUAU_LSP_VERSION/scripts/globalTypes.None.d.luau"

if [ ! -f "$DEFS_FILE" ]; then
	mkdir -p "$DEFS_DIR"
	echo "Downloading Roblox type definitions for luau-lsp $LUAU_LSP_VERSION"
	curl -fsSL -o "$DEFS_FILE" "$DEFS_URL"
fi

rojo sourcemap default.project.json --output sourcemap.json > /dev/null

luau-lsp analyze \
	--platform roblox \
	--sourcemap sourcemap.json \
	--definitions "@roblox=$DEFS_FILE" \
	src
echo "Type check passed"

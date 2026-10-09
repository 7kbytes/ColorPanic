#!/usr/bin/env bash
# Runs the pure-logic tests in tests/ with Lune. Run from the repo root: bash scripts/test.sh
set -euo pipefail

cd "$(dirname "$0")/.."

rojo sourcemap default.project.json --output sourcemap.json > /dev/null
lune run tests/run

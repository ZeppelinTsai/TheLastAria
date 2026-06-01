#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

resolve_godot_bin() {
    if [[ -n "${GODOT_BIN:-}" ]]; then
        printf '%s\n' "$GODOT_BIN"
        return 0
    fi

    local candidate
    for candidate in godot godot4 godot4.6; do
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done

    return 1
}

echo "========================="
echo "Godot Web Export"
echo "========================="

if ! GODOT_BIN_PATH="$(resolve_godot_bin)"; then
    echo "FAILED"
    echo "Godot executable not found. Install Godot or set GODOT_BIN=/path/to/godot."
    exit 127
fi

rm -rf build/web
mkdir -p build/web

if ! "$GODOT_BIN_PATH" --headless --path . --export-release "Web" build/web/index.html; then
    echo "FAILED"
    echo "If the error mentions missing export templates, install the matching Godot Export Templates for your current Godot version."
    exit 1
fi

echo "export finished"

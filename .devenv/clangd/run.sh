#!/usr/bin/env bash

# .devenv/config.toml の [clangd].enable が true のときだけ
# .clangd 生成スクリプトを実行します。
CONFIG_FILE="$PWD/.devenv/config.toml"

if [ ! -f "$CONFIG_FILE" ]; then
  return 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  return 0
fi

enabled="$({
  python3 - "$CONFIG_FILE" <<'PY'
from pathlib import Path
import sys
import tomllib

config_path = Path(sys.argv[1])
try:
    data = tomllib.loads(config_path.read_text(encoding="utf-8"))
except Exception:
    print("false")
    raise SystemExit(0)

clangd = data.get("clangd")
if isinstance(clangd, dict) and clangd.get("enable") is True:
    print("true")
else:
    print("false")
PY
} 2>/dev/null || echo "false")"

if [ "$enabled" != "true" ]; then
  return 0
fi

python3 "$PWD/.devenv/clangd/generate_clangd.py"

#!/usr/bin/env bash
set -euo pipefail

# direnv などから `source` される入口です。
# 下位スクリプトで export した値を、呼び出し元シェルへ反映します。
source "$PWD/.devenv/run_codex.sh"
source "$PWD/.devenv/run_nvm.sh"

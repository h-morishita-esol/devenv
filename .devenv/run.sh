#!/usr/bin/env bash
set -euo pipefail

# このファイルは direnv などから読み込まれるエントリポイントです。
# 実行ではなく source 前提のため、下位スクリプトで export した環境変数を
# 呼び出し元シェルへ反映できます。
source "$PWD/.devenv/run_codex.sh"
source "$PWD/.devenv/run_nvm.sh"
